//! vec.zig — Fixed-point 2D and 3D vector types.
//!
//! Vectors are the building blocks of 3D graphics math. A Vec3 represents
//! a point or direction in 3D space. All components use Q16.16 fixed-point
//! to avoid floating-point operations on the ESP32.
//!
//! ## Operations
//! - add/sub: component-wise, used for translation
//! - dot: scalar product, used for backface culling and lighting
//! - cross: vector product, used for surface normals
//! - scale: multiply all components by a scalar
//!
//! ## Learning Notes
//! In computer vision, these same vector operations extract features from
//! images. The dot product measures similarity between directions; the
//! cross product finds perpendicular directions (surface normals). Here
//! we use them to project 3D geometry onto a 2D screen.

const Fix16 = @import("fixed_point.zig").Fix16;

/// 3D vector with Q16.16 fixed-point components.
pub const Vec3 = struct {
    x: Fix16,
    y: Fix16,
    z: Fix16,

    /// Create a Vec3 from three fixed-point values.
    pub fn init(x: Fix16, y: Fix16, z: Fix16) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    /// Create a Vec3 from integer values (converted to Q16.16).
    pub fn fromInts(x: i32, y: i32, z: i32) Vec3 {
        return .{
            .x = Fix16.fromInt(x),
            .y = Fix16.fromInt(y),
            .z = Fix16.fromInt(z),
        };
    }

    /// Component-wise addition.
    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.x.add(b.x),
            .y = a.y.add(b.y),
            .z = a.z.add(b.z),
        };
    }

    /// Component-wise subtraction.
    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.x.sub(b.x),
            .y = a.y.sub(b.y),
            .z = a.z.sub(b.z),
        };
    }

    /// Dot product: a·b = ax*bx + ay*by + az*bz
    ///
    /// Returns a scalar. Positive means same direction, negative means
    /// opposite. Used for backface culling: if dot(normal, view) < 0,
    /// the face points away from camera.
    pub fn dot(a: Vec3, b: Vec3) Fix16 {
        return a.x.mul(b.x).add(a.y.mul(b.y)).add(a.z.mul(b.z));
    }

    /// Cross product: a×b = perpendicular vector.
    ///
    /// The resulting vector is perpendicular to both a and b.
    /// Its magnitude equals |a|*|b|*sin(angle). Used to compute
    /// surface normals for backface culling.
    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y.mul(b.z).sub(a.z.mul(b.y)),
            .y = a.z.mul(b.x).sub(a.x.mul(b.z)),
            .z = a.x.mul(b.y).sub(a.y.mul(b.x)),
        };
    }

    /// Multiply all components by a scalar.
    pub fn scale(self: Vec3, s: Fix16) Vec3 {
        return .{
            .x = self.x.mul(s),
            .y = self.y.mul(s),
            .z = self.z.mul(s),
        };
    }

    /// Negate all components.
    pub fn neg(self: Vec3) Vec3 {
        return .{
            .x = self.x.neg(),
            .y = self.y.neg(),
            .z = self.z.neg(),
        };
    }

    /// Zero vector.
    pub const zero = Vec3{
        .x = Fix16.zero,
        .y = Fix16.zero,
        .z = Fix16.zero,
    };
};

/// 2D vector for screen-space operations (projected coordinates).
pub const Vec2 = struct {
    x: Fix16,
    y: Fix16,

    pub fn init(x: Fix16, y: Fix16) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn sub(a: Vec2, b: Vec2) Vec2 {
        return .{
            .x = a.x.sub(b.x),
            .y = a.y.sub(b.y),
        };
    }

    /// 2D cross product (returns scalar): useful for backface culling
    /// in screen space. Positive = CCW winding, Negative = CW winding.
    pub fn cross2d(a: Vec2, b: Vec2) Fix16 {
        return a.x.mul(b.y).sub(a.y.mul(b.x));
    }
};
