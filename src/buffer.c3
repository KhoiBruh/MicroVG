module microvg;

struct Buffer <Type> {
	Type* data;
	sz count;
	sz cap;
}

macro void Buffer.reset(&self) {
	self.count = 0;
}

macro void Buffer.init(&self, sz cap) {
	self.reset();
	self.cap = cap;
	self.data = mem::calloc(Type::size * cap);
}

macro void Buffer.reserve(&self, sz cap) {
	if (cap <= self.cap) return;

	sz newCap = self.cap == 0 ? 1 : self.cap * 2;
	while (newCap < cap) newCap *= 2;

	self.data = mem::realloc(self.data, Type::size * newCap);
	self.cap = newCap;
}

macro void Buffer.push(&self, Type data) {
	self.reserve(self.count + 1);
	self.data[self.count++] = data;
}

macro void Buffer.destroy(&self) {
	mem::free(self.data);
	*self = {};
}

struct DrawCall {
	int first;
	int count;
	Paint paint;
}

typedef DrawCallBuffer = inline Buffer{DrawCall};
typedef VertexBuffer = inline Buffer{float};

macro void VertexBuffer.push(&self, Vec2 vertex) {
	self.reserve(self.count + 2);
	self.data[self.count++] = vertex.x;
	self.data[self.count++] = vertex.y;
}
