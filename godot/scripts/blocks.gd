extends Node2D
## The blocks that do something (same rules as the original game):
## bricks and crates break when she bumps them from below, gift boxes give a gem or a power-up,
## secret blocks appear out of nowhere with an extra life, and dirt blocks crumble after she stands on them.

const TILE := 64
const KIND := {
	"B": "break", "C": "break", "H": "hidden", "~": "crumble", "R": "boulder", "O": "obstacle",
	"?": "gift", "+": "gift", "*": "gift", "&": "gift", "U": "gift", "G": "gift",
}
const CONTENT := { "?": "gem", "+": "cupcake", "*": "star", "&": "heart", "U": "balloon", "G": "magnet" }
const TEXTURE := { "B": "tile_brick", "C": "tile_crate", "~": "tile_dirt_block", "R": "boulder", "O": "barrel", "H": "tile_gift_used" }

var level: Node2D
var _blocks := {}      ## cell -> { body, pic, shape, kind, content }
var _last_bump := 0


func build(grid: PackedStringArray, width: int) -> void:
	for r in grid.size():
		for c in width:
			var ch := grid[r][c]
			if KIND.has(ch):
				_add(Vector2i(c, r), ch)
	# some gift boxes hold a magic power instead (data/powers.json)
	for p: Array in level.def.get("powers", []):
		var info: Dictionary = _blocks.get(Vector2i(p[0], p[1]), {})
		if not info.is_empty():
			info.content = p[2]


func _add(cell: Vector2i, ch: String) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0)
	body.set_meta("cell", cell)
	var box := RectangleShape2D.new()
	box.size = Vector2(TILE, TILE)
	var shape := CollisionShape2D.new()
	shape.shape = box
	body.add_child(shape)
	var pic := Sprite2D.new()
	pic.texture = Game.texture(TEXTURE.get(ch, "tile_gift"))
	if level.skin and ch in "BC":
		pic.texture = Game.texture(level.skin_art("block")) # the level's own crate
	pic.scale = Vector2(TILE, TILE) / pic.texture.get_size()
	body.add_child(pic)
	add_child(body)
	var info := { "body": body, "pic": pic, "shape": shape, "kind": KIND[ch], "content": CONTENT.get(ch, "") }
	if info.kind == "hidden":
		pic.modulate.a = 0.0 # invisible until she finds it
		shape.disabled = true
	_blocks[cell] = info


## -1: no special block here; 0: there is one but she can't stand on it right now; 1: solid
func state_at(c: int, r: int) -> int:
	var info: Dictionary = _blocks.get(Vector2i(c, r), {})
	if info.is_empty():
		return -1
	return 0 if info.shape.disabled or info.get("gone", false) else 1


## Called every physics step: what did her last move bump into?
func check(p: CharacterBody2D) -> void:
	for i in p.get_slide_collision_count():
		var hit := p.get_slide_collision(i)
		var body := hit.get_collider() as Node
		if not body or not body.has_meta("cell"):
			continue
		var info: Dictionary = _blocks.get(body.get_meta("cell"), {})
		if info.is_empty():
			continue
		if hit.get_normal().y > 0.5:
			_bump(info, p)        # her head hit it from below
		elif hit.get_normal().y < -0.5 and info.kind == "crumble":
			_crumble(info)        # she's standing on it
	# secret blocks are invisible: found when her head reaches one on the way up
	if p.velocity.y < 0:
		var head := Vector2i(floori(p.position.x / TILE), floori((p.position.y - 116) / TILE))
		var info: Dictionary = _blocks.get(head, {})
		if not info.is_empty() and info.kind == "hidden":
			_reveal(info, p)


## secret areas and Kitty's hint: are there secret blocks near this x?
func hidden_near(x: float, reach: float) -> bool:
	for info: Dictionary in _blocks.values():
		if info.kind == "hidden" and absf(info.body.position.x - x) < reach:
			return true
	return false


func _bump(info: Dictionary, p: CharacterBody2D) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_bump < 200 or absf(info.body.position.x - p.position.x) > 52:
		return # one block per jump, and only the one above her
	_last_bump = now
	var body: StaticBody2D = info.body
	match info.kind:
		"break":
			Game.play_sfx("smash")
			level.smash(body.position)
			info.gone = true
			body.queue_free()
			return
		"gift":
			info.kind = "used"
			info.pic.texture = Game.texture("tile_gift_used")
			if info.content == "gem":
				Game.play_sfx("gem")
				level.pop_gem(body.position + Vector2(0, -TILE))
			else:
				Game.play_sfx("sprout")
				level.spawn_powerup(info.content, body.position, p.position.x)
	# a little hop of the block
	var tw := create_tween()
	tw.tween_property(info.pic, "position:y", -12.0, 0.08)
	tw.tween_property(info.pic, "position:y", 0.0, 0.08)


func _reveal(info: Dictionary, p: CharacterBody2D) -> void:
	Game.play_sfx("one_up")
	info.kind = "used"
	info.shape.set_deferred("disabled", false)
	info.pic.modulate.a = 1.0
	p.velocity.y = 0
	p.position.y = info.body.position.y + TILE / 2.0 + 113 # just below it
	level.secret_block(info.body.position)


## shakes for a moment, drops away, and comes back a few seconds later
func _crumble(info: Dictionary) -> void:
	if info.get("falling", false):
		return
	info.falling = true
	var pic: Sprite2D = info.pic
	var tw := create_tween()
	for i in 4:
		tw.tween_property(pic, "position:x", 3.0, 0.05)
		tw.tween_property(pic, "position:x", -3.0, 0.05)
	tw.tween_property(pic, "position:x", 0.0, 0.05)
	tw.tween_callback(func() -> void:
		info.shape.set_deferred("disabled", true)
		info.gone = true
		level.puff_at(info.body.position + Vector2(0, 20), 10))
	tw.tween_property(pic, "position:y", 320.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(pic, "rotation_degrees", 20.0, 0.6)
	tw.parallel().tween_property(pic, "modulate:a", 0.0, 0.6)
	tw.tween_interval(4.0)
	tw.tween_callback(func() -> void:
		pic.position = Vector2.ZERO
		pic.rotation = 0
		info.shape.set_deferred("disabled", false)
		info.gone = false
		info.falling = false)
	tw.tween_property(pic, "modulate:a", 1.0, 0.3)
