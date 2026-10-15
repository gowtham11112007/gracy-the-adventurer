extends Node2D
## Doors that lead somewhere else, and notice boards (1-4's trick: "DON'T BELIEVE EVERYTHING...").
## doors: [column, row she stands on, label, column she comes out at]; signs: [column, row, text]

const TILE := 64
const GROUND_Y := 10 * TILE

var level: Node2D
var _doors: Array[Dictionary] = []
var _busy := false


func build(def: Dictionary) -> void:
	for d: Array in def.get("doors", []):
		var x: float = d[0] * TILE + TILE / 2.0
		var y: float = d[1] * TILE
		var pic := Sprite2D.new()
		pic.texture = Game.texture("door_%s" % String(d[2]).to_lower())
		pic.centered = false
		pic.position = Vector2(x - pic.texture.get_width() / 2.0, y - pic.texture.get_height())
		pic.z_index = -1
		add_child(pic)
		var name_tag := Game.label(d[2], 13, Color("#ff7a59") if d[2] == "HELL" else Color("#fff3b0"))
		name_tag.position = Vector2(x - d[2].length() * 6.5, pic.position.y - 26)
		add_child(name_tag)
		_doors.append({ "x": x, "y": y, "to": float(d[3]) * TILE + TILE / 2.0 })
	for s: Array in def.get("signs", []):
		var x: float = s[0] * TILE + TILE / 2.0
		var board := Sprite2D.new()
		board.texture = Game.texture("notice_board")
		board.centered = false
		board.position = Vector2(x - board.texture.get_width() / 2.0, s[1] * TILE + 6 - board.texture.get_height())
		board.z_index = -1
		add_child(board)
		var words := Game.label(s[2], 11, Color("#4a2a12"))
		words.add_theme_constant_override("outline_size", 0)
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.size = Vector2(board.texture.get_width() - 20, 60)
		words.position = board.position + Vector2(10, 28)
		add_child(words)


## walking into a door takes her through it (the wrong one sends her back)
func update(p: CharacterBody2D) -> void:
	if _busy or p.frozen or not p.is_on_floor():
		return
	for d in _doors:
		if absf(p.position.x - d.x) < 18 and absf(p.position.y - d.y) < 10:
			_go_through(p, d)
			return


func _go_through(p: CharacterBody2D, d: Dictionary) -> void:
	_busy = true
	p.frozen = true
	p.velocity = Vector2.ZERO
	level.iris_close_on_player(func() -> void:
		p.teleport(Vector2(d.to, GROUND_Y))
		level.kitty.snap()
		level.iris_open()
		p.frozen = false
		_busy = false
		if d.to < d.x:
			level.banner("TOO GOOD TO BE TRUE!", "The sign did warn you...")
		else:
			level.banner("THE SIGN WAS RIGHT!", ""))
