const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;

pub fn main() !void {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = allocator.allocator();

    var chunk: Chunk = undefined;
    chunk.init();
    try chunk.write(gpa, 1);
    chunk.free(gpa);
}

//
//
// TESTS
//

test "chunk creation, writing and freeing doesn't crash" {
    const allocator = std.testing.allocator;
    var chunk: Chunk = undefined;

    // Try simply initing, writing a single value, and freeing
    chunk.init();
    try chunk.write(allocator, 1);
    chunk.free(allocator);

    // Check that array growth happens as expected
    // And that the chunk contents equal the values being written
    for (1..14) |i| {
        try chunk.write(allocator, @truncate(u8, i));
        if (i <= 8) {
            try std.testing.expect(chunk.code.len == 8);
        } else {
            try std.testing.expect(chunk.code.len == 16);
        }
        try std.testing.expect(chunk.code[i - 1] == i);
    }
    chunk.free(allocator);
    try std.testing.expect(chunk.code.len == 0);
}
