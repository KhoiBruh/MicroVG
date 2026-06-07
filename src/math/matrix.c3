module microvg;

import std::math;

struct Mat2x3 {
	Vec4f linear;
	Vec2f trans;
}

const Mat2x3 IDENTITY_2X3 = {
	{ 1, 0, 0, 1 },
	{ 0, 0 }
};

fn void Mat2x3.translate(&self, Vec2f vec) {
	self.trans.x += self.linear.x * vec.x + self.linear.z * vec.y;
	self.trans.y += self.linear.y * vec.x + self.linear.w * vec.y;
}

fn void Mat2x3.scale(&self, Vec2f vec) {
	self.linear.x *= vec.x;
	self.linear.y *= vec.x;
	self.linear.z *= vec.y;
	self.linear.w *= vec.y;
}

fn void Mat2x3.rotate(&self, float rad) {
	float c = math::cos(rad);
	float s = math::sin(rad);

	float lx = self.linear.x;
    float ly = self.linear.y;
    float lz = self.linear.z;
    float lw = self.linear.w;

    self.linear.x = lx * c + lz * s;
    self.linear.y = ly * c + lw * s;
    self.linear.z = lx * -s + lz * c;
    self.linear.w = ly * -s + lw * c;
}

fn Mat4f Mat2x3.to4x4(&self) {
	Mat4f matrix = IDENTITY_4X4;

	matrix.col0.x = self.linear.x;
	matrix.col0.y = self.linear.y;

	matrix.col1.x = self.linear.z;
	matrix.col1.y = self.linear.w;

	matrix.col3.x = self.trans.x;
	matrix.col3.y = self.trans.y;

	return matrix;
}

struct Mat4f {
	Vec4f col0;
	Vec4f col1;
	Vec4f col2;
	Vec4f col3;
}

const Mat4f IDENTITY_4X4 = {
	{ 1, 0, 0, 0 },
	{ 0, 1, 0, 0 },
	{ 0, 0, 1, 0 },
	{ 0, 0, 0, 1 }
};

fn void Mat4f.ortho(&self, float left, float right, float bottom, float top) {
	float inverseRL = 1 / (right - left);
	float inverseTB = 1 / (top - bottom);

	self.col0.x = 2 * inverseRL;
	self.col1.y = 2 * inverseTB;
	self.col2.z = -1;

	self.col3.x = -(right + left) * inverseRL;
	self.col3.y = -(top + bottom) * inverseTB;
	self.col3.w = 1;
}

fn void Mat4f.translate(&self, Vec2f vec) {
	self.col3.xy = vec;
}

fn void Mat4f.scale(&self, Vec2f vec) {
	self.col0.x = vec.x;
	self.col1.y = vec.y;
	self.col2.z = 1;
}

fn void Mat4f.rotate(&self, float rad) {
	float cos = math::cos(rad);
	float sin = math::sin(rad);

	self.col0.x = cos;
	self.col0.y = sin;

	self.col1.x = -sin;
	self.col1.y = cos;
}
