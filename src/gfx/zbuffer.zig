//! zbuffer.zig — Depth buffer for hidden surface removal.
//!
//! A z-buffer stores the depth (distance from camera) of each pixel.
//! When drawing a new pixel, we compare its depth against the stored value:
//! if it's closer, we draw it and update the buffer. If it's further, skip.
//!
//! ## Memory
//! 80×160 pixels × 2 bytes (u16) = 25,600 bytes.
//! Combined with the double framebuffer (51,200 bytes), total is ~77KB —
//! well within the ESP32's 300KB usable SRAM.
//!
//! ## Precision
//! u16 gives 65,536 depth levels. For our z range [2, 12], this maps to
//! ~0.00015 units per step — far more precision than needed for wireframe
//! and flat-shaded rendering on an 80×160 screen.
//!
//! ## Learning Notes
//! The z-buffer was invented by Ed Catmull (later Pixar co-founder) in 1974.
//! It's the standard hidden surface algorithm used by every GPU today.
//! The key insight: per-pixel depth comparison is O(1) — no sorting needed.

const config = @import("../config.zig");

/// Number of pixels in the z-buffer.
const PIXEL_COUNT: usize = @as(usize, config.SCREEN_W) * @as(usize, config.SCREEN_H);

/// Z-buffer for per-pixel depth testing.
pub const ZBuffer = struct {
    buffer: [PIXEL_COUNT]u16,

    /// Initialize with all depths at maximum (far plane).
    pub fn init() ZBuffer {
        return .{ .buffer = [_]u16{0xFFFF} ** PIXEL_COUNT };
    }

    /// Clear all depths to maximum (call once per frame).
    pub fn clear(self: *ZBuffer) void {
        @memset(&self.buffer, 0xFFFF);
    }

    /// Test and conditionally set depth at (x, y).
    ///
    /// Returns true if the new depth is closer (smaller) than the stored
    /// depth, updating the buffer. Returns false if occluded.
    pub fn testAndSet(self: *ZBuffer, x: u16, y: u16, depth: u16) bool {
        if (x >= config.SCREEN_W or y >= config.SCREEN_H) return false;
        const idx = @as(usize, y) * @as(usize, config.SCREEN_W) + @as(usize, x);
        if (depth < self.buffer[idx]) {
            self.buffer[idx] = depth;
            return true;
        }
        return false;
    }

    /// Get the current depth at (x, y). Returns 0xFFFF for out-of-bounds.
    pub fn getDepth(self: *const ZBuffer, x: u16, y: u16) u16 {
        if (x >= config.SCREEN_W or y >= config.SCREEN_H) return 0xFFFF;
        const idx = @as(usize, y) * @as(usize, config.SCREEN_W) + @as(usize, x);
        return self.buffer[idx];
    }
};
