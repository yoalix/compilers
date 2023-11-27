const std = @import("std");
const memory = @import("memory.zig");
const Value = @import("value.zig").Value;
const ValueArray = @import("value.zig").ValueArray;

pub const OpCode = enum(u8) {
    // OP_LONG_CONSTANT,
    OP_NEGATE,
    OP_ADD,
    OP_SUBTRACT,
    OP_MULTIPLY,
    OP_DIVIDE,
    OP_CONSTANT,
    OP_RETURN,
};

pub const Chunk = struct {
    const Self = @This();
    alloc: std.mem.Allocator,
    count: u32 = 0,
    capacity: u32 = 0,
    code: [*]u8 = undefined,
    lines: [*]u32 = undefined,
    linesCapacity: u32 = 0,
    lineCount: u32 = 0,
    constants: ValueArray,

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
            .constants = ValueArray.init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        memory.freeArray(self.alloc, u8, self.code, self.capacity);
        memory.freeArray(self.alloc, u32, self.lines, self.linesCapacity);
        self.constants.deinit();
        self.count = 0;
        self.capacity = 0;
        self.code = undefined;
        self.lines = undefined;
        self.linesCapacity = 0;
        self.lineCount = 0;
        self.constants = ValueArray.init(self.alloc);
    }

    pub fn write(self: *Self, byte: u8, line: u32) void {
        if (self.count + 1 > self.capacity) {
            var oldCapacity = self.capacity;
            self.capacity = memory.growCapacity(self.capacity);
            self.code = memory.growArray(self.alloc, u8, self.code, oldCapacity, self.capacity);
        }

        self.code[self.count] = byte;
        self.count += 1;

        if (self.lineCount + 1 > self.linesCapacity) {
            var oldCapacity = self.linesCapacity;
            self.linesCapacity = memory.growCapacity(self.lineCount);
            self.lines = memory.growArray(self.alloc, u32, self.lines, oldCapacity, self.linesCapacity);
            for (oldCapacity..self.linesCapacity) |i| {
                self.lines[i] = 0;
            }
        }
        var index: usize = line - 1;
        if (self.lines[index] == 0) {
            self.lineCount += 1;
        }
        self.lines[index] += line;
    }

    pub fn addConstant(self: *Self, value: Value) u32 {
        self.constants.writeValue(value);
        return self.constants.count - 1;
    }

    pub inline fn getLine(self: *Self, offset: u32) u32 {
        var lineStart: u32 = 0;
        for (0..self.lineCount) |i| {
            lineStart += self.lines[i];
            if (lineStart > offset) {
                return @as(u32, @intCast(i + 1));
            }
        }
        return 0;
    }
};

test "chunk" {
    var allocator = std.testing.allocator;
    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    var constant = chunk.addConstant(1.2);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(@intCast(constant), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    try std.testing.expect(chunk.count == 3);
    try std.testing.expect(chunk.code[0] == @intFromEnum(OpCode.OP_CONSTANT));
    try std.testing.expect(chunk.code[1] == constant);
    try std.testing.expect(chunk.code[2] == @intFromEnum(OpCode.OP_RETURN));
}
