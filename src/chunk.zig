const std = @import("std");
const mem = @import("memory.zig");
const values = @import("value.zig");

const ValueArray = values.ValueArray;

const Allocator = std.mem.Allocator;

pub const OpCode = enum(u8) { OP_RETURN, OP_CONSTANT };
pub const num_op_codes = std.enums.values(OpCode).len;

// TODO: Create a better API. Combine create_chunk and init_chunk.

// TODO: Does Zig have a built-in list type that offers this structure, but better?
pub const Chunk = struct {
    count: usize, // Num actual elements in chunk
    capacity: usize, // Num elements there's space allocated for in the chunk
    code: ?[]u8,
    constants: ValueArray,
};

pub inline fn create_chunk() Chunk {
    var chunk = Chunk{ .count = undefined, .capacity = undefined, .code = undefined, .constants = undefined };
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
    init_chunk(chunk);
}

pub fn write_chunk(allocator: Allocator, chunk: *Chunk, byte: u8) void {
    // TODO: Handle allocation failure
    if (chunk.capacity <= chunk.count) {
        // const old_capacity = chunk.capacity;
        chunk.capacity = mem.grow_capacity(chunk.capacity);
        chunk.code = mem.grow_array(u8, allocator, chunk.code, chunk.capacity) catch unreachable;
    }

    if (chunk.code) |data| {
        data[chunk.count] = byte;
        chunk.count += 1;
    } else {
        unreachable;
    }
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
    chunk.constants = values.create_value_array();
}
