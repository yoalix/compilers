const std = @import("std");
const memory = @import("./memory.zig");

pub const EnumValues = enum {
    number,
    boolean,
    nil,
};

pub const Value = union(EnumValues) {
    const Self = @This();

    number: f64,
    boolean: bool,
    nil: void,

    pub fn isNumber(self: Self) bool {
        return @TypeOf(self) == Self.number;
    }

    pub fn isBoolean(self: Self) bool {
        return @TypeOf(self) == Self.boolean;
    }

    pub fn isNil(self: Self) bool {
        return @TypeOf(self) == Self.nil;
    }
};
pub fn valuesEquals(a: Value, b: Value) bool {
    if (@TypeOf(a) != @TypeOf(b)) return false;
    switch (a) {
        .number => a == b,
        .boolean => a == b,
        .nil => true,
        else => false,
    }
}

pub fn printValue(value: Value) void {
    switch (value) {
        .number => std.debug.print("{d}", .{value.number}),
        .boolean => std.debug.print("{}", .{value.boolean}),
        .nil => std.debug.print("nil", .{}),
    }
}

pub const ValueArray = struct {
    const Self = @This();
    count: u32 = 0,
    capacity: u32 = 0,
    values: [*]Value = undefined,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
        };
    }
    pub fn deinit(self: *Self) void {
        memory.freeArray(self.alloc, Value, self.values, self.capacity);
        self.count = 0;
        self.capacity = 0;
        self.values = undefined;
    }

    pub fn writeValue(self: *Self, value: Value) void {
        if (self.count >= self.capacity) {
            if (self.capacity == std.math.maxInt(u32)) {
                @panic("Capacity overflow");
            }
            const newCapacity = memory.growCapacity(u32, self.capacity);
            self.values = memory.growArray(self.alloc, Value, self.values, self.capacity, newCapacity);
            self.capacity = newCapacity;
        }
        if (self.count == std.math.maxInt(usize)) {
            @panic("Count overflow");
        }
        self.values[self.count] = value;
        self.count += 1;
    }
};
