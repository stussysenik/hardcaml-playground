//! test_zbuffer.zig — Verify z-buffer depth testing behavior.

const std = @import("std");
const ZBuffer = @import("zbuffer").ZBuffer;

test "init sets all depths to max" {
    const zb = ZBuffer.init();
    try std.testing.expectEqual(@as(u16, 0xFFFF), zb.getDepth(0, 0));
    try std.testing.expectEqual(@as(u16, 0xFFFF), zb.getDepth(40, 80));
    try std.testing.expectEqual(@as(u16, 0xFFFF), zb.getDepth(79, 159));
}

test "clear resets all depths" {
    var zb = ZBuffer.init();
    _ = zb.testAndSet(10, 10, 100);
    try std.testing.expectEqual(@as(u16, 100), zb.getDepth(10, 10));

    zb.clear();
    try std.testing.expectEqual(@as(u16, 0xFFFF), zb.getDepth(10, 10));
}

test "nearer depth passes, farther depth fails" {
    var zb = ZBuffer.init();

    // First write should always pass (closer than 0xFFFF)
    try std.testing.expect(zb.testAndSet(20, 30, 500));
    try std.testing.expectEqual(@as(u16, 500), zb.getDepth(20, 30));

    // Nearer (smaller) depth should pass
    try std.testing.expect(zb.testAndSet(20, 30, 200));
    try std.testing.expectEqual(@as(u16, 200), zb.getDepth(20, 30));

    // Farther (larger) depth should fail
    try std.testing.expect(!zb.testAndSet(20, 30, 300));
    try std.testing.expectEqual(@as(u16, 200), zb.getDepth(20, 30)); // unchanged
}

test "equal depth fails (strictly less-than)" {
    var zb = ZBuffer.init();
    _ = zb.testAndSet(5, 5, 1000);
    try std.testing.expect(!zb.testAndSet(5, 5, 1000)); // same depth = fail
}

test "out of bounds returns false and 0xFFFF" {
    var zb = ZBuffer.init();
    try std.testing.expect(!zb.testAndSet(80, 0, 100)); // x out of bounds
    try std.testing.expect(!zb.testAndSet(0, 160, 100)); // y out of bounds
    try std.testing.expectEqual(@as(u16, 0xFFFF), zb.getDepth(80, 0));
}

test "independent pixels don't interfere" {
    var zb = ZBuffer.init();
    _ = zb.testAndSet(10, 10, 100);
    _ = zb.testAndSet(11, 10, 200);
    try std.testing.expectEqual(@as(u16, 100), zb.getDepth(10, 10));
    try std.testing.expectEqual(@as(u16, 200), zb.getDepth(11, 10));
}
