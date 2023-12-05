const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const TokenType = @import("scanner.zig").TokenType;
const Token = @import("scanner.zig").Token;
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;

pub const Precedence = enum {
    NONE,
    ASSIGNMENT, // =
    OR, // or
    AND, // and
    EQUALITY, // == !=
    COMPARISON, // < > <= >=
    TERM, // + -
    FACTOR, // * /
    UNARY, // ! -
    CALL, // . ()
    PRIMARY,
};

pub const TokenCount: usize = 38;

const ParseFn = *const fn (*Compiler) void;

const Rule = struct {
    prefix: ?ParseFn,
    infix: ?ParseFn,
    precedence: Precedence,
};

pub const Compiler = struct {
    const Self = @This();
    scanner: Scanner,
    compilingChunk: *Chunk,
    current: Token,
    previous: Token,
    hadError: bool,
    panicMode: bool,

    pub fn init(source: [:0]u8, chunk: *Chunk) Self {
        return Self{
            .scanner = Scanner.init(source),
            .compilingChunk = chunk,
            .current = undefined,
            .previous = undefined,
            .hadError = false,
            .panicMode = false,
        };
    }

    pub fn compile(self: *Self) bool {
        self.advance();
        self.expression();
        self.consume(TokenType.EOF, "Expect end of expression.");
        self.endCompiler();
        return !self.hadError;
    }

    pub fn endCompiler(self: *Self) void {
        self.emitReturn();
    }

    pub fn consume(self: *Self, tokenType: TokenType, message: []const u8) void {
        if (self.current.type == tokenType) {
            self.advance();
            return;
        }

        self.errorAtCurrent(message);
    }

    pub fn expression(self: *Self) void {
        self.parsePrecedence(Precedence.ASSIGNMENT);
    }

    pub fn advance(self: *Self) void {
        self.previous = self.current;

        while (true) {
            self.current = self.scanner.scanToken();
            if (self.current.type != TokenType.ERROR) {
                break;
            }
            self.errorAtCurrent(self.current.start[0..self.current.length]);
        }
    }

    pub fn parsePrecedence(self: *Self, precedence: Precedence) void {
        self.advance();
        var prefixRule = getRule(self.previous.type).prefix;
        if (prefixRule == null) {
            self.compilerError("Expect expression.");
            return;
        }

        prefixRule.?(self);
        while (@intFromEnum(precedence) <= @intFromEnum(getRule(self.current.type).precedence)) {
            self.advance();
            var infixRule = getRule(self.previous.type).infix;
            infixRule.?(self);
        }
    }

    fn grouping(self: *Self) void {
        self.expression();
        self.consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.");
    }

    fn number(self: *Self) void {
        var value = std.fmt.parseFloat(f64, self.previous.start[0..self.previous.length]) catch {
            self.compilerError("Invalid character in number.");
            return;
        };
        self.emitConstant(Value{ .number = value });
    }

    fn literal(self: *Self) void {
        var operatorType = self.previous.type;
        switch (operatorType) {
            .FALSE => self.emitByte(@intFromEnum(OpCode.OP_FALSE)),
            .TRUE => self.emitByte(@intFromEnum(OpCode.OP_TRUE)),
            .NIL => self.emitByte(@intFromEnum(OpCode.OP_NIL)),
            else => unreachable,
        }
    }

    fn unary(self: *Self) void {
        var operatorType = self.previous.type;
        self.parsePrecedence(Precedence.UNARY);

        switch (operatorType) {
            .MINUS => self.emitByte(@intFromEnum(OpCode.OP_NEGATE)),
            else => unreachable,
        }
    }

    fn binary(self: *Self) void {
        var operatorType = self.previous.type;
        var rule = getRule(operatorType);
        self.parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

        switch (operatorType) {
            // .BANG_EQUAL => self.emitBytes(OpCode.OP_EQUAL, OpCode.NOT),
            // .EQUAL_EQUAL => self.emitByte(OpCode.OP_EQUAL),
            // .GREATER => self.emitByte(OpCode.OP_GREATER),
            // .GREATER_EQUAL => self.emitBytes(OpCode.OP_LESS, OpCode.OP_EQUAL),
            // .LESS => self.emitByte(OpCode.OP_LESS),
            // .LESS_EQUAL => self.emitBytes(OpCode.OP_GREATER, OpCode.NOT),
            .PLUS => self.emitByte(@intFromEnum(OpCode.OP_ADD)),
            .MINUS => self.emitByte(@intFromEnum(OpCode.OP_SUBTRACT)),
            .STAR => self.emitByte(@intFromEnum(OpCode.OP_MULTIPLY)),
            .SLASH => self.emitByte(@intFromEnum(OpCode.OP_DIVIDE)),
            else => unreachable,
        }
    }

    fn emitByte(self: *Self, byte: u8) void {
        self.compilingChunk.write(byte, self.previous.line);
    }

    fn emitBytes(self: *Self, byte1: u8, byte2: u8) void {
        self.emitByte(byte1);
        self.emitByte(byte2);
    }

    fn emitReturn(self: *Self) void {
        self.emitByte(@intFromEnum(OpCode.OP_RETURN));
    }

    fn emitConstant(self: *Self, value: Value) void {
        self.emitBytes(@intFromEnum(OpCode.OP_CONSTANT), self.makeConstant(value));
    }

    fn makeConstant(self: *Self, value: Value) u8 {
        var constant = self.compilingChunk.addConstant(value);
        if (constant > @sizeOf(u8)) {
            self.compilerError("Too many constants in one chunk.");
            return 0;
        }
        return @intCast(constant);
    }

    fn compilerError(self: *Self, message: []const u8) void {
        self.errorAt(self.previous, message);
    }

    fn errorAtCurrent(self: *Self, message: []const u8) void {
        self.errorAt(self.current, message);
    }

    fn errorAt(self: *Self, token: Token, message: []const u8) void {
        if (self.panicMode) {
            return;
        }
        self.panicMode = true;
        std.debug.print("[line {d}] Error", .{token.line});
        if (token.type == TokenType.EOF) {
            std.debug.print(" at end", .{});
        } else if (token.type == TokenType.ERROR) {
            // Nothing.
        } else {
            std.debug.print(" at '{s}'", .{token.start[0..token.length]});
        }
        std.debug.print(": {s}\n", .{message});
        self.hadError = true;
    }
};

