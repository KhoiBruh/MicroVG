package microvg.shader

const val ROUND_RECT_FRAG = """
	
	#version 330 core

	in vec2 vPos;
	in vec2 vHalfSize;
	in vec4 vColor;
	in float vRadius;
	
	uniform vec4 uBloomColor;
	uniform int uBloomRadius;
	
	uniform int uUseBlur;
	uniform sampler2D uBlurTex;
	uniform ivec2 uScreenSize;
	
	out vec4 fragColor;
	
	void main() {
	    float r = min(vRadius, min(vHalfSize.x, vHalfSize.y));
	    vec2 q = abs(vPos) - vHalfSize + r;
	    float dist = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
	    float fw = fwidth(dist);
	
	    float shapeAlpha = 1.0 - smoothstep(-fw, fw, dist);
	
	    float glowAlpha = 0.0;
	    if (uBloomColor.a > 0.0 && uBloomRadius > 0) {
	        glowAlpha = smoothstep(uBloomRadius, -fw, dist) * uBloomColor.a;
	        glowAlpha *= (1.0 - shapeAlpha);
	    }
	
	    vec3 baseColor = vColor.rgb;
	    float baseAlpha = vColor.a;
	
	    if (uUseBlur == 1 && shapeAlpha > 0.0) {
	        vec2 screenUv = gl_FragCoord.xy / uScreenSize;
	        vec3 blurredBg = texture(uBlurTex, screenUv).rgb;
	
	        baseColor = mix(blurredBg, vColor.rgb, vColor.a);
	
	        baseAlpha = 1.0;
	    }
	
	    vec4 shape = vec4(baseColor, baseAlpha * shapeAlpha);
	    vec4 bloom = vec4(uBloomColor.rgb, glowAlpha);
	
	    float outA = shape.a + bloom.a * (1.0 - shape.a);
	    if (outA <= 0.0) discard;
	
	    vec3 outRGB = (shape.rgb * shape.a + bloom.rgb * bloom.a * (1.0 - shape.a)) / outA;
	    fragColor = vec4(outRGB, outA);
	}

"""

const val ROUND_RECT_VERT = """
	
	#version 330 core

	layout (location = 0) in vec2 aCorner;
	
	layout (location = 1) in vec4 iPosSize;
	layout (location = 2) in vec4 iColor;
	layout (location = 3) in float iRadius;
	
	uniform mat4 uProjection;
	uniform int uBloomRadius;
	
	out vec2 vPos;
	out vec2 vHalfSize;
	out vec4 vColor;
	out float vRadius;
	
	void main() {
	    int pad = uBloomRadius;
	
	    vec2 expandedXY = iPosSize.xy - pad;
	    vec2 expandedWH = iPosSize.zw + 2.0 * pad;
	    vec2 worldPos = expandedXY + aCorner * expandedWH;
	
	    gl_Position = uProjection * vec4(worldPos, 0.0, 1.0);
	
	    vec2 center = iPosSize.xy + iPosSize.zw * 0.5;
	    vPos = worldPos - center;
	    vHalfSize = iPosSize.zw * 0.5;
	
	    vColor = iColor;
	    vRadius = iRadius;
	}

"""