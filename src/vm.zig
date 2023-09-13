//! The Virtual Machine. Implementation relies on Zig
//! treating files as structs. "Clients" will then do
//! const VM = import("vm.zig");
//! and treat the VM as a "singleton" struct -- i.e., we don't use fields
//! but instead use members belonging to the struct declaration itself.
//!
//! This matches the book, which also uses only a single VM struct for everything.

// IMPORTS
const std = @import("std");
const builtin = @import("builtin");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const debug = @import("debug.zig");
const compiler = @import("compiler.zig");

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
pub fn interpret(allocator: std.mem.Allocator, source: [:0]const u8) InterpreterError!void {
    var _chunk: Chunk = undefined;
    _chunk.init();
    defer _chunk.free(allocator);

    // Translate source into VM instructions
    try compiler.compile(allocator, source, &_chunk);

    // Bind chunk to VM
    chunk = &_chunk;
    ip = 0;

    // Execute chunk
    try run();
}

pub fn interpretChunk(arg_chunk: *Chunk) InterpreterError!void {
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
            .OP_NIL => {
                push(Value{ .nil = 0.0 });
            },
            .OP_TRUE => {
                push(Value{ .boolean = true });
            },
            .OP_FALSE => {
                push(Value{ .boolean = false });
            },
            .OP_EQUAL => {
                const b = pop();
                const a = pop();
                // std.meta.eql should first compare tags, then values if tags equal (https://github.com/ziglang/zig/issues/2251#issuecomment-1476915212)
                // Comparing bits directly is not a good idea. See final part of chapter 18 for why
                push(Value{ .boolean = std.meta.eql(a, b) });
            },
            .OP_NEGATE => {
                // Could likely be optimized by simply modifying the value right on the stack (see challenge 15.4)
                const val = peek(0);
                if (val != Value.number) {
                    runtimeError("Operand of negation must be a number.", .{});
                    return InterpreterError.RuntimeError;
                }
                push(Value{ .number = -pop().number });
            },
            .OP_NOT => {
                push(Value{ .boolean = isFalsey(pop()) });
            },
            .OP_ADD, .OP_SUBTRACT, .OP_MULTIPLY, .OP_DIVIDE, .OP_GREATER, .OP_LESS => {
                // TODO: Get rid of nested switch: Extract logic into a function.
                // Pass operator as enum. Inside function do a comptime switch on operator.
                // And make function inline.
                if (peek(0) != Value.number or peek(1) != Value.number) {
                    runtimeError("Operands must be numbers.", .{});
                    return InterpreterError.RuntimeError;
                }
                const b = pop();
                const a = pop();
                push(
                    switch (instruction) {
                        .OP_ADD => Value{ .number = a.number + b.number },
                        .OP_SUBTRACT => Value{ .number = a.number - b.number },
                        .OP_MULTIPLY => Value{ .number = a.number * b.number },
                        .OP_DIVIDE => Value{ .number = a.number / b.number }, // TODO: Handle division by zero?
                        .OP_GREATER => Value{ .boolean = a.number > b.number },
                        .OP_LESS => Value{ .boolean = a.number < b.number },
                        else => unreachable, // actually unreachable
                    },
                );
            },
            .OP_RETURN => {
                const value = pop();
                // Needed because 'zig build test' behaves strangely on release 0.11, printing
                // errors when there are none (as well as omitting the test summary statistics)
                if (DEBUG_TRACE_EXECUTION) {
                    std.debug.print("RETURN:\n{}\n", .{value});
                }
                return;
            },
        }
    }
}

fn isFalsey(val: Value) bool {
    return val == Value.nil or (val == Value.boolean and !val.boolean);
}

/// Takes a format string and the arguments to the format
/// (as an anonymous struct)
fn runtimeError(comptime format: []const u8, fargs: anytype) void {
    std.debug.print(format, fargs);
    std.debug.print("\n", .{});

    const instruction = ip - 1;
    const line = chunk.lines[instruction];
    std.debug.print("[line {d}] in script\n", .{line});
    resetStack();
}

fn peek(distance: usize) Value {
    return stack[sp - 1 - distance];
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
    const v1 = Value{ .number = 1.0 };
    const v2 = Value{ .number = 2.0 };
    const v3 = Value{ .number = 3.0 };

    resetStack();
    try std.testing.expectEqual(@as(u8, 0), sp);
    push(v1);
    push(v2);
    try std.testing.expectEqual(@as(u8, 2), sp);

    // Check popping
    try std.testing.expectEqual(Value{ .number = 2.0 }, pop());
    try std.testing.expectEqual(@as(u8, 1), sp);

    // Push after pop overwriting values
    push(v3);
    try std.testing.expectEqual(@as(u8, 2), sp);
    try std.testing.expectEqual(Value{ .number = 3.0 }, pop());
    _ = pop();
    try std.testing.expectEqual(@as(u8, 0), sp);
}
