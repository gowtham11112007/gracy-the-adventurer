extends Node2D
## One level, built from its tile grid (data/levels.json, exported from the original game).
## Terrain and decorations, gems, crystals, candles, spikes, enemies, hearts and lives, the checkpoint,
## pit rescue, the finish gate, Janani and Kitty, the top bar and touch buttons. The special pieces have
## their own scripts: blocks (bricks, gift boxes, secret and crumbling blocks), power-ups, secret rooms,
## moving platforms, ropes, and doors and signs.

signal finished
signal exited(to_room: String, arrive: String)  ## she walked off the edge of a room into the next one
signal restart_requested   ## from the pause menu
signal quit_requested      ## from the pause menu: back to the map

const UI := preload("res://scripts/ui.gd")

const TILE := 64
const GROUND_Y := 10 * TILE        ## top of the ground row
const SOLID := "#="                ## plain ground and grass platforms (special blocks: blocks.gd)
const ENEMY_KIND := { "m": "mushroom", "M": "hopper", "b": "bee", "d": "diver", "n": "snail" }
const STOMP_BOUNCE := 620.0
const MAX_CHARGES := 3             ## magic charges she can save up (one per animal defeated)
const SWORD_REACH := 200.0         ## how far in front of her the sword reaches
const World := preload("res://scripts/world.gd")
## the moves she learns at the shrines, and the doors they open
const SHRINE_NAME := { "dash": "Dash Shrine", "double_jump": "Cloud Shrine", "wall_jump": "Climbing Shrine" }
const MOVE_NAME := { "dash": "The wind's blessing", "double_jump": "Double jump", "wall_jump": "The climber's blessing" }
const MOVE_HINT := { "dash": "The doors marked for the wind are open now", "double_jump": "Jump again in mid-air",
	"wall_jump": "The deep doors of the fortress are open now" }
## which art pack dresses each level (World 1): ground tiles, background and decorations
const SKIN_FOR_MOOD := { "day": "meadow", "windy": "meadow", "sky": "sky", "golden": "desert", "dusk": "graveyard" }

## drawing order, back to front
enum Z { SKY = -10, HORIZON = -5, DECO_BACK = -1, GROUND = 0, DECO_FRONT = 1, ITEM = 2, ENEMY = 3, KITTY = 4, JANANI = 5, FOREGROUND = 7 }

var def: Dictionary
var player: CharacterBody2D
var kitty: AnimatedSprite2D
var hearts := 4
var gems := 0
var _grid: PackedStringArray
var _width := 0
var _respawn: Vector2      ## the start, or the checkpoint once reached
var _checkpoint_reached := false
var _last_safe := Vector2.ZERO
var _done := false
var _dying := false
var _enemies: Array[Node] = []
var _spikes: Array[Area2D] = []
var _hurtbox: Area2D
var _cam: Camera2D
var _hud := {}
var _told_magic := false   ## the first charge explains the fire button
var _dust_timer := 0.0
var score := 0
var blocks: Node2D
var ladders: Node2D
var _secrets: Node2D
var _doors: Node2D
var _iris: CanvasLayer
var _gems: Array[Area2D] = []    ## for the gem magnet
var _boss_fight: Node2D          ## only on the boss level
var skin := ""                   ## the art pack this level uses ("" = the original Gemini look)
var _skin: Dictionary
var entry := ""                  ## rooms: where she comes in: "left", "right" or "bench" ("" = the room's start)
var _age := 0.0                  ## seconds since the level opened
var _closed_told := false        ## the "way is closed" message was just shown
var _doorways: Array[Dictionary] = []  ## rooms: the arches to the rooms above and below ({ exit, at })
var _bench_here := -1            ## the bench column she is standing at (so resting happens once per visit)
var _cinema: Node2D              ## the level's light and mood (cinema.gd)
var _lean := 150.0               ## how far the camera looks ahead of her
var _crystals_placed := 0        ## numbers the big crystals 0, 1, 2 (saved as found)


func _ready() -> void:
	_grid = PackedStringArray(def.grid)
	_width = int(def.width)
	_respawn = _start_pos()
	hearts = Game.state.max_hearts
	skin = SKIN_FOR_MOOD.get(def.get("mood", ""), "")
	_skin = Game.skins.get(skin, {})
	blocks = _part("blocks")
	blocks.build(_grid, _width)
	_build_background()
	_build_terrain()
	_decorate()
	_atmosphere(def.get("mood", "day"))
	_cinema = _part("cinema")
	_cinema.build(def.get("mood", "day"))
	_build_things()
	_build_checkpoint()
	_build_finish()
	_build_benches()
	_build_doorways()
	_build_shrine()
	_secrets = _part("secrets")
	_secrets.build(def, _grid, _width)
	_part("movers").build(def, skin_art("tile_%d" % _skin.float[1]) if skin else "tile_grass_float")
	_part("ropes").build(def)
	ladders = _part("ladders")
	ladders.build(_grid, _width)
	_doors = _part("doors")
	_doors.build(def)
	if def.has("boss"):
		_boss_fight = _part("boss_fight")
		_boss_fight.build(def)
	_build_player()
	_build_hud()
	_iris = preload("res://scripts/iris.gd").new()
	add_child(_iris)
	iris_open()
	Game.play_music(def.get("mood", "meadow"))
	if def.get("room", false):
		Game.discover_room(def.id) # the world map remembers every room she walks into


## Does this level use the Beta rules: a low hop that clears one-tile obstacles, floors only reachable by ladder?
## (The Beta level, and every world room.)
func hop_physics() -> bool:
	return def.get("id") == "beta" or def.get("hop", false)


## Where she appears (her feet): the level's start; or, in a room, beside the door she came through (in the
## doorway, for one above or below), or at her bench.
func _start_pos() -> Vector2:
	var col := int(def.start)
	var row := 10
	if def.get("room", false):
		match entry:
			"left":
				col = 2
			"right":
				col = _width - 3
			"bench":
				if not def.benches.is_empty():
					col = int(def.benches[0])
			"up", "down":
				for ex: Dictionary in def.exits:
					if ex.side == entry:
						col = int(ex.col)
						row = int(ex.row)
	return Vector2(col * TILE + TILE / 2.0, row * TILE)


## one of the level's helper scripts, added as a child that knows its level
func _part(script: String) -> Node2D:
	var node: Node2D = load("res://scripts/%s.gd" % script).new()
	node.set("level", self)
	add_child(node)
	return node


