module microvg::glbackend;

import microvg;
import opengl::gl;
import std::core::mem;
import std::math;
import std::io;

const int ANTIALIAS = 1 << 0;
const int STENCIL_STROKES = 1 << 1;
const int DEBUG = 1 << 2;
const int IMAGE_NODELETE = 1 << 16;

const int GLNVG_FRAG_BINDING = 0;

enum GlLoc : char {
	VIEWSIZE,
	TEX,
	FRAG,
	MAX_LOCS
}

enum NsvgShader : char {
	FILLGRAD,
	FILLIMG,
	SIMPLE,
	IMG
}

enum GlCallType : char {
	NONE,
	FILL,
	CONVEXFILL,
	EARFILL,
	STROKE,
	TRIANGLES
}

struct GlShader {
	uint prog;
	uint frag;
	uint vert;
	int[3] loc;
}

struct GlTexture {
	int id;
	uint tex;
	int width, height;
	TextureType type;
	int flags;
}

struct GlBlend {
	GLenum srcRGB;
	GLenum dstRGB;
	GLenum srcAlpha;
	GLenum dstAlpha;
}

struct GlCall {
	GlCallType type;
	int image;
	int pathOffset;
	int pathCount;
	int triangleOffset;
	int triangleCount;
	int uniformOffset;
	GlBlend blendFunc;
}

struct GlPath {
	int fillOffset;
	int fillCount;
	int strokeOffset;
	int strokeCount;
}

struct GlFragUniforms {
	float[12] scissorMat;
	float[12] paintMat;
	Color innerCol;
	Color outerCol;
	microvg::Vec2 scissorExt;
	microvg::Vec2 scissorScale;
	microvg::Vec2 extent;
	float radius;
	float feather;
	float strokeMult;
	float strokeThr;
	int texType;
	NsvgShader type;
}

struct GlContext {
	GlShader shader;
	GlTexture* textures;
	microvg::Vec2 view;
	int ntextures;
	int ctextures;
	int textureId;
	uint vertBuf;
	uint vertArr;
	uint fragBuf;
	int fragSize;
	int flags;

	FrameBuf callsBuf;
	FrameBuf pathsBuf;
	FrameBuf vertsBuf;
	FrameBuf uniformBuf;

	GLuint boundTexture;
	GLuint stencilMask;
	GLenum stencilFunc;
	GLint stencilFuncRef;
	GLuint stencilFuncMask;
	GlBlend blendFunc;

	int dummyTex;
}

fn void GlContext.bindTexture(&self, GLuint tex) {
	if (self.boundTexture != tex) {
		self.boundTexture = tex;
		gl::bindTexture(gl::GL_TEXTURE_2D, tex);
	}
}

fn void GlContext.setStencilMask(&self, GLuint mask) {
	if (self.stencilMask != mask) {
		self.stencilMask = mask;
		gl::stencilMask(mask);
	}
}

fn void GlContext.setStencilFunc(&self, GLenum func, GLint ref_val, GLuint mask) {
	if ((self.stencilFunc != func) || (self.stencilFuncRef != ref_val) || (self.stencilFuncMask != mask)) {
		self.stencilFunc = func;
		self.stencilFuncRef = ref_val;
		self.stencilFuncMask = mask;
		gl::stencilFunc((GLenum)func, ref_val, mask);
	}
}

fn void GlContext.blendFuncSeparate(&self, GlBlend* blend) {
	if (
	(self.blendFunc.srcRGB != blend.srcRGB) ||
	(self.blendFunc.dstRGB != blend.dstRGB) ||
	(self.blendFunc.srcAlpha != blend.srcAlpha) ||
	(self.blendFunc.dstAlpha != blend.dstAlpha)
	) {
		self.blendFunc = *blend;
		gl::blendFuncSeparate(blend.srcRGB, blend.dstRGB, blend.srcAlpha, blend.dstAlpha);
	}
}

fn GlTexture* GlContext.allocTexture(&self) {
	GlTexture* tex = null;
	for (int i = 0; i < self.ntextures; i++) {
		if (self.textures[i].id == 0) {
			tex = &self.textures[i];
			break;
		}
	}
	if (tex == null) {
		if (self.ntextures + 1 > self.ctextures) {
			int ctextures = math::max(math::max(self.ntextures + 1, 4), self.ctextures + self.ctextures / 2);
			GlTexture* textures = mem::realloc(self.textures, (GlTexture::size * ctextures));
			if (textures == null) return null;
			self.textures = textures;
			self.ctextures = ctextures;
		}
		tex = &self.textures[self.ntextures++];
	}
	mem::clear(tex, GlTexture::size);
	tex.id = ++self.textureId;
	return tex;
}

fn GlTexture* GlContext.findTexture(&self, int id) {
	for (int i = 0; i < self.ntextures; i++) {
		if (self.textures[i].id == id) {
			return &self.textures[i];
		}
	}
	return null;
}

fn int GlContext.deleteTexture(&self, int id) {
	for (int i = 0; i < self.ntextures; i++) {
		if (self.textures[i].id == id) {
			if (self.textures[i].tex != 0 && (self.textures[i].flags & IMAGE_NODELETE) == 0) {
				gl::deleteTextures(1, &self.textures[i].tex);
			}
			mem::clear(&self.textures[i], GlTexture::size);
			return 1;
		}
	}
	return 0;
}

fn void glnvgDumpShaderError(uint shader, char* name, char* type) @local {
	char[513] str = {};
	int len = 0;
	gl::getShaderInfoLog(shader, 512, &len, &str[0]);
	if (len > 512) len = 512;
	str[len] = 0;
	io::eprintfn("Shader %s/%s error:\n%s", ((ZString)name).str_view(), ((ZString)type).str_view(), ((ZString)&str[0]).str_view());
}

