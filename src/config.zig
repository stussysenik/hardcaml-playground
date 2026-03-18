//! config.zig — Compile-time constants for the 3D wireframe renderer.
//!
//! All tunable parameters live here so they're easy to find and modify.
//! Screen dimensions match the M5StickC's ST7735S TFT (80×160 portrait).
//! The simulator scales the window up for comfortable viewing on a desktop.
//!
//! ## Learning Notes
//! Centralizing constants prevents magic numbers scattered across the codebase.
//! `comptime` in Zig means these values are resolved at compile time — zero
//! runtime cost, and the compiler can optimize based on known values.

/// Physical screen width in pixels (M5StickC ST7735S).
pub const SCREEN_W: u16 = 80;

/// Physical screen height in pixels (M5StickC ST7735S).
pub const SCREEN_H: u16 = 160;

/// Target frames per second. 30 FPS gives ~33ms per frame,
/// well within our ~1.6ms CPU budget on ESP32.
pub const TARGET_FPS: u32 = 30;

/// Milliseconds per frame, derived from TARGET_FPS.
pub const FRAME_MS: u32 = 1000 / TARGET_FPS;

/// Scale factor for the SDL2 simulator window.
/// 80×160 is tiny on a desktop, so we scale 4× to 320×640.
pub const SIM_SCALE: u16 = 4;

/// Bytes per framebuffer: width × height × 2 (RGB565 = 16 bits per pixel).
pub const FB_BYTES: usize = @as(usize, SCREEN_W) * @as(usize, SCREEN_H) * 2;

/// Maximum number of vertices a mesh can have.
/// 64 vertices × 12 bytes (3 × i32) = 768 bytes — fits comfortably in SRAM.
pub const MAX_VERTICES: usize = 64;

/// Maximum number of edges a mesh can have.
/// 128 edges × 4 bytes (2 × u16) = 512 bytes.
pub const MAX_EDGES: usize = 128;

/// Maximum number of faces a mesh can have.
pub const MAX_FACES: usize = 64;

/// Maximum faces that can be sorted for painter's algorithm.
/// With 8 objects × 20 faces (icosahedron) = 160, so 256 gives headroom.
pub const MAX_SORTED_FACES: usize = 256;
