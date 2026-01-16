//! QASM parser for OpenQASM 2.0.
//!
//! Parses a stream of tokens from the lexer and constructs a quantum circuit.

const std = @import("std");
const lexer = @import("lexer.zig");
const builder = @import("../circuit/builder.zig");

pub const ParserError = error{
    UnexpectedToken,
    InvalidSyntax,
    QubitOutOfRange,
    CregNotSupported, // We only support state vector simulation for now
    OutOfMemory,
};

/// QASM Parser state.
pub fn Parser(comptime n: comptime_int, comptime P: type) type {
    const Circuit = builder.Circuit(n, P);

    return struct {
        lexer: lexer.Lexer,
        currentToken: lexer.Token,
        circuit: *Circuit,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, source: []const u8, circ: *Circuit) Self {
            var p = Self{
                .lexer = lexer.Lexer.init(source),
                .currentToken = undefined,
                .circuit = circ,
                .allocator = allocator,
            };
            p.currentToken = p.lexer.nextToken();
            return p;
        }

        fn consume(self: *Self, tt: lexer.TokenType) !lexer.Token {
            if (self.currentToken.type == tt) {
                const token = self.currentToken;
                self.currentToken = self.lexer.nextToken();
                return token;
            }
            return ParserError.UnexpectedToken;
        }

        /// Parse the source and populate the circuit.
        pub fn parse(self: *Self) !void {
            while (self.currentToken.type != .EOF) {
                try self.parseStatement();
            }
        }

        fn parseStatement(self: *Self) !void {
            switch (self.currentToken.type) {
                .OPENQASM => {
                    _ = try self.consume(.OPENQASM);
                    _ = try self.consume(.REAL);
                    _ = try self.consume(.SEMICOLON);
                },
                .INCLUDE => {
                    _ = try self.consume(.INCLUDE);
                    _ = try self.consume(.STRING);
                    _ = try self.consume(.SEMICOLON);
                },
                .QREG => {
                    _ = try self.consume(.QREG);
                    _ = try self.consume(.ID);
                    _ = try self.consume(.LBRACKET);
                    const size_token = try self.consume(.NNINTEGER);
                    _ = try self.consume(.RBRACKET);
                    _ = try self.consume(.SEMICOLON);

                    const size = try std.fmt.parseInt(usize, size_token.text, 10);
                    if (size > n) return ParserError.QubitOutOfRange;
                },
                .CREG => {
                    _ = try self.consume(.CREG);
                    _ = try self.consume(.ID);
                    _ = try self.consume(.LBRACKET);
                    _ = try self.consume(.NNINTEGER);
                    _ = try self.consume(.RBRACKET);
                    _ = try self.consume(.SEMICOLON);
                },
                .BARRIER => {
                    _ = try self.consume(.BARRIER);
                    while (self.currentToken.type != .SEMICOLON) {
                        _ = self.lexer.nextToken(); // Skip IDs and commas
                        self.currentToken = self.lexer.nextToken();
                    }
                    _ = try self.consume(.SEMICOLON);
                },
                .MEASURE => {
                    _ = try self.consume(.MEASURE);
                    _ = try self.consume(.ID);
                    if (self.currentToken.type == .LBRACKET) {
                        _ = try self.consume(.LBRACKET);
                        _ = try self.consume(.NNINTEGER);
                        _ = try self.consume(.RBRACKET);
                    }
                    _ = try self.consume(.ARROW);
                    _ = try self.consume(.ID); // creg ID
                    if (self.currentToken.type == .LBRACKET) {
                        _ = try self.consume(.LBRACKET);
                        _ = try self.consume(.NNINTEGER);
                        _ = try self.consume(.RBRACKET);
                    }
                    _ = try self.consume(.SEMICOLON);

                    // Note: We don't store classical bits yet, just perform the collapse
                    // In a real simulator, we'd need a random source here.
                    // For parsing, we'll skip the actual measurement or use a dummy RNG.
                },
                .ID => {
                    // This is likely a gate application
                    const gate_name = try self.consume(.ID);

                    // Parse qubits
                    var qubits = std.ArrayListUnmanaged(usize){};
                    defer qubits.deinit(self.allocator);

                    while (true) {
                        _ = try self.consume(.ID);
                        var idx: usize = 0;
                        if (self.currentToken.type == .LBRACKET) {
                            _ = try self.consume(.LBRACKET);
                            const idx_token = try self.consume(.NNINTEGER);
                            _ = try self.consume(.RBRACKET);
                            idx = try std.fmt.parseInt(usize, idx_token.text, 10);
                        }
                        try qubits.append(self.allocator, idx);

                        if (self.currentToken.type == .COMMA) {
                            _ = try self.consume(.COMMA);
                        } else {
                            break;
                        }
                    }
                    _ = try self.consume(.SEMICOLON);

                    // Apply to circuit
                    if (std.mem.eql(u8, gate_name.text, "h")) {
                        _ = self.circuit.h(qubits.items[0]);
                    } else if (std.mem.eql(u8, gate_name.text, "x")) {
                        _ = self.circuit.x(qubits.items[0]);
                    } else if (std.mem.eql(u8, gate_name.text, "cx")) {
                        _ = self.circuit.cnot(qubits.items[0], qubits.items[1]);
                    }
                },
                else => return ParserError.InvalidSyntax,
            }
        }
    };
}

test "unit: qasm parser basic" {
    const source = "OPENQASM 2.0; qreg q[2]; h q[0]; cx q[0],q[1];";
    var circuit = builder.Circuit(2, f64).init(std.testing.allocator);
    defer circuit.deinit();

    var parser = Parser(2, f64).init(std.testing.allocator, source, &circuit);
    try parser.parse();

    try std.testing.expectEqual(@as(usize, 2), circuit.ops.items.len);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), circuit.probability(0), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), circuit.probability(3), 1e-10);
}
