//! Single-qubit quantum gates.
//!
//! Provides standard single-qubit gate matrices (Pauli gates, Hadamard, phase gates,
//! rotation gates) and convenient methods to apply them to quantum states.

const std = @import("std");
const complex = @import("../core/complex.zig");
const state = @import("../core/state.zig");

/// Gate type containing a 2x2 complex matrix.
pub fn Gate(comptime P: type) type {
    const C = complex.Complex(P);

    return struct {
        matrix: [2][2]C,

        const Self = @This();

        // ============================================================
        // Standard Gates
        // ============================================================

        /// Identity gate I
        pub const Identity = Self{
            .matrix = .{
                .{ C.one, C.zero },
                .{ C.zero, C.one },
            },
        };

        /// Pauli-X gate (NOT gate, bit flip)
        /// X|0⟩ = |1⟩, X|1⟩ = |0⟩
        pub const PauliX = Self{
            .matrix = .{
                .{ C.zero, C.one },
                .{ C.one, C.zero },
            },
        };

        /// Pauli-Y gate
        /// Y|0⟩ = i|1⟩, Y|1⟩ = -i|0⟩
        pub const PauliY = Self{
            .matrix = .{
                .{ C.zero, C.init(0, -1) },
                .{ C.init(0, 1), C.zero },
            },
        };

        /// Pauli-Z gate (phase flip)
        /// Z|0⟩ = |0⟩, Z|1⟩ = -|1⟩
        pub const PauliZ = Self{
            .matrix = .{
                .{ C.one, C.zero },
                .{ C.zero, C.init(-1, 0) },
            },
        };

        /// Hadamard gate
        /// H|0⟩ = (|0⟩+|1⟩)/√2, H|1⟩ = (|0⟩-|1⟩)/√2
        pub const Hadamard = blk: {
            const s: P = 1.0 / @sqrt(2.0);
            break :blk Self{
                .matrix = .{
                    .{ C.init(s, 0), C.init(s, 0) },
                    .{ C.init(s, 0), C.init(-s, 0) },
                },
            };
        };

        /// S gate (√Z, phase gate)
        /// S|0⟩ = |0⟩, S|1⟩ = i|1⟩
        pub const S = Self{
            .matrix = .{
                .{ C.one, C.zero },
                .{ C.zero, C.i },
            },
        };

        /// S† gate (S-dagger, inverse of S)
        pub const Sdg = Self{
            .matrix = .{
                .{ C.one, C.zero },
                .{ C.zero, C.init(0, -1) },
            },
        };

        /// T gate (π/8 gate, √S)
        /// T|0⟩ = |0⟩, T|1⟩ = e^(iπ/4)|1⟩
        pub const T = blk: {
            const angle: P = std.math.pi / 4.0;
            break :blk Self{
                .matrix = .{
                    .{ C.one, C.zero },
                    .{ C.zero, C.init(@cos(angle), @sin(angle)) },
                },
            };
        };

        /// T† gate (T-dagger, inverse of T)
        pub const Tdg = blk: {
            const angle: P = -std.math.pi / 4.0;
            break :blk Self{
                .matrix = .{
                    .{ C.one, C.zero },
                    .{ C.zero, C.init(@cos(angle), @sin(angle)) },
                },
            };
        };

        // ============================================================
        // Rotation Gates
        // ============================================================

        /// Rx(θ) - Rotation around X-axis
        /// Rx(θ) = cos(θ/2)I - i·sin(θ/2)X
        pub fn rx(theta: P) Self {
            const c = @cos(theta / 2.0);
            const s = @sin(theta / 2.0);
            return Self{
                .matrix = .{
                    .{ C.init(c, 0), C.init(0, -s) },
                    .{ C.init(0, -s), C.init(c, 0) },
                },
            };
        }

        /// Ry(θ) - Rotation around Y-axis
        /// Ry(θ) = cos(θ/2)I - i·sin(θ/2)Y
        pub fn ry(theta: P) Self {
            const c = @cos(theta / 2.0);
            const s = @sin(theta / 2.0);
            return Self{
                .matrix = .{
                    .{ C.init(c, 0), C.init(-s, 0) },
                    .{ C.init(s, 0), C.init(c, 0) },
                },
            };
        }

        /// Rz(θ) - Rotation around Z-axis
        /// Rz(θ) = e^(-iθ/2)|0⟩⟨0| + e^(iθ/2)|1⟩⟨1|
        pub fn rz(theta: P) Self {
            const half = theta / 2.0;
            return Self{
                .matrix = .{
                    .{ C.init(@cos(-half), @sin(-half)), C.zero },
                    .{ C.zero, C.init(@cos(half), @sin(half)) },
                },
            };
        }

        /// Phase gate P(φ) - Also known as Rφ
        /// P(φ)|0⟩ = |0⟩, P(φ)|1⟩ = e^(iφ)|1⟩
        pub fn phase(phi: P) Self {
            return Self{
                .matrix = .{
                    .{ C.one, C.zero },
                    .{ C.zero, C.init(@cos(phi), @sin(phi)) },
                },
            };
        }

        // ============================================================
        // Gate Operations
        // ============================================================

        /// Apply this gate to a quantum state at the specified qubit.
        pub fn apply(self: Self, comptime n: comptime_int, pstate: *state.QuantumState(n, P), qubit: usize) void {
            pstate.applySingleQubitGate(qubit, self.matrix);
        }

        /// Compute gate product: self * other
        pub fn mul(self: Self, other: Self) Self {
            var result: Self = undefined;
            for (0..2) |i| {
                for (0..2) |j| {
                    result.matrix[i][j] = self.matrix[i][0].mul(other.matrix[0][j])
                        .add(self.matrix[i][1].mul(other.matrix[1][j]));
                }
            }
            return result;
        }

        /// Compute conjugate transpose (Hermitian adjoint) U†
        pub fn dagger(self: Self) Self {
            return Self{
                .matrix = .{
                    .{ self.matrix[0][0].conj(), self.matrix[1][0].conj() },
                    .{ self.matrix[0][1].conj(), self.matrix[1][1].conj() },
                },
            };
        }

        /// Check if gate is approximately unitary (U†U ≈ I)
        pub fn isUnitary(self: Self, epsilon: P) bool {
            const product = self.dagger().mul(self);
            return product.matrix[0][0].approxEq(C.one, epsilon) and
                product.matrix[0][1].approxEq(C.zero, epsilon) and
                product.matrix[1][0].approxEq(C.zero, epsilon) and
                product.matrix[1][1].approxEq(C.one, epsilon);
        }

        /// Check approximate equality of two gates
        pub fn approxEq(self: Self, other: Self, epsilon: P) bool {
            return self.matrix[0][0].approxEq(other.matrix[0][0], epsilon) and
                self.matrix[0][1].approxEq(other.matrix[0][1], epsilon) and
                self.matrix[1][0].approxEq(other.matrix[1][0], epsilon) and
                self.matrix[1][1].approxEq(other.matrix[1][1], epsilon);
        }
    };
}

