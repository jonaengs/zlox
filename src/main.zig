const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const VM = @import("vm.zig");

fn repl(allocator: std.mem.Allocator) !void {
    var buffer = [_:0]u8{0} ** 1024;
    const stdin = std.io.getStdIn().reader();

    while (true) {
        std.debug.print("> ", .{});
        // TODO: Handle inputs larger than buffer size gracefully
        const bytes_read = try stdin.read(&buffer);
        if (bytes_read == 0) {
            std.debug.print("\n", .{});
            break;
        }

        buffer[bytes_read] = 0;
        std.debug.print("--- Interpreting Result ---\n", .{});
        try VM.interpret(allocator, buffer[0..bytes_read :0]);
    }
}

/// Reads the contents of the file in the path into a dynamically
/// sized and allocated array
fn readFile(allocator: std.mem.Allocator, path: []const u8) ![:0]const u8 {
    // const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    // const contents: [:0]u8 = try file.reader().readAllAlloc(allocator, std.math.maxInt(u32));
    // file.close();
    // return contents;
    const data = try std.fs.cwd().readFileAllocOptions(allocator, path, std.math.maxInt(usize), null, 8, 0);
    return data;
}

fn runFile(allocator: std.mem.Allocator, path: []const u8) void {
    var source: [:0]const u8 = undefined;
    if (readFile(allocator, path)) |data| {
        source = data;
    } else |err| {
        switch (err) {
            error.FileNotFound => {
                std.debug.print("\nERROR: Could not find file: {s}.\n", .{path});
            },
            error.OutOfMemory => {
                std.debug.print("\nERROR: Not enough memory to read: {s}.\n", .{path});
            },
            // error.ReadError => {
            //     std.debug.print("\nERROR: Could not read file: {s}.\n", .{path});
            // },
            else => {
                std.debug.print("\nERROR: Other I/O error: {s}.\n", .{path});
            },
        }
        std.os.exit(74);
    }
    defer allocator.free(source);

    VM.interpret(allocator, source) catch |err| switch (err) {
        error.CompileError => std.process.exit(65),
        error.RuntimeError => std.process.exit(70),
    };
}

pub fn main() !void {
    // Setup allocator
    var _allocator_maker = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = _allocator_maker.allocator();

    VM.init();
    defer VM.free();

    var args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);
    if (args.len == 1) {
        try repl(gpa);
    } else if (args.len == 2) {
        runFile(gpa, args[1]);
    } else {
        // debug.print outputs to stderr
        std.debug.print("Usage: zlox [path]\n", .{});
        std.process.exit(64);
    }
}

//
//
// TESTS
//

test "simple arithmetic doesn't crash" {
    // Setup
    const gpa = std.testing.allocator;
    VM.init();
    var chunk: Chunk = undefined;
    chunk.init();
    defer chunk.free(gpa);
    defer VM.free();

    // Push 1 to the stack
    var constant: u8 = try chunk.addConstant(gpa, Value{ .number = 1.0 });
    try chunk.write(gpa, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(gpa, constant, 1);

    // Evaluate -( -(1.2) + (-3.4) )
    constant = try chunk.addConstant(gpa, Value{ .number = 1.2 });
    try chunk.write(gpa, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(gpa, constant, 1);
    try chunk.write(gpa, @intFromEnum(OpCode.OP_NEGATE), 1);

    constant = try chunk.addConstant(gpa, Value{ .number = -3.4 });
    try chunk.write(gpa, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(gpa, constant, 1);

    try chunk.write(gpa, @intFromEnum(OpCode.OP_ADD), 1);
    try chunk.write(gpa, @intFromEnum(OpCode.OP_NEGATE), 1);

    // Return 1 * (ans / 4.6)
    constant = try chunk.addConstant(gpa, Value{ .number = 4.6 });
    try chunk.write(gpa, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(gpa, constant, 1);

    try chunk.write(gpa, @intFromEnum(OpCode.OP_DIVIDE), 1);
    try chunk.write(gpa, @intFromEnum(OpCode.OP_MULTIPLY), 1);
    try chunk.write(gpa, @intFromEnum(OpCode.OP_RETURN), 1);

    // Execute
    try VM.interpretChunk(&chunk);
}

test "add constant doesn't crash" {
    const allocator = std.testing.allocator;
    var chunk: Chunk = undefined;
    chunk.init();

    const constant = try chunk.addConstant(allocator, Value{ .number = 1.2 });
    try chunk.write(allocator, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(allocator, constant, 1);

    // Expect to see the instruction first
    try std.testing.expect(@as(OpCode, @enumFromInt(chunk.code[0])) == OpCode.OP_CONSTANT);
    // then the index
    try std.testing.expectEqual(@as(usize, 0), chunk.code[1]);
    // Expect the index to lead to the correct value
    try std.testing.expectEqual(@as(f64, 1.2), chunk.constants.values[0].number);

    // Expect both code and constants arrays to have length 8 before free
    try std.testing.expectEqual(@as(usize, 8), chunk.code.len);
    try std.testing.expectEqual(@as(usize, 8), chunk.constants.values.len);
    try std.testing.expectEqual(@as(usize, 2), chunk.count);
    try std.testing.expectEqual(@as(usize, 1), chunk.constants.count);

    // Expect both code and constants arrays to be empty after free
    chunk.free(allocator);
    try std.testing.expectEqual(@as(usize, 0), chunk.code.len);
    try std.testing.expectEqual(@as(usize, 0), chunk.constants.values.len);
    try std.testing.expectEqual(@as(usize, 0), chunk.count);
    try std.testing.expectEqual(@as(usize, 0), chunk.constants.count);
}

test "chunk creation, writing and freeing doesn't crash" {
    const allocator = std.testing.allocator;
    var chunk: Chunk = undefined;

    // Try simply initing, writing a single value, and freeing
    chunk.init();
    try chunk.write(allocator, 1, 1);
    chunk.free(allocator);

    // Check that array growth happens as expected
    // And that the chunk contents equal the values being written
    for (1..14) |i| {
        try chunk.write(allocator, @as(u8, @truncate(i)), 1);
        if (i <= 8) {
            try std.testing.expectEqual(@as(usize, 8), chunk.code.len);
        } else {
            try std.testing.expectEqual(@as(usize, 16), chunk.code.len);
        }
        try std.testing.expect(chunk.code[i - 1] == i);
    }
    chunk.free(allocator);
    try std.testing.expectEqual(@as(usize, 0), chunk.code.len);
}
