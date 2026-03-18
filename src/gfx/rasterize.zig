//! rasterize.zig — Scanline triangle rasterizer with z-buffer support.
//!
//! Fills triangles using the classic flat-top/flat-bottom decomposition:
//!   1. Sort vertices by Y coordinate (top to bottom)
//!   2. Split the triangle into a flat-bottom and flat-top half at the
//!      middle vertex's Y coordinate
//!   3. For each scanline, interpolate X (and Z) along both edges
//!   4. Fill the horizontal span between the two X endpoints
//!
//! ## Fixed-Point Edge Walking
//! Edge X positions are tracked in Q16.16 fixed-point, stepping by
//! dx/dy per scanline. This avoids floating-point and gives sub-pixel
//! accuracy. The inner loop uses only additions — no multiplies.
//!
//! ## Z Interpolation
//! Per-pixel Z is interpolated linearly across each scanline for z-buffer
//! testing. The Z values are mapped from Q16.16 to u16 via right-shift.
//!
//! ## Learning Notes
//! This is the same algorithm used by software renderers in the 1990s
//! (Quake, Unreal). Modern GPUs implement this in hardware with parallel
//! fragment shaders, but the math is identical.

const config = @import("../config.zig");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const ZBuffer = @import("zbuffer.zig").ZBuffer;

/// A vertex with screen position and depth for rasterization.
pub const RasterVertex = struct {
    x: i16,
    y: i16,
    /// Depth in Q16.16 format (raw Fix16 value). Larger = further from camera.
    z: i32,
};

/// Fill a triangle with a solid color, using z-buffer for depth testing.
///
/// Vertices can be in any order — they are sorted internally by Y.
/// If `zbuf` is null, no depth testing is performed (painter's mode).
pub fn fillTriangle(
    fb: *Framebuffer,
    zbuf: ?*ZBuffer,
    v0: RasterVertex,
    v1: RasterVertex,
    v2: RasterVertex,
    color: u16,
) void {
    // Sort vertices by Y (ascending: top to bottom on screen)
    var top = v0;
    var mid = v1;
    var bot = v2;

    if (top.y > mid.y) {
        const tmp = top;
        top = mid;
        mid = tmp;
    }
    if (mid.y > bot.y) {
        const tmp = mid;
        mid = bot;
        bot = tmp;
    }
    if (top.y > mid.y) {
        const tmp = top;
        top = mid;
        mid = tmp;
    }

    // Degenerate: all same Y (horizontal line) or single point
    if (top.y == bot.y) return;

    // Total height of the triangle
    const total_dy = bot.y - top.y;
    if (total_dy == 0) return;

    // Upper half: top → mid
    if (top.y != mid.y) {
        fillHalf(fb, zbuf, top, mid, bot, top.y, mid.y, total_dy, color);
    }

    // Lower half: mid → bot
    if (mid.y != bot.y) {
        fillHalf(fb, zbuf, top, mid, bot, mid.y, bot.y, total_dy, color);
    }
}

