extends CanvasLayer
## The world map, as an overlay: dark glass, rooms in their area's colour. Only rooms Janani has walked into are
## filled in; the unexplored rooms next to them show as a faint "?". Gold dots on the lines are doors that need an
## ability (hollow once she has it). Her room pulses. Symbols: bench, candle, shrine (a move to learn), boss.
## Open it with  var m := preload("res://scripts/map_screen.gd").new(); add_child(m)  (it frees itself on close).
## `show_all` draws every room (for testing and screenshots).

signal closed

const UI := preload("res://scripts/ui.gd")
const World := preload("res://scripts/world.gd")
const COLS := 10
const ROWS := 7

var show_all := false
var _canvas: Control


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.05, 0.88)
	dim.size = vp
	add_child(dim)
	var head := UI.heading("Map", minf(vp.x - 200, 700), 40)
	head.position = Vector2((vp.x - head.size.x) / 2, 14)
	add_child(head)
	var x := UI.icon_button("close", 60)
	x.position = Vector2(vp.x - 84, 18)
	x.pressed.connect(close)
	add_child(x)
	_canvas = MapCanvas.new()
	_canvas.position = Vector2(20, 84)
	_canvas.size = Vector2(vp.x - 40, vp.y - 100)
	_canvas.show_all = show_all
	add_child(_canvas)


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_M):
		get_viewport().set_input_as_handled()
		close()


class MapCanvas extends Control:
	var show_all := false
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _seen(id: String) -> bool:
		return show_all or Game.save.rooms_seen.has(id)

	func _draw() -> void:
		var font := UI.font("body")
		var cw := minf(size.x / COLS, 124.0)
		var ch := minf((size.y - 70) / ROWS, 76.0)
		var origin := Vector2((size.x - cw * COLS) / 2.0, 0.0)
		var center := func(id: String) -> Vector2:
			var r: Dictionary = World.room(id)
			return origin + Vector2((r.x + 0.5) * cw, (r.y + 0.5) * ch)
		var abilities: Array = Game.save.abilities if not show_all else World.data().abilities
		# the lines between rooms (and the doors on them)
		for e: Dictionary in World.edges():
			var a_seen := _seen(e.from)
			var b_seen := _seen(e.to)
			if not (a_seen or b_seen):
				continue
			var pa: Vector2 = center.call(e.from)
			var pb: Vector2 = center.call(e.to)
			var col := Color(UI.MIST, 0.7 if (a_seen and b_seen) else 0.25)
			draw_line(pa, pb, col, 3.0, true)
			if not e.gate.is_empty():
				var mid := (pa + pb) / 2.0
				var open := World.gate_open(e.gate, abilities, Game.save.candles.size())
				if open:
					draw_arc(mid, 8.0, 0, TAU, 20, UI.GOLD, 2.5, true)
				else:
					draw_circle(mid, 8.0, UI.GOLD)
		# the rooms
		for r: Dictionary in World.rooms():
			var seen := _seen(r.id)
			var near := false
			if not seen:
				for n: Dictionary in World.neighbors(r.id):
					if _seen(n.room):
						near = true
			if not (seen or near):
				continue
			var rect := Rect2(origin + Vector2(r.x * cw + 5, r.y * ch + 5), Vector2(cw - 10, ch - 10))
			var area_col := World.area_color(r.area)
			var box := StyleBoxFlat.new()
			box.set_corner_radius_all(8)
			box.anti_aliasing = true
			if seen:
				box.bg_color = UI.NIGHT.lightened(0.07).lerp(Color("#050a12"), 0.0) # solid: lines must not show through
				box.border_color = area_col
				box.set_border_width_all(3 if r.id != Game.save.room else 4)
			else:
				box.bg_color = UI.NIGHT.lerp(Color("#050a12"), 0.4) # solid too, just darker
				box.border_color = Color(area_col, 0.3)
				box.set_border_width_all(2)
			draw_style_box(box, rect)
			if not seen:
				draw_string(font, rect.position + Vector2(0, rect.size.y / 2 + 9), "?", HORIZONTAL_ALIGNMENT_CENTER,
					rect.size.x, 24, Color(area_col, 0.5))
				continue
			draw_multiline_string(font, rect.position + Vector2(6, 17), r.name, HORIZONTAL_ALIGNMENT_LEFT,
				rect.size.x - 10, 13, 2, UI.CREAM)
			# symbols along the bottom of the room
			var sx := rect.position.x + 9.0
			var sy := rect.position.y + rect.size.y - 10.0
			for item: String in r.has:
				if item == "bench":
					draw_rect(Rect2(sx - 5, sy - 4, 10, 8), UI.MIST)
				elif item == "candle":
					draw_circle(Vector2(sx, sy), 5.0, Color("#ffd34d"))
				elif item.begins_with("ability:"):
					draw_colored_polygon(PackedVector2Array([Vector2(sx, sy - 7), Vector2(sx + 6, sy + 5), Vector2(sx - 6, sy + 5)]), UI.GOLD)
				elif item == "boss":
					draw_colored_polygon(PackedVector2Array([Vector2(sx, sy - 7), Vector2(sx + 7, sy), Vector2(sx, sy + 7), Vector2(sx - 7, sy)]), Color("#e0524d"))
				else:
					continue
				sx += 18.0
			if r.id == Game.save.room: # where she is
				var pulse := 0.5 + 0.5 * sin(_time * 3.0)
				draw_rect(rect.grow(3 + pulse * 2), Color(UI.GOLD, 0.25 + 0.35 * pulse), false, 2.0)
		# the key
		var ky := size.y - 34.0
		var kx := origin.x + 6.0
		draw_rect(Rect2(kx, ky - 4, 10, 8), UI.MIST)
		draw_string(font, Vector2(kx + 16, ky + 5), "bench", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.MIST)
		draw_circle(Vector2(kx + 92, ky), 5.0, Color("#ffd34d"))
		draw_string(font, Vector2(kx + 104, ky + 5), "candle", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.MIST)
		draw_colored_polygon(PackedVector2Array([Vector2(kx + 190, ky - 7), Vector2(kx + 196, ky + 5), Vector2(kx + 184, ky + 5)]), UI.GOLD)
		draw_string(font, Vector2(kx + 204, ky + 5), "shrine", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.MIST)
		draw_circle(Vector2(kx + 288, ky), 8.0, UI.GOLD)
		draw_string(font, Vector2(kx + 302, ky + 5), "door that needs a move", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.MIST)
		var learned := "Moves:  "
		for ab: String in World.data().abilities:
			learned += "%s %s    " % [ab.replace("_", " ").capitalize(), "✓" if abilities.has(ab) else "-"]
		draw_string(font, Vector2(origin.x + size.x - 430, ky + 5), learned, HORIZONTAL_ALIGNMENT_LEFT, 420, 15, UI.GOLD)
