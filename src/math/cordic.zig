//! cordic.zig — CORDIC sin/cos engine (no floating-point trig).
//!
//! CORDIC (COordinate Rotation DIgital Computer) computes trigonometric
//! functions using only shifts, adds, and a small lookup table. Invented
//! in 1959 for real-time navigation on aircraft computers with no FPU.
//!
//! ## How CORDIC Works
//! Start with a unit vector (1, 0). Rotate it toward the target angle
//! using successively smaller rotations: atan(2^0), atan(2^-1), atan(2^-2)...
//! Each rotation is a multiply-by-power-of-2 (just a shift!) plus an add.
//! After N iterations, the vector's x/y components are cos/sin of the angle.
//!
//! ## Binary Radians (BRAD)
//! Instead of radians (0 to 2π) or degrees (0 to 360), we use binary
//! radians: full circle = 65536 (2^16). This makes angle wrapping free —
//! integer overflow handles it automatically. Quarter circle = 16384.
//!
//! ## Precision
//! 10 iterations give error < 0.001 radians ≈ 0.06°. At a display radius
//! of 160 pixels, that's < 0.16 pixels of error — invisible to the eye.
//!
//! ## Learning Notes
//! CORDIC is still used today in FPGA/ASIC designs where you need trig
//! without a hardware multiplier. The same iterative rotation principle
//! appears in the Gram-Schmidt process (linear algebra) and in Givens
//! rotations (used in QR decomposition for computer vision).

const Fix16 = @import("fixed_point.zig").Fix16;
const Mat3 = @import("matrix.zig").Mat3;

/// Number of CORDIC iterations. 10 gives sub-pixel accuracy.
const ITERATIONS: usize = 10;

/// Full circle in binary radians. Wraps via integer overflow.
pub const BRAD_360: i32 = 65536;

/// Quarter circle (90°) in binary radians.
pub const BRAD_90: i32 = 16384;

/// Half circle (180°) in binary radians.
pub const BRAD_180: i32 = 32768;

/// CORDIC angle lookup table: atan(2^-i) in binary radians.
///
/// Each entry is the angle of rotation at iteration i. The values get
/// smaller as i increases, giving finer angular precision.
/// atan(2^-i) in BRAD = atan(2^-i) * 65536 / (2*pi)
const ATAN_TABLE: [ITERATIONS]i32 = .{
    8192,  // atan(1)     = 45.000° → 8192 BRAD
    4836,  // atan(1/2)   = 26.565° → 4836 BRAD
    2555,  // atan(1/4)   = 14.036° → 2555 BRAD
    1297,  // atan(1/8)   =  7.125° → 1297 BRAD
    651,   // atan(1/16)  =  3.576° →  651 BRAD
    326,   // atan(1/32)  =  1.790° →  326 BRAD
    163,   // atan(1/64)  =  0.895° →  163 BRAD
    81,    // atan(1/128) =  0.448° →   81 BRAD
    41,    // atan(1/256) =  0.224° →   41 BRAD
    20,    // atan(1/512) =  0.112° →   20 BRAD
};

/// CORDIC gain factor K ≈ 0.60725 in Q16.16.
///
/// After N iterations, the vector magnitude grows by a known factor.
/// We compensate by multiplying the result by K = product(cos(atan(2^-i))).
/// For 10 iterations, K = 0.607252935... → 39797 in Q16.16.
const CORDIC_K: i32 = 39797;

/// Compute sin and cos of an angle simultaneously using CORDIC.
///
/// Input: angle in binary radians (0 = 0°, 16384 = 90°, 32768 = 180°, 65536 = 360°).
/// Output: { .sin, .cos } as Q16.16 fixed-point values in range [-1, +1].
///
/// ## Algorithm
/// 1. Fold the angle into quadrant 1 [-90°, +90°]
/// 2. Run CORDIC iterations to rotate (K, 0) by the target angle
/// 3. Apply CORDIC gain compensation
/// 4. Restore original quadrant
pub fn sincos(angle_brad: i32) struct { sin: Fix16, cos: Fix16 } {
    // Normalize angle to [0, 65536) range
    var angle = @mod(angle_brad, BRAD_360);

    // Quadrant folding: reduce to [-90°, +90°] for CORDIC convergence
    var flip_sin: bool = false;
    var flip_cos: bool = false;

    if (angle > BRAD_90 and angle <= BRAD_180 + BRAD_90) {
        // Quadrant 2 or 3: cos is negative
        if (angle <= BRAD_180) {
            // Q2: sin positive, cos negative
            angle = BRAD_180 - angle;
            flip_cos = true;
        } else {
            // Q3: sin negative, cos negative
            angle = angle - BRAD_180;
            flip_sin = true;
            flip_cos = true;
        }
    } else if (angle > BRAD_180 + BRAD_90) {
        // Q4: sin negative, cos positive
        angle = BRAD_360 - angle;
        flip_sin = true;
    }

    // Start vector: (K, 0) — the K factor compensates for CORDIC gain.
    // After iterations, (x, y) will be (cos, sin) × K × (1/K) = (cos, sin).
    var x: i32 = CORDIC_K;
    var y: i32 = 0;
    var z: i32 = angle; // Remaining angle to rotate

    // CORDIC iteration loop
    for (0..ITERATIONS) |i| {
        const shift: u5 = @intCast(i);
        if (z >= 0) {
            // Rotate clockwise: angle is positive, so rotate toward 0
            const new_x = x - (y >> shift);
            const new_y = y + (x >> shift);
            x = new_x;
            y = new_y;
            z -= ATAN_TABLE[i];
        } else {
            // Rotate counter-clockwise: angle is negative
            const new_x = x + (y >> shift);
            const new_y = y - (x >> shift);
            x = new_x;
            y = new_y;
            z += ATAN_TABLE[i];
        }
    }

    // Apply quadrant correction
    var sin_val: Fix16 = .{ .raw = y };
    var cos_val: Fix16 = .{ .raw = x };

    if (flip_sin) sin_val = sin_val.neg();
    if (flip_cos) cos_val = cos_val.neg();

    return .{ .sin = sin_val, .cos = cos_val };
}

/// Build rotation matrix around X axis using CORDIC.
pub fn rotateX(angle_brad: i32) Mat3 {
    const sc = sincos(angle_brad);
    return Mat3.rotateX(sc.cos, sc.sin);
}

/// Build rotation matrix around Y axis using CORDIC.
pub fn rotateY(angle_brad: i32) Mat3 {
    const sc = sincos(angle_brad);
    return Mat3.rotateY(sc.cos, sc.sin);
}

/// Build rotation matrix around Z axis using CORDIC.
pub fn rotateZ(angle_brad: i32) Mat3 {
    const sc = sincos(angle_brad);
    return Mat3.rotateZ(sc.cos, sc.sin);
}
