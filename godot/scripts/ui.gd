extends RefCounted
## The look shared by every screen: magical and cinematic. Dark glass panels with thin gold lines, carved
## Cinzel titles over clean Nunito text, line-drawn icons, and the atmosphere (fireflies, drifting fog,
## light rays, soft glows, a dark vignette) over layered forest backgrounds (assets/backdrops, made by
## tools/prepare_gui.py). Use it as  const UI := preload("res://scripts/ui.gd")

const GOLD := Color("#e6c47a")
const GOLD_DIM := Color(0.9, 0.77, 0.48, 0.55)
const CREAM := Color("#f4ead2")
const MIST := Color("#a9c4d4")       ## quiet secondary text
const NIGHT := Color("#0a1320")      ## the glass colour
const GLOW_TEAL := Color("#7ff0e0")

static var _fonts := {}


## "title" (Cinzel, carved capitals), "body" (Nunito, easy to read) or "bold" (Nunito, heavier).
static func font(kind := "body") -> Font:
	if not _fonts.has(kind):
		var f := FontVariation.new()
		f.base_font = load("res://fonts/cinzel.ttf" if kind == "title" else "res://fonts/nunito.ttf")
		var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
		f.variation_opentype = { wght: { "title": 700, "body": 600, "bold": 800 }[kind] }
		if kind == "title":
			f.spacing_glyph = 2 # carved capitals look best a little apart
		_fonts[kind] = f
	return _fonts[kind]


## Text with a soft dark shadow underneath, so it reads over any background.
static func text(t: String, size := 28, color := CREAM, kind := "body") -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", maxi(4, size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A title in carved gold capitals.
static func title(t: String, size := 44, color := GOLD) -> Label:
	return text(t.to_upper(), size, color, "title")


## Text centred inside a box.
static func centered(l: Label, box: Vector2) -> Label:
	l.size = box
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## The dark glass look: translucent night blue, a thin gold edge, rounded corners and a soft shadow.
static func glass(radius := 18, alpha := 0.78, border := GOLD_DIM) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(NIGHT, alpha)
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 16
	s.shadow_offset = Vector2(0, 6)
	s.anti_aliasing = true
	return s


## A glass panel.
static func panel(size: Vector2, radius := 18) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", glass(radius))
	p.size = size
	return p


## A button with words. "gold" is the main action (solid gold, dark letters); "glass" is everything else.
static func button(t: String, style := "glass", width := 260.0, height := 64.0, size := 24) -> Button:
	var b := Button.new()
	b.text = t.to_upper()
	b.focus_mode = Control.FOCUS_NONE
	var r := int(height / 2)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s: StyleBoxFlat
		if style == "gold":
			s = glass(r, 1.0, Color(1, 0.93, 0.75, 0.9))
			s.bg_color = { "normal": GOLD, "hover": GOLD.lightened(0.15), "pressed": GOLD.darkened(0.15), "disabled": Color(GOLD.darkened(0.4), 0.6) }[state]
		else:
			s = glass(r, 0.6)
			if state == "hover":
				s.border_color = GOLD
				s.bg_color = Color(NIGHT.lightened(0.08), 0.7)
			elif state == "pressed":
				s.bg_color = Color(NIGHT, 0.9)
		s.shadow_size = 10
		b.add_theme_stylebox_override(state, s)
	b.add_theme_font_override("font", font("title"))
	b.add_theme_font_size_override("font_size", size)
	var ink := NIGHT if style == "gold" else CREAM
	for c in ["font_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_hover_color", NIGHT if style == "gold" else GOLD)
	b.size = Vector2(width, height)
	b.custom_minimum_size = b.size
	soft_press(b)
	return b


## A words-only menu entry (like Hollow Knight's menus): cream, turning gold with small diamonds on both sides
## when the finger or mouse is on it.
static func menu_item(t: String, size := 34) -> Button:
	var b := MenuItem.new()
	b.text = t.to_upper()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font("title"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	b.add_theme_constant_override("shadow_offset_y", 3)
	b.add_theme_constant_override("shadow_outline_size", 6)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	soft_press(b)
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	return b


class MenuItem extends Button:
	var lit := false: ## shown with its diamonds (the chosen entry)
		set(v):
			lit = v
			queue_redraw()

	func _draw() -> void:
		if not (lit or is_hovered()):
			return
		var font_size := get_theme_font_size("font_size")
		var w := get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var cy := size.y / 2
		for side in [-1, 1]:
			var x: float = size.x / 2 + side * (w / 2 + 26)
			var d := 7.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, cy - d), Vector2(x + d, cy), Vector2(x, cy + d), Vector2(x - d, cy)]), GOLD)
			draw_line(Vector2(x + side * 12, cy), Vector2(x + side * 46, cy), GOLD_DIM, 2.0, true)


