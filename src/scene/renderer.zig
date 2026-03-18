//! renderer.zig — Full 3D rendering pipeline (wireframe + solid + effects).
//!
//! Orchestrates the complete transform→cull→project→draw pipeline:
//!   1. Rotate all vertices by the current orientation matrix
//!   2. Translate vertices to object position + camera distance
//!   3. Project 3D vertices to 2D screen coordinates
//!   4. Optionally cull back-facing triangles
//!   5. Draw edges and/or filled triangles based on render mode
//!
//! ## Render Modes (u3)
//! - 0: Wireframe only — classic vector display look
//! - 1: Solid (flat-shaded) — filled triangles with lighting
//! - 2: Wireframe + solid overlay — both layers composited
//! - 3: Ghost (dithered wireframe) — stochastic transparency
//! - 4: Dissolve (IMU-jerk dithered) — shake to dissolve
//!
//! ## Visual Effects
//! - Depth coloring: far edges dimmer than near edges
//! - Glow: soft bloom halo around wireframe edges
//! - CRT scanlines and palette cycling are applied in main.zig

const config = @import("../config.zig");
const Fix16 = @import("../math/fixed_point.zig").Fix16;
const Vec3 = @import("../math/vec.zig").Vec3;
const Vec2 = @import("../math/vec.zig").Vec2;
const Mat3 = @import("../math/matrix.zig").Mat3;
const cordic = @import("../math/cordic.zig");
const projection = @import("../math/projection.zig");
const Mesh = @import("mesh.zig").Mesh;
const Camera = @import("camera.zig").Camera;
const scene_mod = @import("scene.zig");
const Scene = scene_mod.Scene;
const mesh_catalog = @import("mesh_catalog.zig");
const Framebuffer = @import("../gfx/framebuffer.zig").Framebuffer;
const draw = @import("../gfx/draw.zig");
const dither = @import("../gfx/dither.zig");
const effects = @import("../gfx/effects.zig");
const rasterize = @import("../gfx/rasterize.zig");
const ZBuffer = @import("../gfx/zbuffer.zig").ZBuffer;
const PrimeField = @import("../math/prime_field.zig").FieldElement;

/// Projected 2D screen coordinates for each vertex.
const ScreenPoint = struct {
    x: i16,
    y: i16,
    z: i32, // world-space Z in Q16.16 (for z-buffer and depth coloring)
    valid: bool,
};

/// Render flags toggled by buttons.
pub const RenderFlags = struct {
    backface_cull: bool = true,
    show_fps: bool = true,
    render_mode: u3 = 0, // 0=wire, 1=solid, 2=wire+solid, 3=ghost, 4=dissolve
    use_zbuffer: bool = true,
    depth_color: bool = false, // depth-based edge dimming
    glow: bool = false, // soft bloom around wireframe edges
};

/// Render all objects in a scene, depth-sorted back-to-front.
pub fn renderScene(
    fb: *Framebuffer,
    scene: *const Scene,
    camera: Camera,
    flags: RenderFlags,
    color: u16,
    frame: u32,
    imu_jerk: u32,
    auto_yaw: i32,
    zbuf: ?*ZBuffer,
) void {
    // Clear z-buffer if using it for solid rendering
    if (zbuf) |zb| {
        if (flags.use_zbuffer and (flags.render_mode == 1 or flags.render_mode == 2)) {
            zb.clear();
        }
    }

    var order: [scene_mod.MAX_OBJECTS]u8 = undefined;
    const count = scene.getSortedIndices(&order);

    for (0..count) |i| {
        const obj = &scene.objects[order[i]];
        if (!obj.active) continue;

        const mesh = &mesh_catalog.catalog[obj.mesh_index];

        const rot_x = cordic.rotateX(obj.angle_x);
        const rot_y = cordic.rotateY(obj.angle_y +% auto_yaw);
        const rotation = rot_x.mul(rot_y);

        render(fb, mesh, rotation, camera, flags, color, frame, imu_jerk, obj.position, zbuf);
    }
}

