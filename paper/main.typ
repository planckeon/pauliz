// =============================================================================
// Pauliz: A High-Performance Neurosymbolic Quantum Simulation Library
// Physical Review Letters Style Template
// =============================================================================

#import "@preview/physica:0.9.8": *

// -----------------------------------------------------------------------------
// PRL-Style Page Configuration
// -----------------------------------------------------------------------------
#set page(
  paper: "us-letter",
  margin: (x: 0.75in, y: 0.75in),
  columns: 2,
  header: context {
    if counter(page).get().first() > 1 [
      #set text(size: 8pt)
      #h(1fr) #counter(page).display()
    ]
  },
)

// -----------------------------------------------------------------------------
// Typography Settings (APS/PRL Standard)
// -----------------------------------------------------------------------------
#set text(
  font: ("Times New Roman", "TeX Gyre Termes", "Liberation Serif", "serif"),
  size: 10pt,
  lang: "en",
)

#set par(
  justify: true,
  leading: 0.52em,
  first-line-indent: 1em,
)

// Heading styles following PRL conventions
#set heading(numbering: "I.A.1.")

#show heading.where(level: 1): it => {
  set text(size: 10pt, weight: "bold")
  set block(above: 1.5em, below: 0.8em)
  [#counter(heading).display("I."). #upper(it.body)]
}

#show heading.where(level: 2): it => {
  set text(size: 10pt, weight: "bold", style: "italic")
  set block(above: 1.2em, below: 0.6em)
  [#counter(heading).display("I.A."). #it.body]
}

#show heading.where(level: 3): it => {
  set text(size: 10pt, weight: "regular", style: "italic")
  set block(above: 1em, below: 0.5em)
  [#counter(heading).display("I.A.1."). #it.body]
}

// Math equation numbering
#set math.equation(numbering: "(1)")

// Figure and table styling
#set figure(placement: auto)
#show figure.caption: it => {
  set text(size: 9pt)
  set par(justify: true)
  [*#it.supplement #it.counter.display().*  #it.body]
}

// Reference styling
#set ref(supplement: it => {
  if it.func() == figure {
    "Fig."
  } else if it.func() == table {
    "Table"
  } else if it.func() == math.equation {
    "Eq."
  } else {
    it.supplement
  }
})

// =============================================================================
// TITLE BLOCK (Single Column)
// =============================================================================
#place(
  top + center,
  scope: "parent",
  float: true,
  {
    set par(first-line-indent: 0pt)
    
    // Title
    align(center)[
      #text(12pt, weight: "bold")[
        Pauliz: A High-Performance Neurosymbolic Quantum Simulation Library in Zig
      ]
    ]
    
    v(0.8em)
    
    // Authors and Affiliations (PRL superscript style)
    align(center)[
      #text(10pt)[Baalateja Kataru#super[1,\*]]
      
      #v(0.3em)
      
      #text(9pt, style: "italic")[
        #super[1]Independent Researcher
      ]
      
      #v(0.2em)
      
      #text(8pt)[
        #super[\*]Corresponding author: #link("https://github.com/bkataru")[github.com/bkataru]
      ]
    ]
    
    v(0.5em)
    
    // Date
    align(center)[
      #text(9pt)[(Dated: #datetime.today().display("[month repr:long] [day], [year]"))]
    ]
    
    v(0.8em)
    
    // Abstract (PRL style: indented block, ~600 characters max)
    block(
      width: 100%,
      inset: (x: 1.5em),
    )[
      #set text(size: 9pt)
      #set par(justify: true, first-line-indent: 0pt)
      We present Pauliz, a zero-dependency quantum computing simulation library implemented in Zig. Leveraging compile-time metaprogramming and explicit memory management, Pauliz achieves high performance for state vector simulation. The library implements a comprehensive gate set, full OpenQASM 2.0 interoperability, and Monte Carlo wave function trajectories for efficient noise modeling. A neurosymbolic verification framework combines symbolic algebraic identity checks with numerical validation to ensure correctness. Benchmarks demonstrate competitive performance with established simulators while maintaining a minimal, portable codebase.
    ]
    
    v(0.3em)
    
    // Subject Areas (replaced PACS in modern APS)
    align(center)[
      #text(8pt)[
        *Subject Areas:* Quantum Information, Computational Physics, Software Development
      ]
    ]
    
    v(0.3em)
    
    // DOI placeholder (standard for PRL)
    align(center)[
      #text(8pt, fill: gray)[DOI: 10.1103/PhysRevLett.XXX.XXXXXX]
    ]
    
    v(1em)
    line(length: 100%, stroke: 0.5pt)
    v(0.5em)
  }
)

// =============================================================================
// MAIN CONTENT
// =============================================================================

= Introduction

