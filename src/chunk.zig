const std = @import("std");
const mem = @import("memory.zig");
const values = @import("value.zig");

const ValueArray = values.ValueArray;

// TODO: Use arena allocator for chunks?
// Arena: A dynamic series of fixed-size bump allocators.
// Should make growing all our arrays very quick.
// Problem: Realloc should always be in-place, but can we guarantee this?
// What about a slab allocator?
const Allocator = std.mem.Allocator;

pub const OpCode = enum(u8) {
    RETURN,
    CONSTANT,
    NEGATE,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
};
pub const num_op_codes = std.enums.values(OpCode).len;

// TODO: Create a better API. Combine create_chunk and init_chunk.
// TODO: Can we make it so that Chunks without allocated code and lines is impossible to create?
// Then, we could remove the optional from these fields, and simplify the code.

// TODO: Does Zig have a built-in list type that offers this structure, but better?
pub const Chunk = struct {
    count: usize, // Num actual elements in chunk
    capacity: usize, // Num elements there's space allocated for in the chunk
    code: ?[]u8,
    lines: ?[]u32, // lines is step-locked with code.
    constants: ValueArray,
};

pub inline fn create_chunk() Chunk {
    var chunk = Chunk{ .count = undefined, .capacity = undefined, .code = undefined, .constants = undefined, .lines = undefined };
    init_chunk(&chunk);
    return chunk;
}

pub fn free_chunk(allocator: Allocator, chunk: *Chunk) void {
    // Free sub-structures
    values.free_value_array(allocator, &chunk.constants);

    // Free the data and set all fields to zero
    if (chunk.code) |data| {
        allocator.free(data);
    }
    if (chunk.lines) |data| {
        allocator.free(data);
    }
    init_chunk(chunk);
}

pub fn write_chunk(allocator: Allocator, chunk: *Chunk, byte: u8, line: u32) void {
    // TODO: Handle allocation failure
    if (chunk.capacity <= chunk.count) {
        // const old_capacity = chunk.capacity;
        chunk.capacity = mem.grow_capacity(chunk.capacity);
        chunk.code = mem.grow_array(u8, allocator, chunk.code, chunk.capacity) catch unreachable;
        chunk.lines = mem.grow_array(u32, allocator, chunk.lines, chunk.capacity) catch unreachable;
    }

    chunk.code.?[chunk.count] = byte;
    chunk.lines.?[chunk.count] = line;
    chunk.count += 1;
}

pub fn add_constant(allocator: Allocator, chunk: *Chunk, value: values.Value) u8 {
    values.write_value_array(allocator, &chunk.constants, value);

    // TODO: Handle usize to u8 better. Maybe make ValueArray use u8
    if (chunk.constants.count > std.math.maxInt(u8)) unreachable;

    // Because write_value_array always adds at least one to count, we know
    // that this subtraction can't cause underflow
    return @intCast(u8, chunk.constants.count - 1);
}
//// PRIVATE FUNCTIONS BELOW ////

fn init_chunk(chunk: *Chunk) void {
    chunk.count = 0;
    chunk.capacity = 0;
    chunk.code = null;
    chunk.lines = null;
    chunk.constants = values.create_value_array();
}
