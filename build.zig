//! build.zig — Multi-target build for the 3D wireframe renderer.
//!
//! Supports two platforms:
//! - `sim` (default): Mac/Linux SDL2 simulator
//! - `esp32`: ESP32-PICO cross-compilation via MicroZig (future)
//!
//! ## Usage
//! ```bash
//! zig build run                    # Build and run simulator
//! zig build test                   # Run all unit tests
//! zig build -Dplatform=esp32       # Cross-compile for ESP32 (future)
//! ```

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- Reusable source modules (no SDL2 dependency for pure logic) ---
    const fixed_point_mod = b.createModule(.{
        .root_source_file = b.path("src/math/fixed_point.zig"),
        .target = target,
        .optimize = optimize,
    });

    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config.zig"),
        .target = target,
        .optimize = optimize,
    });

    const vec_mod = b.createModule(.{
        .root_source_file = b.path("src/math/vec.zig"),
        .target = target,
        .optimize = optimize,
    });
    vec_mod.addImport("fixed_point.zig", fixed_point_mod);

    const matrix_mod = b.createModule(.{
        .root_source_file = b.path("src/math/matrix.zig"),
        .target = target,
        .optimize = optimize,
    });
    matrix_mod.addImport("fixed_point.zig", fixed_point_mod);
    matrix_mod.addImport("vec.zig", vec_mod);

    const cordic_mod = b.createModule(.{
        .root_source_file = b.path("src/math/cordic.zig"),
        .target = target,
        .optimize = optimize,
    });
    cordic_mod.addImport("fixed_point.zig", fixed_point_mod);
    cordic_mod.addImport("matrix.zig", matrix_mod);

    // --- Main executable (simulator) ---
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    mod.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    mod.linkSystemLibrary("SDL2", .{});

    const exe = b.addExecutable(.{
        .name = "wireframe",
        .root_module = mod,
    });

    b.installArtifact(exe);

    // --- Run step ---
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Build and run the wireframe renderer");
    run_step.dependOn(&run_cmd.step);

    // --- Unit tests ---
    const test_step = b.step("test", "Run all unit tests");

    // Test: fixed_point
    {
        const t_mod = b.createModule(.{
            .root_source_file = b.path("tests/test_fixed_point.zig"),
            .target = target,
            .optimize = optimize,
        });
        t_mod.addImport("fixed_point", fixed_point_mod);
        const t = b.addTest(.{ .root_module = t_mod });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Test: draw
    {
        const fb_mod = b.createModule(.{
            .root_source_file = b.path("src/gfx/framebuffer.zig"),
            .target = target,
            .optimize = optimize,
        });
        fb_mod.addImport("../config.zig", config_mod);

        const draw_mod = b.createModule(.{
            .root_source_file = b.path("src/gfx/draw.zig"),
            .target = target,
            .optimize = optimize,
        });
        draw_mod.addImport("framebuffer.zig", fb_mod);
        draw_mod.addImport("../config.zig", config_mod);

        const t_mod = b.createModule(.{
            .root_source_file = b.path("tests/test_draw.zig"),
            .target = target,
            .optimize = optimize,
        });
        t_mod.addImport("framebuffer", fb_mod);
        t_mod.addImport("draw", draw_mod);
        const t = b.addTest(.{ .root_module = t_mod });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Test: cordic
    {
        const t_mod = b.createModule(.{
            .root_source_file = b.path("tests/test_cordic.zig"),
            .target = target,
            .optimize = optimize,
        });
        t_mod.addImport("cordic", cordic_mod);
        t_mod.addImport("fixed_point", fixed_point_mod);
        t_mod.addImport("vec", vec_mod);
        t_mod.addImport("matrix", matrix_mod);
        const t = b.addTest(.{ .root_module = t_mod });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Test: mesh
    {
        const projection_mod = b.createModule(.{
            .root_source_file = b.path("src/math/projection.zig"),
            .target = target,
            .optimize = optimize,
        });
        projection_mod.addImport("fixed_point.zig", fixed_point_mod);
        projection_mod.addImport("vec.zig", vec_mod);
        projection_mod.addImport("../config.zig", config_mod);

        const mesh_mod = b.createModule(.{
            .root_source_file = b.path("src/scene/mesh.zig"),
            .target = target,
            .optimize = optimize,
        });
        mesh_mod.addImport("../config.zig", config_mod);
        mesh_mod.addImport("../math/fixed_point.zig", fixed_point_mod);
        mesh_mod.addImport("../math/vec.zig", vec_mod);

        const t_mod = b.createModule(.{
            .root_source_file = b.path("tests/test_mesh.zig"),
            .target = target,
            .optimize = optimize,
        });
        t_mod.addImport("mesh", mesh_mod);
        t_mod.addImport("fixed_point", fixed_point_mod);
        t_mod.addImport("vec", vec_mod);
        t_mod.addImport("projection", projection_mod);
        const t = b.addTest(.{ .root_module = t_mod });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Test: effects
    {
        const fb_mod = b.createModule(.{
            .root_source_file = b.path("src/gfx/framebuffer.zig"),
            .target = target,
            .optimize = optimize,
        });
        fb_mod.addImport("../config.zig", config_mod);

        const draw_mod = b.createModule(.{
            .root_source_file = b.path("src/gfx/draw.zig"),
            .target = target,
            .optimize = optimize,
        });
        draw_mod.addImport("framebuffer.zig", fb_mod);
        draw_mod.addImport("../config.zig", config_mod);

        const effects_mod = b.createModule(.{
            .root_source_file = b.path("src/gfx/effects.zig"),
            .target = target,
            .optimize = optimize,
        });
        effects_mod.addImport("framebuffer.zig", fb_mod);
        effects_mod.addImport("draw.zig", draw_mod);
        effects_mod.addImport("../config.zig", config_mod);

        const palette_mod = b.createModule(.{
            .root_source_file = b.path("src/gfx/palette.zig"),
            .target = target,
            .optimize = optimize,
        });
        palette_mod.addImport("framebuffer.zig", fb_mod);

        const t_mod = b.createModule(.{
            .root_source_file = b.path("tests/test_effects.zig"),
            .target = target,
            .optimize = optimize,
        });
        t_mod.addImport("effects", effects_mod);
        t_mod.addImport("framebuffer", fb_mod);
        t_mod.addImport("palette", palette_mod);
        const t = b.addTest(.{ .root_module = t_mod });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Test: zbuffer
    {
        const zb_mod = b.createModule(.{
            .root_source_file = b.path("src/gfx/zbuffer.zig"),
            .target = target,
            .optimize = optimize,
        });
        zb_mod.addImport("../config.zig", config_mod);

        const t_mod = b.createModule(.{
            .root_source_file = b.path("tests/test_zbuffer.zig"),
            .target = target,
            .optimize = optimize,
        });
        t_mod.addImport("zbuffer", zb_mod);
        const t = b.addTest(.{ .root_module = t_mod });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Test: rasterize
    {
        const fb_mod = b.createModule(.{
            .root_source_file = b.path("src/gfx/framebuffer.zig"),
            .target = target,
            .optimize = optimize,
        });
        fb_mod.addImport("../config.zig", config_mod);

        const zb_mod = b.createModule(.{
            .root_source_file = b.path("src/gfx/zbuffer.zig"),
            .target = target,
            .optimize = optimize,
        });
        zb_mod.addImport("../config.zig", config_mod);

        const rast_mod = b.createModule(.{
            .root_source_file = b.path("src/gfx/rasterize.zig"),
            .target = target,
            .optimize = optimize,
        });
        rast_mod.addImport("framebuffer.zig", fb_mod);
        rast_mod.addImport("zbuffer.zig", zb_mod);
        rast_mod.addImport("../config.zig", config_mod);

        const t_mod = b.createModule(.{
            .root_source_file = b.path("tests/test_rasterize.zig"),
            .target = target,
            .optimize = optimize,
        });
        t_mod.addImport("rasterize", rast_mod);
        t_mod.addImport("framebuffer", fb_mod);
        t_mod.addImport("zbuffer", zb_mod);
        const t = b.addTest(.{ .root_module = t_mod });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Test: scene
    {
        const scene_mod = b.createModule(.{
            .root_source_file = b.path("src/scene/scene.zig"),
            .target = target,
            .optimize = optimize,
        });
        scene_mod.addImport("../math/fixed_point.zig", fixed_point_mod);
        scene_mod.addImport("../math/vec.zig", vec_mod);

        const t_mod = b.createModule(.{
            .root_source_file = b.path("tests/test_scene.zig"),
            .target = target,
            .optimize = optimize,
        });
        t_mod.addImport("scene", scene_mod);
        t_mod.addImport("fixed_point", fixed_point_mod);
        t_mod.addImport("vec", vec_mod);
        const t = b.addTest(.{ .root_module = t_mod });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Test: dither
    {
        const fb_mod = b.createModule(.{
            .root_source_file = b.path("src/gfx/framebuffer.zig"),
            .target = target,
            .optimize = optimize,
        });
        fb_mod.addImport("../config.zig", config_mod);

        const dither_mod = b.createModule(.{
            .root_source_file = b.path("src/gfx/dither.zig"),
            .target = target,
            .optimize = optimize,
        });
        dither_mod.addImport("framebuffer.zig", fb_mod);
        dither_mod.addImport("../config.zig", config_mod);

        const t_mod = b.createModule(.{
            .root_source_file = b.path("tests/test_dither.zig"),
            .target = target,
            .optimize = optimize,
        });
        t_mod.addImport("dither", dither_mod);
        t_mod.addImport("framebuffer", fb_mod);
        const t = b.addTest(.{ .root_module = t_mod });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Test: prime_field
    {
        const pf_mod = b.createModule(.{
            .root_source_file = b.path("src/math/prime_field.zig"),
            .target = target,
            .optimize = optimize,
        });
        const t_mod = b.createModule(.{
            .root_source_file = b.path("tests/test_prime_field.zig"),
            .target = target,
            .optimize = optimize,
        });
        t_mod.addImport("prime_field", pf_mod);
        const t = b.addTest(.{ .root_module = t_mod });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }
}
