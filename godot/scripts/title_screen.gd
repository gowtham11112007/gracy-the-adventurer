extends Node2D
## The title screen: a deep forest at night (the cartoon-forest pack, its layers swaying for depth) with light
## falling through the trees, drifting fog and fireflies. "GRACY - The Adventurer" in carved gold, the menu
## below it, Janani and Kitty on the forest floor, and Yuva floating among the trees with Janika in her bubble.

signal start_game                  ## continue into the world map (a slot is loaded)
signal new_game_started(slot: int) ## a fresh game was started in this slot
signal open_story
signal open_wardrobe
signal open_shrine

const UI := preload("res://scripts/ui.gd")
const FLOOR := 672.0 ## where feet touch the forest floor

var _vp: Vector2
var _items: Array[Button] = []
var _selected := 0


func _ready() -> void:
	_vp = get_viewport_rect().size
	var back := UI.backdrop("teal_forest", Color(0.78, 0.86, 0.95))
	UI.fill_screen(back, _vp)
	add_child(back)
	add_child(UI.light_rays(_vp, Color(0.75, 1.0, 0.9, 0.3)))
	_characters()
	add_child(UI.fog(_vp, Color(0.55, 0.85, 0.85, 0.14), 0.88))
	add_child(UI.fireflies(_vp, 45))
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(UI.vignette(_vp, 0.75))
	_logo(ui)
	_menu(ui)
	_progress(ui)
	Game.play_music("title")
	var args := OS.get_cmdline_user_args()
	if "slots" in args: # (testing) open the save slots / settings straight away
		_open_slots()
	elif "settings" in args:
		_open_settings()


func _x(x: float) -> float:
	return x * _vp.x / 1280.0


func _characters() -> void:
	var spot := Vector2(_x(210), FLOOR)
	add_child(_shadow(spot, 90))
	var light := UI.glow(170, Color(0.5, 0.95, 0.85, 0.22)) # a soft light around them, as if from the fireflies
	light.position = spot + Vector2(30, -110)
	add_child(light)
	var janani := UI.actor("janani")
	janani.scale = Vector2(1.25, 1.25)
	janani.position = spot
	janani.modulate = Color(0.9, 0.95, 1.0)
	add_child(janani)
	var kitty := UI.actor("kitty")
	kitty.scale = Vector2(0.95, 0.95)
	kitty.position = spot + Vector2(96, 0)
	kitty.modulate = Color(0.9, 0.95, 1.0)
	add_child(kitty)

	# Yuva drifts among the trees with Janika in her glowing bubble
	var group := Node2D.new()
	group.position = Vector2(_x(1060), 300)
	add_child(group)
	var bubble := UI.bubble(62)
	bubble.position = Vector2(-105, -4)
	group.add_child(bubble)
	var janika := UI.actor("janika")
	janika.scale = Vector2(0.6, 0.6)
	janika.position = Vector2(-105, 42)
	group.add_child(janika)
	var yuva := UI.actor("yuva")
	yuva.scale = Vector2(0.7, 0.7)
	yuva.flip_h = true
	yuva.position = Vector2(30, 70)
	yuva.modulate = Color(0.8, 0.85, 0.95)
	group.add_child(yuva)
	UI.bob(group, 12, 2.4)


