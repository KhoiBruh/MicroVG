module microvg::color;

struct Color {
	float r;
	float g;
	float b;
	float a;
}

fn Color rgba(int r, int g, int b, int a = 255) => {
	.r = r / 255.0f,
	.g = g / 255.0f,
	.b = b / 255.0f,
	.a = a / 255.0f
};

fn Color hex(uint argb) => rgba(
	(int) ((argb >> 16) & 0xFF),
	(int) ((argb >> 8) & 0xFF),
	(int) (argb & 0xFF),
	(int) ((argb >> 24) & 0xFF)
);

fn Color Color.alpha(&self, float a) => {
	self.r, self.g, self.b, a
};


