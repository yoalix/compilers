const std = @import("std");
const common = @import("common.zig");
const stdout = common.stdout;

pub const TokenType = enum { // Single-character tokens.
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,
    // One or two character tokens.
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,
    // Literals.
    IDENTIFIER,
    STRING,
    NUMBER,
    // Keywords.
    AND,
    STRUCT,
    ELSE,
    FALSE,
    FOR,
    FN,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    TRUE,
    VAR,
    WHILE,

    ERROR,
    EOF,
};

pub const Token = struct {
    type: TokenType,
    start: [*]const u8,
    length: usize,
    line: u32,
};

pub const Scanner = struct {
    const Self = @This();
    start: [*]u8,
    current: [*]u8,
    len: usize,
    line: u32,

    pub fn init(source: [:0]u8) Self {
        return Self{
            .start = source.ptr,
            .current = source.ptr,
            .len = source.len,
            .line = 1,
        };
    }

    pub fn scanToken(self: *Self) Token {
        self.skipWhitespace();

        self.start = self.current;

        if (self.isAtEnd()) {
            return self.makeToken(TokenType.EOF);
        }

        var c = self.advance();
        if (isAlpha(c)) {
            return self.identifier();
        }
        if (isDigit(c)) {
            return self.number();
        }

        switch (c) {
            '(' => return self.makeToken(TokenType.LEFT_PAREN),
            ')' => return self.makeToken(TokenType.RIGHT_PAREN),
            '{' => return self.makeToken(TokenType.LEFT_BRACE),
            '}' => return self.makeToken(TokenType.RIGHT_BRACE),
            ';' => return self.makeToken(TokenType.SEMICOLON),
            ',' => return self.makeToken(TokenType.COMMA),
            '.' => return self.makeToken(TokenType.DOT),
            '-' => return self.makeToken(TokenType.MINUS),
            '+' => return self.makeToken(TokenType.PLUS),
            '/' => return self.makeToken(TokenType.SLASH),
            '*' => return self.makeToken(TokenType.STAR),
            '!' => return self.makeToken(if (self.match('=')) TokenType.BANG_EQUAL else TokenType.BANG),
            '=' => return self.makeToken(if (self.match('=')) TokenType.EQUAL_EQUAL else TokenType.EQUAL),
            '<' => return self.makeToken(if (self.match('=')) TokenType.LESS_EQUAL else TokenType.LESS),
            '>' => return self.makeToken(if (self.match('=')) TokenType.GREATER_EQUAL else TokenType.GREATER),
            '"' => return self.string(),
            else => return self.errorToken("Unexpected character."),
        }

        return self.errorToken("Unexpected character.");
    }

    fn number(self: *Self) Token {
        while (isDigit(self.peek())) {
            _ = self.advance();
        }

        // Look for a fractional part.
        if (self.peek() == '.' and isDigit(self.peekNext())) {
            // Consume the "."
            _ = self.advance();

            while (isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        return self.makeToken(TokenType.NUMBER);
    }

    fn string(self: *Self) Token {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') {
                self.line += 1;
            }
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            return self.errorToken("Unterminated string.");
        }

        // The closing ".
        _ = self.advance();
        return self.makeToken(TokenType.STRING);
    }

    fn identifier(self: *Self) Token {
        while (isAlpha(self.peek()) or isDigit(self.peek())) {
            _ = self.advance();
        }

        return self.makeToken(self.identifierType());
    }

    fn identifierType(self: *Self) TokenType {
        switch (self.start[0]) {
            'a' => return self.checkKeyword(1, 2, "nd", TokenType.AND),
            'e' => return self.checkKeyword(1, 3, "lse", TokenType.ELSE),
            'f' => {
                if (@intFromPtr(self.current) - @intFromPtr(self.start) > 1) {
                    switch (self.start[1]) {
                        'a' => return self.checkKeyword(2, 3, "lse", TokenType.FALSE),
                        'n' => return self.checkKeyword(2, 1, "n", TokenType.FN),
                        'o' => return self.checkKeyword(2, 1, "r", TokenType.FOR),
                        else => return TokenType.IDENTIFIER,
                    }
                }
            },
            'i' => return self.checkKeyword(1, 1, "f", TokenType.IF),
            'n' => return self.checkKeyword(1, 2, "il", TokenType.NIL),
            'o' => return self.checkKeyword(1, 1, "r", TokenType.OR),
            'p' => return self.checkKeyword(1, 4, "rint", TokenType.PRINT),
            'r' => return self.checkKeyword(1, 5, "eturn", TokenType.RETURN),
            't' => return self.checkKeyword(1, 3, "rue", TokenType.TRUE),
            'v' => return self.checkKeyword(1, 2, "ar", TokenType.VAR),
            'w' => return self.checkKeyword(1, 4, "hile", TokenType.WHILE),
            else => return TokenType.IDENTIFIER,
        }

        return TokenType.IDENTIFIER;
    }

    fn makeToken(self: *Self, tokenType: TokenType) Token {
        return Token{
            .type = tokenType,
            .start = self.start,
            .length = @intFromPtr(self.current) - @intFromPtr(self.start),
            .line = self.line,
        };
    }

    fn errorToken(self: *Self, message: []const u8) Token {
        return Token{
            .type = TokenType.ERROR,
            .start = message.ptr,
            .length = message.len,
            .line = self.line,
        };
    }

    fn checkKeyword(self: *Self, start: u32, comptime length: u32, rest: *const [length:0]u8, tokenType: TokenType) TokenType {
        if (std.mem.eql(u8, self.start[start .. start + length], rest)) {
            return tokenType;
        }
        return TokenType.IDENTIFIER;
    }

    pub fn advance(self: *Self) u8 {
        const result = self.current[0];
        self.current += 1;
        return result;
    }

    fn match(self: *Self, expected: u8) bool {
        if (self.isAtEnd()) {
            return false;
        }
        if (self.current[0] != expected) {
            return false;
        }

        self.current += 1;
        return true;
    }

    fn peek(self: *Self) u8 {
        return self.current[0];
    }

    fn peekNext(self: *Self) u8 {
        if (self.isAtEnd()) {
            return 0;
        }
        return self.current[1];
    }

    pub fn isAtEnd(self: *Self) bool {
        return self.current[0] == 0;
    }

    fn skipWhitespace(self: *Self) void {
        while (true) {
            var c = self.peek();
            switch (c) {
                ' ' => _ = self.advance(),
                '\r' => _ = self.advance(),
                '\t' => _ = self.advance(),
                '\n' => {
                    self.line += 1;
                    _ = self.advance();
                },
                '/' => {
                    if (self.peekNext() == '/') {
                        // A comment goes until the end of the line.
                        while (self.peek() != '\n' and !self.isAtEnd()) {
                            _ = self.advance();
                        }
                    } else {
                        return;
                    }
                },
                else => return,
            }
        }
    }
};

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}
