package microvg.builder

import microvg.shape.RoundRectRenderer

class RoundRect(
	private var w: Float = 0f,
	private var h: Float = 0f,
	private var r: Float = 0f
) : Shape() {

	override fun fill(color: Int): RoundRect {
		fillColor = color
		return this
	}

	override fun stroke(color: Int, width: Float): RoundRect {
		strokeColor = color
		strokeWidth = width
		return this
	}

	override fun shadow(radius: Int, mode: ShadowMode, color: Int): RoundRect {
		shadowRadius = radius
		shadowMode = mode
		shadowColor = color
		return this
	}

	override fun blur(radius: Int, mode: BlurMode): RoundRect {
		blurRadius = radius
		blurMode = mode
		return this
	}

	fun size(w: Float = this.w, h: Float = this.h, r: Float = this.r): RoundRect {
		this.w = w
		this.h = h
		this.r = r
		return this
	}

	override fun draw(x: Float, y: Float) {
		super.draw(x, y)
		RoundRectRenderer.draw(
			this.x, this.y, w, h, r,
			fillColor, shadowColor, shadowRadius
		)
	}

	override fun contains(mX: Float, mY: Float) = mX in 0f..w && mY in 0f..h
}