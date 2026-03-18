//! framebuffer.zig — Double-buffered RGB565 framebuffer for tear-free rendering.
//!
//! This module manages two framebuffers: one being drawn to (back buffer)
//! and one being displayed (front buffer). `swap()` flips them atomically.
//! On ESP32, this lets SPI DMA transfer the front buffer while the CPU
//! draws the next frame into the back buffer — zero tearing, zero wait.
//!
//! ## Memory Layout
//! Each buffer is 80×160×2 = 25,600 bytes of RGB565 pixel data.
//! Pixels are stored row-major: buffer[y * SCREEN_W + x].
//! Total: 51,200 bytes for both buffers (~17% of usable ESP32 SRAM).
//!
//! ## Learning Notes
//! RGB565 packs color into 16 bits: 5 red, 6 green, 5 blue. Green gets
//! the extra bit because human eyes are most sensitive to green. This is
//! the native format of the ST7735S display — no conversion needed.

const config = @import("../config.zig");

/// Number of pixels in a single framebuffer.
const FB_PIXELS: usize = @as(usize, config.SCREEN_W) * @as(usize, config.SCREEN_H);

/// Double-buffered framebuffer with RGB565 pixel format.
///
/// Usage:
/// ```
/// var fb = Framebuffer.init();
/// fb.clear(Framebuffer.rgb565(0, 0, 255));  // blue background
/// fb.setPixel(40, 80, Framebuffer.rgb565(255, 255, 255));  // white dot
/// const display_data = fb.swap();  // flip buffers, get front for display
/// ```
pub const Framebuffer = struct {
    /// The two framebuffers. `current` indexes the back buffer (draw target).
    buffers: [2][FB_PIXELS]u16,

    /// Which buffer is currently the back buffer (0 or 1).
    current: u1,

    /// Initialize both buffers to black (all zeros).
    pub fn init() Framebuffer {
        return Framebuffer{
            .buffers = .{ .{0} ** FB_PIXELS, .{0} ** FB_PIXELS },
            .current = 0,
        };
    }

    /// Fill the entire back buffer with a single color.
    ///
    /// Used at the start of each frame to erase the previous frame.
    /// On ESP32 at 240MHz, clearing 25.6KB takes ~0.03ms.
    pub fn clear(self: *Framebuffer, color: u16) void {
        @memset(&self.buffers[self.current], color);
    }

    /// Set a single pixel in the back buffer.
    ///
    /// Coordinates are unsigned — the caller must bounds-check before calling.
    /// This keeps the hot path (line drawing) fast by avoiding redundant checks.
    pub fn setPixel(self: *Framebuffer, x: u16, y: u16, color: u16) void {
        if (x >= config.SCREEN_W or y >= config.SCREEN_H) return;
        self.buffers[self.current][@as(usize, y) * config.SCREEN_W + @as(usize, x)] = color;
    }

    /// Read a pixel from the back buffer. Returns 0 (black) if out of bounds.
    pub fn getPixel(self: *const Framebuffer, x: u16, y: u16) u16 {
        if (x >= config.SCREEN_W or y >= config.SCREEN_H) return 0;
        return self.buffers[self.current][@as(usize, y) * config.SCREEN_W + @as(usize, x)];
    }

    /// Swap front and back buffers. Returns a pointer to the new front buffer
    /// (the one just drawn) as a byte slice for DMA/display transfer.
    ///
    /// After swap, the old front becomes the new back buffer, ready for drawing.
    pub fn swap(self: *Framebuffer) *const [FB_PIXELS]u16 {
        const front = self.current;
        self.current = if (self.current == 0) 1 else 0;
        return &self.buffers[front];
    }

    /// Get a pointer to the raw back buffer data as bytes for display transfer.
    pub fn backBufferBytes(self: *Framebuffer) [*]const u8 {
        return @ptrCast(&self.buffers[self.current]);
    }

    /// Pack 8-bit RGB into RGB565 format.
    ///
    /// RGB565 layout (big-endian): RRRRRGGG GGGBBBBB
    /// - Red:   5 bits (0-31), mapped from 0-255 by >>3
    /// - Green: 6 bits (0-63), mapped from 0-255 by >>2
    /// - Blue:  5 bits (0-31), mapped from 0-255 by >>3
    ///
    /// ## Example
    /// ```
    /// const white = Framebuffer.rgb565(255, 255, 255);  // 0xFFFF
    /// const red   = Framebuffer.rgb565(255, 0, 0);      // 0xF800
    /// const green = Framebuffer.rgb565(0, 255, 0);      // 0x07E0
    /// const blue  = Framebuffer.rgb565(0, 0, 255);      // 0x001F
    /// ```
    pub fn rgb565(r: u8, g: u8, b: u8) u16 {
        return (@as(u16, r >> 3) << 11) | (@as(u16, g >> 2) << 5) | @as(u16, b >> 3);
    }
};
