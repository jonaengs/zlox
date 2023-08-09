const std = @import("std");
const memory = @import("memory.zig");

const OpCode = enum(u8) {
    OP_RETURN,
};

pub const Chunk = struct {
    count: usize,
    code: []u8,
    // Drop 'capacity' because we use the fat-pointered Slice type

    pub fn init(self: *Chunk) void {
        self.count = 0;
        self.code = &.{}; // Accessing this would obviously be terrible
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
        self.init();
    }
};