// Type aliases for convenience
pub const Gate64 = Gate(f64);
pub const Gate32 = Gate(f32);

// ============================================================
// Symbolic Tests
// ============================================================

test "symbolic: all standard gates are unitary (U†U = I)" {
    const G = Gate64;
    const eps = 1e-10;

    try std.testing.expect(G.Identity.isUnitary(eps));
    try std.testing.expect(G.PauliX.isUnitary(eps));
    try std.testing.expect(G.PauliY.isUnitary(eps));
    try std.testing.expect(G.PauliZ.isUnitary(eps));
    try std.testing.expect(G.Hadamard.isUnitary(eps));
    try std.testing.expect(G.S.isUnitary(eps));
    try std.testing.expect(G.Sdg.isUnitary(eps));
    try std.testing.expect(G.T.isUnitary(eps));
    try std.testing.expect(G.Tdg.isUnitary(eps));
}

test "symbolic: X·X = I" {
    const G = Gate64;
    const result = G.PauliX.mul(G.PauliX);
    try std.testing.expect(result.approxEq(G.Identity, 1e-10));
}

test "symbolic: Y·Y = I" {
    const G = Gate64;
    const result = G.PauliY.mul(G.PauliY);
    try std.testing.expect(result.approxEq(G.Identity, 1e-10));
}

