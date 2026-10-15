extends Node2D
## A soft pulsing white glow behind Super Kitty.


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := 0.22 + sin(Time.get_ticks_msec() / 140.0) * 0.08
	draw_circle(Vector2(0, -34), 46, Color(0.91, 0.93, 1.0, pulse))
	draw_circle(Vector2(0, -34), 30, Color(1, 1, 1, pulse * 0.8))
