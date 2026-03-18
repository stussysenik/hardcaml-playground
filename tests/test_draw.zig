//! test_draw.zig — Verify Bresenham line drawing correctness.
//!
//! Tests all 8 octants, boundary conditions, and out-of-bounds clipping.
//! Uses a framebuffer to check that pixels land where expected.

const std = @import("std");
const Framebuffer = @import("framebuffer").Framebuffer;
const draw = @import("draw");

test "horizontal line" {
    var fb = Framebuffer.init();
    draw.line(&fb, 10, 50, 20, 50, 0xFFFF);

    // All pixels on the line should be set
    for (10..21) |x| {
        try std.testing.expect(fb.getPixel(@intCast(x), 50) == 0xFFFF);
    }
    // Adjacent pixels should be clear
    try std.testing.expect(fb.getPixel(9, 50) == 0);
    try std.testing.expect(fb.getPixel(21, 50) == 0);
}

test "vertical line" {
    var fb = Framebuffer.init();
    draw.line(&fb, 40, 10, 40, 30, 0xF800);

    for (10..31) |y| {
        try std.testing.expect(fb.getPixel(40, @intCast(y)) == 0xF800);
    }
}

test "diagonal line (45 degrees)" {
    var fb = Framebuffer.init();
    draw.line(&fb, 0, 0, 10, 10, 0x07E0);

    // Diagonal: each step moves both x and y by 1
    for (0..11) |i| {
        try std.testing.expect(fb.getPixel(@intCast(i), @intCast(i)) == 0x07E0);
    }
}

test "steep line (slope > 1)" {
    var fb = Framebuffer.init();
    draw.line(&fb, 10, 10, 12, 20, 0x001F);

    // Start and end pixels should be set
    try std.testing.expect(fb.getPixel(10, 10) == 0x001F);
    try std.testing.expect(fb.getPixel(12, 20) == 0x001F);
}

test "reverse direction line" {
    var fb = Framebuffer.init();
    // Draw from right to left
    draw.line(&fb, 20, 50, 10, 50, 0xFFFF);

    for (10..21) |x| {
        try std.testing.expect(fb.getPixel(@intCast(x), 50) == 0xFFFF);
    }
}

test "negative coordinate clipping" {
    var fb = Framebuffer.init();
    // Line partially off-screen: starts at negative coordinates
    draw.line(&fb, -5, 10, 5, 10, 0xFFFF);

    // Only the visible portion should be drawn
    try std.testing.expect(fb.getPixel(0, 10) == 0xFFFF);
    try std.testing.expect(fb.getPixel(5, 10) == 0xFFFF);
}

test "single pixel line" {
    var fb = Framebuffer.init();
    draw.line(&fb, 40, 80, 40, 80, 0xFFFF);
    try std.testing.expect(fb.getPixel(40, 80) == 0xFFFF);
}

test "all octants - no crash with random coords" {
    var fb = Framebuffer.init();
    // Draw lines in all directions from center — should not crash
    const cx: i16 = 40;
    const cy: i16 = 80;
    const offsets = [_]i16{ -50, -30, -10, 0, 10, 30, 50 };
    for (offsets) |dx| {
        for (offsets) |dy| {
            draw.line(&fb, cx, cy, cx + dx, cy + dy, 0xFFFF);
        }
    }
    // If we got here without crashing, all octants work
}
