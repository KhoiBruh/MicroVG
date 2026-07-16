module microvg;

import std::math;

alias Color = float[<4>];

fn Color rgb(char r, char g, char b) => rgba(r, g, b, 255);

fn Color rgbf(float r, float g, float b) => rgbaf(r, g, b, 1.0f);

fn Color rgba(char r, char g, char b, char a) => {
	r / 255.0f,
	g / 255.0f,
	b / 255.0f,
	a / 255.0f
};

fn Color rgbaf(float r, float g, float b, float a) => { r, g, b, a };

fn Color Color.alpha(self, char a) {
	self.a = a / 255.0f;
	return self;
}

fn Color Color.alphaf(self, float a) {
	self.a = a;
	return self;
}

fn Color hsl(float h, float s, float l) => hsla(h, s, l, 255);

fn Color hsla(float h, float s, float l, char a) {
	Color col;
	h = h % 1.0f;
	if (h < 0.0f) h += 1.0f;
	s = math::clamp(s, 0.0f, 1.0f);
	l = math::clamp(l, 0.0f, 1.0f);
	float m2 = l <= 0.5f ?(l * (1 + s)) :(l + s - l * s);
	float m1 = 2 * l - m2;
	col.r = math::clamp(hue(h + 1.0f / 3.0f, m1, m2), 0.0f, 1.0f);
	col.g = math::clamp(hue(h, m1, m2), 0.0f, 1.0f);
	col.b = math::clamp(hue(h - 1.0f / 3.0f, m1, m2), 0.0f, 1.0f);
	col.a = a / 255.0f;
	return col;
}

fn float hue(float h, float m1, float m2) {
	if (h < 0) h += 1;
	if (h > 1) h -= 1;

	if (h < 1.0f / 6.0f) {
		return m1 + (m2 - m1) * h * 6.0f;
	}
	else if (h < 3.0f / 6.0f) {
		return m2;
	}
	else if (h < 4.0f / 6.0f) {
		return m1 + (m2 - m1) * (2.0f / 3.0f - h) * 6.0f;
	}

	return m1;
}

struct Paint {
	Mat2x3 form;
	Vec2 extent;
	float radius;
	float feather;
	Color innerColor;
	Color outerColor;
	int image;
}

fn void Paint.color(&self, Color color) {
	mem::clear(self, Paint::size);
	self.form.identity();
	self.radius = 0.0f;
	self.feather = 1.0f;
	self.innerColor = color;
	self.outerColor = color;
}
