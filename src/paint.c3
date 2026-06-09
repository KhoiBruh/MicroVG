module microvg;

enum LineJoin : char {
	SQUARE, ROUND, FLAT
}

enum LineCap : char {
	ROUND, BEVEL, MITER
}

struct Paint {
	Vec4f fillColor;
	Vec4f lineColor;

    float lineWidth;
    LineCap lineCap;
    LineJoin lineJoin;

	bool hasFill;
	bool hasLine;
}

fn void Paint.fill(&self, Vec4f color) {
	self.fillColor = color;
	self.hasFill = true;
}

fn void Paint.line(&self, Vec4f color, float width) {
	self.lineColor = color;
	self.lineWidth = width;
	self.hasLine = true;
}

fn void Paint.cap(&self, LineCap cap) {
	self.lineCap = cap;
}

fn void Paint.join(&self, LineJoin join) {
	self.lineJoin = join;
}

fn Vec4f rgba(char r, char g, char b, char a) => {
	r / 255.0f,
	g / 255.0f,
	b / 255.0f,
	a / 255.0f
};
