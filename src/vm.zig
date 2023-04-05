const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const debug = @import("debug.zig");
const std = @import("std");

const debug_trace_execution = true;

const VM = struct {
    chunk: *Chunk,
    ip: [*]u8, // Instruction Pointer. Points to the *next* instruction (byte) to be used
};
const InterpretResult = enum { OK, COMPILE_ERROR, RUNTIME_ERROR };

var vm: VM = .{ .chunk = undefined, .ip = undefined };

pub fn interpret(chunk: *Chunk) InterpretResult {
    vm.chunk = chunk;
    vm.ip = vm.chunk.code.?.ptr;
    return run();
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
    if (debug_trace_execution) {
        std.debug.print("\n=== ENTERING VM ===\n", .{});
    }

    while (true) {
        if (debug_trace_execution) {
            const offset = @ptrToInt(vm.ip) - @ptrToInt(vm.chunk.code.?.ptr);
            _ = debug.disassemble_instruction(vm.chunk, offset);
        }

        // Assume invalid/unknown (out of range) instructions can never enter into the code
        const instruction = @intToEnum(OpCode, read_byte());
        switch (instruction) {
            (OpCode.OP_RETURN) => {
                return InterpretResult.OK;
            },
            (OpCode.OP_CONSTANT) => {
                const constant = read_constant();
                std.debug.print("{}\n", .{constant.double});
            },
            // else => {
            //     return InterpretResult.RUNTIME_ERROR;
            // },
        }
    }
    return InterpretResult.OK;
}
pub fn init_vm() void {}
pub fn free_vm() void {}
