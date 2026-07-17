module microvg;

import std::core::mem;
import std::math;

fn void prepareStrokePath(MicroVG* vg) @private {
	MvgPath* path = &vg.cache.paths[0];
	Point* p0 = &vg.cache.points[path.first + path.count - 1];
	Point* p1 = &vg.cache.points[path.first];
	for (int i = 0; i < path.count; i++) {
		p0.dx = p1.x - p0.x;
		p0.dy = p1.y - p0.y;
		p0.len = nvgNormalize(&p0.dx, &p0.dy);
		p0 = p1;
		p1++;
	}
}

fn void initStrokeTest(MicroVG* vg) @private {
	vg.cache = allocPathCache();
	assert(vg.cache != null);
	vg.setPxRatio(1.0f);
}

fn int expectedRoundCapDivisions(float radius, float tolerance) @private {
	float da = math::acos(radius / (radius + tolerance)) * 2.0f;
	return math::max(2, (int)math::ceil(PI / da));
}

fn void testRoundCapsUseAdaptiveTriangleStrip() @test {
	MicroVG vg = {};
	initStrokeTest(&vg);
	defer vg.cache.delete();
	defer if (vg.commands != null) mem::free(vg.commands);
	vg.addPath();
	vg.addPoint({ 0.0f, 0.0f }, PT_CORNER);
	vg.addPoint({ 10.0f, 0.0f }, PT_CORNER);
	prepareStrokePath(&vg);

	int ncap = expectedRoundCapDivisions(5.0f, vg.tessTol);
	assert(vg.expandStroke(5.0f, 0.0f, LineCap.ROUND, LineJoin.MITER, 10.0f) == 1);
	MvgPath* path = &vg.cache.paths[0];
	assert(path.nstroke == (ncap * 2 + 2) * 2);
	assert(path.stroke[1].u == 0.5f && path.stroke[1].v == 1.0f);
	assert(path.stroke[path.nstroke - 2].u == 0.5f && path.stroke[path.nstroke - 2].v == 1.0f);
}

fn void testRoundJoinUsesAdaptiveTriangleStrip() @test {
	MicroVG vg = {};
	initStrokeTest(&vg);
	defer vg.cache.delete();
	defer if (vg.commands != null) mem::free(vg.commands);
	vg.addPath();
	vg.addPoint({ 0.0f, 0.0f }, PT_CORNER);
	vg.addPoint({ 10.0f, 0.0f }, PT_CORNER);
	vg.addPoint({ 10.0f, 10.0f }, PT_CORNER);
	prepareStrokePath(&vg);

	int ncap = expectedRoundCapDivisions(5.0f, vg.tessTol);
	assert(vg.expandStroke(5.0f, 0.0f, LineCap.BUTT, LineJoin.ROUND, 10.0f) == 1);
	MvgPath* path = &vg.cache.paths[0];
	assert(path.nstroke == (2 + ncap * 2 + 2) + 8);
	assert(path.stroke[5].u == 0.5f && path.stroke[5].v == 1.0f);
}
