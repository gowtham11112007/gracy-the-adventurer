extends Node2D
## A soft shadow on the ground under a character: it stays on the ground when she jumps,
## shrinking and fading the higher she goes, so you always see where she'll land.

var target: Node2D
var width := 46.0
var _ground_y := 0.0
var _height := 0.0


func _physics_process(_delta: float) -> void:
	var space := get_world_2d().direct_space_state
	var from := target.global_position + Vector2(0, -8)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 600), 1) # ground only
	var hit := space.intersect_ray(query)
	visible = not hit.is_empty() and target.visible
	if hit:
		_ground_y = hit.position.y
		_height = maxf(0.0, _ground_y - target.global_position.y)
	global_position = Vector2(target.global_position.x, _ground_y)
	queue_redraw()


func _draw() -> void:
	var fade := clampf(1.0 - _height / 320.0, 0.25, 1.0)
	var w := width * (0.55 + 0.45 * fade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.28)) # a squashed circle: an ellipse
	var shade := Color(0.04, 0.1, 0.03) # a deep green-black, so it sits naturally on grass and dirt
	draw_circle(Vector2(0, 0), w, Color(shade, 0.45 * fade))
	draw_circle(Vector2(0, 0), w * 0.68, Color(shade, 0.3 * fade))
