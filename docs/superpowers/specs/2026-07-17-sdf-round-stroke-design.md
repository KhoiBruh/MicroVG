# SDF Round Stroke Design

## Goal

Improve round line caps and joins without stencil masking. The implementation must remain portable to explicit backends such as Vulkan and must preserve MicroVG's public API.

## Current Problem

Round caps and joins are emitted as inscribed five-segment SDF fans inside the same triangle strip as the stroke body. The fan geometry can clip the intended circular coverage. Connector triangles interpolate between body and SDF shader modes, creating discontinuities and seams. Round joins also no longer preserve NanoVG's left/right and inner-bevel topology.

## Geometry

Stroke bodies remain triangle strips. A body strip ends at the incoming cross-section of a round join and resumes at the outgoing cross-section. Round caps and joins are emitted into a separate contiguous triangle range.

A round cap covers only the half-plane outside its endpoint. A round join covers only the outer angular sector between the incoming and outgoing stroke edges. These regions share boundaries with the body but do not overlap its antialiased fringe, avoiding repeated alpha blending.

Round-sector triangles use circumscribed outer vertices. For angular step `delta`, the geometry radius is `outer_radius / cos(delta / 2)`. This guarantees that rasterized geometry contains the desired circular SDF boundary. Angular subdivision is derived from the swept angle and tessellation tolerance rather than a fixed segment count.

Left and right turns are handled separately. Inner-bevel handling follows the existing NanoVG-derived join calculations so short adjacent segments do not produce invalid or self-intersecting geometry.

## Vertex Data and Shader Modes

Every triangle has one coverage mode: body stroke or round primitive. All three vertices of a triangle carry the same mode, so mode selection does not depend on an interpolated threshold.

Round vertices carry the primitive center and antialiasing width required by the radial SDF. The round fragment coverage is computed from distance to the center. Geometry restricts cap and join fragments to their required half-plane or angular sector.

Body coverage continues to use the existing transverse stroke coordinates. Scissor and paint evaluation remain shared by both coverage modes.

## Backend Data Flow

`expandStroke()` produces the existing body range plus a new contiguous round-triangle range. The GL backend uploads both ranges to the existing vertex and stroke-data buffers. It draws the body ranges as triangle strips and the round range as triangles using the same paint state and shader program.

The representation does not depend on OpenGL stencil operations. A Vulkan backend can bind the same buffers and pipeline data and issue equivalent strip and triangle draw ranges.

## Shader Organization

GLSL source moves out of `gl_backend.c3` into:

- `src/backend/shaders/fill.vert.glsl`
- `src/backend/shaders/fill.frag.glsl`

The C3 backend embeds these files at compile time with `$embed`. Backend-selected defines such as `EDGE_AA` remain compiler prefixes. The fragment shader is organized into scissor coverage, body-stroke coverage, round coverage, and paint evaluation functions. No public API changes are introduced.

## Testing and Validation

CPU geometry tests cover:

- Circumscribed sector geometry contains the requested circular arc.
- Start and end caps stay in the correct outer half-plane.
- Left and right joins sweep the correct outer sector.
- Degenerate and short adjacent segments do not create NaN values or invalid counts.
- Vertex counts and allocated ranges agree for open, closed, round-cap, and round-join paths.

Validation includes the targeted C3 tests, a debug build, and a rendered demo comparison covering thin and thick strokes, acute and obtuse joins, both turn directions, and round caps at multiple pixel ratios.

## Scope

This change does not add stencil masking, change public drawing APIs, redesign non-round cap or join behavior, or refactor unrelated backend code.
