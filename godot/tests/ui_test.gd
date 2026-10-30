extends SceneTree
## Checks the interface and the controls the way a player uses them: the title menu, the save slots, the
## candles, Back (Esc / the phone's Back button) on every screen, the phone's touch buttons (their layout on
## several phone shapes, fingers, the pause menu, walking through a door) and the keyboard on a ladder.
## Nothing here is written to a real save slot.
## Run from the godot folder:  Godot --headless --path . --script res://tests/ui_test.gd

const TILE := 64
const PAD := preload("res://scripts/touch_pad.gd")
var _fails := 0
var game: Node


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1280, 720) # (a test window is tiny: give it a phone screen's size, so taps land where aimed)
	await process_frame
	game = root.get_node("Game")
	var keep_slot: int = game.slot
	var keep_save: Dictionary = game.save.duplicate(true)
	game.slot = 0 # nothing here is written to a real save slot
	await _test_title()
	await _test_slots()
	await _test_candles()
	await _test_pad_layout()
	await _test_fingers()
	await _test_back_in_room()
	await _test_back_on_pages()
	await _test_ladder_keys()
	await _test_room_hud()
	game.save = keep_save
	game.slot = keep_slot
	print("\n%s" % ("ALL INTERFACE TESTS PASSED" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## a left-button click at a point on the screen, like a mouse or a tapping finger
func _click(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	root.push_input(down)
	var up: InputEventMouseButton = down.duplicate()
	up.pressed = false
	root.push_input(up)


## a key on the keyboard, pressed or let go (goes through the game's controls, like a real key)
func _key(code: Key, pressed := true) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e) # (this also hands the key to the screen, like a real key)
	Input.flush_buffered_events()


## a finger touching the phone's screen (or lifting off it)
func _touch(finger: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = at
	e.pressed = pressed
	root.push_input(e)


func _held_buttons() -> Array:
	return PAD.BUTTONS.filter(func(a: String) -> bool: return Input.is_action_pressed(a))


func _labels(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _open_room(id: String) -> Node2D:
	var level: Node2D = load("res://scripts/level.gd").new()
	level.def = game.room_def(id)
	root.add_child(level)
	return level


func _test_title() -> void:
	game.slot = 0
	var title: Node2D = load("res://scripts/title_screen.gd").new()
	root.add_child(title)
	await _wait(2.2) # the menu rises in
	var items: Array = title._items
	_check(items[0].text == "NEW GAME" and not items.any(func(b: Button) -> bool: return b.text == "CONTINUE"),
		"with no game loaded, the title menu starts with New Game")
	var settings: Button = items.filter(func(b: Button) -> bool: return b.text == "SETTINGS")[0]
	_click(settings.get_global_rect().get_center())
	await _wait(0.2)
	_check(game.overlays.size() == 1, "clicking Settings opens the settings")
	await _wait(0.3)
	game.go_back()
	await _wait(0.4)
	_check(game.overlays.is_empty(), "Back closes the settings")
	var before: int = title._selected
	_key(KEY_DOWN)
	_key(KEY_DOWN, false)
	_check(title._selected == (before + 1) % title._items.size(), "the Down key moves along the menu (round to the top after the last)")
	var all: Dictionary = game.world_totals()
	_check(_labels(title).any(func(t: String) -> bool: return t.begins_with("Rooms") and ("/ %d" % all.rooms) in t and ("/ %d" % all.crystals) in t),
		"the line along the bottom counts the world's %d rooms and %d crystals" % [all.rooms, all.crystals])
	title.free()
	game.slot = 1 # (only read by the menu here)
	var title2: Node2D = load("res://scripts/title_screen.gd").new()
	root.add_child(title2)
	await process_frame
	_check(title2._items[0].text == "CONTINUE", "with a game loaded, it starts with Continue")
	title2.free()
	game.slot = 0


func _test_slots() -> void:
	var title: Node2D = load("res://scripts/title_screen.gd").new()
	root.add_child(title)
	await process_frame
	title._open_slots()
	await _wait(0.5)
	var popup: Node = game.overlays.back()
	_check(not _labels(popup).any(func(t: String) -> bool: return "Levels" in t), "the save slots no longer talk about the old five levels")
	var buttons: Array = popup.find_children("*", "Button", true, false)
	var new_game: Array = buttons.filter(func(b: Button) -> bool: return b.text.to_upper() == "NEW GAME")
	_check(not new_game.is_empty() and new_game.all(func(b: Button) -> bool: return b.size.x >= 170), "the New Game buttons are wide enough for their words")
	var widths: Array = []
	for row: Node in popup.body.get_children():
		if row is HBoxContainer:
			widths.append(int((row as HBoxContainer).get_child(0).size.x))
	_check(widths.size() == 3 and widths.max() - widths.min() <= 1, "the three slot cards line up %s" % [widths])
	await _wait(0.3)
	game.go_back()
	await _wait(0.4)
	_check(game.overlays.is_empty(), "Back closes the save slots")
	title.free()


func _test_candles() -> void:
	game.save.candles = ["m4"]
	game.save.rooms_seen = ["m4"]
	var chapel: Node2D = load("res://scripts/rpg_chapel.gd").new()
	root.add_child(chapel)
	await process_frame
	var words: Array = _labels(chapel)
	_check(words.any(func(t: String) -> bool: return t.begins_with("1 of 5 lit")), "the candle found in the Hilltop room is lit on the candles screen")
	_check(words.has("Hilltop") and words.has("Sunny Meadow") and words.has("Yuva's Hill"), "the candles show their areas, and the rooms she has been to")
	_check(not words.any(func(t: String) -> bool: return t.begins_with("1-")), "no old level numbers on the candles screen")
	chapel.free()
	game.save.candles = []
	game.save.rooms_seen = []


## the owner's layout (17 Oct): left and right on the left; up, down, sword and jump on the right with the magic on
## top. On every phone shape: inside the screen, nothing overlapping.
func _test_pad_layout() -> void:
	var pad: Control = PAD.new()
	root.add_child(pad)
	pad.shoot_icon = game.texture("icon_fire") # (the magic button shows while she has a charge)
	var bad: Array = []
	for size: Vector2 in [Vector2(1280, 720), Vector2(1440, 720), Vector2(1560, 720), Vector2(1600, 720),
			Vector2(1680, 720), Vector2(1280, 800), Vector2(1280, 960)]:
		var c: Dictionary = pad.centers(size)
		for a: String in c:
			var r: float = PAD.RADIUS[a]
			if c[a].x - r < 8 or c[a].x + r > size.x - 8 or c[a].y - r < 8 or c[a].y + r > size.y - 8:
				bad.append("%s is cut off at %s" % [a, size])
			for b: String in c:
				if a < b and c[a].distance_to(c[b]) < r + PAD.RADIUS[b] + 6:
					bad.append("%s and %s overlap at %s" % [a, b, size])
		for a: String in ["left", "right"]:
			if c[a].x > size.x / 2:
				bad.append("%s is not on the left at %s" % [a, size])
		for a: String in ["up", "down", "attack", "jump", "shoot"]:
			if c[a].x < size.x / 2:
				bad.append("%s is not on the right at %s" % [a, size])
		if not (c.up.y < c.down.y and c.shoot.y < c.up.y):
			bad.append("up / down / magic out of order at %s" % size)
	_check(bad.is_empty(), "the touch buttons fit every phone shape without overlapping: left/right on the left, up/down + magic on top on the right %s" % [bad])
	pad.free()


func _test_fingers() -> void:
	var pad: Control = PAD.new()
	root.add_child(pad)
	await process_frame
	var c: Dictionary = pad.centers()
	_touch(0, c.right, true)
	await _frames(2)
	_check(_held_buttons() == ["right"], "a thumb on the right button runs right, and only that")
	_touch(1, c.jump, true)
	await _frames(2)
	_check(Input.is_action_pressed("right") and Input.is_action_pressed("jump"), "two thumbs: run and jump at the same time")
	_touch(1, c.jump, false)
	_touch(0, c.right, false)
	await _frames(3)
	_check(_held_buttons().is_empty(), "lifting both thumbs lets go of both")
	_touch(0, (c.up + c.attack) / 2.0, true) # between two buttons
	await _frames(2)
	_check(_held_buttons().size() == 1, "a thumb between two buttons presses only one of them %s" % [_held_buttons()])
	_touch(0, (c.up + c.attack) / 2.0, false)
	await _frames(3)
	# the pause menu: a thumb held on "right", lifted while the game is paused: she mustn't keep running after
	_touch(0, c.right, true)
	await _frames(2)
	paused = true
	_touch(0, c.right, false)
	await _frames(3)
	paused = false
	await _frames(2)
	_check(not Input.is_action_pressed("right"), "a thumb lifted during the pause menu doesn't leave her running")
	# through a door: the next room's pad knows the thumb is still there, and lets go when it lifts
	_touch(0, c.right, true)
	await _frames(2)
	var next_pad: Control = PAD.new()
	root.add_child(next_pad)
	pad.queue_free()
	await _frames(3)
	_check(Input.is_action_pressed("right"), "holding right through a door keeps her running in the next room")
	_touch(0, c.right, false)
	await _frames(3)
	_check(not Input.is_action_pressed("right"), "and lifting the thumb there stops her (no stuck button)")
	next_pad.free()


func _test_back_in_room() -> void:
	var level := _open_room("m2")
	await _wait(0.3)
	level.go_back() # (main.gd sends Back here when nothing else is open)
	await _wait(0.3)
	_check(paused and game.overlays.size() == 1, "Back in a room opens the pause menu")
	game.go_back()
	await _wait(0.4)
	_check(not paused and game.overlays.is_empty(), "Back again closes it and play goes on")
	_key(KEY_M)
	_key(KEY_M, false)
	await _wait(0.3)
	_check(paused and game.overlays.size() == 1 and String(game.overlays[0].get_script().resource_path).ends_with("map_screen.gd"), "M opens the map, and the game waits")
	game.go_back()
	await _wait(0.4)
	_check(not paused and game.overlays.is_empty(), "Back closes the map and play goes on")
	# pause menu, then its Map: Back closes only the map, then the pause menu
	level.open_pause_menu()
	await _wait(0.3)
	var map_button: Button = game.overlays[0].find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.to_upper() == "MAP")[0]
	map_button.pressed.emit()
	await _wait(0.3)
	game.go_back()
	await _wait(0.4)
	_check(paused and game.overlays.size() == 1, "from the pause menu's map, Back returns to the pause menu")
	game.go_back()
	await _wait(0.4)
	_check(not paused and game.overlays.is_empty(), "and Back once more goes back to playing")
	# the Esc key goes the same way
	var heard := [0]
	var count := func() -> void: heard[0] += 1
	game.back_pressed.connect(count)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE, false)
	await _wait(0.3)
	_check(heard[0] == 1, "the Esc key counts as Back")
	game.back_pressed.disconnect(count)
	level.free()


## with the whole game (main.gd): Back on the wardrobe and candles returns to the title; on the title it does nothing
func _test_back_on_pages() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	for page: String in ["cottage", "chapel"]:
		main.call("open_rpg_" + page)
		await _wait(1.2)
		var opened: String = main._current_screen.get_script().resource_path
		game.go_back()
		await _wait(1.2)
		var now: String = main._current_screen.get_script().resource_path
		_check(opened.ends_with("rpg_%s.gd" % page) and now.ends_with("title_screen.gd"), "Back on the %s screen returns to the title" % ("wardrobe" if page == "cottage" else "candles"))
	game.go_back()
	await _wait(1.0)
	_check(main._current_screen.get_script().resource_path.ends_with("title_screen.gd"), "Back on the title does nothing (it doesn't quit the game)")
	main.free()


## the keyboard's Up key is also a jump key: on a ladder it must only climb
func _test_ladder_keys() -> void:
	var level := _open_room("m2")
	await physics_frame
	var col := String(level.def.grid[5]).find("L")
	level.player.teleport(Vector2(col * TILE + TILE / 2.0, 640))
	await _wait(0.2)
	_key(KEY_UP)
	await _frames(20)
	_check(level.player.climbing, "the Up key grabs the ladder")
	_key(KEY_UP, false)
	await _frames(3)
	_key(KEY_UP) # a second tap of Up
	await _frames(4)
	_check(level.player.climbing, "tapping Up again keeps her on the ladder (it used to make her jump off)")
	_key(KEY_UP, false)
	await _frames(2)
	_key(KEY_SPACE)
	await _frames(3)
	_key(KEY_SPACE, false)
	await _frames(2)
	_check(not level.player.climbing, "Space jumps off the ladder")
	level.free()


func _test_room_hud() -> void:
	var level := _open_room("m1")
	await physics_frame
	_check(not level._hud.score.visible and not level._hud.lives.visible, "rooms show hearts, magic and gems, but no score or lives")
	var lives: int = game.state.lives
	level._die()
	await _wait(2.6)
	_check(game.state.lives == lives and not level._dying and level.hearts == game.state.max_hearts,
		"running out of hearts in a room costs no life: she starts the room again with full hearts")
	level.free()
