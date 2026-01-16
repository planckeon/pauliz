const std = @import("std");
const state = @import("../core/state.zig");
const single = @import("../gates/single.zig");
const controlled = @import("../gates/controlled.zig");

/// Type of operation performed in a circuit.
pub const OpType = enum {
    h,
    x,
    y,
    z,
    s,
    t,
    rx,
    ry,
    rz,
    cnot,
    cz,
    ccx,
    swap,
    measure,
};

/// A recorded quantum operation.
pub const Operation = struct {
    op: OpType,
    qubits: [3]usize,
    params: [1]f64, // For rotation angles etc.
};

/// A quantum circuit for `n` qubits with precision `P`.
pub fn Circuit(comptime n: comptime_int, comptime P: type) type {
    const State = state.QuantumState(n, P);
    const G = single.Gate(P);
    const Ctrl = controlled.Controlled(P);

    return struct {
        state: State,
        ops: std.ArrayListUnmanaged(Operation),
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Initialize a circuit in the ground state |0...0⟩.
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .state = State.init(),
                .ops = .{},
                .allocator = allocator,
            };
        }

        /// Clean up stored operations.
        pub fn deinit(self: *Self) void {
            self.ops.deinit(self.allocator);
        }

        fn record(self: *Self, op: OpType, q1: usize, q2: usize, q3: usize, p: f64) void {
            self.ops.append(self.allocator, .{
                .op = op,
                .qubits = .{ q1, q2, q3 },
                .params = .{p},
            }) catch {}; // Silent catch for simplicity in fluent API
        }

        // ============================================================
        // Single-Qubit Gates (Fluent API)
        // ============================================================

        pub fn x(self: *Self, qubit: usize) *Self {
            G.PauliX.apply(n, &self.state, qubit);
            self.record(.x, qubit, 0, 0, 0);
            return self;
        }

        pub fn y(self: *Self, qubit: usize) *Self {
            G.PauliY.apply(n, &self.state, qubit);
            self.record(.y, qubit, 0, 0, 0);
            return self;
        }

        pub fn z(self: *Self, qubit: usize) *Self {
            G.PauliZ.apply(n, &self.state, qubit);
            self.record(.z, qubit, 0, 0, 0);
            return self;
        }

        pub fn h(self: *Self, qubit: usize) *Self {
            G.Hadamard.apply(n, &self.state, qubit);
            self.record(.h, qubit, 0, 0, 0);
            return self;
        }

        pub fn s(self: *Self, qubit: usize) *Self {
            G.S.apply(n, &self.state, qubit);
            self.record(.s, qubit, 0, 0, 0);
            return self;
        }

        pub fn t(self: *Self, qubit: usize) *Self {
            G.T.apply(n, &self.state, qubit);
            self.record(.t, qubit, 0, 0, 0);
            return self;
        }

        pub fn rx(self: *Self, qubit: usize, theta: P) *Self {
            G.rx(theta).apply(n, &self.state, qubit);
            self.record(.rx, qubit, 0, 0, @as(f64, theta));
            return self;
        }

        pub fn ry(self: *Self, qubit: usize, theta: P) *Self {
            G.ry(theta).apply(n, &self.state, qubit);
            self.record(.ry, qubit, 0, 0, @as(f64, theta));
            return self;
        }

        pub fn rz(self: *Self, qubit: usize, theta: P) *Self {
            G.rz(theta).apply(n, &self.state, qubit);
            self.record(.rz, qubit, 0, 0, @as(f64, theta));
            return self;
        }

        // ============================================================
        // Controlled Gates (Fluent API)
        // ============================================================

        pub fn cnot(self: *Self, control: usize, target: usize) *Self {
            Ctrl.cnot(n, &self.state, control, target);
            self.record(.cnot, control, target, 0, 0);
            return self;
        }

        pub fn cz(self: *Self, control: usize, target: usize) *Self {
            Ctrl.cz(n, &self.state, control, target);
            self.record(.cz, control, target, 0, 0);
            return self;
        }

        pub fn ccx(self: *Self, c1: usize, c2: usize, target: usize) *Self {
            Ctrl.ccx(n, &self.state, c1, c2, target);
            self.record(.ccx, c1, c2, target, 0);
            return self;
        }

        pub fn swap(self: *Self, q1: usize, q2: usize) *Self {
            Ctrl.swap(n, &self.state, q1, q2);
            self.record(.swap, q1, q2, 0, 0);
            return self;
        }

        // ============================================================
        // Measurement
        // ============================================================

        /// Measure a single qubit.
        pub fn measure(self: *Self, qubit: usize, rng: std.Random) u1 {
            const outcome = self.state.measure(qubit, rng);
            self.record(.measure, qubit, 0, 0, @as(f64, outcome));
            return outcome;
        }

        // ============================================================
        // Utilities
        // ============================================================

        /// Get current state probability of basis state `k`.
        pub fn probability(self: *const Self, k: usize) P {
            return self.state.probability(k);
        }
    };
}

// ============================================================
// Symbolic Tests
// ============================================================

test "unit: circuit builder records operations" {
    var circuit = Circuit(2, f64).init(std.testing.allocator);
    defer circuit.deinit();

    _ = circuit.h(0).cnot(0, 1);

    try std.testing.expectEqual(@as(usize, 2), circuit.ops.items.len);
    try std.testing.expectEqual(OpType.h, circuit.ops.items[0].op);
    try std.testing.expectEqual(OpType.cnot, circuit.ops.items[1].op);
}
