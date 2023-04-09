const std = @import("std");
const TokenType = @import("token.zig").TokenType;

// TODO: Convert everything to be methods on a scanner struct
const ScannerError = error{
    UnexpectedToken,
    UnterminatedString,
};

const empty_str: *const [0:0]u8 = "";
const EOF = empty_str[0];

pub const Token = struct {
    type: TokenType,
    start: [*]const u8,
    length: usize,
    line: usize,
};

// Same fields as Token
pub const ErrorInfo = struct {
    msg: []const u8,
    line: usize,
};

const Scanner = struct {
    start: [*]const u8,
    current: [*]const u8,
    line: usize,
};
var scanner = Scanner{ .start = undefined, .current = undefined, .line = undefined };

pub fn scan_token() !Token {
    skip_whitespace();
    scanner.start = scanner.current;

    if (is_at_end()) return make_token(TokenType.EOF);

    const c = advance();
    if (is_alpha(c)) return identifier();
    return switch (c) {
        '(' => make_token(TokenType.LEFT_PAREN),
        ')' => make_token(TokenType.RIGHT_PAREN),
        '{' => make_token(TokenType.LEFT_BRACE),
        '}' => make_token(TokenType.RIGHT_BRACE),
        ';' => make_token(TokenType.SEMICOLON),
        ',' => make_token(TokenType.COMMA),
        '.' => make_token(TokenType.DOT),
        '-' => make_token(TokenType.MINUS),
        '+' => make_token(TokenType.PLUS),
        '/' => make_token(TokenType.SLASH),
        '*' => make_token(TokenType.STAR),

        // Two-character lexemes
        '!' => make_token(if (match('=')) TokenType.BANG_EQUAL else TokenType.BANG),
        '=' => make_token(if (match('=')) TokenType.EQUAL_EQUAL else TokenType.EQUAL),
        '<' => make_token(if (match('=')) TokenType.LESS_EQUAL else TokenType.LESS),
        '>' => make_token(if (match('=')) TokenType.GREATER_EQUAL else TokenType.GREATER),

        // Literals
        '"' => return string(),
        '0'...'9' => return number(),
        else => ScannerError.UnexpectedToken,
    };
}

fn skip_whitespace() void {
    while (true) {
        const c = peek();
        switch (c) {
            ' ', '\t', '\r' => {
                _ = advance();
            },
            '\n' => {
                scanner.line += 1;
                _ = advance();
            },
            '/' => {
                if (peek_next() == '/') {
                    while (peek() != '\n' and !is_at_end()) _ = advance();
                } else return;
            },
            else => break,
        }
    }
}

fn string() !Token {
    while (peek() != '"' and !is_at_end()) {
        if (peek() == '\n') scanner.line += 1;
        _ = advance();
    }
    if (is_at_end()) return ScannerError.UnterminatedString;

    // Advance past the closing quote
    _ = advance();
    return make_token(TokenType.STRING);
}

fn identifier() Token {
    while (is_alpha(peek()) or is_digit(peek())) _ = advance();
    return make_token(identfier_type());
}

fn identfier_type() TokenType {
    return switch (scanner.start[0]) {
        'a' => check_keyword(1, "nd", TokenType.AND),
        'c' => check_keyword(1, "lass", TokenType.CLASS),
        'e' => check_keyword(1, "lse", TokenType.ELSE),
        'f' => if (scanner.current[0] != scanner.start[1])
            // Only check next char if token is longer than one char
            switch (scanner.start[1]) {
                'a' => check_keyword(2, "lse", TokenType.FALSE),
                'o' => check_keyword(2, "r", TokenType.FOR),
                'u' => check_keyword(2, "n", TokenType.FUN),
                else => TokenType.IDENTIFIER,
            }
        else
            TokenType.IDENTIFIER,
        'i' => check_keyword(1, "f", TokenType.IF),
        'n' => check_keyword(1, "il", TokenType.NIL),
        'o' => check_keyword(1, "r", TokenType.OR),
        'p' => check_keyword(1, "rint", TokenType.PRINT),
        'r' => check_keyword(1, "eturn", TokenType.RETURN),
        's' => check_keyword(1, "uper", TokenType.SUPER),
        't' => if (scanner.current[0] != scanner.start[1])
            switch (scanner.start[1]) {
                'h' => check_keyword(2, "is", TokenType.THIS),
                'r' => check_keyword(2, "ue", TokenType.TRUE),
                else => TokenType.IDENTIFIER,
            }
        else
            TokenType.IDENTIFIER,
        'v' => check_keyword(1, "ar", TokenType.VAR),
        'w' => check_keyword(1, "hile", TokenType.WHILE),
        else => TokenType.IDENTIFIER,
    };
}

