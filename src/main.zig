const std = @import("std");
const chunks = @import("chunk.zig");
const values = @import("value.zig");
const debug = @import("debug.zig");
const vm = @import("vm.zig");

fn repl() !void {
    const stdin = std.io.getStdIn().reader();
    var buffer: [1024]u8 = undefined;
    while (true) {
        std.debug.print("> ", .{});

        // If only input is EOF, end REPL
        const bytes_read = try stdin.readAll(&buffer);
        if (bytes_read == 0) {
            std.debug.print("\n", .{});
            break;
        }
        intepret(buffer[0..]);
    }
}

fn read_file(allocator: Allocator, path: []const u8) ![]const u8 {
    const cwd = std.fs.cwd();
    std.debug.print("{s}\n", .{path});
    std.debug.print("{}\n", .{cwd});
    const file = try cwd.openFile(path, .{});

    const fsize = try file.getEndPos();
    std.debug.print("{}\n", .{fsize});

    var buffer = try allocator.alloc(u8, fsize);
    errdefer {
        allocator.free(buffer);
    }

    // TODO: Why isn't ReadError automatically returned if readall fails?
    // It must be returned manually for some reason.
    const bytes_read = try file.readAll(buffer);
    if (bytes_read < fsize) {
        std.debug.print("{}, {}\n", .{ fsize, bytes_read });
        return error.ReadError;
    }

    std.debug.print("\n==== FILE BEGIN ====\n", .{});
    std.debug.print("{s}\n", .{buffer});
    std.debug.print("==== FILE END ====\n", .{});

    return buffer;
}

fn run_file(allocator: Allocator, path: []const u8) !void {
    // TODO: Move error handling into read_file
    if (read_file(allocator, path)) |source| {
        const result = vm.interpret(source);
        _ = result;

        allocator.free(source);
    } else |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("\nERROR: Could not find file: {s}.\n", .{path});
            std.os.exit(74);
        },
        error.OutOfMemory => {
            std.debug.print("\nERROR: Not enough memory to read: {s}.\n", .{path});
            std.os.exit(74);
        },
        error.ReadError => {
            std.debug.print("\nERROR: Could not read file: {s}.\n", .{path});
            std.os.exit(74);
        },
        else => {
            return err;
        },
    }
}

pub fn main() !void {
    // Setup allocator

    vm.init_vm();
    defer vm.free_vm();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);
    for (args) |arg, i| {
        std.debug.print("{}: {s}\n", .{ i, arg });
    }
    if (args.len == 1) {
        try repl();
    } else if (args.len == 2) {
        try run_file(gpa, args[1]);
    } else {
        std.debug.print("Usage: zlox [path]\n", .{});
        std.process.exit(64);
    }
}

test "evalaute binary operations" {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    vm.init_vm();
    defer vm.free_vm();
    var chunk = chunks.create_chunk();
    defer chunks.free_chunk(gpa, &chunk);

    { // Add 2.2 to stack
        const constant = chunks.add_constant(gpa, &chunk, values.Value{ .double = 2.2 });
        chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.CONSTANT), 123);
        chunks.write_chunk(gpa, &chunk, constant, 123);
    }
    { // Add 3.4 to stack
        const constant = chunks.add_constant(gpa, &chunk, values.Value{ .double = 3.4 });
        chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.CONSTANT), 123);
        chunks.write_chunk(gpa, &chunk, constant, 123);
    }

    // Add the two numbers
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.ADD), 123);

    { // Add 5.6 to the stack
        const constant = chunks.add_constant(gpa, &chunk, values.Value{ .double = 5.6 });
        chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.CONSTANT), 123);
        chunks.write_chunk(gpa, &chunk, constant, 123);
    }
    // Divide the two numbers
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.DIVIDE), 123);
    // Negate the result
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.NEGATE), 123);
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.RETURN), 123);

    try std.testing.expectEqual(vm.InterpretResult.OK, vm.interpret_chunk(&chunk));
    // VM is technically empty after we return (and thus pop) the only stack value, but
    // the value still resides on the stack, and we can still view it.
    try std.testing.expectApproxEqAbs(@as(f64, -1), vm.peek_ahead().double, 0.00001);
}

