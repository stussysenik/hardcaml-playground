//! overlay.zig — FPS counter and debug text overlay.
//!
//! Renders performance metrics on top of the 3D scene using the 5×7
//! bitmap font. The FPS counter updates once per second to avoid flicker.
//!
//! ## Learning Notes
//! FPS (frames per second) is the primary performance metric for real-time
//! rendering. On the M5StickC, we target 30 FPS (33ms/frame). The counter
//! helps verify we're hitting the target and spot performance regressions.

const Framebuffer = @import("framebuffer.zig").Framebuffer;
const font = @import("font5x7.zig");

/// FPS counter state.
pub const FpsCounter = struct {
    frame_count: u32,
    last_update: u32,
    fps: u32,
    /// Buffer for "XX FPS" string rendering.
    buf: [8]u8,
    buf_len: usize,

    pub fn init() FpsCounter {
        return .{
            .frame_count = 0,
            .last_update = 0,
            .fps = 0,
            .buf = undefined,
            .buf_len = 0,
        };
    }

    /// Call once per frame. Updates the displayed FPS value every second.
    pub fn tick(self: *FpsCounter, now_ms: u32) void {
        self.frame_count += 1;
        if (now_ms - self.last_update >= 1000) {
            self.fps = self.frame_count;
            self.frame_count = 0;
            self.last_update = now_ms;

            // Format "XX FPS" into buffer
            self.buf_len = formatFps(self.fps, &self.buf);
        }
    }

    /// Render the FPS counter at the top-left corner (2, 2).
    pub fn draw(self: *const FpsCounter, fb: *Framebuffer) void {
        if (self.buf_len == 0) return;
        const color = Framebuffer.rgb565(0, 255, 0); // bright green
        font.drawString(fb, 2, 2, self.buf[0..self.buf_len], color);
    }
};

/// Format an integer FPS value as "N FPS" into the provided buffer.
/// Returns the number of characters written.
fn formatFps(fps: u32, buf: *[8]u8) usize {
    var n = fps;
    var digits: [4]u8 = undefined;
    var len: usize = 0;

    if (n == 0) {
        digits[0] = '0';
        len = 1;
    } else {
        while (n > 0 and len < 4) {
            digits[len] = @intCast('0' + (n % 10));
            n /= 10;
            len += 1;
        }
    }

    // Reverse digits into buffer
    for (0..len) |i| {
        buf[i] = digits[len - 1 - i];
    }

    // Append " FPS"
    const suffix = " FPS";
    for (suffix, 0..) |ch, i| {
        buf[len + i] = ch;
    }

    return len + suffix.len;
}
