//! Complex number implementation for quantum computing.
//!
//! Provides a generic complex number type with all operations needed
//! for quantum state manipulation: addition, multiplication, conjugation,
//! norm, and phase calculations.

const std = @import("std");
const math = std.math;

/// Generic complex number type parameterized by precision.
pub fn Complex(comptime T: type) type {
    return struct {
        re: T,
        im: T,

        const Self = @This();

        // ============================================================
        // Constructors
        // ============================================================

        /// Create a complex number from real and imaginary parts.
        pub fn init(re: T, im: T) Self {
            return .{ .re = re, .im = im };
        }

        /// Create a complex number from a real value (imaginary = 0).
        pub fn fromReal(re: T) Self {
            return .{ .re = re, .im = 0 };
        }

        /// Create a complex number from polar form (r, θ).
        pub fn fromPolar(r: T, theta: T) Self {
            return .{
                .re = r * @cos(theta),
                .im = r * @sin(theta),
            };
        }

        /// Zero complex number.
        pub const zero = Self{ .re = 0, .im = 0 };

        /// One (real unit).
        pub const one = Self{ .re = 1, .im = 0 };

        /// Imaginary unit i.
        pub const i = Self{ .re = 0, .im = 1 };

        // ============================================================
        // Arithmetic Operations
        // ============================================================

        /// Addition: (a + bi) + (c + di) = (a+c) + (b+d)i
        pub fn add(self: Self, other: Self) Self {
            return .{
                .re = self.re + other.re,
                .im = self.im + other.im,
            };
        }

        /// Subtraction: (a + bi) - (c + di) = (a-c) + (b-d)i
        pub fn sub(self: Self, other: Self) Self {
            return .{
                .re = self.re - other.re,
                .im = self.im - other.im,
            };
        }

        /// Multiplication: (a + bi)(c + di) = (ac - bd) + (ad + bc)i
        pub fn mul(self: Self, other: Self) Self {
            return .{
                .re = self.re * other.re - self.im * other.im,
                .im = self.re * other.im + self.im * other.re,
            };
        }

        /// Division: (a + bi) / (c + di)
        pub fn div(self: Self, other: Self) Self {
            const denom = other.re * other.re + other.im * other.im;
            return .{
                .re = (self.re * other.re + self.im * other.im) / denom,
                .im = (self.im * other.re - self.re * other.im) / denom,
            };
        }

        /// Scalar multiplication: s * (a + bi) = sa + sbi
        pub fn scale(self: Self, s: T) Self {
            return .{
                .re = self.re * s,
                .im = self.im * s,
            };
        }

        /// Negation: -(a + bi) = -a - bi
        pub fn neg(self: Self) Self {
            return .{
                .re = -self.re,
                .im = -self.im,
            };
        }

        // ============================================================
        // Complex-Specific Operations
        // ============================================================

        /// Complex conjugate: (a + bi)* = a - bi
        pub fn conj(self: Self) Self {
            return .{
                .re = self.re,
                .im = -self.im,
            };
        }

        /// Squared magnitude: |z|² = a² + b²
        /// This is the probability amplitude in quantum mechanics.
        pub fn normSq(self: Self) T {
            return self.re * self.re + self.im * self.im;
        }

        /// Magnitude: |z| = √(a² + b²)
        pub fn norm(self: Self) T {
            return @sqrt(self.normSq());
        }

        /// Phase angle: arg(z) = atan2(b, a)
        pub fn arg(self: Self) T {
            return math.atan2(self.im, self.re);
        }

        /// Exponential: e^(a + bi) = e^a * (cos(b) + i*sin(b))
        pub fn exp(self: Self) Self {
            const ea = @exp(self.re);
            return .{
                .re = ea * @cos(self.im),
                .im = ea * @sin(self.im),
            };
        }

        // ============================================================
        // Comparison
        // ============================================================

        /// Approximate equality within epsilon tolerance.
        pub fn approxEq(self: Self, other: Self, epsilon: T) bool {
            return @abs(self.re - other.re) < epsilon and
                @abs(self.im - other.im) < epsilon;
        }

        /// Exact equality.
        pub fn eql(self: Self, other: Self) bool {
            return self.re == other.re and self.im == other.im;
        }

        // ============================================================
        // Formatting
        // ============================================================

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            if (self.im >= 0) {
                try writer.print("{d}+{d}i", .{ self.re, self.im });
            } else {
                try writer.print("{d}{d}i", .{ self.re, self.im });
            }
        }
    };
}

