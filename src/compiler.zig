const std = @import("std");
const init_scanner = @import("scanner.zig").init_scanner;
const scan_token = @import("scanner.zig").scan_token;
const TokenType = @import("scanner.zig").TokenType;

pub fn compile(source: []const u8) void {
    init_scanner(source);

    var line: isize = -1;
    while (true) {
        const token = scan_token() catch unreachable; // TODO: HANDLE
        if (token.line != line) {
            std.debug.print("{d:>4} ", .{token.line});
            line = @intCast(isize, token.line); // Assume we can safely convert from usize to isize. Can't imagine this being a problem with 64-bit ptrs...
        } else {
            std.debug.print("   | ", .{});
        }

        std.debug.print("{d:0>2} '{s}'\n", .{ @enumToInt(token.type), token.start[0..token.length] });
        if (token.type == TokenType.EOF) break;
    }
}
