//! fixed_point.zig — Q16.16 fixed-point arithmetic type.
//!
//! Fixed-point math represents fractional numbers using integers. Q16.16
//! means 16 bits for the integer part and 16 bits for the fraction, stored
//! in a single i32. This gives:
//!   - Range: [-32768.0, +32767.99998] (±32K)
//!   - Precision: 1/65536 ≈ 0.0000153 (sub-pixel accurate)
//!   - Operations: add/sub are just integer add/sub (free!)
//!   - Multiply: needs i64 intermediate to avoid overflow
//!   - Division: needs i64 pre-shift for precision
//!
//! ## Why fixed-point instead of float?
//! The ESP32 has no FPU. Soft-float adds ~10x overhead per operation.
//! Fixed-point keeps everything in hardware integer ALU — deterministic
//! and fast. The tradeoff is limited range, but ±32K is plenty for our
//! 80×160 screen coordinates and small 3D scenes.
//!
//! ## Learning Notes
//! Fixed-point is the foundation of old-school game engines (DOOM, Quake),
//! embedded DSP, and financial computing (where exact decimal is critical).
//! The key insight: shifting left by N is equivalent to multiplying by 2^N,
//! so `value << 16` converts an integer to Q16.16.

/// Q16.16 fixed-point number. 16 bits integer, 16 bits fraction.
///
/// Internal representation: the real value `v` is stored as `v * 65536`.
/// For example, 1.5 is stored as 98304 (1.5 × 65536).
pub const Fix16 = struct {
    raw: i32,

    /// Number of fractional bits.
    pub const FRAC_BITS: u5 = 16;

    /// Scale factor: 2^16 = 65536.
    pub const ONE: i32 = 1 << FRAC_BITS;

    /// Create a Fix16 from an integer value.
    /// Example: Fix16.fromInt(3) represents 3.0
    pub fn fromInt(val: i32) Fix16 {
        return .{ .raw = val << FRAC_BITS };
    }

    /// Create a Fix16 from a raw Q16.16 value.
    /// Use when you already have the scaled representation.
    pub fn fromRaw(raw: i32) Fix16 {
        return .{ .raw = raw };
    }

    /// Create Fix16 from a comptime float. Only usable at compile time.
    /// Example: Fix16.fromFloat(1.5) = Fix16{ .raw = 98304 }
    pub fn fromFloat(comptime val: comptime_float) Fix16 {
        return .{ .raw = @intFromFloat(val * @as(comptime_float, ONE)) };
    }

    /// Create Fix16 from a runtime f32 value. For testing only — not for
    /// production code on ESP32 (uses soft-float).
    pub fn fromF32(val: f32) Fix16 {
        return .{ .raw = @intFromFloat(val * @as(f32, @floatFromInt(ONE))) };
    }

    /// Convert to integer by truncating the fractional part.
    pub fn toInt(self: Fix16) i32 {
        return self.raw >> FRAC_BITS;
    }

    /// Convert to f32 for debugging/testing. NOT for use in production code.
    pub fn toFloat(self: Fix16) f32 {
        return @as(f32, @floatFromInt(self.raw)) / @as(f32, @floatFromInt(ONE));
    }

    /// Addition. Same as integer add — no scaling needed.
    pub fn add(a: Fix16, b: Fix16) Fix16 {
        return .{ .raw = a.raw +% b.raw };
    }

    /// Subtraction.
    pub fn sub(a: Fix16, b: Fix16) Fix16 {
        return .{ .raw = a.raw -% b.raw };
    }

    /// Multiplication. Uses i64 intermediate to prevent overflow.
    ///
    /// Math: (a × 2^16) × (b × 2^16) = ab × 2^32
    /// We need ab × 2^16, so shift right by 16 after the multiply.
    pub fn mul(a: Fix16, b: Fix16) Fix16 {
        const wide: i64 = @as(i64, a.raw) * @as(i64, b.raw);
        return .{ .raw = @intCast(wide >> FRAC_BITS) };
    }

    /// Division. Pre-shifts numerator to maintain precision.
    ///
    /// Math: (a × 2^16) / (b × 2^16) = a/b (lost the scale!)
    /// Fix: shift a left by 16 first: (a × 2^32) / (b × 2^16) = (a/b) × 2^16
    pub fn div(a: Fix16, b: Fix16) Fix16 {
        if (b.raw == 0) return .{ .raw = if (a.raw >= 0) std.math.maxInt(i32) else std.math.minInt(i32) };
        const wide: i64 = @as(i64, a.raw) << FRAC_BITS;
        return .{ .raw = @intCast(@divTrunc(wide, b.raw)) };
    }

    /// Negate: -x
    pub fn neg(self: Fix16) Fix16 {
        return .{ .raw = -%self.raw };
    }

    /// Absolute value.
    pub fn abs(self: Fix16) Fix16 {
        return .{ .raw = if (self.raw < 0) -%self.raw else self.raw };
    }

    /// Zero constant.
    pub const zero = Fix16{ .raw = 0 };

    /// One constant (1.0).
    pub const one = Fix16{ .raw = ONE };

    /// Compare: returns true if a > b.
    pub fn gt(a: Fix16, b: Fix16) bool {
        return a.raw > b.raw;
    }

    /// Compare: returns true if a < b.
    pub fn lt(a: Fix16, b: Fix16) bool {
        return a.raw < b.raw;
    }
};

const std = @import("std");
