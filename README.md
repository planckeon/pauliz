# Pauliz

A high-performance, zero-dependency quantum computing simulation library written in Zig.

## Features

- **Pure Zig Implementation**: No external dependencies; built entirely from the Zig Standard Library
- **Compile-Time Generics**: Fixed qubit counts enable aggressive compiler optimizations (loop unrolling, SIMD vectorization)
- **Explicit Memory Management**: Allocator-aware design for predictable resource utilization
- **OpenQASM 2.0 Support**: Full parse/export round-trip capability
- **Noise Simulation**: Monte Carlo wave function trajectories for realistic device modeling
- **Neurosymbolic Verification**: Dual symbolic/numerical testing framework

## Quick Start

### Requirements

- [Zig](https://ziglang.org/download/) 0.13.0 or later

### Building

```bash
# Run tests
zig build test

# Run Bell state example
zig build bell
```

### Usage

```zig
const pauliz = @import("pauliz");

// Create a 2-qubit circuit
var circuit = pauliz.Circuit(2, f64).init(allocator);
defer circuit.deinit();

// Build a Bell state: |00⟩ → (|00⟩ + |11⟩)/√2
_ = circuit.h(0).cnot(0, 1);

// Check probabilities
const p00 = circuit.probability(0);  // ~0.5
const p11 = circuit.probability(3);  // ~0.5
```

## Architecture

```
src/
├── pauliz.zig          # Public API and re-exports
├── core/
│   ├── complex.zig     # Complex number arithmetic
│   └── state.zig       # Quantum state vector representation
├── gates/
│   ├── single.zig      # Single-qubit gates (H, X, Y, Z, S, T, Rx, Ry, Rz)
│   └── controlled.zig  # Multi-qubit gates (CNOT, CZ, SWAP, Toffoli)
├── circuit/
│   └── builder.zig     # Fluent circuit builder API
├── qasm/
│   ├── lexer.zig       # OpenQASM tokenizer
│   ├── parser.zig      # OpenQASM parser
│   └── exporter.zig    # QASM code generation
├── noise/
│   └── channels.zig    # Noise channels (bit flip, phase flip, amplitude damping)
└── viz/
    └── ascii.zig       # ASCII circuit visualization
```

## Supported Gates

### Single-Qubit Gates
| Gate | Description |
|------|-------------|
| `I` | Identity |
| `X` | Pauli-X (NOT) |
| `Y` | Pauli-Y |
| `Z` | Pauli-Z |
| `H` | Hadamard |
| `S` | Phase gate (√Z) |
| `T` | π/8 gate (√S) |
| `Rx(θ)` | X-axis rotation |
| `Ry(θ)` | Y-axis rotation |
| `Rz(θ)` | Z-axis rotation |

### Multi-Qubit Gates
| Gate | Description |
|------|-------------|
| `CNOT` | Controlled-NOT |
| `CY` | Controlled-Y |
| `CZ` | Controlled-Z |
| `CH` | Controlled-Hadamard |
| `SWAP` | Qubit swap |
| `CCX` | Toffoli (Controlled-Controlled-X) |

## Noise Channels

Monte Carlo wave function simulation supports:
- **Bit Flip**: `X` error with probability `p`
- **Phase Flip**: `Z` error with probability `p`
- **Depolarizing**: Random Pauli error
- **Amplitude Damping**: Energy relaxation (T₁ decay)
- **Phase Damping**: Dephasing (T₂ relaxation)

## OpenQASM Example

```zig
const pauliz = @import("pauliz");

// Parse QASM
const source = "OPENQASM 2.0; qreg q[2]; h q[0]; cx q[0],q[1];";
var circuit = pauliz.Circuit(2, f64).init(allocator);
defer circuit.deinit();

var parser = pauliz.Parser(2, f64).init(allocator, source, &circuit);
try parser.parse();

// Export back to QASM
const qasm_code = try pauliz.exportToQasm(allocator, 2, f64, &circuit);
defer allocator.free(qasm_code);
```

## Testing

The library employs a neurosymbolic verification approach:

```bash
# Run all tests (unit + integration)
zig build test
```

Tests verify:
- Algebraic identities: `H·H = I`, `X·X = I`, `i² = -1`
- Gate unitarity: `U†U = I` for all gates
- State normalization: `⟨ψ|ψ⟩ = 1`
- QASM round-trip correctness

## Research Paper

See [`paper/`](paper/) for the accompanying Physical Review Letters-style research paper detailing the architecture, implementation, and validation methodology.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Citation

```bibtex
@software{pauliz,
  author = {Kataru, Baalateja},
  title = {pauliz: Zero-Dependency Quantum Computing Simulation in Zig},
  year = {2026},
  publisher = {GitHub},
  url = {https://github.com/planckeon/pauliz}
}
```