/// Fill one half of a split triangle (upper or lower).
///
/// One edge always spans the full height (top→bot). The other edge
/// spans only the half being drawn (y_start→y_end).
fn fillHalf(
    fb: *Framebuffer,
    zbuf: ?*ZBuffer,
    top: RasterVertex,
    mid: RasterVertex,
    bot: RasterVertex,
    y_start: i16,
    y_end: i16,
    total_dy: i16,
    color: u16,
) void {
    const is_upper = (y_start == top.y);

    var y: i16 = @max(y_start, 0);
    const y_max: i16 = @min(y_end, @as(i16, config.SCREEN_H) - 1);

    while (y < y_max) : (y += 1) {
        // Interpolation factor along the full edge (top→bot)
        const t_full_num: i32 = y - top.y;
        const t_full_den: i32 = @as(i32, total_dy);

        // X on the full edge (top→bot)
        const x_full = @as(i32, top.x) + @divTrunc((@as(i32, bot.x) - @as(i32, top.x)) * t_full_num, t_full_den);
        const z_full = top.z + @divTrunc((bot.z - top.z) * t_full_num, t_full_den);

        // X on the half edge
        var x_half: i32 = undefined;
        var z_half: i32 = undefined;
        if (is_upper) {
            // Half edge: top → mid
            const half_dy: i32 = @as(i32, mid.y) - @as(i32, top.y);
            if (half_dy == 0) continue;
            const t_half_num: i32 = y - top.y;
            x_half = @as(i32, top.x) + @divTrunc((@as(i32, mid.x) - @as(i32, top.x)) * t_half_num, half_dy);
            z_half = top.z + @divTrunc((mid.z - top.z) * t_half_num, half_dy);
        } else {
            // Half edge: mid → bot
            const half_dy: i32 = @as(i32, bot.y) - @as(i32, mid.y);
            if (half_dy == 0) continue;
            const t_half_num: i32 = y - mid.y;
            x_half = @as(i32, mid.x) + @divTrunc((@as(i32, bot.x) - @as(i32, mid.x)) * t_half_num, half_dy);
            z_half = mid.z + @divTrunc((bot.z - mid.z) * t_half_num, half_dy);
        }

        // Ensure x_left <= x_right
        var x_left = x_full;
        var x_right = x_half;
        var z_left = z_full;
        var z_right = z_half;
        if (x_left > x_right) {
            const tmp_x = x_left;
            x_left = x_right;
            x_right = tmp_x;
            const tmp_z = z_left;
            z_left = z_right;
            z_right = tmp_z;
        }

        // Clip to screen bounds
        const xl: i16 = @intCast(@max(x_left, 0));
        const xr: i16 = @intCast(@min(x_right, @as(i32, config.SCREEN_W) - 1));

        // Fill the horizontal span
        const span = xr - xl;
        if (span <= 0) {
            // Single pixel
            if (xl >= 0 and xl < config.SCREEN_W) {
                const depth = zToU16(z_left);
                if (zbuf) |zb| {
                    if (zb.testAndSet(@intCast(xl), @intCast(y), depth)) {
                        fb.setPixel(@intCast(xl), @intCast(y), color);
                    }
                } else {
                    fb.setPixel(@intCast(xl), @intCast(y), color);
                }
            }
        } else {
            var x: i16 = xl;
            while (x <= xr) : (x += 1) {
                // Interpolate Z across the span
                const t_span: i32 = @as(i32, x) - x_left;
                const span_width: i32 = x_right - x_left;
                const z_interp = if (span_width > 0)
                    z_left + @divTrunc((z_right - z_left) * t_span, span_width)
                else
                    z_left;

                const depth = zToU16(z_interp);

                if (zbuf) |zb| {
                    if (zb.testAndSet(@intCast(x), @intCast(y), depth)) {
                        fb.setPixel(@intCast(x), @intCast(y), color);
                    }
                } else {
                    fb.setPixel(@intCast(x), @intCast(y), color);
                }
            }
        }
    }
}

/// Convert Q16.16 depth to u16 for z-buffer storage.
/// Clamps to [0, 65535]. Closer objects have smaller values.
fn zToU16(z_raw: i32) u16 {
    // Shift from Q16.16 to u16 range
    const shifted = z_raw >> 8;
    if (shifted < 0) return 0;
    if (shifted > 65535) return 65535;
    return @intCast(shifted);
}

/// Compute flat shading brightness from face normal and light direction.
///
/// Returns a brightness factor in [0, 255] where 255 = fully lit.
/// `nx`, `ny`, `nz` are the face normal components (Q16.16).
/// Uses a fixed light direction of approximately (0.3, 0.7, 0.6) normalized.
pub fn flatShade(nx: i32, ny: i32, nz: i32) u8 {
    // Light direction (pre-normalized, Q16.16):
    // (0.3, 0.7, 0.6) normalized ≈ (0.307, 0.717, 0.614)
    const lx: i32 = 20120; // 0.307 × 65536
    const ly: i32 = 46990; // 0.717 × 65536
    const lz: i32 = 40239; // 0.614 × 65536

    // dot = normal · light (Q32.32, shift back to Q16.16)
    const dot: i64 = @as(i64, nx) * @as(i64, lx) +
        @as(i64, ny) * @as(i64, ly) +
        @as(i64, nz) * @as(i64, lz);

    const dot_fixed: i32 = @intCast(dot >> 16);

    // Clamp to [0, 1] range (negative = facing away from light)
    if (dot_fixed <= 0) return 20; // ambient minimum

    // Scale to [20, 255] — ambient floor of ~8%
    const scaled: i32 = 20 + @divTrunc(dot_fixed * 235, 65536);
    return @intCast(@min(scaled, 255));
}

/// Apply brightness to an RGB565 color.
/// `brightness` is in [0, 255] where 255 = full brightness.
pub fn applyBrightness(base_color: u16, brightness: u8) u16 {
    const r5: u16 = (base_color >> 11) & 0x1F;
    const g6: u16 = (base_color >> 5) & 0x3F;
    const b5: u16 = base_color & 0x1F;

    const br: u32 = @as(u32, brightness);
    const fr: u16 = @intCast((@as(u32, r5) * br) >> 8);
    const fg: u16 = @intCast((@as(u32, g6) * br) >> 8);
    const fb_val: u16 = @intCast((@as(u32, b5) * br) >> 8);

    return (fr << 11) | (fg << 5) | fb_val;
}