test "symbolic: Z·Z = I" {
    const G = Gate64;
    const result = G.PauliZ.mul(G.PauliZ);
    try std.testing.expect(result.approxEq(G.Identity, 1e-10));
}

test "symbolic: H·H = I" {
    const G = Gate64;
    const result = G.Hadamard.mul(G.Hadamard);
    try std.testing.expect(result.approxEq(G.Identity, 1e-10));
}

test "symbolic: S·S = Z" {
    const G = Gate64;
    const result = G.S.mul(G.S);
    try std.testing.expect(result.approxEq(G.PauliZ, 1e-10));
}

test "symbolic: T·T = S" {
    const G = Gate64;
    const result = G.T.mul(G.T);
    try std.testing.expect(result.approxEq(G.S, 1e-10));
}

test "symbolic: S·S† = I" {
    const G = Gate64;
    const result = G.S.mul(G.Sdg);
    try std.testing.expect(result.approxEq(G.Identity, 1e-10));
}

test "symbolic: T·T† = I" {
    const G = Gate64;
    const result = G.T.mul(G.Tdg);
    try std.testing.expect(result.approxEq(G.Identity, 1e-10));
}

test "symbolic: XYZ = iI (up to global phase)" {
    const G = Gate64;
    const C = complex.Complex(f64);
    const result = G.PauliX.mul(G.PauliY).mul(G.PauliZ);

    // XYZ = i·I
    const expected = G{
        .matrix = .{
            .{ C.i, C.zero },
            .{ C.zero, C.i },
        },
    };
    try std.testing.expect(result.approxEq(expected, 1e-10));
}

test "symbolic: rotation gates are unitary" {
    const G = Gate64;
    const eps = 1e-10;

    // Test at various angles
    const angles = [_]f64{ 0.0, std.math.pi / 4.0, std.math.pi / 2.0, std.math.pi, 2.0 * std.math.pi };

    for (angles) |theta| {
        try std.testing.expect(G.rx(theta).isUnitary(eps));
        try std.testing.expect(G.ry(theta).isUnitary(eps));
        try std.testing.expect(G.rz(theta).isUnitary(eps));
        try std.testing.expect(G.phase(theta).isUnitary(eps));
    }
}

test "symbolic: Rx(2π) = -I (up to global phase)" {
    const G = Gate64;
    const C = complex.Complex(f64);

    const result = G.rx(2.0 * std.math.pi);

    // Rx(2π) = -I
    const minus_i = G{
        .matrix = .{
            .{ C.init(-1, 0), C.zero },
            .{ C.zero, C.init(-1, 0) },
        },
    };
    try std.testing.expect(result.approxEq(minus_i, 1e-10));
}

test "symbolic: dagger inverts gate (U·U† = I)" {
    const G = Gate64;
    const eps = 1e-10;

    // Test with Hadamard (self-inverse anyway)
    const h_dag = G.Hadamard.dagger();
    try std.testing.expect(G.Hadamard.mul(h_dag).approxEq(G.Identity, eps));

    // Test with a rotation gate
    const rx_gate = G.rx(std.math.pi / 3.0);
    const rx_dag = rx_gate.dagger();
    try std.testing.expect(rx_gate.mul(rx_dag).approxEq(G.Identity, eps));
}

test "unit: gate application to state" {
    const G = Gate64;
    const State = state.QuantumState(1, f64);

    var s = State.init(); // |0⟩
    G.PauliX.apply(1, &s, 0);

    // Should now be |1⟩
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), s.probability(0), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), s.probability(1), 1e-10);
}
