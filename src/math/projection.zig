//! projection.zig — 3D to 2D perspective projection.
//!
//! Converts 3D world-space vertices into 2D screen-space pixel coordinates.
//! This is the core of any 3D renderer: making far things look small and
//! near things look big.
//!
//! ## Perspective Projection Math
//! For a camera at the origin looking down +Z:
//!   screen_x = (x / z) * focal_length + screen_center_x
//!   screen_y = -(y / z) * focal_length + screen_center_y
//!
//! The division by z creates the perspective effect: distant objects (large z)
//! get divided more, making them smaller on screen. The y-axis is negated
//! because screen y increases downward, but world y increases upward.
//!
//! ## NDC (Normalized Device Coordinates)
//! Before mapping to pixels, we compute NDC: x/z and y/z. These are in the
//! range [-1, 1] for objects within the field of view. Then we scale by
//! focal length and offset to screen center.
//!
//! ## Learning Notes
//! This is identical to the pinhole camera model in computer vision:
//!   [u, v, 1]^T = K * [R|t] * [X, Y, Z, 1]^T
//! Where K contains focal length and principal point (our screen center).
//! We've simplified by assuming camera at origin with no rotation (R=I, t=0).

const Fix16 = @import("fixed_point.zig").Fix16;
const Vec3 = @import("vec.zig").Vec3;
const config = @import("../config.zig");

/// Project a 3D point onto the 2D screen using perspective division.
///
/// Returns screen-space (x, y) as i16. Returns null if the point is
/// behind the camera (z ≤ 0) to avoid division by zero or inverted images.
///
/// Parameters:
/// - `v`: 3D vertex in world space (already rotated)
/// - `focal`: Focal length in Q16.16 (controls field of view)
///
/// ## Coordinate System
/// - World: right-handed, Y-up, camera looks down +Z
/// - Screen: origin top-left, X-right, Y-down
/// - Center of screen: (SCREEN_W/2, SCREEN_H/2) = (40, 80)
pub fn project(v: Vec3, focal: Fix16) ?struct { x: i16, y: i16 } {
    // Safety: skip vertices behind the camera
    const min_z = Fix16.fromFloat(0.1);
    if (v.z.raw <= min_z.raw) return null;

    // Perspective divide: NDC = position / depth
    const ndc_x = v.x.div(v.z);
    const ndc_y = v.y.div(v.z);

    // Scale by focal length and map to screen coordinates
    const screen_x = ndc_x.mul(focal).toInt() + config.SCREEN_W / 2;
    const screen_y = -(ndc_y.mul(focal).toInt()) + config.SCREEN_H / 2;

    return .{
        .x = @intCast(@as(i32, @intCast(screen_x))),
        .y = @intCast(@as(i32, @intCast(screen_y))),
    };
}

/// Default focal length: 38 pixels.
///
/// Chosen so a unit cube at z=4 fills roughly half the 80px screen width.
/// FOV ≈ 2 * atan(40/38) ≈ 92° — wide enough to feel immersive on the
/// tiny display.
pub const DEFAULT_FOCAL = Fix16.fromInt(38);
