module microvg;

import std::core::mem;
import std::math;

struct FrameBuf {
	char* data;
	int count;
	int cap;
	sz size;
}

fn bool FrameBuf.init(&self, sz size, int cap) {
	self.size = size;
	self.cap = cap;
	self.count = 0;
	self.data = mem::malloc(size * cap);
	return self.data != null;
}

fn void* FrameBuf.at(&self, int i) => self.data + i * self.size;

fn int FrameBuf.alloc(&self, int n) {
	while (self.count + n > self.cap) {
		self.cap = math::max(self.cap * 2, self.count + n + 64);
	}
	char* newData = mem::realloc(self.data, self.size * self.cap);
	if (newData == null) return -1;
	self.data = newData;

	int ret = self.count;
	self.count += n;
	return ret;
}

fn void FrameBuf.reset(&self) => self.count = 0;

fn void FrameBuf.delete(&self) {
	if (self.data != null) mem::free(self.data);
	self.data = null;
	self.count = 0;
	self.cap = 0;
}
