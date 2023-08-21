const std = @import("std");
pub const TokenType = @import("token_type.zig").TokenType;

pub const ScannerError = error{
    UnexpectedToken,
};

pub const Token = struct {
    ttype: TokenType,
    slice: []const u8, // Store slice instead of pointer plus length
    line: usize,

    fn make(typ: TokenType) Token {
        return Token{ .ttype = typ, .slice = start[0..current], .line = line };
    }

    /// message is expected to a string literal
    fn makeError(message: []const u8) Token {
        return Token{ .ttype = TokenType.ERROR, .slice = message, .line = line };
    }
};

// Scanner variables.
var start: [:0]const u8 = undefined;
var current: usize = 0; // As in VM, we use an index instead of direct pointers. Change if performance suffers.
var line: usize = 0;

pub fn init(source: [:0]const u8) void {
    start = source; // make null-terminated
    current = 0;
    line = 1;
}

pub fn scanToken() Token {
    skipWhiteSpace();

    start = start[current..];
    current = 0;

    if (isAtEnd())
        return Token.make(TokenType.EOF);

    const char = advance();
    // std.debug.print("st: {c} ({})\n", .{ char, char });

    return switch (char) {
        // Single-character tokens
        '(' => Token.make(.LEFT_PAREN),
        ')' => Token.make(.RIGHT_PAREN),
        '{' => Token.make(.LEFT_BRACE),
        '}' => Token.make(.RIGHT_BRACE),
        ';' => Token.make(.SEMICOLON),
        ',' => Token.make(.COMMA),
        '.' => Token.make(.DOT),
        '-' => Token.make(.MINUS),
        '+' => Token.make(.PLUS),
        '/' => Token.make(.SLASH),
        '*' => Token.make(.STAR),

        // Two-character punctuation:
        '!' => Token.make(if (match('=')) .BANG_EQUAL else .BANG),
        '=' => Token.make(if (match('=')) .EQUAL_EQUAL else .EQUAL),
        '<' => Token.make(if (match('=')) .LESS_EQUAL else .LESS),
        '>' => Token.make(if (match('=')) .GREATER_EQUAL else .GREATER),

        //
        '"' => return string(),
        '0'...'9' => return number(),
        'a'...'z', 'A'...'Z', '_' => identifier(),

        // Error if nothing matches
        else => Token.makeError("Unexpected Token"),
    };
}

fn isAtEnd() bool {
    return current >= start.len;
}

fn advance() u8 {
    current += 1;
    return start[current - 1];
}

fn match(expected: u8) bool {
    if (isAtEnd()) return false;
    if (start[current] != expected) return false;
    current += 1;
    return true;
}

fn peek() u8 {
    return start[current];
}

fn peekNext() u8 {
    if (isAtEnd()) return start[start.len]; // return EOF character
    return start[current + 1];
}

fn isAlpha(char: u8) bool {
    return (char >= 'a' and char <= 'z') or
        (char >= 'A' and char <= 'Z') or
        char == '_';
}

