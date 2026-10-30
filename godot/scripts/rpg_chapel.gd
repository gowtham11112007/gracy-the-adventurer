extends Node2D
## The birthday candles: an enchanted wood at night and five tall candles, one for each candle hidden in the
## world (the rooms marked with a candle in data/world.json).
## The candles Janani has found burn with a flickering flame (the Kenney particle pack's flame) and glow;
## the others wait, unlit. All five lit: the birthday finale is ready.

signal back_to_map

const UI := preload("res://scripts/ui.gd")


func _ready() -> void:
	var vp := get_viewport_rect().size
	var back := UI.backdrop("enchanted_wood", Color(0.62, 0.6, 0.78))
	UI.fill_screen(back, vp)
	add_child(back)
	add_child(UI.fireflies(vp, 28, Color(1.0, 0.8, 0.95)))
	var lit := 0
	var spacing := minf(220.0, (vp.x - 160) / 5.0)
	var world := preload("res://scripts/world.gd")
	var places: Array = world.rooms().filter(func(r: Dictionary) -> bool: return r.has.has("candle"))
	for i in places.size():
		var room: Dictionary = places[i]
		var on: bool = Game.save.candles.has(room.id)
		lit += 1 if on else 0
		var at := Vector2(vp.x / 2 + (i - (places.size() - 1) / 2.0) * spacing, vp.y * 0.62)
		_candle(at, on, i)
		var plate := UI.panel(Vector2(spacing - 24, 76), 16)
		plate.position = at + Vector2(-(spacing - 24) / 2, 70)
		add_child(plate)
		# where it is: the area, and the room's name once she has been there
		var area: String = world.data().areas[room.area].name
		var title := UI.centered(UI.text(area, 15, UI.GOLD if on else UI.MIST, "bold"), Vector2(plate.size.x, 26))
		title.position.y = 10
		plate.add_child(title)
		var seen: bool = Game.save.rooms_seen.has(room.id)
		var name := UI.centered(UI.text(String(room.name) if seen or on else "?", 17, UI.CREAM if on else UI.MIST), Vector2(plate.size.x, 26))
		name.position.y = 40
		plate.add_child(name)

	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(UI.vignette(vp, 0.7))
	var head := UI.heading("Birthday Candles", minf(vp.x - 200, 900), 44)
	head.position = Vector2((vp.x - head.size.x) / 2, 40)
	ui.add_child(head)
	var line := "All five candles are lit. The birthday is ready." if lit == 5 else \
		"%d of 5 lit. Look for the candle marks on the map." % lit
	var sub := UI.centered(UI.text(line, 24, UI.GOLD if lit == 5 else UI.CREAM), Vector2(vp.x, 34))
	sub.position.y = 118
	ui.add_child(sub)
	UI.rise_in(head, 0.1)
	UI.rise_in(sub, 0.4)
	var back_btn := UI.icon_button("back", 60)
	back_btn.position = Vector2(22, 22)
	back_btn.pressed.connect(func() -> void: back_to_map.emit())
	ui.add_child(back_btn)


## one tall ivory candle on a gold holder; a lit one has a flickering flame and a warm glow
func _candle(at: Vector2, on: bool, index: int) -> void:
	var c := Candle.new()
	c.lit = on
	c.position = at
	c.height = 120 + (index % 2) * 26
	add_child(c)
	if not on:
		return
	var tip := Vector2(0, -c.height - 6)
	var glow := UI.glow(150, Color(1.0, 0.75, 0.4, 0.55))
	glow.position = tip
	c.add_child(glow)
	UI.breathe(glow, 0.7, 0.6 + index * 0.07)
	var flame := Sprite2D.new()
	flame.texture = load("res://assets/fx/flame_01.png")
	flame.scale = Vector2(0.09, 0.13)
	flame.offset = Vector2(0, -180) # the flame's base sits on the wick
	flame.position = tip + Vector2(0, 8)
	flame.modulate = Color(1.0, 0.75, 0.35)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flame.material = add
	c.add_child(flame)
	var tw := flame.create_tween().set_loops() # a gentle flicker
	tw.tween_property(flame, "scale", Vector2(0.085, 0.14), 0.18 + index * 0.02)
	tw.tween_property(flame, "scale", Vector2(0.095, 0.12), 0.22)


class Candle extends Node2D:
	var lit := false
	var height := 120.0

	func _draw() -> void:
		var gold := Color("#e6c47a") if lit else Color("#7d7a8c")
		draw_set_transform(Vector2(0, 8), 0, Vector2(1, 0.3)) # the holder's dish
		draw_circle(Vector2.ZERO, 46, gold.darkened(0.35))
		draw_circle(Vector2(0, -6), 42, gold)
		draw_set_transform(Vector2.ZERO)
		var body := Color("#f6eedc") if lit else Color("#9a97a8")
		draw_rect(Rect2(-14, -height, 28, height), body)
		draw_rect(Rect2(-14, -height, 7, height), body.lightened(0.25)) # light on its left side
		draw_rect(Rect2(7, -height, 7, height), body.darkened(0.12))
		draw_line(Vector2(0, -height), Vector2(0, -height - 12), Color("#2a2420"), 3.0, true) # the wick


## Back (Esc, the phone's Back button): to the title, like the back arrow
func go_back() -> void:
	back_to_map.emit()
