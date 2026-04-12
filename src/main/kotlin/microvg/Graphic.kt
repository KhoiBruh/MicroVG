package microvg

import microvg.shape.Circle
import microvg.shape.RoundRect
import microvg.util.TRANSPARENT

fun push() = States.push()

fun pop() = States.pop()

fun translate(x: Float, y: Float) = States.translate(x, y)

fun scale(x: Float, y: Float) = States.scale(x, y)

fun scale(s: Float) = States.scale(s)

fun rect(
	x: Float, y: Float, w: Float, h: Float,
	radius: Float, color: Int,
	bloomColor: Int = TRANSPARENT, bloomRadius: Int = 0
) = RoundRect.draw(x, y, w, h, radius, color, bloomColor, bloomRadius)

fun circle(
	x: Float, y: Float, radius: Float, color: Int,
	bloomColor: Int = TRANSPARENT, bloomRadius: Int = 0
) = Circle.draw(x, y, radius, color, bloomColor, bloomRadius)
