extends Node2D
## World 1's map at dusk: the painted map, dimmed and cooled with a vignette and fireflies, five glass stops on
## the road (gold-rimmed once cleared, dim and locked until the one before is cleared), Janani and Kitty
## walking between them, Yuva near his castle with Janika in her glowing bubble, and a glass card about the
## chosen level with a gold PLAY button. Back returns to the title.

signal level_selected(index: int)
signal open_rpg_cottage
signal open_rpg_chapel
signal open_beta_map
signal back_to_title

const UI := preload("res://scripts/ui.gd")
const MAP_W := 1024.0
const MAP_H := 572.0

## The 5 clearings on the map's road, in map picture pixels
const CLEARINGS: Array[Vector2] = [
	Vector2(155, 497),
	Vector2(326, 454),
	Vector2(520, 495),
	Vector2(724, 449),
	Vector2(920, 474)
]

var current := 0
var walking := false
var _scale_k := 1.25
var _offset := Vector2.ZERO
var _spots: Array[Vector2] = []
var _stops: Array[Button] = []

var hero: AnimatedSprite2D
var kitty: AnimatedSprite2D
var _card_world: Label
var _card_title: Label
var _card_gems: Array[TextureRect] = []
var _card_candle: TextureRect


func _ready() -> void:
	var vp := get_viewport_rect().size
	_scale_k = maxf(vp.x / MAP_W, vp.y / MAP_H)
	_offset = (vp - Vector2(MAP_W, MAP_H) * _scale_k) / 2.0
	for p in CLEARINGS:
		_spots.append(_offset + p * _scale_k)

	var map := Sprite2D.new()
	map.texture = Game.texture("world1_map")
	map.centered = false
	map.position = _offset
	map.scale = Vector2(_scale_k, _scale_k)
	map.modulate = Color(0.72, 0.78, 0.92) # dusk light over the bright painting
	add_child(map)
	_build_boss_teaser()
	_build_heroes()
	add_child(UI.fireflies(vp, 30))
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	ui.add_child(UI.vignette(vp, 0.7))
	_build_stops(ui)
	_build_top(ui, vp)
	_build_card(ui, vp)
	_build_bottom(ui, vp)

	for i in Game.levels.solo.size(): # start at the furthest level she can play
		if is_unlocked(i):
			current = i
	_snap_heroes(current)
	_update_card()
	Game.play_music("title")


func is_unlocked(index: int) -> bool:
	return index == 0 or Game.save.cleared.has(Game.levels.solo[index - 1].id)


func is_cleared(index: int) -> bool:
	return Game.save.cleared.has(Game.levels.solo[index].id)


func _build_boss_teaser() -> void:
	var group := Node2D.new()
	group.position = _offset + Vector2(860, 330) * _scale_k
	add_child(group)
	var bubble := UI.bubble(46)
	bubble.position = Vector2(-70, -4)
	group.add_child(bubble)
	var janika := UI.actor("janika")
	janika.scale = Vector2(0.45, 0.45)
	janika.position = Vector2(-70, 30)
	group.add_child(janika)
	var yuva := UI.actor("yuva")
	yuva.scale = Vector2(0.55, 0.55)
	yuva.flip_h = true
	yuva.position = Vector2(20, 60)
	group.add_child(yuva)
	UI.bob(group, 10, 2.0)


# ------------------------------------------------------------ level stops ---

func _build_stops(ui: CanvasLayer) -> void:
	for i in _spots.size():
		var lvl_id: String = Game.levels.solo[i].id
		var unlocked := is_unlocked(i)
		var stop := UI.button(str(i + 1), "glass", 66, 66, 30)
		stop.position = _spots[i] - stop.size / 2
		stop.disabled = not unlocked
		if is_cleared(i): # a gold rim once cleared
			var s: StyleBoxFlat = stop.get_theme_stylebox("normal").duplicate()
			s.border_color = UI.GOLD
			s.set_border_width_all(3)
			stop.add_theme_stylebox_override("normal", s)
		if not unlocked: # locked: dim, with no number yet
			stop.text = ""
			stop.modulate = Color(0.6, 0.6, 0.7, 0.8)
		var glow := UI.glow(70, Color(1.0, 0.85, 0.5, 0.35 if unlocked else 0.0))
		glow.position = stop.size / 2
		glow.show_behind_parent = true
		stop.add_child(glow)
		if Game.save.candles.has(lvl_id):
			var candle := UI.picture(Game.texture("candle"), Vector2(16, 34))
			candle.position = Vector2(56, -14)
			stop.add_child(candle)
		var idx := i
		stop.pressed.connect(func() -> void: _on_stop_pressed(idx))
		ui.add_child(stop)
		_stops.append(stop)

	# A floating celestial Beta icon on the map for quick testing
	var beta_stop := UI.button("β", "gold", 64, 64, 30)
	beta_stop.position = _offset + Vector2(430, 310) * _scale_k - beta_stop.size / 2
	var bglow := UI.glow(80, Color(0.4, 0.9, 1.0, 0.65))
	bglow.position = beta_stop.size / 2
	bglow.show_behind_parent = true
	beta_stop.add_child(bglow)
	UI.breathe(bglow, 0.6, 1.2)
	var blabel := UI.text("BETA", 14, UI.GOLD, "title")
	blabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blabel.position = Vector2(-20, 64)
	blabel.size = Vector2(104, 20)
	beta_stop.add_child(blabel)
	beta_stop.pressed.connect(func() -> void: open_beta_map.emit())
	ui.add_child(beta_stop)


func _on_stop_pressed(index: int) -> void:
	if walking or not is_unlocked(index):
		return
	if index == current:
		enter_level()
	else:
		walk_to(index)


