const std = @import("std");
const memory = @import("memory.zig");
const Value = @import("value.zig").Value;
const ValueArray = @import("value.zig").ValueArray;

pub const OpCode = enum(u8) {
    OP_RETURN,
    OP_CONSTANT,
};

pub const Chunk = struct {
    count: usize,
    // Drop 'capacity' because we use the fat-pointered Slice type
    code: []u8,
    constants: ValueArray,

    pub fn init(self: *Chunk) void {
        self.count = 0;
        self.code = &.{}; // Accessing this would obviously be terrible
        self.constants.init();
    }

    pub fn write(self: *Chunk, allocator: std.mem.Allocator, byte: u8) !void {
        if (self.code.len < self.count + 1) {
            self.code = try memory.grow_array(allocator, self.code);
        }
        self.code[self.count] = byte;
        self.count += 1;
    }

    pub fn free(self: *Chunk, allocator: std.mem.Allocator) void {
        memory.free_array(allocator, self.code);
        self.constants.free(allocator);
        self.init();
    }

    /// Store a constant value to the Chunk's ValueArray and return the value's index in that array
    pub fn addConstant(self: *Chunk, allocator: std.mem.Allocator, value: Value) !u8 {
        try self.constants.write(allocator, value);
        if (self.constants.count <= std.math.maxInt(u8)) {
            return @intCast(self.constants.count - 1);
        }
        // TODO: Handle this case
        unreachable;
    }
};