fn void glnvgDumpProgramError(uint prog, char* name) @local {
	char[513] str = {};
	int len = 0;
	gl::getProgramInfoLog(prog, 512, &len, &str[0]);
	if (len > 512) len = 512;
	str[len] = 0;
	io::eprintfn("Program %s error:\n%s", ((ZString)name).str_view(), ((ZString)&str[0]).str_view());
}

fn void GlContext.checkError(&self, char* str) {
	if ((self.flags & DEBUG) == 0) return;
	GLenum err = gl::getError();
	if (err != gl::GL_NO_ERROR) io::eprintfn("Error %08x after %s", err, ((ZString)str).str_view());
}

fn int GlContext.allocCall(&self) => self.callsBuf.alloc(1);

fn int GlContext.allocPaths(&self, int n) => self.pathsBuf.alloc(n);

fn int GlContext.allocVerts(&self, int n) => self.vertsBuf.alloc(n);

fn int GlContext.allocFragUniforms(&self, int n) => self.uniformBuf.alloc(n * self.fragSize);

fn int glnvgCreateShader(GlShader* shader, char* name, char* header, char* opts, char* vshader, char* fshader) @local {
	int status;
	uint prog, vert, frag;
	char*[3] str;
	str[0] = header;
	str[1] = opts != null ? opts : "";
	mem::clear(shader, GlShader::size);

	prog = gl::createProgram();
	vert = gl::createShader(gl::GL_VERTEX_SHADER);
	frag = gl::createShader(gl::GL_FRAGMENT_SHADER);
	str[2] = vshader;
	gl::shaderSource(vert, 3, &str[0], null);
	str[2] = fshader;
	gl::shaderSource(frag, 3, &str[0], null);

	gl::compileShader(vert);
	gl::getShaderiv(vert, gl::GL_COMPILE_STATUS, &status);
	if (status != gl::GL_TRUE) {
		glnvgDumpShaderError(vert, name, "vert");
		return 0;
	}

	gl::compileShader(frag);
	gl::getShaderiv(frag, gl::GL_COMPILE_STATUS, &status);
	if (status != gl::GL_TRUE) {
		glnvgDumpShaderError(frag, name, "frag");
		return 0;
	}

	gl::attachShader(prog, vert);
	gl::attachShader(prog, frag);

	gl::bindAttribLocation(prog, 0, "vertex");
	gl::bindAttribLocation(prog, 1, "tcoord");

	gl::linkProgram(prog);
	gl::getProgramiv(prog, gl::GL_LINK_STATUS, &status);
	if (status != gl::GL_TRUE) {
		glnvgDumpProgramError(prog, name);
		return 0;
	}

	shader.prog = prog;
	shader.vert = vert;
	shader.frag = frag;

	return 1;
}

fn void glnvgDeleteShader(GlShader* shader) @local {
	if (shader.prog != 0) gl::deleteProgram(shader.prog);
	if (shader.vert != 0) gl::deleteShader(shader.vert);
	if (shader.frag != 0) gl::deleteShader(shader.frag);
}

fn void glnvgGetUniforms(GlShader* shader) @local {
	shader.loc[GlLoc.VIEWSIZE] = gl::getUniformLocation(shader.prog, "viewSize");
	shader.loc[GlLoc.TEX] = gl::getUniformLocation(shader.prog, "tex");
	shader.loc[GlLoc.FRAG] = (int) gl::getUniformBlockIndex(shader.prog, "frag");
}

fn void glnvgXformToMat3x4(float* m3, Mat2x3* t) @local {
	m3[0] = t.linear.x;
	m3[1] = t.linear.y;
	m3[2] = 0.0f;
	m3[3] = 0.0f;
	m3[4] = t.linear.z;
	m3[5] = t.linear.w;
	m3[6] = 0.0f;
	m3[7] = 0.0f;
	m3[8] = t.trans.x;
	m3[9] = t.trans.y;
	m3[10] = 1.0f;
	m3[11] = 0.0f;
}

fn int GlContext.convertPaint(&self, GlFragUniforms* frag, Paint* paint, Scissor* scissor, float width, float fringe, float strokeThr) {
	GlTexture* tex = null;
	Mat2x3 invxform;

	mem::clear(frag, GlFragUniforms::size);

	frag.innerCol = paint.innerColor.premul();
	frag.outerCol = paint.outerColor.premul();

	if (scissor.extent.x < -0.5f || scissor.extent.y < -0.5f) {
		mem::clear(&frag.scissorMat[0], 12 * float::size);
		frag.scissorExt.x = 1.0f;
		frag.scissorExt.y = 1.0f;
		frag.scissorScale.x = 1.0f;
		frag.scissorScale.y = 1.0f;
	}
	else {
		invxform = scissor.form.inverse();
		glnvgXformToMat3x4(&frag.scissorMat[0], &invxform);
		frag.scissorExt.x = scissor.extent.x;
		frag.scissorExt.y = scissor.extent.y;
		frag.scissorScale.x = math::sqrt(scissor.form.linear.x * scissor.form.linear.x + scissor.form.linear.z * scissor.form.linear.z) / fringe;
		frag.scissorScale.y = math::sqrt(scissor.form.linear.y * scissor.form.linear.y + scissor.form.linear.w * scissor.form.linear.w) / fringe;
	}

	frag.extent = paint.extent;
	frag.strokeMult = (width * 0.5f + fringe * 0.5f) / fringe;
	frag.strokeThr = strokeThr;

	if (paint.image != 0) {
		tex = self.findTexture(paint.image);
		if (tex == null) return 0;
		if ((tex.flags & microvg::IMAGE_FLIPY) != 0) {
			Mat2x3 m1;
			Mat2x3 m2;

			m1.identity();
			m1.translate(0.0f, frag.extent.y * 0.5f);
			paint.form = m1 * paint.form;

			m2.identity();
			m2.scale(1.0f, -1.0f);
			m2 = m1 * m2;

			m1.identity();
			m1.translate(0.0f, -frag.extent.y * 0.5f);
			m1 = m2 * m1;

			invxform = m1.inverse();
		}
		else {
			invxform = paint.form.inverse();
		}
		frag.type = (NsvgShader.FILLIMG);
		if (tex.type == TextureType.RGBA) {
			frag.texType = (tex.flags & microvg::IMAGE_PREMULTIPLIED) ? 0 : 1;
		}
		else {
			frag.texType = 2;
		}
	}
	else {
		frag.type = NsvgShader.FILLGRAD;
		frag.texType = (int)paint.gradientType;
		frag.radius = paint.radius;
		frag.feather = paint.feather;
		invxform = paint.form.inverse();
	}

	glnvgXformToMat3x4(&frag.paintMat[0], &invxform);

	return 1;
}

