//! Quantum state vector representation.
//!
//! Provides both compile-time fixed-size and runtime dynamic quantum states.
//! States are represented as vectors of complex amplitudes in computational basis.

const std = @import("std");
const complex = @import("complex.zig");

/// Compile-time fixed-size quantum state for `n` qubits.
/// Size is 2^n amplitudes, enabling stack allocation and optimal performance.
pub fn QuantumState(comptime n: comptime_int, comptime P: type) type {
    const N: usize = 1 << n; // 2^n basis states
    const C = complex.Complex(P);

    return struct {
        amplitudes: [N]C,

        const Self = @This();

        /// Number of qubits in this state
        pub const num_qubits = n;
        /// Number of basis states (2^n)
        pub const num_states = N;
        /// Underlying complex type
        pub const ComplexType = C;

        // ============================================================
        // Constructors
        // ============================================================

        /// Initialize to |0...0⟩ ground state.
        pub fn init() Self {
            var state: Self = undefined;
            state.amplitudes[0] = C.one;
            for (state.amplitudes[1..]) |*amp| {
                amp.* = C.zero;
            }
            return state;
        }

        /// Initialize from a specific basis state index |k⟩.
        /// For n=2: 0=|00⟩, 1=|01⟩, 2=|10⟩, 3=|11⟩
        pub fn fromBasisState(k: usize) Self {
            std.debug.assert(k < N);
            var state: Self = undefined;
            for (&state.amplitudes, 0..) |*amp, i| {
                amp.* = if (i == k) C.one else C.zero;
            }
            return state;
        }

        /// Initialize from amplitude array directly.
        pub fn fromAmplitudes(amps: [N]C) Self {
            return .{ .amplitudes = amps };
        }

        // ============================================================
        // State Properties
        // ============================================================

        /// Total probability (should equal 1.0 for valid states).
        pub fn totalProbability(self: *const Self) P {
            var sum: P = 0.0;
            for (self.amplitudes) |amp| {
                sum += amp.normSq();
            }
            return sum;
        }

        /// Check if state is normalized within tolerance.
        pub fn isNormalized(self: *const Self, epsilon: P) bool {
            return @abs(self.totalProbability() - 1.0) < epsilon;
        }

        /// Normalize the state in-place.
        pub fn normalize(self: *Self) void {
            const norm = @sqrt(self.totalProbability());
            if (norm > 0) {
                const inv_norm = 1.0 / norm;
                for (&self.amplitudes) |*amp| {
                    amp.* = amp.scale(inv_norm);
                }
            }
        }

        /// Get probability of measuring basis state |k⟩.
        pub fn probability(self: *const Self, k: usize) P {
            return self.amplitudes[k].normSq();
        }

        // ============================================================
        // State Operations
        // ============================================================

        /// Apply a single-qubit 2x2 gate matrix to qubit at index `qubit`.
        /// Gate matrix format: [[g00, g01], [g10, g11]]
        pub fn applySingleQubitGate(self: *Self, qubit: usize, gate: [2][2]C) void {
            std.debug.assert(qubit < n);

            // Iterate over pairs of amplitudes that differ only in bit `qubit`
            const step = @as(usize, 1) << @intCast(qubit);
            var i: usize = 0;
            while (i < N) : (i += 1) {
                // Skip if this index has bit `qubit` set (we process pairs from the 0-side)
                if ((i & step) != 0) continue;

                const idx0 = i;
                const idx1 = i | step;

                const a0 = self.amplitudes[idx0];
                const a1 = self.amplitudes[idx1];

                // Apply 2x2 matrix: [new0, new1]^T = gate * [a0, a1]^T
                self.amplitudes[idx0] = gate[0][0].mul(a0).add(gate[0][1].mul(a1));
                self.amplitudes[idx1] = gate[1][0].mul(a0).add(gate[1][1].mul(a1));
            }
        }

        /// Apply controlled single-qubit gate (control, target, gate).
        pub fn applyControlledGate(self: *Self, control: usize, target: usize, gate: [2][2]C) void {
            std.debug.assert(control < n and target < n);
            std.debug.assert(control != target);

            const control_bit = @as(usize, 1) << @intCast(control);
            const target_bit = @as(usize, 1) << @intCast(target);

            var i: usize = 0;
            while (i < N) : (i += 1) {
                // Only apply when control bit is set AND we're on the 0-side of target
                if ((i & control_bit) == 0) continue;
                if ((i & target_bit) != 0) continue;

                const idx0 = i;
                const idx1 = i | target_bit;

                const a0 = self.amplitudes[idx0];
                const a1 = self.amplitudes[idx1];

                self.amplitudes[idx0] = gate[0][0].mul(a0).add(gate[0][1].mul(a1));
                self.amplitudes[idx1] = gate[1][0].mul(a0).add(gate[1][1].mul(a1));
            }
        }

        // ============================================================
        // Measurement
        // ============================================================

        /// Measure qubit and collapse state. Returns 0 or 1.
        pub fn measure(self: *Self, qubit: usize, rng: std.Random) u1 {
            std.debug.assert(qubit < n);

            const bit_mask = @as(usize, 1) << @intCast(qubit);

            // Calculate probability of measuring |0⟩ on this qubit
            var prob_0: P = 0.0;
            for (self.amplitudes, 0..) |amp, i| {
                if ((i & bit_mask) == 0) {
                    prob_0 += amp.normSq();
                }
            }

            // Randomly choose outcome based on probability
            const random_val = rng.float(P);
            const outcome: u1 = if (random_val < prob_0) 0 else 1;

            // Collapse state: zero out non-matching amplitudes, renormalize
            var norm_sq: P = 0.0;
            const expected_bit = if (outcome == 0) @as(usize, 0) else bit_mask;

            for (&self.amplitudes, 0..) |*amp, i| {
                if ((i & bit_mask) == expected_bit) {
                    norm_sq += amp.normSq();
                } else {
                    amp.* = C.zero;
                }
            }

            // Renormalize
            if (norm_sq > 0) {
                const inv_norm = 1.0 / @sqrt(norm_sq);
                for (&self.amplitudes) |*amp| {
                    amp.* = amp.scale(inv_norm);
                }
            }

            return outcome;
        }

        // ============================================================
        // Utility
        // ============================================================

        /// Inner product ⟨self|other⟩.
        pub fn innerProduct(self: *const Self, other: *const Self) C {
            var sum = C.zero;
            for (self.amplitudes, other.amplitudes) |a, b| {
                sum = sum.add(a.conj().mul(b));
            }
            return sum;
        }

        /// Check approximate equality of two states.
        pub fn approxEq(self: *const Self, other: *const Self, epsilon: P) bool {
            for (self.amplitudes, other.amplitudes) |a, b| {
                if (!a.approxEq(b, epsilon)) return false;
            }
            return true;
        }

        /// Format state for printing.
        pub fn format(
            self: *const Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            try writer.writeAll("QuantumState(\n");
            for (self.amplitudes, 0..) |amp, i| {
                if (amp.normSq() > 1e-10) {
                    try writer.print("  |{b:0>{}}⟩: {}\n", .{ i, n, amp });
                }
            }
            try writer.writeAll(")");
        }
    };
}

