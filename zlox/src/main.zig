const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const VM = @import("vm.zig").VM;
const debug = @import("debug.zig");

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var args = try std.process.argsWithAllocator(allocator);

    var vm = VM.init(allocator);
    defer vm.deinit();
    if (args.inner.count == 1) {
        try repl(&vm);
    } else if (args.inner.count == 2) {
        _ = args.skip();
        try runFile(allocator, &vm, args.next().?);
    } else {
        std.debug.print("Usage: clox [path]\n", .{});
        std.os.exit(64);
    }
    // var chunk = Chunk.init(allocator);
    // defer chunk.deinit();

    // var constant = chunk.addConstant(1.2);
    // chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    // chunk.write(@intCast(constant), 1);
    // // chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    // constant = chunk.addConstant(3.2);
    // chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    // chunk.write(@intCast(constant), 1);
    // // chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    // chunk.write(@intFromEnum(OpCode.OP_ADD), 1);

    // constant = chunk.addConstant(5.6);
    // chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    // chunk.write(@intCast(constant), 1);

    // chunk.write(@intFromEnum(OpCode.OP_DIVIDE), 1);
    // chunk.write(@intFromEnum(OpCode.OP_NEGATE), 1);
    // chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    // debug.disassembleChunk(&chunk, "test chunk");
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

fn repl(vm: *VM) !void {

    // Create an arraylist of characters to store the output
    // Remember to clean up this arraylist once you're done with it!
    var line: [1024]u8 = undefined;

    while (true) {
        try stdout.print("> ", .{});
        // Try to read user input into that arraylist, accepting up to 1024 characters in this example
        // You can get the resulting bytes as a slice with `line.items`
        if (stdin.readUntilDelimiterOrEof(&line, '\n') catch null) |list| {
            var source = line[0 .. list.len + 1];
            if (std.mem.eql(u8, source, "exit")) {
                break;
            }
            source[list.len] = 0;
            // try stdout.print("{s}\n", .{source});
            _ = try vm.interpret(source[0..list.len :0]);

            // If the user pressed Ctrl-C, then we'll get a null error
            // We'll just exit in that case
        }
    }
}

fn runFile(alloc: std.mem.Allocator, vm: *VM, path: []const u8) !void {
    _ = vm;
    var source = try readFile(alloc, path);
    _ = source;
    // try vm.interpret(source);
}

fn readFile(alloc: std.mem.Allocator, path: []const u8) ![]const u8 {
    var file = try std.fs.cwd().readFileAlloc(alloc, path, 1_000_000);

    return file;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
