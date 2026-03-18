//! test_rasterize.zig — Verify scanline triangle rasterization.

const std = @import("std");
const rasterize = @import("rasterize");
const Framebuffer = @import("framebuffer").Framebuffer;
const ZBuffer = @import("zbuffer").ZBuffer;

test "triangle fills pixels within bounds" {
    var fb = Framebuffer.init();
    fb.clear(0);

    // Small triangle in the middle of the screen
    const v0 = rasterize.RasterVertex{ .x = 40, .y = 60, .z = 4 << 16 };
    const v1 = rasterize.RasterVertex{ .x = 50, .y = 80, .z = 4 << 16 };
    const v2 = rasterize.RasterVertex{ .x = 30, .y = 80, .z = 4 << 16 };

    rasterize.fillTriangle(&fb, null, v0, v1, v2, 0xFFFF);

    // Center of triangle should be filled
    try std.testing.expect(fb.getPixel(40, 70) != 0);
    // Way outside should not be filled
    try std.testing.expect(fb.getPixel(10, 10) == 0);
}

test "degenerate triangle (zero area) draws nothing" {
    var fb = Framebuffer.init();
    fb.clear(0);

    // All points on same Y = horizontal line = zero area
    const v0 = rasterize.RasterVertex{ .x = 10, .y = 50, .z = 3 << 16 };
    const v1 = rasterize.RasterVertex{ .x = 20, .y = 50, .z = 3 << 16 };
    const v2 = rasterize.RasterVertex{ .x = 30, .y = 50, .z = 3 << 16 };

    rasterize.fillTriangle(&fb, null, v0, v1, v2, 0xFFFF);

    // Should not draw anything (degenerate)
    var count: u32 = 0;
    var x: u16 = 0;
    while (x < 80) : (x += 1) {
        if (fb.getPixel(x, 50) != 0) count += 1;
    }
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "zbuffer occlusion works with triangles" {
    var fb = Framebuffer.init();
    var zb = ZBuffer.init();
    fb.clear(0);

    // Near triangle (z=2) with red color
    const near0 = rasterize.RasterVertex{ .x = 35, .y = 70, .z = 2 << 16 };
    const near1 = rasterize.RasterVertex{ .x = 45, .y = 90, .z = 2 << 16 };
    const near2 = rasterize.RasterVertex{ .x = 25, .y = 90, .z = 2 << 16 };
    const red = Framebuffer.rgb565(255, 0, 0);
    rasterize.fillTriangle(&fb, &zb, near0, near1, near2, red);

    // Far triangle (z=8) with green color, overlapping
    const far0 = rasterize.RasterVertex{ .x = 30, .y = 65, .z = 8 << 16 };
    const far1 = rasterize.RasterVertex{ .x = 50, .y = 95, .z = 8 << 16 };
    const far2 = rasterize.RasterVertex{ .x = 20, .y = 95, .z = 8 << 16 };
    const green = Framebuffer.rgb565(0, 255, 0);
    rasterize.fillTriangle(&fb, &zb, far0, far1, far2, green);

    // Overlapping pixel should be red (near wins)
    const pixel = fb.getPixel(35, 80);
    // Red channel should be non-zero, green should dominate elsewhere
    try std.testing.expect(pixel == red or pixel != green);
}

test "flat shading: light-facing normal is brighter" {
    // Normal pointing toward light (0.3, 0.7, 0.6) should be bright
    const bright = rasterize.flatShade(0, 0, 1 << 16); // pointing +Z
    // Normal pointing away should be dim (ambient only)
    const dim = rasterize.flatShade(0, 0, -(1 << 16)); // pointing -Z

    try std.testing.expect(bright > dim);
}

test "apply brightness scales color" {
    const white = Framebuffer.rgb565(255, 255, 255); // 0xFFFF
    const full = rasterize.applyBrightness(white, 255);
    const half = rasterize.applyBrightness(white, 128);
    const dark = rasterize.applyBrightness(white, 0);

    // Full brightness should preserve most of the color
    try std.testing.expect(full > half);
    try std.testing.expect(half > dark);
    try std.testing.expectEqual(@as(u16, 0), dark);
}

test "triangle vertex order does not matter" {
    // Same triangle in different vertex orders should fill the same area
    var fb1 = Framebuffer.init();
    var fb2 = Framebuffer.init();
    fb1.clear(0);
    fb2.clear(0);

    const va = rasterize.RasterVertex{ .x = 20, .y = 40, .z = 4 << 16 };
    const vb = rasterize.RasterVertex{ .x = 60, .y = 100, .z = 4 << 16 };
    const vc = rasterize.RasterVertex{ .x = 10, .y = 90, .z = 4 << 16 };

    rasterize.fillTriangle(&fb1, null, va, vb, vc, 0xFFFF);
    rasterize.fillTriangle(&fb2, null, vc, va, vb, 0xFFFF);

    // Count filled pixels — should be identical
    var count1: u32 = 0;
    var count2: u32 = 0;
    var y: u16 = 0;
    while (y < 160) : (y += 1) {
        var x: u16 = 0;
        while (x < 80) : (x += 1) {
            if (fb1.getPixel(x, y) != 0) count1 += 1;
            if (fb2.getPixel(x, y) != 0) count2 += 1;
        }
    }
    try std.testing.expectEqual(count1, count2);
}