fn GlFragUniforms* GlContext.fragUniformPtr(&self, int i) {
	return (GlFragUniforms*)(self.uniformBuf.data + i);
}

fn void GlContext.setUniforms(&self, int uniformOffset, int image) {
	GlTexture* tex = null;
	gl::bindBufferRange(gl::GL_UNIFORM_BUFFER, GLNVG_FRAG_BINDING, self.fragBuf, uniformOffset, GlFragUniforms::size);

	if (image != 0) tex = self.findTexture(image);
	if (tex == null) tex = self.findTexture(self.dummyTex);
	self.bindTexture(tex != null ? tex.tex : 0);
	self.checkError("tex paint tex");
}

fn void GlContext.fill(&self, GlCall* call) {
	GlPath* paths = self.pathsBuf.at(call.pathOffset);
	int npaths = call.pathCount;

	gl::enable(gl::GL_STENCIL_TEST);
	self.setStencilMask(0xff);
	self.setStencilFunc(gl::GL_ALWAYS, 0, 0xff);
	gl::colorMask(gl::GL_FALSE, gl::GL_FALSE, gl::GL_FALSE, gl::GL_FALSE);

	self.setUniforms(call.uniformOffset, 0);
	self.checkError("fill simple");

	gl::stencilOpSeparate(gl::GL_FRONT, gl::GL_KEEP, gl::GL_KEEP, gl::GL_INCR_WRAP);
	gl::stencilOpSeparate(gl::GL_BACK, gl::GL_KEEP, gl::GL_KEEP, gl::GL_DECR_WRAP);
	gl::disable(gl::GL_CULL_FACE);
	for (int i = 0; i < npaths; i++) {
		gl::drawArrays(gl::GL_TRIANGLE_FAN, paths[i].fillOffset, paths[i].fillCount);
	}
	gl::enable(gl::GL_CULL_FACE);

	gl::colorMask(gl::GL_TRUE, gl::GL_TRUE, gl::GL_TRUE, gl::GL_TRUE);

	self.setUniforms(call.uniformOffset + self.fragSize, call.image);
	self.checkError("fill fill");

	if (self.flags & ANTIALIAS) {
		self.setStencilFunc(gl::GL_EQUAL, 0x00, 0xff);
		gl::stencilOp(gl::GL_KEEP, gl::GL_KEEP, gl::GL_KEEP);
		for (int i = 0; i < npaths; i++) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}
	}

	self.setStencilFunc(gl::GL_NOTEQUAL, 0x0, 0xff);
	gl::stencilOp(gl::GL_ZERO, gl::GL_ZERO, gl::GL_ZERO);
	gl::drawArrays(gl::GL_TRIANGLE_STRIP, call.triangleOffset, call.triangleCount);

	gl::disable(gl::GL_STENCIL_TEST);
}

fn void GlContext.convexFill(&self, GlCall* call) {
	GlPath* paths = self.pathsBuf.at(call.pathOffset);
	int npaths = call.pathCount;

	self.setUniforms(call.uniformOffset, call.image);
	self.checkError("convex fill");

	for (int i = 0; i < npaths; i++) {
		gl::drawArrays(gl::GL_TRIANGLE_FAN, paths[i].fillOffset, paths[i].fillCount);
		if (paths[i].strokeCount > 0) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}
	}
}

fn void GlContext.earFill(&self, GlCall* call) {
	GlPath* paths = self.pathsBuf.at(call.pathOffset);
	int npaths = call.pathCount;

	self.setUniforms(call.uniformOffset, call.image);
	self.checkError("ear fill");

	gl::drawArrays(gl::GL_TRIANGLES, call.triangleOffset, call.triangleCount);

	if (self.flags & ANTIALIAS) {
		for (int i = 0; i < npaths; i++) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}
	}
}

fn void GlContext.stroke(&self, GlCall* call) {
	GlPath* paths = self.pathsBuf.at(call.pathOffset);
	int npaths = call.pathCount;

	if (self.flags & STENCIL_STROKES) {
		gl::enable(gl::GL_STENCIL_TEST);
		self.setStencilMask(0xff);

		self.setStencilFunc(gl::GL_EQUAL, 0x0, 0xff);
		gl::stencilOp(gl::GL_KEEP, gl::GL_KEEP, gl::GL_INCR);
		self.setUniforms(call.uniformOffset + self.fragSize, call.image);
		self.checkError("stroke fill 0");
		for (int i = 0; i < npaths; i++) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}

		self.setUniforms(call.uniformOffset, call.image);
		self.setStencilFunc(gl::GL_EQUAL, 0x00, 0xff);
		gl::stencilOp(gl::GL_KEEP, gl::GL_KEEP, gl::GL_KEEP);
		for (int i = 0; i < npaths; i++) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}

		gl::colorMask(gl::GL_FALSE, gl::GL_FALSE, gl::GL_FALSE, gl::GL_FALSE);
		self.setStencilFunc(gl::GL_ALWAYS, 0x0, 0xff);
		gl::stencilOp(gl::GL_ZERO, gl::GL_ZERO, gl::GL_ZERO);
		self.checkError("stroke fill 1");
		for (int i = 0; i < npaths; i++) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}
		gl::colorMask(gl::GL_TRUE, gl::GL_TRUE, gl::GL_TRUE, gl::GL_TRUE);

		gl::disable(gl::GL_STENCIL_TEST);
	}
	else {
		self.setUniforms(call.uniformOffset, call.image);
		self.checkError("stroke fill");
		for (int i = 0; i < npaths; i++) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}
	}
}

