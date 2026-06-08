module microvg;

enum FillMode : char {
	SOLID, GRADIENT, IMAGE
}

struct Fill {
	FillMode mode;
	Vec4f color;
	bool hasFill;
}

fn void Fill.fillMode(&self, FillMode mode) {
	self.mode = mode;
	self.hasFill = true;
}

fn void Fill.fillColor(&self, Vec4f color) {
	self.color = color;
}

fn Vec4f rgba(char r, char g, char b, char a) => {
	r / 255.0f,
	g / 255.0f,
	b / 255.0f,
	a / 255.0f
};
