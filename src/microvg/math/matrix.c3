module microvg::matrix;

import std::math;

import microvg::vector;

faultdef MATRIX_INVERSE_DOESNT_EXIST;

const Mat2x3 IDENTITY_2X3 = {
    .linear = { 1, 0, 0, 1 },
    .translation = { 0, 0 }
};

struct Mat2x3 {
	Vec4f linear;
	Vec2f translation;
}

fn Vec2f Mat2x3.apply(self, Vec2f v) @operator(*) => {
	self.linear.x * v.x + self.linear.z * v.y + self.translation.x,
	self.linear.y * v.x + self.linear.w * v.y + self.translation.y
};

fn Mat2x3 Mat2x3.mul(self, Mat2x3 b) @operator(*) => {
	.linear = {
		self.linear.x * b.linear.x + self.linear.z * b.linear.y,
		self.linear.y * b.linear.x + self.linear.w * b.linear.y,
		self.linear.x * b.linear.z + self.linear.z * b.linear.w,
		self.linear.y * b.linear.z + self.linear.w * b.linear.w
	},
	.translation = self * b.translation
};

fn void Mat2x3.translate(&self, Vec2f v) {
	self.translation += {
		self.linear.x * v.x + self.linear.z * v.y,
		self.linear.y * v.x + self.linear.w * v.y
	};
}

fn void Mat2x3.scale(&self, Vec2f v) {
	self.linear.xy *= v.x;
	self.linear.zw *= v.y;
}

fn void Mat2x3.rotate(&self, float angle) {
	float c = math::cos(angle);
	float s = math::sin(angle);
	float a = self.linear.x;
	float b = self.linear.y;
	float c0 = self.linear.z;
	float d = self.linear.w;

	self.linear.x = a * c + c0 * s;
	self.linear.y = b * c + d * s;
	self.linear.z = c0 * c - a * s;
	self.linear.w = d * c - b * s;
}

fn float Mat2x3.maxScale(self) {
	float sx = math::hypot(self.linear.x, self.linear.y);
	float sy = math::hypot(self.linear.z, self.linear.w);

	return math::max(sx, sy);
}
