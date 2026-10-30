extends Node2D
## The story scenes, in the painted forest of Sunny Meadow, with a glass dialogue box along the bottom.
## - "intro": a walk two days before the birthday; Yuva takes Janika away in a bubble; Janani's promise.
## - "world1end": Yuva beaten, the bubble bursts, the twins' hug, and then Yuva takes Kitty.

signal finished(mode: String)

const UI := preload("res://scripts/ui.gd")
const TILE := 64

var mode := "intro"
var _step := 0
var _busy := false
var _ended := false
var _steps: Array[Callable] = []

var _actors: Dictionary = {}
var _dialogue_box: Control
var _portrait: TextureRect
var _name_lbl: Label
var _text_lbl: Label
var _bubble_node: Node2D
var _hug_sprite: Sprite2D


func _ready() -> void:
	var vp_size := get_viewport_rect().size
	_build_scene_backdrop(vp_size)
	_build_dialogue_ui(vp_size)

	if mode == "intro":
		_setup_intro(vp_size)
	else:
		_setup_world1end(vp_size)

	_run_next()


# ------------------------------------------------------------- backdrop ---

## The same painted forest and ground as Sunny Meadow (the meadow skin), in warm late light.
func _build_scene_backdrop(vp_size: Vector2) -> void:
	for i in 3:
		var layer := Sprite2D.new()
		layer.texture = Game.texture("skins/meadow/bg_%d" % i)
		layer.centered = false
		add_child(layer)
	var ground_y := vp_size.y - 160.0
	for x in range(0, int(vp_size.x) + TILE, TILE):
		for row in 3: # grass on top, earth below
			var g := Sprite2D.new()
			g.texture = Game.texture("skins/meadow/tile_%d" % (2 if row == 0 else 5))
			g.centered = false
			g.position = Vector2(x, ground_y - 15 + row * TILE)
			add_child(g)
	var grade := CanvasModulate.new()
	grade.color = Color(1.0, 0.92, 0.84)
	add_child(grade)
	var over := CanvasLayer.new()
	over.layer = 5
	add_child(over)
	over.add_child(UI.light_rays(vp_size, Color(1.0, 0.85, 0.55, 0.3)))
	over.add_child(UI.fireflies(vp_size, 18, Color(1.0, 0.9, 0.6)))
	over.add_child(UI.vignette(vp_size, 0.6))


func _build_dialogue_ui(vp_size: Vector2) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	# taps anywhere move the story on (behind the buttons)
	var clicker := Button.new()
	clicker.flat = true
	clicker.size = vp_size
	clicker.pressed.connect(_on_tap)
	canvas.add_child(clicker)

	var skip := UI.button("Skip", "glass", 120, 50, 20)
	skip.position = Vector2(vp_size.x - 150, 22)
	skip.pressed.connect(_finish_cutscene)
	canvas.add_child(skip)

	# the glass dialogue box along the bottom: portrait, name in gold capitals, the line
	_dialogue_box = UI.panel(Vector2(minf(vp_size.x - 80, 1100), 150), 22)
	_dialogue_box.position = Vector2((vp_size.x - _dialogue_box.size.x) / 2, vp_size.y - 172)
	_dialogue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_box.visible = false
	canvas.add_child(_dialogue_box)
	_portrait = UI.picture(null, Vector2(112, 112))
	_portrait.position = Vector2(22, 19)
	_dialogue_box.add_child(_portrait)
	_name_lbl = UI.title("", 26)
	_name_lbl.position = Vector2(156, 18)
	_dialogue_box.add_child(_name_lbl)
	_text_lbl = UI.text("", 26, UI.CREAM)
	_text_lbl.position = Vector2(156, 56)
	_text_lbl.size = Vector2(_dialogue_box.size.x - 190, 80)
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_box.add_child(_text_lbl)
	var more := UI.text("tap to continue", 16, UI.MIST)
	more.position = Vector2(_dialogue_box.size.x - 150, _dialogue_box.size.y - 30)
	_dialogue_box.add_child(more)
	UI.breathe(more, 0.3, 0.9)


