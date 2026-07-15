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

fn void Mat2x3.skewX(&self, float a) {
	float ta = math::tan(a);
	self.linear.z += self.linear.x * ta;
	self.linear.w += self.linear.y * ta;
}

fn void Mat2x3.skewY(&self, float a) {
	float ta = math::tan(a);
	self.linear.x += self.linear.z * ta;
	self.linear.y += self.linear.w * ta;
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
