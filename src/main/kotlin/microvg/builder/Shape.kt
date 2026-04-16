package microvg.builder

import microvg.util.TRANSPARENT

sealed class Shape {
	var x = 0F
	var y = 0F
	protected var fillColor = TRANSPARENT
	protected var strokeColor = TRANSPARENT
	protected var strokeWidth = 0F
	protected var shadowColor = TRANSPARENT
	protected var shadowRadius = 0
	protected var shadowMode = ShadowMode.OUTER
	protected var blurRadius = 0
	protected var blurMode = BlurMode.BACKGROUND

	abstract fun fill(color: Int = TRANSPARENT): Shape
	abstract fun stroke(color: Int = TRANSPARENT, width: Float = 1F): Shape
	abstract fun shadow(radius: Int = 0, mode: ShadowMode = ShadowMode.OUTER, color: Int = TRANSPARENT): Shape
	abstract fun blur(radius: Int = 0, mode: BlurMode = BlurMode.BACKGROUND): Shape

	abstract fun contains(mX: Float, mY: Float): Boolean

	open fun draw(x: Float, y: Float) {
		this.x = x
		this.y = y
	}

	enum class ShadowMode {
		INNER, OUTER
	}

	enum class BlurMode {
		BACKGROUND, FOREGROUND
	}
}