# ----------------------------------------------------------------- heroes ---

func _build_heroes() -> void:
	hero = UI.actor("janani")
	hero.z_index = 5
	hero.scale = Vector2(0.6, 0.6)
	add_child(hero)
	kitty = UI.actor("kitty")
	kitty.z_index = 4
	kitty.scale = Vector2(0.5, 0.5)
	add_child(kitty)


func _snap_heroes(index: int) -> void:
	hero.position = _spots[index] + Vector2(0, -30)
	kitty.position = _spots[index] + Vector2(-40, -30)
	hero.play("idle")
	kitty.play("idle")
	_highlight()


## the chosen stop breathes softly
func _highlight() -> void:
	for i in _stops.size():
		var s := _stops[i]
		if s.has_meta("tween"):
			(s.get_meta("tween") as Tween).kill()
			s.remove_meta("tween")
		s.self_modulate = Color.WHITE
		if i == current:
			var tw := s.create_tween().set_loops()
			tw.tween_property(s, "self_modulate", Color(1.3, 1.2, 0.9), 0.8).set_trans(Tween.TRANS_SINE)
			tw.tween_property(s, "self_modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)
			s.set_meta("tween", tw)


func walk_to(target: int) -> void:
	if walking or target == current or not is_unlocked(target):
		return
	walking = true
	var step := 1 if target > current else -1
	hero.flip_h = step < 0
	kitty.flip_h = step < 0
	hero.play("walk")
	kitty.play("walk")
	var step_fn: Callable
	step_fn = func() -> void:
		current += step
		var s: Vector2 = _spots[current]
		var tw := create_tween()
		tw.tween_property(hero, "position", s + Vector2(0, -30), 0.4)
		tw.parallel().tween_property(kitty, "position", s + Vector2(-40 * step, -30), 0.45)
		tw.tween_callback(func() -> void:
			if current != target:
				step_fn.call()
			else:
				hero.flip_h = false
				kitty.flip_h = false
				hero.play("idle")
				kitty.play("idle")
				walking = false
				_highlight()
				_update_card())
	step_fn.call()


# ------------------------------------------------------------- UI panels ---

func _build_top(ui: CanvasLayer, vp: Vector2) -> void:
	var back := UI.icon_button("back", 60)
	back.position = Vector2(22, 22)
	back.pressed.connect(func() -> void: back_to_title.emit())
	ui.add_child(back)
	var stats := UI.text("Lives  %d       Gems  %d" % [Game.state.lives, Game.state.gems], 22, UI.CREAM, "bold")
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.size = Vector2(320, 36)
	stats.position = Vector2(vp.x - 350, 36)
	ui.add_child(stats)


func _build_card(ui: CanvasLayer, vp: Vector2) -> void:
	var card := UI.panel(Vector2(620, 132), 22)
	card.position = Vector2((vp.x - 620) / 2, 18)
	ui.add_child(card)
	_card_world = UI.text("", 20, UI.MIST)
	_card_world.position = Vector2(30, 16)
	card.add_child(_card_world)
	_card_title = UI.title("", 36)
	_card_title.position = Vector2(30, 40)
	card.add_child(_card_title)
	for i in 3: # the level's three big crystals, dim until found
		var gem := UI.picture(Game.texture("gem_big"), Vector2(30, 30))
		gem.position = Vector2(32 + i * 36, 88)
		card.add_child(gem)
		_card_gems.append(gem)
	_card_candle = UI.picture(Game.texture("candle"), Vector2(14, 30))
	_card_candle.position = Vector2(150, 88)
	card.add_child(_card_candle)
	var play := UI.button("Play", "gold", 170, 60, 26)
	play.position = Vector2(420, 36)
	play.pressed.connect(enter_level)
	card.add_child(play)
	UI.rise_in(card, 0.1)


func _update_card() -> void:
	var def: Dictionary = Game.levels.solo[current]
	_card_world.text = "World %s" % def.id
	_card_title.text = String(def.name).to_upper()
	var found: Array = Game.save.crystals.get(def.id, [])
	for i in 3:
		_card_gems[i].modulate = Color.WHITE if found.has(i) else Color(0.4, 0.45, 0.6, 0.4)
	_card_candle.modulate = Color.WHITE if Game.save.candles.has(def.id) else Color(0.4, 0.45, 0.6, 0.4)


func _build_bottom(ui: CanvasLayer, vp: Vector2) -> void:
	var buttons := [["Wardrobe", open_rpg_cottage], ["Candles", open_rpg_chapel], ["Beta Map", open_beta_map]]
	for i in buttons.size():
		var b := UI.button(buttons[i][0], "glass", 210, 58, 22)
		b.position = Vector2(22 + i * 226, vp.y - 82)
		var sig: Signal = buttons[i][1]
		b.pressed.connect(func() -> void: sig.emit())
		if buttons[i][0] == "Beta Map":
			var glow := UI.glow(60, Color(0.4, 0.9, 1.0, 0.45))
			glow.position = b.size / 2
			glow.show_behind_parent = true
			b.add_child(glow)
			UI.breathe(glow, 0.6, 1.2)
		ui.add_child(b)
		UI.rise_in(b, 0.3 + i * 0.1)


func enter_level() -> void:
	if not walking:
		level_selected.emit(current)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed:
		return
	if key.keycode == KEY_RIGHT or key.keycode == KEY_D:
		if current < _spots.size() - 1:
			walk_to(current + 1)
	elif key.keycode == KEY_LEFT or key.keycode == KEY_A:
		if current > 0:
			walk_to(current - 1)
	elif key.keycode == KEY_B:
		open_beta_map.emit()
	elif key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
		enter_level()
	elif key.keycode == KEY_ESCAPE:
		back_to_title.emit()
