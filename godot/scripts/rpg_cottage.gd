extends Node2D
## The wardrobe: the lantern forest at night, Janani standing large in the outfit she wears with Kitty beside
## her (tap Kitty for a purr), and a glass panel of Janani's outfits. She starts in the white kurti and
## each World 1 level she clears unlocks the next one (Game.OUTFITS). The "Beta" outfit, the new detailed
## Janani being tested, is always open. Tap an outfit to wear it.

signal back_to_map

const UI := preload("res://scripts/ui.gd")
const FLOOR := 650.0

var _hero: AnimatedSprite2D
var _kitty: AnimatedSprite2D
var _cards: Array[Button] = []
var _vp: Vector2


func _ready() -> void:
	_vp = get_viewport_rect().size
	var back := UI.backdrop("lantern_forest", Color(0.78, 0.8, 0.92))
	UI.fill_screen(back, _vp)
	add_child(back)
	add_child(UI.fireflies(_vp, 26, Color(1.0, 0.85, 0.55)))
	_showcase()
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(UI.vignette(_vp, 0.65))
	_panel(ui)
	var back_btn := UI.icon_button("back", 60)
	back_btn.position = Vector2(22, 22)
	back_btn.pressed.connect(func() -> void: back_to_map.emit())
	ui.add_child(back_btn)


var _kitty_label: Label
var _kitty_chips: Array[Button] = []


func _showcase() -> void:
	var spot := Vector2(_vp.x * 0.24, FLOOR)
	var light := UI.glow(240, Color(1.0, 0.85, 0.6, 0.3))
	light.position = spot + Vector2(0, -150)
	add_child(light)
	_hero = UI.actor("janani")
	_hero.scale = Vector2(2.0, 2.0)
	_hero.position = spot
	add_child(_hero)
	_kitty = UI.actor("kitty")
	_kitty.scale = Vector2(1.2, 1.2)
	_kitty.position = spot + Vector2(150, 0)
	add_child(_kitty)

	# Coat label above Kitty
	_kitty_label = UI.centered(UI.text("", 14, UI.GOLD, "bold"), Vector2(180, 24))
	_kitty_label.position = _kitty.position + Vector2(-90, -145)
	add_child(_kitty_label)

	# Color chips for Kitty coats
	var chips_row := HBoxContainer.new()
	chips_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chips_row.add_theme_constant_override("separation", 10)
	chips_row.position = _kitty.position + Vector2(-75, 8)
	add_child(chips_row)

	for skin: Dictionary in Game.KITTY_SKINS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(28, 28)
		var style := StyleBoxFlat.new()
		style.bg_color = skin.color
		style.set_corner_radius_all(14)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = UI.GOLD if skin.id == Game.kitty_skin() else Color(0.1, 0.1, 0.15, 0.6)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.pressed.connect(func() -> void:
			_select_kitty_skin(skin.id)
			_purr())
		chips_row.add_child(btn)
		_kitty_chips.append(btn)

	_update_kitty_label()

	var pet := Button.new() # tap Kitty: she cycles coat, purrs and sparkles
	pet.flat = true
	pet.size = Vector2(130, 110)
	pet.position = _kitty.position + Vector2(-65, -105)
	pet.pressed.connect(_cycle_kitty_skin)
	add_child(pet)


func _cycle_kitty_skin() -> void:
	var cur := Game.kitty_skin()
	var idx := 0
	for i in Game.KITTY_SKINS.size():
		if Game.KITTY_SKINS[i].id == cur:
			idx = (i + 1) % Game.KITTY_SKINS.size()
			break
	_select_kitty_skin(Game.KITTY_SKINS[idx].id)
	_purr()


