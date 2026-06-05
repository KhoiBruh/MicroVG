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

## 11. Add Anti-Aliased Path Edges - In Progress

Difficulty: **Hard**

Completion after task: **93%**

- Current status:
  - Added first-pass coverage support through the existing vertex `u` channel.
  - Added fill fringe geometry around flattened contours.
  - Added stroke fringe geometry around segment sides, joins, and caps.
  - Accounted for `pixelRatio` and current transform scale when sizing the fringe.
  - Kept the shader and blending path premultiplied-alpha compatible.
  - Remaining problem: AA is still patch-based rather than generated from one coherent expanded path mesh. This leaves uneven coverage at rounded corners, flattened Bezier joins, sharp joins, multi-subpath contour joins, and some caps.

### 11.1 Define AA Geometry Model

- Introduce explicit AA geometry concepts instead of ad hoc fringe quads:
  - `EdgeAA`: inner edge, outer edge, coverage values.
  - `StrokePoint`: source point, incoming/outgoing directions, left/right normals, join classification.
  - `StrokeExtrusion`: left/right inner stroke edges and left/right outer fringe edges.
  - `FillExtrusion`: contour point, outward normal/miter, outer fringe point.
- Decide and document coordinate conventions:
  - Positive contour winding and outward normal direction.
  - Left/right stroke side semantics.
  - Coverage convention: solid vertices use coverage `1`, outer fringe vertices use coverage `0`.
  - Fringe width is in device pixels converted back through the current transform scale.
- Add small helper functions for:
  - 2D cross product.
  - safe normalization.
  - line intersection.
  - miter vector and bounded miter scale.
  - arc step count based on radius, angle, and tessellation tolerance.

### 11.2 Replace Fill Fringe With Contour-Wide AA Mesh

- Generate one outer fringe vertex per contour vertex instead of one independent quad per edge.
- Join adjacent edge fringes at vertices using bounded miter extrusion.
- Fall back to bevel-style outer points for extremely sharp or degenerate corners.
- Preserve hole behavior with stencil fill rules:
  - Solid fill remains stencil-based.
  - Fringe draw calls must be emitted per contour with correct outward direction for each contour winding.
  - Inner holes need their fringe to fade into the hole, not outward into the filled area.
- Handle multi-subpath paths independently:
  - Do not connect AA geometry between contours.
  - Keep each contour's fringe closed only within that contour.
- Add visual fixtures for:
  - Rounded rectangle corners.
  - Circle and ellipse outlines.
  - Concave polygon corners.
  - Compound path with holes.
  - Multiple independent subpaths in one path.

### 11.3 Rebuild Stroke AA Around A Unified Stroke Mesh

- Stop emitting stroke AA as separate after-the-fact side bands plus join patches.
- Build all stroke geometry from a single per-point extrusion pass:
  - For each valid segment, compute direction and normal.
  - For each join point, compute left/right inner stroke points.
  - Compute left/right outer fringe points using `halfWidth + fringe`.
  - Store join classification: smooth, bevel, miter, round.
- Emit solid stroke body and AA fringe from the same extrusion data:
  - Solid body: coverage `1` only.
  - Left fringe: inner coverage `1`, outer coverage `0`.
  - Right fringe: inner coverage `1`, outer coverage `0`.
  - Join fringe: generated from the same boundary as the solid join.
  - Cap fringe: generated from the same boundary as the solid cap.
- Preserve current stroke correctness fixes:
  - Sharp `ROUND` and `BEVEL` joins keep rectangular segment bodies plus explicit join fill.
  - Smooth flattened Bezier joins may use shared miter-style body offsets to avoid cracks.
  - Miter joins are bounded by `Paint.miterLimit` and fall back to bevel geometry.
- Generate proper AA for each join type:
  - Smooth joins: continuous mitered side fringe, no extra fan unless needed.
  - Bevel joins: fringe band along the bevel edge and connected side fringes.
  - Miter joins: fringe along both miter edges and miter tip, bounded by the same miter limit.
  - Round joins: solid round fan plus outer annular fringe fan.
- Generate proper AA for each cap type:
  - Butt cap: fringe at the end edge only.
  - Square cap: side fringes and end fringe around the extended rectangle.
  - Round cap: solid semicircle plus outer annular fringe.
- Add fixtures for:
  - Open strokes with butt, square, and round caps.
  - Closed strokes.
  - Sharp polyline joins.
  - Flattened cubic Bezier strokes.
  - Very small segments and duplicate points.
  - Extreme miter-limit fallback.

### 11.4 Improve Curve Flattening For AA Quality

- Tie curve flattening tolerance to both transform scale and stroke width.
- Use tighter tolerance for high-curvature stroked curves so the AA edge does not show faceting.
- Avoid excessive subdivision on nearly straight curves.
- Preserve duplicate-point filtering after flattening.
- Add regression fixtures for:
  - Shallow cubic curves.
  - Tight cubic curves.
  - Rounded rectangles built from cubic arcs.
  - Circles and ellipses at small and large radii.

### 11.5 Rendering And Blending Validation

- Keep premultiplied-alpha output in the shader.
- Verify coverage interpolation is linear and only uses the vertex `u` channel for AA coverage.
- Confirm draw ordering:
  - Fill stencil pass.
  - Fill cover pass.
  - Fill fringe pass.
  - Stroke solid and stroke fringe pass.
- Check that overlapping fringe triangles do not create visible double-dark or double-light seams.
- Consider splitting solid geometry and fringe geometry into separate draw ranges if overdraw becomes visibly incorrect.

