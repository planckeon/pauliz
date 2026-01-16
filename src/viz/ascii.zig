//! ASCII visualization for quantum circuits.
//!
//! Provides utilities to generate human-readable ASCII diagrams of quantum circuits.

const std = @import("std");
const builder = @import("../circuit/builder.zig");

/// ASCII representation of a quantum circuit.
pub fn drawCircuit(allocator: std.mem.Allocator, comptime n: comptime_int, comptime P: type, circuit: *const builder.Circuit(n, P)) ![]const u8 {
    var lines = std.ArrayListUnmanaged(std.ArrayListUnmanaged(u8)){};
    defer {
        for (lines.items) |*line| line.deinit(allocator);
        lines.deinit(allocator);
    }

    // Initialize lines with qubit labels
    for (0..n) |i| {
        var line = std.ArrayListUnmanaged(u8){};
        try line.writer(allocator).print("q{d}: ──", .{i});
        try lines.append(allocator, line);
    }

    // Process operations
    for (circuit.ops.items) |op| {
        switch (op.op) {
            .h, .x, .y, .z, .s, .t => {
                const q = op.qubits[0];
                const tag = @tagName(op.op);
                const label = switch (op.op) {
                    .h => "H",
                    .x => "X",
                    .y => "Y",
                    .z => "Z",
                    .s => "S",
                    .t => "T",
                    else => tag,
                };

                try lines.items[q].writer(allocator).print("─{s}─", .{label});
                // Pad other lines to keep them aligned
                for (0..n) |i| {
                    if (i == q) continue;
                    try lines.items[i].appendSlice(allocator, "───");
                }
            },
            .cnot => {
                const ctrl = op.qubits[0];
                const target = op.qubits[1];
                try lines.items[ctrl].appendSlice(allocator, "─●─");
                try lines.items[target].appendSlice(allocator, "─X─");
                for (0..n) |i| {
                    if (i == ctrl or i == target) continue;
                    try lines.items[i].appendSlice(allocator, "───");
                }
            },
            .cz => {
                const ctrl = op.qubits[0];
                const target = op.qubits[1];
                try lines.items[ctrl].appendSlice(allocator, "─●─");
                try lines.items[target].appendSlice(allocator, "─●─");
                for (0..n) |i| {
                    if (i == ctrl or i == target) continue;
                    try lines.items[i].appendSlice(allocator, "───");
                }
            },
            .measure => {
                const q = op.qubits[0];
                try lines.items[q].appendSlice(allocator, "─M─");
                for (0..n) |i| {
                    if (i == q) continue;
                    try lines.items[i].appendSlice(allocator, "───");
                }
            },
            else => {
                for (0..n) |i| {
                    try lines.items[i].appendSlice(allocator, "───");
                }
            },
        }
    }

    // Terminate lines
    for (0..n) |i| {
        try lines.items[i].appendSlice(allocator, "──");
    }

    // Join lines
    var result = std.ArrayListUnmanaged(u8){};
    for (lines.items) |line| {
        try result.appendSlice(allocator, line.items);
        try result.append(allocator, '\n');
    }

    return result.toOwnedSlice(allocator);
}

test "unit: draw ASCII circuit" {
    const builder_mod = @import("../circuit/builder.zig");
    var circuit = builder_mod.Circuit(2, f64).init(std.testing.allocator);
    defer circuit.deinit();

    _ = circuit.h(0).cnot(0, 1);

    const viz = try drawCircuit(std.testing.allocator, 2, f64, &circuit);
    defer std.testing.allocator.free(viz);

    // Expected structure:
    // q0: ───H────●────
    // q1: ────────X────
    try std.testing.expect(std.mem.indexOf(u8, viz, "H") != null);
    try std.testing.expect(std.mem.indexOf(u8, viz, "●") != null);
    try std.testing.expect(std.mem.indexOf(u8, viz, "X") != null);
}
