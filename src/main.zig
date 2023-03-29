const std = @import("std");
const chunks = @import("chunk.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    var chunk = chunks.create_chunk();
    chunks.init_chunk(&chunk);

    chunks.write_chunk(gpa, &chunk, 1);

    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        chunks.write_chunk(gpa, &chunk, 1);
    }
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
        chunks.write_chunk(gpa, &chunk, 1);
    }

    // Check that code behaves as expected
    try std.testing.expectEqual(@as(usize, 100), chunk.count);
    try std.testing.expectEqual(@as(usize, 128), chunk.capacity);
    try std.testing.expectEqual(@as(usize, 128), chunk.code.?.len);
}
