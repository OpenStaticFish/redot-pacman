class_name ArcadeIcons
extends RefCounted
## Small, crisp vector symbols shared by the native arcade interface.

enum Symbol { SOUND, MUTED, PAUSE, PLAY, FULLSCREEN, BRANCH, TROPHY, ARROW_RIGHT, POWER }


static func paint(canvas: CanvasItem, symbol: Symbol, position: Vector2, color: Color, scale_factor: float = 1.0) -> void:
	match symbol:
		Symbol.SOUND, Symbol.MUTED:
			_polygon(canvas, position, color, scale_factor, [Vector2(-9, -4), Vector2(-5, -4), Vector2(1, -9), Vector2(1, 9), Vector2(-5, 4), Vector2(-9, 4)])
			if symbol == Symbol.SOUND:
				for radius in [6, 10]:
					canvas.draw_arc(position - Vector2(1, 0) * scale_factor, radius * scale_factor, -0.72, 0.72, 16, color, 1.6 * scale_factor, true)
			else:
				_line(canvas, position, color, scale_factor, [Vector2(4, -4), Vector2(10, 4)])
				_line(canvas, position, color, scale_factor, [Vector2(4, 4), Vector2(10, -4)])
		Symbol.PAUSE:
			for x in [-6, 2]:
				canvas.draw_rect(Rect2(position + Vector2(x, -8) * scale_factor, Vector2(4, 16) * scale_factor), color)
		Symbol.PLAY:
			_polygon(canvas, position, color, scale_factor, [Vector2(-5, -8), Vector2(8, 0), Vector2(-5, 8)])
		Symbol.FULLSCREEN:
			for x in [-1, 1]:
				for y in [-1, 1]:
					_line(canvas, position, color, scale_factor, [Vector2(x * 3, y * 8), Vector2(x * 8, y * 8), Vector2(x * 8, y * 3)])
		Symbol.BRANCH:
			_line(canvas, position, color, scale_factor, [Vector2(-5, -7), Vector2(-5, 7)])
			_line(canvas, position, color, scale_factor, [Vector2(-5, 2), Vector2(6, -5)])
			for point: Vector2 in [Vector2(-5, -7), Vector2(-5, 7), Vector2(6, -5)]:
				canvas.draw_circle(position + point * scale_factor, 2.4 * scale_factor, color)
		Symbol.TROPHY:
			_polygon(canvas, position, color, scale_factor, [Vector2(-6, -8), Vector2(6, -8), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0)])
			_line(canvas, position, color, scale_factor, [Vector2(-6, -6), Vector2(-10, -6), Vector2(-9, -1), Vector2(-4, 1)])
			_line(canvas, position, color, scale_factor, [Vector2(6, -6), Vector2(10, -6), Vector2(9, -1), Vector2(4, 1)])
			_line(canvas, position, color, scale_factor, [Vector2(0, 3), Vector2(0, 9)])
			_line(canvas, position, color, scale_factor, [Vector2(-5, 9), Vector2(5, 9)])
		Symbol.ARROW_RIGHT:
			_line(canvas, position, color, scale_factor, [Vector2(-8, 0), Vector2(8, 0)])
			_line(canvas, position, color, scale_factor, [Vector2(3, -5), Vector2(8, 0), Vector2(3, 5)])
		Symbol.POWER:
			_polygon(canvas, position, color, scale_factor, [Vector2(-1, -9), Vector2(5, -9), Vector2(1, -1), Vector2(7, -1), Vector2(-3, 10), Vector2(-1, 2), Vector2(-7, 2)])


static func _points(position: Vector2, scale_factor: float, points: Array[Vector2]) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point: Vector2 in points:
		transformed.append(position + point * scale_factor)
	return transformed


static func _line(canvas: CanvasItem, position: Vector2, color: Color, scale_factor: float, points: Array[Vector2]) -> void:
	canvas.draw_polyline(_points(position, scale_factor, points), color, 1.7 * scale_factor, true)


static func _polygon(canvas: CanvasItem, position: Vector2, color: Color, scale_factor: float, points: Array[Vector2]) -> void:
	canvas.draw_colored_polygon(_points(position, scale_factor, points), color)
