//! test_prime_field.zig — Verify prime field axioms hold for GF(65521).
//!
//! A proper finite field must satisfy:
//! - Closure: a + b and a * b are in the field
//! - Identity: a + 0 = a, a * 1 = a
//! - Inverse: a * inv(a) = 1 for all a ≠ 0
//! - Associativity and commutativity
//!
//! These property tests verify the implementation is correct.

const std = @import("std");
const pf = @import("prime_field");
const FieldElement = pf.FieldElement;

test "additive identity" {
    const a = FieldElement.init(12345);
    const result = a.add(FieldElement.zero);
    try std.testing.expectEqual(a.val, result.val);
}

test "multiplicative identity" {
    const a = FieldElement.init(12345);
    const result = a.mul(FieldElement.one);
    try std.testing.expectEqual(a.val, result.val);
}

test "multiplicative inverse for small values" {
    // For each a ≠ 0: a * inv(a) == 1
    const test_values = [_]u32{ 1, 2, 3, 7, 13, 127, 251, 1000, 65520 };
    for (test_values) |v| {
        const a = FieldElement.init(v);
        const a_inv = a.inv();
        const product = a.mul(a_inv);
        try std.testing.expectEqual(@as(u16, 1), product.val);
    }
}

test "commutativity of multiplication" {
    const a = FieldElement.init(1234);
    const b = FieldElement.init(5678);
    try std.testing.expectEqual(a.mul(b).val, b.mul(a).val);
}

test "commutativity of addition" {
    const a = FieldElement.init(1234);
    const b = FieldElement.init(5678);
    try std.testing.expectEqual(a.add(b).val, b.add(a).val);
}

test "subtraction: a - a == 0" {
    const a = FieldElement.init(42000);
    try std.testing.expectEqual(@as(u16, 0), a.sub(a).val);
}

test "associativity of multiplication" {
    const a = FieldElement.init(100);
    const b = FieldElement.init(200);
    const cc = FieldElement.init(300);
    // (a*b)*c == a*(b*c)
    try std.testing.expectEqual(
        a.mul(b).mul(cc).val,
        a.mul(b.mul(cc)).val,
    );
}

test "pow computes correct values" {
    const a = FieldElement.init(2);
    // 2^10 = 1024
    const result = a.pow(10);
    try std.testing.expectEqual(@as(u16, 1024), result.val);

    // 2^16 = 65536 mod 65521 = 15
    const result2 = a.pow(16);
    try std.testing.expectEqual(@as(u16, 15), result2.val);
}

test "reduction: values >= P are reduced" {
    const a = FieldElement.init(65521); // == P, should become 0
    try std.testing.expectEqual(@as(u16, 0), a.val);

    const b = FieldElement.init(65522); // P+1, should become 1
    try std.testing.expectEqual(@as(u16, 1), b.val);
}
