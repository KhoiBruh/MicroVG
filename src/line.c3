module microvg;

enum LineMode : char {
	SOLID, GRADIENT
}

enum LineJoin : char {
	SQUARE, ROUND, FLAT
}

enum LineCap : char {
	ROUND, BEVEL, MITER
}

struct Line {
	LineMode mode;
	Vec4f color;
	float width;
	LineCap cap;
	LineJoin join;
	bool hasLine;
}

fn void Line.lineMode(&self, LineMode mode) {
	self.mode = mode;
	self.hasLine = true;
}

fn void Line.lineColor(&self, Vec4f color) {
	self.color = color;
}

fn void Line.lineWidth(&self, float width) {
	self.width = width;
}

fn void Line.lineCap(&self, LineCap cap) {
	self.cap = cap;
}

fn void Line.lineJoin(&self, LineJoin join) {
	self.join = join;
}