### 11.6 Testing And Acceptance Criteria

- Add debug-scene fixtures that isolate AA behavior instead of mixing many unrelated shapes.
- Add a screenshot checklist for desktop and high-DPI pixel ratios.
- Acceptance criteria:
  - Rounded rectangle corners have no cut-ins at arc/edge transitions.
  - Circle and ellipse edges have uniform one-pixel fringe coverage.
  - Bezier stroke edges do not show segment join artifacts.
  - Sharp polyline joins remain filled and have AA on the outer join boundary.
  - Multi-subpath contours do not connect to each other and each contour has its own AA fringe.
  - Holes fade in the correct direction.
  - No obvious overdraw seams at joins, caps, or closed-contour wrap points.

## 12. Clean Up And Refactor Path System Code

Difficulty: **Medium-Hard**

Completion after task: **95%**

The path system is now functional but too messy and inconsistent. Fill tessellation, stroke construction, AA fringe generation, contour handling, and low-level geometry helpers are spread across files with duplicated math and unclear ownership. This task should happen before advanced paint support so gradients/images do not get built on unstable geometry code.

### 12.1 Establish Module Boundaries

- Keep `path.c3` focused on the public path command API only.
- Keep `path_flatten.c3` focused on command flattening and contour construction only.
- Keep `path_tess.c3` focused on fill tessellation only.
- Split stroke generation into clearer sections or files:
  - stroke segment building.
  - stroke join/cap classification.
  - solid stroke emission.
  - AA stroke emission.
- Split fill rendering into clearer sections:
  - contour winding/bounds.
  - stencil fill emission.
  - fill AA emission.
- Move shared geometry helpers into a dedicated file, for example `path_geom.c3`:
  - cross product.
  - area/winding.
  - safe normalize.
  - line intersection.
  - miter calculations.
  - arc stepping.
  - duplicate/degenerate point checks.

### 12.2 Normalize Naming And Data Structures

- Use consistent names for contour counts:
  - raw flattened point count.
  - closed contour point count excluding repeated closing point.
  - segment count.
- Use explicit structs where paired values are currently ambiguous:
  - `StrokeSideOffsets` instead of generic `StrokeOffsets` if it represents left/right stroke side offsets.
  - `JoinGeometry` for resolved join points.
  - `CapGeometry` for resolved cap points.
- Avoid mixing absolute points and offset vectors in similarly named variables.
- Document left/right side conventions once and use them consistently.
- Replace magic constants with named constants:
  - miter fringe limit.
  - round join minimum steps.
  - round cap minimum steps.
  - smooth-join threshold.

### 12.3 Remove Duplication

- Reuse one line-intersection helper across fill/stroke/AA code.
- Reuse one miter helper for fill fringe, stroke body offsets, and stroke fringe.
- Reuse one arc fan/band emitter for round joins and round caps where practical.
- Reuse one quad emitter for solid quads and one band emitter for coverage fringe.
- Centralize degenerate segment filtering so fill, stroke, and AA agree on which points are valid.

### 12.4 Make Render Passes Explicit

- Replace implicit vertex offset bookkeeping with small local emit records:
  - `GeometryRange { offset, count }`.
  - `PathDrawRanges { fill, cover, fringe, stroke }` if useful.
- Make each public render helper return whether it emitted geometry.
- Avoid pushing empty draw calls.
- Keep stencil fill calls and regular color calls clearly separated.
- Make AA fringe draw calls explicit rather than hidden after solid geometry.

### 12.5 Improve Debuggability

- Add debug stats for:
  - flattened points.
  - contours.
  - emitted fill triangles.
  - emitted stroke triangles.
  - emitted AA triangles.
  - skipped degenerate segments.
  - tessellation failures.
- Add optional debug colors or modes for:
  - fill triangles.
  - fill fringe.
  - stroke body.
  - stroke joins.
  - stroke fringe.
- Keep the default debug scene clean, but make focused fixtures easy to toggle.

### 12.6 Add Focused Tests And Fixtures

- Add unit tests where practical for pure geometry helpers:
  - winding direction.
  - miter scale bounds.
  - line intersection.
  - duplicate point cleanup.
  - join classification.
- Add visual fixtures for manual verification:
  - fills only.
  - strokes only.
  - AA only.
  - joins and caps.
  - holes and multi-subpaths.
  - transforms and high-DPI scale.
- Keep fixtures small enough that one artifact is easy to identify.

### 12.7 Acceptance Criteria

- Path rendering files have clear ownership and no large mixed-purpose helper blocks.
- Shared geometry math is not duplicated across fill/stroke/AA paths.
- Stroke join/cap behavior is preserved after refactor.
- Fill rules and hole behavior are preserved after refactor.
- AA behavior from task 11 is preserved or improved after refactor.
- `c3c build MicroVG` passes.
- Debug fixtures still render all path examples.

## 13. Add Advanced Paint Support For Paths

Difficulty: **Hard**

Completion after task: **98%**

- Support solid colors first-class.
- Add linear gradients, radial gradients, and image paints if desired.
- Extend draw calls and shaders to carry paint data.
- Preserve the simple color path for cheap solid draws.

## 14. Add Tests And Visual Fixtures

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
10. Clean up and refactor path system code.
11. Advanced paint support.
12. Tests and visual fixtures.

The biggest correctness jumps are multiple subpaths, real tessellation, and stroke caps/joins. The biggest visual quality jump is anti-aliased edge geometry. The cleanup/refactor step should happen before advanced paint support so gradients, image paints, and future backends are built on coherent path geometry code.