func _physics_process(delta: float) -> void:
	_age += delta
	_lean = lerpf(_lean, -150.0 if player.look.flip_h else 150.0, 0.03) # look ahead of her
	_cam.position = Vector2(_lean, -150) # (Juice shakes the camera's offset)
	if _done or _dying:
		return
	if player.position.y > 12 * TILE + 80:
		_fell_in_pit()
	if not _checkpoint_reached and def.has("checkpoint") and player.position.x >= def.checkpoint * TILE:
		_reach_checkpoint()
	if def.has("finish") and player.position.x >= def.finish * TILE + TILE / 2.0:
		_finish()
	if def.get("room", false):
		_check_exits()
		_check_doorways()
	blocks.check(player)
	if Input.is_action_just_pressed("shoot"):
		_shoot()
	_secrets.update(player, kitty)
	_doors.update(player)
	_pull_gems()
	if _boss_fight:
		_boss_fight.update(player, delta)
	for body in _hurtbox.get_overlapping_bodies():
		_touch_enemy(body)
	for spike in _spikes:
		if spike.overlaps_body(player):
			_hurt(spike.position.x)
			if not _dying:
				player.velocity.y = -650.0
	_note_safe_ground()
	# little dust kicks from her feet while she runs fast
	_dust_timer -= delta
	if player.is_on_floor() and absf(player.velocity.x) > 220 and _dust_timer <= 0:
		puff(2, -signf(player.velocity.x) * 14)
		_dust_timer = 0.11


## Rooms: walking off the left or right edge goes through that side's door to the next room (a fade, then
## `exited`). A side with no door, or one marked closed ("to": ""), is a wall.
func _check_exits() -> void:
	var x := player.position.x
	var lo := TILE * 0.4
	var hi := (_width - 0.4) * TILE
	if x >= lo and x <= hi:
		_closed_told = false
		return
	var side := "left" if x < lo else "right"
	for ex: Dictionary in def.exits:
		if ex.side == side and not String(ex.to).is_empty() and gate_open(ex):
			_leave(ex)
			return
	player.position.x = clampf(x, lo, hi) # a wall
	player.velocity.x = 0.0
	for ex: Dictionary in def.exits:
		if ex.side == side and not _closed_told:
			_closed_told = true
			_tell_closed(ex)


## is this door open? Some need a move she learns at a shrine, Yuva's needs three lit candles.
func gate_open(ex: Dictionary) -> bool:
	return World.gate_open(String(ex.get("gate", "")), Game.save.abilities, Game.save.candles.size())


func _tell_closed(ex: Dictionary) -> void:
	var gate := String(ex.get("gate", ""))
	if gate.begins_with("candles"):
		banner("The way is sealed", "Light three birthday candles (%d of 3)" % mini(3, Game.save.candles.size()), 2.0)
	elif not gate.is_empty():
		banner("The way is closed", "Find the %s" % SHRINE_NAME.get(gate, "shrine"), 2.0)
	else:
		banner("The way is closed", "for now", 1.6)


## Doorways to the rooms above and below: a glowing arch. Standing in one and pressing Up goes through.
func _build_doorways() -> void:
	for ex: Dictionary in def.get("exits", []):
		if not ex.has("col"):
			continue
		var at := Vector2(int(ex.col) * TILE + TILE / 2.0, int(ex.row) * TILE)
		var arch := Sprite2D.new()
		arch.texture = Game.texture("portal")
		var size := 150.0 / arch.texture.get_height()
		arch.scale = Vector2(size, size)
		arch.position = at + Vector2(0, -75)
		arch.z_index = Z.DECO_BACK
		arch.modulate = Color(1, 1, 1, 1) if gate_open(ex) else Color(0.45, 0.45, 0.55, 0.9)
		add_child(arch)
		var glow := UI.glow(110, Color(0.5, 0.8, 1.0, 0.45) if gate_open(ex) else Color(0.6, 0.5, 0.8, 0.2))
		glow.position = arch.position
		add_child(glow)
		UI.breathe(glow, 0.5, 1.3)
		var to: Dictionary = World.room(String(ex.to))
		var sign := Game.label(("^ " if ex.side == "up" else "v ") + String(to.get("name", "")), 11, Color(1.0, 0.92, 0.7))
		sign.position = at + Vector2(-90, -186)
		sign.size.x = 180
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign.z_index = Z.DECO_FRONT
		add_child(sign)
		_doorways.append({ "exit": ex, "at": at })


## standing in a doorway and pressing Up: through it (or told what it needs)
func _check_doorways() -> void:
	if not Input.is_action_just_pressed("up") or player.climbing:
		return
	for d: Dictionary in _doorways:
		var at: Vector2 = d.at
		if absf(player.position.x - at.x) < 44 and absf(player.position.y - at.y) < 24:
			if gate_open(d.exit):
				_leave(d.exit)
			else:
				_tell_closed(d.exit)
			return


## A shrine (def.shrine): a glowing stone that teaches her a move. Its doors open once she has it.
func _build_shrine() -> void:
	if not def.has("shrine"):
		return
	var ability := String(def.shrine.ability)
	var x := int(def.shrine.col) * TILE + TILE / 2.0
	var stone := _stand("gem_big", x, GROUND_Y - 30, Z.DECO_BACK, 1.6)
	var glow := UI.glow(200, Color(0.55, 0.9, 1.0, 0.65))
	glow.position = Vector2(x, GROUND_Y - 80)
	add_child(glow)
	UI.breathe(glow, 0.5, 1.0)
	var name := Game.label(SHRINE_NAME.get(ability, "Shrine"), 14, UI.GOLD)
	name.position = Vector2(x - 120, GROUND_Y - 230)
	name.size.x = 240
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.z_index = Z.DECO_FRONT
	add_child(name)
	var area := Area2D.new()
	area.position = Vector2(x, GROUND_Y - 60)
	area.collision_layer = 0
	area.collision_mask = 2
	var box := RectangleShape2D.new()
	box.size = Vector2(120, 140)
	var shape := CollisionShape2D.new()
	shape.shape = box
	area.add_child(shape)
	area.body_entered.connect(func(body: Node) -> void:
		if body == player and Game.unlock_ability(ability):
			stone.modulate = Color(1.4, 1.4, 1.6)
			flash(Color(0.7, 0.9, 1.0, 0.5))
			Game.play_sfx("one_up")
			banner(String(MOVE_NAME.get(ability, ability)).to_upper(), MOVE_HINT.get(ability, ""), 2.6))
	add_child(area)


func _leave(ex: Dictionary) -> void:
	if _done:
		return
	_done = true
	player.frozen = true
	iris_close_on_player(func() -> void: exited.emit(ex.to, ex.arrive))


