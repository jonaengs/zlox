const std = @import("std");
const scanner = @import("scanner.zig");
const Token = @import("scanner.zig").Token;

pub fn compile(source: [:0]const u8) void {
    scanner.init(source);

    var line: usize = 0; // lines start at one. 0 indicates we haven't started yet

    while (true) {
        const token = scanner.scanToken();
        if (token.line != line) {
            std.debug.print("{d:04} ", .{token.line});
            line = token.line;
        } else {
            std.debug.print("   | ", .{});
        }
        std.debug.print("{} '{s}'", .{ token.ttype, token.slice });

        if (token.ttype == .EOF) break;
    }
}