## A round glass button with a line-drawn gold icon: play, pause, back, close, settings, restart, home,
## music, sound, next.
static func icon_button(icon: String, size := 64.0) -> Button:
	var b := IconButton.new()
	b.icon_name = icon
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		var s := glass(int(size / 2), 0.65 if state != "pressed" else 0.9, GOLD if state == "hover" else GOLD_DIM)
		s.shadow_size = 8
		b.add_theme_stylebox_override(state, s)
	b.size = Vector2(size, size)
	b.custom_minimum_size = b.size
	soft_press(b)
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	return b


class IconButton extends Button:
	var icon_name := ""

	func _draw() -> void:
		var c := size / 2
		var k := size.x / 64.0 # icons are drawn for a 64 px button
		var col := GOLD if is_hovered() else CREAM
		var w := 3.0 * k
		var p := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * k
		match icon_name:
			"play":
				draw_colored_polygon(PackedVector2Array([p.call(-8, -13), p.call(14, 0), p.call(-8, 13)]), col)
			"pause":
				draw_rect(Rect2(p.call(-11, -12), Vector2(7, 24) * k), col)
				draw_rect(Rect2(p.call(4, -12), Vector2(7, 24) * k), col)
			"back", "next":
				var s := -1.0 if icon_name == "back" else 1.0
				draw_polyline(PackedVector2Array([p.call(-5 * s, -12), p.call(7 * s, 0), p.call(-5 * s, 12)]), col, w, true)
			"close":
				draw_line(p.call(-10, -10), p.call(10, 10), col, w, true)
				draw_line(p.call(10, -10), p.call(-10, 10), col, w, true)
			"settings":
				for i in 8:
					var a := i * TAU / 8
					draw_line(c + Vector2.from_angle(a) * 11 * k, c + Vector2.from_angle(a) * 17 * k, col, 5 * k, true)
				draw_arc(c, 11 * k, 0, TAU, 32, col, w, true)
				draw_arc(c, 4.5 * k, 0, TAU, 16, col, w, true)
			"restart":
				draw_arc(c, 12 * k, -PI * 0.35, PI * 1.45, 32, col, w, true)
				var tip: Vector2 = c + Vector2.from_angle(-PI * 0.35) * 12 * k
				draw_colored_polygon(PackedVector2Array([tip + Vector2(-2, -8) * k, tip + Vector2(8, 1) * k, tip + Vector2(-4, 6) * k]), col)
			"home":
				draw_polyline(PackedVector2Array([p.call(-13, 0), p.call(0, -12), p.call(13, 0)]), col, w, true)
				draw_polyline(PackedVector2Array([p.call(-9, -2), p.call(-9, 12), p.call(9, 12), p.call(9, -2)]), col, w, true)
			"music":
				draw_line(p.call(-4, 9), p.call(-4, -12), col, w, true)
				draw_line(p.call(-4, -12), p.call(10, -15), col, w, true)
				draw_line(p.call(10, -15), p.call(10, 6), col, w, true)
				draw_circle(p.call(-8, 10), 5 * k, col)
				draw_circle(p.call(6, 7), 5 * k, col)
			"sound":
				draw_colored_polygon(PackedVector2Array([p.call(-13, -5), p.call(-6, -5), p.call(2, -12), p.call(2, 12), p.call(-6, 5), p.call(-13, 5)]), col)
				draw_arc(p.call(2, 0), 8 * k, -PI / 3, PI / 3, 12, col, w, true)
				draw_arc(p.call(2, 0), 14 * k, -PI / 3, PI / 3, 12, col, w, true)


## Buttons ease down a little when pressed and back up, with a soft click: they feel solid, not toy-like.
static func soft_press(b: BaseButton) -> void:
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2)
	b.pivot_offset = b.size / 2
	b.button_down.connect(func() -> void:
		b.create_tween().tween_property(b, "scale", Vector2(0.95, 0.95), 0.08))
	b.button_up.connect(func() -> void:
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE))
	b.pressed.connect(func() -> void: Game.play_sfx("select"))


## A heading with thin gold lines and diamonds on both sides:  ——◆  TITLE  ◆——
static func heading(t: String, width: float, size := 36) -> Control:
	var h := Ornament.new()
	h.size = Vector2(width, size * 1.6)
	var l := centered(title(t, size), h.size)
	h.add_child(l)
	h.text_width = l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return h


