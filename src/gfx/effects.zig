//! effects.zig — Post-processing visual effects.
//!
//! All effects operate directly on the framebuffer as post-processing passes.
//! They are designed to be toggleable and composable — apply any combination
//! of CRT scanlines, glow, and depth coloring simultaneously.
//!
//! ## CRT Scanlines
//! Darkens every odd row by shifting all RGB565 channels right by 1.
//! The mask `0x7BEF` prevents bit bleeding between channels:
//!   R: bits 15-11, G: bits 10-5, B: bits 4-0
//!   Shifted: each channel's MSB becomes 0, halving brightness.
//!
//! ## Glow
//! Draws wireframe lines at ±1px offsets in dim (25%) brightness, then
//! the normal line on top. Creates a soft, bloomy halo around edges.
//! Cost: 5× line draws, but still fast for ≤30 edges.
//!
//! ## Learning Notes
//! CRT scanline simulation is a classic post-processing effect in emulators
//! and retro-styled games. The bit manipulation trick (`>> 1 & mask`) is
//! the same technique used in GameBoy Advance homebrew.

const Framebuffer = @import("framebuffer.zig").Framebuffer;
const draw = @import("draw.zig");
const config = @import("../config.zig");

/// Apply CRT scanline darkening to the entire framebuffer.
///
/// Every odd row is dimmed to 50% brightness. This simulates the black
/// lines between phosphor rows on a CRT monitor.
pub fn crtScanlines(fb: *Framebuffer) void {
    var y: u16 = 1; // start at row 1 (first odd row)
    while (y < config.SCREEN_H) : (y += 2) {
        var x: u16 = 0;
        while (x < config.SCREEN_W) : (x += 1) {
            const pixel = fb.getPixel(x, y);
            // Halve each RGB565 channel without cross-channel bleeding
            const dimmed: u16 = (pixel >> 1) & 0x7BEF;
            fb.setPixel(x, y, dimmed);
        }
    }
}

/// Draw a line with glow effect (bloom halo).
///
/// Draws 4 offset copies at 25% brightness, then the bright center line.
/// The offsets create a soft 3-pixel-wide bloom around the edge.
pub fn glowLine(
    fb: *Framebuffer,
    x0: i16,
    y0: i16,
    x1: i16,
    y1: i16,
    color: u16,
) void {
    // 25% brightness for the glow (shift right by 2, mask to prevent bleed)
    const dim: u16 = (color >> 2) & 0x39E7;

    // Draw offset copies (bloom halo)
    draw.line(fb, x0 - 1, y0, x1 - 1, y1, dim); // left
    draw.line(fb, x0 + 1, y0, x1 + 1, y1, dim); // right
    draw.line(fb, x0, y0 - 1, x1, y1 - 1, dim); // up
    draw.line(fb, x0, y0 + 1, x1, y1 + 1, dim); // down

    // Draw bright center line on top
    draw.line(fb, x0, y0, x1, y1, color);
}
