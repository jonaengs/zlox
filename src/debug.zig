const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;

pub fn dissasembleChunk(chunk: *Chunk, name: []const u8) void {
    std.debug.print("\n== {s} ==\n", .{name});

    // Loop over instructions and data in chunk and dissasemble individually
    var offset: usize = 0;
    while (offset < chunk.count) {
        offset = dissasembleInstruction(chunk, offset);
    }
}

fn dissasembleInstruction(chunk: *Chunk, offset: usize) usize {
    std.debug.print("{d:04} ", .{offset});

    // Safety check before this conversion is not really necessary because:
    // 1. Conversion should never fail
    // 2. The cast is safety-checked, so the program will fail with a proper error message and trace
    // 3. Our only real option if something goes wrong here is to crash, which we do
    const instruction = @as(OpCode, @enumFromInt(chunk.code[offset])); // renamed to "enumFromInt" in newer Zig versions

    switch (instruction) {
        OpCode.OP_RETURN => {
            return simpleInstruction(instruction, offset);
        },
        OpCode.OP_CONSTANT => {
            return constantInstruction(instruction, chunk, offset);
        },
    }
}

/// Instructions which take no arguments.
/// Prints name and increments offset.
fn simpleInstruction(instr: OpCode, offset: usize) usize {
    std.debug.print("{s:<16}\n", .{@tagName(instr)});
    return offset + 1;
}

fn constantInstruction(instr: OpCode, chunk: *Chunk, offset: usize) usize {
    const constant_idx = chunk.code[offset + 1]; // add 1 to skip opcode
    std.debug.print("{s:<16} {d:04} '", .{ @tagName(instr), constant_idx });
    printValue(chunk.constants.values[constant_idx]);
    std.debug.print("'\n", .{});
    return offset + 2;
}

fn printValue(val: Value) void {
    switch (val) {
        Value.double => |v| std.debug.print("{d}", .{v}),
        Value.boolean => |v| std.debug.print("{?}", .{v}),
    }
}

//
//
// TESTS
//

test "print chunk with constant" {
    const allocator = std.testing.allocator;
    var chunk: Chunk = undefined;

    chunk.init();
    defer chunk.free(allocator);

    const constant = try chunk.addConstant(allocator, Value{ .double = 1.2 });
    try chunk.write(allocator, @intFromEnum(OpCode.OP_CONSTANT));
    try chunk.write(allocator, constant);
    try chunk.write(allocator, @intFromEnum(OpCode.OP_RETURN));
    dissasembleChunk(&chunk, "TEST CONSTANT CHUNK");
}

test "print simple chunk" {
    const allocator = std.testing.allocator;
    var chunk: Chunk = undefined;

    // Try simply initing, writing a single value, and freeing
    chunk.init();
    defer chunk.free(allocator);

    try chunk.write(allocator, @intFromEnum(OpCode.OP_RETURN));
    try chunk.write(allocator, @intFromEnum(OpCode.OP_RETURN));
    dissasembleChunk(&chunk, "TEST CHUNK");
}
