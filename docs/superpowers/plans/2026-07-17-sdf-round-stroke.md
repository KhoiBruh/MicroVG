# Portable SDF Round Stroke Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hybrid round-cap/join triangle strip with non-overlapping SDF round triangle ranges and move GLSL into embedded source files.

**Architecture:** Stroke bodies remain triangle strips. Round caps and outer join sectors become contiguous `GL_TRIANGLES` ranges whose circumscribed geometry fully contains the analytic circular boundary; each triangle uses one explicit coverage mode. The backend uploads both ranges into its existing vertex/stroke-data buffers and issues a second, non-stencil draw range.

**Tech Stack:** C3 0.8.x, OpenGL 3 core GLSL, C3 `$embed`, C3 `@test`.

---

## File Structure

- Create `src/backend/shaders/fill.vert.glsl`: vertex transform and interpolants.
- Create `src/backend/shaders/fill.frag.glsl`: scissor, body coverage, round SDF coverage, and paint evaluation.
- Create `test/sdf_stroke_test.c3`: CPU tests for conservative sectors and cap/join classification.
- Modify `src/microvg/path.c3`: store round triangle vertices/data and release their allocations.
- Modify `src/microvg/context.c3`: conservative-sector helpers and separate body/round expansion.
- Modify `src/backend/gl_backend.c3`: embed GLSL, upload round ranges, and draw them as triangles.
- Modify `src/main.c3`: add acute/obtuse, left/right, thin/thick round-stroke examples for visual verification.

### Task 1: Extract and Embed GLSL Without Behavioral Changes

**Files:**
- Create: `src/backend/shaders/fill.vert.glsl`
- Create: `src/backend/shaders/fill.frag.glsl`
- Modify: `src/backend/gl_backend.c3:593-770`

- [ ] **Step 1: Capture the current build as the behavioral baseline**

Run: `c3c build MicroVG`

Expected: PASS. If it fails before edits, record the complete baseline error and stop rather than attributing it to shader extraction.

- [ ] **Step 2: Move the existing shader bodies verbatim into focused files**

`fill.vert.glsl` starts at the current `#ifdef NANOVG_GL3` vertex block and contains its complete `main`. `fill.frag.glsl` starts at the current precision block and contains every existing helper and fragment `main`; do not rename uniforms or change equations in this step.

- [ ] **Step 3: Replace inline shader strings with compile-time embeds**

Use file-scope constants in `gl_backend.c3`:

```c3
char[] FILL_VERT_SHADER = $embed("shaders/fill.vert.glsl");
char[] FILL_FRAG_SHADER = $embed("shaders/fill.frag.glsl");
```

Pass `FILL_VERT_SHADER.ptr` and `FILL_FRAG_SHADER.ptr` to `glnvgCreateShader`; retain `shaderHeader` and the `EDGE_AA` option prefix in C3.

- [ ] **Step 4: Build to verify extraction**

Run: `c3c build MicroVG`

Expected: PASS with both shaders compiling and linking.

- [ ] **Step 5: Commit shader extraction**

```powershell
git add src/backend/gl_backend.c3 src/backend/shaders/fill.vert.glsl src/backend/shaders/fill.frag.glsl
git commit -m "refactor: extract embedded GL shaders"
```

### Task 2: Test Conservative SDF Sector Math

**Files:**
- Create: `test/sdf_stroke_test.c3`
- Modify: `src/microvg/context.c3:699-749`

- [ ] **Step 1: Write failing tests for subdivision and conservative radius**

```c3
module microvg;

import std::math;

fn void test_sdf_sector_radius_contains_arc() @test {
    float delta = PI / 5.0f;
    float outer = 6.0f;
    float geometry = sdfSectorRadius(outer, delta);
    assert(geometry * math::cos(delta * 0.5f) >= outer);
    assert(geometry > outer);
}

fn void test_sdf_sector_divisions_scale_with_sweep() @test {
    assert(sdfSectorDivisions(PI, PI / 4.0f) == 4);
    assert(sdfSectorDivisions(PI * 0.25f, PI / 4.0f) == 1);
    assert(sdfSectorDivisions(0.0f, PI / 4.0f) == 1);
}

fn void test_sdf_cap_vertices_stay_outside_endpoint_plane() @test {
    Vec2 direction = { 1.0f, 0.0f };
    Vec2 endpoint = { 10.0f, 20.0f };
    Vec2 sample = sdfCapPoint(endpoint, direction, 4.0f, 0.0f);
    assert((sample.x - endpoint.x) * direction.x + (sample.y - endpoint.y) * direction.y >= 0.0f);
}
```

