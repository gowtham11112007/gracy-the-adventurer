extends Node2D
## After a level: the lantern forest at night, Janani in her victory pose, and a glass card that counts up
## the level's crystals, gems, candle and score, then names the outfit this level unlocked.
## Buttons: World map, and Next (Continue after Yuva's hill).

signal next_level
signal return_to_map

const UI := preload("res://scripts/ui.gd")

var level_id := "1-1"
var level_name := "SUNNY MEADOW"
var final_score := 0
var gems_collected := 0
var candle_found := false

var _score_lbl: Label
var _gems_lbl: Label


func _ready() -> void:
	var vp := get_viewport_rect().size
	var back := UI.backdrop("lantern_forest", Color(0.7, 0.72, 0.85))
	UI.fill_screen(back, vp)
	add_child(back)
	add_child(UI.fireflies(vp, 30, Color(1.0, 0.85, 0.55)))
	var janani := UI.actor("janani")
	janani.scale = Vector2(1.5, 1.5)
	janani.position = Vector2(vp.x * 0.2, vp.y - 60)
	janani.play("victory")
	add_child(janani)
	var light := UI.glow(220, Color(1.0, 0.85, 0.55, 0.3))
	light.position = janani.position + Vector2(0, -110)
	add_child(light)
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(UI.vignette(vp, 0.7))
	_card(ui, vp)
	Game.play_sfx("win")


func _card(ui: CanvasLayer, vp: Vector2) -> void:
	var card := UI.panel(Vector2(600, 560), 24)
	card.position = Vector2(vp.x * 0.62 - 300, (vp.y - 560) / 2)
	ui.add_child(card)
	UI.rise_in(card, 0.2, 0.7)
	var world := UI.centered(UI.text("World %s  ·  %s" % [level_id, level_name.capitalize()], 22, UI.MIST), Vector2(600, 30))
	world.position.y = 28
	card.add_child(world)
	var head := UI.heading("Course clear", 560, 40)
	head.position = Vector2(20, 60)
	card.add_child(head)

	# the three big crystals of this level, appearing one by one (dim if still hidden somewhere)
	var found: Array = Game.save.crystals.get(level_id, [])
	for i in 3:
		var gem := UI.picture(Game.texture("gem_big"), Vector2(78, 78))
		gem.position = Vector2(165 + i * 96, 140)
		gem.modulate = Color.WHITE if found.has(i) else Color(0.35, 0.4, 0.55, 0.35)
		card.add_child(gem)
		if found.has(i):
			var glow := UI.glow(70, Color(0.55, 0.9, 1.0, 0.5))
			glow.position = gem.size / 2
			glow.show_behind_parent = true
			gem.add_child(glow)
		UI.rise_in(gem, 0.6 + i * 0.25, 0.4)

	var rows := [["Gems", "0"], ["Birthday candle", "Found" if candle_found else "Still hidden"], ["Score", "0"]]
	for i in rows.size():
		var y := 250 + i * 54
		var name := UI.text(rows[i][0], 26, UI.CREAM)
		name.position = Vector2(60, y)
		card.add_child(name)
		var value := UI.text(rows[i][1], 26, UI.GOLD if i != 1 or candle_found else UI.MIST, "bold")
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size = Vector2(240, 36)
		value.position = Vector2(300, y)
		card.add_child(value)
		if i == 0:
			_gems_lbl = value
		elif i == 2:
			_score_lbl = value

	# the outfit this level unlocked
	var index: int = Game.levels.solo.map(func(l: Dictionary) -> String: return l.id).find(level_id)
	if index >= 0 and index + 1 < Game.OUTFITS.size() and not Game.OUTFITS[index + 1].get("beta", false):
		var outfit := UI.centered(UI.text("New outfit in the wardrobe:  %s" % Game.OUTFITS[index + 1].name, 22, UI.GOLD), Vector2(600, 30))
		outfit.position.y = 420
		card.add_child(outfit)
		UI.rise_in(outfit, 1.8)

	var map := UI.button("World map", "glass", 220, 60, 22)
	map.position = Vector2(60, 470)
	map.pressed.connect(func() -> void: return_to_map.emit())
	card.add_child(map)
	var next := UI.button("Continue" if level_id == "1-5" else "Next", "gold", 220, 60, 24)
	next.position = Vector2(320, 470)
	next.pressed.connect(func() -> void: next_level.emit())
	card.add_child(next)

	# count the numbers up
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_method(func(v: int) -> void: _gems_lbl.text = str(v), 0, gems_collected, 0.7)
	tw.tween_method(func(v: int) -> void: _score_lbl.text = "%06d" % v, 0, final_score, 1.0)
