//! palette.zig — Color palettes for the wireframe renderer.
//!
//! Four aesthetic palettes inspired by classic CRT displays and retro
//! computing. Each palette defines wire color, fill color, and background.
//! Cycle through them with the P key for instant mood changes.
//!
//! ## Palettes
//! - Cyan: cool blue-green (default M5StickC look)
//! - Green Phosphor: classic green terminal (VT100, Matrix)
//! - Amber: warm orange (IBM 5151 monochrome)
//! - Mono: pure white on black (Vectrex, oscilloscope)
//!
//! ## Learning Notes
//! Color palettes are one of the cheapest ways to add visual variety.
//! By swapping just 3 colors (wire, fill, background), the entire scene
//! feels completely different. The same technique is used in NES/Game Boy
//! games and modern pixel art engines.

const Framebuffer = @import("framebuffer.zig").Framebuffer;

/// A complete color scheme for rendering.
pub const Palette = struct {
    /// Wireframe edge color.
    wire: u16,
    /// Solid fill base color.
    fill: u16,
    /// Background clear color.
    background: u16,
    /// Human-readable name for debug overlay.
    name: []const u8,
};

/// Number of available palettes.
pub const PALETTE_COUNT: u8 = 4;

/// All palettes, indexed by palette_index.
pub const palettes = [PALETTE_COUNT]Palette{
    // 0: Cyan — default cool look
    .{
        .wire = Framebuffer.rgb565(0, 220, 255),
        .fill = Framebuffer.rgb565(0, 160, 200),
        .background = Framebuffer.rgb565(4, 4, 16),
        .name = "CYAN",
    },
    // 1: Green Phosphor — classic terminal
    .{
        .wire = Framebuffer.rgb565(0, 255, 80),
        .fill = Framebuffer.rgb565(0, 180, 40),
        .background = Framebuffer.rgb565(0, 8, 0),
        .name = "GREEN",
    },
    // 2: Amber — warm monochrome
    .{
        .wire = Framebuffer.rgb565(255, 180, 0),
        .fill = Framebuffer.rgb565(200, 120, 0),
        .background = Framebuffer.rgb565(16, 8, 0),
        .name = "AMBER",
    },
    // 3: Mono — pure white
    .{
        .wire = Framebuffer.rgb565(255, 255, 255),
        .fill = Framebuffer.rgb565(180, 180, 180),
        .background = Framebuffer.rgb565(0, 0, 0),
        .name = "MONO",
    },
};