- [ ] **Step 2: Run tests and verify RED**

Run: `c3c test`

Expected: FAIL because `sdfSectorRadius`, `sdfSectorDivisions`, and `sdfCapPoint` do not exist.

- [ ] **Step 3: Implement the minimal geometry helpers**

Add near the stroke expansion helpers:

```c3
const float SDF_MAX_SECTOR_ANGLE = PI / 4.0f;

fn int sdfSectorDivisions(float sweep, float max_angle) {
    return math::max(1, (int)math::ceil(math::abs(sweep) / max_angle));
}

fn float sdfSectorRadius(float outer_radius, float delta) {
    return outer_radius / math::max(0.001f, math::cos(math::abs(delta) * 0.5f));
}

fn Vec2 sdfCapPoint(Vec2 endpoint, Vec2 direction, float radius, float angle) {
    Vec2 normal = { direction.y, -direction.x };
    return endpoint + direction * (math::cos(angle) * radius) + normal * (math::sin(angle) * radius);
}
```

Use the project-supported explicit component arithmetic instead of vector operators if `Vec2` does not overload them.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `c3c test`

Expected: all three SDF geometry tests PASS.

- [ ] **Step 5: Commit geometry helpers and tests**

```powershell
git add test/sdf_stroke_test.c3 src/microvg/context.c3
git commit -m "test: define conservative SDF sector geometry"
```

### Task 3: Store and Generate Separate Round Triangle Ranges

**Files:**
- Modify: `src/microvg/path.c3:46-70,90-103`
- Modify: `src/microvg/context.c3:699-1250`
- Modify: `test/sdf_stroke_test.c3`

- [ ] **Step 1: Add failing allocation/count tests**

Add tests that build an open two-point path with round caps and a three-point path with a round join, call the normal public path/stroke setup, and assert:

```c3
assert(vg.cache.paths[0].nroundStroke == 12); // two cap quads, two triangles each
assert(vg.cache.paths[0].roundStroke != null);
assert(vg.cache.paths[0].roundStrokeData != null);
```

For the three-point case assert `nroundStroke > 0`, `nroundStroke % 3 == 0`, and every emitted `Vertex`/stroke-data float is finite.

- [ ] **Step 2: Run tests and verify RED**

Run: `c3c test`

Expected: FAIL because `MvgPath` has no round-stroke range.

- [ ] **Step 3: Add owned round-range fields and cleanup**

Extend `MvgPath`:

```c3
Vertex* roundStroke;
int nroundStroke;
float* roundStrokeData;
```

Free `roundStroke` and `roundStrokeData` in `PathCache.delete()`, and free/reset any previous per-frame values before replacing them in `expandStroke()`.

- [ ] **Step 4: Replace SDF fan insertion with separate cap triangles**

Remove `nvgSdfCapFan` calls from the body strip. Emit each cap as two triangles covering a conservative half-disc rectangle outside the endpoint. Store identical mode and center data on all six vertices:

```c3
// strokedata: center.x, center.y, aa, ROUND_MODE
round_data[0] = endpoint.x;
round_data[1] = endpoint.y;
round_data[2] = aa;
round_data[3] = 1.0f;
```

The start cap uses `-direction` as its outward axis; the end cap uses `direction`. The rectangle begins at the endpoint plane and extends by the outer SDF radius, so it does not overlap the body longitudinally.

- [ ] **Step 5: Emit conservative outer join-sector triangles**

For each round join, use the existing `p1.flags.left` branch to compute the two outer normal angles. Split the sweep with `sdfSectorDivisions`. For each interval, emit one triangle from the corner center to two vertices at `sdfSectorRadius(outer_radius, delta)`. Keep inner-bevel/body connector geometry in the body strip; remove the old before/after SDF connector pairs.

- [ ] **Step 6: Make allocation counts exact**

Perform a count pass before allocation. Caps contribute 6 vertices each. Each join contributes `divisions * 3`. Allocate `roundStroke`, `roundStrokeData`, and the reduced body strip independently, then assert emitted counts equal calculated counts in debug builds.

- [ ] **Step 7: Run tests and verify GREEN**