fn void GlContext.triangles(&self, GlCall* call) {
	self.setUniforms(call.uniformOffset, call.image);
	self.checkError("triangles fill");
	gl::drawArrays(gl::GL_TRIANGLES, call.triangleOffset, call.triangleCount);
}

fn void glnvgRenderCancel(void* up) @local {
	GlContext* gl = (GlContext*)up;
	gl.callsBuf.reset();
	gl.pathsBuf.reset();
	gl.vertsBuf.reset();
	gl.uniformBuf.reset();
}

fn GLenum glConvertBlendFuncFactor(BlendFactor factor) @local {
	switch (factor) {
		case BlendFactor.ZERO: return gl::GL_ZERO;
		case BlendFactor.ONE: return gl::GL_ONE;
		case BlendFactor.SRC_COLOR: return gl::GL_SRC_COLOR;
		case BlendFactor.ONE_MINUS_SRC_COLOR: return gl::GL_ONE_MINUS_SRC_COLOR;
		case BlendFactor.DST_COLOR: return gl::GL_DST_COLOR;
		case BlendFactor.ONE_MINUS_DST_COLOR: return gl::GL_ONE_MINUS_DST_COLOR;
		case BlendFactor.SRC_ALPHA: return gl::GL_SRC_ALPHA;
		case BlendFactor.ONE_MINUS_SRC_ALPHA: return gl::GL_ONE_MINUS_SRC_ALPHA;
		case BlendFactor.DST_ALPHA: return gl::GL_DST_ALPHA;
		case BlendFactor.ONE_MINUS_DST_ALPHA: return gl::GL_ONE_MINUS_DST_ALPHA;
		case BlendFactor.SRC_ALPHA_SATURATE: return gl::GL_SRC_ALPHA_SATURATE;
		default: return gl::GL_INVALID_ENUM;
	}
}

fn GlBlend glBlendCompositeOp(CompositeOpState op) @local {
	GlBlend blend = {
		glConvertBlendFuncFactor(op.srcRGB),
		glConvertBlendFuncFactor(op.dstRGB),
		glConvertBlendFuncFactor(op.srcAlpha),
		glConvertBlendFuncFactor(op.dstAlpha)
	};

	if (
	blend.srcRGB == gl::GL_INVALID_ENUM || blend.dstRGB == gl::GL_INVALID_ENUM ||
	blend.srcAlpha == gl::GL_INVALID_ENUM || blend.dstAlpha == gl::GL_INVALID_ENUM
	) {
		blend.srcRGB = gl::GL_ONE;
		blend.dstRGB = gl::GL_ONE_MINUS_SRC_ALPHA;
		blend.srcAlpha = gl::GL_ONE;
		blend.dstAlpha = gl::GL_ONE_MINUS_SRC_ALPHA;
	}

	return blend;
}

fn int glnvgMaxVertCount(MvgPath* paths, int npaths) @local {
	int count = 0;
	for (int i = 0; i < npaths; i++) {
		count += paths[i].nfill;
		count += paths[i].nstroke;
	}
	return count;
}

