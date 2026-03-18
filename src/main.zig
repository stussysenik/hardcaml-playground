//! main.zig — Entry point for the M5StickC 3D wireframe renderer.
//!
//! ## Controls
//! - Mouse: rotate active object
//! - Scroll / Up/Down: zoom camera
//! - Z: cycle active scene object
//! - X: cycle render mode (wire→solid→both→ghost→dissolve)
//! - C: toggle backface culling
//! - V: cycle mesh for active object
//! - Space: add new object to scene
//! - P: cycle color palette
//! - G: toggle glow effect
//! - S: toggle CRT scanlines
//! - D: toggle depth coloring
//! - Escape: quit

const config = @import("config.zig");
const hal = @import("hal.zig");
const Framebuffer = @import("gfx/framebuffer.zig").Framebuffer;
const ZBuffer = @import("gfx/zbuffer.zig").ZBuffer;
const palette_mod = @import("gfx/palette.zig");
const effects = @import("gfx/effects.zig");
const Camera = @import("scene/camera.zig").Camera;
const Scene = @import("scene/scene.zig").Scene;
const mesh_catalog = @import("scene/mesh_catalog.zig");
const renderer = @import("scene/renderer.zig");
const cordic = @import("math/cordic.zig");
const overlay = @import("gfx/overlay.zig");
const Fix16 = @import("math/fixed_point.zig").Fix16;
const Vec3 = @import("math/vec.zig").Vec3;

/// Number of render modes to cycle through.
const RENDER_MODE_COUNT: u3 = 5;

pub fn main() !void {
    var plat = hal.Platform.init();
    defer plat.deinit();

    // --- Initialize scene ---
    var scene = Scene.init();
    var camera = Camera.default;
    var fps_counter = overlay.FpsCounter.init();
    var zbuf = ZBuffer.init();

    // Render flags
    var flags = renderer.RenderFlags{};

    // Visual effect toggles
    var crt_scanlines: bool = false;
    var palette_index: u8 = 0;

    // Frame counter
    var frame: u32 = 0;
    var auto_yaw: i32 = 0;

    // IMU jerk tracking
    var prev_gyro_x: i32 = 0;
    var prev_gyro_z: i32 = 0;

    // Spawn counter
    var spawn_counter: u8 = 0;

    // --- Main loop ---
    while (!plat.shouldQuit()) {
        const frame_start = plat.millis();

        plat.pollInput();

        // Read IMU and integrate rotation for active object
        const imu = plat.readImu();
        const active = scene.getActive();
        active.angle_x +%= imu.gyro_x;
        active.angle_y +%= imu.gyro_z;

        // Compute IMU jerk
        const jerk_x = @abs(imu.gyro_x - prev_gyro_x);
        const jerk_z = @abs(imu.gyro_z - prev_gyro_z);
        const imu_jerk: u32 = @intCast(@min(jerk_x + jerk_z, 255));
        prev_gyro_x = imu.gyro_x;
        prev_gyro_z = imu.gyro_z;

        auto_yaw +%= @divTrunc(cordic.BRAD_360, @as(i32, config.TARGET_FPS) * 10);

        // Handle buttons
        const buttons = plat.getButtons();

        if (buttons.a_pressed) scene.cycleActiveForward(); // Z
        if (buttons.b_pressed) { // X = cycle render mode
            flags.render_mode = @intCast((@as(u4, flags.render_mode) + 1) % RENDER_MODE_COUNT);
        }
        if (buttons.c_pressed) flags.backface_cull = !flags.backface_cull; // C
        if (buttons.v_pressed) { // V = cycle mesh
            const obj = scene.getActive();
            obj.mesh_index = (obj.mesh_index + 1) % mesh_catalog.MESH_COUNT;
        }
        if (buttons.space_pressed) { // Space = add object
            const spawn_positions = [_]Vec3{
                Vec3.init(Fix16.fromFloat(1.2), Fix16.zero, Fix16.zero),
                Vec3.init(Fix16.fromFloat(-1.2), Fix16.zero, Fix16.zero),
                Vec3.init(Fix16.zero, Fix16.fromFloat(1.2), Fix16.zero),
                Vec3.init(Fix16.zero, Fix16.fromFloat(-1.2), Fix16.zero),
                Vec3.init(Fix16.fromFloat(0.8), Fix16.fromFloat(0.8), Fix16.zero),
                Vec3.init(Fix16.fromFloat(-0.8), Fix16.fromFloat(0.8), Fix16.zero),
                Vec3.init(Fix16.fromFloat(0.8), Fix16.fromFloat(-0.8), Fix16.zero),
            };
            if (spawn_counter < spawn_positions.len) {
                _ = scene.addObject(spawn_counter % mesh_catalog.MESH_COUNT, spawn_positions[spawn_counter]);
                spawn_counter += 1;
            }
        }
        if (buttons.p_pressed) { // P = cycle palette
            palette_index = (palette_index + 1) % palette_mod.PALETTE_COUNT;
        }
        if (buttons.g_pressed) flags.glow = !flags.glow; // G
        if (buttons.s_pressed) crt_scanlines = !crt_scanlines; // S
        if (buttons.d_pressed) flags.depth_color = !flags.depth_color; // D

        // Scroll = zoom
        if (buttons.scroll_y > 0) camera.zoomIn() else if (buttons.scroll_y < 0) camera.zoomOut();

        // Get current palette
        const pal = palette_mod.palettes[palette_index];

        // Clear and render
        const fb = plat.getFramebuffer();
        fb.clear(pal.background);

        renderer.renderScene(fb, &scene, camera, flags, pal.wire, frame, imu_jerk, auto_yaw, &zbuf);

        // Post-processing effects
        if (crt_scanlines) {
            effects.crtScanlines(fb);
        }

        // FPS overlay
        fps_counter.tick(plat.millis());
        if (flags.show_fps) {
            fps_counter.draw(fb);
        }

        plat.flushDisplay();

        // Frame rate limiting
        const frame_time = plat.millis() - frame_start;
        if (frame_time < config.FRAME_MS) {
            plat.delay(config.FRAME_MS - frame_time);
        }

        frame +%= 1;
    }
}
