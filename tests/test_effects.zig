//! test_effects.zig — Verify visual effects correctness.

const std = @import("std");
const effects = @import("effects");
const Framebuffer = @import("framebuffer").Framebuffer;
const palette = @import("palette");

test "CRT scanlines darken odd rows" {
    var fb = Framebuffer.init();
    // Fill entire screen with white
    var y: u16 = 0;
    while (y < 160) : (y += 1) {
        var x: u16 = 0;
        while (x < 80) : (x += 1) {
            fb.setPixel(x, y, 0xFFFF);
        }
    }

    effects.crtScanlines(&fb);

    // Even rows should remain white (0xFFFF)
    try std.testing.expectEqual(@as(u16, 0xFFFF), fb.getPixel(40, 0));
    try std.testing.expectEqual(@as(u16, 0xFFFF), fb.getPixel(40, 2));

    // Odd rows should be dimmed (halved = 0x7BEF)
    try std.testing.expectEqual(@as(u16, 0x7BEF), fb.getPixel(40, 1));
    try std.testing.expectEqual(@as(u16, 0x7BEF), fb.getPixel(40, 3));
}

test "CRT scanlines preserve even rows" {
    var fb = Framebuffer.init();
    const test_color: u16 = Framebuffer.rgb565(100, 200, 50);

    // Fill with test color
    var y: u16 = 0;
    while (y < 160) : (y += 1) {
        var x: u16 = 0;
        while (x < 80) : (x += 1) {
            fb.setPixel(x, y, test_color);
        }
    }

    effects.crtScanlines(&fb);

    // Even row pixel should be unchanged
    try std.testing.expectEqual(test_color, fb.getPixel(10, 0));
    try std.testing.expectEqual(test_color, fb.getPixel(10, 10));
}

test "glow writes offset pixels" {
    var fb = Framebuffer.init();
    fb.clear(0);

    // Draw a glow line in the middle
    effects.glowLine(&fb, 20, 80, 60, 80, 0xFFFF);

    // Center should have bright pixel
    try std.testing.expect(fb.getPixel(40, 80) != 0);
    // Offset row should have dim pixel (glow halo)
    try std.testing.expect(fb.getPixel(40, 79) != 0); // one pixel above
    try std.testing.expect(fb.getPixel(40, 81) != 0); // one pixel below
}

test "palette count is 4" {
    try std.testing.expectEqual(@as(u8, 4), palette.PALETTE_COUNT);
}

test "palette wraps correctly" {
    // Cycling should wrap around
    var idx: u8 = 0;
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        idx = (idx + 1) % palette.PALETTE_COUNT;
    }
    try std.testing.expectEqual(@as(u8, 0), idx); // 8 presses = 2 full cycles
}

test "all palettes have distinct backgrounds" {
    var i: u8 = 0;
    while (i < palette.PALETTE_COUNT) : (i += 1) {
        var j: u8 = i + 1;
        while (j < palette.PALETTE_COUNT) : (j += 1) {
            try std.testing.expect(
                palette.palettes[i].background != palette.palettes[j].background,
            );
        }
    }
}
