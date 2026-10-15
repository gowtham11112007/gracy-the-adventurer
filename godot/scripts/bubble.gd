extends Node2D
## The glowing bubble Yuva traps someone in.

var radius := 60.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1, 0.6, 0.84, 0.22))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1, 1, 1, 0.85), 4.0, true)
	draw_arc(Vector2.ZERO, radius * 0.8, PI * 1.1, PI * 1.4, 16, Color(1, 1, 1, 0.6), 5.0, true)