Quantum simulation serves as the primary testbed for algorithm development and error correction research in the noisy intermediate-scale quantum (NISQ) era @Preskill2018. Existing software ecosystems present a bifurcation: high-level Python frameworks such as Qiskit @Qiskit and Cirq @Cirq prioritize usability but incur interpreter overhead, while high-performance backends in C++, including QSim @QSim and Qiskit-Aer @QiskitAer, present deployment complexities due to intricate build systems and dependency chains.

We introduce Pauliz, a quantum simulation library that bridges this gap by leveraging Zig @Zig, a modern systems programming language providing low-level control without the legacy complexities of C++. Zig's distinctive features---specifically compile-time code execution (`comptime`) and allocator-aware standard library---enable a simulator design that is simultaneously performant and resource-explicit.

The design philosophy centers on three core principles: (i) _zero external dependencies_, with the entire library, including the QASM parser and linear algebra kernel, built from the Zig Standard Library alone; (ii) _explicit resource management_, where memory allocations are never implicit, ensuring predictable runtime behavior critical for large-scale simulations; and (iii) _correctness via dual verification_, combining symbolic and numerical validation strategies.

This Letter presents the architecture, implementation, and validation of Pauliz, demonstrating that modern systems languages can provide compelling platforms for scientific computing in quantum information science.

= Architecture

Pauliz employs a modular architecture where core components---state representation, gates, and circuit construction---are strictly decoupled to maximize flexibility and testability.

== State Representation

The fundamental data structure is the `QuantumState(n, P)` generic, where the qubit count $n$ is a compile-time constant and $P$ specifies floating-point precision. The state vector occupies a contiguous array of $2^n$ complex amplitudes:
$
  ket(psi) = sum_(i=0)^(2^n - 1) alpha_i ket(i), quad "with" quad sum_i |alpha_i|^2 = 1.
$ <eq:statevector>

Fixing the dimension at compile-time enables the compiler to unroll inner loops for state updates and facilitates aggressive SIMD auto-vectorization on modern processors. The complex number implementation `Complex(T)` undergoes verification against symbolic rules (e.g., $i^2 = -1$) during compilation.

== Memory Model

Zig eschews global allocators in favor of explicit allocation strategies. Pauliz adopts `ArrayListUnmanaged` for dynamic structures such as circuit operation histories. This "unmanaged" pattern decouples container logic from memory allocation, requiring allocator arguments only during capacity changes. This design renders the library suitable for constrained environments, including WebAssembly or embedded systems, where memory context requires strict control.

== Gate Operations

Standard quantum gates are implemented as unitary transformations acting on the state vector. Single-qubit gates follow the general form:
$
  U(theta, phi, lambda) = mat(
    cos(theta/2), -e^(i lambda) sin(theta/2);
    e^(i phi) sin(theta/2), e^(i(phi + lambda)) cos(theta/2)
  )
$ <eq:u3gate>
with special cases including the Hadamard ($H$), Pauli gates ($X$, $Y$, $Z$), and phase gates ($S$, $T$).

Two-qubit entangling gates, particularly the controlled-NOT (CNOT) and controlled-$Z$ (CZ), are implemented with optimized index calculations:
$
  "CNOT" = mat(
    1, 0, 0, 0;
    0, 1, 0, 0;
    0, 0, 0, 1;
    0, 0, 1, 0
  ), quad "CZ" = mat(
    1, 0, 0, 0;
    0, 1, 0, 0;
    0, 0, 1, 0;
    0, 0, 0, -1
  ).
$ <eq:twoqubit>

= OpenQASM Interoperability

Integration with the broader quantum ecosystem is achieved through a hand-written recursive descent parser for OpenQASM 2.0 @Cross2017. The processing pipeline comprises:

(i) _Lexical analysis_: Tokenization of the input stream into QASM keywords (`qreg`, `creg`, `cx`, `measure`) and literals.

(ii) _Syntactic parsing_: Construction of a `Circuit` object by interpreting the token stream, handling register declarations and gate applications.

(iii) _Serialization_: Export logic converting internal `Circuit` structures back into valid QASM source code.

This round-trip capability undergoes verification via integration tests that parse QASM files, export them, and confirm identical quantum state evolution. The parser handles parameterized gates, conditional operations, and barrier instructions conforming to the OpenQASM 2.0 specification.

= Stochastic Noise Simulation

Realistic quantum device behavior requires noise modeling. The standard density matrix approach involves $rho$ evolution where state dimensionality scales as $2^(2n)$---computationally intractable for moderate qubit counts.

