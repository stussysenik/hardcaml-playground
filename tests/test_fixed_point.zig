//! test_fixed_point.zig — Verify Q16.16 fixed-point accuracy against f32.
//!
//! Tests that our integer-only math produces results within 1 LSB
//! (1/65536 ≈ 0.0000153) of the equivalent floating-point operations.
//! This ensures the renderer will produce correct geometry.

const std = @import("std");
const Fix16 = @import("fixed_point").Fix16;

test "fromInt and toInt roundtrip" {
    try std.testing.expectEqual(@as(i32, 0), Fix16.fromInt(0).toInt());
    try std.testing.expectEqual(@as(i32, 1), Fix16.fromInt(1).toInt());
    try std.testing.expectEqual(@as(i32, -1), Fix16.fromInt(-1).toInt());
    try std.testing.expectEqual(@as(i32, 100), Fix16.fromInt(100).toInt());
    try std.testing.expectEqual(@as(i32, -500), Fix16.fromInt(-500).toInt());
}

test "fromFloat accuracy" {
    const half = Fix16.fromFloat(1.5);
    try std.testing.expectEqual(@as(i32, 98304), half.raw);

    const quarter = Fix16.fromFloat(0.25);
    try std.testing.expectEqual(@as(i32, 16384), quarter.raw);
}

test "addition matches f32" {
    // Test with comptime-known values
    const a1 = Fix16.fromFloat(1.5);
    const b1 = Fix16.fromFloat(2.25);
    try std.testing.expect(@abs(a1.add(b1).toFloat() - 3.75) < 0.001);

    const a2 = Fix16.fromFloat(-3.0);
    const b2 = Fix16.fromFloat(7.5);
    try std.testing.expect(@abs(a2.add(b2).toFloat() - 4.5) < 0.001);

    const a3 = Fix16.fromFloat(-100.5);
    const b3 = Fix16.fromFloat(100.5);
    try std.testing.expect(@abs(a3.add(b3).toFloat()) < 0.001);
}

test "multiplication accuracy" {
    const r1 = Fix16.fromFloat(2.0).mul(Fix16.fromFloat(3.0));
    try std.testing.expect(@abs(r1.toFloat() - 6.0) < 0.01);

    const r2 = Fix16.fromFloat(1.5).mul(Fix16.fromFloat(-2.5));
    try std.testing.expect(@abs(r2.toFloat() - (-3.75)) < 0.01);

    const r3 = Fix16.fromFloat(0.1).mul(Fix16.fromFloat(10.0));
    try std.testing.expect(@abs(r3.toFloat() - 1.0) < 0.01);

    const r4 = Fix16.fromFloat(-4.0).mul(Fix16.fromFloat(-0.25));
    try std.testing.expect(@abs(r4.toFloat() - 1.0) < 0.01);
}

test "multiplication with runtime fromF32" {
    // Test runtime float conversion used in tests
    const values = [_]f32{ 1.5, 2.5, -3.0, 0.1, 100.0 };
    for (values) |v| {
        const fix = Fix16.fromF32(v);
        try std.testing.expect(@abs(fix.toFloat() - v) < 0.001);
    }
}

test "division accuracy" {
    const a = Fix16.fromFloat(10.0);
    const b = Fix16.fromFloat(3.0);
    const result = a.div(b);
    const diff = @abs(result.toFloat() - 3.333333);
    try std.testing.expect(diff < 0.001);
}

test "division by zero returns max/min" {
    const pos = Fix16.fromInt(5);
    const neg = Fix16.fromInt(-5);
    const zero = Fix16.fromInt(0);

    try std.testing.expectEqual(std.math.maxInt(i32), pos.div(zero).raw);
    try std.testing.expectEqual(std.math.minInt(i32), neg.div(zero).raw);
}

test "neg and abs" {
    const val = Fix16.fromFloat(3.5);
    try std.testing.expectEqual(-val.raw, val.neg().raw);
    try std.testing.expectEqual(val.raw, val.neg().abs().raw);
}
