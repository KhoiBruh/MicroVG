module microvg::buffer;

struct Buffer <Type> {
	Type* items;
	int count;
	int capacity;
	Allocator alloc;
}

macro void Buffer.init(&self, Allocator alloc, int capacity) {
	self.alloc = alloc;
	self.count = 0;
	self.capacity = capacity;
	self.items = alloc::calloc(alloc, Type::size * capacity);
}

macro void Buffer.resize(&self, int capacity) {
	self.items = alloc::realloc(self.alloc, self.items, Type::size * capacity);
	self.capacity = capacity;
}

macro void Buffer.free(&self) {
	alloc::free(self.alloc, self.items);
	self.items = null;
	self.count = 0;
	self.capacity = 0;
}

fn void Buffer.clear(&self) {
	self.count = 0;
}

fn void Buffer.store(&self, int count) {
	int needed = self.count + count;
	if (needed <= self.capacity) return;

	int capacity = self.capacity;
	if (capacity == 0) capacity = 1;
	while (capacity < needed) capacity *= 2;

	self.resize(capacity);
}

fn void Buffer.push(&self, Type type) {
	self.store(1);
	self.items[self.count] = type;
	self.count++;
}
