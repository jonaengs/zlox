const std = @import("std");

const Allocator = std.mem.Allocator;

pub inline fn grow_capacity(cap: usize) usize {
    return if (cap < 8) 8 else cap * 2;
}

pub inline fn grow_array(comptime T: type, allocator: Allocator, pointer: ?[]T, new_size: usize) ![]T {
    // TODO: Handle allocation failure
    // std.debug.print("Array size: {d}\n", .{new_size});
    if (pointer) |data| {
        // TODO: Try resize first, then realloc if it fails? Does resize automatically do this?
        return try allocator.realloc(data, new_size);
        // allocator.free(data);
        // return allocator.alloc(T, new_size);
    } else {
        return try allocator.alloc(T, new_size);
    }
}