fn getRule(tokenType: TokenType) *const Rule {
    return &rules[@intFromEnum(tokenType)];
}

const rules: [@intFromEnum(TokenType.EOF) + 1]Rule = blk: {
    comptime var tmp: [@intFromEnum(TokenType.EOF) + 1]Rule = .{.{ .prefix = null, .infix = null, .precedence = Precedence.NONE }} ** (@intFromEnum(TokenType.EOF));
    tmp[@intFromEnum(TokenType.LEFT_PAREN)] = Rule{ .prefix = Compiler.grouping, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.RIGHT_PAREN)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.LEFT_BRACE)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.RIGHT_BRACE)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.COMMA)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.DOT)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.MINUS)] = Rule{ .prefix = Compiler.unary, .infix = Compiler.binary, .precedence = Precedence.TERM };
    tmp[@intFromEnum(TokenType.PLUS)] = Rule{ .prefix = null, .infix = Compiler.binary, .precedence = Precedence.TERM };
    tmp[@intFromEnum(TokenType.SEMICOLON)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.SLASH)] = Rule{ .prefix = null, .infix = Compiler.binary, .precedence = Precedence.FACTOR };
    tmp[@intFromEnum(TokenType.STAR)] = Rule{ .prefix = null, .infix = Compiler.binary, .precedence = Precedence.FACTOR };
    tmp[@intFromEnum(TokenType.BANG)] = Rule{ .prefix = Compiler.unary, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.BANG_EQUAL)] = Rule{ .prefix = null, .infix = Compiler.binary, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.EQUAL)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.EQUAL_EQUAL)] = Rule{ .prefix = null, .infix = Compiler.binary, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.GREATER)] = Rule{ .prefix = null, .infix = Compiler.binary, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.GREATER_EQUAL)] = Rule{ .prefix = null, .infix = Compiler.binary, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.LESS)] = Rule{ .prefix = null, .infix = Compiler.binary, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.LESS_EQUAL)] = Rule{ .prefix = null, .infix = Compiler.binary, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.IDENTIFIER)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.STRING)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.NUMBER)] = Rule{ .prefix = Compiler.number, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.AND)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.ELSE)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.FALSE)] = Rule{ .prefix = Compiler.literal, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.FOR)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.FN)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.IF)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.NIL)] = Rule{ .prefix = Compiler.literal, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.OR)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.PRINT)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.RETURN)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.STRUCT)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.TRUE)] = Rule{ .prefix = Compiler.literal, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.VAR)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.WHILE)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };
    tmp[@intFromEnum(TokenType.ERROR)] = Rule{ .prefix = null, .infix = null, .precedence = Precedence.NONE };

    break :blk tmp;
};

// pub fn compile(source: [:0]u8) !void {
//     var scanner = Scanner.init(source);
//     _ = scanner;
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
// var line: u32 = undefined;

// while (true) {
//     var token = scanner.scanToken();
//     if (token.line != line) {
//         try stdout.print("{:>4} ", .{token.line});
//         line = token.line;
//     } else {
//         try stdout.print("   | ", .{});
//     }
//     try stdout.print("{:0>2} '{s}'\n", .{ token.type, token.start[0..token.length] });
//     if (token.type == TokenType.EOF) {
//         break;
//     }
// }
// }
