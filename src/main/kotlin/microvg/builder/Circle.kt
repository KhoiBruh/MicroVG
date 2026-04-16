package microvg.builder

import microvg.shape.CircleRenderer

class Circle(
	private var radius: Float = 0f
) : Shape() {

	override fun fill(color: Int): Circle {
		fillColor = color
		return this
	}

	override fun stroke(color: Int, width: Float): Circle {
		strokeColor = color
		strokeWidth = width
		return this
	}

	override fun shadow(radius: Int, mode: ShadowMode, color: Int): Circle {
		shadowRadius = radius
		shadowMode = mode
		shadowColor = color
		return this
	}

	override fun blur(radius: Int, mode: BlurMode): Circle {
		blurRadius = radius
		blurMode = mode
		return this
	}

	fun radius(r: Float): Circle {
		radius = r
		return this
	}

	override fun draw(x: Float, y: Float) {
		super.draw(x, y)
		CircleRenderer.draw(
			this.x, this.y,
			radius, fillColor,
			shadowColor, shadowRadius,
		)
	}

	override fun contains(mX: Float, mY: Float) = mX * mX + mY * mY <= radius * radius
}