## Benches (def.benches: columns): a glowing lantern post. Touching one heals her and saves the game there.
func _build_benches() -> void:
	for col: int in def.get("benches", []):
		var x := col * TILE + TILE / 2.0
		var post := Node2D.new()
		post.position = Vector2(x, GROUND_Y)
		post.z_index = Z.DECO_BACK
		post.set_script(preload("res://scripts/bench_art.gd"))
		add_child(post)
		var glow := UI.glow(120, Color(1.0, 0.8, 0.45, 0.5))
		glow.position = Vector2(0, -96)
		post.add_child(glow)
		UI.breathe(glow, 0.55, 1.1)
		var area := Area2D.new()
		area.position = Vector2(x, GROUND_Y - 60)
		area.collision_layer = 0
		area.collision_mask = 2
		var box := RectangleShape2D.new()
		box.size = Vector2(110, 140)
		var shape := CollisionShape2D.new()
		shape.shape = box
		area.add_child(shape)
		area.body_entered.connect(func(body: Node) -> void:
			if body == player and _bench_here != col:
				_bench_here = col
				_rest())
		area.body_exited.connect(func(body: Node) -> void:
			if body == player and _bench_here == col:
				_bench_here = -1)
		add_child(area)


## she rests: full hearts, and the game is saved here (she returns to this bench).
func _rest() -> void:
	hearts = Game.state.max_hearts
	player.charges = 0
	Game.save.bench = def.id
	Game.save.room = def.id
	Game.write_save()
	_update_hud()
	puff_at(player.position + Vector2(0, -80), 10, Color(1.0, 0.85, 0.5))
	Game.play_sfx("one_up")
	var wait := maxf(0.0, 3.6 - _age) # (not on top of the room's title card at the start)
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	banner("Rested", "Your game is saved", 1.4)


## is there solid ground at this point of the level? (enemies use it to stop at ledges)
func is_solid_at(point: Vector2) -> bool:
	return _solid(floori(point.x / TILE), floori(point.y / TILE))


func _solid(c: int, r: int) -> bool:
	if r < 0 or r >= _grid.size() or c < 0 or c >= _width:
		return false
	var special: int = blocks.state_at(c, r) if blocks else -1
	return special == 1 if special >= 0 else SOLID.contains(_grid[r][c])


# ------------------------------------------------------------------ building ---

