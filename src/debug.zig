const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const num_op_codes = @import("chunk.zig").num_op_codes;

// @tagName to get name of enum
// @enumToInt to get int value of enum
// @intToEnum to get enum from int
pub fn disassemble_chunk(chunk: *Chunk, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.count) {
        offset = disassemble_instruction(chunk, offset);
    }
}

fn simple_instruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s:<12}\n", .{name});
    return offset + 1;
}

fn constant_instruction(name: []const u8, chunk: *Chunk, offset: usize) usize {
    const constant = chunk.code.?[offset + 1];
    std.debug.print("{s:<12} {d:0>4} ", .{ name, offset });
    std.debug.print("'{}'\n", .{constant});
    return offset + 2;
}

// Returns the passed offset plus the size of the instruction at the current offset
fn disassemble_instruction(chunk: *Chunk, offset: usize) usize {
    std.debug.print("{d:0>4} ", .{offset});
    if (offset > 0 and chunk.lines.?[offset] == chunk.lines.?[offset - 1]) {
        std.debug.print("   | ", .{});
    } else {
        std.debug.print("{d:0>4} ", .{chunk.lines.?[offset]});
    }

    // Check that instruction can be converted to enum before doing so
    const instruction = chunk.code.?[offset];
    if (instruction >= num_op_codes) {
        std.debug.print("Unknown opcode {d}\n", .{instruction});
        return offset + 1;
    }

    // TO match multiple, separate with comma: case1, case2, case3 =>
    const op_code = @intToEnum(OpCode, instruction);
    switch (op_code) {
        OpCode.OP_RETURN => {
            return simple_instruction(@tagName(op_code), offset);
        },
        OpCode.OP_CONSTANT => {
            return constant_instruction(@tagName(op_code), chunk, offset);
        },
    }
}
