//! prime_field.zig — Arithmetic in GF(65521), a prime field.
//!
//! A prime field GF(p) is the set {0, 1, ..., p-1} with addition and
//! multiplication done modulo p. Every nonzero element has a unique
//! multiplicative inverse, which makes the arithmetic exact (no rounding).
//!
//! ## Why 65521?
//! It's the largest prime < 2^16. This means:
//! - All elements fit in a u16
//! - Products fit in u32 (no i64 needed)
//! - Same prime used by Adler-32 checksum (a nice coincidence)
//!
//! ## Use Cases
//! - Vertex hashing for noise seed distribution
//! - Deterministic pseudo-random patterns that tile perfectly
//! - Non-repeating dither patterns across frames
//!
//! ## Learning Notes
//! Prime fields (also called Galois fields) are fundamental in:
//! - Cryptography (RSA, elliptic curves)
//! - Error-correcting codes (Reed-Solomon)
//! - Procedural generation (hash functions)
//! The key property: every equation ax = b (a ≠ 0) has exactly one solution.

/// The prime modulus. Largest prime below 2^16.
pub const P: u32 = 65521;

/// A field element in GF(65521).
pub const FieldElement = struct {
    val: u16,

    /// Create from integer, reducing mod P.
    pub fn init(v: u32) FieldElement {
        return .{ .val = @intCast(v % P) };
    }

    /// Addition mod P.
    pub fn add(a: FieldElement, b: FieldElement) FieldElement {
        const sum: u32 = @as(u32, a.val) + @as(u32, b.val);
        return .{ .val = @intCast(sum % P) };
    }

    /// Subtraction mod P.
    pub fn sub(a: FieldElement, b: FieldElement) FieldElement {
        const diff: u32 = @as(u32, a.val) + P - @as(u32, b.val);
        return .{ .val = @intCast(diff % P) };
    }

    /// Multiplication mod P.
    pub fn mul(a: FieldElement, b: FieldElement) FieldElement {
        const prod: u32 = @as(u32, a.val) * @as(u32, b.val);
        return .{ .val = @intCast(prod % P) };
    }

    /// Multiplicative inverse using Fermat's little theorem:
    /// a^(-1) = a^(p-2) mod p.
    ///
    /// This works because a^(p-1) = 1 (mod p) for any a ≠ 0,
    /// so a^(p-2) * a = 1 (mod p), meaning a^(p-2) is the inverse.
    pub fn inv(self: FieldElement) FieldElement {
        return self.pow(P - 2);
    }

    /// Exponentiation by squaring: a^n mod P.
    ///
    /// Computes the power in O(log n) multiplications using the
    /// binary representation of n. Classic algorithm from 1614.
    pub fn pow(self: FieldElement, n: u32) FieldElement {
        var result = FieldElement{ .val = 1 };
        var base = self;
        var exp = n;
        while (exp > 0) {
            if (exp & 1 == 1) {
                result = result.mul(base);
            }
            base = base.mul(base);
            exp >>= 1;
        }
        return result;
    }

    /// Zero element.
    pub const zero = FieldElement{ .val = 0 };

    /// One element (multiplicative identity).
    pub const one = FieldElement{ .val = 1 };
};
