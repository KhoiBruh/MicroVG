module microvg;

// --- Color ---

struct Color {
    float r;
    float g;
    float b;
    float a;
}

fn Color rgba(char r, char g, char b, char a) => {
    r / 255.0f,
    g / 255.0f,
    b / 255.0f,
    a / 255.0f
};

// --- Paint style enums ---

enum LineCap : char {
    FLAT,
    SQUARE,
    ROUND
}

enum LineJoin : char {
    MITER,
    BEVEL,
    ROUND
}

// --- Paint ---
// Paint đại diện cho phong cách vẽ (màu sắc, độ dày, v.v.)
// Được tạo qua vg.makePaint(), là value type thuần.

struct Paint {
    Color fillColor;
    Color lineColor;
    float lineWidth;
    LineCap lineCap;
    LineJoin lineJoin;
    bool hasFill;
    bool hasLine;
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
