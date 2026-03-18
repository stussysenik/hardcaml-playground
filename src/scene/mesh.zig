//! mesh.zig — 3D mesh storage with built-in primitive shapes.
//!
//! A mesh is defined by vertices (3D points) and edges (pairs of vertex
//! indices). For wireframe rendering, we only need vertices and edges —
//! no triangles, no textures, no normals. This keeps memory usage minimal.
//!
//! We also store faces (triplets of vertex indices) for backface culling.
//! A face's winding order determines its front/back: if the screen-space
//! cross product of its edges is positive, we're looking at the front.
//!
//! ## Memory Budget
//! - 64 vertices × 12 bytes = 768 bytes
//! - 128 edges × 4 bytes = 512 bytes
//! - 64 faces × 6 bytes = 384 bytes
//! Total: ~1.6 KB — negligible on ESP32's 520KB SRAM.
//!
//! ## Learning Notes
//! Meshes in production graphics use indexed triangle lists with normals,
//! UVs, and material IDs. Our edge-based representation is simpler — it's
//! what 1970s vector displays used (Asteroids, Star Wars arcade). Perfect
//! for learning the fundamentals.

const config = @import("../config.zig");
const Fix16 = @import("../math/fixed_point.zig").Fix16;
const Vec3 = @import("../math/vec.zig").Vec3;

/// An edge connects two vertices by their indices.
pub const Edge = struct {
    a: u16,
    b: u16,
};

/// A face is a triangle defined by 3 vertex indices.
/// Winding order matters: vertices should be ordered counter-clockwise
/// when viewed from the front face.
pub const Face = struct {
    a: u16,
    b: u16,
    c: u16,

    /// Which edges belong to this face (indices into the edge array).
    /// Used to avoid drawing edges twice when culling is enabled.
    edges: [3]u16,
};

