//! dither.zig — Stochastic line drawing and depth-based fade.
//!
//! Adds visual effects to the wireframe by drawing lines with probabilistic
//! pixel placement. Instead of every pixel being solid, each pixel fires
//! with a probability proportional to a "density" parameter (0-255).
//!
//! ## Stochastic Bresenham
//! Same as regular Bresenham, but before drawing each pixel, we generate
//! a pseudo-random number and compare it to the density threshold. This
//! creates a shimmering, ghostly wireframe effect.
//!
//! ## LCG (Linear Congruential Generator)
//! We use a tiny PRNG with prime modulus 251, multiplier 29, offset 43.
//! Period = 250 (full period for mod 251). Fast enough for per-pixel use,
//! and the short period is fine since no single edge exceeds ~200 pixels.
//!
//! ## Rendering Modes
//! - Mode A (Solid): density=255, every pixel drawn
//! - Mode B (Ghost): density≈184 (~72%), shimmering effect
//! - Mode C (Dissolve): density varies with IMU jerk (shake = dissolve)
//!
//! ## Learning Notes
//! Stochastic rendering is used in production ray tracers (path tracing)
//! to approximate continuous integrals with random sampling. Our version
//! is much simpler but uses the same principle: randomness creates the
//! illusion of partial transparency without needing alpha blending.

const Framebuffer = @import("framebuffer.zig").Framebuffer;
const config = @import("../config.zig");

/// LCG state for stochastic drawing. Per-line seed for variety.
const LcgState = struct {
    state: u8,

    fn init(seed: u16) LcgState {
        // Mix the seed into a starting state
        return .{ .state = @as(u8, @truncate(seed ^ (seed >> 8))) | 1 };
    }

    /// Generate next pseudo-random value in [0, 250].
    fn next(self: *LcgState) u8 {
        // LCG: state = (29 * state + 43) mod 251
        const wide: u16 = (@as(u16, self.state) * 29 + 43) % 251;
        self.state = @intCast(wide);
        return self.state;
    }
};

/// Draw a stochastic (dithered) line from (x0,y0) to (x1,y1).
///
/// `density` controls how many pixels are drawn:
/// - 255 = all pixels (identical to solid line)
/// - 128 ≈ 50% of pixels
/// - 0 = no pixels
///
/// `seed` should vary per-edge per-frame for visual variety.
pub fn ditheredLine(
    fb: *Framebuffer,
    x0: i16,
    y0: i16,
    x1: i16,
    y1: i16,
    color: u16,
    density: u8,
    seed: u16,
) void {
    if (density == 0) return;

    var rng = LcgState.init(seed);

    var cx: i16 = x0;
    var cy: i16 = y0;

    const dx: i16 = if (x1 > x0) x1 - x0 else x0 - x1;
    const dy: i16 = if (y1 > y0) y1 - y0 else y0 - y1;
    const sx: i16 = if (x0 < x1) 1 else -1;
    const sy: i16 = if (y0 < y1) 1 else -1;
    var err: i16 = dx - dy;

    while (true) {
        // Stochastic test: draw pixel only if random < density
        if (density == 255 or rng.next() < density) {
            if (cx >= 0 and cy >= 0) {
                const ux: u16 = @intCast(cx);
                const uy: u16 = @intCast(cy);
                fb.setPixel(ux, uy, color);
            }
        }

        if (cx == x1 and cy == y1) break;

        const e2: i16 = err *| 2;
        if (e2 > -dy) {
            err -= dy;
            cx += sx;
        }
        if (e2 < dx) {
            err += dx;
            cy += sy;
        }
    }
}

/// Compute a depth-faded color. Objects further from the camera get dimmer.
///
/// `depth_z` is the Z coordinate in Q16.16. Closer = brighter, further = dimmer.
/// Returns an RGB565 color scaled by depth.
pub fn depthFade(base_color: u16, depth_raw: i32) u16 {
    // Extract RGB components from RGB565
    const r5: u16 = (base_color >> 11) & 0x1F;
    const g6: u16 = (base_color >> 5) & 0x3F;
    const b5: u16 = base_color & 0x1F;

    // Compute fade factor: 1.0 at z=2, 0.25 at z=8, linear falloff
    // depth_raw is Q16.16, so z=4.0 → depth_raw ≈ 262144
    const z_units: u32 = @intCast(@max(depth_raw, 1 << 16) >> 16); // clamp to >= 1
    const fade: u32 = @min(256, 512 / @max(z_units, 1)); // 256 = full brightness

    // Apply fade
    const fr: u16 = @intCast((@as(u32, r5) * fade) >> 8);
    const fg: u16 = @intCast((@as(u32, g6) * fade) >> 8);
    const fb_val: u16 = @intCast((@as(u32, b5) * fade) >> 8);

    return (fr << 11) | (fg << 5) | fb_val;
}
