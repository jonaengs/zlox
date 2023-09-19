//! Representation of constant values encountered in a program
const std = @import("std");
const memory = @import("memory.zig");
const Obj = @import("object.zig").Obj;
const ObjString = @import("object.zig").ObjString;

/// Internal representation of all values permitted by Lox
pub const Value = union(enum) {
    boolean: bool,
    number: f64,
    nil: f64,
    obj: *Obj,

    /// Convenience function for casting *ObjString to *Obj
    /// and putting it in a Value.
    pub fn makeString(objString: *ObjString) Value {
        return Value{ .obj = @ptrCast(objString) };
    }

    /// Convenience function for checking whether a Value is an Obj with type ObjString
    pub fn isString(self: *const Value) bool {
        return self.* == Value.obj and Obj.isObjType(self.*, .STRING);
    }

    pub fn print(self: *const Value) void {
        std.debug.print("{}", .{self.*});
    }

    pub fn format(
        self: *const Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try switch (self.*) {
            .number => |v| writer.print("{d:.2}", .{v}),
            .boolean => |v| writer.print("{}", .{v}),
            .nil => |_| writer.print("nil", .{}),
            .obj => |obj| switch (obj.otype) {
                .STRING => {
                    const oStr = obj.as(ObjString);
                    try writer.print("\"{s}\"", .{oStr.chars[0..oStr.length]});
                },
            },
        };
    }
};

pub const ValueArray = struct {
    count: usize,
    values: []Value,

    pub fn init(self: *ValueArray) void {
        self.count = 0;
        self.values = &.{};
    }

    pub fn write(self: *ValueArray, allocator: std.mem.Allocator, value: Value) !void {
        if (self.values.len < self.count + 1) {
            self.values = try memory.grow_array(allocator, self.values);
        }
        self.values[self.count] = value;
        self.count += 1;
    }

    pub fn free(self: *ValueArray, allocator: std.mem.Allocator) void {
        memory.free_array(allocator, self.values);
        self.init();
    }
};
