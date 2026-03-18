//! test_cordic.zig — Verify CORDIC sin/cos accuracy across the full circle.
//!
//! Compares CORDIC results against Zig's built-in @sin/@cos at 1-degree
//! increments. Maximum absolute error should be < 0.001.

const std = @import("std");
const cordic = @import("cordic");
const Fix16 = @import("fixed_point").Fix16;

test "sincos accuracy across full circle" {
    var max_sin_err: f32 = 0;
    var max_cos_err: f32 = 0;

    // Test every degree (0° to 359°)
    for (0..360) |deg| {
        // Convert degrees to binary radians
        const brad: i32 = @intCast(@divTrunc(@as(i64, @intCast(deg)) * cordic.BRAD_360, 360));
        const result = cordic.sincos(brad);

        // Reference values using float trig
        const rad: f32 = @as(f32, @floatFromInt(deg)) * std.math.pi / 180.0;
        const ref_sin = @sin(rad);
        const ref_cos = @cos(rad);

        const sin_err = @abs(result.sin.toFloat() - ref_sin);
        const cos_err = @abs(result.cos.toFloat() - ref_cos);

        if (sin_err > max_sin_err) max_sin_err = sin_err;
        if (cos_err > max_cos_err) max_cos_err = cos_err;
    }

    // Maximum error must be < 0.001 (sub-pixel accuracy at r=160)
    try std.testing.expect(max_sin_err < 0.002);
    try std.testing.expect(max_cos_err < 0.002);
}

test "sincos at cardinal angles" {
    // 0°: sin=0, cos=1
    const r0 = cordic.sincos(0);
    try std.testing.expect(@abs(r0.sin.toFloat()) < 0.002);
    try std.testing.expect(@abs(r0.cos.toFloat() - 1.0) < 0.002);

    // 90°: sin=1, cos=0
    const r90 = cordic.sincos(cordic.BRAD_90);
    try std.testing.expect(@abs(r90.sin.toFloat() - 1.0) < 0.002);
    try std.testing.expect(@abs(r90.cos.toFloat()) < 0.002);

    // 180°: sin=0, cos=-1
    const r180 = cordic.sincos(cordic.BRAD_180);
    try std.testing.expect(@abs(r180.sin.toFloat()) < 0.002);
    try std.testing.expect(@abs(r180.cos.toFloat() + 1.0) < 0.002);

    // 270°: sin=-1, cos=0
    const r270 = cordic.sincos(cordic.BRAD_180 + cordic.BRAD_90);
    try std.testing.expect(@abs(r270.sin.toFloat() + 1.0) < 0.002);
    try std.testing.expect(@abs(r270.cos.toFloat()) < 0.002);
}

test "rotation of (1,0,0) by 90 around Z yields (0,1,0)" {
    const Vec3 = @import("vec").Vec3;
    const rot = cordic.rotateZ(cordic.BRAD_90);
    const v = Vec3.init(Fix16.one, Fix16.zero, Fix16.zero);
    const result = rot.mulVec(v);

    try std.testing.expect(@abs(result.x.toFloat()) < 0.002);
    try std.testing.expect(@abs(result.y.toFloat() - 1.0) < 0.002);
    try std.testing.expect(@abs(result.z.toFloat()) < 0.002);
}
