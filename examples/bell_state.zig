//! Bell State Example
//!
//! Demonstrates creating a maximally entangled Bell state (|Phi+>)
//! using Pauliz's circuit builder API.
//!
//! The Bell state (|00> + |11>)/sqrt(2) exhibits:
//! - Perfect correlation: measuring one qubit determines the other
//! - Superposition: 50% probability for |00> and |11>
//! - Entanglement: non-separable quantum state
//!
//! Note: Pauliz uses little-endian qubit ordering where qubit 0 is
//! the least significant bit. For n=2: 0=|00>, 1=|01>, 2=|10>, 3=|11>

const std = @import("std");
const pauliz = @import("pauliz");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print(
        \\
        \\================================================
        \\          Pauliz Bell State Demo
        \\================================================
        \\
        \\
    , .{});

    // Create a 2-qubit quantum circuit
    var circuit = pauliz.Circuit(2, f64).init(allocator);
    defer circuit.deinit();

    std.debug.print("Initial state: |00>\n\n", .{});

    // Step 1: Apply Hadamard to qubit 0 (LSB)
    // |00> -> (|00> + |01>)/sqrt(2)   [qubit 0 in superposition]
    _ = circuit.h(0);
    std.debug.print("After H on qubit 0 (LSB):\n", .{});
    std.debug.print("  State: (|00> + |01>)/sqrt(2)\n", .{});
    std.debug.print("  P(|00>) = {d:.4}  [index 0: q1=0, q0=0]\n", .{circuit.probability(0)});
    std.debug.print("  P(|01>) = {d:.4}  [index 1: q1=0, q0=1]\n", .{circuit.probability(1)});
    std.debug.print("  P(|10>) = {d:.4}  [index 2: q1=1, q0=0]\n", .{circuit.probability(2)});
    std.debug.print("  P(|11>) = {d:.4}  [index 3: q1=1, q0=1]\n\n", .{circuit.probability(3)});

    // Step 2: Apply CNOT with control=0, target=1
    // When qubit 0 is |1>, flip qubit 1
    // (|00> + |01>)/sqrt(2) -> (|00> + |11>)/sqrt(2)
    _ = circuit.cnot(0, 1);
    std.debug.print("After CNOT(control=0, target=1):\n", .{});
    std.debug.print("  State: (|00> + |11>)/sqrt(2)  [Bell state |Phi+>]\n", .{});
    std.debug.print("  P(|00>) = {d:.4}\n", .{circuit.probability(0)});
    std.debug.print("  P(|01>) = {d:.4}\n", .{circuit.probability(1)});
    std.debug.print("  P(|10>) = {d:.4}\n", .{circuit.probability(2)});
    std.debug.print("  P(|11>) = {d:.4}\n\n", .{circuit.probability(3)});

    // Verify normalization
    const total_prob = circuit.probability(0) + circuit.probability(1) +
        circuit.probability(2) + circuit.probability(3);
    std.debug.print("Total probability: {d:.6} (should be 1.0)\n\n", .{total_prob});

    // Export to OpenQASM
    const qasm = try pauliz.exportToQasm(allocator, 2, f64, &circuit);
    defer allocator.free(qasm);

    std.debug.print("OpenQASM 2.0 Output:\n", .{});
    std.debug.print("--------------------\n{s}\n", .{qasm});

    std.debug.print(
        \\Circuit diagram:
        \\
        \\q0 (LSB) --[H]--*------
        \\                |
        \\q1 (MSB) ------[X]-----
        \\
        \\Legend: * = control, [X] = CNOT target
        \\
    , .{});
}
