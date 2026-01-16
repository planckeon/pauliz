//! Integration tests / QASM Round-trip verification.

const std = @import("std");
const pauliz = @import("pauliz");
const Circuit = pauliz.Circuit;
const Parser = pauliz.Parser;
const exportToQasm = pauliz.exportToQasm;

test "integration: QASM round-trip Bell State" {
    const allocator = std.testing.allocator;

    // 1. Create original circuit
    var circ1 = Circuit(2, f64).init(allocator);
    defer circ1.deinit();

    _ = circ1.h(0).cnot(0, 1);

    // 2. Export to QASM
    const qasm_code = try exportToQasm(allocator, 2, f64, &circ1);
    defer allocator.free(qasm_code);

    // 3. Parse back to new circuit
    var circ2 = Circuit(2, f64).init(allocator);
    defer circ2.deinit();

    var parser = Parser(2, f64).init(allocator, qasm_code, &circ2);
    try parser.parse();

    // 4. Verify operations match
    try std.testing.expectEqual(circ1.ops.items.len, circ2.ops.items.len);

    // Note: circ1 ops: [H(0), CNOT(0,1)]
    // circ2 ops depends on parsing order, but should be same.
    for (0..circ1.ops.items.len) |i| {
        const op1 = circ1.ops.items[i];
        const op2 = circ2.ops.items[i];

        try std.testing.expectEqual(op1.op, op2.op);
        // Compare qubits
        try std.testing.expectEqual(op1.qubits[0], op2.qubits[0]);
        if (op1.op == .cnot) {
            try std.testing.expectEqual(op1.qubits[1], op2.qubits[1]);
        }
    }

    // 5. Verify states match
    // Run circ1? Circuit builder applies gates immediately to .state
    // Wait, circ2 operations were applied during parsing?
    // Parser applies gates to the circuit as it parses.

    // Verify states are identical.
    try std.testing.expectApproxEqAbs(@as(f64, 0.70710678), circ1.state.amplitudes[0].re, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.70710678), circ2.state.amplitudes[0].re, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.70710678), circ1.state.amplitudes[3].re, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.70710678), circ2.state.amplitudes[3].re, 1e-6);
}

test "integration: QASM round-trip H-X-Z-CNOT" {
    const allocator = std.testing.allocator;

    // 1. Create original circuit
    var circ1 = Circuit(2, f64).init(allocator);
    defer circ1.deinit();

    _ = circ1.h(0).x(1).z(0).cnot(1, 0);

    // 2. Export to QASM
    const qasm_code = try exportToQasm(allocator, 2, f64, &circ1);
    defer allocator.free(qasm_code);

    // 3. Parse back
    var circ2 = Circuit(2, f64).init(allocator);
    defer circ2.deinit();

    var parser = Parser(2, f64).init(allocator, qasm_code, &circ2);
    try parser.parse();

    // 4. Verify states match
    // Check specific probability or amplitude
    const p0_orig = circ1.probability(0);
    const p0_new = circ2.probability(0);

    try std.testing.expectApproxEqAbs(p0_orig, p0_new, 1e-6);
}
