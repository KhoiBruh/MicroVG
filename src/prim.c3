module microvg;

// Triangle-level helpers that append to the vertex buffer. These are the only
// place that turns geometry into vertices; everything above works in points.

// Solid triangle (all vertices at the core UV, fully opaque core).
fn void MicroVG.pushTri(&self, Vec2 a, Vec2 b, Vec2 c, Color color, float alpha) {
    self.pushVert(a, UV_CORE, color, alpha);
    self.pushVert(b, UV_CORE, color, alpha);
    self.pushVert(c, UV_CORE, color, alpha);
}

// Triangle with explicit per-vertex UVs (used for antialiased fringe bands).
fn void MicroVG.pushVertTri(&self, Vec2 a, Vec2 ua, Vec2 b, Vec2 ub, Vec2 c, Vec2 uc, Color color, float alpha) {
    self.pushVert(a, ua, color, alpha);
    self.pushVert(b, ub, color, alpha);
    self.pushVert(c, uc, color, alpha);
}