fn int glnvgRenderCreate(void* up) @local {
	GlContext* gl = (GlContext*)up;
	int align = 4;

	gl.callsBuf.init(GlCall::size, 128);
	gl.pathsBuf.init(GlPath::size, 128);
	gl.vertsBuf.init(Vertex::size, 4096);
	gl.uniformBuf.init(1, 16384);

	char* shaderHeader = `
		#version 150 core
		#define NANOVG_GL3 1
		#define USE_UNIFORMBUFFER 1
	`;

	char* fillVertShader = `
		#ifdef NANOVG_GL3
			uniform vec2 viewSize;
			in vec2 vertex;
			in vec2 tcoord;
			out vec2 ftcoord;
			out vec2 fpos;
		#else
			uniform vec2 viewSize;
			attribute vec2 vertex;
			attribute vec2 tcoord;
			varying vec2 ftcoord;
			varying vec2 fpos;
		#endif
		void main(void) {
			ftcoord = tcoord;
			fpos = vertex;
			gl_Position = vec4(2.0*vertex.x/viewSize.x - 1.0, 1.0 - 2.0*vertex.y/viewSize.y, 0, 1);
		}
	`;

	char* fillFragShader = `
		#ifdef GL_ES
		#if defined(GL_FRAGMENT_PRECISION_HIGH) || defined(NANOVG_GL3)
		 precision highp float;
		#else
		 precision mediump float;
		#endif
		#endif
		#ifdef NANOVG_GL3
		#ifdef USE_UNIFORMBUFFER
			layout(std140) uniform frag {
				mat3 scissorMat;
				mat3 paintMat;
				vec4 innerCol;
				vec4 outerCol;
				vec2 scissorExt;
				vec2 scissorScale;
				vec2 extent;
				float radius;
				float feather;
				float strokeMult;
				float strokeThr;
				int texType;
				int type;
			};
		#else
			uniform vec4 frag[UNIFORMARRAY_SIZE];
		#endif
			uniform sampler2D tex;
			in vec2 ftcoord;
			in vec2 fpos;
			out vec4 outColor;
		#else
			uniform vec4 frag[UNIFORMARRAY_SIZE];
			uniform sampler2D tex;
			varying vec2 ftcoord;
			varying vec2 fpos;
		#endif
		#ifndef USE_UNIFORMBUFFER
			#define scissorMat mat3(frag[0].xyz, frag[1].xyz, frag[2].xyz)
			#define paintMat mat3(frag[3].xyz, frag[4].xyz, frag[5].xyz)
			#define innerCol frag[6]
			#define outerCol frag[7]
			#define scissorExt frag[8].xy
			#define scissorScale frag[8].zw
			#define extent frag[9].xy
			#define radius frag[9].z
			#define feather frag[9].w
			#define strokeMult frag[10].x
			#define strokeThr frag[10].y
			#define texType int(frag[10].z)
			#define type int(frag[10].w)
		#endif

		float sdroundrect(vec2 pt, vec2 ext, float rad) {
			vec2 ext2 = ext - vec2(rad,rad);
			vec2 d = abs(pt) - ext2;
			return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rad;
		}

		float scissorMask(vec2 p) {
			vec2 sc = (abs((scissorMat * vec3(p,1.0)).xy) - scissorExt);
			sc = vec2(0.5,0.5) - sc * scissorScale;
			return clamp(sc.x,0.0,1.0) * clamp(sc.y,0.0,1.0);
		}
		#ifdef EDGE_AA
		float strokeMask() {
			return min(1.0, (1.0-abs(ftcoord.x*2.0-1.0))*strokeMult) * min(1.0, ftcoord.y);
		}
		#endif

		void main(void) {
			vec4 result;
			float scissor = scissorMask(fpos);
	#ifdef EDGE_AA
			float strokeAlpha = strokeMask();
			if (strokeAlpha < strokeThr) discard;
	#else
			float strokeAlpha = 1.0;
	#endif
			if (type == 0) {
				vec2 pt = (paintMat * vec3(fpos,1.0)).xy;
				float d;
				if (texType == 0) {
					d = clamp(pt.x / max(extent.x, 1e-6), 0.0, 1.0);
				} else if (texType == 1) {
					float dist = length(pt);
					d = clamp((dist - radius + feather * 0.5) / feather, 0.0, 1.0);
				} else {
					d = clamp((sdroundrect(pt, extent, radius) + feather*0.5) / feather, 0.0, 1.0);
				}
				vec4 color = mix(innerCol,outerCol,d);
				color *= strokeAlpha * scissor;
				result = color;
			} else if (type == 1) {
				vec2 pt = (paintMat * vec3(fpos,1.0)).xy / extent;
		#ifdef NANOVG_GL3
				vec4 color = texture(tex, pt);
		#else
				vec4 color = texture2D(tex, pt);
		#endif
				if (texType == 1) color = vec4(color.xyz*color.w,color.w);
				if (texType == 2) color = vec4(color.x);
				color *= innerCol;
				color *= strokeAlpha * scissor;
				result = color;
			} else if (type == 2) {
				result = vec4(1,1,1,1);
			} else if (type == 3) {
		#ifdef NANOVG_GL3
				vec4 color = texture(tex, ftcoord);
		#else
				vec4 color = texture2D(tex, ftcoord);
		#endif
				if (texType == 1) color = vec4(color.xyz*color.w,color.w);
				if (texType == 2) color = vec4(color.x);
				color *= scissor;
				result = color * innerCol;
			}
		#ifdef NANOVG_GL3
			outColor = result;
		#else
			gl_FragColor = result;
		#endif
		}
	`;

	gl.checkError("init");

	if (gl.flags & ANTIALIAS) {
		if (glnvgCreateShader(&gl.shader, "shader", shaderHeader, "#define EDGE_AA 1\n", fillVertShader, fillFragShader) == 0) {
			return 0;
		}
	}
	else {
		if (glnvgCreateShader(&gl.shader, "shader", shaderHeader, null, fillVertShader, fillFragShader) == 0) {
			return 0;
		}
	}

	gl.checkError("uniform locations");
	glnvgGetUniforms(&gl.shader);

	gl::genVertexArrays(1, &gl.vertArr);
	gl::genBuffers(1, &gl.vertBuf);

	gl::uniformBlockBinding(gl.shader.prog, (GLuint) gl.shader.loc[GlLoc.FRAG], GLNVG_FRAG_BINDING);
	gl::genBuffers(1, &gl.fragBuf);
	gl::getIntegerv(gl::GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT, &align);
	gl.fragSize = (int)(GlFragUniforms::size) + align - (int)(GlFragUniforms::size) % align;

	gl.dummyTex = glnvgRenderCreateTexture(gl, TextureType.ALPHA, 1, 1, 0, null);

	gl.checkError("create done");

	return 1;
}

fn int glnvgRenderCreateTexture(void* up, TextureType type, int w, int h, int imageFlags, char* data) @local {
	GlContext* gl = (GlContext*)up;
	GlTexture* tex = gl.allocTexture();

	if (tex == null) return 0;

	gl::genTextures(1, &tex.tex);
	tex.width = w;
	tex.height = h;
	tex.type = type;
	tex.flags = imageFlags;
	gl.bindTexture(tex.tex);

	gl::pixelStorei(gl::GL_UNPACK_ALIGNMENT, 1);
	gl::pixelStorei(gl::GL_UNPACK_ROW_LENGTH, tex.width);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_PIXELS, 0);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_ROWS, 0);

	if (type == TextureType.RGBA) {
		gl::texImage2D(gl::GL_TEXTURE_2D, 0, gl::GL_RGBA, w, h, 0, gl::GL_RGBA, gl::GL_UNSIGNED_BYTE, data);
	}
	else {
		gl::texImage2D(gl::GL_TEXTURE_2D, 0, gl::GL_RED, w, h, 0, gl::GL_RED, gl::GL_UNSIGNED_BYTE, data);
	}

	if (imageFlags & microvg::IMAGE_GENERATE_MIPMAPS) {
		if (imageFlags & microvg::IMAGE_NEAREST) {
			gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, gl::GL_NEAREST_MIPMAP_NEAREST);
		}
		else {
			gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, gl::GL_LINEAR_MIPMAP_LINEAR);
		}
	}
	else {
		if (imageFlags & microvg::IMAGE_NEAREST) {
			gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, gl::GL_NEAREST);
		}
		else {
			gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, gl::GL_LINEAR);
		}
	}

	if (imageFlags & microvg::IMAGE_NEAREST) {
		gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MAG_FILTER, gl::GL_NEAREST);
	}
	else {
		gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MAG_FILTER, gl::GL_LINEAR);
	}

	if (imageFlags & microvg::IMAGE_REPEATX) {
		gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_S, gl::GL_REPEAT);
	}
	else {
		gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_S, gl::GL_CLAMP_TO_EDGE);
	}

	if (imageFlags & microvg::IMAGE_REPEATY) {
		gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_T, gl::GL_REPEAT);
	}
	else {
		gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_T, gl::GL_CLAMP_TO_EDGE);
	}

	gl::pixelStorei(gl::GL_UNPACK_ALIGNMENT, 4);
	gl::pixelStorei(gl::GL_UNPACK_ROW_LENGTH, 0);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_PIXELS, 0);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_ROWS, 0);

	if (imageFlags & microvg::IMAGE_GENERATE_MIPMAPS) gl::generateMipmap(gl::GL_TEXTURE_2D);

	gl.checkError("create tex");
	gl.bindTexture(0);

	return tex.id;
}

