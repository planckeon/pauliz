//! QASM lexer for OpenQASM 2.0 and 3.0.
//!
//! Tokenizes QASM source code into a stream of tokens for the parser.

const std = @import("std");

/// QASM token types.
pub const TokenType = enum {
    // Keywords
    OPENQASM,
    INCLUDE,
    QREG,
    CREG,
    GATE,
    OPAQUE,
    BARRIER,
    RESET,
    MEASURE,
    IF,

    // Symbols
    SEMICOLON,
    COMMA,
    LPAREN,
    RPAREN,
    LBRACE,
    RBRACE,
    LBRACKET,
    RBRACKET,
    ARROW,
    EQUAL,

    // Values
    ID,
    REAL,
    NNINTEGER,
    STRING,

    // Special
    EOF,
    INVALID,
};

/// A QASM token.
pub const Token = struct {
    type: TokenType,
    text: []const u8,
    line: usize,
    col: usize,
};

/// QASM lexer state.
pub const Lexer = struct {
    source: []const u8,
    pos: usize = 0,
    line: usize = 1,
    col: usize = 1,

    const Self = @This();

    pub fn init(source: []const u8) Self {
        return .{ .source = source };
    }

    fn peek(self: *const Self) u8 {
        if (self.pos >= self.source.len) return 0;
        return self.source[self.pos];
    }

    fn advance(self: *Self) u8 {
        if (self.pos >= self.source.len) return 0;
        const char = self.source[self.pos];
        self.pos += 1;
        if (char == '\n') {
            self.line += 1;
            self.col = 1;
        } else {
            self.col += 1;
        }
        return char;
    }

    fn skipWhitespace(self: *Self) void {
        while (true) {
            const char = self.peek();
            switch (char) {
                ' ', '\t', '\r', '\n' => _ = self.advance(),
                '/' => {
                    if (self.pos + 1 < self.source.len and self.source[self.pos + 1] == '/') {
                        // Skip comment
                        while (self.peek() != '\n' and self.peek() != 0) _ = self.advance();
                    } else {
                        break;
                    }
                },
                else => break,
            }
        }
    }

    pub fn nextToken(self: *Self) Token {
        self.skipWhitespace();

        const start_pos = self.pos;
        const start_line = self.line;
        const start_col = self.col;

        const char = self.advance();
        if (char == 0) return Token{ .type = .EOF, .text = "", .line = start_line, .col = start_col };

        switch (char) {
            ';' => return Token{ .type = .SEMICOLON, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col },
            ',' => return Token{ .type = .COMMA, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col },
            '(' => return Token{ .type = .LPAREN, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col },
            ')' => return Token{ .type = .RPAREN, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col },
            '{' => return Token{ .type = .LBRACE, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col },
            '}' => return Token{ .type = .RBRACE, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col },
            '[' => return Token{ .type = .LBRACKET, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col },
            ']' => return Token{ .type = .RBRACKET, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col },
            '-' => {
                if (self.peek() == '>') {
                    _ = self.advance();
                    return Token{ .type = .ARROW, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col };
                }
                return Token{ .type = .INVALID, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col };
            },
            '=' => {
                if (self.peek() == '=') {
                    _ = self.advance();
                    return Token{ .type = .EQUAL, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col };
                }
                return Token{ .type = .EQUAL, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col };
            },
            '"' => {
                // String literal
                while (self.peek() != '"' and self.peek() != 0) _ = self.advance();
                if (self.peek() == '"') _ = self.advance();
                return Token{ .type = .STRING, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col };
            },
            else => {
                if (std.ascii.isAlphabetic(char)) {
                    while (std.ascii.isAlphanumeric(self.peek()) or self.peek() == '_') _ = self.advance();
                    const text = self.source[start_pos..self.pos];

                    const tt = if (std.mem.eql(u8, text, "OPENQASM")) TokenType.OPENQASM else if (std.mem.eql(u8, text, "include")) TokenType.INCLUDE else if (std.mem.eql(u8, text, "qreg")) TokenType.QREG else if (std.mem.eql(u8, text, "creg")) TokenType.CREG else if (std.mem.eql(u8, text, "gate")) TokenType.GATE else if (std.mem.eql(u8, text, "opaque")) TokenType.OPAQUE else if (std.mem.eql(u8, text, "barrier")) TokenType.BARRIER else if (std.mem.eql(u8, text, "reset")) TokenType.RESET else if (std.mem.eql(u8, text, "measure")) TokenType.MEASURE else if (std.mem.eql(u8, text, "if")) TokenType.IF else TokenType.ID;

                    return Token{ .type = tt, .text = text, .line = start_line, .col = start_col };
                } else if (std.ascii.isDigit(char)) {
                    var has_dot = false;
                    while (std.ascii.isDigit(self.peek()) or (self.peek() == '.' and !has_dot)) {
                        if (self.peek() == '.') has_dot = true;
                        _ = self.advance();
                    }
                    return Token{ .type = if (has_dot) .REAL else .NNINTEGER, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col };
                }
            },
        }

        return Token{ .type = .INVALID, .text = self.source[start_pos..self.pos], .line = start_line, .col = start_col };
    }
};

test "unit: qasm lexer basic" {
    const source = "OPENQASM 2.0; qreg q[2]; creg c[2]; h q[0]; cx q[0],q[1]; measure q -> c;";
    var lexer = Lexer.init(source);

    const expected = [_]TokenType{
        .OPENQASM,  .REAL,      .SEMICOLON,
        .QREG,      .ID,        .LBRACKET,
        .NNINTEGER, .RBRACKET,  .SEMICOLON,
        .CREG,      .ID,        .LBRACKET,
        .NNINTEGER, .RBRACKET,  .SEMICOLON,
        .ID,        .ID,        .LBRACKET,
        .NNINTEGER, .RBRACKET,  .SEMICOLON,
        .ID,        .ID,        .LBRACKET,
        .NNINTEGER, .RBRACKET,  .COMMA,
        .ID,        .LBRACKET,  .NNINTEGER,
        .RBRACKET,  .SEMICOLON, .MEASURE,
        .ID,        .ARROW,     .ID,
        .SEMICOLON, .EOF,
    };

    for (expected) |tt| {
        const token = lexer.nextToken();
        try std.testing.expectEqual(tt, token.type);
    }
}