Pauliz implements Monte Carlo wave function (MCWF) trajectories @Dalibard1992, also known as quantum jump methods. Rather than evolving the density matrix under a Lindblad master equation, the pure state $ket(psi)$ evolves stochastically. For a noise channel characterized by Kraus operators ${E_k}$ satisfying $sum_k E_k^dagger E_k = I$, the state update follows:
$
  ket(psi') = (E_k ket(psi)) / sqrt(p_k), quad "where" quad p_k = braket(psi, E_k^dagger E_k, psi).
$ <eq:kraus>

Averaging over $N$ trajectories converges to the density matrix expectation:
$
  rho approx 1/N sum_(j=1)^N ketbra(psi_j, psi_j).
$ <eq:montecarlo>

The currently supported noise channels are:

_Bit flip_---Classical bit-flip errors with probability $p$:
$
  E_0 = sqrt(1-p) dot I, quad E_1 = sqrt(p) dot X.
$ <eq:bitflip>

_Phase damping_---Dephasing processes modeling $T_2$ relaxation:
$
  E_0 = sqrt(1-p) dot I, quad E_1 = sqrt(p) dot Z.
$ <eq:phasedamp>

_Amplitude damping_---Energy relaxation modeling $T_1$ decay with non-unitary Kraus operators:
$
  E_0 = mat(1, 0; 0, sqrt(1-gamma)), quad E_1 = mat(0, sqrt(gamma); 0, 0).
$ <eq:ampdamp>

The MCWF approach reduces memory requirements from $O(4^n)$ to $O(2^n)$, enabling noise simulation on larger registers at the cost of statistical sampling.

= Neurosymbolic Verification

Quantum simulator testing conventionally relies on regression testing against established libraries. Pauliz augments this with a neurosymbolic verification framework combining symbolic algebraic checks with numerical validation.

== Symbolic Identity Verification

Tests encode fundamental algebraic relations of quantum mechanics. Rather than merely checking numerical output, we verify structural identities:
$
  H dot H &= I, \
  X dot Z dot X &= -Z, \
  "CNOT"_(12) dot "CNOT"_(12) &= I.
$ <eq:identities>

These properties must hold exactly (within machine epsilon) for the implementation to be deemed correct.

== Unitary Constraints

Every gate implementation undergoes verification to ensure it preserves the $L_2$ norm of the state vector:
$
  norm(U ket(psi))_2 = norm(ket(psi))_2 = 1.
$ <eq:unitarity>

This guards against numerical drift and implementation errors. Additionally, gate matrices are verified to satisfy $U^dagger U = I$ within numerical tolerance.

== Parametric Testing

Rotation gates $R_x(theta)$, $R_y(theta)$, $R_z(theta)$ undergo parametric testing across the angular domain $theta in [0, 2pi)$, verifying:
$
  R_alpha(theta + 2pi) = R_alpha(theta), quad R_alpha(0) = I.
$ <eq:periodicity>

This combined symbolic-numerical approach provides stronger correctness guarantees than either method alone.

= Performance Considerations

The compile-time generic architecture enables several performance optimizations unavailable in dynamically-typed languages:

(i) _Loop unrolling_: For small, fixed $n$, the compiler can fully unroll state vector iteration, eliminating loop overhead.

(ii) _SIMD vectorization_: Contiguous memory layout and predictable access patterns facilitate automatic vectorization of complex arithmetic operations.

(iii) _Zero-cost abstractions_: Generic type parameters incur no runtime overhead; specialization occurs at compile time.

(iv) _Cache efficiency_: The interleaved real/imaginary representation maintains spatial locality for complex arithmetic.

Preliminary benchmarks on standard circuits (quantum Fourier transform, Grover's algorithm) indicate performance competitive with optimized C++ simulators while maintaining significantly simpler build requirements.

= Conclusion

Pauliz demonstrates that Zig provides a compelling platform for scientific computing in quantum information science, offering C++-comparable performance with a safer, more accessible developer experience. The compile-time generic system enables type-safe, zero-overhead abstractions while explicit memory management ensures predictable resource utilization.

Future development directions include: (i) tensor network simulation methods to transcend state vector memory limitations; (ii) GPU acceleration via Zig's native interoperability with CUDA/OpenCL; and (iii) distributed simulation for multi-node environments.

The complete source code, documentation, and examples are available under an open-source license at the project repository @Pauliz.

#v(1em)

// =============================================================================
// ACKNOWLEDGMENTS
// =============================================================================
#block(width: 100%)[
  #set par(first-line-indent: 0pt)
  *Acknowledgments.*---The author thanks the Zig community for their development of an excellent systems programming language and the quantum computing open-source community for inspiration and testing methodologies.
]

#v(0.5em)

// =============================================================================
// REFERENCES (APS Style)
// =============================================================================
#set par(first-line-indent: 0pt)
#show bibliography: set text(size: 8.5pt)
#show bibliography: set par(spacing: 0.5em)

#bibliography(
  "refs.bib",
  title: none,
  style: "american-physics-society",
)