class Ornament extends Control:
	var text_width := 200.0

	func _draw() -> void:
		var cy := size.y / 2
		var inner := text_width / 2 + 26
		var outer := minf(size.x / 2 - 6, inner + 150)
		for side in [-1, 1]:
			var x: float = size.x / 2 + side * inner
			var d := 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, cy - d), Vector2(x + d, cy), Vector2(x, cy + d), Vector2(x - d, cy)]), GOLD)
			draw_line(Vector2(x + side * 10, cy), Vector2(size.x / 2 + side * outer, cy), GOLD_DIM, 2.0, true)


## An ON/OFF switch: a glass track with a gold knob that slides across. `changed` gets the new value.
static func switch(on: bool, changed: Callable) -> Button:
	var b := Switch.new()
	b.toggle_mode = true
	b.button_pressed = on
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(96, 48)
	b.size = b.custom_minimum_size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.toggled.connect(func(v: bool) -> void:
		Game.play_sfx("select")
		b.slide(v)
		changed.call(v))
	return b


class Switch extends Button:
	var knob := -1.0 ## 0 off, 1 on

	func _ready() -> void:
		knob = 1.0 if button_pressed else 0.0

	func slide(on: bool) -> void:
		create_tween().tween_property(self, "knob", 1.0 if on else 0.0, 0.18).set_trans(Tween.TRANS_SINE)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := size.y / 2
		var track := StyleBoxFlat.new()
		track.bg_color = Color(GOLD, 0.35 * knob) + Color(NIGHT, 0.8 * (1.0 - knob))
		track.border_color = GOLD_DIM.lerp(GOLD, knob)
		track.set_border_width_all(2)
		track.set_corner_radius_all(int(r))
		track.anti_aliasing = true
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		var x := lerpf(r, size.x - r, knob)
		draw_circle(Vector2(x, r), r - 7, MIST.lerp(GOLD, knob))


## A picture as a Control (icons inside panels).
static func picture(t: Texture2D, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Fades something in while it rises a little into place (panels, buttons, titles appearing).
static func rise_in(c: CanvasItem, delay := 0.0, seconds := 0.6) -> void:
	var to: Vector2 = c.position
	c.position = to + Vector2(0, 24)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "position", to, seconds).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, seconds).set_delay(delay)


## Floats a node slowly up and down forever.
static func bob(n: CanvasItem, height := 6.0, seconds := 2.2) -> void:
	var y: float = n.position.y
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "position:y", y - height, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(n, "position:y", y + height, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Makes something breathe: its brightness rises and falls slowly (the button to press next, glows).
static func breathe(n: CanvasItem, low := 0.75, seconds := 1.4) -> void:
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "modulate:a", low, seconds).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "modulate:a", 1.0, seconds).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------------ characters ---

## A character for menu screens, standing with its feet on its position:
## "janani" (in her chosen outfit), "janika", "kitty" or "yuva". Animations: idle, walk/run, victory.
static func actor(who: String) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.centered = false # the offsets below put the feet on the position
	match who:
		"janani":
			var outfit := Game.outfit()
			var detailed := Game.detailed_frames(outfit) # the Beta outfit: the new detailed Janani
			if detailed:
				var cell: int = Game.hd[outfit].cell
				a.sprite_frames = detailed
				a.offset = Vector2(-cell / 2.0, -cell)
			else:
				var hero := "hero_" + outfit
				a.sprite_frames = Game.sprite_frames({
					"idle": [hero, [0, 0, 0, 0, 1, 0, 0, 2], 4, true],
					"walk": [hero, [7, 8, 9, 10], 8, true],
					"run": [hero + "_moves", range(6), 14, true],
					"victory": [hero, [15], 1, false],
				})
				a.offset = Vector2(-52, -150)
		"janika":
			a.sprite_frames = Game.sprite_frames({
				"idle": ["twin", [0, 1, 2, 1, 0, 0, 3, 0, 1, 2, 1, 4], 4, true],
				"walk": ["hero_janika_moves", range(6), 10, true],
				"victory": ["twin", [9], 1, false],
			})
			a.offset = Vector2(-52, -150)
		"kitty":
			a.sprite_frames = Game.kitty_frames()
			a.offset = Vector2(-64, -128)
		"yuva":
			a.sprite_frames = Game.sprite_frames({
				"idle": ["boss", [0, 1], 2, true],
				"dizzy": ["boss", [7], 1, false],
			})
			a.offset = Vector2(-105, -190)
	a.play("idle")
	return a


## Janika's prison: a softly glowing magic bubble.
static func bubble(radius := 70.0) -> Node2D:
	var b := Bubble.new()
	b.radius = radius
	b.add_child(glow(radius * 1.6, Color(1.0, 0.55, 0.85, 0.5)))
	return b


