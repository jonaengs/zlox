const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const VM = @import("vm.zig");

pub fn main() !void {
    // Setup allocator
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = allocator.allocator();

    // Begin actual program
    VM.init();

    var chunk: Chunk = undefined;
    chunk.init();
    defer chunk.free(gpa);
    defer VM.free();

    // Push 1 to the stack
    var constant: u8 = try chunk.addConstant(gpa, Value{ .double = 1.0 });
    try chunk.write(gpa, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(gpa, constant, 1);

    // Evaluate -( -(1.2) + (-3.4) )
    constant = try chunk.addConstant(gpa, Value{ .double = 1.2 });
    try chunk.write(gpa, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(gpa, constant, 1);
    try chunk.write(gpa, @intFromEnum(OpCode.OP_NEGATE), 1);

    constant = try chunk.addConstant(gpa, Value{ .double = -3.4 });
    try chunk.write(gpa, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(gpa, constant, 1);

    try chunk.write(gpa, @intFromEnum(OpCode.OP_ADD), 1);
    try chunk.write(gpa, @intFromEnum(OpCode.OP_NEGATE), 1);

    // Return 1 * (ans / 4.6)
    constant = try chunk.addConstant(gpa, Value{ .double = 4.6 });
    try chunk.write(gpa, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(gpa, constant, 1);

    try chunk.write(gpa, @intFromEnum(OpCode.OP_DIVIDE), 1);
    try chunk.write(gpa, @intFromEnum(OpCode.OP_MULTIPLY), 1);
    try chunk.write(gpa, @intFromEnum(OpCode.OP_RETURN), 1);

    // Execute
    try VM.interpret(&chunk);
}

//
//
// TESTS
//

test "simple arithmetic doesn't crash" {
    // Setup
    const gpa = std.testing.allocator;
    VM.init();
    var chunk: Chunk = undefined;
    chunk.init();
    defer chunk.free(gpa);
    defer VM.free();

    // Push 1 to the stack
    var constant: u8 = try chunk.addConstant(gpa, Value{ .double = 1.0 });
    try chunk.write(gpa, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(gpa, constant, 1);

    // Evaluate -( -(1.2) + (-3.4) )
    constant = try chunk.addConstant(gpa, Value{ .double = 1.2 });
    try chunk.write(gpa, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(gpa, constant, 1);
    try chunk.write(gpa, @intFromEnum(OpCode.OP_NEGATE), 1);

    constant = try chunk.addConstant(gpa, Value{ .double = -3.4 });
    try chunk.write(gpa, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(gpa, constant, 1);

    try chunk.write(gpa, @intFromEnum(OpCode.OP_ADD), 1);
    try chunk.write(gpa, @intFromEnum(OpCode.OP_NEGATE), 1);

    // Return 1 * (ans / 4.6)
    constant = try chunk.addConstant(gpa, Value{ .double = 4.6 });
    try chunk.write(gpa, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(gpa, constant, 1);

    try chunk.write(gpa, @intFromEnum(OpCode.OP_DIVIDE), 1);
    try chunk.write(gpa, @intFromEnum(OpCode.OP_MULTIPLY), 1);
    try chunk.write(gpa, @intFromEnum(OpCode.OP_RETURN), 1);

    // Execute
    try VM.interpret(&chunk);

    try std.testing.expectEqual(@as(f64, 1), 1.0);
}

test "add constant doesn't crash" {
    const allocator = std.testing.allocator;
    var chunk: Chunk = undefined;
    chunk.init();

    const constant = try chunk.addConstant(allocator, Value{ .double = 1.2 });
    try chunk.write(allocator, @intFromEnum(OpCode.OP_CONSTANT), 1);
    try chunk.write(allocator, constant, 1);

    // Expect to see the instruction first
    try std.testing.expect(@as(OpCode, @enumFromInt(chunk.code[0])) == OpCode.OP_CONSTANT);
    // then the index
    try std.testing.expectEqual(@as(usize, 0), chunk.code[1]);
    // Expect the index to lead to the correct value
    try std.testing.expectEqual(@as(f64, 1.2), chunk.constants.values[0].double);

    // Expect both code and constants arrays to have length 8 before free
    try std.testing.expectEqual(@as(usize, 8), chunk.code.len);
    try std.testing.expectEqual(@as(usize, 8), chunk.constants.values.len);
    try std.testing.expectEqual(@as(usize, 2), chunk.count);
    try std.testing.expectEqual(@as(usize, 1), chunk.constants.count);

    // Expect both code and constants arrays to be empty after free
    chunk.free(allocator);
    try std.testing.expectEqual(@as(usize, 0), chunk.code.len);
    try std.testing.expectEqual(@as(usize, 0), chunk.constants.values.len);
    try std.testing.expectEqual(@as(usize, 0), chunk.count);
    try std.testing.expectEqual(@as(usize, 0), chunk.constants.count);
}

test "chunk creation, writing and freeing doesn't crash" {
    const allocator = std.testing.allocator;
    var chunk: Chunk = undefined;

    // Try simply initing, writing a single value, and freeing
    chunk.init();
    try chunk.write(allocator, 1, 1);
    chunk.free(allocator);

    // Check that array growth happens as expected
    // And that the chunk contents equal the values being written
    for (1..14) |i| {
        try chunk.write(allocator, @as(u8, @truncate(i)), 1);
        if (i <= 8) {
            try std.testing.expectEqual(@as(usize, 8), chunk.code.len);
        } else {
            try std.testing.expectEqual(@as(usize, 16), chunk.code.len);
        }
        try std.testing.expect(chunk.code[i - 1] == i);
    }
    chunk.free(allocator);
    try std.testing.expectEqual(@as(usize, 0), chunk.code.len);
}
