const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const values = @import("value.zig");
const debug = @import("debug.zig");
const std = @import("std");

const DEBUG_TRACE_EXECUTION = true;

// TODO: Make stack size dynamic?
const STACK_MAX = 256;
const VM = struct {
    chunk: *Chunk,
    ip: [*]u8, // Instruction Pointer. Points to the *next* instruction (byte) to be used

    // TODO: Move stack_top before stack in the struct? Maybe better for locality
    stack: [STACK_MAX]Value,
    stack_top: [*]Value, // Points just past the element that's on top of the stack. If pointing to idx 0, the stack is empty
    // TODO: Pointing just past the last element of a full array is legal and well-specified in C. But what about in Zig?
};
const InterpretResult = enum { OK, COMPILE_ERROR, RUNTIME_ERROR };

var vm: VM = .{ .chunk = undefined, .ip = undefined, .stack = undefined, .stack_top = undefined };

pub fn interpret(chunk: *Chunk) InterpretResult {
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

inline fn read_byte() u8 {
    const byte = vm.ip[0];
    vm.ip += 1;
    return byte;
}

inline fn read_constant() Value {
    // Unsafe and unchecked access, so watch out for bugs
    return vm.chunk.constants.values.?[read_byte()];
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
            std.debug.print("          ", .{});
            var slot: [*]Value = &vm.stack;
            while (@ptrToInt(slot) < @ptrToInt(vm.stack_top)) : (slot += 1) {
                std.debug.print("[ ", .{});
                values.print_value(slot[0]);
                std.debug.print(" ]", .{});
            }
            std.debug.print("\n", .{});
            {
                const offset = @ptrToInt(vm.ip) - @ptrToInt(vm.chunk.code.?.ptr);
                _ = debug.disassemble_instruction(vm.chunk, offset);
            }
        }

        // Assume invalid/unknown (out of range) instructions can never enter into the code
        const instruction = @intToEnum(OpCode, read_byte());
        switch (instruction) {
            (OpCode.OP_RETURN) => {
                values.print_value(pop());
                std.debug.print("\n", .{});
                return InterpretResult.OK;
            },
            (OpCode.OP_CONSTANT) => {
                const constant = read_constant();
                push(constant);
            },
        }
    }
    return InterpretResult.OK;
}