class Bubble extends Node2D:
	var radius := 70.0

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.6, 0.9, 0.16))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1.0, 0.85, 0.95, 0.75), 2.5, true)
		draw_arc(Vector2.ZERO, radius - 6, PI * 1.1, PI * 1.45, 16, Color(1, 1, 1, 0.6), 3.0, true)


# ------------------------------------------------------------------ atmosphere ---

static var _soft: GradientTexture2D


## A soft round light texture (white in the middle, fading to nothing).
static func soft_light() -> GradientTexture2D:
	if not _soft:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 128
		_soft.height = 128
	return _soft


## A glow: light added on top of what's behind it (gems, candles, lanterns, the bubble).
static func glow(radius: float, color: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = soft_light()
	s.scale = Vector2.ONE * radius / 64.0
	s.modulate = color
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	return s


## Fireflies drifting and twinkling over an area.
static func fireflies(area: Vector2, count := 40, color := Color(0.75, 1.0, 0.7)) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = area / 2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area / 2
	p.amount = count
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.gravity = Vector2(0, -6)
	p.direction = Vector2(1, -0.3)
	p.spread = 180
	p.initial_velocity_min = 4
	p.initial_velocity_max = 18
	p.texture = soft_light()
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.16
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0))
	ramp.add_point(0.2, Color(color, 1))
	ramp.add_point(0.5, Color(color, 0.25))
	ramp.add_point(0.75, Color(color, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(color, 0))
	p.color_ramp = ramp
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	return p


## Soft fog drifting slowly across the bottom of the screen.
static func fog(area: Vector2, color := Color(0.6, 0.85, 0.9, 0.16), y := 0.8) -> Node2D:
	var holder := Node2D.new()
	for i in 5:
		var s := Sprite2D.new()
		s.texture = soft_light()
		s.scale = Vector2(area.x / 128.0 * 0.7, area.y / 128.0 * 0.28)
		s.modulate = color
		s.position = Vector2(area.x * (i / 4.0), area.y * y + randf_range(-30, 30))
		holder.add_child(s)
		var tw := s.create_tween().set_loops()
		var drift := randf_range(80, 160)
		tw.tween_property(s, "position:x", s.position.x + drift, randf_range(9, 14)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "position:x", s.position.x, randf_range(9, 14)).set_trans(Tween.TRANS_SINE)
	return holder


## Shafts of light falling through the trees and shimmering (shaders/god_rays.gdshader). `color`'s alpha is
## how strong they are.
static func light_rays(area: Vector2, color := Color(0.8, 1.0, 0.9, 0.35), angle := -0.3) -> ColorRect:
	var r := ColorRect.new()
	r.size = area
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/god_rays.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("ray_angle", angle)
	m.set_shader_parameter("speed", 0.6)
	r.material = m
	return r


## Darkens the edges of the screen, like a film camera, which pulls the eye to the middle.
static func vignette(area: Vector2, strength := 0.6) -> ColorRect:
	var v := ColorRect.new()
	v.size = area
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.6;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.8);
	COLOR = vec4(0.0, 0.02, 0.05, smoothstep(0.32, 0.8, length(d)) * strength);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("strength", strength)
	v.material = mat
	return v


## Stretches a full-screen picture (made for 1280x720) to fill the screen, which on wide phones is wider.
static func fill_screen(n: Node2D, vp: Vector2) -> void:
	n.scale = Vector2(vp.x / 1280.0, vp.y / 720.0)


## A screen background from assets/backdrops/<name>, layer by layer. The layers sway a little, the far
## ones less than the near ones, so the picture has depth. `tint` darkens and colours it (moonlight blue...).
static func backdrop(name: String, tint := Color.WHITE) -> Node2D:
	var b := Backdrop.new()
	b.modulate = tint
	var i := 0
	while ResourceLoader.exists("res://assets/backdrops/%s/%d.png" % [name, i]):
		b.add_layer(load("res://assets/backdrops/%s/%d.png" % [name, i]))
		i += 1
	return b


class Backdrop extends Node2D:
	var _layers: Array[Node2D] = []
	var _time := 0.0

	func add_layer(t: Texture2D) -> void:
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		add_child(s)
		_layers.append(s)

	func _process(delta: float) -> void:
		_time += delta
		var count := maxf(1.0, _layers.size() - 1.0)
		for i in _layers.size():
			var k := i / count # 0 = far away, 1 = nearest
			var s := _layers[i]
			s.position.x = (sin(_time * 0.25) - 1.0) * 12.0 * k
			s.scale = Vector2.ONE * (1.0 + 0.02 * k) # the near layers a touch bigger, so the sway never shows an edge
