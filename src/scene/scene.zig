//! scene.zig — Scene graph for managing multiple 3D objects.
//!
//! Supports up to 8 independently positioned and rotated objects.
//! Each object references a mesh from the catalog and carries its own
//! rotation angles. The scene tracks which object is "active" (controlled
//! by user input).
//!
//! ## Depth Sorting
//! Objects are sorted back-to-front by their centroid Z after transformation.
//! This is painter's algorithm at the object level — correct as long as
//! objects don't intersect. Insertion sort is used since N ≤ 8.
//!
//! ## Learning Notes
//! A scene graph is the standard way to organize 3D worlds. Production
//! engines use trees (parent-child transforms), but a flat list is perfect
//! for our use case. The key insight: separate "what to draw" (mesh) from
//! "where to draw it" (transform).

const Fix16 = @import("../math/fixed_point.zig").Fix16;
const Vec3 = @import("../math/vec.zig").Vec3;

/// Maximum objects in the scene. 8 keeps sorting trivial and RAM tiny.
pub const MAX_OBJECTS: usize = 8;

/// A single object in the scene.
pub const SceneObject = struct {
    /// Index into the mesh catalog.
    mesh_index: u8,
    /// Position offset from origin in Q16.16.
    position: Vec3,
    /// Rotation angles in binary radians (accumulated from input).
    angle_x: i32,
    angle_y: i32,
    /// Whether this object is currently visible.
    active: bool,

    /// Create a new object at the given position with the specified mesh.
    pub fn init(mesh_index: u8, position: Vec3) SceneObject {
        return .{
            .mesh_index = mesh_index,
            .position = position,
            .angle_x = 0,
            .angle_y = 0,
            .active = true,
        };
    }
};

/// Scene containing multiple objects with depth sorting.
pub const Scene = struct {
    objects: [MAX_OBJECTS]SceneObject,
    count: u8,
    /// Index of the currently selected (user-controlled) object.
    active_index: u8,

    /// Create a scene with one default object (cube at origin).
    pub fn init() Scene {
        var s: Scene = undefined;
        s.count = 1;
        s.active_index = 0;
        s.objects[0] = SceneObject.init(0, Vec3.init(Fix16.zero, Fix16.zero, Fix16.zero));
        return s;
    }

    /// Add a new object to the scene. Returns false if scene is full.
    pub fn addObject(self: *Scene, mesh_index: u8, position: Vec3) bool {
        if (self.count >= MAX_OBJECTS) return false;
        self.objects[self.count] = SceneObject.init(mesh_index, position);
        self.count += 1;
        return true;
    }

    /// Remove the last object. Returns false if only one object remains.
    pub fn removeLastObject(self: *Scene) bool {
        if (self.count <= 1) return false;
        self.count -= 1;
        if (self.active_index >= self.count) {
            self.active_index = 0;
        }
        return true;
    }

    /// Cycle active object index forward.
    pub fn cycleActiveForward(self: *Scene) void {
        if (self.count == 0) return;
        self.active_index = (self.active_index + 1) % self.count;
    }

    /// Get the currently active object (mutable).
    pub fn getActive(self: *Scene) *SceneObject {
        return &self.objects[self.active_index];
    }

    /// Get depth-sorted render order indices (back-to-front).
    /// Uses insertion sort — trivial for N ≤ 8.
    ///
    /// `camera_distance` is the Z translation applied to all objects.
    /// `centroid_z[i]` = object position.z + camera_distance (approximate).
    pub fn getSortedIndices(self: *const Scene, order: *[MAX_OBJECTS]u8) u8 {
        // Initialize indices
        for (0..self.count) |i| {
            order[i] = @intCast(i);
        }

        // Insertion sort by position.z (ascending = back-to-front for +Z forward)
        var i: usize = 1;
        while (i < self.count) : (i += 1) {
            const key = order[i];
            const key_z = self.objects[key].position.z.raw;
            var j: usize = i;
            while (j > 0 and self.objects[order[j - 1]].position.z.raw > key_z) {
                order[j] = order[j - 1];
                j -= 1;
            }
            order[j] = key;
        }

        return self.count;
    }
};