## a soft dark oval on the ground under someone
func _shadow(at: Vector2, width: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = UI.soft_light()
	s.modulate = Color(0, 0.02, 0.04, 0.55)
	s.scale = Vector2(width / 64.0, width / 64.0 * 0.22)
	s.position = at + Vector2(30, 0)
	return s


func _logo(ui: CanvasLayer) -> void:
	var logo := Control.new()
	logo.size = Vector2(800, 200)
	logo.position = Vector2((_vp.x - 800) / 2, 52)
	ui.add_child(logo)
	var glow := UI.glow(260, Color(1.0, 0.8, 0.45, 0.18))
	glow.position = Vector2(400, 70)
	glow.scale.x *= 2.2
	logo.add_child(glow)
	var name := UI.centered(UI.title("Gracy", 112), Vector2(800, 130))
	logo.add_child(name)
	var line := UI.heading("The Adventurer", 800, 26)
	line.position.y = 128
	line.modulate = Color(1, 1, 1, 0.9)
	logo.add_child(line)
	UI.rise_in(logo, 0.2, 1.2)


func _menu(ui: CanvasLayer) -> void:
	# Continue (only when a save is loaded), then the save slots, the story, wardrobe, candles and settings.
	# A Callable entry runs here; a Signal entry is emitted.
	var entries: Array = []
	if Game.slot >= 1:
		entries.append(["Continue", start_game])
	entries.append(["Save Slots", _open_slots])
	entries.append_array([["Story", open_story], ["Wardrobe", open_wardrobe], ["Candles", open_shrine],
		["Settings", _open_settings]])
	var box := VBoxContainer.new()
	box.size = Vector2(440, 320)
	box.position = Vector2((_vp.x - 440) / 2, 318)
	box.add_theme_constant_override("separation", 4)
	ui.add_child(box)
	for i in entries.size():
		var item := UI.menu_item(entries[i][0], 40 if i == 0 else 30)
		item.custom_minimum_size = Vector2(440, 64 if i == 0 else 54)
		var action: Variant = entries[i][1]
		item.pressed.connect(func() -> void:
			if action is Callable:
				action.call()
			else:
				(action as Signal).emit())
		var idx := i
		item.mouse_entered.connect(func() -> void: _select(idx))
		box.add_child(item)
		_items.append(item)
	_select(0)
	UI.rise_in(box, 0.9, 1.0)


func _select(index: int) -> void:
	_selected = index
	for i in _items.size():
		_items[i].lit = i == index


## Crystals and candles found so far, quietly along the bottom.
func _progress(ui: CanvasLayer) -> void:
	var crystals := 0
	for k in Game.save.crystals:
		crystals += (Game.save.crystals[k] as Array).size()
	var l := UI.centered(UI.text("Crystals  %d / 15        Candles  %d / 5" % [crystals, Game.save.candles.size()], 20, UI.MIST), Vector2(_vp.x, 30))
	l.position.y = _vp.y - 44
	ui.add_child(l)
	UI.rise_in(l, 1.4)


func _open_settings() -> void:
	var p := preload("res://scripts/popup.gd").new()
	p.title = "Settings"
	p.sheet_size = Vector2(640, 520)
	add_child(p)
	p.add_all_settings("title")


## The three save slots: an empty one starts a new game; a used one shows its progress and can be loaded or
## deleted (the delete button asks once more before it deletes).
func _open_slots() -> void:
	var p := preload("res://scripts/popup.gd").new()
	p.title = "Save Slots"
	p.sheet_size = Vector2(940, 560)
	add_child(p)
	for i in range(1, Game.SLOTS + 1):
		var info := Game.slot_summary(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.custom_minimum_size = Vector2(0, 92)
		var card := UI.panel(Vector2(0, 92), 16)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 92)
		row.add_child(card)
		var name := UI.title("Slot %d" % i, 24)
		name.position = Vector2(22, 10)
		card.add_child(name)
		var line := "Empty" if info.is_empty() else "Levels %d/5   Crystals %d/15   Candles %d/5   %s" % [
			info.cleared, info.crystals, info.candles, _play_time(info.played)]
		var sub := UI.text(line, 18, UI.MIST if info.is_empty() else UI.CREAM)
		sub.position = Vector2(22, 50)
		card.add_child(sub)
		var go := UI.button("New game" if info.is_empty() else "Load", "gold", 150, 70, 22)
		var slot := i
		go.pressed.connect(func() -> void:
			if info.is_empty():
				Game.new_game(slot)
				p.close()
				new_game_started.emit(slot)
			else:
				Game.load_slot(slot)
				p.close()
				start_game.emit())
		row.add_child(go)
		if not info.is_empty():
			var del := UI.button("Delete", "glass", 130, 70, 18)
			var armed := [false]
			del.pressed.connect(func() -> void:
				if not armed[0]:
					armed[0] = true
					del.text = "SURE?" # one more tap deletes
					get_tree().create_timer(3.0).timeout.connect(func() -> void:
						if is_instance_valid(del):
							armed[0] = false
							del.text = "DELETE")
					return
				Game.delete_slot(slot)
				p.close()
				_open_slots())
			row.add_child(del)
		p.body.add_child(row)


func _play_time(seconds: float) -> String:
	var m := int(seconds / 60.0)
	return "%dh %02dm" % [m / 60, m % 60] if m >= 60 else "%d min" % m


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed:
		return
	if key.keycode == KEY_DOWN:
		_select((_selected + 1) % _items.size())
	elif key.keycode == KEY_UP:
		_select((_selected - 1 + _items.size()) % _items.size())
	elif key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
		_items[_selected].pressed.emit()