fn int glnvgRenderDeleteTexture(void* up, int image) @local {
	GlContext* gl = (GlContext*)up;
	return gl.deleteTexture(image);
}

fn int glnvgRenderUpdateTexture(void* up, int image, int x, int y, int w, int h, char* data) @local {
	GlContext* gl = (GlContext*)up;
	GlTexture* tex = gl.findTexture(image);

	if (tex == null) return 0;
	gl.bindTexture(tex.tex);

	gl::pixelStorei(gl::GL_UNPACK_ALIGNMENT, 1);
	gl::pixelStorei(gl::GL_UNPACK_ROW_LENGTH, tex.width);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_PIXELS, x);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_ROWS, y);

	if (tex.type == TextureType.RGBA) {
		gl::texSubImage2D(gl::GL_TEXTURE_2D, 0, x, y, w, h, gl::GL_RGBA, gl::GL_UNSIGNED_BYTE, data);
	}
	else {
		gl::texSubImage2D(gl::GL_TEXTURE_2D, 0, x, y, w, h, gl::GL_RED, gl::GL_UNSIGNED_BYTE, data);
	}

	gl::pixelStorei(gl::GL_UNPACK_ALIGNMENT, 4);
	gl::pixelStorei(gl::GL_UNPACK_ROW_LENGTH, 0);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_PIXELS, 0);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_ROWS, 0);

	gl.bindTexture(0);

	return 1;
}

fn int glnvgRenderGetTextureSize(void* up, int image, int* w, int* h) @local {
	GlContext* gl = (GlContext*)up;
	GlTexture* tex = gl.findTexture(image);
	if (tex == null) return 0;
	*w = tex.width;
	*h = tex.height;
	return 1;
}

fn void glnvgRenderViewport(void* up, float width, float height, float devicePixelRatio) @local {
	GlContext* gl = (GlContext*)up;
	gl.view.x = width;
	gl.view.y = height;
}

fn void glnvgRenderFlush(void* up) @local {
	GlContext* gl = (GlContext*)up;

	if (gl.callsBuf.count > 0) {

		gl::useProgram(gl.shader.prog);

		gl::enable(gl::GL_CULL_FACE);
		gl::cullFace(gl::GL_BACK);
		gl::frontFace(gl::GL_CCW);
		gl::enable(gl::GL_BLEND);
		gl::disable(gl::GL_DEPTH_TEST);
		gl::disable(gl::GL_SCISSOR_TEST);
		gl::colorMask(gl::GL_TRUE, gl::GL_TRUE, gl::GL_TRUE, gl::GL_TRUE);
		gl::stencilMask(0xffffffff);
		gl::stencilOp(gl::GL_KEEP, gl::GL_KEEP, gl::GL_KEEP);
		gl::stencilFunc(gl::GL_ALWAYS, 0, 0xffffffff);
		gl::activeTexture(gl::GL_TEXTURE0);
		gl::bindTexture(gl::GL_TEXTURE_2D, 0);
		gl.boundTexture = (GLuint)0;
		gl.stencilMask = (GLuint)0xffffffff;
		gl.stencilFunc = gl::GL_ALWAYS;
		gl.stencilFuncRef = (GLint)0;
		gl.stencilFuncMask = (GLuint)0xffffffff;
		gl.blendFunc.srcRGB = gl::GL_INVALID_ENUM;
		gl.blendFunc.srcAlpha = gl::GL_INVALID_ENUM;
		gl.blendFunc.dstRGB = gl::GL_INVALID_ENUM;
		gl.blendFunc.dstAlpha = gl::GL_INVALID_ENUM;

		gl::bindBuffer(gl::GL_UNIFORM_BUFFER, gl.fragBuf);
		gl::bufferData(gl::GL_UNIFORM_BUFFER, gl.uniformBuf.count, gl.uniformBuf.data, gl::GL_STREAM_DRAW);

		gl::bindVertexArray(gl.vertArr);
		gl::bindBuffer(gl::GL_ARRAY_BUFFER, gl.vertBuf);
		gl::bufferData(gl::GL_ARRAY_BUFFER, gl.vertsBuf.count * Vertex::size, gl.vertsBuf.data, gl::GL_STREAM_DRAW);
		gl::enableVertexAttribArray(0);
		gl::enableVertexAttribArray(1);
		gl::vertexAttribPointer(0, 2, gl::GL_FLOAT, gl::GL_FALSE, Vertex::size, (void*)(usz)0);
		gl::vertexAttribPointer(1, 2, gl::GL_FLOAT, gl::GL_FALSE, Vertex::size, (void*)(usz)(2 * float::size));

		gl::uniform1i(gl.shader.loc[(GlLoc.TEX)], 0);
		gl::uniform2fv(gl.shader.loc[(GlLoc.VIEWSIZE)], 1, &gl.view[0]);

		gl::bindBuffer(gl::GL_UNIFORM_BUFFER, gl.fragBuf);

		for (int i = 0; i < gl.callsBuf.count; i++) {
			GlCall* call = (GlCall*)gl.callsBuf.at(i);
			gl.blendFuncSeparate(&call.blendFunc);

			switch (call.type) {
				case GlCallType.FILL: gl.fill(call);
				case GlCallType.CONVEXFILL: gl.convexFill(call);
				case GlCallType.EARFILL: gl.earFill(call);
				case GlCallType.STROKE: gl.stroke(call);
				case GlCallType.TRIANGLES: gl.triangles(call);
				case GlCallType.NONE: break;
			}
		}

		gl::disableVertexAttribArray(0);
		gl::disableVertexAttribArray(1);
		gl::bindVertexArray(0);
		gl::disable(gl::GL_CULL_FACE);
		gl::bindBuffer(gl::GL_ARRAY_BUFFER, 0);
		gl::useProgram(0);
		gl.bindTexture(0);
	}

	gl.callsBuf.reset();
	gl.pathsBuf.reset();
	gl.vertsBuf.reset();
	gl.uniformBuf.reset();
}