func _sprite(key: String, pos: Vector2, z := Z.GROUND, frame := -1, cell := 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Game.frame(key, frame, cell) if frame >= 0 else Game.texture(key)
	s.centered = false
	s.position = pos
	s.z_index = z
	add_child(s)
	return s


## a picture standing on the ground, centred on x
func _stand(key: String, x: float, y: float, z: int, size := 1.0) -> Sprite2D:
	var s := _sprite(key, Vector2.ZERO, z)
	s.scale = Vector2(size, size)
	s.position = Vector2(x - s.texture.get_width() * size / 2.0, y - s.texture.get_height() * size)
	return s


## a picture from this level's art pack
func skin_art(name: String) -> String:
	return "skins/%s/%s" % [skin, name]


func _build_background() -> void:
	if skin:
		# the pack's background (the sky has two layers: the sky itself, and clouds a little nearer)
		var layers: Array = _skin.bg
		for i in layers.size():
			var tex := Game.texture(skin_art(layers[i]))
			var layer := _parallax(0.1 + i * 0.15 if layers.size() > 1 else 0.25, tex.get_width())
			layer.z_index = Z.SKY + i
			var pic := Sprite2D.new()
			pic.texture = tex
			pic.centered = false
			layer.add_child(pic)
		return
	var tex := Game.texture("bg_meadow_wide")
	var s := 720.0 / tex.get_height()
	var sky := _parallax(0.3, tex.get_width() * s)
	sky.z_index = Z.SKY
	var pic := Sprite2D.new()
	pic.texture = tex
	pic.centered = false
	pic.scale = Vector2(s, s)
	if def.has("tint") and not skin:
		pic.modulate = Color.hex((int(def.tint) << 8) | 0xff)
	if def.get("mood", "") == "sky":
		pic.position.y = 720 * 0.42 # up in the treetops: more open sky above the hills
	sky.add_child(pic)


func _parallax(speed: float, repeat_width: float) -> Parallax2D:
	var layer := Parallax2D.new()
	layer.scroll_scale = Vector2(speed, 1.0 if speed > 0.3 else 0.0)
	layer.repeat_size = Vector2(repeat_width, 0)
	layer.repeat_times = 3
	add_child(layer)
	return layer


## Ground pictures, and one long collision box per run of solid tiles in a row.
func _build_terrain() -> void:
	var walls := StaticBody2D.new()
	add_child(walls)
	for r in _grid.size():
		var run_start := -1
		for c in _width + 1:
			if c < _width and _grid[r][c] == "#" and skin:
				_sprite(skin_art("tile_%d" % _ground_piece(c, r)), Vector2(c * TILE, r * TILE))
			elif c < _width and _grid[r][c] == "#":
				if _solid(c, r - 1):
					_sprite("ground_dirt", Vector2(c * TILE, r * TILE))
				else:
					# grass on top: the pattern alternates every tile, and the grass pokes above the tile
					var top := _sprite("ground_top", Vector2.ZERO, Z.GROUND, c % 2, TILE)
					top.position = Vector2(c * TILE, (r + 1) * TILE - top.texture.get_height())
			var solid := c < _width and SOLID.contains(_grid[r][c])
			if solid and run_start < 0:
				run_start = c
			elif not solid and run_start >= 0:
				var box := RectangleShape2D.new()
				box.size = Vector2((c - run_start) * TILE, TILE)
				var shape := CollisionShape2D.new()
				shape.shape = box
				shape.position = Vector2((run_start + c) * TILE / 2.0, r * TILE + TILE / 2.0)
				walls.add_child(shape)
				run_start = -1


## which numbered piece of the pack's ground a tile needs: grass on top where it's open above,
## rounded edges where it's open at the side (1-3 grass top, 4-6 earth below)
func _ground_piece(c: int, r: int) -> int:
	var ground := func(cc: int, rr: int) -> bool:
		if cc < 0 or cc >= _width:
			return true # the level's edges count as more ground
		return rr >= 0 and rr < _grid.size() and _grid[rr][cc] == "#"
	var open_left: bool = not ground.call(c - 1, r)
	var open_right: bool = not ground.call(c + 1, r)
	var side := 0 if open_left == open_right else (-1 if open_left else 1)
	var middle := 2 if not ground.call(c, r - 1) else 5
	return middle + side


## a grass platform piece: rounded ends where the row of platforms ends
func _float_piece(c: int, r: int) -> String:
	var pieces: Array = _skin.float
	var left := c > 0 and _grid[r][c - 1] == "="
	var right := c < _width - 1 and _grid[r][c + 1] == "="
	var n: int = pieces[1]
	if right and not left:
		n = pieces[0]
	elif left and not right:
		n = pieces[2]
	return skin_art("tile_%d" % n)


## Trees, bushes, flowers and rocks along the ground, clouds drifting in the sky, faded trees on the
## horizon and grass tufts in front of her feet (same recipe as the original, so each level looks the same).
func _decorate() -> void:
	if hop_physics():
		return
	var rnd := RandomNumberGenerator.new()
	rnd.seed = hash(def.id)
	var free := func(c: int, top: int) -> bool:
		for cc in range(c - 1, c + 2):
			for r in range(top, 10):
				if cc < 0 or cc >= _width or _grid[r][cc] != " ":
					return false
			if _grid[10][cc] != "#":
				return false
		return true
	var last := -10
	var last_tree := -10
	for c in range(5, _width - 2):
		if c - last < 2 or c in [int(def.start), int(def.get("checkpoint", -1))] or absi(c - int(def.get("finish", -99))) < 6:
			continue
		var roll := rnd.randf()
		var x := c * TILE + rnd.randi_range(-12, 12)
		var key := ""
		var back := true
		if roll < 0.13 and c - last_tree > 6 and free.call(c, 4):
			key = _deco_pick("tree", rnd, ["deco_tree", "deco_tree_round", "deco_tree_small"])
			last_tree = c
		elif roll < 0.3 and free.call(c, 8):
			key = _deco_pick("bush", rnd, ["deco_bush", "deco_bush_tall", "deco_bush_flowers"])
		elif roll < 0.48 and free.call(c, 9) and def.get("id") != "beta":
			key = _deco_pick("small", rnd, ["deco_flowers_yellow", "deco_flowers_purple", "deco_tuft", "deco_tuft2"])
			back = false
		elif roll < 0.53 and free.call(c, 9) and def.get("id") != "beta":
			key = _deco_pick("rock", rnd, ["deco_rock", "deco_rock2"])
		if key:
			last = c
			var sink := 18 if back else 10
			if skin:
				sink = 4 # the packs' ground has no grass poking above the tile
			_stand(key, x, GROUND_Y + sink, Z.DECO_BACK if back else Z.DECO_FRONT)

	# clouds at three distances, drifting slowly (the art packs' skies have their own)
	for i in (0 if skin else 3):
		var layer := _parallax(0.15 + i * 0.15, 2400)
		layer.scroll_scale.y = 0
		layer.autoscroll = Vector2(6 + i * 4, 0)
		layer.z_index = Z.SKY + 1
		for n in 4:
			var cloud := Sprite2D.new()
			cloud.texture = Game.texture("cloud_big" if rnd.randf() < 0.5 else "cloud_small")
			cloud.position = Vector2(rnd.randf_range(0, 2400), rnd.randf_range(40, 260))
			cloud.scale = Vector2.ONE * (0.7 + i * 0.3)
			cloud.modulate.a = 0.55 + i * 0.15
			layer.add_child(cloud)
	if def.get("mood", "day") == "sky" or skin:
		return # the pack backgrounds already have their own hills and horizon
	# faded trees on the horizon, moving slower than the ground
	var horizon := _parallax(0.5, 3000)
	horizon.z_index = Z.HORIZON
	var x := 0.0
	while x < 3000:
		var tree := Sprite2D.new()
		tree.texture = Game.texture(["deco_tree", "deco_tree_round", "deco_tree_small"][rnd.randi() % 3])
		var size := rnd.randf_range(1.1, 1.6)
		tree.scale = Vector2(size, size)
		tree.position = Vector2(x, GROUND_Y + 20 - tree.texture.get_height() * size / 2.0)
		tree.modulate = Color(0.72, 0.83, 0.91, 0.55)
		horizon.add_child(tree)
		x += rnd.randf_range(110, 260)
	# grass and flowers in front of her feet, for depth
	var c := 4
	while c < _width - 2:
		if _grid[10][c] == "#" and _grid[9][c] == " ":
			var key: String = ["deco_tuft", "deco_tuft2", "deco_flowers_yellow", "deco_flowers_purple"][rnd.randi() % 4]
			_stand(key, c * TILE + rnd.randi_range(-20, 20), GROUND_Y + 30, Z.FOREGROUND, 1.25)
		c += rnd.randi_range(6, 14)


## Each level's weather and light: petals on the meadow, blowing leaves on the windy hills, clouds below
## the treetops, golden motes at the fortress, and a moon with fireflies at dusk on Yuva's hill.
func _atmosphere(mood: String) -> void:
	var size := Vector2(1600, 720)
	if mood == "sky" and not skin:
		var rnd := RandomNumberGenerator.new()
		rnd.seed = hash(def.id + "-clouds")
		var x := 0.0
		while x < _width * TILE:
			var cloud := _sprite("cloud_big", Vector2.ZERO, Z.DECO_BACK)
			var big := rnd.randf_range(2.0, 3.0)
			cloud.scale = Vector2(big, big)
			cloud.position = Vector2(x, 12 * TILE - rnd.randi_range(20, 90) - cloud.texture.get_height() * big / 2.0)
			x += rnd.randf_range(300, 600)
	if mood == "dusk" and not skin: # the graveyard pack has its own full moon
		var far := _parallax(0.05, 100000)
		far.z_index = Z.SKY + 1
		var moon := Sprite2D.new()
		moon.texture = Game.texture("moon")
		moon.position = Vector2(1000, 110)
		moon.modulate.a = 0.9
		far.add_child(moon)
	var weather: Array = {
		"day": [[Color("#ffe6a8"), Color("#fff6dc")], Vector2(1, 0.6), 30.0, 4.0, 9.0, 0.7],
		"windy": [[Color("#7ec850"), Color("#a6dd6a")], Vector2(-1, 0.05), 340.0, 11.0, 5.0, 1.2],
		"sky": [[Color.WHITE, Color("#d8f0ff")], Vector2(0.3, 0.1), 15.0, 3.0, 6.0, 0.8],
		"golden": [[Color("#ffe08a"), Color("#fff3c4")], Vector2(0, -1), 25.0, 6.0, 7.0, 0.7],
		"dusk": [[Color("#d8ff7a"), Color("#fff38a")], Vector2(0, -0.2), 25.0, 7.0, 5.0, 0.8],
	}.get(mood, [])
	if weather.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.layer = 1 # over the level, under the top bar
	add_child(layer)
	var air := CPUParticles2D.new()
	air.amount = int(weather[3] * weather[4])
	air.lifetime = weather[4]
	air.preprocess = weather[4] # already drifting when the level starts
	air.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	air.emission_rect_extents = size / 2
	air.position = size / 2
	if mood == "windy":
		air.emission_rect_extents = Vector2(20, size.y / 2) # blown in from the right edge
		air.position = Vector2(size.x, size.y / 2)
	air.direction = weather[1]
	air.spread = 25.0
	air.initial_velocity_min = weather[2] * 0.6
	air.initial_velocity_max = weather[2] * 1.4
	air.gravity = Vector2.ZERO
	air.angular_velocity_min = -90.0
	air.angular_velocity_max = 90.0
	air.scale_amount_min = 4.0 * weather[5]
	air.scale_amount_max = 7.0 * weather[5]
	var fade := Gradient.new()
	fade.set_color(0, Color(weather[0][0], 0.0))
	fade.add_point(0.15, Color(weather[0][0], 0.9))
	fade.add_point(0.8, Color(weather[0][1], 0.8))
	fade.set_color(fade.get_point_count() - 1, Color(weather[0][1], 0.0))
	air.color_ramp = fade
	layer.add_child(air)


## a decoration: from this level's art pack, or the original Gemini set
func _deco_pick(group: String, rnd: RandomNumberGenerator, original: Array) -> String:
	if skin and _skin.deco.has(group):
		var names: Array = _skin.deco[group]
		return skin_art(names[rnd.randi() % names.size()])
	return original[rnd.randi() % original.size()]


func _build_things() -> void:
	for r in _grid.size():
		for c in _width:
			var ch := _grid[r][c]
			var center := Vector2(c * TILE + TILE / 2.0, r * TILE + TILE / 2.0)
			if ch == "=" and skin:
				_sprite(_float_piece(c, r), Vector2(c * TILE, r * TILE))
			elif ch == "=":
				var s := _sprite("tile_grass_float", Vector2(c * TILE, r * TILE))
				s.scale = Vector2(TILE, TILE) / s.texture.get_size()
			elif ch == "o":
				_item(center, "gem", ["gem", [0, 1, 2, 1], 6])
			elif ch == "X":
				_item(center, "crystal", ["gem_big", [], 0])
			elif ch == "c":
				_item(center, "candle", ["candle", [], 0])
			elif ch == "^":
				_add_spikes(center)
			elif ENEMY_KIND.has(ch):
				var e: CharacterBody2D = preload("res://scripts/enemy.gd").new()
				e.kind = ENEMY_KIND[ch]
				e.level = self
				e.position = Vector2(center.x, (r + 1) * TILE)
				e.z_index = Z.ENEMY
				add_child(e)
				_enemies.append(e)


## Something to pick up: spins (if it has frames) and pops when collected.
func _item(pos: Vector2, kind: String, art: Array) -> void:
	var area := Area2D.new()
	area.position = pos
	area.z_index = Z.ITEM
	area.collision_mask = 2 # looks for Janani
	var circle := CircleShape2D.new()
	circle.radius = 22
	var shape := CollisionShape2D.new()
	shape.shape = circle
	area.add_child(shape)
	if art[1].is_empty():
		var pic := Sprite2D.new()
		pic.texture = Game.texture(art[0])
		area.add_child(pic)
	else:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = Game.sprite_frames({ "spin": [art[0], art[1], art[2], true] })
		anim.play("spin")
		area.add_child(anim)
	if kind == "gem":
		_gems.append(area)
	# everything worth picking up glows softly, so it catches the eye in the dark
	var glow: Sprite2D = { "gem": UI.glow(34, Color(0.8, 0.5, 1.0, 0.55)), "crystal": UI.glow(90, Color(0.55, 0.9, 1.0, 0.7)),
		"candle": UI.glow(80, Color(1.0, 0.8, 0.45, 0.75)) }[kind]
	glow.position.y = -14 if kind == "candle" else 0
	glow.z_index = -1
	area.add_child(glow)
	UI.breathe(glow, 0.55, randf_range(0.9, 1.3))
	var crystal_number := _crystals_placed
	if kind == "crystal":
		_crystals_placed += 1
	# a gentle float up and down
	var bob := area.create_tween().set_loops()
	bob.tween_property(area, "position:y", pos.y - 6, 0.7).set_trans(Tween.TRANS_SINE)
	bob.tween_property(area, "position:y", pos.y, 0.7).set_trans(Tween.TRANS_SINE)
	area.body_entered.connect(func(body: Node) -> void:
		if body != player or area.get_meta("taken", false):
			return
		area.set_meta("taken", true)
		bob.kill()
		if kind == "gem":
			add_gem()
			Game.play_sfx("gem")
		elif kind == "crystal":
			score += 2000
			Game.play_sfx("power")
			banner("Big Crystal", "")
			var found: Array = Game.save.crystals.get(def.id, [])
			if not found.has(crystal_number):
				found.append(crystal_number)
			Game.save.crystals[def.id] = found
			Game.write_save()
		elif kind == "candle":
			score += 5000
			Game.play_sfx("one_up")
			banner("Birthday Candle", "One of five, for the birthday cake")
			if not Game.save.candles.has(def.id):
				Game.save.candles.append(def.id)
			Game.write_save()
		_update_hud()
		var pop := create_tween()
		pop.tween_property(area, "scale", Vector2(1.6, 1.6), 0.12)
		pop.parallel().tween_property(area, "modulate:a", 0.0, 0.12)
		pop.tween_callback(area.queue_free)
		area.set_deferred("monitoring", false))
	add_child(area)


func _add_spikes(pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	area.z_index = Z.ITEM
	area.collision_mask = 2
	var box := RectangleShape2D.new()
	box.size = Vector2(40, 26)
	var shape := CollisionShape2D.new()
	shape.shape = box
	shape.position.y = 12 # only the points hurt
	area.add_child(shape)
	var pic := Sprite2D.new()
	pic.texture = Game.texture("tile_spikes")
	pic.scale = Vector2(TILE, TILE) / pic.texture.get_size()
	area.add_child(pic)
	add_child(area)
	_spikes.append(area)


## balloons tied to a signpost mark the checkpoint
func _build_checkpoint() -> void:
	if not def.has("checkpoint"):
		return
	var x: float = def.checkpoint * TILE + TILE / 2.0
	_stand(skin_art(_skin.deco.sign[0]) if skin else "deco_sign", x, GROUND_Y + (4 if skin else 14), Z.DECO_BACK)
	var balloons := _stand("balloons", x, GROUND_Y - 40, Z.DECO_BACK)
	balloons.name = "CheckpointBalloons"


func _build_finish() -> void:
	if not def.has("finish"):
		return
	var x: float = def.finish * TILE + TILE / 2.0
	if def.get("id") == "beta":
		var portal := _stand("portal", x, GROUND_Y + 4, Z.DECO_BACK)
		var glow := UI.glow(120, Color(0.4, 0.8, 1.0, 0.6))
		glow.position = portal.position + Vector2(portal.texture.get_width() * portal.scale.x / 2.0, portal.texture.get_height() * portal.scale.y / 2.0)
		add_child(glow)
		UI.breathe(glow, 0.5, 1.2)
		return
	var gate := _stand("finish_gate", x, GROUND_Y + 14, Z.DECO_BACK)
	var sign := Game.label("FINISH", 26, Color("#c2185b"))
	sign.add_theme_constant_override("outline_size", 0)
	sign.position = Vector2(x - 78, gate.position.y + gate.texture.get_height() * 0.21 - 16)
	sign.z_index = Z.DECO_BACK
	add_child(sign)


func _build_player() -> void:
	player = preload("res://scripts/player.gd").new()
	player.set("level", self)
	player.position = _respawn
	player.z_index = Z.JANANI
	add_child(player)
	# a slightly smaller box than her body: touching an enemy or bee with it counts
	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = 4
	var box := RectangleShape2D.new()
	box.size = Vector2(36, 108)
	var shape := CollisionShape2D.new()
	shape.shape = box
	shape.position.y = -56
	_hurtbox.add_child(shape)
	player.add_child(_hurtbox)

	kitty = preload("res://scripts/kitty.gd").new()
	kitty.player = player
	kitty.z_index = Z.KITTY
	add_child(kitty)
	_cinema.light_player(player)

	# soft shadows on the ground under both of them
	for who: Node2D in [player, kitty]:
		var shadow: Node2D = preload("res://scripts/shadow.gd").new()
		shadow.target = who
		shadow.width = 46.0 if who == player else 34.0
		shadow.z_index = Z.DECO_FRONT
		add_child(shadow)

	# dust: a puff when she jumps, a bigger one on hard landings, and little kicks while running
	player.jumped.connect(func() -> void: puff(6))
	player.slashed.connect(_sword_swing)
	player.landed.connect(func(speed: float) -> void:
		if speed > 380:
			puff(14 if speed > 800 else 8))

	_cam = Camera2D.new()
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = _width * TILE
	_cam.limit_bottom = 12 * TILE
	_cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS # moves in step with the smoothed physics
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 6.0
	player.add_child(_cam)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var vp := get_viewport_rect().size
	# top left, on a strip of glass: hearts, then her magic and its charges
	var bar := UI.panel(Vector2(250, 56), 28)
	bar.position = Vector2(20, 18)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bar)
	_hud.hearts = []
	for i in Game.state.max_hearts:
		var h := UI.picture(Game.texture("heart"), Vector2(32, 30))
		h.position = Vector2(18 + i * 38, 13)
		bar.add_child(h)
		_hud.hearts.append(h)
	_hud.power = UI.picture(null, Vector2(36, 36)) # the magic power she has
	_hud.power.position = Vector2(270, 26)
	layer.add_child(_hud.power)
	_hud.charges = UI.text("", 22, UI.CREAM, "bold")
	_hud.charges.position = _hud.power.position + Vector2(40, 2)
	layer.add_child(_hud.charges)
	# gems and lives, quietly, beside it
	var gem_icon := UI.picture(Game.frame("gem", 0), Vector2(26, 34))
	gem_icon.position = Vector2(30, 86)
	layer.add_child(gem_icon)
	_hud.gems = UI.text("", 24, UI.CREAM, "bold")
	_hud.gems.position = Vector2(62, 84)
	layer.add_child(_hud.gems)
	var face := UI.picture(Game.texture("portrait_janani"), Vector2(34, 34))
	face.position = Vector2(120, 85)
	layer.add_child(face)
	_hud.lives = UI.text("", 24, UI.CREAM, "bold")
	_hud.lives.position = Vector2(158, 84)
	layer.add_child(_hud.lives)
	# top right: the score and the pause button
	_hud.score = UI.text("", 26, UI.GOLD, "title")
	_hud.score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.score.size = Vector2(220, 40)
	_hud.score.position = Vector2(vp.x - 330, 28)
	layer.add_child(_hud.score)
	var pause := UI.icon_button("pause", 60)
	pause.position = Vector2(vp.x - 86, 18)
	pause.pressed.connect(open_pause_menu)
	layer.add_child(pause)
	# the big message in the middle: a carved gold title and a quiet line under it
	_hud.banner = VBoxContainer.new()
	_hud.banner.size = Vector2(vp.x, 120)
	_hud.banner.position = Vector2(0, 190)
	_hud.banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.banner.modulate.a = 0.0
	_hud.banner_title = UI.centered(UI.title("", 48), Vector2(vp.x, 64))
	_hud.banner_sub = UI.centered(UI.text("", 26, UI.CREAM), Vector2(vp.x, 36))
	_hud.banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.banner.add_child(_hud.banner_title)
	_hud.banner.add_child(_hud.banner_sub)
	layer.add_child(_hud.banner)
	_level_card(layer, vp)
	# the phone's buttons (on a computer only when started with `-- touch` or `autorun`)
	_hud.pad = null
	var args := OS.get_cmdline_user_args()
	if DisplayServer.is_touchscreen_available() or "touch" in args: # (not in "autorun": the pad would undo its key presses)
		_hud.pad = preload("res://scripts/touch_pad.gd").new()
		layer.add_child(_hud.pad)
	_update_hud()


## the level's name, shown like a film title when it starts, then fading away
func _level_card(layer: CanvasLayer, vp: Vector2) -> void:
	var card := Control.new()
	card.size = Vector2(vp.x, 140)
	card.position = Vector2(0, vp.y * 0.3)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var world := UI.centered(UI.text(def.get("area_name", "World %s" % def.id), 24, UI.MIST), Vector2(vp.x, 36))
	card.add_child(world)
	var title := UI.heading(String(def.name), minf(vp.x, 900), 54)
	title.position = Vector2((vp.x - title.size.x) / 2, 38)
	card.add_child(title)
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(card, "modulate:a", 1.0, 0.8)
	tw.tween_interval(1.8)
	tw.tween_property(card, "modulate:a", 0.0, 0.8)
	tw.tween_callback(card.queue_free)


func open_pause_menu() -> void:
	if get_tree().paused or not is_playing():
		return
	get_tree().paused = true
	var p := preload("res://scripts/popup.gd").new()
	p.title = "Paused"
	var in_room: bool = def.get("room", false)
	p.sheet_size = Vector2(520, 620 if in_room else 520)
	p.closed.connect(func() -> void: get_tree().paused = false)
	add_child(p)
	p.add_button("Resume", "gold", p.close)
	if in_room: # the world map: only the rooms she has walked into are filled in
		p.add_button("Map", "glass", func() -> void:
			var m := preload("res://scripts/map_screen.gd").new()
			add_child(m))
	p.add_button("Restart room" if in_room else "Restart level", "glass", func() -> void:
		get_tree().paused = false
		restart_requested.emit())
	p.add_button("Title screen" if in_room else "World map", "glass", func() -> void:
		get_tree().paused = false
		quit_requested.emit())
	p.add_audio_switches(def.get("mood", "meadow"))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_P):
		open_pause_menu()