// ============================================================
// Common State Type Aliases
// ============================================================

/// 1-qubit state (2 amplitudes)
pub const Qubit = QuantumState(1, f64);
/// 2-qubit state (4 amplitudes)
pub const TwoQubit = QuantumState(2, f64);
/// 3-qubit state (8 amplitudes)
pub const ThreeQubit = QuantumState(3, f64);

// ============================================================
// Symbolic Tests
// ============================================================

test "symbolic: ground state initialization" {
    const State = QuantumState(2, f64);
    const state = State.init();

    // |00⟩ should have amplitude 1
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), state.probability(0), 1e-10);
    // All other states should have probability 0
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.probability(1), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.probability(2), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.probability(3), 1e-10);
}

test "symbolic: state normalization (|ψ|² = 1)" {
    const State = QuantumState(2, f64);
    const state = State.init();

    // Ground state should be normalized
    try std.testing.expect(state.isNormalized(1e-10));
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), state.totalProbability(), 1e-10);
}

test "symbolic: basis state creation" {
    const State = QuantumState(2, f64);

    // |01⟩ state (index 1)
    const state1 = State.fromBasisState(1);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), state1.probability(1), 1e-10);
    try std.testing.expect(state1.isNormalized(1e-10));

    // |11⟩ state (index 3)
    const state3 = State.fromBasisState(3);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), state3.probability(3), 1e-10);
}

test "symbolic: Pauli-X gate (|0⟩ → |1⟩)" {
    const C = complex.Complex(f64);
    const State = QuantumState(1, f64);

    var state = State.init(); // |0⟩

    // Pauli-X matrix: [[0,1],[1,0]]
    const x_gate = [2][2]C{
        .{ C.zero, C.one },
        .{ C.one, C.zero },
    };

    state.applySingleQubitGate(0, x_gate);

    // Should now be |1⟩
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.probability(0), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), state.probability(1), 1e-10);
}

