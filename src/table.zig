const std = @import("std");
const memory = @import("memory.zig");
const Value = @import("value.zig").Value;
const ObjString = @import("object.zig").ObjString;

// The hash table implementation relies on
// open addressing with linear probing.

// TODO: Have a look at using another implementation, like
// some of the ones presented here: https://ayende.com/blog/197185-B/criticizing-hare-language-approach-for-generic-data-structures

// TODO: Test different table load values
const TABLE_MAX_LOAD = 0.75;

pub const Table = struct {
    allocator: std.mem.Allocator,
    count: u32,
    // capacity = entries.len
    entries: []Entry,

    pub fn init(table: *Table, allocator: std.mem.Allocator) void {
        table.allocator = allocator;
        table.count = 0;
        table.entries = &.{};
    }

    pub fn free(table: *Table) void {
        // We don't need to check for empty slice before freeing -- allocator is smart enough to handle it
        table.allocator.free(table.entries);
        table.init(table.allocator);
    }

    /// Sets table[key] = value.
    /// Returns true if key was already present in table.
    pub fn set(table: *Table, key: *ObjString, value: Value) bool {
        const adjustmentThreshold: usize = @intFromFloat(@floor(
            @as(f32, @floatFromInt(table.entries.len)) * TABLE_MAX_LOAD
        ));
        if (table.count + 1 > adjustmentThreshold) {
            const new_capacity = @max(8, table.entries.len * 2);
            adjustCapacity(table, new_capacity);
        }

        const entry = findEntry(table.entries, key);
        // TODO: Check what this compiles down to. Could be very inefficient.
        const isNewKey = entry.key == null;
        // only increment the count if the entry we're replacing was empty and also not a tombstone
        // because we don't decrement the count when we delete/tombstone values
        table.count += @intFromBool(isNewKey and entry.value == Value.nil);

        entry.key = key;
        entry.value = value;

        return isNewKey;
    }

    /// Returns true and sets the value pointer if the key is found
    /// otherwise, returns false
    pub fn get(table: *Table, key: *ObjString, value: *Value) bool {
        // Important to check in case the entries array is empty
        if (table.count == 0) return false;

        const entry = findEntry(table, key);
        if (entry.key) {
            value.* = entry.value;
            return true;
        }

        return false;
    }

    /// Deletes the key/entry from the table.
    /// Returns true if the key was found, false if the key was not found
    pub fn delete(table: *Table, key: *ObjString) bool {
        // Due of linear probing, we cannot simply do tableSet(table, Value._nil())
        // as, in case of collisions, this would cause following keys to no longer be found

        if (table.count == 0) return false;

        const entry = findEntry(table, key);
        if (entry.key) {
            // If value exists, tombstone it by setting key to null but setting value value to true
            entry.key = null;
            entry.value = Value{ .boolean = true };
            return true;
        }

        return false;
    }

    pub fn findString(table: *Table, string: []const u8, hash: u32) ?*ObjString {
        if (table.count == 0) return null;

        var index = hash % table.entries.len;

        while (true) {
            const entry = table.entries[index];
            if (entry.key) |key| {
                if (key.hash == hash and std.mem.eql(u8, key.chars[0 .. key.length], string)) {
                    return key;
                }
            }
            else if (entry.value == Value.nil) {
                // Return null if we find an empty non-tombstone value
                return null;
            }
            index = (index + 1) % table.entries.len;
        }
    }

    pub fn format(
        self: *const Table,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{{\n", .{});
        for (self.entries) |entry| {
            try writer.print("\t{}\n", .{entry});
        }
        try writer.print("}}\n", .{});
    }
};

/// A table entry
/// If key is null, then the entry is empty (value = nil)
/// (Except if the key was deleted, in which case value = true)
const Entry = struct {
    key: ?*ObjString,
    value: Value,

    pub fn format(
        self: *const Entry,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        if (self.key) |key| {
            const asVal = Value{ .obj = @ptrCast(&key.obj) };
            try writer.print("{}: {}", .{asVal, self.value});
        } else {
            if (self.value != Value.nil) {
                // tombstone
                try writer.print("✝", .{});
            } else {
                try writer.print("-", .{});
            }
        }
    }
};

fn adjustCapacity(table: *Table, newCapacity: usize) void {
    var newEntries: []Entry = table.allocator.alloc(Entry, newCapacity) catch @panic("OOM at table");
    for (newEntries) |*entry| {
        entry.key = null;
        entry.value = Value._nil();
    }

    // Move entries to (possibly) new indices
    table.count = 0; // Reset entry count to account for tombstones
    for (table.entries) |oldEntry| {
        // skip empty entries
        if (oldEntry.key == null) continue;
        
        const destination = findEntry(newEntries, oldEntry.key.?);
        destination.key = oldEntry.key;
        destination.value = oldEntry.value;
        table.count += 1;
    }

    // Freeing table.entries must happen BEFORE we set table.entries to the new entries array
    table.allocator.free(table.entries);
    table.entries = newEntries;
}

/// Copies all entries from the first table into the second table
fn tableAddAll(from: *Table, into: *Table) void {
    for (from.entries) |entry| {
        // skip empty entries
        if (entry.key) |key| {
            into.set(key, entry.value);
        }
    }
}

/// Finds an entry for the key
/// If the key is already in the table, the key's existing entry is returned
/// Otherwise returns a blank/empty entry
fn findEntry(entries: []Entry, key: *ObjString) *Entry {
    // It could be that we could achieve better performance by returning
    // a copy of the entry rather than a pointer to it

    var index = key.hash % entries.len;
    var tombstone: ?*Entry = null;

    // Performs linear probing -- if key isn't where the hash indicates it should be,
    // we simply look at the next entry until we find a match
    // Due to tombstoning, the logic is a little more complex:
    // If we find a tombstone before finding the matching key or an empty entry then we keep going.
    // If we find an empty entry, then the tombstone is return
    while (true) {
        // Assumes we never have a full entries array that's missing the given key
        // This assumption holds because tableSet will grow the table before the table becomes full

        const entry = &entries[index];
        if (entry.key == null) {
            // Key being null means either empty or tombstoned entry
            if (entry.value == Value.nil) {
                // Found an empty entry
                // Return the tombstone instead, if we found one
                return if (tombstone) |t| t else entry;
            } else {
                // We found a tombstone
                if (tombstone == null) {
                    tombstone = entry;
                }
            }
        } else if (entry.key.? == key) {
            // pointer equality check works due to us interning all strings
            // such that if two strings lie at two different memory addresses, they must be different
            return entry;
        }

        index = (index + 1) % entries.len;
    }
}
