//! Controlled quantum gates and multi-qubit operations.
//!
//! Provides common controlled gates (CNOT, CZ, Controlled-Phase, Toffoli)
//! and utilities for creating general multi-controlled gates.

const std = @import("std");
const complex = @import("../core/complex.zig");
const state = @import("../core/state.zig");
const single = @import("single.zig");

/// Controlled gate operations.
pub fn Controlled(comptime P: type) type {
    const G = single.Gate(P);

    return struct {
        /// CNOT gate (Controlled-X)
        pub fn cnot(comptime n: comptime_int, pstate: *state.QuantumState(n, P), control: usize, target: usize) void {
            pstate.applyControlledGate(control, target, G.PauliX.matrix);
        }

        /// CY gate (Controlled-Y)
        pub fn cy(comptime n: comptime_int, pstate: *state.QuantumState(n, P), control: usize, target: usize) void {
            pstate.applyControlledGate(control, target, G.PauliY.matrix);
        }

        /// CZ gate (Controlled-Z, phase flip)
        pub fn cz(comptime n: comptime_int, pstate: *state.QuantumState(n, P), control: usize, target: usize) void {
            pstate.applyControlledGate(control, target, G.PauliZ.matrix);
        }

        /// CH gate (Controlled-Hadamard)
        pub fn ch(comptime n: comptime_int, pstate: *state.QuantumState(n, P), control: usize, target: usize) void {
            pstate.applyControlledGate(control, target, G.Hadamard.matrix);
        }

        /// CP(phi) gate (Controlled-Phase)
        pub fn cp(comptime n: comptime_int, pstate: *state.QuantumState(n, P), control: usize, target: usize, phi: P) void {
            pstate.applyControlledGate(control, target, G.phase(phi).matrix);
        }

        /// CS gate (Controlled-S)
        pub fn cs(comptime n: comptime_int, pstate: *state.QuantumState(n, P), control: usize, target: usize) void {
            pstate.applyControlledGate(control, target, G.S.matrix);
        }

        /// CT gate (Controlled-T)
        pub fn ct(comptime n: comptime_int, pstate: *state.QuantumState(n, P), control: usize, target: usize) void {
            pstate.applyControlledGate(control, target, G.T.matrix);
        }

        /// SWAP gate
        /// Implemented as three CNOTs
        pub fn swap(comptime n: comptime_int, pstate: *state.QuantumState(n, P), q1: usize, q2: usize) void {
            cnot(n, pstate, q1, q2);
            cnot(n, pstate, q2, q1);
            cnot(n, pstate, q1, q2);
        }

        /// CCX gate (Toffoli gate, Controlled-Controlled-X)
        pub fn ccx(comptime n: comptime_int, pstate: *state.QuantumState(n, P), c1: usize, c2: usize, target: usize) void {
            std.debug.assert(c1 < n and c2 < n and target < n);
            std.debug.assert(c1 != c2 and c1 != target and c2 != target);

            const mask = (@as(usize, 1) << @intCast(c1)) | (@as(usize, 1) << @intCast(c2));
            const target_bit = @as(usize, 1) << @intCast(target);

            var i: usize = 0;
            while (i < state.QuantumState(n, P).num_states) : (i += 1) {
                // Apply ONLY when both control bits are set AND we're on the 0-side of target
                if ((i & mask) != mask) continue;
                if ((i & target_bit) != 0) continue;

                const idx0 = i;
                const idx1 = i | target_bit;

                const a0 = pstate.amplitudes[idx0];
                const a1 = pstate.amplitudes[idx1];

                // X gate: [[0, 1], [1, 0]]
                pstate.amplitudes[idx0] = a1;
                pstate.amplitudes[idx1] = a0;
            }
        }
    };
}

pub const Controlled64 = Controlled(f64);
pub const Controlled32 = Controlled(f32);

// ============================================================
// Symbolic Tests
// ============================================================

test "symbolic: CNOT |10⟩ -> |11⟩" {
    const State = state.QuantumState(2, f64);
    const Ctrl = Controlled64;

    var s = State.fromBasisState(2); // |10⟩ (binary 10, index 2)
    Ctrl.cnot(2, &s, 1, 0); // Control bit 1 (val=1), target bit 0 (val=0) -> |11⟩

    try std.testing.expectApproxEqAbs(@as(f64, 1.0), s.probability(3), 1e-10);
}

test "symbolic: SWAP |10⟩ -> |01⟩" {
    const State = state.QuantumState(2, f64);
    const Ctrl = Controlled64;

    var s = State.fromBasisState(2); // |10⟩
    Ctrl.swap(2, &s, 0, 1);

    try std.testing.expectApproxEqAbs(@as(f64, 1.0), s.probability(1), 1e-10);
}

test "symbolic: Toffoli |110⟩ -> |111⟩" {
    const State = state.QuantumState(3, f64);
    const Ctrl = Controlled64;

    var s = State.fromBasisState(6); // |110⟩ (index 6)
    Ctrl.ccx(3, &s, 2, 1, 0); // Controls 2,1, target 0 -> |111⟩ (index 7)

    try std.testing.expectApproxEqAbs(@as(f64, 1.0), s.probability(7), 1e-10);
}

test "symbolic: Toffoli |101⟩ -> |101⟩ (no flip)" {
    const State = state.QuantumState(3, f64);
    const Ctrl = Controlled64;

    var s = State.fromBasisState(5); // |101⟩ (index 5)
    Ctrl.ccx(3, &s, 2, 1, 0); // C2=1, C1=0 -> no flip

    try std.testing.expectApproxEqAbs(@as(f64, 1.0), s.probability(5), 1e-10);
}