fn void glnvgRenderFill(void* up, Paint* paint, CompositeOpState compositeOp, Scissor* scissor, float fringe, float* bounds, MvgPath* paths, int npaths) @local {
	GlContext* gl = (GlContext*)up;
	bool convex = (npaths == 1 && paths[0].convex);
	bool earClip = !convex && npaths == 1 && paths[0].triFill != null;

	int fillVertCount = 0;
	int strokeVertCount = 0;
	for (int i = 0; i < npaths; i++) {
		if (paths[i].triFill != null) {
			fillVertCount += paths[i].ntriFill;
		}
		else {
			fillVertCount += paths[i].nfill;
		}
		strokeVertCount += paths[i].nstroke;
	}

	int triVertCount = convex ? 0 : (earClip ? 0 : 4);
	int uniCount = (convex || earClip) ? 1 : 2;

	int callIdx = gl.allocCall();
	if (callIdx < 0) return;

	int pathOff = gl.allocPaths(npaths);
	if (pathOff < 0) {
		gl.callsBuf.count--;
		return;
	}

	int vertOff = gl.allocVerts(fillVertCount + strokeVertCount + triVertCount);
	if (vertOff < 0) {
		gl.callsBuf.count--;
		gl.pathsBuf.count -= npaths;
		return;
	}

	int uniByteOff = gl.allocFragUniforms(uniCount);
	if (uniByteOff < 0) {
		gl.callsBuf.count--;
		gl.pathsBuf.count -= npaths;
		gl.vertsBuf.count -= (fillVertCount + strokeVertCount + triVertCount);
		return;
	}

	GlCall* call = (GlCall*)gl.callsBuf.at(callIdx);
	mem::clear(call, GlCall::size);
	call.type = convex ? GlCallType.CONVEXFILL : (earClip ? GlCallType.EARFILL : GlCallType.FILL);
	call.triangleCount = triVertCount;
	call.pathOffset = pathOff;
	call.pathCount = npaths;
	call.image = paint.image;
	call.blendFunc = glBlendCompositeOp(compositeOp);

	int voff = vertOff;
	for (int i = 0; i < npaths; i++) {
		GlPath* copy = gl.pathsBuf.at(pathOff + i);
		MvgPath* path = &paths[i];
		mem::clear(copy, GlPath::size);
		if (earClip) {
			copy.fillOffset = voff;
			copy.fillCount = path.ntriFill;
			mem::copy(gl.vertsBuf.at(voff), path.triFill, Vertex::size * path.ntriFill);
			voff += path.ntriFill;
		}
		else if (path.nfill > 0) {
			copy.fillOffset = voff;
			copy.fillCount = path.nfill;
			mem::copy(gl.vertsBuf.at(voff), path.fill, Vertex::size * path.nfill);
			voff += path.nfill;
		}
		if (path.nstroke > 0) {
			copy.strokeOffset = voff;
			copy.strokeCount = path.nstroke;
			mem::copy(gl.vertsBuf.at(voff), path.stroke, Vertex::size * path.nstroke);
			voff += path.nstroke;
		}
	}

	if (earClip) {
		call.triangleOffset = vertOff;
		call.triangleCount = paths[0].ntriFill;
		call.uniformOffset = uniByteOff;
		GlFragUniforms* frag = (GlFragUniforms*)(gl.uniformBuf.data + call.uniformOffset);
		gl.convertPaint(frag, paint, scissor, fringe, fringe, -1.0f);
	}
	else if (!convex) {
		call.triangleOffset = voff;
		Vertex* quad = (Vertex*)gl.vertsBuf.at(call.triangleOffset);
		quad[0] = { bounds[2], bounds[3], 0.5f, 1.0f };
		quad[1] = { bounds[2], bounds[1], 0.5f, 1.0f };
		quad[2] = { bounds[0], bounds[3], 0.5f, 1.0f };
		quad[3] = { bounds[0], bounds[1], 0.5f, 1.0f };

		call.uniformOffset = uniByteOff;
		GlFragUniforms* frag = (GlFragUniforms*)(gl.uniformBuf.data + call.uniformOffset);
		mem::clear(frag, GlFragUniforms::size);
		frag.strokeThr = -1.0f;
		frag.type = (NsvgShader.SIMPLE);
		gl.convertPaint((GlFragUniforms*)(gl.uniformBuf.data + call.uniformOffset + gl.fragSize), paint, scissor, fringe, fringe, -1.0f);
	}
	else {
		call.uniformOffset = uniByteOff;
		GlFragUniforms* frag = (GlFragUniforms*)(gl.uniformBuf.data + call.uniformOffset);
		gl.convertPaint(frag, paint, scissor, fringe, fringe, -1.0f);
	}
}