func _update_hud() -> void:
	_hud.gems.text = str(gems)
	_hud.score.text = "%06d" % score
	_hud.lives.text = str(maxi(0, Game.state.lives))
	for i in _hud.hearts.size():
		_hud.hearts[i].modulate = Color.WHITE if i < hearts else Color(0.3, 0.3, 0.4, 0.5)
	var magic := Game.texture("icon_" + player.power)
	_hud.power.texture = magic
	_hud.power.visible = player.charges > 0
	_hud.charges.visible = player.charges > 0
	_hud.charges.text = "x%d" % player.charges
	if _hud.pad:
		_hud.pad.shoot_icon = magic if player.charges > 0 else null


# ------------------------------------------------- helpers for the other scripts ---

func is_playing() -> bool:
	return not _done and not _dying


## an animal defeated: one more magic charge (up to 3)
func _charge() -> void:
	if player.charges >= MAX_CHARGES:
		return
	player.charges += 1
	if not _told_magic:
		_told_magic = true
		banner("MAGIC CHARGED!", "Press the fire button to throw it")
	else:
		pop_text(player.position + Vector2(0, -150), "+MAGIC")
	_update_hud()


## throw a fireball or shoot a fire arrow, using one charge (two at a time on screen, like the classics)
func _shoot() -> void:
	if player.charges <= 0 or player.frozen or not player.hanging.is_empty() or not is_playing():
		return
	var flying := get_children().filter(func(n: Node) -> bool: return n.get_script() == preload("res://scripts/shot.gd"))
	if flying.size() >= 2:
		return
	var shot: CharacterBody2D = preload("res://scripts/shot.gd").new()
	shot.kind = player.power
	shot.dir = -1.0 if player.look.flip_h else 1.0
	shot.level = self
	Game.play_sfx("whoosh")
	shot.position = player.position + Vector2(shot.dir * 40, -70)
	shot.z_index = Z.ENEMY
	add_child(shot)
	player.charges -= 1
	_update_hud()


