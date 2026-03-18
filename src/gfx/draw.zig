//! draw.zig — Bresenham line drawing and primitive shapes.
//!
//! Implements integer-only line rasterization for the wireframe renderer.
//! Bresenham's algorithm is the classic approach: it converts a continuous
//! line equation (y = mx + b) into discrete pixel coordinates using only
//! integer addition and comparison — no multiplication or division in the
//! inner loop.
//!
//! ## How Bresenham Works
//! For a line from (x0,y0) to (x1,y1) with slope 0 < m < 1:
//!   1. Start at (x0, y0)
//!   2. Always step +1 in x (the "fast" axis)
//!   3. Maintain an error term that tracks how far we are from the true line
//!   4. When error exceeds 0.5, step +1 in y and subtract 1.0 from error
//!   5. Using 2*error avoids the 0.5 comparison (integer-only)
//!
//! For other slopes, we swap axes and/or negate directions. This handles
//! all 8 octants with one unified loop.
//!
//! ## Dependencies
//! - `gfx/framebuffer.zig` for pixel output
//!
//! ## Learning Notes
//! This is the same algorithm used in early computer graphics (1962, IBM).
//! On the ESP32, each pixel costs ~4 integer ops. A 50-pixel line takes
//! ~200 ops = ~1 microsecond at 240MHz. Drawing 12 edges per frame is
//! essentially free.

const Framebuffer = @import("framebuffer.zig").Framebuffer;
const config = @import("../config.zig");

/// Draw a single pixel with signed coordinates. Out-of-bounds pixels are
/// silently clipped — this keeps the line drawing loop branch-free.
pub fn pixel(fb: *Framebuffer, x: i16, y: i16, color: u16) void {
    if (x < 0 or y < 0) return;
    const ux: u16 = @intCast(x);
    const uy: u16 = @intCast(y);
    fb.setPixel(ux, uy, color);
}

/// Draw a line from (x0, y0) to (x1, y1) using Bresenham's algorithm.
///
/// Handles all 8 octants (any slope, any direction). Pixels outside
/// the screen bounds are silently clipped per-pixel.
///
/// ## Why integer-only?
/// The ESP32's integer multiply is 1 cycle. Avoiding floats means
/// deterministic timing — no surprise slowdowns from denormals or NaN.
pub fn line(fb: *Framebuffer, x0: i16, y0: i16, x1: i16, y1: i16, color: u16) void {
    // Compute absolute deltas and step directions
    var cx: i16 = x0;
    var cy: i16 = y0;

    const dx: i16 = if (x1 > x0) x1 - x0 else x0 - x1;
    const dy: i16 = if (y1 > y0) y1 - y0 else y0 - y1;
    const sx: i16 = if (x0 < x1) 1 else -1;
    const sy: i16 = if (y0 < y1) 1 else -1;

    // Bresenham error term. We use the "error * 2" formulation to avoid
    // fractional comparisons. err starts as dx - dy; the sign tells us
    // which axis to step along.
    var err: i16 = dx - dy;

    while (true) {
        pixel(fb, cx, cy, color);

        // Reached the endpoint — done
        if (cx == x1 and cy == y1) break;

        // Double the error for comparison (avoids 0.5 threshold)
        const e2: i16 = err *| 2;

        // Step in x if error favors horizontal movement
        if (e2 > -dy) {
            err -= dy;
            cx += sx;
        }

        // Step in y if error favors vertical movement
        if (e2 < dx) {
            err += dx;
            cy += sy;
        }
    }
}

/// Draw a rectangle outline (not filled).
pub fn rect(fb: *Framebuffer, x: i16, y: i16, w: u16, h: u16, color: u16) void {
    const x1: i16 = x +| @as(i16, @intCast(w -| 1));
    const y1: i16 = y +| @as(i16, @intCast(h -| 1));
    line(fb, x, y, x1, y, color); // top
    line(fb, x, y1, x1, y1, color); // bottom
    line(fb, x, y, x, y1, color); // left
    line(fb, x1, y, x1, y1, color); // right
}
