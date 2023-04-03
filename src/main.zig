const std = @import("std");
const chunks = @import("chunk.zig");
const debug = @import("debug.zig");

pub fn main() !void {
    // Setup allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    // Setup a chunk
    var chunk = chunks.create_chunk();
    defer {
        chunks.free_chunk(gpa, &chunk);
    }

    // Write some stuff to the chunk
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.OP_RETURN));
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.OP_RETURN));
    chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.OP_RETURN));

    // Test the debug functionality
    debug.disassemble_chunk(&chunk, "Test Chunk");
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
    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        chunks.write_chunk(gpa, &chunk, @enumToInt(chunks.OpCode.OP_RETURN));
    }

    // Check that code behaves as expected
    try std.testing.expectEqual(@as(usize, 100), chunk.count);
    try std.testing.expectEqual(@as(usize, 128), chunk.capacity);
    try std.testing.expectEqual(@as(usize, 128), chunk.code.?.len);

    debug.disassemble_chunk(&chunk, "Test");
}
