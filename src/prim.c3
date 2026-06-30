module microvg;

// Triangle-level helpers that append to the vertex buffer. These are the only
// place that turns geometry into vertices; everything above works in points.

// Solid triangle (all vertices at the core, fully opaque).
fn void MicroVG.pushTri(&self, Vec2 a, Vec2 b, Vec2 c, Color color, float alpha) {
    self.pushVert(a, { U_CORE, FILL_MULT }, color, alpha);
    self.pushVert(b, { U_CORE, FILL_MULT }, color, alpha);
    self.pushVert(c, { U_CORE, FILL_MULT }, color, alpha);
}

// Triangle with explicit per-vertex cross-coords (for antialiased fringe bands).
fn void MicroVG.pushVertTri(&self, Vec2 a, float ua, Vec2 b, float ub, Vec2 c, float uc, Color color, float alpha) {
    self.pushVert(a, { ua, FILL_MULT }, color, alpha);
    self.pushVert(b, { ub, FILL_MULT }, color, alpha);
    self.pushVert(c, { uc, FILL_MULT }, color, alpha);
}
