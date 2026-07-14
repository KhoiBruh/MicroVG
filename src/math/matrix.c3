module microvg;

import std::math;

struct Mat2x3 {
	Vec4 linear;
	Vec2 trans;
}

const Mat2x3 IDENTITY_2X3 = {
	{ 1, 0, 0, 1 },
	{ 0, 0 }
};

fn Vec2 Mat2x3.transform(self, Vec2 v) => self * v;

fn Vec2 Mat2x3.apply(self, Vec2 v) @operator(*) => {
    self.linear.x * v.x + self.linear.z * v.y + self.trans.x,
    self.linear.y * v.x + self.linear.w * v.y + self.trans.y
};

fn void Mat2x3.translate(&self, float x, float y) {
	self.trans.x += self.linear.x * x + self.linear.z * y;
	self.trans.y += self.linear.y * x + self.linear.w * y;
}

fn void Mat2x3.scale(&self, float x, float y) {
	self.linear.x *= x;
	self.linear.y *= x;
	self.linear.z *= y;
	self.linear.w *= y;
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

fn float Mat2x3.averageScale(self) {
    float sx = math::sqrt(self.linear.x * self.linear.x + self.linear.z * self.linear.z);
    float sy = math::sqrt(self.linear.y * self.linear.y + self.linear.w * self.linear.w);
    return (sx + sy) * 0.5f;
}

fn Mat2x3 Mat2x3.multiply(self, Mat2x3 other) @operator(*) => {
	{
		self.linear.x * other.linear.x + self.linear.z * other.linear.y,
		self.linear.y * other.linear.x + self.linear.w * other.linear.y,
		self.linear.x * other.linear.z + self.linear.z * other.linear.w,
		self.linear.y * other.linear.z + self.linear.w * other.linear.w
	},
	{
		self.linear.x * other.trans.x + self.linear.z * other.trans.y + self.trans.x,
		self.linear.y * other.trans.x + self.linear.w * other.trans.y + self.trans.y
	}
};

fn Mat2x3 Mat2x3.inverse(self) {
	float det = self.linear.x * self.linear.w - self.linear.z * self.linear.y;
	if (det > -1e-6f && det < 1e-6f) {
		return IDENTITY_2X3;
	}
	float invdet = 1.0f / det;
	return {
		{
			 self.linear.w * invdet,
			-self.linear.y * invdet,
			-self.linear.z * invdet,
			 self.linear.x * invdet
		},
		{
			(self.linear.z * self.trans.y - self.linear.w * self.trans.x) * invdet,
			(self.linear.y * self.trans.x - self.linear.x * self.trans.y) * invdet
		}
	};
}

fn Mat4 Mat2x3.to4x4(&self) {
	Mat4 matrix = IDENTITY_4X4;

	matrix.col0.x = self.linear.x;
	matrix.col0.y = self.linear.y;

	matrix.col1.x = self.linear.z;
	matrix.col1.y = self.linear.w;

	matrix.col3.x = self.trans.x;
	matrix.col3.y = self.trans.y;

	return matrix;
}

struct Mat4 {
	Vec4 col0;
	Vec4 col1;
	Vec4 col2;
	Vec4 col3;
}

const Mat4 IDENTITY_4X4 = {
	{ 1, 0, 0, 0 },
	{ 0, 1, 0, 0 },
	{ 0, 0, 1, 0 },
	{ 0, 0, 0, 1 }
};

fn void Mat4.ortho(&self, float left, float right, float bottom, float top) {
	float inverseRL = 1 / (right - left);
	float inverseTB = 1 / (top - bottom);

	self.col0.x = 2 * inverseRL;
	self.col1.y = 2 * inverseTB;
	self.col2.z = -1;

	self.col3.x = -(right + left) * inverseRL;
	self.col3.y = -(top + bottom) * inverseTB;
	self.col3.w = 1;
}

fn void Mat4.translate(&self, Vec2 vec) {
	self.col3.xy = vec;
}

fn void Mat4.scale(&self, Vec2 vec) {
	self.col0.x = vec.x;
	self.col1.y = vec.y;
	self.col2.z = 1;
}

fn void Mat4.rotate(&self, float rad) {
	float cos = math::cos(rad);
	float sin = math::sin(rad);

	self.col0.x = cos;
	self.col0.y = sin;

	self.col1.x = -sin;
	self.col1.y = cos;
}
