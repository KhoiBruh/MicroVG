module microvg;

struct Color { float r, g, b, a; }

fn Color Color.alpha(self, float a) => {
	self.r, self.g, self.b, self.a * a
};

fn Color rgba(char r, char g, char b, char a) => {
    r / 255.0f, g / 255.0f, b / 255.0f, a / 255.0f
};

enum LineCap : char { FLAT, SQUARE, ROUND }
enum LineJoin : char { MITER, BEVEL, ROUND }

struct Paint {
    Color fillColor, lineColor;
    float lineWidth;
    LineCap lineCap;
    LineJoin lineJoin;
    bool hasFill, hasLine;
}

fn void Paint.fill(&self, Color color) {
	self.fillColor = color;
	self.hasFill = true;
}

fn void Paint.line(&self, Color color, float width) {
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
