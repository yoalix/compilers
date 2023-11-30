const stdout = @import("common.zig").stdout;
const Scanner = @import("scanner.zig").Scanner;
const TokenType = @import("scanner.zig").TokenType;

pub fn compile(source: [:0]u8) !void {
    var scanner = Scanner.init(source);
    // try stdout.print("current {d} len {d}\n", .{ @intFromPtr(scanner.current) - @intFromPtr(scanner.start), scanner.len });
    // var c = scanner.advance();
    // try stdout.print("char {c} current {d} len {d}\n", .{ c, @intFromPtr(scanner.current) - @intFromPtr(scanner.start), scanner.len });
    // c = scanner.advance();
    // try stdout.print("char {c} current {d} len {d}\n", .{ c, @intFromPtr(scanner.current) - @intFromPtr(scanner.start), scanner.len });
    // c = scanner.advance();
    // try stdout.print("char {c} current {d} len {d}\n", .{ c, @intFromPtr(scanner.current) - @intFromPtr(scanner.start), scanner.len });
    // c = scanner.advance();
    // try stdout.print("char {c} current {d} len {d}\n", .{ c, @intFromPtr(scanner.current) - @intFromPtr(scanner.start), scanner.len });
    // c = scanner.advance();
    // try stdout.print("char {c} current {d} len {d}\n", .{ c, @intFromPtr(scanner.current) - @intFromPtr(scanner.start), scanner.len });
    // try stdout.print("at end {}\n", .{scanner.isAtEnd()});
    var line: u32 = undefined;

    while (true) {
        var token = scanner.scanToken();
        if (token.line != line) {
            try stdout.print("{:>4} ", .{token.line});
            line = token.line;
        } else {
            try stdout.print("   | ", .{});
        }
        try stdout.print("{:0>2} '{s}'\n", .{ token.type, token.start[0..token.length] });
        if (token.type == TokenType.EOF) {
            break;
        }
    }
}
