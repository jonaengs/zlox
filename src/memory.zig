//! Functions for dealing with allocation and deallocation of memory
const std = @import("std");
const Allocator = std.mem.Allocator;

/// Double the slice's length (and size), or set its length to 8 if shorter.
/// 'slice' parameter must be a slice
pub fn grow_array(allocator: Allocator, slice: anytype) !@TypeOf(slice) {
    const new_len = if (slice.len < 8) 8 else slice.len * 2;
    return try allocator.realloc(slice, new_len);
}

/// Free the given slice
pub fn free_array(allocator: Allocator, slice: anytype) void {
    return allocator.free(slice);
}

//
//
// TESTS
//

const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;

test "expected grow_array byte sizes for already allocated arrs" {
    const allocator = std.testing.allocator;

    // Test for u8/OpCode (size = 1 byte)
    {
        var slice = try allocator.alloc(u8, 8);
        slice = try grow_array(allocator, slice);
        defer free_array(allocator, slice);

        // Should grow to 16 items and 16 bytes
        try std.testing.expectEqual(@as(usize, 16), slice.len);
        try std.testing.expectEqual(@as(usize, 16), std.mem.sliceAsBytes(slice).len);
    }

    // Test for Value (size = 8 bytes)
    {
        var slice = try allocator.alloc(Value, 8);
        slice = try grow_array(allocator, slice);
        defer free_array(allocator, slice);

        // Should grow to contain 16 items.
        // Due to Value size being 16, this should give a byte size of 256
        try std.testing.expectEqual(@as(usize, 16), slice.len);
        try std.testing.expectEqual(@as(usize, 256), std.mem.sliceAsBytes(slice).len);
    }
}

test "expected grow_array byte sizes for empty arrs" {
    const allocator = std.testing.allocator;

    // Test for u8/OpCode (size = 1 byte)
    {
        var slice: []u8 = &.{};
        slice = try grow_array(allocator, slice);
        defer free_array(allocator, slice);

        // Should grow to 8 items and 8 bytes
        try std.testing.expectEqual(@as(usize, 8), slice.len);
        try std.testing.expectEqual(@as(usize, 8), std.mem.sliceAsBytes(slice).len);
    }

    // Test for Value (size = 8 bytes)
    {
        var slice: []Value = &.{};
        slice = try grow_array(allocator, slice);
        defer free_array(allocator, slice);

        // Should grow to contain 8 items.
        // Due to Value size being 8, this should give a byte size of 128
        try std.testing.expectEqual(@as(usize, 16), @sizeOf(Value));
        try std.testing.expectEqual(@as(usize, 8), slice.len);
        try std.testing.expectEqual(@as(usize, 128), std.mem.sliceAsBytes(slice).len);
    }
}