fn check_keyword(start: usize, rest: []const u8, ttype: TokenType) TokenType {
    const token_length = @ptrToInt(scanner.current) - @ptrToInt(scanner.start);

    if (token_length == start + rest.len and std.mem.eql(u8, scanner.start[start..token_length], rest)) {
        return ttype;
    }
    return TokenType.IDENTIFIER;
}
fn is_alpha(c: u8) bool {
    return ('a' <= c and c <= 'z') or ('A' <= c and c <= 'Z') or c == '_';
}

fn is_digit(c: u8) bool {
    return '0' <= c and c <= '9';
}

fn number() Token {
    while (is_digit(peek())) _ = advance();

    if (peek() == '.' and is_digit(peek_next())) {
        // consume the dot and get rest of number
        _ = advance();
        while (is_digit(peek())) _ = advance();
    }

    return make_token(TokenType.NUMBER);
}

fn advance() u8 {
    const char = scanner.current[0];
    scanner.current += 1;
    return char;
}

fn peek() u8 {
    return scanner.current[0];
}
fn peek_next() u8 {
    if (is_at_end()) return EOF;
    return scanner.current[1];
}

fn match(expected: u8) bool {
    if (is_at_end()) return false;
    if (scanner.current[0] != expected) return false;

    scanner.current += 1;
    return true;
}

fn is_at_end() bool {
    return scanner.current[0] == EOF;
}

fn make_token(ttype: TokenType) Token {
    return Token{
        .type = ttype,
        .start = scanner.start,
        .length = @ptrToInt(scanner.current) - @ptrToInt(scanner.start), // Data length is 1 byte, so no need to divide by sizeof
        .line = scanner.line,
    };
}

pub fn get_error_info(comptime error_type: ScannerError) ErrorInfo {
    const message = switch (error_type) {
        error.UnexpectedToken => "Unexpected token.",
    };
    return ErrorInfo{
        .message = message,
        .line = scanner.line,
    };
}

pub fn init_scanner(source: []const u8) void {
    scanner.start = source.ptr;
    scanner.current = source.ptr;
    scanner.line = 1;
}

////////////////
// TESTS
////////////////