## Her sword: a moment after she swings (when the blade comes round), every animal in front of her within
## reach is knocked out, and Yuva takes a hit. A hit freezes the action for an instant and shakes the camera.
func _sword_swing() -> void:
	await get_tree().create_timer(0.12, false, true).timeout
	if not is_instance_valid(player) or not is_playing():
		return
	var dir := -1.0 if player.look.flip_h else 1.0
	var reach := Rect2(player.position.x - (SWORD_REACH if dir < 0 else 30.0), player.position.y - 200, SWORD_REACH + 30.0, 220)
	var hit := false
	for e: Node in _enemies:
		if is_instance_valid(e) and not e.dead and reach.has_point(e.position + Vector2(0, -30)):
			e.defeat()
			score += 200
			_charge()
			puff_at(e.position + Vector2(0, -40), 8, Color(1.0, 0.95, 0.8))
			hit = true
	if _boss_fight and is_instance_valid(_boss_fight.boss) and reach.has_point(_boss_fight.boss.position + Vector2(0, -60)):
		hit = _boss_fight.sword_hit() or hit
	if hit:
		Game.play_sfx("smash")
		Juice.hitstop(0.06, 0.05)
		shake(0.12)
		_update_hud()


## an animated cartoon explosion (fireball hits, Yuva's bombs)
func boom(at: Vector2, size := 1.0) -> void:
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = Game.sprite_frames({ "boom": ["explosion", range(10), 24, false] })
	fx.position = at
	fx.scale = Vector2(size, size)
	fx.z_index = Z.FOREGROUND
	fx.animation_finished.connect(fx.queue_free)
	fx.play("boom")
	add_child(fx)


