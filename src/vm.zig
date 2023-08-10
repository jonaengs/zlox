//! The Virtual Machine. Implementation relies on Zig
//! treating files as structs. "Clients" will then do
//! const VM = import("vm.zig");
//! and treat the VM as a "singleton" struct.
//!
//! This matches the book, which also uses only a single VM struct for everything.

// IMPORTS
const std = @import("std");
const builtin = @import("builtin");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const debug = @import("debug.zig");

const DEBUG_TRACE_EXECUTION = @import("build_options").trace_execution and !builtin.is_test;
const STACK_MAX_SIZE = 256;

/// Errors returned by the VM interpreter.
const InterpreterError = error{
    CompileError,
    RuntimeError,
};

// STRUCT FIELDS
// Use indices instead of pointers because Zig really doesn't like pointer arithmetic. Consider changing if detrimental to performance.
var chunk: *Chunk = undefined; // Chunk currently being intepreted
var ip: usize = 0; // Instruction pointer for the chunk's code
var stack: [STACK_MAX_SIZE]Value = undefined;
var sp: u8 = 0; // Points one past the top element of the stack
// While the C standard allows pointing one past the end of an array, I'm not sure how Zig feels about it. I guess I'll find out soon enough.

pub fn init() void {
    resetStack();
}
pub fn free() void {}
pub fn interpret(arg_chunk: *Chunk) InterpreterError!void {
    chunk = arg_chunk;
    ip = 0;

    return run();
}

inline fn read_constant() Value {
    // here, ip points to the index of the value in the constants array
    ip += 1;
    return chunk.constants.values[chunk.code[ip - 1]];
}

inline fn read_instruction() OpCode {
    ip += 1;
    return @enumFromInt(chunk.code[ip - 1]);
}

pub fn run() InterpreterError!void {
    while (true) {
        if (DEBUG_TRACE_EXECUTION) {
            // Print the stack
            std.debug.print("          ", .{});
            for (stack[0..sp]) |value| {
                std.debug.print("[ {} ]", .{value});
            }
            std.debug.print("\n", .{});

            // Print the instruction
            _ = debug.dissasembleInstruction(chunk, ip);
            std.debug.print("\n", .{});
        }

        const instruction = read_instruction();
        switch (instruction) {
            .OP_CONSTANT => {
                const value = read_constant();
                push(value);
            },
            .OP_NEGATE => {
                // Could likely be optimized by simply modifying the value right on the stack (see challenge 15.4)
                const val = pop();
                std.debug.assert(val == Value.double); // TODO: Handle illegal negation more gracefully
                push(Value{ .double = -val.double });
            },
            .OP_ADD, .OP_SUBTRACT, .OP_MULTIPLY, .OP_DIVIDE => {
                // Only handle doubles for now
                const b = pop();
                const a = pop();
                std.debug.assert(b == Value.double);
                std.debug.assert(a == Value.double);
                // TODO: Get rid of nested switch
                push(Value{
                    .double = switch (instruction) {
                        .OP_ADD => a.double + b.double,
                        .OP_SUBTRACT => a.double - b.double,
                        .OP_MULTIPLY => a.double * b.double,
                        .OP_DIVIDE => a.double / b.double, // TODO: Handle division by zero?
                        else => unreachable, // actually unreachable
                    },
                });
            },
            .OP_RETURN => {
                const value = pop();
                // Needed because 'zig build test' behaves strangely on release 0.11, printing
                // errors when there are none (as well as omitting the test summary statistics)
                if (DEBUG_TRACE_EXECUTION) {
                    std.debug.print("{}\n", .{value});
                }
                return;
            },
        }
    }
}

fn resetStack() void {
    sp = 0;
}

fn push(value: Value) void {
    stack[sp] = value;
    sp += 1;
}

fn pop() Value {
    sp -= 1;
    return stack[sp];
}

//
//
// TESTS
//

test "simple stack operations" {
    const v1 = Value{ .double = 1.0 };
    const v2 = Value{ .double = 2.0 };
    const v3 = Value{ .double = 3.0 };

    resetStack();
    try std.testing.expectEqual(@as(u8, 0), sp);
    push(v1);
    push(v2);
    try std.testing.expectEqual(@as(u8, 2), sp);

    // Check popping
    try std.testing.expectEqual(Value{ .double = 2.0 }, pop());
    try std.testing.expectEqual(@as(u8, 1), sp);

    // Push after pop overwriting values
    push(v3);
    try std.testing.expectEqual(@as(u8, 2), sp);
    try std.testing.expectEqual(Value{ .double = 3.0 }, pop());
    _ = pop();
    try std.testing.expectEqual(@as(u8, 0), sp);
}