/// Render a single mesh to the framebuffer.
pub fn render(
    fb: *Framebuffer,
    mesh: *const Mesh,
    rotation: Mat3,
    camera: Camera,
    flags: RenderFlags,
    color: u16,
    frame: u32,
    imu_jerk: u32,
    obj_position: Vec3,
    zbuf: ?*ZBuffer,
) void {
    var screen_pts: [config.MAX_VERTICES]ScreenPoint = undefined;
    var world_pts: [config.MAX_VERTICES]Vec3 = undefined;

    // --- Stage 1: Transform and project vertices ---
    for (0..mesh.vertex_count) |i| {
        const rotated = rotation.mulVec(mesh.vertices[i]);

        const translated = Vec3.init(
            rotated.x.add(obj_position.x),
            rotated.y.add(obj_position.y),
            rotated.z.add(obj_position.z).add(camera.distance),
        );

        world_pts[i] = translated;

        if (projection.project(translated, camera.focal)) |p| {
            screen_pts[i] = .{ .x = p.x, .y = p.y, .z = translated.z.raw, .valid = true };
        } else {
            screen_pts[i] = .{ .x = 0, .y = 0, .z = 0, .valid = false };
        }
    }

    // --- Determine render path ---
    const wants_solid = (flags.render_mode == 1 or flags.render_mode == 2);
    const wants_wire = (flags.render_mode == 0 or flags.render_mode == 2 or
        flags.render_mode == 3 or flags.render_mode == 4);

    // --- Compute wire density ---
    const density: u8 = switch (flags.render_mode) {
        0 => 255,
        1 => 255,
        2 => 255,
        3 => 184,
        4 => blk: {
            const clamped = @min(imu_jerk, 255);
            break :blk @as(u8, @intCast(255 -| clamped));
        },
        else => 255,
    };

    // --- Stage 2: Determine visible faces and edges ---
    var edge_visible: u128 = 0;

    if (flags.backface_cull and mesh.face_count > 0) {
        for (0..mesh.face_count) |fi| {
            const face = mesh.faces[fi];
            const pa = screen_pts[face.a];
            const pb = screen_pts[face.b];
            const pc = screen_pts[face.c];

            if (!pa.valid or !pb.valid or !pc.valid) continue;

            const e1x: i32 = pb.x - pa.x;
            const e1y: i32 = pb.y - pa.y;
            const e2x: i32 = pc.x - pa.x;
            const e2y: i32 = pc.y - pa.y;
            const cross_z: i32 = e1x * e2y - e1y * e2x;

            if (cross_z < 0) {
                for (face.edges) |edge_idx| {
                    edge_visible |= @as(u128, 1) << @intCast(edge_idx);
                }

                if (wants_solid) {
                    fillFace(fb, zbuf, flags, mesh, fi, &screen_pts, &world_pts, color);
                }
            }
        }
    } else {
        for (0..mesh.edge_count) |ei| {
            edge_visible |= @as(u128, 1) << @intCast(ei);
        }
        if (wants_solid) {
            for (0..mesh.face_count) |fi| {
                fillFace(fb, zbuf, flags, mesh, fi, &screen_pts, &world_pts, color);
            }
        }
    }

    // --- Stage 3: Draw wireframe edges ---
    if (wants_wire) {
        const wire_color = if (flags.render_mode == 2)
            Framebuffer.rgb565(255, 255, 255)
        else
            color;

        for (0..mesh.edge_count) |ei| {
            if (edge_visible & (@as(u128, 1) << @intCast(ei)) == 0) continue;
            const edge = mesh.edges[ei];
            const a = screen_pts[edge.a];
            const b = screen_pts[edge.b];
            if (!a.valid or !b.valid) continue;

            // Apply depth coloring: average Z of both endpoints
            const edge_color = if (flags.depth_color) blk: {
                const avg_z = @divTrunc(a.z + b.z, 2);
                break :blk dither.depthFade(wire_color, avg_z);
            } else wire_color;

            if (flags.glow) {
                // Draw glow effect (dim offset lines + bright center)
                effects.glowLine(fb, a.x, a.y, b.x, b.y, edge_color);
            } else {
                drawEdge(fb, a, b, edge_color, density, ei, frame);
            }
        }
    }
}

/// Fill a single face with flat shading.
fn fillFace(
    fb: *Framebuffer,
    zbuf: ?*ZBuffer,
    flags: RenderFlags,
    mesh: *const Mesh,
    fi: usize,
    screen_pts: *const [config.MAX_VERTICES]ScreenPoint,
    world_pts: *const [config.MAX_VERTICES]Vec3,
    base_color: u16,
) void {
    const face = mesh.faces[fi];
    const pa = screen_pts[face.a];
    const pb = screen_pts[face.b];
    const pc = screen_pts[face.c];

    if (!pa.valid or !pb.valid or !pc.valid) return;

    const wa = world_pts[face.a];
    const wb = world_pts[face.b];
    const wc = world_pts[face.c];

    const e1 = Vec3.init(wb.x.sub(wa.x), wb.y.sub(wa.y), wb.z.sub(wa.z));
    const e2 = Vec3.init(wc.x.sub(wa.x), wc.y.sub(wa.y), wc.z.sub(wa.z));

    const normal = e1.cross(e2);

    const brightness = rasterize.flatShade(normal.x.raw, normal.y.raw, normal.z.raw);
    const shaded_color = rasterize.applyBrightness(base_color, brightness);

    const rv0 = rasterize.RasterVertex{ .x = pa.x, .y = pa.y, .z = pa.z };
    const rv1 = rasterize.RasterVertex{ .x = pb.x, .y = pb.y, .z = pb.z };
    const rv2 = rasterize.RasterVertex{ .x = pc.x, .y = pc.y, .z = pc.z };

    const effective_zbuf = if (flags.use_zbuffer) zbuf else null;
    rasterize.fillTriangle(fb, effective_zbuf, rv0, rv1, rv2, shaded_color);
}

/// Draw a single edge, choosing solid or dithered based on density.
fn drawEdge(
    fb: *Framebuffer,
    a: ScreenPoint,
    b: ScreenPoint,
    color: u16,
    density: u8,
    edge_idx: usize,
    frame: u32,
) void {
    if (density == 255) {
        draw.line(fb, a.x, a.y, b.x, b.y, color);
    } else {
        const seed = PrimeField.init(@as(u32, @intCast(edge_idx)) + 1)
            .mul(PrimeField.init((frame % 65521) + 1)).val;
        dither.ditheredLine(fb, a.x, a.y, b.x, b.y, color, density, seed);
    }
}
