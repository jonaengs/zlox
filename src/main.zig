const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const VM = @import("vm.zig");

fn repl() !void {
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
        try VM.interpret(buffer[0..bytes_read :0]);
    }
}

/// Reads complete files contents into a dynamically allocated buffer
/// and returns the buffer (and ownership of it) to the caller.
fn readFile(allocator: std.mem.Allocator, path: []const u8) ![:0]const u8 {
    const data = try std.fs.cwd().readFileAllocOptions(
        allocator,
        path,
        std.math.maxInt(usize), // Max buffer size in bytes
        null, // size hint
        8, // comptime alignment
        0, // sentinel value
    );
    return data;
}

fn runFile(allocator: std.mem.Allocator, path: []const u8) void {
    var source: [:0]const u8 = undefined;
    if (readFile(allocator, path)) |data| {
        source = data;
        defer allocator.free(source);
    } else |err| {
        switch (err) {
            error.FileNotFound => {
                std.debug.print("\nERROR: Could not find file: {s}.\n", .{path});
            },
            error.OutOfMemory => {
                std.debug.print("\nERROR: Not enough memory to read: {s}.\n", .{path});
            },
            else => |other_err| {
                std.debug.print("\nERROR: Other I/O error ({}): {s}.\n", .{ other_err, path });
            },
        }
        std.os.exit(74);
    }

    VM.interpret(source) catch |err| switch (err) {
        error.CompileError => std.process.exit(65),
        error.RuntimeError => std.process.exit(70),
    };
}

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; // If memory leaks, add "verbose_log = true" to config
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok); // deinit calls detectleaks() in .Debug and .ReleaseSafe modes

    VM.init(allocator);
    defer VM.free();

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len == 1) {
        try repl();
    } else if (args.len == 2) {
        runFile(allocator, args[1]);
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
