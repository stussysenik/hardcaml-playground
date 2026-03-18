//! hal.zig — Comptime platform selector.
//!
//! This module picks the correct platform backend at compile time based on
//! the build option `-Dplatform=sim|esp32`. It re-exports the chosen
//! platform's types so the rest of the codebase can just `@import("hal.zig")`.
//!
//! ## How it works
//! Zig evaluates `@import` at comptime, so only the selected platform's code
//! gets compiled. The ESP32 backend won't even be parsed when building for sim,
//! avoiding any SDL2/MicroZig dependency conflicts.
//!
//! ## Learning Notes
//! This is Zig's answer to C's `#ifdef PLATFORM_ESP32`. But unlike C preprocessor
//! macros, Zig's comptime is type-checked and IDE-friendly.

const platform = @import("platform.zig");

// For now, we only have the simulator backend.
// ESP32 backend will be added when hardware is available.
const sim = @import("hal/sim.zig");

/// The active platform type. All platform-dependent code uses this.
pub const Platform = sim.SimPlatform;

// Compile-time validation: ensure the platform satisfies the HAL contract.
comptime {
    platform.validatePlatform(Platform);
}
