extends Node2D
## Secret rooms: covered with dirt or brick that looks solid until Janani steps inside, then turns
## see-through. Kitty shows a bouncing "!" when a secret is nearby.

const TILE := 64

var level: Node2D
var _fakes: Array[Dictionary] = []  ## { pic, c, r, found }
var _hint: Label


func build(def: Dictionary, grid: PackedStringArray, width: int) -> void:
	# secret rooms listed in the level: [column, row, width, height, "dirt" or "brick"]
	for s: Array in def.get("secrets", []):
		for c in range(s[0], s[0] + s[2]):
			for r in range(s[1], s[1] + s[3]):
				if s[4] == "brick":
					_cover(c, r, "tile_brick")
				elif r == int(s[1]) and r > 0 and grid[r - 1][c] == " ":
					_cover(c, r, "ground_top") # the top of a hill: grass on top so it blends in
				else:
					_cover(c, r, "ground_dirt")
	# fake walls: F looks like brick, f like dirt
	for r in grid.size():
		for c in width:
			if grid[r][c] == "F":
				_cover(c, r, "tile_brick")
			elif grid[r][c] == "f":
				_cover(c, r, "ground_dirt")
	_hint = Game.label("!", 26, Color("#ffe14d"))
	_hint.visible = false
	_hint.z_index = 9
	add_child(_hint)
	var bounce := create_tween().set_loops()
	bounce.tween_property(_hint, "scale", Vector2(1.25, 1.25), 0.3)
	bounce.tween_property(_hint, "scale", Vector2.ONE, 0.3)


func _cover(c: int, r: int, key: String) -> void:
	var pic := Sprite2D.new()
	pic.centered = false
	pic.position = Vector2(c * TILE, r * TILE)
	if level.skin:
		# the art pack's own ground or crates, so the secret wall looks like the things around it
		pic.texture = Game.texture(level.skin_art({ "ground_top": "tile_2", "tile_brick": "block" }.get(key, "tile_5")))
	elif key == "ground_top":
		pic.texture = Game.frame("ground_top", c % 2, TILE)
		pic.position.y = (r + 1) * TILE - pic.texture.get_height() # the grass pokes above the tile
	else:
		pic.texture = Game.texture(key)
		pic.scale = Vector2(TILE, TILE) / pic.texture.get_size()
	pic.z_index = 6 # in front of Janani: she disappears "into" the wall
	add_child(pic)
	_fakes.append({ "pic": pic, "c": c, "r": r, "found": false })


func update(p: CharacterBody2D, kitty: Node2D) -> void:
	for f in _fakes:
		var inside: bool = absf(p.position.x - (f.c * TILE + TILE / 2.0)) < 56 \
			and p.position.y - 112 < (f.r + 1) * TILE and p.position.y > f.r * TILE
		f.pic.modulate.a = 0.35 if inside or f.found else 1.0
		if inside and not f.found:
			# reveal the whole hidden wall it belongs to
			for o in _fakes:
				if absi(o.c - f.c) <= 3 and absi(o.r - f.r) <= 4:
					o.found = true
			level.banner("SECRET ROOM!", "")
	var near: bool = level.blocks.hidden_near(p.position.x, 260.0)
	for f in _fakes:
		if not f.found and absf(f.c * TILE - p.position.x) < 260:
			near = true
	_hint.visible = near and kitty != null and not p.frozen
	if _hint.visible:
		_hint.position = kitty.position + Vector2(-10, -100)
