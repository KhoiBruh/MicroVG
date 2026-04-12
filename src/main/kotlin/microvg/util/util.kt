package microvg.util

import java.awt.Color
import kotlin.math.max

const val WHITE = -1
const val BLACK = 0xFF000000.toInt()
const val TRANSPARENT = 0

val Int.r
	get() = this shr 16 and 0xFF

val Int.g
	get() = this shr 8 and 0xFF

val Int.b
	get() = this and 0xFF

val Int.a
	get() = this shr 24 and 0xFF

fun Int.darker(factor: Float = 0.7F): Int {
	val r = max(r * factor, 0F).toInt()
	val g = max(g * factor, 0F).toInt()
	val b = max(b * factor, 0F).toInt()
	return rgba(r, g, b, a)
}

fun Int.fade(next: Int, factor: Float = 0.7F): Int {
	val inverseFactor = 1 - factor
	val nextA = next.a
	val nextR = next.r
	val nextG = next.g
	val nextB = next.b
	return rgba(
		(r * inverseFactor + nextR * factor).toInt(),
		(g * inverseFactor + nextG * factor).toInt(),
		(b * inverseFactor + nextB * factor).toInt(),
		(a * inverseFactor + nextA * factor).toInt(),
	)
}

fun Int.alpha(alpha: Int) = this and 0x00FFFFFF or (alpha shl 24)

fun Int.toAwtColor() = Color(this, true)

fun Int.toFloats(): FloatArray {
	val r = r / 255F
	val g = g / 255F
	val b = b / 255F
	val a = a / 255F
	return floatArrayOf(r, g, b, a)
}

fun rgba(r: Int, g: Int, b: Int, a: Int = 255) = a shl 24 or (r shl 16) or (g shl 8) or b

fun hsb(h: Float, s: Float, b: Float, a: Float = 1F): Int {
	val rgb = Color.HSBtoRGB(h, s, b)
	return if (a == 1F) rgb else rgb.alpha((a * 255).toInt())
}

fun Boolean.toInt() = if (this) 1 else 0