Run: `c3c test`

Expected: cap counts, triangle divisibility, finite-data, and conservative coverage tests PASS.

- [ ] **Step 8: Commit separate round geometry**

```powershell
git add src/microvg/path.c3 src/microvg/context.c3 test/sdf_stroke_test.c3
git commit -m "feat: generate separate SDF round stroke triangles"
```

### Task 4: Upload, Shade, and Draw Round Ranges

**Files:**
- Modify: `src/backend/gl_backend.c3:72-78,403-530,573-580,1116-1190`
- Modify: `src/backend/shaders/fill.vert.glsl`
- Modify: `src/backend/shaders/fill.frag.glsl`

- [ ] **Step 1: Extend backend range metadata**

Add to `GlPath`:

```c3
int roundStrokeOffset;
int roundStrokeCount;
```

Include `nroundStroke` in `glnvgMaxVertCount`, copy `roundStroke` and `roundStrokeData` after each path body range, and preserve exact vertex/data-buffer offset alignment.

- [ ] **Step 2: Replace interpolated threshold mode with explicit data mode**

Keep `strokedata.xyz` as center/AA data and use `strokedata.w` as `0.0` for body and `1.0` for round. Forward it as a `flat` integer-compatible mode from the vertex shader, or ensure all vertices in every triangle carry the identical value and branch on `fjoin.w > 0.5`.

- [ ] **Step 3: Split fragment coverage into focused functions**

Use these responsibilities in `fill.frag.glsl`:

```glsl
float bodyStrokeCoverage() {
    return min(1.0, (1.0 - abs(ftcoord.x * 2.0 - 1.0)) * strokeMult)
         * min(1.0, ftcoord.y);
}

float roundStrokeCoverage() {
    float innerRadius = fjoin.z * (strokeMult - 0.5);
    float outerRadius = fjoin.z * (strokeMult + 0.5);
    return 1.0 - smoothstep(innerRadius, outerRadius, length(fpos - fjoin.xy));
}
```

Select coverage by explicit mode, then apply the existing threshold, paint, and scissor logic once. Delete the `ftcoord.y > 1.5` convention.

- [ ] **Step 4: Draw round ranges without stencil**

After each path body `GL_TRIANGLE_STRIP` draw in the normal stroke pass, issue:

```c3
if (paths[i].roundStrokeCount > 0) {
    gl::drawArrays(GL_TRIANGLES, paths[i].roundStrokeOffset, paths[i].roundStrokeCount);
}
```

Do not add these triangles to stencil-stroke coverage passes; the default non-stencil path is the required behavior. Preserve existing optional stencil behavior for body strokes without introducing new stencil dependencies.

- [ ] **Step 5: Build and run tests**

Run: `c3c test`

Expected: PASS.

Run: `c3c build MicroVG`

Expected: PASS with GLSL compile/link success at demo startup.

- [ ] **Step 6: Commit backend integration**

```powershell
git add src/backend/gl_backend.c3 src/backend/shaders/fill.vert.glsl src/backend/shaders/fill.frag.glsl
git commit -m "feat: render portable SDF round stroke ranges"
```

### Task 5: Visual Regression Scene and Final Verification

**Files:**
- Modify: `src/main.c3:270-320`

- [ ] **Step 1: Add a compact round-stroke matrix to the demo**

Add open paths covering horizontal/diagonal caps, acute and obtuse joins, left and right turns, and widths `1`, `5`, and `20`, all using `LineCap.ROUND` and `LineJoin.ROUND`. Keep the scene within the existing window and do not remove current examples.

- [ ] **Step 2: Run targeted automated verification**

Run: `c3c test`

Expected: all tests PASS with zero failures.

Run: `c3c build MicroVG`

Expected: PASS.

- [ ] **Step 3: Run the demo and capture the result**

Run: `c3c run MicroVG`

Expected: round caps remain circular at all widths; joins have no clipped chords, spikes, dark overlap seams, or gaps on either turn direction. Capture a screenshot and compare it against the two supplied reference images.

- [ ] **Step 4: Inspect the final diff**

Run: `git diff --check` and `git status --short`.

Expected: no whitespace errors; only the planned source, shader, test, demo, and pre-existing user change are present.

- [ ] **Step 5: Commit the visual regression scene**

```powershell
git add src/main.c3
git commit -m "test: add SDF round stroke demo cases"
```