test "simple vm" {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    vm.init_vm();
    defer vm.free_vm();
    var chunk = chunks.create_chunk();
    defer chunks.free_chunk(gpa, &chunk);

    // Write const value
    const constant = chunks.add_constant(gpa, &chunk, values.Value{ .double = 1.2 });
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.CONSTANT), 111);
    chunks.write_chunk(gpa, &chunk, constant, 111);

    // Negate the value
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.NEGATE), 111);

    // Return the negated value
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.RETURN), 112);

    // Run the chunk in the VM
    const result = vm.interpret_chunk(&chunk);
    try std.testing.expectEqual(vm.InterpretResult.OK, result);
}

test "chunk allocation" {
    // Setup allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    // Setup a chunk
    var chunk = chunks.create_chunk();
    defer {
        chunks.free_chunk(gpa, &chunk);
    }

    // Insert 100 items into the chunk
    var i: u32 = 0;
    while (i < 30) : (i += 1) {
        chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.RETURN), i / 5);
    }

    // Check that code behaves as expected
    try std.testing.expectEqual(@as(usize, 30), chunk.count);
    try std.testing.expectEqual(@as(usize, 32), chunk.capacity);
    try std.testing.expectEqual(@as(usize, 32), chunk.code.?.len);

    debug.disassemble_chunk(&chunk, "Test");
}

test "chunk add constant" {
    // Setup allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    // Setup a chunk
    var chunk = chunks.create_chunk();
    defer {
        chunks.free_chunk(gpa, &chunk);
    }

    const value_array_idx_1 = chunks.add_constant(gpa, &chunk, values.Value{ .double = 1.0 });
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.CONSTANT), 1);
    chunks.write_chunk(gpa, &chunk, value_array_idx_1, 1);

    const value_array_idx_2 = chunks.add_constant(gpa, &chunk, values.Value{ .double = 2.0 });
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.CONSTANT), 1);
    chunks.write_chunk(gpa, &chunk, value_array_idx_2, 1);

    debug.disassemble_chunk(&chunk, "Constant");
}

test "chunk add constant direct" {
    // Setup allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    // Setup a chunk
    var chunk = chunks.create_chunk();
    defer {
        chunks.free_chunk(gpa, &chunk);
    }

    const value_array_idx_1 = chunks.add_constant(gpa, &chunk, values.Value{ .double = 1.0 });
    const value_array_idx_2 = chunks.add_constant(gpa, &chunk, values.Value{ .double = 1.0 });
    try std.testing.expectEqual(@as(usize, 0), value_array_idx_1);
    try std.testing.expectEqual(@as(usize, 1), value_array_idx_2);

    debug.disassemble_chunk(&chunk, "Constant Direct");
}

test "value array allocation" {
    // Setup allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    // Setup a chunk
    var val_arr = values.create_value_array();
    defer {
        values.free_value_array(gpa, &val_arr);
    }

    // Insert 100 items into the chunk
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        values.write_value_array(gpa, &val_arr, values.Value{ .double = 1.0 });
    }

    // Check that code behaves as expected
    try std.testing.expectEqual(@as(usize, 100), val_arr.count);
    try std.testing.expectEqual(@as(usize, 128), val_arr.capacity);
    try std.testing.expectEqual(@as(usize, 128), val_arr.values.?.len);
}

test "value array value types" {
    // Setup allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    // Setup a chunk
    var val_arr = values.create_value_array();
    defer {
        values.free_value_array(gpa, &val_arr);
    }

    // Insert all different allowed types
    values.write_value_array(gpa, &val_arr, values.Value{ .double = 1.0 });
}
