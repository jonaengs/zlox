const std = @import("std");
const mem = @import("memory.zig");

const Allocator = std.mem.Allocator;

pub const ValuesTag = enum {
    double,
};
pub const Value = union(ValuesTag) {
    double: f64,
};
pub const ValueArray = struct {
    capacity: usize,
    count: usize,
    values: ?[]Value,
};

pub fn write_value_array(allocator: Allocator, value_array: *ValueArray, value: Value) void {
    // TODO: Handle allocation failure
    if (value_array.capacity <= value_array.count) {
        value_array.capacity = mem.grow_capacity(value_array.capacity);
        value_array.values = mem.grow_array(Value, allocator, value_array.values, value_array.capacity) catch unreachable;
    }

    value_array.values.?[value_array.count] = value;
    value_array.count += 1;
}

pub inline fn create_value_array() ValueArray {
    var value_array = ValueArray{ .count = undefined, .capacity = undefined, .values = undefined };
    init_value_array(&value_array);
    return value_array;
}

pub fn free_value_array(allocator: Allocator, value_array: *ValueArray) void {
    // Free the data and set all fields to zero
    if (value_array.values) |data| {
        allocator.free(data);
    }
    init_value_array(value_array);
}

//// PRIVATE FUNCTIONS BELOW ////

fn init_value_array(value_array: *ValueArray) void {
    value_array.count = 0;
    value_array.capacity = 0;
    value_array.values = null;
}
