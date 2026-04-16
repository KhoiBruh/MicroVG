package microvg.shader

const val TEXT_FRAG = """
	
	#version 330 core

	in vec2 vUV;
	
	uniform sampler2D uAtlas;
	uniform vec4 uColor;
	
	uniform vec4 uBloomColor;
	uniform int uBloomRadius;
	
	uniform float uSdfThreshold;
	uniform float uSdfPxRange;
	
	out vec4 fragColor;
	
	void main() {
	    float dist = texture(uAtlas, vUV).r - uSdfThreshold;
	    float fw = fwidth(dist);
	
	    float textAlpha = smoothstep(-fw, fw, dist);
	
	    float glowAlpha = 0.0;
	    if (uBloomColor.a > 0.0 && uBloomRadius > 0) {
	        float glowDist = uBloomRadius * fw;
	        glowAlpha = smoothstep(-glowDist, 0.0, dist) * uBloomColor.a;
	        glowAlpha *= (1.0 - textAlpha);
	    }
	
	    vec4 bloom = vec4(uBloomColor.rgb, glowAlpha);
	    vec4 text = vec4(uColor.rgb, uColor.a * textAlpha);
	
	    float outA = text.a + bloom.a * (1.0 - text.a);
	    if (outA <= 0.0) discard;
	
	    vec3 outRGB = (text.rgb * text.a + bloom.rgb * bloom.a * (1.0 - text.a)) / outA;
	    fragColor = vec4(outRGB, outA);
	}

"""

const val TEXT_VERT = """
	
	#version 330 core

	layout (location = 0) in vec2 aCorner;
	layout (location = 1) in vec4 iPosSize;
	layout (location = 2) in vec4 iUVRect;
	
	uniform mat4 uProjection;
	
	out vec2 vUV;
	
	void main() {
	    vec2 pos = iPosSize.xy + aCorner * iPosSize.zw;
	
	    vUV = mix(iUVRect.xy, iUVRect.zw, aCorner);
	
	    gl_Position = uProjection * vec4(pos, 0.0, 1.0);
	}

"""