//! camera.zig — Camera parameters for 3D rendering.
//!
//! Defines where the virtual camera sits and how it projects the 3D scene
//! onto the 2D screen. For this renderer, the camera is always at the origin
//! looking down the +Z axis. The scene is translated along Z to be in view.
//!
//! ## Zoom
//! `zoomIn()` and `zoomOut()` adjust the camera distance, clamped to [2.0, 12.0].
//! This changes the apparent size of objects without modifying their geometry.
//!
//! ## Learning Notes
//! In a full 3D engine, the camera would have position, orientation, and
//! a view matrix. We simplify: the model moves in front of a fixed camera.
//! Same visual result with less math — the classic trick from early 3D games.

const Fix16 = @import("../math/fixed_point.zig").Fix16;

/// Camera configuration.
pub const Camera = struct {
    /// Focal length in Q16.16 pixels. Controls field of view.
    /// Larger = narrower FOV (telephoto), smaller = wider FOV (fisheye).
    focal: Fix16,

    /// Distance from camera to the model center along Z axis.
    /// The model is translated by (0, 0, +distance) before projection.
    distance: Fix16,

    /// Default camera: focal=38px, distance=4.0 units.
    /// A unit cube at z=4 fills about 40% of the 80px width.
    pub const default = Camera{
        .focal = Fix16.fromInt(38),
        .distance = Fix16.fromInt(4),
    };

    /// Minimum zoom distance (closest the camera can get).
    const MIN_DISTANCE = Fix16.fromInt(2);

    /// Maximum zoom distance (farthest the camera can get).
    const MAX_DISTANCE = Fix16.fromInt(12);

    /// Zoom step size per input tick.
    const ZOOM_STEP = Fix16.fromFloat(0.25);

    /// Zoom in (move camera closer). Clamps at minimum distance.
    pub fn zoomIn(self: *Camera) void {
        const new_dist = self.distance.sub(ZOOM_STEP);
        self.distance = if (new_dist.raw > MIN_DISTANCE.raw) new_dist else MIN_DISTANCE;
    }

    /// Zoom out (move camera further). Clamps at maximum distance.
    pub fn zoomOut(self: *Camera) void {
        const new_dist = self.distance.add(ZOOM_STEP);
        self.distance = if (new_dist.raw < MAX_DISTANCE.raw) new_dist else MAX_DISTANCE;
    }
};
