const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const VM = @import("vm.zig").VM;
const debug = @import("debug.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var vm = VM.init(allocator);
    defer vm.deinit();
    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    var constant = chunk.addConstant(1.2);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(@intCast(constant), 1);
    // chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    constant = chunk.addConstant(3.2);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(@intCast(constant), 1);
    // chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    chunk.write(@intFromEnum(OpCode.OP_ADD), 1);

    constant = chunk.addConstant(5.6);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(@intCast(constant), 1);

    chunk.write(@intFromEnum(OpCode.OP_DIVIDE), 1);
    chunk.write(@intFromEnum(OpCode.OP_NEGATE), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    debug.disassembleChunk(&chunk, "test chunk");
    _ = vm.interpret(&chunk);
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // // stdout is for the actual output of your application, for example if you
    // // are implementing gzip, then only the compressed bytes should be sent to
    // // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    // try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
