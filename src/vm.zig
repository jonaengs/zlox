const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const ValueArray = @import("value.zig").ValueArray;
const values = @import("value.zig");
const debug = @import("debug.zig");
const std = @import("std");
const compiler = @import("compiler.zig");

const DEBUG_TRACE_EXECUTION = true;

// TODO: Make stack size dynamic?
const STACK_MAX = 256;
const VM = struct {
    chunk: *const Chunk,
    ip: [*]u8, // Instruction Pointer. Points to the *next* instruction (byte) to be used

    // TODO: Move stack_top before stack in the struct? Maybe better for locality
    stack: [STACK_MAX]Value,
    stack_top: [*]Value, // Points just past the element that's on top of the stack. If pointing to idx 0, the stack is empty
    // TODO: Pointing just past the last element of a full array is legal and well-specified in C. But what about in Zig?
};
pub const InterpretResult = enum { OK, COMPILE_ERROR, RUNTIME_ERROR };

var vm: VM = .{ .chunk = undefined, .ip = undefined, .stack = undefined, .stack_top = undefined };

pub fn interpret(source: []const u8) InterpretResult {
    compiler.compile(source);
    return InterpretResult.OK;
}

pub fn interpret_chunk(chunk: *const Chunk) InterpretResult {
    vm.chunk = chunk;
    vm.ip = vm.chunk.code.?.ptr;
    return run();
}

pub fn init_vm() void {
    reset_stack();
}
pub fn free_vm() void {}

/// PRIVATE FUNCS ///
fn reset_stack() void {
    vm.stack_top = &vm.stack;
}

fn push(value: Value) void {
    vm.stack_top[0] = value;
    vm.stack_top += 1;
}
fn pop() Value {
    vm.stack_top -= 1;
    return vm.stack_top[0];
}

// Two functions used for testing the stack:
// Get the top-most value on the stack
pub fn peek() Value {
    vm.stack_top -= 1;
    const top = vm.stack_top[0];
    vm.stack_top += 1;
    return top;
}
// Get the value at the stack_top, one ahead of where the top-most stack value lies
pub fn peek_ahead() Value {
    return vm.stack_top[0];
}

// TODO: This is a macro in the book. Make sure my implementation doesn't cause a performance degradation
inline fn binary_op(comptime op: u8) void {
    const b = pop().double;
    const a = pop().double;
    switch (op) {
        '+' => {
            push(Value{ .double = a + b });
        },
        '-' => {
            push(Value{ .double = a - b });
        },
        '*' => {
            push(Value{ .double = a * b });
        },
        '/' => {
            push(Value{ .double = a / b });
        },
        else => unreachable,
    }
}

inline fn read_byte() u8 {
    const byte = vm.ip[0];
    vm.ip += 1;
    return byte;
}

inline fn read_constant() Value {
    // Unsafe and unchecked access, so watch out for bugs
    return vm.chunk.constants.values.?[read_byte()];
}

fn print_stack() void {
    std.debug.print("          ", .{});
    var slot: [*]Value = &vm.stack;
    while (@ptrToInt(slot) < @ptrToInt(vm.stack_top)) : (slot += 1) {
        std.debug.print("[ ", .{});
        values.print_value(slot[0]);
        std.debug.print(" ]", .{});
    }
    std.debug.print("\n", .{});
}

// TODO: For performance, extract ip from the VM and put it in a local var, so it can reside in a register.
// Quote from the book (15.1 note): "If we were trying to squeeze every ounce of speed out of our bytecode interpreter, we would store ip in a local variable. It gets modified so often during execution that we want the C compiler to keep it in a register."
// Another performance TODO: Nystrom writes about speeding up the decoding/dispatching of instructions: "If you want to learn some of these techniques, look up “direct threaded code”, “jump table”, and “computed goto”."
// TODO: Check out other types of interpreters than stack-based ones.
fn run() InterpretResult {
    if (DEBUG_TRACE_EXECUTION) {
        std.debug.print("\n=== ENTERING VM ===\n", .{});
    }

    while (true) {
        if (DEBUG_TRACE_EXECUTION) {
            print_stack();
            {
                const offset = @ptrToInt(vm.ip) - @ptrToInt(vm.chunk.code.?.ptr);
                _ = debug.disassemble_instruction(vm.chunk, offset);
            }
        }

        // Assume invalid/unknown (out of range) instructions can never enter into the code
        const instruction = @intToEnum(OpCode, read_byte());
        switch (instruction) {
            OpCode.RETURN => {
                values.print_value(pop());
                std.debug.print("\n", .{});
                return InterpretResult.OK;
            },
            OpCode.CONSTANT => {
                const constant = read_constant();
                push(constant);
            },
            OpCode.NEGATE => {
                push(Value{ .double = -pop().double });
            },
            OpCode.ADD => {
                binary_op('+');
            },
            OpCode.SUBTRACT => {
                binary_op('-');
            },
            OpCode.MULTIPLY => {
                binary_op('*');
            },
            OpCode.DIVIDE => {
                binary_op('/');
            },
        }
    }
    return InterpretResult.OK;
}

test "push and pop" {
    reset_stack();
    push(Value{ .double = 3.14 });
    try std.testing.expectEqual(Value{ .double = 3.14 }, pop());
}

test "interpret simple chunk" {
    // Create a chunk
    var code = [_]u8{
        @enumToInt(OpCode.CONSTANT),
        0, // Index into constants
        @enumToInt(OpCode.NEGATE),
        @enumToInt(OpCode.RETURN),
    };
    var lines = [_]u32{ 1, 1, 1, 1 };
    var vals = [_]Value{Value{ .double = 3.14 }};
    const chunk = Chunk{
        .count = 2,
        .capacity = 8,
        .code = code[0..],
        .lines = lines[0..],
        .constants = ValueArray{ .count = 1, .capacity = 1, .values = vals[0..] },
    };

    init_vm();
    const result = interpret_chunk(&chunk);
    try std.testing.expectEqual(InterpretResult.OK, result);
}

test "binary operators" {
    push(Value{ .double = 2 });
    push(Value{ .double = 2 });
    binary_op('+');
    try std.testing.expectApproxEqAbs(@as(f64, 4), peek().double, 0.00001);

    push(Value{ .double = 2 });
    binary_op('-');
    try std.testing.expectApproxEqAbs(@as(f64, 2), peek().double, 0.00001);

    push(Value{ .double = 2 });
    binary_op('*');
    try std.testing.expectApproxEqAbs(@as(f64, 4), peek().double, 0.00001);

    push(Value{ .double = 2 });
    binary_op('/');
    try std.testing.expectApproxEqAbs(@as(f64, 2), peek().double, 0.00001);
}
