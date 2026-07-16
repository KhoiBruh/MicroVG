module microvg;

import std::math;

const float PI = 3.14159265358979323846264338327f;

const float KAPPA90 = 0.5522847493f;

fn float toRad(float deg) => deg / 180.0f * PI;

fn float toDeg(float rad) => rad / PI * 180.0f;

fn float nvgNormalize(float* x, float* y) {
	float d = math::sqrt(x[0] * x[0] + y[0] * y[0]);
	if (d > 1e-6f) {
		float id = 1.0f / d;
		x[0] *= id;
		y[0] *= id;
	}
	return d;
}
