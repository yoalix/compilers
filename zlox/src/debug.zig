const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const value = @import("value.zig");

pub const trace_enabled = @import("build_options").trace_enable;

pub fn disassembleChunk(chunk: *Chunk, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});
    var offset: u32 = 0;
    while (offset < chunk.count) {
        offset = disassembleInstruction(chunk, offset);
    }
}

pub fn disassembleInstruction(chunk: *Chunk, offset: u32) u32 {
    std.debug.print("{:0>4} ", .{offset});
    if (offset > 0 and chunk.lines[offset] == chunk.lines[offset - 1]) {
        std.debug.print("   | ", .{});
    } else {
        std.debug.print("{d:4} ", .{chunk.getLine(offset)});
    }

    var instruction = @as(OpCode, @enumFromInt(chunk.code[offset]));
    return switch (instruction) {
        .OP_RETURN => simpleInstruction("OP_RETURN", offset),
        .OP_CONSTANT => constantInstruction("OP_CONSTANT", chunk, offset),
        .OP_TRUE => simpleInstruction("OP_TRUE", offset),
        .OP_FALSE => simpleInstruction("OP_FALSE", offset),
        .OP_NIL => simpleInstruction("OP_NIL", offset),
        .OP_ADD => simpleInstruction("OP_ADD", offset),
        .OP_SUBTRACT => simpleInstruction("OP_SUBTRACT", offset),
        .OP_MULTIPLY => simpleInstruction("OP_MULTIPLY", offset),
        .OP_DIVIDE => simpleInstruction("OP_DIVIDE", offset),
        .OP_NEGATE => simpleInstruction("OP_NEGATE", offset),
        // else => {
        //     std.debug.print("Unknown opcode {}\n", .{instruction});
        //     return offset + 1;
        // },
    };
}
pub fn simpleInstruction(name: []const u8, offset: u32) u32 {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}

pub fn constantInstruction(name: []const u8, chunk: *Chunk, offset: u32) u32 {
    const constant = chunk.code[offset + 1];
    std.debug.print("{s:<16} {d:4} '", .{ name, constant });
    value.printValue(chunk.constants.values[constant]);
    std.debug.print("'\n", .{});
    return offset + 2;
}