test "symbolic: X·X = I (X gate is self-inverse)" {
    const C = complex.Complex(f64);
    const State = QuantumState(1, f64);

    var state = State.init(); // |0⟩

    const x_gate = [2][2]C{
        .{ C.zero, C.one },
        .{ C.one, C.zero },
    };

    state.applySingleQubitGate(0, x_gate); // X|0⟩ = |1⟩
    state.applySingleQubitGate(0, x_gate); // X|1⟩ = |0⟩

    // Should be back to |0⟩
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), state.probability(0), 1e-10);
}

test "symbolic: Hadamard creates superposition (H|0⟩ = (|0⟩+|1⟩)/√2)" {
    const C = complex.Complex(f64);
    const State = QuantumState(1, f64);

    var state = State.init(); // |0⟩

    // Hadamard matrix
    const s = 1.0 / @sqrt(2.0);
    const h_gate = [2][2]C{
        .{ C.init(s, 0), C.init(s, 0) },
        .{ C.init(s, 0), C.init(-s, 0) },
    };

    state.applySingleQubitGate(0, h_gate);

    // Equal superposition: 50% |0⟩, 50% |1⟩
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), state.probability(0), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), state.probability(1), 1e-10);
    try std.testing.expect(state.isNormalized(1e-10));
}

test "symbolic: H·H = I (Hadamard is self-inverse)" {
    const C = complex.Complex(f64);
    const State = QuantumState(1, f64);

    var state = State.init(); // |0⟩

    const s = 1.0 / @sqrt(2.0);
    const h_gate = [2][2]C{
        .{ C.init(s, 0), C.init(s, 0) },
        .{ C.init(s, 0), C.init(-s, 0) },
    };

    state.applySingleQubitGate(0, h_gate);
    state.applySingleQubitGate(0, h_gate);

    // Should be back to |0⟩
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), state.probability(0), 1e-10);
}

test "symbolic: CNOT preserves normalization" {
    const C = complex.Complex(f64);
    const State = QuantumState(2, f64);

    var state = State.init(); // |00⟩

    // First apply H to qubit 0 to create superposition
    const s = 1.0 / @sqrt(2.0);
    const h_gate = [2][2]C{
        .{ C.init(s, 0), C.init(s, 0) },
        .{ C.init(s, 0), C.init(-s, 0) },
    };
    state.applySingleQubitGate(0, h_gate);

    // CNOT: X gate on target when control is |1⟩
    const x_gate = [2][2]C{
        .{ C.zero, C.one },
        .{ C.one, C.zero },
    };
    state.applyControlledGate(0, 1, x_gate);

    // State should still be normalized
    try std.testing.expect(state.isNormalized(1e-10));
}

test "symbolic: Bell state creation (H then CNOT)" {
    const C = complex.Complex(f64);
    const State = QuantumState(2, f64);

    var state = State.init(); // |00⟩

    // H on qubit 0
    const s = 1.0 / @sqrt(2.0);
    const h_gate = [2][2]C{
        .{ C.init(s, 0), C.init(s, 0) },
        .{ C.init(s, 0), C.init(-s, 0) },
    };
    state.applySingleQubitGate(0, h_gate);

    // CNOT with control=0, target=1
    const x_gate = [2][2]C{
        .{ C.zero, C.one },
        .{ C.one, C.zero },
    };
    state.applyControlledGate(0, 1, x_gate);

    // Bell state: (|00⟩ + |11⟩)/√2
    // |00⟩ = index 0, |11⟩ = index 3
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), state.probability(0), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.probability(1), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.probability(2), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), state.probability(3), 1e-10);
}

test "symbolic: inner product ⟨ψ|ψ⟩ = 1 for normalized state" {
    const State = QuantumState(2, f64);
    const state = State.init();

    const inner = state.innerProduct(&state);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), inner.re, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), inner.im, 1e-10);
}

test "symbolic: orthogonal states ⟨0|1⟩ = 0" {
    const State = QuantumState(1, f64);

    const state0 = State.fromBasisState(0); // |0⟩
    const state1 = State.fromBasisState(1); // |1⟩

    const inner = state0.innerProduct(&state1);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), inner.re, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), inner.im, 1e-10);
}
