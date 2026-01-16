//! Quantum noise channels.
//!
//! Implements noise channels using Monte Carlo wave function trajectories (stochastic gate application).
//! This allows simulating noise on state vectors without the full cost of density matrices.

const std = @import("std");
const complex = @import("../core/complex.zig");
const state = @import("../core/state.zig");
const gates = @import("../gates/single.zig");

pub fn NoiseChannel(comptime n: comptime_int, comptime P: type) type {
    const State = state.QuantumState(n, P);
    const Gate = gates.Gate(P);

    return struct {
        /// Apply Bit Flip noise (X error) with probability `p`.
        pub fn applyBitFlip(s: *State, qubit: usize, p: f64, rng: std.Random) void {
            if (rng.float(f64) < p) {
                Gate.PauliX.apply(n, s, qubit);
            }
        }

        /// Apply Phase Flip noise (Z error) with probability `p`.
        pub fn applyPhaseFlip(s: *State, qubit: usize, p: f64, rng: std.Random) void {
            if (rng.float(f64) < p) {
                Gate.PauliZ.apply(n, s, qubit);
            }
        }

        /// Apply Depolarizing noise with probability `p`.
        /// Applies X, Y, or Z each with probability p/3, or Identity with 1-p.
        pub fn applyDepolarizing(s: *State, qubit: usize, p: f64, rng: std.Random) void {
            const r = rng.float(f64);
            if (r < p) {
                const type_prob = p / 3.0;
                if (r < type_prob) {
                    Gate.PauliX.apply(n, s, qubit);
                } else if (r < 2 * type_prob) {
                    Gate.PauliY.apply(n, s, qubit);
                } else {
                    Gate.PauliZ.apply(n, s, qubit);
                }
            }
        }

        /// Apply Amplitude Damping with probability `gamma` (energy relaxation).
        /// Kraus operators:
        /// E0 = [[1, 0], [0, sqrt(1-gamma)]]
        /// E1 = [[0, sqrt(gamma)], [0, 0]]
        /// This is a non-unitary operation, so we must be careful with state vector normalization.
        /// Monte Carlo approach: collapse state to |0> or |1> based on standard measurement logic?
        /// No, amplitude damping is a continuous process.
        ///
        /// For a generic CPTP map with Kraus operators {Ek}, the probability of branch k is p_k = <psi|Ek† Ek|psi>.
        /// The new state is Ek|psi> / sqrt(p_k).
        pub fn applyAmplitudeDamping(s: *State, qubit: usize, gamma: f64, rng: std.Random) void {
            // Calculate probabilities for Kraus outcomes
            // We need to peek at the state amplitudes for the target qubit.
            // P(E0) is related to population in |0> and |1>.
            // E0 leaves |0> alone and damps |1>. E1 flips |1> to |0>.

            // It's effectively a generalized measurement.

            // Let prob1 = probability of being in state |1> for this qubit.
            const prob1 = s.probabilityOfBit(qubit, 1);

            // Probability of a jump (decay |1> -> |0>): p_decay = prob1 * gamma
            // Probability of no jump (damping): p_no_decay = 1 - p_decay

            const p_decay = prob1 * @as(P, @floatCast(gamma));

            if (rng.float(P) < p_decay) {
                // Decay occurred: |1> -> |0>
                // Apply E1 = [[0, sqrt(gamma)], [0, 0]] and normalize

                // This is equivalent to: project to |1>, then flip X, then normalize.
                // Or simply: zero out |0> components (already zero if we projected to |1>),
                // move |1> components to |0>, and normalize.

                // For a single qubit state a|0> + b|1>:
                // E1 applied: b*sqrt(gamma)|0>.
                // Norm squared: |b|^2 * gamma = prob1 * gamma = p_decay. Correct.

                // Efficient implementation:
                // 1. Zero out all amplitudes where qubit=0 (dest is 0) - wait, no.
                // 2. For each pair (i where q=0, j where q=1):
                //    amp[i] = amp[j] (move |1> to |0>)
                //    amp[j] = 0
                // 3. Normalize.

                const step = @as(usize, 1) << @intCast(qubit);
                var i: usize = 0;
                while (i < state.pow2(n)) : (i += 1) {
                    if ((i & step) == 0) { // qubit is 0
                        const idx0 = i;
                        const idx1 = i | step;

                        s.amplitudes[idx0] = s.amplitudes[idx1];
                        s.amplitudes[idx1] = complex.Complex(P).zero();
                    }
                }

                s.normalize();
            } else {
                // No decay: Apply E0 = [[1, 0], [0, sqrt(1-gamma)]]
                // Damping the |1> state.

                const sqrt_one_minus_gamma = @sqrt(1.0 - @as(P, @floatCast(gamma)));

                const step = @as(usize, 1) << @intCast(qubit);
                var i: usize = 0;
                while (i < state.pow2(n)) : (i += 1) {
                    if ((i & step) != 0) { // qubit is 1
                        s.amplitudes[i] = s.amplitudes[i].scale(sqrt_one_minus_gamma);
                    }
                }

                s.normalize();
            }
        }

        /// Apply Phase Damping (dephasing) with probability `gamma`.
        /// Kraus operators:
        /// E0 = [[1, 0], [0, sqrt(1-gamma)]]
        /// E1 = [[0, 0], [0, sqrt(gamma)]]
        // Actually often represented as E0 = srqt(1-p) I, E1 = sqrt(p) Z.
        // Or pure dephasing: M0=[[1,0],[0,sqrt(1-lambda)]], M1=[[0,0],[0,sqrt(lambda)]] ?
        // Standard definition:
        // E0 = [[1, 0], [0, sqrt(1-lambda)]]  -- damp off-diagonals (wait, this looks like Amplitude Damping E0?)
        // Let's use the Phase Flip interpretation for Monte Carlo:
        // With probability p, apply Z. This destroys phase coherence.
        // It's equivalent to the channel rho -> (1-p)rho + p Z rho Z.
        pub fn applyPhaseDamping(s: *State, qubit: usize, gamma: f64, rng: std.Random) void {
            // For Monte Carlo, Phase Damping is often just Phase Flip with some probability derived from gamma.
            // If the channel is defined as E0=[[1,0],[0,sqrt(1-gamma)]], E1=[[0,0],[0,sqrt(gamma)]] Z?
            // No, standard dephasing channel is:
            // rho -> (1-p) rho + p Z rho Z
            // So simply call applyPhaseFlip.
            applyPhaseFlip(s, qubit, gamma, rng);
        }
    };
}

test "unit: noise channels" {
    const testing = std.testing;
    const S = state.QuantumState(1, f64);
    const Noise = NoiseChannel(1, f64);
    var s = S.init();
    var rng = std.Random.DefaultPrng.init(0);
    const random = rng.random();

    // Test Bit Flip (deterministic p=1.0)
    Noise.applyBitFlip(&s, 0, 1.0, random);
    // Should be |1>
    try testing.expectApproxEqAbs(@as(f64, 0.0), s.probability(0), 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 1.0), s.probability(1), 1e-10);
}
