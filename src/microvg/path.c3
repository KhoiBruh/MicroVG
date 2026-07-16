module microvg;

enum PathCommand : char {
	MOVE,
	LINE,
	BEZIER,
	CLOSE,
	WINDING
}

enum Winding : char {
	CCW,
	CW
}

enum LineCap : char {
	BUTT,
	ROUND,
	SQUARE
}

enum LineJoin : char {
	ROUND,
	BEVEL,
	MITER
}

bitstruct PathPointFlags : char {
	bool corner : 0..0;
	bool left : 1..1;
	bool bevel : 2..2;
	bool innerBevel : 3..3;
}

const PathPointFlags PT_CORNER = { .corner = true };
const PathPointFlags PT_LEFT = { .left = true };
const PathPointFlags PT_BEVEL = { .bevel = true };
const PathPointFlags PR_INNERBEVEL = { .innerBevel = true };

struct PathCmd {
	PathCommand cmd;
	Vec2 p0, p1, p2;
}

struct MvgPath {
	int first;
	int count;
	char closed;
	int nbevel;
	Vertex* fill;
	int nfill;
	Vertex* stroke;
	int nstroke;
	Winding winding;
	bool convex;
}

struct Point {
	float x, y;
	float dx, dy;
	float len;
	float dmx, dmy;
	PathPointFlags flags;
}

struct PathCache {
	Point* points;
	int npoints;
	int cpoints;
	MvgPath* paths;
	int npaths;
	int cpaths;
	Vertex* verts;
	int nverts;
	int cverts;
	Vec4 bounds;
}

fn void PathCache.delete(&self) {
	if (self == null) return;
	if (self.points != null) mem::free(self.points);
	if (self.paths != null) mem::free(self.paths);
	if (self.verts != null) mem::free(self.verts);
	mem::free(self);
}

fn PathCache* allocPathCache() {
	PathCache* c = mem::calloc(PathCache::size);
	if (c == null) return null;

	c.points = mem::malloc(Point::size * INIT_POINTS_SIZE);
	if (c.points == null) {
		c.delete();
		return null;
	}
	c.npoints = 0;
	c.cpoints = INIT_POINTS_SIZE;

	c.paths = mem::malloc(MvgPath::size * INIT_PATHS_SIZE);
	if (c.paths == null) {
		c.delete();
		return null;
	}
	c.npaths = 0;
	c.cpaths = INIT_PATHS_SIZE;

	c.verts = mem::malloc(Vertex::size * INIT_VERTS_SIZE);
	if (c.verts == null) {
		c.delete();
		return null;
	}
	c.nverts = 0;
	c.cverts = INIT_VERTS_SIZE;

	return c;
}