/// Also skips comments
fn skipWhiteSpace() void {
    while (!isAtEnd()) {
        const char = peek();
        switch (char) {
            ' ', '\r', '\t' => {
                _ = advance();
            },
            '\n' => {
                line += 1;
                _ = advance();
            },
            // Handle single-line comments
            '/' => {
                if (peekNext() == '/') {
                    while (peek() != '\n' and !isAtEnd()) _ = advance();
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}

fn string() Token {
    // TODO: Support quote char escaping?
    while (peek() != '"' and !isAtEnd()) {
        if (peek() == '\n') line += 1;
        _ = advance();
    }

    if (isAtEnd()) return Token.makeError("Unterminated string.");

    // Move past closing quote
    _ = advance();
    return Token.make(.STRING);
}

fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn number() Token {
    while (isDigit(peek())) _ = advance();

    // Check for '.X'
    if (peek() == '.' and isDigit(peekNext())) {
        _ = advance(); // Consume the '.'
        while (isDigit(peek())) _ = advance();
    }
    const token = Token.make(.NUMBER);
    return token;
}

fn checkKeyword(start_idx: usize, rest: []const u8, ttype: TokenType) TokenType {
    if (current - start_idx == rest.len and std.mem.eql(u8, start[start_idx .. start_idx + rest.len], rest)) {
        return ttype;
    }
    return .IDENTIFIER;
}

fn identifierType() TokenType {
    return switch (start[0]) {
        'a' => checkKeyword(1, "nd", .AND),
        'c' => checkKeyword(1, "lass", .CLASS),
        'e' => checkKeyword(1, "lse", .ELSE),
        'i' => checkKeyword(1, "f", .IF),
        'n' => checkKeyword(1, "il", .NIL),
        'o' => checkKeyword(1, "r", .OR),
        'p' => checkKeyword(1, "rint", .PRINT),
        'r' => checkKeyword(1, "eturn", .RETURN),
        's' => checkKeyword(1, "uper", .SUPER),
        'v' => checkKeyword(1, "ar", .VAR),
        'w' => checkKeyword(1, "hile", .WHILE),

        // Complex cases below
        'f' => if (current > 1) {
            return switch (start[1]) {
                'a' => checkKeyword(2, "lse", .FALSE),
                'o' => checkKeyword(2, "r", .FOR),
                'u' => checkKeyword(2, "n", .FUN),
                else => .IDENTIFIER,
            };
        } else .IDENTIFIER,
        't' => if (current > 1) {
            return switch (start[1]) {
                'h' => checkKeyword(2, "is", .THIS),
                'r' => checkKeyword(2, "ue", .TRUE),
                else => .IDENTIFIER,
            };
        } else .IDENTIFIER,

        // Default to identifier if no keywords match
        else => .IDENTIFIER,
    };
}

fn identifier() Token {
    while (isAlpha(peek()) or isDigit(peek())) _ = advance();
    return Token.make(identifierType());
}

//
//
// TESTS
//

test "simple single-character tokens" {
    const source = "(){};,.-+/*";
    const expected = [_]TokenType{ .LEFT_PAREN, .RIGHT_PAREN, .LEFT_BRACE, .RIGHT_BRACE, .SEMICOLON, .COMMA, .DOT, .MINUS, .PLUS, .SLASH, .STAR };

    init(source);
    for (expected, source, 0..) |ttype, char, idx| {
        const token = scanToken();
        try std.testing.expectEqual(ttype, token.ttype);
        try std.testing.expectEqual(@as(usize, 1), token.slice.len);
        try std.testing.expectEqual(char, token.slice[0]);

        // Current should reset to zero and then count up to 1,
        // while start should be shortened with each iteration
        try std.testing.expectEqual(@as(usize, 1), current);
        try std.testing.expectEqual(source.len - idx, start.len);
    }
    try std.testing.expectEqual(TokenType.EOF, scanToken().ttype);
}

test "other single-character tokens" {
    // The slightly tricker single-char tokens
    // which are also valid parts of the two-char tokens if suffixed
    // with an equals character
    const source = "=<>!";
    const expected = [_]TokenType{ .EQUAL, .LESS, .GREATER, .BANG };

    init(source);
    for (expected, source, 0..) |ttype, char, idx| {
        const token = scanToken();
        try std.testing.expectEqual(ttype, token.ttype);
        try std.testing.expectEqual(@as(usize, 1), token.slice.len);
        try std.testing.expectEqual(char, token.slice[0]);

        try std.testing.expectEqual(@as(usize, 1), current);
        try std.testing.expectEqual(source.len - idx, start.len);
    }
    try std.testing.expectEqual(TokenType.EOF, scanToken().ttype);
}

test "two-character tokens" {
    // Also tests some whitespace handling
    const source = "== != <= >=";
    const expected = [_]TokenType{ .EQUAL_EQUAL, .BANG_EQUAL, .LESS_EQUAL, .GREATER_EQUAL };
    var split = std.mem.split(u8, source, " ");

    init(source);
    for (expected) |ttype| {
        const chars = split.next().?;
        const token = scanToken();

        try std.testing.expectEqual(ttype, token.ttype);
        try std.testing.expectEqualStrings(chars, token.slice);
        try std.testing.expectEqual(@as(usize, 2), current);
    }
}

test "numbers" {
    // Also tests some whitespace handling
    const source = "2 3.14 0.0 1231231236787";
    var split = std.mem.split(u8, source, " ");

    init(source);
    while (split.next()) |chars| {
        const token = scanToken();

        try std.testing.expectEqual(TokenType.NUMBER, token.ttype);
        try std.testing.expectEqualStrings(chars, token.slice);
        try std.testing.expectEqual(@as(usize, chars.len), current);
    }
}

test "strings (and whitespace and comments)" {
    // Also tests some whitespace handling
    const source = " \"hello\"// \n\n \t\"goodbye\" \n\r //2";
    init(source);

    var token = scanToken();
    try std.testing.expectEqual(TokenType.STRING, token.ttype);
    try std.testing.expectEqualStrings("\"hello\"", token.slice);
    try std.testing.expectEqual(@as(usize, 1), line);

    token = scanToken();
    try std.testing.expectEqual(TokenType.STRING, token.ttype);
    try std.testing.expectEqualStrings("\"goodbye\"", token.slice);
    try std.testing.expectEqual(@as(usize, 3), line);

    token = scanToken();
    try std.testing.expectEqual(TokenType.EOF, token.ttype);
}

test "keywords" {
    const source = "and class else false for fun if nil or print return super this true var while";
    const expected = [_]TokenType{ .AND, .CLASS, .ELSE, .FALSE, .FOR, .FUN, .IF, .NIL, .OR, .PRINT, .RETURN, .SUPER, .THIS, .TRUE, .VAR, .WHILE };

    init(source);
    for (expected) |ttype| {
        const token = scanToken();
        try std.testing.expectEqual(ttype, token.ttype);
    }
    try std.testing.expectEqual(TokenType.EOF, scanToken().ttype);
}

test "identifiers" {
    const source = "an clas els fals fo fu i ni o prin retur supe thi tru va whil" ++ "andd classd elsed falsed ford fund ifd nild ord printd returnd superd thisd true1 var_ _while";

    init(source);
    var token = scanToken();
    while (token.ttype != .EOF) {
        try std.testing.expectEqual(TokenType.IDENTIFIER, token.ttype);
        token = scanToken();
    }
    try std.testing.expectEqual(TokenType.EOF, scanToken().ttype);
}