var _typing: Tween

func _say(speaker_key: String, speaker_name: String, text: String) -> void:
	_portrait.texture = Game.texture("portrait_" + speaker_key)
	_name_lbl.text = speaker_name.to_upper()
	_text_lbl.text = text
	_text_lbl.visible_ratio = 0.0
	if not _dialogue_box.visible:
		_dialogue_box.visible = true
		UI.rise_in(_dialogue_box, 0.0, 0.3)
	if _typing:
		_typing.kill()
	_typing = create_tween() # the line writes itself out
	_typing.tween_property(_text_lbl, "visible_ratio", 1.0, text.length() * 0.025)
	Game.play_sfx("select")


## a tap finishes the line being written, or moves on to the next one
func _on_tap() -> void:
	if _busy or not _dialogue_box.visible:
		return
	if _text_lbl.visible_ratio < 1.0:
		_typing.kill()
		_text_lbl.visible_ratio = 1.0
		return
	_run_next()


func _run_next() -> void:
	if _step >= _steps.size():
		_finish_cutscene()
		return
	var cur_step: Callable = _steps[_step]
	_step += 1
	cur_step.call()


## Back (Esc, the phone's Back button): skips the scene, like the Skip button
func go_back() -> void:
	_finish_cutscene()


## Janika as tall as her twin: Janani is drawn 1.2x; the detailed Janani stands 168 px, Janika's picture 128 px
func _twin_scale() -> float:
	return 1.2 * (168.0 if Game.hd.has(Game.outfit()) else 128.0) / 128.0


func _finish_cutscene() -> void:
	if _ended: # (Skip and Back pressed together must not start the next screen twice)
		return
	_ended = true
	finished.emit(mode)


# ------------------------------------------------------------- INTRO SCENE ---

