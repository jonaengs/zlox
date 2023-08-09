const std = @import("std");
const Allocator = std.mem.Allocator;

/// Double the slice's length (and size), or set its length to 8 if shorter.
/// 'slice' parameter must be a slice
pub fn grow_array(allocator: Allocator, slice: anytype) !@TypeOf(slice) {
    const new_len = if (slice.len < 8) 8 else slice.len * 2;
    const slice_element_type = @typeInfo(@TypeOf(slice)).Pointer.child;
    const new_size = new_len * @sizeOf(slice_element_type);

    return try allocator.realloc(slice, new_size);
}

/// Free the given slice
pub fn free_array(allocator: Allocator, slice: anytype) void {
    return allocator.free(slice);
}