// ============================================================
// Symbolic Tests: Algebraic Identities
// ============================================================

test "symbolic: additive identity (z + 0 = z)" {
    const C = Complex(f64);
    const z = C.init(3.0, 4.0);
    const result = z.add(C.zero);
    try std.testing.expect(result.eql(z));
}

test "symbolic: multiplicative identity (z * 1 = z)" {
    const C = Complex(f64);
    const z = C.init(3.0, 4.0);
    const result = z.mul(C.one);
    try std.testing.expect(result.eql(z));
}

test "symbolic: additive inverse (z + (-z) = 0)" {
    const C = Complex(f64);
    const z = C.init(3.0, 4.0);
    const result = z.add(z.neg());
    try std.testing.expect(result.approxEq(C.zero, 1e-10));
}

test "symbolic: i² = -1" {
    const C = Complex(f64);
    const result = C.i.mul(C.i);
    const expected = C.init(-1.0, 0.0);
    try std.testing.expect(result.approxEq(expected, 1e-10));
}

test "symbolic: conjugate of conjugate (z** = z)" {
    const C = Complex(f64);
    const z = C.init(3.0, 4.0);
    const result = z.conj().conj();
    try std.testing.expect(result.eql(z));
}

test "symbolic: |z|² = z * z*" {
    const C = Complex(f64);
    const z = C.init(3.0, 4.0);
    const product = z.mul(z.conj());
    try std.testing.expectApproxEqAbs(z.normSq(), product.re, 1e-10);
    try std.testing.expectApproxEqAbs(0.0, product.im, 1e-10);
}

test "symbolic: Euler's identity (e^(iπ) + 1 = 0)" {
    const C = Complex(f64);
    const i_pi = C.init(0.0, std.math.pi);
    const result = i_pi.exp().add(C.one);
    try std.testing.expect(result.approxEq(C.zero, 1e-10));
}

test "symbolic: polar form round-trip" {
    const C = Complex(f64);
    const z = C.init(3.0, 4.0);
    const r = z.norm();
    const theta = z.arg();
    const reconstructed = C.fromPolar(r, theta);
    try std.testing.expect(z.approxEq(reconstructed, 1e-10));
}

test "unit: multiplication commutativity (ab = ba)" {
    const C = Complex(f64);
    const a = C.init(2.0, 3.0);
    const b = C.init(5.0, -7.0);
    const ab = a.mul(b);
    const ba = b.mul(a);
    try std.testing.expect(ab.approxEq(ba, 1e-10));
}

test "unit: multiplication associativity ((ab)c = a(bc))" {
    const C = Complex(f64);
    const a = C.init(1.0, 2.0);
    const b = C.init(3.0, -1.0);
    const c = C.init(-2.0, 4.0);
    const ab_c = a.mul(b).mul(c);
    const a_bc = a.mul(b.mul(c));
    try std.testing.expect(ab_c.approxEq(a_bc, 1e-10));
}

test "unit: distributivity (a(b+c) = ab + ac)" {
    const C = Complex(f64);
    const a = C.init(2.0, 1.0);
    const b = C.init(3.0, 4.0);
    const c = C.init(-1.0, 2.0);
    const lhs = a.mul(b.add(c));
    const rhs = a.mul(b).add(a.mul(c));
    try std.testing.expect(lhs.approxEq(rhs, 1e-10));
}

test "unit: division inverse (z / z = 1)" {
    const C = Complex(f64);
    const z = C.init(3.0, 4.0);
    const result = z.div(z);
    try std.testing.expect(result.approxEq(C.one, 1e-10));
}

test "unit: 3-4-5 triangle norm" {
    const C = Complex(f64);
    const z = C.init(3.0, 4.0);
    try std.testing.expectApproxEqAbs(5.0, z.norm(), 1e-10);
    try std.testing.expectApproxEqAbs(25.0, z.normSq(), 1e-10);
}
