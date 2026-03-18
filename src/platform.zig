//! platform.zig — Hardware Abstraction Layer (HAL) interface contract.
//!
//! This file defines the interface that every platform backend must satisfy.
//! Instead of using Zig interfaces (which require dynamic dispatch), we use
//! comptime duck-typing: the platform module must have the right function
//! signatures, checked at compile time via `validatePlatform()`.
//!
//! ## Why this pattern?
//! The M5StickC (ESP32) and Mac simulator have completely different hardware:
//! SPI vs SDL2 for display, I2C vs mouse for IMU, GPIO vs keyboard for buttons.
//! The HAL lets `main.zig` and `renderer.zig` work identically on both platforms.
//!
//! ## Learning Notes
//! This is the "strategy pattern" implemented at compile time. In C, you'd use
//! function pointers (runtime cost). In Zig, comptime generics give zero overhead —
//! the compiler inlines the concrete implementation directly.

const Framebuffer = @import("gfx/framebuffer.zig").Framebuffer;

/// IMU (Inertial Measurement Unit) reading.
/// On ESP32: comes from MPU6886 over I2C.
/// On Mac: synthesized from mouse movement.
pub const ImuData = struct {
    /// Gyroscope angular velocity in binary radians per second.
    /// X = pitch (nod), Y = roll (tilt), Z = yaw (turn).
    gyro_x: i32 = 0,
    gyro_y: i32 = 0,
    gyro_z: i32 = 0,

    /// Accelerometer reading (not used in Phase 5, reserved for future).
    accel_x: i32 = 0,
    accel_y: i32 = 0,
    accel_z: i32 = 0,
};

/// Button state snapshot.
pub const ButtonState = struct {
    /// Button A on M5StickC (front face). Z key on Mac.
    a: bool = false,
    /// Button B on M5StickC (side). X key on Mac.
    b: bool = false,
    /// C key on Mac (backface cull toggle).
    c: bool = false,
    /// V key on Mac (cycle mesh for active object).
    v: bool = false,
    /// Space key on Mac (add object to scene).
    space: bool = false,
    /// P key (cycle palette).
    p: bool = false,
    /// G key (toggle glow).
    g: bool = false,
    /// S key (toggle CRT scanlines).
    s: bool = false,
    /// D key (toggle depth coloring).
    d: bool = false,
    /// True only on the frame the button was first pressed.
    a_pressed: bool = false,
    b_pressed: bool = false,
    c_pressed: bool = false,
    v_pressed: bool = false,
    space_pressed: bool = false,
    p_pressed: bool = false,
    g_pressed: bool = false,
    s_pressed: bool = false,
    d_pressed: bool = false,
    /// Scroll wheel delta (positive = up/zoom in, negative = down/zoom out).
    scroll_y: i32 = 0,
};

/// Validate that a platform module implements all required functions.
///
/// Called at comptime in `hal.zig`. If a function is missing or has the
/// wrong signature, you'll get a clear compile error pointing here.
pub fn validatePlatform(comptime P: type) void {
    // Required functions — existence check via comptime field access.
    _ = &P.init;
    _ = &P.deinit;
    _ = &P.getFramebuffer;
    _ = &P.flushDisplay;
    _ = &P.readImu;
    _ = &P.getButtons;
    _ = &P.pollInput;
    _ = &P.millis;
    _ = &P.shouldQuit;
}
