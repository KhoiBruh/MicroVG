# Path System Implementation Tasks

Current completion: **88%**

The current path system can record commands, flatten lines and cubic Beziers, tessellate concave fills, evaluate stencil fill rules, and draw strokes with configurable caps and joins. It is usable for simple demos, but it is not yet a complete NanoVG-like path system.

## 1. Clean API Defaults And Style State - Done

Difficulty: **Easy**

Completion after task: **40%**

- Added explicit fill/stroke intent with `hasFill` and `hasStroke`.
- Added `fill(Color)` and kept `stroke(Color, width)`.
- `drawPath` now checks requested operations before emitting fill or stroke geometry.
- Alpha remains a visibility guard inside the geometry functions.

## 2. Move Path Render Helpers Behind Clear Sections - Done

Difficulty: **Easy**

Completion after task: **43%**

- Kept `drawPath` as the public entry point.
- Moved path rendering into `src/microvg/path_render.c3`.
- Grouped helpers into entry, flatten, fill, and stroke sections.
- Kept `microvg.c3` focused on context, state, and buffer management.

## 3. Split Paint From Path - Done

Difficulty: **Easy-Medium**

Completion after task: **46%**

- `Path` now stores geometry commands only.
- `Paint` stores fill/stroke style and requested-operation flags.
- Added `MicroVG.makePaint()` plus `Paint.fill()` and `Paint.stroke()`.
- `drawPath(path, paint)` now makes the final draw operation explicit.

## 4. Support Multiple Subpaths - Done

Difficulty: **Easy-Medium**

Completion after task: **50%**

- Each `moveTo` starts a new contour.
- Flattening now stores contour ranges beside the point buffer.
- Fill and stroke are emitted independently per contour.
- `close()` now marks only the active contour as closed.

## 5. Add Quadratic Curves Or Convenience Conversion - Done

Difficulty: **Easy-Medium**

Completion after task: **53%**

- Added `Path.quadTo(cx, cy, x, y)`.
- Added `CmdType.QUAD` to the path command buffer.
- Quadratic curves are converted to cubic curves during flattening.
- The conversion reuses the existing cubic Bezier subdivision path.

## 6. Implement Rect, Rounded Rect, Circle, And Ellipse Helpers - Done

Difficulty: **Medium**

Completion after task: **60%**

- Added `Path.rect(x, y, w, h)`.
- Added `Path.roundedRect(x, y, w, h, r)` with radius clamping.
- Added `Path.circle(cx, cy, r)`.
- Added `Path.ellipse(cx, cy, rx, ry)`.
- Shapes build from existing line and cubic Bezier commands.

## 7. Implement `arcTo` Properly - Done

Difficulty: **Medium**

Completion after task: **66%**

- Resolves tangent points from current point, `(x1, y1)`, `(x2, y2)`, and radius.
- Inserts a line to the first tangent point.
- Flattens the arc into line segments.
- Handles degenerate cases: zero radius, collinear points, missing current point.

## 8. Add Winding And Fill Rules - Done

Difficulty: **Medium-Hard**

Completion after task: **72%**

- Added clockwise/counter-clockwise contour winding detection from flattened points.
- Added `FillRule.NON_ZERO` and `FillRule.EVEN_ODD` on `Paint`.
- Preserved contour direction through flattening and transforms.
- Holes now render through stencil-based non-zero/even-odd fill evaluation.

## 9. Replace Triangle Fan Fill With Real Tessellation - Done

Difficulty: **Hard**

Completion after task: **82%**

- Replaced per-contour triangle fans with ear-clipping tessellation.
- Concave flattened contours now triangulate correctly in the fill stencil pass.
- Ear clipping simplifies duplicate and near-collinear flattened points before tessellation.
- Removed the temporary fan fallback; failed tessellation now reports through debug stats.
- Holes compose through the stencil fill rules added in task 8, keeping contour input simple.
- Added a concave fill fixture to the debug scene.

## 10. Improve Stroke Joins And Caps - Done

Difficulty: **Hard**

Completion after task: **88%**

- Added `LineCap.BUTT`, `LineCap.SQUARE`, and `LineCap.ROUND`.
- Added `LineJoin.MITER`, `LineJoin.BEVEL`, and `LineJoin.ROUND`.
- Added `Paint.cap()`, `Paint.join()`, and `Paint.miter()` configuration.
- Default stroke joins are round to avoid faceting flattened curves unless callers request miter or bevel joins.
- Open contours now emit explicit cap geometry when requested.
- Closed contours now connect final and first stroke segments through the same join path.
- Miters are bounded by the configured miter limit and fall back to bevel geometry.
- Round joins and round caps are tessellated with bounded triangle fans.
- Near-collinear flattened curve segments skip extra join geometry to avoid cracks and overdraw spikes.
- Added a stroke-style fixture to the debug scene.

## 11. Add Anti-Aliased Path Edges

Difficulty: **Hard**

Completion after task: **93%**

- Generate fringe geometry around fills and strokes.
- Use coverage in the existing vertex `u` channel.
- Account for `pixelRatio` and current transform scale.
- Keep blending premultiplied-alpha compatible with the current shader.

## 12. Add Advanced Paint Support For Paths

Difficulty: **Hard**

Completion after task: **96%**

- Support solid colors first-class.
- Add linear gradients, radial gradients, and image paints if desired.
- Extend draw calls and shaders to carry paint data.
- Preserve the simple color path for cheap solid draws.

## 13. Add Tests And Visual Fixtures

Difficulty: **Hard**

Completion after task: **100%**

- Add unit tests for flattening, contour splitting, arc tangent math, and winding.
- Add visual fixtures for fills, strokes, joins, caps, holes, and transforms.
- Include regression cases for tiny segments and sharp joins.
- Add simple screenshots or reference images for manual verification.

## Recommended Order

1. API defaults and style state.
2. Split paint from path.
3. Multiple subpaths.
4. Shape helpers.
5. `arcTo`.
6. Winding and fill rules.
7. Real tessellation.
8. Stroke caps and joins.
9. Anti-aliasing.
10. Advanced paint support.
11. Tests and visual fixtures.

The biggest correctness jumps are multiple subpaths, real tessellation, and stroke caps/joins. The biggest visual quality jump is anti-aliased edge geometry.
