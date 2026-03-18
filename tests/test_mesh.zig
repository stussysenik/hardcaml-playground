//! test_mesh.zig — Verify mesh construction and projection correctness.
//!
//! Tests that the cube mesh has the right number of components and
//! that projection produces sane screen coordinates.

const std = @import("std");
const Mesh = @import("mesh").Mesh;
const Fix16 = @import("fixed_point").Fix16;
const Vec3 = @import("vec").Vec3;
const projection = @import("projection");

test "cube has correct component counts" {
    const cube = Mesh.cube();
    try std.testing.expectEqual(@as(u16, 8), cube.vertex_count);
    try std.testing.expectEqual(@as(u16, 12), cube.edge_count);
    try std.testing.expectEqual(@as(u16, 6), cube.face_count);
}

test "cube vertices are at ±0.5" {
    const cube = Mesh.cube();
    const half = Fix16.fromFloat(0.5).raw;
    const nhalf = Fix16.fromFloat(-0.5).raw;

    for (0..cube.vertex_count) |i| {
        const v = cube.vertices[i];
        // Each component should be either +0.5 or -0.5
        try std.testing.expect(v.x.raw == half or v.x.raw == nhalf);
        try std.testing.expect(v.y.raw == half or v.y.raw == nhalf);
        try std.testing.expect(v.z.raw == half or v.z.raw == nhalf);
    }
}

test "projection of point at z=4 lands on screen" {
    // A point at (0, 0, 4) should project to screen center
    const v = Vec3.init(Fix16.zero, Fix16.zero, Fix16.fromInt(4));
    const focal = projection.DEFAULT_FOCAL;

    if (projection.project(v, focal)) |p| {
        // Should be near center of 80×160 screen (40, 80)
        try std.testing.expect(@abs(@as(i32, p.x) - 40) < 5);
        try std.testing.expect(@abs(@as(i32, p.y) - 80) < 5);
    } else {
        return error.TestUnexpectedResult;
    }
}

test "points behind camera return null" {
    const behind = Vec3.init(Fix16.one, Fix16.one, Fix16.fromFloat(-1.0));
    try std.testing.expect(projection.project(behind, projection.DEFAULT_FOCAL) == null);
}

test "edge indices are valid" {
    const cube = Mesh.cube();
    for (0..cube.edge_count) |i| {
        const edge = cube.edges[i];
        try std.testing.expect(edge.a < cube.vertex_count);
        try std.testing.expect(edge.b < cube.vertex_count);
    }
}

test "face indices are valid" {
    const cube = Mesh.cube();
    for (0..cube.face_count) |i| {
        const face = cube.faces[i];
        try std.testing.expect(face.a < cube.vertex_count);
        try std.testing.expect(face.b < cube.vertex_count);
        try std.testing.expect(face.c < cube.vertex_count);
        for (face.edges) |edge_idx| {
            try std.testing.expect(edge_idx < cube.edge_count);
        }
    }
}

// --- Tetrahedron tests ---

test "tetrahedron has correct component counts" {
    const tetra = Mesh.tetrahedron();
    try std.testing.expectEqual(@as(u16, 4), tetra.vertex_count);
    try std.testing.expectEqual(@as(u16, 6), tetra.edge_count);
    try std.testing.expectEqual(@as(u16, 4), tetra.face_count);
}

test "tetrahedron edge indices are valid" {
    const tetra = Mesh.tetrahedron();
    for (0..tetra.edge_count) |i| {
        const edge = tetra.edges[i];
        try std.testing.expect(edge.a < tetra.vertex_count);
        try std.testing.expect(edge.b < tetra.vertex_count);
    }
}

test "tetrahedron face indices are valid" {
    const tetra = Mesh.tetrahedron();
    for (0..tetra.face_count) |i| {
        const face = tetra.faces[i];
        try std.testing.expect(face.a < tetra.vertex_count);
        try std.testing.expect(face.b < tetra.vertex_count);
        try std.testing.expect(face.c < tetra.vertex_count);
        for (face.edges) |edge_idx| {
            try std.testing.expect(edge_idx < tetra.edge_count);
        }
    }
}

// --- Icosahedron tests ---

test "icosahedron has correct component counts" {
    const icosa = Mesh.icosahedron();
    try std.testing.expectEqual(@as(u16, 12), icosa.vertex_count);
    try std.testing.expectEqual(@as(u16, 30), icosa.edge_count);
    try std.testing.expectEqual(@as(u16, 20), icosa.face_count);
}

test "icosahedron edge indices are valid" {
    const icosa = Mesh.icosahedron();
    for (0..icosa.edge_count) |i| {
        const edge = icosa.edges[i];
        try std.testing.expect(edge.a < icosa.vertex_count);
        try std.testing.expect(edge.b < icosa.vertex_count);
    }
}

test "icosahedron face indices are valid" {
    const icosa = Mesh.icosahedron();
    for (0..icosa.face_count) |i| {
        const face = icosa.faces[i];
        try std.testing.expect(face.a < icosa.vertex_count);
        try std.testing.expect(face.b < icosa.vertex_count);
        try std.testing.expect(face.c < icosa.vertex_count);
        for (face.edges) |edge_idx| {
            try std.testing.expect(edge_idx < icosa.edge_count);
        }
    }
}

test "icosahedron all edges referenced by faces" {
    // Every edge should appear in at least one face
    const icosa = Mesh.icosahedron();
    var edge_referenced: [30]bool = .{false} ** 30;

    for (0..icosa.face_count) |fi| {
        for (icosa.faces[fi].edges) |edge_idx| {
            edge_referenced[edge_idx] = true;
        }
    }

    for (0..icosa.edge_count) |i| {
        try std.testing.expect(edge_referenced[i]);
    }
}