func add_score(points: int) -> void:
	score += points
	_update_hud()


func hurt_from(x: float) -> void:
	_hurt(x)


## the camera shakes (Saltmire Juice): a short shake for small bumps, a longer one punches harder
func shake(seconds: float) -> void:
	if Game.settings.shake: # a setting: some people don't like a shaking screen
		Juice.shake(_cam, clampf(seconds * 3.0, 0.25, 0.8))


## keep the camera between two x positions (the boss arena)
func set_camera_range(from_x: float, to_x: float) -> void:
	_cam.limit_left = int(from_x)
	_cam.limit_right = int(to_x)


## the whole screen flashes a colour for a moment
func flash(color: Color) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	var tw := rect.create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 0.3)
	tw.tween_callback(layer.queue_free)


## a word that floats up from the action ("DIZZY!", "MEOW!")
func pop_text(at: Vector2, text: String) -> void:
	var l := UI.text(text, 26, UI.GOLD, "bold")
	l.position = at - Vector2(text.length() * 7, 0)
	l.z_index = 9
	l.scale = Vector2(0.6, 0.6)
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", at.y - 40, 0.25)
	tw.tween_interval(0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func boss_beaten() -> void:
	_finish()

func add_gem() -> void:
	gems += 1
	score += 100
	if gems % 100 == 0:
		Game.state.lives += 1
		banner("1 UP", "100 gems")
	_update_hud()


## a gem popping out of a gift box
func pop_gem(at: Vector2) -> void:
	add_gem()
	var gem := AnimatedSprite2D.new()
	gem.sprite_frames = Game.sprite_frames({ "spin": ["gem", [0, 1, 2, 1], 12, true] })
	gem.play("spin")
	gem.position = at
	gem.z_index = Z.ITEM
	add_child(gem)
	var tw := gem.create_tween()
	tw.tween_property(gem, "position:y", at.y - 70, 0.45)
	tw.parallel().tween_property(gem, "modulate:a", 0.0, 0.45)
	tw.tween_callback(gem.queue_free)


func spawn_powerup(kind: String, at: Vector2, from_x: float) -> void:
	var p: CharacterBody2D = preload("res://scripts/powerup.gd").new()
	p.kind = kind
	p.level = self
	p.from_x = from_x
	p.position = at
	p.z_index = Z.ITEM
	add_child.call_deferred(p)


func collect_powerup(item: Node2D) -> void:
	if item.get_meta("taken", false):
		return
	item.set_meta("taken", true)
	score += 1000
	match item.kind:
		"cupcake":
			player.shield = true
			banner("CUPCAKE SHIELD", "Survives one hit")
		"star":
			player.star_time = 8.0
			banner("STAR POWER", "")
		"heart":
			hearts = mini(Game.state.max_hearts, hearts + 1)
		"balloon":
			player.float_time = 15.0
			banner("BALLOON!", "Jump again in mid-air, hold jump to glide")
		"magnet":
			player.magnet_time = 15.0
			banner("GEM MAGNET!", "Gems fly to you")
		"fire", "arrow":
			player.power = item.kind
			banner("MAGIC ARROW!" if item.kind == "arrow" else "FIRE MAGIC!", "Defeat animals to charge your magic")
	_update_hud()
	var tw := item.create_tween()
	tw.tween_property(item, "scale", Vector2(1.5, 1.5), 0.15)
	tw.parallel().tween_property(item, "modulate:a", 0.0, 0.15)
	tw.tween_callback(item.queue_free)


## a secret block found: an extra life
func secret_block(_at: Vector2) -> void:
	Game.state.lives += 1
	_update_hud()
	banner("SECRET!", "1 UP")


## a brick broken from below
func smash(at: Vector2) -> void:
	score += 50
	_update_hud()
	puff_at(at, 14, Color(0.75, 0.35, 0.25))


## gem magnet: nearby gems drift to her
func _pull_gems() -> void:
	if player.magnet_time <= 0:
		return
	var target := player.position + Vector2(0, -60)
	for gem in _gems:
		if is_instance_valid(gem) and not gem.get_meta("taken", false) and gem.position.distance_to(target) < 280:
			gem.position += (target - gem.position) * 0.16


func iris_open() -> void:
	_iris.play(_on_screen(player.position + Vector2(0, -60)), true, 0.6)


func iris_close_on_player(done: Callable) -> void:
	_iris.play(_on_screen(player.position + Vector2(0, -60)), false, 0.45, done)


## where a point of the level is on the screen
func _on_screen(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world


## a burst of dust at her feet (dx: a little behind her, for running kicks)
func puff(count: int, dx := 0.0) -> void:
	puff_at(player.position + Vector2(dx, 0), count)


## a burst of dust (or brick bits) anywhere in the level
func puff_at(at: Vector2, count: int, color := Color(0.85, 0.74, 0.58)) -> void:
	var dust := CPUParticles2D.new()
	dust.position = at + Vector2(0, -4)
	dust.z_index = Z.FOREGROUND
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.amount = count
	dust.lifetime = 0.45
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(14, 2)
	dust.direction = Vector2(0, -1)
	dust.spread = 75.0
	dust.initial_velocity_min = 40.0
	dust.initial_velocity_max = 120.0
	dust.gravity = Vector2(0, 220)
	dust.texture = _soft_dot()
	dust.scale_amount_min = 0.35
	dust.scale_amount_max = 0.7
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 0.8))
	fade.set_color(1, Color(color, 0.0))
	dust.color_ramp = fade
	add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)


