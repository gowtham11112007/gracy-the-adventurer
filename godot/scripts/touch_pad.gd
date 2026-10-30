extends Control
## The phone's on-screen buttons (the owner's layout, 17 Oct): left and right under the left thumb; under the
## right thumb a diamond of up, down, the sword and jump, with the magic button on top while she has a power.
## Every finger is tracked, so she can run and jump at the same time; each finger presses the one button it
## is nearest to (never two at once), with a generous reach because thumbs aren't precise. They press the same
## actions as the keyboard, so the rest of the game doesn't care which one is used.
## The pad keeps following the fingers while the game is paused, so a thumb lifted during the pause menu
## doesn't leave her running afterwards.

const BUTTONS := ["left", "right", "up", "down", "jump", "attack", "shoot"]
## how big each button is (left and right are what the left thumb rests on, jump is the biggest on the right)
const RADIUS := { "left": 72.0, "right": 72.0, "up": 52.0, "down": 52.0, "jump": 68.0, "attack": 62.0, "shoot": 52.0 }
const REACH := 1.45  ## a finger this many radii from a button's middle still presses it

## finger index -> where it is on screen (shared by every room's pad: a thumb held on "right" while she walks
## through a door is still known to the next room's pad, which lets go when the thumb lifts)
static var _touches := {}
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
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("touch_pad")
	get_viewport().size_changed.connect(queue_redraw)
	_update_buttons() # (fingers already down from the room before)


## leaving with a room: let go of its buttons, unless the next room's pad (already there) holds them too
func _exit_tree() -> void:
	for name: String in _held:
		if not _held[name]:
			continue
		var kept := false
		for pad: Node in get_tree().get_nodes_in_group("touch_pad"):
			kept = kept or (pad != self and pad._held.get(name, false))
		if not kept:
			Input.action_release(name)


## Where each button sits: left and right in the bottom-left corner; up (ladders, doorways) above and down
## below, the sword to the left and jump to the right, in the bottom-right corner, and the magic above jump.
## (Measured from the corners, so wider phones just spread them further apart. Nothing overlaps or is cut off.)
func centers(size := Vector2.ZERO) -> Dictionary:
	if size == Vector2.ZERO: # (the tests try other phone shapes)
		size = get_viewport_rect().size
	var diamond := Vector2(size.x - 205, size.y - 205) # the middle of the right-hand buttons
	return {
		"left": Vector2(118, size.y - 128),
		"right": Vector2(300, size.y - 128),
		"up": diamond + Vector2(0, -100),
		"down": diamond + Vector2(0, 100),
		"attack": diamond + Vector2(-106, 0),
		"jump": diamond + Vector2(106, 0),
		"shoot": diamond + Vector2(106, -152),
	}


## the button a finger at `pos` presses: the nearest one in reach ("" for none)
func button_at(pos: Vector2) -> String:
	var where := centers()
	var best := ""
	var best_d := INF
	for name: String in BUTTONS:
		if name == "shoot" and not shoot_icon:
			continue
		var d := pos.distance_to(where[name]) / float(RADIUS[name])
		if d < REACH and d < best_d:
			best = name
			best_d = d
	return best


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
	var pressed := {}
	for pos: Vector2 in _touches.values():
		var name := button_at(pos)
		if name:
			pressed[name] = true
	for name: String in BUTTONS:
		var on: bool = pressed.has(name)
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
		var radius: float = RADIUS[name]
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
