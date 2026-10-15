extends CanvasLayer
## The classic circle transition: the screen closes into a circle around a point, or opens out of one.

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 50
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://scripts/iris.gdshader")
	_rect.material = _mat
	add_child(_rect)
	set_radius(4000.0) # fully open


func set_radius(r: float) -> void:
	_mat.set_shader_parameter("radius", r)


## close (open = false) or open around a point on the screen; `done` runs at the end
func play(center: Vector2, open: bool, seconds := 0.6, done := Callable()) -> void:
	_mat.set_shader_parameter("center", center)
	var size := get_viewport().get_visible_rect().size
	var far := maxf(center.length(), (size - center).length()) + maxf(size.x, size.y) * 0.5
	var tw := create_tween()
	tw.tween_method(set_radius, 0.0 if open else far, far if open else 0.0, seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if done.is_valid():
		tw.tween_callback(done)