var _dot: Texture2D

## a soft round blob (white in the middle, fading out), for dust and sparkles
func _soft_dot() -> Texture2D:
	if not _dot:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 32
		tex.height = 32
		_dot = tex
	return _dot


## a big message in the middle of the screen for a moment
func banner(title: String, subtitle: String, seconds := 1.4) -> void:
	var b: Control = _hud.banner
	_hud.banner_title.text = title.to_upper()
	_hud.banner_sub.text = subtitle
	if b.has_meta("tween"):
		(b.get_meta("tween") as Tween).kill()
	b.position.y = 204
	var tw := b.create_tween().set_parallel()
	tw.tween_property(b, "modulate:a", 1.0, 0.25)
	tw.tween_property(b, "position:y", 190.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(seconds)
	tw.chain().tween_property(b, "modulate:a", 0.0, 0.4)
	b.set_meta("tween", tw)


# ------------------------------------------------------------------ events ---

func _touch_enemy(enemy: Node) -> void:
	if _boss_fight and enemy == _boss_fight.boss:
		_boss_fight.touch(player)
		return
	if enemy.dead:
		return
	if player.star_time > 0:
		enemy.defeat() # star power: knocked out just by touching her
		score += 200
		_charge()
		Game.play_sfx("smash")
		return
	if enemy.is_stomp(player):
		enemy.defeat(true)
		score += 200
		_charge()
		_update_hud()
		Game.play_sfx("stomp")
		player.velocity.y = -STOMP_BOUNCE
		Juice.hitstop(0.045, 0.05) # a tiny freeze on impact makes the stomp land
		shake(0.1)
	else:
		_hurt(enemy.position.x)
		if enemy.info.get("spiky") and player.velocity.y > 0:
			player.velocity.y = -STOMP_BOUNCE # bounced off the snail's shell


func _hurt(from_x: float) -> void:
	if player.safe or _dying or _done:
		return
	player.knockback(from_x)
	if player.shield:
		player.shield = false # the cupcake takes the hit
		return
	hearts -= 1
	shake(0.15)
	Juice.flash(player.look, Color(2.2, 0.7, 0.7))
	_update_hud()
	if hearts <= 0:
		_die()


## falling into a pit costs one heart and Kitty pulls her back onto steady ground
## (a whole life only on her last heart)
func _fell_in_pit() -> void:
	if hearts <= 1 or _last_safe == Vector2.ZERO:
		_die()
		return
	hearts -= 1
	_update_hud()
	player.teleport(_last_safe)
	player.safe_time = 1.5
	kitty.snap()
	banner("OOPS!", "Kitty pulled you back up", 1.0)


## remember where she last stood on steady ground, with a tile of ground on both sides
func _note_safe_ground() -> void:
	if not player.is_on_floor():
		return
	var y := player.position.y + 8
	var steady := func(x: float) -> bool:
		var c := floori(x / TILE)
		var r := floori(y / TILE)
		return _solid(c, r) and _grid[r][c] != "~"
	if steady.call(player.position.x - 76) and steady.call(player.position.x + 76):
		_last_safe = player.position


func _reach_checkpoint() -> void:
	_checkpoint_reached = true
	_respawn = Vector2(def.checkpoint * TILE + TILE / 2.0, GROUND_Y)
	var balloons: Node2D = get_node("CheckpointBalloons")
	var tw := create_tween()
	tw.tween_property(balloons, "scale", Vector2(1.2, 1.2), 0.16)
	tw.tween_property(balloons, "scale", Vector2.ONE, 0.16)
	Game.play_sfx("checkpoint")
	banner("CHECKPOINT", "")


## classic: she pops up and falls through everything, then tries again at the checkpoint
func _die() -> void:
	_dying = true
	Game.state.lives -= 1
	_update_hud()
	player.frozen = true
	player.look.play("hurt")
	Game.play_sfx("lose")
	for c in player.get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	player.hanging = {}
	var tw := create_tween()
	tw.tween_property(player, "position:y", player.position.y - 120, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "position:y", 12 * TILE + 200, 0.7).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _iris.play(get_viewport_rect().size / 2, false, 0.6, _respawn_after_death))


func _respawn_after_death() -> void:
	if Game.state.lives < 0:
		banner("GAME OVER", "", 2.0)
		Game.state.lives = 7 # start the world again with full lives
		_respawn = _start_pos()
	for c in player.get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", false)
	hearts = Game.state.max_hearts
	player.charges = 0
	player.teleport(_respawn)
	player.frozen = false
	player.safe_time = 1.5
	kitty.snap()
	_dying = false
	_update_hud()
	iris_open()


func _finish() -> void:
	_done = true
	player.frozen = true
	player.velocity = Vector2.ZERO
	player.look.flip_h = false
	player.look.play("victory")
	banner("COURSE CLEAR!", "", 99.0)
	Game.play_sfx("win")
	finished.emit()
