const std = @import("std");
const memory = @import("./memory.zig");

pub const Value = f64;

pub fn printValue(value: Value) void {
    std.debug.print("{d}", .{value});
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
        if (self.count + 1 > self.capacity) {
            const newCapacity = memory.growCapacity(self.capacity);
            self.values = memory.growArray(self.alloc, Value, self.values, self.capacity, newCapacity);
            self.capacity = newCapacity;
        }
        self.values[self.count] = value;
        self.count += 1;
    }
};
