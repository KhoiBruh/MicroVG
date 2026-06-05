module microvg::state;

import std::math;

import microvg::matrix;
import microvg::vector;

struct State {
	Mat2x3 form;
	float alpha;
}

fn State defaultState() => {
	.form = matrix::IDENTITY_2X3,
	.alpha = 1
};

fn Vec2f State.transform(&self, float x, float y) {
	Vec2f vec = { x, y };
	return self.form * vec;
}

fn void State.translate(&self, float x, float y) {
	Vec2f vec = { x, y };
	self.form.translate(vec);
}

fn void State.scale(&self, float x, float y) {
	Vec2f vec = { x, y };
	self.form.scale(vec);
}

fn void State.rotate(&self, float rad) => self.form.rotate(rad);

fn float State.maxScale(&self) => self.form.maxScale();

fn void State.setAlpha(&self, float a) {
	self.alpha = math::clamp(a, 0, 1);
}
