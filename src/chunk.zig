const std = @import("std");
const memory = @import("memory.zig");
const Value = @import("value.zig").Value;
const ValueArray = @import("value.zig").ValueArray;

pub const OpCode = enum(u8) {
    OP_RETURN,
    OP_CONSTANT,
};

/// Represents a portion (like a file?) of code
pub const Chunk = struct {
    // Drop 'capacity' because we use the fat-pointered Slice type
    count: usize,
    code: []u8,
    constants: ValueArray,
    lines: []usize, // line number of each item in self.code
    // Better line encodings: 1. delta encoding with u8  2. only store line changes (array of offsets and their line)

    pub fn init(self: *Chunk) void {
        self.count = 0;
        self.code = &.{};
        self.lines = &.{};
        self.constants.init();
    }

    pub fn write(
        self: *Chunk,
        allocator: std.mem.Allocator,
        byte: u8,
        line: usize,
    ) !void {
        if (self.code.len < self.count + 1) {
            self.code = try memory.grow_array(allocator, self.code);
            self.lines = try memory.grow_array(allocator, self.lines);
        }
        self.code[self.count] = byte;
        self.lines[self.count] = line;
        self.count += 1;
    }

    pub fn free(self: *Chunk, allocator: std.mem.Allocator) void {
        memory.free_array(allocator, self.code);
        memory.free_array(allocator, self.lines);
        self.constants.free(allocator);

        // Make sure to not call init before all allocated memory has been freed
        self.init();
    }

    /// Store a constant value to the Chunk's ValueArray and return the value's index in that array
    pub fn addConstant(self: *Chunk, allocator: std.mem.Allocator, value: Value) !u8 {
        try self.constants.write(allocator, value);
        if (self.constants.count <= std.math.maxInt(u8)) {
            return @intCast(self.constants.count - 1);
        }
        // TODO: Handle this case (see chapter 14 challenge 2)
        unreachable;
    }
};
