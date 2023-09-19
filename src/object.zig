const std = @import("std");
const Value = @import("value.zig").Value;
const VM = @import("vm.zig");

pub const Obj = packed struct {
    const Self = @This();
    pub const ObjType = enum(u8) {
        STRING,
    };

    otype: ObjType,
    next: ?*Obj, // Reference to next object allocated

    pub fn isObjType(value: Value, otype: ObjType) bool {
        return value == Value.obj and value.obj.otype == otype;
    }

    /// Cast to one of the containing types
    pub fn as(self: *Self, comptime otype: type) *otype {
        return @alignCast(@ptrCast(self));
    }

    pub fn isEqual(self: *Self, other: *Self) bool {
        if (self.otype != other.otype) return false;
        switch (self.otype) {
            .STRING => {
                const aString = self.as(ObjString);
                const bString = other.as(ObjString);
                return aString.length == bString.length and std.mem.eql(
                    u8,
                    aString.chars[0..aString.length],
                    bString.chars[0..bString.length],
                );
            },
        }
    }
};

pub const ObjString = packed struct {
    obj: Obj,

    length: usize,
    chars: [*]u8,
};

/// Copies the given char slice and returns it as an ObjString
pub fn copyString(allocator: std.mem.Allocator, string: []const u8) *ObjString {
    // TODO: Handle OOM error here
    // Note that I don't zero-terminate strings. If I have to change it, use "allocator.dupeZ()"
    var copy = allocator.dupe(u8, string[1 .. string.len - 1]) catch @panic("OOM at str copy");
    return allocateObjString(allocator, copy) catch @panic("OOM at struct creation");
}

/// Returns the argument string as an ObjString, without copying it
pub fn takeString(allocator: std.mem.Allocator, string: []u8) *ObjString {
    return allocateObjString(allocator, string) catch @panic("OOM at struct creation");
}

/// Allocates the objString struct with a pointer to the given characters.
/// Does not allocate or copy the characters.
fn allocateObjString(allocator: std.mem.Allocator, chars: []u8) !*ObjString {
    var objString = try allocateObj(ObjString, allocator);
    objString.length = chars.len;
    objString.chars = chars.ptr;
    return objString;
}

/// Does the actual allocation of the Obj struct
fn allocateObj(comptime objType: type, allocator: std.mem.Allocator) !*objType {
    // New object points to the current objects list head,
    // then replaces the head reference with its own address
    var obj = try allocator.create(objType);
    obj.obj = Obj{
        .otype = switch (objType) {
            ObjString => .STRING,
            else => unreachable,
        },
        .next = VM.objects,
    };
    VM.objects = @ptrCast(obj);

    return obj;
}
