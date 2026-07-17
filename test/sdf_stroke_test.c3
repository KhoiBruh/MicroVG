module microvg;

import std::math;

fn void testSdfSectorDivisionsScalesWithSweep() @test {
	assert(sdfSectorDivisions(0.0f, PI * 0.25f) == 1);
	assert(sdfSectorDivisions(PI * 0.25f, PI * 0.25f) == 1);
	assert(sdfSectorDivisions(PI * 0.5f, PI * 0.25f) == 2);
	assert(sdfSectorDivisions(PI, PI * 0.25f) == 4);
}

fn void testSdfSectorRadiusCircumscribesArc() @test {
	float outer_radius = 10.0f;
	float delta = PI * 0.25f;
	float sector_radius = sdfSectorRadius(outer_radius, delta);

	for (int i = 0; i <= 8; i++) {
		float angle = -delta * 0.5f + delta * (float)i / 8.0f;
		float boundary_radius = sector_radius * math::cos(delta * 0.5f) / math::cos(angle);
		assert(boundary_radius >= outer_radius);
	}

	float large_delta_radius = sdfSectorRadius(outer_radius, PI);
	assert(math::is_finite(large_delta_radius));
	assert(large_delta_radius > 0.0f);
}

fn void testSdfCapPointStaysInOutwardEndpointHalfPlane() @test {
	Vec2 endpoint = { 3.0f, -2.0f };
	Vec2 direction = { 0.6f, 0.8f };

	for (int i = 0; i <= 8; i++) {
		float angle = -PI * 0.5f + PI * (float)i / 8.0f;
		Vec2 point = sdfCapPoint(endpoint, direction, 5.0f, angle);
		float outward_distance = (point.x - endpoint.x) * direction.x + (point.y - endpoint.y) * direction.y;
		assert(outward_distance >= -0.0001f);
	}
}

fn void testSdfCapPointUsesClockwiseNormal() @test {
	Vec2 point = sdfCapPoint({ 0.0f, 0.0f }, { 1.0f, 0.0f }, 5.0f, PI * 0.5f);
	assert(math::abs(point.x) < 0.0001f);
	assert(point.y < 0.0f);
}
