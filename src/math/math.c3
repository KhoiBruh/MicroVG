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

fn void nvgTransformTranslate(Mat2x3* t, float tx, float ty) {
	*t = { { 1, 0, 0, 1 }, { tx, ty } };
}

fn void nvgTransformScale(Mat2x3* t, float sx, float sy) {
	*t = { { sx, 0, 0, sy }, { 0, 0 } };
}

fn void nvgTransformRotate(Mat2x3* t, float a) {
	float cs = math::cos(a);
	float sn = math::sin(a);
	*t = { { cs, sn, -sn, cs }, { 0, 0 } };
}

fn void nvgTransformMultiply(Mat2x3* t, Mat2x3* s) {
	*t = *s * *t;
}

fn void nvgTransformPremultiply(Mat2x3* t, Mat2x3* s) {
	*t = *t * *s;
}

fn int nvgTransformInverse(Mat2x3* inv, Mat2x3* t) {
	*inv = t.inverse();
	float det = t.linear.x * t.linear.w - t.linear.z * t.linear.y;
	if (det > -1e-6f && det < 1e-6f) return 0;
	return 1;
}
