//! pauliz - Quantum Computing Simulation Library
//!
//! A pure Zig quantum computing simulation library with zero dependencies.
//! Provides state vector simulation, quantum gates, circuit building,
//! QASM import/export, and noise simulation.

pub const complex = @import("core/complex.zig");
pub const state = @import("core/state.zig");
pub const gates = @import("gates/single.zig");
pub const controlled = @import("gates/controlled.zig");
pub const circuit = @import("circuit/builder.zig");
pub const viz = @import("viz/ascii.zig");
pub const qasm_lexer = @import("qasm/lexer.zig");
pub const qasm_parser = @import("qasm/parser.zig");
pub const qasm_exporter = @import("qasm/exporter.zig");
pub const noise = @import("noise/channels.zig");

pub const Complex = complex.Complex;
pub const QuantumState = state.QuantumState;
pub const Gate = gates.Gate;
pub const Controlled = controlled.Controlled;
pub const Circuit = circuit.Circuit;
pub const drawCircuit = viz.drawCircuit;
pub const Lexer = qasm_lexer.Lexer;
pub const Parser = qasm_parser.Parser;
pub const exportToQasm = qasm_exporter.exportToQasm;
pub const NoiseChannel = noise.NoiseChannel;

// Re-export common types
pub const Complex64 = Complex(f64);
pub const Complex32 = Complex(f32);
pub const Qubit = state.Qubit;
pub const TwoQubit = state.TwoQubit;
pub const ThreeQubit = state.ThreeQubit;
pub const Gate64 = gates.Gate64;
pub const Gate32 = gates.Gate32;
pub const Controlled64 = controlled.Controlled64;
pub const Controlled32 = controlled.Controlled32;

test {
    _ = @import("core/complex.zig");
    _ = @import("core/state.zig");
    _ = @import("gates/single.zig");
    _ = @import("gates/controlled.zig");
    _ = @import("circuit/builder.zig");
    _ = @import("viz/ascii.zig");
    _ = @import("qasm/lexer.zig");
    _ = @import("qasm/parser.zig");
    _ = @import("qasm/exporter.zig");
    _ = @import("noise/channels.zig");
}
