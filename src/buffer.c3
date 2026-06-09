module microvg;

const sz VERTEX_INIT_CAP @private = 2048;

struct VertexBuffer {
	float* data;
	sz count;
	sz cap;
}

fn void VertexBuffer.reset(&self) @inline {
	self.count = 0;
}

fn void VertexBuffer.push(&self, Vec2 data) {
	sz len = data.len;
    if (self.count + len > self.cap) {
        sz newCap = self.cap == 0 ? VERTEX_INIT_CAP : self.cap * 2;
        self.data = mem::realloc(self.data, float::size * newCap);
        self.cap = newCap;
    }

    self.data[self.count++] = data.x;
    self.data[self.count++] = data.y;
}

fn void VertexBuffer.destroy(&self) {
    mem::free(self.data);
    *self = {};
}
