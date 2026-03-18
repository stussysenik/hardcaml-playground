//! mesh_catalog.zig — Comptime catalog of all available meshes.
//!
//! Centralizes mesh construction so the scene graph can reference meshes
//! by index. All meshes are computed at compile time — zero runtime cost.
//!
//! ## Learning Notes
//! Comptime arrays in Zig are evaluated during compilation and embedded
//! directly into the binary's .rodata section. This means zero heap
//! allocation and instant access — perfect for embedded systems.

const Mesh = @import("mesh.zig").Mesh;

/// Total number of available meshes.
pub const MESH_COUNT: u8 = 3;

/// All meshes, indexed by mesh_index. Computed at comptime.
pub const catalog = [MESH_COUNT]Mesh{
    Mesh.cube(),
    Mesh.tetrahedron(),
    Mesh.icosahedron(),
};

/// Mesh names for debug overlay, matching catalog order.
pub const names = [MESH_COUNT][]const u8{
    "CUBE",
    "TETRA",
    "ICOSA",
};
