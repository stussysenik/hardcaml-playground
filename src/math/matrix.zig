//! matrix.zig — 3×3 rotation/transformation matrix in Q16.16 fixed-point.
//!
//! A 3×3 matrix transforms 3D vectors: rotating, scaling, or shearing them.
//! For our wireframe renderer, we only need rotation matrices — built from
//! CORDIC sin/cos values — to orient the 3D model based on IMU readings.
//!
//! ## Matrix Layout
//! Stored as 3 row vectors (row-major). Matrix-vector multiplication:
//!   result.x = row0 · vec
//!   result.y = row1 · vec
//!   result.z = row2 · vec
//!
//! ## Learning Notes
//! In computer vision, the same rotation matrices describe how a camera
//! is oriented in 3D space. The "camera matrix" decomposes into intrinsic
//! parameters (focal length, etc.) and extrinsic rotation+translation.
//! We're building the extrinsic rotation part here.

const Fix16 = @import("fixed_point.zig").Fix16;
const Vec3 = @import("vec.zig").Vec3;

/// 3×3 matrix stored as 9 Q16.16 values in row-major order.
///
/// ```
/// | m[0] m[1] m[2] |     | row0.x row0.y row0.z |
/// | m[3] m[4] m[5] |  =  | row1.x row1.y row1.z |
/// | m[6] m[7] m[8] |     | row2.x row2.y row2.z |
/// ```
pub const Mat3 = struct {
    m: [9]Fix16,

    /// Identity matrix: no rotation, no scaling.
    pub const identity = Mat3{
        .m = .{
            Fix16.one,  Fix16.zero, Fix16.zero,
            Fix16.zero, Fix16.one,  Fix16.zero,
            Fix16.zero, Fix16.zero, Fix16.one,
        },
    };

    /// Multiply matrix × vector. Applies the transformation to a point.
    ///
    /// This is the core operation: every vertex gets multiplied by the
    /// rotation matrix once per frame to orient it in world space.
    pub fn mulVec(self: Mat3, v: Vec3) Vec3 {
        return Vec3{
            .x = self.m[0].mul(v.x).add(self.m[1].mul(v.y)).add(self.m[2].mul(v.z)),
            .y = self.m[3].mul(v.x).add(self.m[4].mul(v.y)).add(self.m[5].mul(v.z)),
            .z = self.m[6].mul(v.x).add(self.m[7].mul(v.y)).add(self.m[8].mul(v.z)),
        };
    }

    /// Multiply two matrices. Used to combine rotations:
    /// rotateX(a).mul(rotateY(b)) = combined XY rotation.
    ///
    /// Matrix multiplication is associative but NOT commutative:
    /// A*B ≠ B*A (rotating X then Y ≠ rotating Y then X).
    pub fn mul(a: Mat3, b: Mat3) Mat3 {
        var result: Mat3 = undefined;
        comptime var row: usize = 0;
        inline while (row < 3) : (row += 1) {
            comptime var col: usize = 0;
            inline while (col < 3) : (col += 1) {
                result.m[row * 3 + col] = a.m[row * 3 + 0].mul(b.m[0 * 3 + col])
                    .add(a.m[row * 3 + 1].mul(b.m[1 * 3 + col]))
                    .add(a.m[row * 3 + 2].mul(b.m[2 * 3 + col]));
            }
        }
        return result;
    }

    /// Build a rotation matrix around the X axis (pitch / nod).
    ///
    /// ```
    /// | 1    0     0   |
    /// | 0  cos(a) -sin(a) |
    /// | 0  sin(a)  cos(a) |
    /// ```
    pub fn rotateX(cos: Fix16, sin: Fix16) Mat3 {
        return .{ .m = .{
            Fix16.one,  Fix16.zero, Fix16.zero,
            Fix16.zero, cos,        sin.neg(),
            Fix16.zero, sin,        cos,
        } };
    }

    /// Build a rotation matrix around the Y axis (yaw / turn).
    ///
    /// ```
    /// |  cos(a)  0  sin(a) |
    /// |    0     1    0    |
    /// | -sin(a)  0  cos(a) |
    /// ```
    pub fn rotateY(cos: Fix16, sin: Fix16) Mat3 {
        return .{ .m = .{
            cos,        Fix16.zero, sin,
            Fix16.zero, Fix16.one,  Fix16.zero,
            sin.neg(),  Fix16.zero, cos,
        } };
    }

    /// Build a rotation matrix around the Z axis (roll / tilt).
    ///
    /// ```
    /// | cos(a) -sin(a)  0 |
    /// | sin(a)  cos(a)  0 |
    /// |   0       0     1 |
    /// ```
    pub fn rotateZ(cos: Fix16, sin: Fix16) Mat3 {
        return .{ .m = .{
            cos,        sin.neg(),  Fix16.zero,
            sin,        cos,        Fix16.zero,
            Fix16.zero, Fix16.zero, Fix16.one,
        } };
    }
};