func _select_kitty_skin(skin_id: String) -> void:
	Game.set_kitty_skin(skin_id)
	_kitty.sprite_frames = Game.kitty_frames(skin_id)
	_kitty.play("idle")
	_update_kitty_label()
	for i in Game.KITTY_SKINS.size():
		if i < _kitty_chips.size():
			var s: Dictionary = Game.KITTY_SKINS[i]
			var active: bool = s.id == skin_id
			var style := StyleBoxFlat.new()
			style.bg_color = s.color
			style.set_corner_radius_all(14)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_color = UI.GOLD if active else Color(0.1, 0.1, 0.15, 0.6)
			_kitty_chips[i].add_theme_stylebox_override("normal", style)
			_kitty_chips[i].add_theme_stylebox_override("hover", style)
			_kitty_chips[i].add_theme_stylebox_override("pressed", style)


func _update_kitty_label() -> void:
	if not _kitty_label:
		return
	var cur := Game.kitty_skin()
	for s: Dictionary in Game.KITTY_SKINS:
		if s.id == cur:
			_kitty_label.text = s.name
			break


func _purr() -> void:
	Game.play_sfx("meow")
	for i in 6:
		var spark := UI.glow(18, Color(1.0, 0.9, 0.6, 0.9))
		spark.position = _kitty.position + Vector2(randf_range(-40, 40), -60)
		add_child(spark)
		var tw := spark.create_tween().set_parallel()
		tw.tween_property(spark, "position:y", spark.position.y - randf_range(60, 110), 0.9)
		tw.tween_property(spark, "modulate:a", 0.0, 0.9)
		tw.chain().tween_callback(spark.queue_free)


func _panel(ui: CanvasLayer) -> void:
	var w := 650.0
	var h := 600.0
	var panel := UI.panel(Vector2(w, h), 24)
	panel.position = Vector2(_vp.x - w - 40, (_vp.y - h) / 2)
	ui.add_child(panel)
	UI.rise_in(panel, 0.1, 0.6)
	var head := UI.heading("Wardrobe", w - 40, 38)
	head.position = Vector2(20, 22)
	panel.add_child(head)
	for i in Game.OUTFITS.size():
		var outfit: Dictionary = Game.OUTFITS[i]
		var beta: bool = outfit.get("beta", false)
		var card_w := 160.0 if Game.OUTFITS.size() == 1 else 136.0
		var card_h := 240.0 if Game.OUTFITS.size() == 1 else 226.0
		var card := UI.button("", "glass", int(card_w), int(card_h), 18)
		if Game.OUTFITS.size() == 1:
			card.position = Vector2((w - card_w) / 2.0, 140.0)
		else:
			card.position = Vector2(30 + (i % 4) * 148, 98 + (i / 4) * 240)
		panel.add_child(card)
		_cards.append(card)
		var look := UI.picture(Game.outfit_picture(outfit.id), Vector2(104, 150))
		look.position = Vector2((card_w - 104) / 2.0, 18)
		card.add_child(look)
		var name := UI.centered(UI.text(outfit.name, 18, UI.GOLD, "bold"), Vector2(card_w, 26))
		name.position.y = 172
		card.add_child(name)
		var desc := UI.centered(UI.text(outfit.get("desc", ""), 13, UI.MIST), Vector2(card_w - 8, 34))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.position = Vector2(4, 194)
		card.add_child(desc)
		var id: String = outfit.id
		card.pressed.connect(func() -> void: _wear(id))
	_mark_worn()


func _wear(id: String) -> void:
	Game.save.outfit = id
	Game.write_save()
	var at := _hero.position
	var size := _hero.scale
	_hero.queue_free()
	_hero = UI.actor("janani")
	_hero.position = at
	_hero.scale = size
	add_child(_hero)
	_hero.play("victory")
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if is_instance_valid(_hero):
			_hero.play("idle"))
	_mark_worn()


## a gold edge around the outfit she's wearing
func _mark_worn() -> void:
	var worn := Game.outfit()
	for i in _cards.size():
		var s: StyleBoxFlat = UI.glass(36, 0.6, UI.GOLD if Game.OUTFITS[i].id == worn else UI.GOLD_DIM)
		s.set_border_width_all(3 if Game.OUTFITS[i].id == worn else 2)
		_cards[i].add_theme_stylebox_override("normal", s)


## Back (Esc, the phone's Back button): to the title, like the back arrow
func go_back() -> void:
	back_to_map.emit()
