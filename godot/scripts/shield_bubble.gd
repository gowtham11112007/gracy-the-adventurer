extends Node2D
## The cupcake shield: a soft, pulsing pink bubble around Janani.


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := 0.18 + sin(Time.get_ticks_msec() / 160.0) * 0.06
	draw_circle(Vector2(0, -64), 78, Color(1, 0.6, 0.84, pulse))
	draw_arc(Vector2(0, -64), 78, 0, TAU, 64, Color(1, 1, 1, 0.7), 3.0, true)
