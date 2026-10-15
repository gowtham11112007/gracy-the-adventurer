extends CanvasLayer
## A pop-up window: the screen darkens, a glass panel with a gold-lined title rises in, and a round X closes it.
## Used for Settings and the Pause menu, and it keeps working while the game is paused.
## Set `title` and `sheet_size`, add it, then add rows to `body`.

signal closed

const UI := preload("res://scripts/ui.gd")

var title := ""
var sheet_size := Vector2(560, 420)
var can_close := true
var body: VBoxContainer
var _sheet: Control
var _dim: ColorRect


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.02, 0.05, 0.6)
	_dim.size = vp
	add_child(_dim)
	_dim.modulate.a = 0.0
	_dim.create_tween().tween_property(_dim, "modulate:a", 1.0, 0.25)

	_sheet = UI.panel(sheet_size, 22)
	_sheet.position = (vp - sheet_size) / 2
	add_child(_sheet)
	var top := 36.0
	if title:
		var h := UI.heading(title, sheet_size.x - 40, 34)
		h.position = Vector2(20, 26)
		_sheet.add_child(h)
		top = 26 + h.size.y + 18
	if can_close:
		var x := UI.icon_button("close", 52)
		x.position = Vector2(sheet_size.x - 70, 18)
		x.pressed.connect(close)
		_sheet.add_child(x)

	body = VBoxContainer.new()
	body.position = Vector2(48, top)
	body.size = Vector2(sheet_size.x - 96, sheet_size.y - top - 36)
	body.add_theme_constant_override("separation", 16)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	_sheet.add_child(body)
	UI.rise_in(_sheet, 0.0, 0.35)


func close() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(_sheet, "modulate:a", 0.0, 0.18)
	tw.tween_property(_dim, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())


## A row with a gold line icon, a word and something on the right (a switch...).
func add_row(icon: String, words: String, right: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var pic := UI.icon_button(icon, 52)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var l := UI.text(words, 28)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	body.add_child(row)


## The Music and Sounds switches (saved, and they take effect at once).
func add_audio_switches(music_track := "title") -> void:
	add_row("music", "Music", UI.switch(Game.save.get("music", true), func(on: bool) -> void:
		Game.save.music = on
		Game.write_save()
		if on:
			Game.play_music(music_track)
		else:
			Game.stop_music()))
	add_row("sound", "Sounds", UI.switch(Game.save.get("sound", true), func(on: bool) -> void:
		Game.save.sound = on
		Game.write_save()))


## A wide button across the panel.
func add_button(words: String, style: String, action: Callable) -> Button:
	var b := UI.button(words, style, sheet_size.x - 160, 62, 24)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	body.add_child(b)
	return b
