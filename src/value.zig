//! Representation of constant values encountered in a program
const std = @import("std");
const memory = @import("memory.zig");

// Make Value a tagged union early, as we will have to do so later anyways,
// and this will remove the need for a lot type-trickery that
// would otherwise be needed to make the code look good
pub const Value = union(enum) {
    boolean: bool,
    double: f64,
};

pub const ValueArray = struct {
    count: usize,
    values: []Value,

    pub fn init(self: *ValueArray) void {
        self.count = 0;
        self.values = &.{};
    }

    pub fn write(self: *ValueArray, allocator: std.mem.Allocator, value: Value) !void {
        if (self.values.len < self.count + 1) {
            self.values = try memory.grow_array(allocator, self.values);
        }
        self.values[self.count] = value;
        self.count += 1;
    }

    pub fn free(self: *ValueArray, allocator: std.mem.Allocator) void {
        memory.free_array(allocator, self.values);
        self.init();
    }
};
