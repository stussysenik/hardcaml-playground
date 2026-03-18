//! test_scene.zig — Verify scene graph operations.
//!
//! Tests object add/remove, active index cycling, and depth sorting.

const std = @import("std");
const Scene = @import("scene").Scene;
const Fix16 = @import("fixed_point").Fix16;
const Vec3 = @import("vec").Vec3;

test "scene initializes with one object" {
    const scene = Scene.init();
    try std.testing.expectEqual(@as(u8, 1), scene.count);
    try std.testing.expectEqual(@as(u8, 0), scene.active_index);
}

test "add objects up to max" {
    var scene = Scene.init();
    // Already has 1, can add 7 more
    var i: u8 = 0;
    while (i < 7) : (i += 1) {
        const pos = Vec3.init(Fix16.fromInt(@as(i16, i)), Fix16.zero, Fix16.zero);
        try std.testing.expect(scene.addObject(0, pos));
    }
    try std.testing.expectEqual(@as(u8, 8), scene.count);

    // 9th should fail
    try std.testing.expect(!scene.addObject(0, Vec3.init(Fix16.zero, Fix16.zero, Fix16.zero)));
}

test "remove last object" {
    var scene = Scene.init();
    const pos = Vec3.init(Fix16.one, Fix16.zero, Fix16.zero);
    _ = scene.addObject(1, pos);
    try std.testing.expectEqual(@as(u8, 2), scene.count);

    try std.testing.expect(scene.removeLastObject());
    try std.testing.expectEqual(@as(u8, 1), scene.count);

    // Can't remove the last one
    try std.testing.expect(!scene.removeLastObject());
}

test "cycle active wraps around" {
    var scene = Scene.init();
    _ = scene.addObject(0, Vec3.init(Fix16.one, Fix16.zero, Fix16.zero));
    _ = scene.addObject(1, Vec3.init(Fix16.zero, Fix16.one, Fix16.zero));
    try std.testing.expectEqual(@as(u8, 3), scene.count);

    try std.testing.expectEqual(@as(u8, 0), scene.active_index);
    scene.cycleActiveForward();
    try std.testing.expectEqual(@as(u8, 1), scene.active_index);
    scene.cycleActiveForward();
    try std.testing.expectEqual(@as(u8, 2), scene.active_index);
    scene.cycleActiveForward();
    try std.testing.expectEqual(@as(u8, 0), scene.active_index); // wrapped
}

test "depth sort orders by z ascending" {
    var scene = Scene.init();
    // Object 0 at z=0 (default)
    // Object 1 at z=2 (further)
    _ = scene.addObject(0, Vec3.init(Fix16.zero, Fix16.zero, Fix16.fromInt(2)));
    // Object 2 at z=-1 (closer)
    _ = scene.addObject(0, Vec3.init(Fix16.zero, Fix16.zero, Fix16.fromInt(-1)));

    var order: [8]u8 = undefined;
    const count = scene.getSortedIndices(&order);
    try std.testing.expectEqual(@as(u8, 3), count);

    // Should be sorted by z: -1 (idx 2), 0 (idx 0), 2 (idx 1)
    try std.testing.expectEqual(@as(u8, 2), order[0]); // z=-1
    try std.testing.expectEqual(@as(u8, 0), order[1]); // z=0
    try std.testing.expectEqual(@as(u8, 1), order[2]); // z=2
}

test "active index clamps on remove" {
    var scene = Scene.init();
    _ = scene.addObject(0, Vec3.init(Fix16.one, Fix16.zero, Fix16.zero));
    scene.active_index = 1; // select second object
    _ = scene.removeLastObject();
    // active_index should wrap to 0
    try std.testing.expectEqual(@as(u8, 0), scene.active_index);
}
