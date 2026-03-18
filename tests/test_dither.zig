//! test_dither.zig — Verify stochastic rendering and depth fade.
//!
//! Tests that dithered lines produce correct pixel coverage at density
//! extremes and that depth fade produces monotonically decreasing brightness.

const std = @import("std");
const dither = @import("dither");
const Framebuffer = @import("framebuffer").Framebuffer;

test "density=255 draws every pixel (solid line)" {
    var fb = Framebuffer.init();
    fb.clear(0);

    // Draw a horizontal line at y=10, x=[5..15]
    dither.ditheredLine(&fb, 5, 10, 15, 10, 0xFFFF, 255, 42);

    // Every pixel in the line should be set
    var count: u32 = 0;
    var x: u16 = 5;
    while (x <= 15) : (x += 1) {
        if (fb.getPixel(x, 10) != 0) count += 1;
    }
    try std.testing.expectEqual(@as(u32, 11), count);
}

test "density=0 draws no pixels" {
    var fb = Framebuffer.init();
    fb.clear(0);

    dither.ditheredLine(&fb, 5, 10, 15, 10, 0xFFFF, 0, 42);

    // No pixels should be set
    var count: u32 = 0;
    var x: u16 = 5;
    while (x <= 15) : (x += 1) {
        if (fb.getPixel(x, 10) != 0) count += 1;
    }
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "ghost density draws partial pixels" {
    var fb = Framebuffer.init();
    fb.clear(0);

    // Draw a longer line with ghost density (184 ≈ 72%)
    dither.ditheredLine(&fb, 0, 20, 79, 20, 0xFFFF, 184, 123);

    // Count drawn pixels — should be between 40% and 95% of 80
    var count: u32 = 0;
    var x: u16 = 0;
    while (x < 80) : (x += 1) {
        if (fb.getPixel(x, 20) != 0) count += 1;
    }
    try std.testing.expect(count > 32); // at least 40%
    try std.testing.expect(count < 76); // at most 95%
}

test "depth fade: closer is brighter than further" {
    const near_color = dither.depthFade(0xFFFF, 2 << 16); // z=2
    const far_color = dither.depthFade(0xFFFF, 8 << 16); // z=8

    // Extract green channel (6 bits, most visible)
    const near_g = (near_color >> 5) & 0x3F;
    const far_g = (far_color >> 5) & 0x3F;

    try std.testing.expect(near_g > far_g);
}

test "depth fade monotonic decrease with distance" {
    // Brightness should decrease (or stay same) as z increases
    var prev_brightness: u32 = 0xFFFF;
    var z: u32 = 2;
    while (z <= 10) : (z += 1) {
        const faded = dither.depthFade(0xFFFF, @intCast(z << 16));
        const brightness: u32 = faded;
        try std.testing.expect(brightness <= prev_brightness);
        prev_brightness = brightness;
    }
}

test "depth fade preserves zero color" {
    const result = dither.depthFade(0x0000, 4 << 16);
    try std.testing.expectEqual(@as(u16, 0), result);
}
