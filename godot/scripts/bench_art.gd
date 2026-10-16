extends Node2D
## A resting place: a short iron lantern post with a stone seat. Drawn with lines (no picture needed), feet on
## the node's position. Level._build_benches (level.gd) sets this script on a node and puts a glow above it.
## Touching it heals and saves.


func _draw() -> void:
	var iron := Color("#2b3442")
	var gold := Color("#e6c47a")
	draw_rect(Rect2(-58, -26, 116, 12), Color("#5a6577"))      # the seat
	draw_rect(Rect2(-58, -26, 116, 4), Color("#7a869a"))       # light on its top edge
	draw_rect(Rect2(-48, -14, 12, 14), Color("#454f60"))       # legs
	draw_rect(Rect2(36, -14, 12, 14), Color("#454f60"))
	draw_line(Vector2(0, -26), Vector2(0, -104), iron, 6.0, true)  # the post
	draw_rect(Rect2(-14, -134, 28, 32), iron)                  # the lantern box
	draw_rect(Rect2(-9, -129, 18, 22), Color("#ffe9a8"))       # the light inside
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -134), Vector2(18, -134), Vector2(0, -150)]), gold)
