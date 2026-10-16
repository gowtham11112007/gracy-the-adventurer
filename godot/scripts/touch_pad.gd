extends Control
## The phone's on-screen buttons: left, right, up and down on the left; jump and the sword on the right,
## and the magic button above them while she has a fire power.
## Every finger is tracked, so she can run and jump at the same time; they press the same
## actions as the keyboard, so the rest of the game doesn't care which one is used.

const BUTTONS := ["left", "right", "up", "down", "jump", "attack", "shoot"]

var radius := 70.0
var _touches := {}       ## finger index -> where it is on screen
var _held := {}          ## button -> pressed right now?
var _release_later := [] ## buttons let go in the same instant they were pressed (a quick tap)
var _pressed_at := {}    ## button -> physics frame it was pressed in
## the power's icon, shown on the magic button (null: no power, no button)
var shoot_icon: Texture2D:
	set(value):
		shoot_icon = value
		if not value and _held.get("shoot", false):
			_held.shoot = false # the power is gone: let go of its button
			Input.action_release("shoot")
		queue_redraw()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)


func centers() -> Dictionary:
	var size := get_viewport_rect().size
	return {
		"left": Vector2(radius + 30, size.y - radius * 1.65 - 25),
		"right": Vector2(radius * 3.4 + 40, size.y - radius * 1.65 - 25),
		"up": Vector2(radius * 2.2 + 35, size.y - radius * 2.85 - 30),
		"down": Vector2(radius * 2.2 + 35, size.y - radius * 0.65 - 15),
		"jump": Vector2(size.x - radius - 55, size.y - radius - 35),
		"attack": Vector2(size.x - radius * 3 - 85, size.y - radius - 15),
		"shoot": Vector2(size.x - radius * 2.4 - 70, size.y - radius * 3.3 - 30),
	}


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_update_buttons()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		_update_buttons()


func _update_buttons() -> void:
	var where := centers()
	for name: String in BUTTONS:
		if name == "shoot" and not shoot_icon:
			continue
		var on := false
		for pos: Vector2 in _touches.values():
			if pos.distance_to(where[name]) < radius * 1.3: # generous: thumbs aren't precise
				on = true
		if on == _held.get(name, false):
			continue
		_held[name] = on
		if on:
			Input.action_press(name)
			_pressed_at[name] = Engine.get_physics_frames()
		elif _pressed_at.get(name, -1) == Engine.get_physics_frames():
			_release_later.append(name) # keep it down for one step so the game still sees the tap
		else:
			Input.action_release(name)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	for name: String in _release_later:
		if not _held.get(name, false):
			Input.action_release(name)
	_release_later.clear()
	queue_redraw()


func _draw() -> void:
	var where := centers()
	for name: String in BUTTONS:
		if name == "shoot" and not shoot_icon:
			continue
		var c: Vector2 = where[name]
		var on: bool = _held.get(name, false) or Input.is_action_pressed(name)
		draw_circle(c, radius, Color(0, 0, 0, 0.35 if on else 0.18))
		draw_arc(c, radius, 0, TAU, 48, Color(1, 1, 1, 0.6 if on else 0.3), 3.0, true)
		if name == "shoot":
			draw_texture(shoot_icon, c - shoot_icon.get_size() / 2, Color(1, 1, 1, 1.0 if on else 0.75))
			continue
		var s := radius * 0.32
		var ink := Color(1, 1, 1, 0.9 if on else 0.6)
		if name == "attack": # a sword, point up and to the right
			draw_line(c + Vector2(-s * 1.1, s * 1.1), c + Vector2(s * 1.2, -s * 1.2), ink, 6.0, true)
			draw_line(c + Vector2(-s * 0.9, s * 0.1), c + Vector2(-s * 0.1, s * 0.9), ink, 5.0, true)
			continue
		if name == "jump": # (not the same as Up: an arrow springing off a line)
			draw_line(c + Vector2(-s, s * 1.15), c + Vector2(s, s * 1.15), ink, 4.0, true)
		var arrow: PackedVector2Array
		match name:
			"left": arrow = [c + Vector2(-s, 0), c + Vector2(s * 0.7, -s), c + Vector2(s * 0.7, s)]
			"right": arrow = [c + Vector2(s, 0), c + Vector2(-s * 0.7, -s), c + Vector2(-s * 0.7, s)]
			"up": arrow = [c + Vector2(0, -s), c + Vector2(-s, s * 0.7), c + Vector2(s, s * 0.7)]
			"down": arrow = [c + Vector2(0, s), c + Vector2(-s, -s * 0.7), c + Vector2(s, -s * 0.7)]
			"jump": arrow = [c + Vector2(0, -s * 1.2), c + Vector2(-s, s * 0.5), c + Vector2(s, s * 0.5)]
		draw_colored_polygon(arrow, ink)
