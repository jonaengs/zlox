const std = @import("std");
const chunks = @import("chunk.zig");
const values = @import("value.zig");
const debug = @import("debug.zig");
const vm = @import("vm.zig");

pub fn main() !void {
    // Setup allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    vm.init_vm();
    defer vm.free_vm();

    // Setup a chunk
    var chunk = chunks.create_chunk();
    defer {
        chunks.free_chunk(gpa, &chunk);
    }

    // Write some stuff to the chunk
    const constant = chunks.add_constant(gpa, &chunk, values.Value{ .double = 1.2 });
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.OP_CONSTANT), 111);
    chunks.write_chunk(gpa, &chunk, constant, 111);

    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.OP_RETURN), 112);

    // Test the debug functionality
    debug.disassemble_chunk(&chunk, "Test Chunk");

    // Run the chunk in the VM
    _ = vm.interpret(&chunk);
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
    while (i < 100) : (i += 1) {
        chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.OP_RETURN), i);
    }

    // Check that code behaves as expected
    try std.testing.expectEqual(@as(usize, 100), chunk.count);
    try std.testing.expectEqual(@as(usize, 128), chunk.capacity);
    try std.testing.expectEqual(@as(usize, 128), chunk.code.?.len);

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
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.OP_CONSTANT), 1);
    chunks.write_chunk(gpa, &chunk, value_array_idx_1, 1);

    const value_array_idx_2 = chunks.add_constant(gpa, &chunk, values.Value{ .double = 2.0 });
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.OP_CONSTANT), 1);
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