func _setup_intro(vp_size: Vector2) -> void:
	var gy := vp_size.y - 175.0
	# Actors
	var janani := UI.actor("janani") # in the outfit she wears (the Beta outfit too)
	janani.position = Vector2(-80, gy)
	janani.scale = Vector2(1.2, 1.2)
	add_child(janani)
	_actors["janani"] = janani

	var janika := AnimatedSprite2D.new()
	janika.sprite_frames = Game.sprite_frames({
		"idle": ["twin", [0, 1, 2, 1, 0, 0, 3, 0, 1, 2, 1, 4], 4, true],
		"walk": ["twin", [1, 2, 3, 4], 8, true]
	})
	janika.centered = false
	janika.offset = Vector2(-52, -150)
	janika.position = Vector2(-180, gy)
	janika.scale = Vector2.ONE * _twin_scale()
	add_child(janika)
	_actors["janika"] = janika

	var kitty := UI.actor("kitty")
	kitty.position = Vector2(-270, gy)
	add_child(kitty)
	_actors["kitty"] = kitty

	var yuva := AnimatedSprite2D.new()
	yuva.sprite_frames = Game.sprite_frames({
		"hover": ["boss", [0, 1, 2, 1], 4, true]
	})
	yuva.centered = false
	yuva.offset = Vector2(-105, -190)
	yuva.position = Vector2(vp_size.x + 180, gy - 260)
	yuva.scale = Vector2(0.9, 0.9)
	yuva.flip_h = true
	add_child(yuva)
	_actors["yuva"] = yuva

	# Intro Step Sequence
	_steps = [
		# 0. Walk in
		func() -> void:
			_busy = true
			janani.play("walk")
			janika.play("walk")
			kitty.play("walk")
			var tw := create_tween()
			tw.parallel().tween_property(janani, "position:x", vp_size.x * 0.45, 2.5)
			tw.parallel().tween_property(janika, "position:x", vp_size.x * 0.32, 2.5)
			tw.parallel().tween_property(kitty, "position:x", vp_size.x * 0.18, 2.5)
			tw.tween_callback(func() -> void:
				janani.play("idle")
				janika.play("idle")
				kitty.play("idle")
				_busy = false
				_run_next()),

		# 1. Janika speaks
		func() -> void:
			_say("janika", "Janika", "Look at this light, Janani. Two days to our birthday, and the whole valley feels like it's celebrating with us."),

		# 2. Janani replies
		func() -> void:
			_say("janani", "Janani", "Then let's make the most of it. Nothing is going to spoil today."),

		# 3. Thunder and Yuva arrives!
		func() -> void:
			_dialogue_box.visible = false
			_busy = true
			Game.play_sfx("thunder")
			var flash := ColorRect.new()
			flash.color = Color.WHITE
			flash.size = vp_size
			add_child(flash)
			var ftw := create_tween()
			ftw.tween_property(flash, "modulate:a", 0.0, 0.4)
			ftw.tween_callback(flash.queue_free)

			# Yuva dives in
			yuva.play("hover")
			var y_tw := create_tween()
			y_tw.tween_property(yuva, "position", Vector2(vp_size.x * 0.68, gy - 40), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			y_tw.tween_callback(func() -> void:
				Game.play_sfx("stomp")
				_busy = false
				_run_next()),

		# 4. Yuva speaks
		func() -> void:
			_say("yuva", "Yuva", "Nothing? How very optimistic of you."),

		# 5. Yuva demands
		func() -> void:
			_say("yuva", "Yuva", "I'll be borrowing your sister for a while. If you want her back, come and find me. If you can."),

		# 6. Yuva traps Janika in bubble!
		func() -> void:
			_dialogue_box.visible = false
			_busy = true
			Game.play_sfx("whoosh")
			var tw := create_tween()
			tw.tween_property(yuva, "position", Vector2(janika.position.x + 90, gy - 120), 0.4)
			tw.tween_callback(func() -> void:
				# Attach bubble to Janika
				_bubble_node = UI.bubble(68)
				_bubble_node.position = Vector2(0, -60)
				janika.add_child(_bubble_node)
				Game.play_sfx("power")
				var b_tw := create_tween()
				b_tw.parallel().tween_property(janika, "position:y", gy - 110, 0.5).set_trans(Tween.TRANS_SINE)
				b_tw.parallel().tween_property(yuva, "position:y", gy - 160, 0.5)
				b_tw.tween_callback(func() -> void:
					_busy = false
					_run_next())),

		# 7. Janika cries for help
		func() -> void:
			_say("janika", "Janika", "Janani! Don't you dare give up on me!"),

		# 8. Yuva flies away with Janika
		func() -> void:
			_dialogue_box.visible = false
			_busy = true
			Game.play_sfx("whoosh")
			var tw := create_tween()
			tw.parallel().tween_property(yuva, "position:x", vp_size.x + 300, 1.4)
			tw.parallel().tween_property(yuva, "position:y", gy - 320, 1.4)
			tw.parallel().tween_property(janika, "position:x", vp_size.x + 200, 1.4)
			tw.parallel().tween_property(janika, "position:y", gy - 270, 1.4)
			tw.tween_callback(func() -> void:
				_busy = false
				_run_next()),

		# 9. Kitty meows
		func() -> void:
			Game.play_sfx("meow")
			_say("kitty", "Kitty", "Mrrrow."),

		# 10. Janani resolves
		func() -> void:
			_say("janani", "Janani", "Hold on, Janika. Kitty and I are coming, all the way to his castle if we have to.")
	]


# ------------------------------------------------------------- WORLD 1 END ---

func _setup_world1end(vp_size: Vector2) -> void:
	var gy := vp_size.y - 175.0
	var janani := UI.actor("janani") # in the outfit she wears (the Beta outfit too)
	janani.position = Vector2(vp_size.x * 0.32, gy)
	janani.scale = Vector2(1.2, 1.2)
	add_child(janani)
	_actors["janani"] = janani

	var janika := AnimatedSprite2D.new()
	janika.sprite_frames = Game.sprite_frames({
		"idle": ["twin", [0, 1, 2, 1, 0, 0, 3, 0, 1, 2, 1, 4], 4, true],
		"walk": ["twin", [1, 2, 3, 4], 8, true]
	})
	janika.centered = false
	janika.offset = Vector2(-52, -150)
	janika.position = Vector2(vp_size.x * 0.62, gy - 110)
	janika.scale = Vector2.ONE * _twin_scale()
	add_child(janika)
	_actors["janika"] = janika

	_bubble_node = UI.bubble(68)
	_bubble_node.position = Vector2(0, -75)
	janika.add_child(_bubble_node)

	var yuva := AnimatedSprite2D.new()
	yuva.sprite_frames = Game.sprite_frames({
		"dizzy": ["boss", [7], 1, false]
	})
	yuva.centered = false
	yuva.offset = Vector2(-105, -190)
	yuva.position = Vector2(vp_size.x * 0.78, gy)
	yuva.scale = Vector2(0.85, 0.85)
	yuva.flip_h = true
	yuva.play("dizzy")
	add_child(yuva)
	_actors["yuva"] = yuva

	var kitty := UI.actor("kitty")
	kitty.position = Vector2(vp_size.x * 0.18, gy)
	add_child(kitty)
	_actors["kitty"] = kitty

	_steps = [
		func() -> void:
			_say("yuva", "Yuva", "Alright, alright! You win. I never thought you'd make it this far."),

		func() -> void:
			_say("janani", "Janani", "Let her go, Yuva. Now."),

		# Pop bubble
		func() -> void:
			_dialogue_box.visible = false
			_busy = true
			Game.play_sfx("smash")
			_bubble_node.queue_free()
			var tw := create_tween()
			tw.tween_property(janika, "position:y", gy, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func() -> void:
				_busy = false
				_run_next()),

		func() -> void:
			_say("janika", "Janika", "I knew you'd come. You always do."),

		# Twin hug!
		func() -> void:
			_dialogue_box.visible = false
			_busy = true
			janani.play("run")
			janika.play("walk")
			var tw := create_tween()
			tw.parallel().tween_property(janani, "position:x", vp_size.x * 0.46, 0.5)
			tw.parallel().tween_property(janika, "position:x", vp_size.x * 0.52, 0.5)
			tw.tween_callback(func() -> void:
				janani.visible = false
				janika.visible = false
				_hug_sprite = Sprite2D.new()
				_hug_sprite.texture = Game.frame("hug", 0)
				_hug_sprite.position = Vector2(vp_size.x * 0.49, gy)
				_hug_sprite.scale = Vector2(1.2, 1.2)
				add_child(_hug_sprite)
				Game.play_sfx("win")
				_busy = false
				_run_next()),

		func() -> void:
			_say("janani", "Janani & Janika", "Happy birthday to us. Together, the way it should be."),

		# Yuva grabs Kitty cliffhanger
		func() -> void:
			_dialogue_box.visible = false
			_busy = true
			Game.play_sfx("whoosh")
			var tw := create_tween()
			tw.tween_property(yuva, "position", kitty.position + Vector2(40, -40), 0.5)
			tw.tween_callback(func() -> void:
				Game.play_sfx("meow")
				var b_tw := create_tween()
				b_tw.parallel().tween_property(yuva, "position:x", vp_size.x + 200, 1.0)
				b_tw.parallel().tween_property(kitty, "position:x", vp_size.x + 180, 1.0)
				b_tw.tween_callback(func() -> void:
					_busy = false
					_run_next())),

		func() -> void:
			_say("janani", "Janani", "He's taken Kitty! Janika, this time we go after him together.")
	]