test "single character tokens" {
    const source =
        \\(+-/*){=!}<>;,.
    ;
    const expected = [_]TokenType{
        TokenType.LEFT_PAREN,
        TokenType.PLUS,
        TokenType.MINUS,
        TokenType.SLASH,
        TokenType.STAR,
        TokenType.RIGHT_PAREN,
        TokenType.LEFT_BRACE,
        TokenType.EQUAL,
        TokenType.BANG,
        TokenType.RIGHT_BRACE,
        TokenType.LESS,
        TokenType.GREATER,
        TokenType.SEMICOLON,
        TokenType.COMMA,
        TokenType.DOT,
        TokenType.EOF,
    };

    init_scanner(source);
    for (expected) |ttype| {
        const token = try scan_token();
        try std.testing.expectEqual(ttype, token.type);
    }
}

test "two character tokens" {
    const source =
        \\ == != >= <=
    ;
    const expected = [_]TokenType{
        TokenType.EQUAL_EQUAL,
        TokenType.BANG_EQUAL,
        TokenType.GREATER_EQUAL,
        TokenType.LESS_EQUAL,
        TokenType.EOF,
    };

    init_scanner(source);
    for (expected) |ttype| {
        const token = try scan_token();
        try std.testing.expectEqual(ttype, token.type);
    }
}

test "comments" {
    const source =
        \\ // This is comment one
        \\ // and this is comment two.
        \\ // Third line here.
    ;

    init_scanner(source);
    const token = try scan_token();
    try std.testing.expectEqual(TokenType.EOF, token.type);
    try std.testing.expectEqual(@as(usize, 3), token.line);
}

test "whitespace" {
    const source = "  \t\r\n\r\t \t \n";

    init_scanner(source);
    const token = try scan_token();
    try std.testing.expectEqual(TokenType.EOF, token.type);
    try std.testing.expectEqual(@as(usize, 3), token.line); // Each \n should increment line
}
test "string literals" {
    const source =
        \\ "hello"
        \\ "multi-line
        \\ string"
    ;
    const expected = [_]TokenType{
        TokenType.STRING,
        TokenType.STRING,
    };

    init_scanner(source);
    for (expected) |ttype| {
        const token = try scan_token();
        try std.testing.expectEqual(ttype, token.type);
    }
    const eof_token = try scan_token();
    try std.testing.expectEqual(TokenType.EOF, eof_token.type);
    try std.testing.expectEqual(@as(usize, 3), eof_token.line);
}

test "number literals" {
    const source = "3 123 195 0.11 987654.1230123";
    const expected = [_]TokenType{
        TokenType.NUMBER,
        TokenType.NUMBER,
        TokenType.NUMBER,
        TokenType.NUMBER,
        TokenType.NUMBER,
        TokenType.EOF,
    };

    init_scanner(source);
    for (expected) |ttype| {
        const token = try scan_token();
        try std.testing.expectEqual(ttype, token.type);
    }
}

test "reserved keywords" {
    const source =
        \\ and class else false for fun 
        \\ if nil or print return super this true var while
    ;
    const expected = [_]TokenType{
        TokenType.AND,
        TokenType.CLASS,
        TokenType.ELSE,
        TokenType.FALSE,
        TokenType.FOR,
        TokenType.FUN,
        TokenType.IF,
        TokenType.NIL,
        TokenType.OR,
        TokenType.PRINT,
        TokenType.RETURN,
        TokenType.SUPER,
        TokenType.THIS,
        TokenType.TRUE,
        TokenType.VAR,
        TokenType.WHILE,
    };

    init_scanner(source);
    for (expected) |ttype| {
        const token = try scan_token();
        try std.testing.expectEqual(ttype, token.type);
    }

    const eof_token = try scan_token();
    try std.testing.expectEqual(TokenType.EOF, eof_token.type);
    try std.testing.expectEqual(@as(usize, 2), eof_token.line);
}

test "indentifiers" {
    const source =
        \\ an andy _class class_ els3 else1 falsy forand funtimes 
        \\ iff iif nilor _print print_ ret retu retur returnn ssuper 
        \\ This thiS trUe Var wIhle
    ;
    const expected = [_]TokenType{TokenType.IDENTIFIER} ** 24;

    init_scanner(source);
    for (expected) |ttype| {
        const token = try scan_token();
        // std.debug.print("{s}\n", .{token.start[0..token.length]});
        try std.testing.expectEqual(ttype, token.type);
    }

    const eof_token = try scan_token();
    try std.testing.expectEqual(TokenType.EOF, eof_token.type);
    try std.testing.expectEqual(@as(usize, 3), eof_token.line);
}

test "scanning errors" {
    // Unexpected chars: \ [ ] : ^ | § ...
    // Unterminated strings: "asd
    const source =
        \\ \[]:^|§$
        \\ "ASD
    ;
    const expected = [_]ScannerError{ScannerError.UnexpectedToken} ** 9 ++ [_]ScannerError{ScannerError.UnterminatedString};

    init_scanner(source);
    for (expected) |expected_err| {
        if (scan_token()) |token| {
            std.debug.print("{s}\n", .{token.start[0..token.length]});
        } else |err| {
            try std.testing.expectEqual(expected_err, err);
        }
    }

    const eof_token = try scan_token();
    try std.testing.expectEqual(TokenType.EOF, eof_token.type);
    try std.testing.expectEqual(@as(usize, 2), eof_token.line);
}
