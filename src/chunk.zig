const std = @import("std");

const Allocator = std.mem.Allocator;

const OpCode = enum { OP_RETURN };

// TODO: Does Zig have a built-in list type that offers this structure, but better?
pub const Chunk = struct {
    count: usize, // Num actual elements in chunk
    capacity: usize, // Num elements there's space allocated for in the chunk
    code: ?[]u8,
};

pub inline fn create_chunk() Chunk {
    var chunk = Chunk{ .count = undefined, .capacity = undefined, .code = undefined };
    init_chunk(&chunk);
    return chunk;
}

pub fn free_chunk(allocator: Allocator, chunk: *Chunk) void {
    // Free the data and set all fields to zero
    if (chunk.code) |data| {
        allocator.free(data);
    }
    init_chunk(chunk);
}

pub fn write_chunk(allocator: Allocator, chunk: *Chunk, byte: u8) void {
    // TODO: Handle allocation failure
    if (chunk.capacity <= chunk.count) {
        // const old_capacity = chunk.capacity;
        chunk.capacity = grow_capacity(chunk.capacity);
        chunk.code = grow_array(allocator, chunk.code, chunk.capacity) catch unreachable;
    }

    if (chunk.code) |data| {
        data[chunk.count] = byte;
        chunk.count += 1;
    } else {
        unreachable;
    }
}

//// PRIVATE FUNCTIONS BELOW ////

fn init_chunk(chunk: *Chunk) void {
    chunk.count = 0;
    chunk.capacity = 0;
    chunk.code = null;
}

inline fn grow_capacity(cap: usize) usize {
    return if (cap < 8) 8 else cap * 2;
}

inline fn grow_array(allocator: Allocator, pointer: ?[]u8, new_size: usize) ![]u8 {
    // TODO: Handle allocation failure
    // std.debug.print("Array size: {d}\n", .{new_size});
    if (pointer) |data| {
        // TODO: Try resize first, then realloc if it fails? Does resize automatically do this?
        return try allocator.realloc(data, new_size);
        // allocator.free(data);
        // return allocator.alloc(u8, new_size);
    } else {
        return try allocator.alloc(u8, new_size);
    }
}
