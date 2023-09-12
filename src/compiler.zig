const std = @import("std");
const builtin = @import("builtin");
const parseFloat = std.fmt.parseFloat;
const scanner = @import("scanner.zig");
const debug = @import("debug.zig");
const Token = @import("scanner.zig").Token;
const TokenType = @import("scanner.zig").TokenType;
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;

const DEBUG_PRINT_CODE = @import("build_options").print_code and !builtin.is_test;

const Precedence = enum(u8) {
    NONE,
    ASSIGNMENT, // =
    OR, //         or
    AND, //        and
    EQUALITY, //   == !=
    COMPARISON, // < > <= >=
    TERM, //       + -
    FACTOR, //     * /
    UNARY, //      ! -
    CALL, //       . ()
    PRIMARY,
};

const rules = rules_blk: {
    var _rules = std.EnumArray(TokenType, ParseRule).initUndefined();
    _rules.set(.LEFT_PAREN, ParseRule{ .prefix = grouping, .infix = null, .precedence = .NONE });
    _rules.set(.RIGHT_PAREN, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.LEFT_BRACE, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.RIGHT_BRACE, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.COMMA, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.DOT, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.MINUS, ParseRule{ .prefix = unary, .infix = binary, .precedence = .TERM });
    _rules.set(.PLUS, ParseRule{ .prefix = null, .infix = binary, .precedence = .TERM });
    _rules.set(.SEMICOLON, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.SLASH, ParseRule{ .prefix = null, .infix = binary, .precedence = .FACTOR });
    _rules.set(.STAR, ParseRule{ .prefix = null, .infix = binary, .precedence = .FACTOR });
    _rules.set(.BANG, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.BANG_EQUAL, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.EQUAL, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.EQUAL_EQUAL, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.GREATER, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.GREATER_EQUAL, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.LESS, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.LESS_EQUAL, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.IDENTIFIER, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.STRING, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.NUMBER, ParseRule{ .prefix = number, .infix = null, .precedence = .NONE });
    _rules.set(.AND, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.CLASS, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.ELSE, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.FALSE, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.FOR, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.FUN, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.IF, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.NIL, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.OR, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.PRINT, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.RETURN, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.SUPER, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.THIS, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.TRUE, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.VAR, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.WHILE, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.ERROR, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    _rules.set(.EOF, ParseRule{ .prefix = null, .infix = null, .precedence = .NONE });
    break :rules_blk _rules;
};

const ParseFn = ?(*const fn () void);
const ParseRule = struct {
    prefix: ParseFn,
    infix: ParseFn,
    precedence: Precedence,
};

const Parser = struct {
    current: Token,
    previous: Token,

    hadError: bool,
    panicMode: bool,
};
var parser: Parser = undefined;
var compilingChunk: *Chunk = undefined;
var currentAllocator: std.mem.Allocator = undefined;

fn currentChunk() *Chunk {
    return compilingChunk;
}

pub fn compile(allocator: std.mem.Allocator, source: [:0]const u8, chunk: *Chunk) !void {
    scanner.init(source);
    compilingChunk = chunk;
    currentAllocator = allocator;

    parser.hadError = false;
    parser.panicMode = false;

    advance();
    expression();
    consume(.EOF, "Expected end of expression");
    endCompiler();

    if (parser.hadError) return error.CompileError;
}

/// Advance to next token, skipping error tokens
fn advance() void {
    parser.previous = parser.current;

    // Skip all error tokens, while reporting them to the user
    while (true) {
        parser.current = scanner.scanToken();
        if (parser.current.ttype != .ERROR) break;

        reportErrorAtCurrent(parser.current.slice);
    }
}

/// Advance past current token if it matches the expected ttype.
/// If ttype doesn't match, reports an error.
fn consume(ttype: TokenType, errmsg: []const u8) void {
    if (parser.current.ttype == ttype) {
        advance();
    } else {
        reportErrorAtCurrent(errmsg);
    }
}

fn endCompiler() void {
    emitReturn();
    if (DEBUG_PRINT_CODE) {
        if (!parser.hadError) {
            debug.dissasembleChunk(currentChunk(), "code");
        }
    }
}

fn parsePrecedence(precedence: Precedence) void {
    advance();
    const prefixRule = rules.get(parser.previous.ttype).prefix orelse {
        reportError("Expected expression.");
        return;
    };

    prefixRule();

    while (@intFromEnum(precedence) <= @intFromEnum(rules.get(parser.current.ttype).precedence)) {
        advance();
        const infixRule = rules.get(parser.previous.ttype).infix.?;
        infixRule();
    }
}

fn expression() void {
    parsePrecedence(.ASSIGNMENT);
}

fn number() void {
    // Parser has already decided that this is a valid float format-wise.
    const value: f64 = parseFloat(f64, parser.previous.slice) catch unreachable;
    emitConstant(Value{ .double = value });
}

fn grouping() void {
    expression();
    consume(.RIGHT_PAREN, "Expect ')' after expression.");
}

fn unary() void {
    const operatorType = parser.previous.ttype;

    parsePrecedence(.UNARY); // Parse same level to allow nested unary expressions
    // TODO: Since nesting unary operators is useless in Lox, we should probably disallow it. NO FUN ALLOWED

    switch (operatorType) {
        .MINUS => emitByte(.OP_NEGATE),
        // TODO: ! operator
        else => unreachable,
    }
}

fn binary() void {
    // Store operator type before parsing (and emitting) right-hand side
    const operatorType = parser.previous.ttype;
    const rule = rules.get(operatorType);
    parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

    // Then emit the operator itself
    switch (operatorType) {
        .PLUS => emitByte(.OP_ADD),
        .MINUS => emitByte(.OP_SUBTRACT),
        .STAR => emitByte(.OP_MULTIPLY),
        .SLASH => emitByte(.OP_DIVIDE),
        else => unreachable,
    }
}

fn makeConstant(value: Value) u8 {
    const constant_idx = currentChunk().addConstant(currentAllocator, value) catch blk: {
        reportError("Too many constants in one chunk");
        break :blk 0;
    };
    // TODO: Handle more constants than can fit in the array. Should probably at least panic/crash
    return constant_idx;
}

// EMIT FUNCTIONS
fn emitConstant(value: Value) void {
    emitBytes(.OP_CONSTANT, makeConstant(value));
}
fn emitReturn() void {
    emitByte(.OP_RETURN);
}

/// Takes either an OpCode or a u8 value
fn emitByte(byte: anytype) void {
    const value: u8 = switch (@TypeOf(byte)) {
        u8 => byte,
        @TypeOf(.enum_literal) => @intFromEnum(@as(OpCode, byte)),
        OpCode => @intFromEnum(byte),
        else => @compileError("Only accepts u8 and OpCode type values."),
    };
    // TODO: Handle chunk write error maybe?
    currentChunk().write(currentAllocator, value, parser.previous.line) catch
        std.debug.panic("Chunk write error", .{});
}
fn emitBytes(byte1: anytype, byte2: anytype) void {
    emitByte(byte1);
    emitByte(byte2);
}

// ERROR REPORTING
fn reportErrorAtCurrent(message: []const u8) void {
    reportErrorAt(&parser.current, message);
}
fn reportError(message: []const u8) void {
    reportErrorAt(&parser.previous, message);
}
fn reportErrorAt(token: *const Token, message: []const u8) void {
    // Suppress errors if we've already encountered some
    if (parser.panicMode) return;
    parser.panicMode = true;

    std.debug.print("[line {d}] Error", .{token.line});

    if (token.ttype == .EOF) {
        std.debug.print(" at end", .{});
    } else if (token.ttype == .ERROR) {
        // Skip -- no extra printing needed here
    } else {
        std.debug.print(" at '{d}'", .{token.slice});
    }

    std.debug.print(": {s}\n", .{message});
    parser.hadError = true;
}