fn void glnvgRenderStroke(void* up, Paint* paint, CompositeOpState compositeOp, Scissor* scissor, float fringe, float strokeWidth, MvgPath* paths, int npaths) @local {
	GlContext* gl = (GlContext*)up;
	int maxverts = glnvgMaxVertCount(paths, npaths);
	int uniCount = (gl.flags & STENCIL_STROKES) ? 2 : 1;

	int callIdx = gl.allocCall();
	if (callIdx < 0) return;

	int pathOff = gl.allocPaths(npaths);
	if (pathOff < 0) {
		gl.callsBuf.count--;
		return;
	}

	int vertOff = gl.allocVerts(maxverts);
	if (vertOff < 0) {
		gl.callsBuf.count--;
		gl.pathsBuf.count -= npaths;
		return;
	}

	int uniByteOff = gl.allocFragUniforms(uniCount);
	if (uniByteOff < 0) {
		gl.callsBuf.count--;
		gl.pathsBuf.count -= npaths;
		gl.vertsBuf.count -= maxverts;
		return;
	}

	GlCall* call = gl.callsBuf.at(callIdx);
	mem::clear(call, GlCall::size);
	call.type = GlCallType.STROKE;
	call.pathOffset = pathOff;
	call.pathCount = npaths;
	call.image = paint.image;
	call.blendFunc = glBlendCompositeOp(compositeOp);
	call.uniformOffset = uniByteOff;

	int voff = vertOff;
	for (int i = 0; i < npaths; i++) {
		GlPath* copy = gl.pathsBuf.at(pathOff + i);
		MvgPath* path = &paths[i];
		mem::clear(copy, GlPath::size);
		if (path.nstroke) {
			copy.strokeOffset = voff;
			copy.strokeCount = path.nstroke;
			mem::copy(gl.vertsBuf.at(voff), path.stroke, Vertex::size * path.nstroke);
			voff += path.nstroke;
		}
	}

	if (gl.flags & STENCIL_STROKES) {
		gl.convertPaint((GlFragUniforms*)(gl.uniformBuf.data + uniByteOff), paint, scissor, strokeWidth, fringe, -1.0f);
		gl.convertPaint((GlFragUniforms*)(gl.uniformBuf.data + uniByteOff + gl.fragSize), paint, scissor, strokeWidth, fringe, 1.0f - 0.5f / 255.0f);
	}
	else {
		gl.convertPaint((GlFragUniforms*)(gl.uniformBuf.data + uniByteOff), paint, scissor, strokeWidth, fringe, -1.0f);
	}
}

fn void glnvgRenderTriangles(void* up, Paint* paint, CompositeOpState compositeOp, Scissor* scissor, Vertex* verts, int nverts, float fringe) @local {
	GlContext* gl = up;

	int callIdx = gl.allocCall();
	if (callIdx < 0) return;

	int vertOff = gl.allocVerts(nverts);
	if (vertOff < 0) {
		gl.callsBuf.count--;
		return;
	}

	int uniByteOff = gl.allocFragUniforms(1);
	if (uniByteOff < 0) {
		gl.callsBuf.count--;
		gl.vertsBuf.count -= nverts;
		return;
	}

	GlCall* call = gl.callsBuf.at(callIdx);
	mem::clear(call, GlCall::size);
	call.type = (GlCallType.TRIANGLES);
	call.image = paint.image;
	call.blendFunc = glBlendCompositeOp(compositeOp);
	call.triangleOffset = vertOff;
	call.triangleCount = nverts;
	call.uniformOffset = uniByteOff;

	mem::copy(gl.vertsBuf.at(vertOff), verts, Vertex::size * nverts);

	GlFragUniforms* frag = (GlFragUniforms*)(gl.uniformBuf.data + uniByteOff);
	gl.convertPaint(frag, paint, scissor, 1.0f, fringe, -1.0f);
	frag.type = NsvgShader.IMG;
}

fn void glnvgRenderDelete(void* up) @local {
	GlContext* gl = (GlContext*)up;
	if (gl == null) return;

	glnvgDeleteShader(&gl.shader);

	if (gl.fragBuf != 0) gl::deleteBuffers(1, &gl.fragBuf);
	if (gl.vertArr != 0) gl::deleteVertexArrays(1, &gl.vertArr);
	if (gl.vertBuf != 0) gl::deleteBuffers(1, &gl.vertBuf);

	for (int i = 0; i < gl.ntextures; i++) {
		if (gl.textures[i].tex != 0 && (gl.textures[i].flags & IMAGE_NODELETE) == 0) {
			gl::deleteTextures(1, &gl.textures[i].tex);
		}
	}
	mem::free(gl.textures);

	gl.callsBuf.delete();
	gl.pathsBuf.delete();
	gl.vertsBuf.delete();
	gl.uniformBuf.delete();

	mem::free(gl);
}

fn MicroVG* nvgCreateGl3(int flags) {
	Params params;
	MicroVG* ctx = null;
	GlContext* gl = mem::calloc(GlContext::size);
	if (gl == null) return null;

	mem::clear(&params, Params::size);
	params.renderCreate = &glnvgRenderCreate;
	params.renderCreateTexture = &glnvgRenderCreateTexture;
	params.renderDeleteTexture = &glnvgRenderDeleteTexture;
	params.renderUpdateTexture = &glnvgRenderUpdateTexture;
	params.renderGetTextureSize = &glnvgRenderGetTextureSize;
	params.renderViewport = &glnvgRenderViewport;
	params.renderCancel = &glnvgRenderCancel;
	params.renderFlush = &glnvgRenderFlush;
	params.renderFill = &glnvgRenderFill;
	params.renderStroke = &glnvgRenderStroke;
	params.renderTriangles = &glnvgRenderTriangles;
	params.renderDelete = &glnvgRenderDelete;
	params.userPtr = gl;
	params.edgeAA = (flags & ANTIALIAS) ? 1 : 0;

	gl.flags = flags;

	ctx = microvg::nvgCreateInternal(&params);
	if (ctx == null) return null;

	return ctx;
}