/// Static mesh definition — vertices, edges, and faces.
/// All arrays are fixed-size to avoid heap allocation.
pub const Mesh = struct {
    vertices: [config.MAX_VERTICES]Vec3,
    edges: [config.MAX_EDGES]Edge,
    faces: [config.MAX_FACES]Face,
    vertex_count: u16,
    edge_count: u16,
    face_count: u16,

    /// Human-readable name for debug overlay.
    pub fn name(self: *const Mesh) []const u8 {
        return switch (self.vertex_count) {
            4 => "TETRA",
            8 => "CUBE",
            12 => "ICOSA",
            else => "MESH",
        };
    }

    /// Unit cube centered at origin. Each vertex is at ±0.5 on each axis.
    ///
    /// 8 vertices, 12 edges, 6 faces.
    /// This is the simplest 3D shape with all three axes visible,
    /// making it perfect for testing rotation and projection.
    pub fn cube() Mesh {
        const h = Fix16.fromFloat(0.5);
        const nh = Fix16.fromFloat(-0.5);

        var m: Mesh = undefined;
        m.vertex_count = 8;
        m.edge_count = 12;
        m.face_count = 6;

        // Vertices: 8 corners of a unit cube
        //    3----2
        //   /|   /|       Y
        //  7----6 |       |
        //  | 0--|-1       +--X
        //  |/   |/       /
        //  4----5       Z
        m.vertices[0] = Vec3.init(nh, nh, nh); // left  bottom back
        m.vertices[1] = Vec3.init(h, nh, nh); // right bottom back
        m.vertices[2] = Vec3.init(h, h, nh); // right top    back
        m.vertices[3] = Vec3.init(nh, h, nh); // left  top    back
        m.vertices[4] = Vec3.init(nh, nh, h); // left  bottom front
        m.vertices[5] = Vec3.init(h, nh, h); // right bottom front
        m.vertices[6] = Vec3.init(h, h, h); // right top    front
        m.vertices[7] = Vec3.init(nh, h, h); // left  top    front

        // 12 edges connecting the corners
        m.edges[0] = .{ .a = 0, .b = 1 }; // bottom back
        m.edges[1] = .{ .a = 1, .b = 2 }; // right back
        m.edges[2] = .{ .a = 2, .b = 3 }; // top back
        m.edges[3] = .{ .a = 3, .b = 0 }; // left back
        m.edges[4] = .{ .a = 4, .b = 5 }; // bottom front
        m.edges[5] = .{ .a = 5, .b = 6 }; // right front
        m.edges[6] = .{ .a = 6, .b = 7 }; // top front
        m.edges[7] = .{ .a = 7, .b = 4 }; // left front
        m.edges[8] = .{ .a = 0, .b = 4 }; // bottom left
        m.edges[9] = .{ .a = 1, .b = 5 }; // bottom right
        m.edges[10] = .{ .a = 2, .b = 6 }; // top right
        m.edges[11] = .{ .a = 3, .b = 7 }; // top left

        // 6 faces (CCW winding when viewed from outside)
        m.faces[0] = .{ .a = 0, .b = 3, .c = 2, .edges = .{ 0, 2, 3 } }; // back   (Z-)
        m.faces[1] = .{ .a = 4, .b = 5, .c = 6, .edges = .{ 4, 5, 6 } }; // front  (Z+)
        m.faces[2] = .{ .a = 0, .b = 4, .c = 7, .edges = .{ 3, 7, 8 } }; // left   (X-)
        m.faces[3] = .{ .a = 1, .b = 2, .c = 6, .edges = .{ 1, 5, 9 } }; // right  (X+)
        m.faces[4] = .{ .a = 0, .b = 1, .c = 5, .edges = .{ 0, 4, 8 } }; // bottom (Y-)
        m.faces[5] = .{ .a = 2, .b = 3, .c = 7, .edges = .{ 2, 6, 11 } }; // top    (Y+)

        return m;
    }

    /// Regular tetrahedron centered at origin.
    ///
    /// 4 vertices, 6 edges, 4 faces.
    /// The simplest Platonic solid — every face is an equilateral triangle.
    /// Vertices placed so centroid is at origin, scaled to ±0.5 range.
    pub fn tetrahedron() Mesh {
        // Tetrahedron vertices from two pairs on alternating cube corners.
        // Scaled by 0.5 to match cube sizing.
        const s = Fix16.fromFloat(0.5);
        const ns = Fix16.fromFloat(-0.5);

        var m: Mesh = undefined;
        m.vertex_count = 4;
        m.edge_count = 6;
        m.face_count = 4;

        //   0 = (+,+,+)  1 = (+,-,-)  2 = (-,+,-)  3 = (-,-,+)
        m.vertices[0] = Vec3.init(s, s, s);
        m.vertices[1] = Vec3.init(s, ns, ns);
        m.vertices[2] = Vec3.init(ns, s, ns);
        m.vertices[3] = Vec3.init(ns, ns, s);

        // 6 edges — every pair of vertices connected
        m.edges[0] = .{ .a = 0, .b = 1 };
        m.edges[1] = .{ .a = 0, .b = 2 };
        m.edges[2] = .{ .a = 0, .b = 3 };
        m.edges[3] = .{ .a = 1, .b = 2 };
        m.edges[4] = .{ .a = 1, .b = 3 };
        m.edges[5] = .{ .a = 2, .b = 3 };

        // 4 triangular faces (CCW winding when viewed from outside)
        m.faces[0] = .{ .a = 0, .b = 1, .c = 2, .edges = .{ 0, 1, 3 } };
        m.faces[1] = .{ .a = 0, .b = 3, .c = 1, .edges = .{ 0, 2, 4 } };
        m.faces[2] = .{ .a = 0, .b = 2, .c = 3, .edges = .{ 1, 2, 5 } };
        m.faces[3] = .{ .a = 1, .b = 3, .c = 2, .edges = .{ 3, 4, 5 } };

        return m;
    }

    /// Regular icosahedron centered at origin.
    ///
    /// 12 vertices, 30 edges, 20 faces.
    /// Built from 3 mutually perpendicular golden rectangles. The golden ratio
    /// φ = (1+√5)/2 ≈ 1.618 creates the perfect geometry where all 20 triangles
    /// are equilateral. Scaled by 0.35 to fit the screen.
    pub fn icosahedron() Mesh {
        // Golden ratio φ ≈ 1.618, scaled by 0.35 to fit viewport
        const phi = Fix16.fromFloat(1.618 * 0.35);
        const one = Fix16.fromFloat(1.0 * 0.35);
        const nphi = Fix16.fromFloat(-1.618 * 0.35);
        const none = Fix16.fromFloat(-1.0 * 0.35);
        const zero = Fix16.zero;
        _ = zero;

        var m: Mesh = undefined;
        m.vertex_count = 12;
        m.edge_count = 30;
        m.face_count = 20;

        // 12 vertices from 3 golden rectangles:
        //   Rectangle 1 (YZ plane): (0, ±1, ±φ)
        //   Rectangle 2 (XY plane): (±1, ±φ, 0)
        //   Rectangle 3 (XZ plane): (±φ, 0, ±1)
        const z = Fix16.fromInt(0);
        m.vertices[0] = Vec3.init(z, one, phi); //  (0, +1, +φ)
        m.vertices[1] = Vec3.init(z, none, phi); //  (0, -1, +φ)
        m.vertices[2] = Vec3.init(z, one, nphi); //  (0, +1, -φ)
        m.vertices[3] = Vec3.init(z, none, nphi); //  (0, -1, -φ)
        m.vertices[4] = Vec3.init(one, phi, z); //  (+1, +φ, 0)
        m.vertices[5] = Vec3.init(none, phi, z); //  (-1, +φ, 0)
        m.vertices[6] = Vec3.init(one, nphi, z); //  (+1, -φ, 0)
        m.vertices[7] = Vec3.init(none, nphi, z); //  (-1, -φ, 0)
        m.vertices[8] = Vec3.init(phi, z, one); //  (+φ, 0, +1)
        m.vertices[9] = Vec3.init(nphi, z, one); //  (-φ, 0, +1)
        m.vertices[10] = Vec3.init(phi, z, none); //  (+φ, 0, -1)
        m.vertices[11] = Vec3.init(nphi, z, none); //  (-φ, 0, -1)

        // 30 edges — each vertex connects to 5 neighbors
        m.edges[0] = .{ .a = 0, .b = 1 }; // front top pair
        m.edges[1] = .{ .a = 0, .b = 4 };
        m.edges[2] = .{ .a = 0, .b = 5 };
        m.edges[3] = .{ .a = 0, .b = 8 };
        m.edges[4] = .{ .a = 0, .b = 9 };
        m.edges[5] = .{ .a = 1, .b = 6 };
        m.edges[6] = .{ .a = 1, .b = 7 };
        m.edges[7] = .{ .a = 1, .b = 8 };
        m.edges[8] = .{ .a = 1, .b = 9 };
        m.edges[9] = .{ .a = 2, .b = 3 }; // back top pair
        m.edges[10] = .{ .a = 2, .b = 4 };
        m.edges[11] = .{ .a = 2, .b = 5 };
        m.edges[12] = .{ .a = 2, .b = 10 };
        m.edges[13] = .{ .a = 2, .b = 11 };
        m.edges[14] = .{ .a = 3, .b = 6 };
        m.edges[15] = .{ .a = 3, .b = 7 };
        m.edges[16] = .{ .a = 3, .b = 10 };
        m.edges[17] = .{ .a = 3, .b = 11 };
        m.edges[18] = .{ .a = 4, .b = 5 };
        m.edges[19] = .{ .a = 4, .b = 8 };
        m.edges[20] = .{ .a = 4, .b = 10 };
        m.edges[21] = .{ .a = 5, .b = 9 };
        m.edges[22] = .{ .a = 5, .b = 11 };
        m.edges[23] = .{ .a = 6, .b = 7 };
        m.edges[24] = .{ .a = 6, .b = 8 };
        m.edges[25] = .{ .a = 6, .b = 10 };
        m.edges[26] = .{ .a = 7, .b = 9 };
        m.edges[27] = .{ .a = 7, .b = 11 };
        m.edges[28] = .{ .a = 8, .b = 10 };
        m.edges[29] = .{ .a = 9, .b = 11 };

        // 20 triangular faces (CCW winding when viewed from outside).
        // Each face references its 3 edge indices for backface culling.
        // Face construction: 5 around top (v0), 5 around bottom (v1),
        // 5 upper ring, 5 lower ring.

        // 5 faces around vertex 0 (front-top)
        m.faces[0] = .{ .a = 0, .b = 1, .c = 8, .edges = .{ 0, 3, 7 } };
        m.faces[1] = .{ .a = 0, .b = 8, .c = 4, .edges = .{ 1, 3, 19 } };
        m.faces[2] = .{ .a = 0, .b = 4, .c = 5, .edges = .{ 1, 2, 18 } };
        m.faces[3] = .{ .a = 0, .b = 5, .c = 9, .edges = .{ 2, 4, 21 } };
        m.faces[4] = .{ .a = 0, .b = 9, .c = 1, .edges = .{ 0, 4, 8 } };

        // 5 faces around vertex 3 (back-bottom)
        m.faces[5] = .{ .a = 3, .b = 2, .c = 10, .edges = .{ 9, 12, 16 } };
        m.faces[6] = .{ .a = 3, .b = 10, .c = 6, .edges = .{ 14, 16, 25 } };
        m.faces[7] = .{ .a = 3, .b = 6, .c = 7, .edges = .{ 14, 15, 23 } };
        m.faces[8] = .{ .a = 3, .b = 7, .c = 11, .edges = .{ 15, 17, 27 } };
        m.faces[9] = .{ .a = 3, .b = 11, .c = 2, .edges = .{ 9, 13, 17 } };

        // 10 middle ring faces
        m.faces[10] = .{ .a = 1, .b = 6, .c = 8, .edges = .{ 5, 7, 24 } };
        m.faces[11] = .{ .a = 8, .b = 6, .c = 10, .edges = .{ 24, 25, 28 } };
        m.faces[12] = .{ .a = 8, .b = 10, .c = 4, .edges = .{ 19, 20, 28 } };
        m.faces[13] = .{ .a = 4, .b = 10, .c = 2, .edges = .{ 10, 12, 20 } };
        m.faces[14] = .{ .a = 4, .b = 2, .c = 5, .edges = .{ 10, 11, 18 } };
        m.faces[15] = .{ .a = 5, .b = 2, .c = 11, .edges = .{ 11, 13, 22 } };
        m.faces[16] = .{ .a = 5, .b = 11, .c = 9, .edges = .{ 21, 22, 29 } };
        m.faces[17] = .{ .a = 9, .b = 11, .c = 7, .edges = .{ 26, 27, 29 } };
        m.faces[18] = .{ .a = 9, .b = 7, .c = 1, .edges = .{ 6, 8, 26 } };
        m.faces[19] = .{ .a = 1, .b = 7, .c = 6, .edges = .{ 5, 6, 23 } };

        return m;
    }
};
