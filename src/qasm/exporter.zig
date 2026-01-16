//! QASM exporter for OpenQASM 2.0.
//!
//! Generates QASM source code from a quantum circuit's operation history.

const std = @import("std");
const builder = @import("../circuit/builder.zig");

/// Export a circuit to QASM 2.0 source code.
pub fn exportToQasm(allocator: std.mem.Allocator, comptime n: comptime_int, comptime P: type, circuit: *const builder.Circuit(n, P)) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    const writer = result.writer(allocator);

    try writer.writeAll("OPENQASM 2.0;\n");
    try writer.writeAll("include \"qelib1.inc\";\n\n");

    try writer.print("qreg q[{d}];\n", .{n});
    try writer.print("creg c[{d}];\n\n", .{n});

    for (circuit.ops.items) |op| {
        switch (op.op) {
            .h, .x, .y, .z, .s, .t => {
                const q = op.qubits[0];
                try writer.print("{s} q[{d}];\n", .{ @tagName(op.op), q });
            },
            .rx, .ry, .rz => {
                const q = op.qubits[0];
                try writer.print("{s}({d}) q[{d}];\n", .{ @tagName(op.op), op.params[0], q });
            },
            .cnot => {
                const ctrl = op.qubits[0];
                const target = op.qubits[1];
                try writer.print("cx q[{d}], q[{d}];\n", .{ ctrl, target });
            },
            .cz => {
                const ctrl = op.qubits[0];
                const target = op.qubits[1];
                try writer.print("cz q[{d}], q[{d}];\n", .{ ctrl, target });
            },
            .ccx => {
                const c1 = op.qubits[0];
                const c2 = op.qubits[1];
                const target = op.qubits[2];
                try writer.print("ccx q[{d}], q[{d}], q[{d}];\n", .{ c1, c2, target });
            },
            .swap => {
                const q1 = op.qubits[0];
                const q2 = op.qubits[1];
                try writer.print("swap q[{d}], q[{d}];\n", .{ q1, q2 });
            },
            .measure => {
                const q = op.qubits[0];
                try writer.print("measure q[{d}] -> c[{d}];\n", .{ q, q });
            },
        }
    }

    return result.toOwnedSlice(allocator);
}

test "unit: qasm exporter basic" {
    var circuit = builder.Circuit(2, f64).init(std.testing.allocator);
    defer circuit.deinit();

    _ = circuit.h(0).cnot(0, 1);

    const qasm = try exportToQasm(std.testing.allocator, 2, f64, &circuit);
    defer std.testing.allocator.free(qasm);

    try std.testing.expect(std.mem.indexOf(u8, qasm, "OPENQASM 2.0;") != null);
    try std.testing.expect(std.mem.indexOf(u8, qasm, "qreg q[2];") != null);
    try std.testing.expect(std.mem.indexOf(u8, qasm, "h q[0];") != null);
    try std.testing.expect(std.mem.indexOf(u8, qasm, "cx q[0], q[1];") != null);
}
