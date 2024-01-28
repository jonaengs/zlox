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
                const aString: *ObjString = self.as(ObjString);
                const bString: *ObjString = other.as(ObjString);
                // Due to string interning, we can simply check for reference equality
                return aString == bString;
            },
        }
    }
};

// TODO: For optimization, implement challenges 1 and 2 from chapter 19
// Must be a packed struct so that we can do type punning on it
/// Lox's internal string representation.
/// Lox strings are immutable.
pub const ObjString = packed struct {
    obj: Obj,

    length: usize,
    chars: [*]u8,  // cannot be a slice because they are not allowed in packed structs
    hash: u32,
};

/// Copies the given raw string literal char slice and returns it as an ObjString
pub fn copyString(allocator: std.mem.Allocator, string: []const u8) *ObjString {
    // TODO: Handle OOM error here
    
    const hash = hashString(string);
    // Drop the quotation marks when duping
    // Note that the string is not zero-terminated. If this has to change, use "allocator.dupeZ()"
    const copy = allocator.dupe(u8, string[1 .. string.len - 1]) catch @panic("OOM at str copy");
    
    // Check if the string has already been interned
    const findResult = VM.strings.findString(copy, hash);
    if (findResult) |interned| {
        // An identical string already exists, so we free the copy and return the existing string instead
        allocator.free(copy);
        return interned;
    }

    return allocateObjString(allocator, copy, hash) catch @panic("OOM at struct creation");
}

/// Returns the argument string as an ObjString, without copying it
pub fn takeString(allocator: std.mem.Allocator, string: []u8) *ObjString {
    const hash = hashString(string);
    return allocateObjString(allocator, string, hash) catch @panic("OOM at struct creation");
}

/// Allocates the objString struct with a pointer to the given characters.
/// Does not allocate or copy the characters.
fn allocateObjString(allocator: std.mem.Allocator, chars: []u8, hash: u32) !*ObjString {
    var objString = try allocateObj(ObjString, allocator);
    objString.length = chars.len;
    objString.chars = chars.ptr;
    objString.hash = hash;
    // intern the string. Because the string interning table is more like a set 
    // than a map, we can set the entry to nil.
    _ = VM.strings.set(objString, Value._nil());
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

fn hashString(string: []const u8) u32 {
    // TODO: Try different hash algorithms!
    // * XXHash (XXH3?)
    //     XXHash's great performance may be due to SIMD, which I don't think are applicable for this use case
    // * CityHash or FarmHash
    // * Have a look at https://github.com/rurban/smhasher
    //     Looks like FNV actually performs extremely well for hash tables in programming language contexts

    // Hash algorithm in use: FNV1-a (http://www.isthe.com/chongo/tech/comp/fnv/#FNV-1a)

    var hash: u32 = 2166136261;
    for (string) |char| {
        hash ^= char;
        hash *%= 16777619; // Allow overflow
    }
    return hash;
}
