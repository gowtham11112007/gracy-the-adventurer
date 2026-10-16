extends SceneTree
## Checks the World 1 gameplay pieces in real levels: gift boxes and power-ups, secret blocks, crumbling
## blocks, secret rooms, ropes, moving platforms and doors. Run from the godot folder:
##   Godot --headless --path . --script res://tests/feature_test.gd

const TILE := 64
var _fails := 0


func _initialize() -> void:
	await process_frame # let the Game autoload load its data first
	await _test_gift_box()
	await _test_secret_block()
	await _test_crumble()
	await _test_secret_room()
	await _test_rope()
	await _test_mover()
	await _test_door()
	await _test_star_power()
	await _test_magic()
	await _test_boss()
	await _test_beta_outfit()
	await _test_every_beta()
	await _test_sword()
	print("\n%s" % ("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _open(index: int) -> Node2D:
	for child in root.get_children():
		if child.name == "TestLevel":
			child.free()
	var level: Node2D = load("res://scripts/level.gd").new()
	level.name = "TestLevel"
	level.def = root.get_node("Game").levels.solo[index]
	root.add_child(level)
	await physics_frame
	return level


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _find(level: Node2D, ch: String) -> Vector2i:
	var grid: Array = level.def.grid
	for r in grid.size():
		var c: int = String(grid[r]).find(ch)
		if c >= 0:
			return Vector2i(c, r)
	return Vector2i(-1, -1)


func _stand_under(level: Node2D, cell: Vector2i) -> void:
	level.player.teleport(Vector2(cell.x * TILE + TILE / 2.0, 10 * TILE))
	await _wait(0.2)


func _test_gift_box() -> void:
	var level := await _open(0)
	var cell := _find(level, "+") # a cupcake box
	await _stand_under(level, cell)
	level.player.jump()
	await _wait(0.7)
	_check(level.blocks.state_at(cell.x, cell.y) == 1 and level.blocks._blocks[cell].kind == "used", "gift box opens when bumped")
	var cupcake := level.find_children("*", "CharacterBody2D", true, false).filter(func(n): return n.get("kind") == "cupcake")
	_check(cupcake.size() == 1, "a cupcake pops out")
	if cupcake.size() == 1:
		level.collect_powerup(cupcake[0])
		_check(level.player.shield, "the cupcake gives a shield")


func _test_secret_block() -> void:
	var level := await _open(0)
	var cell := _find(level, "H")
	var lives: int = root.get_node("Game").state.lives
	await _stand_under(level, cell)
	level.player.jump()
	await _wait(0.7)
	_check(root.get_node("Game").state.lives == lives + 1 and level.blocks.state_at(cell.x, cell.y) == 1, "secret block appears with an extra life")


func _test_crumble() -> void:
	for i in 5:
		var level := await _open(i)
		var cell := _find(level, "~")
		if cell.x < 0:
			continue
		level.player.teleport(Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE - 2))
		await _wait(1.0)
		_check(level.blocks.state_at(cell.x, cell.y) == 0, "dirt block crumbles under her (level %s)" % level.def.id)
		return


func _test_secret_room() -> void:
	var level := await _open(0)
	var room: Array = level.def.secrets[0]
	level.player.teleport(Vector2(room[0] * TILE + TILE / 2.0, (room[1] + room[3]) * TILE - 2))
	await _wait(0.3)
	var found: bool = level._secrets._fakes.any(func(f): return f.found)
	_check(found, "secret room turns see-through when she steps inside")


func _test_rope() -> void:
	var level := await _open(0)
	var p: CharacterBody2D = level.player
	var ropes: Node2D = level.find_children("*", "Node2D", false, false).filter(func(n): return n.has_method("_try_grab"))[0]
	# jump into the rope's swinging end, like she would
	for i in 30:
		var r: Dictionary = ropes._ropes[0]
		var end := Vector2(r.ax + sin(r.angle) * r.len, r.ay + cos(r.angle) * r.len)
		if p.hanging.is_empty():
			p.teleport(end + Vector2(0, 70))
		await physics_frame
	_check(not p.hanging.is_empty(), "she grabs the rope")
	await _wait(0.6)
	p.wants_release = true
	await _wait(0.05)
	_check(p.hanging.is_empty() and p.velocity.y < 0, "jump lets go of the rope and launches her")


func _test_mover() -> void:
	var level := await _open(4)
	var body: Node2D = level.find_children("*", "AnimatableBody2D", true, false)[0]
	var before := body.position
	await _wait(0.8)
	_check(body.position.distance_to(before) > 5, "moving platform moves")


func _test_door() -> void:
	var level := await _open(3)
	var door: Array = level.def.doors[0] # HEAVEN: the trap, sends her back
	level.player.teleport(Vector2(door[0] * TILE + TILE / 2.0, door[1] * TILE))
	await _wait(1.6)
	_check(absf(level.player.position.x - (door[3] * TILE + TILE / 2.0)) < 40, "Heaven door sends her back")


## the wardrobe's Beta outfit: the new detailed Janani in a level; a missing outfit falls back safely
func _test_beta_outfit() -> void:
	var game := root.get_node("Game")
	var before: String = game.save.get("outfit", "beta")
	game.save.outfit = "beta"
	var level := await _open(0)
	var p: CharacterBody2D = level.player
	var run: Texture2D = p.look.sprite_frames.get_frame_texture("run", 0)
	_check(p.outfit == "beta" and run.get_width() == int(game.hd.beta.cell), "the Beta outfit uses the new detailed Janani")
	_check(p.look.sprite_frames.has_animation("rise") and p.look.sprite_frames.has_animation("hurt"), "with her jump and hurt moves")
	game.save.outfit = "no-such-outfit"
	_check(game.outfit() == "beta", "a missing outfit falls back to the beta version")
	game.save.outfit = before


## every Spriterrific set in the wardrobe (Beta 1..7) builds all her animations, and no frame points outside its strip
func _test_every_beta() -> void:
	var game := root.get_node("Game")
	var needed := ["idle", "walk", "run", "takeoff", "rise", "peak", "fall", "land", "hurt", "victory"]
	var bad: Array = []
	for o: Dictionary in game.OUTFITS:
		var sf: SpriteFrames = game.detailed_frames(o.id)
		if sf == null:
			bad.append(o.id + " (no data)")
			continue
		for anim: String in needed:
			if not sf.has_animation(anim) or sf.get_frame_count(anim) == 0:
				bad.append("%s/%s (empty)" % [o.id, anim])
				continue
			for i in sf.get_frame_count(anim):
				var t := sf.get_frame_texture(anim, i) as AtlasTexture
				if t == null or t.region.end.x > t.atlas.get_width() or t.region.end.y > t.atlas.get_height():
					bad.append("%s/%s frame %d (outside its strip)" % [o.id, anim, i])
					break
	_check(bad.is_empty() and game.OUTFITS.size() == 7, "all %d Beta sets build every animation inside their strips %s" % [game.OUTFITS.size(), bad])


## her sword (the AutoSprite slash, on the "25" sets): an animal in front of her is knocked out, one behind isn't
func _test_sword() -> void:
	var game := root.get_node("Game")
	var before: String = game.save.get("outfit", "beta")
	game.save.outfit = "beta7"
	var level := await _open(0)
	var p: CharacterBody2D = level.player
	_check(p.look.sprite_frames.get_frame_count("slash") > 10 and p.look.sprite_frames.get_frame_count("climb") > 10, "the \"25\" Janani has her sword slash and ladder climb")
	var enemies: Array = level._enemies.duplicate()
	enemies.sort_custom(func(a, b): return a.position.x < b.position.x)
	var target: Node = enemies[0]
	p.teleport(target.position + Vector2(-260, 0)) # out of reach
	p.look.flip_h = false
	await _wait(0.1)
	p.slash()
	await _wait(0.3)
	_check(not target.dead, "the sword doesn't reach far-away animals")
	await _wait(0.4)
	p.teleport(target.position + Vector2(-130, 0))
	await physics_frame
	p.slash()
	await _wait(0.3)
	_check(target.dead and p.charges == 1, "a sword slash knocks out the animal in front of her (and charges her magic)")
	game.save.outfit = before


func _test_star_power() -> void:
	var level := await _open(0)
	var p: CharacterBody2D = level.player
	p.star_time = 8.0
	var enemy: Node = level._enemies[1]
	p.teleport(enemy.position + Vector2(-30, 0))
	await _wait(0.3)
	_check(enemy.dead, "star power knocks out an enemy she touches")
	_check(level.hearts == root.get_node("Game").state.max_hearts, "and she isn't hurt")


func _test_magic() -> void:
	var level := await _open(0)
	var p: CharacterBody2D = level.player
	_check(p.charges == 0, "no magic at the start")
	var enemies: Array = level._enemies.duplicate()
	enemies.sort_custom(func(a, b): return a.position.x < b.position.x)
	var stomped: Node = enemies[0] # mushroom at col 24
	p.teleport(stomped.position + Vector2(0, -150))
	p.velocity.y = 400
	await _wait(0.4)
	_check(stomped.dead and p.charges == 1, "defeating an animal charges her magic")
	var enemy: Node = enemies[1] # mushroom at col 26
	p.teleport(enemy.position + Vector2(-260, 0))
	p.look.flip_h = false # facing the enemy
	await _wait(0.1)
	level._shoot()
	_check(p.charges == 0, "a throw uses the charge")
	await _wait(1.0)
	_check(enemy.dead, "a fireball knocks out an animal")
	level._shoot()
	await _wait(0.1)
	_check(level.get_children().filter(func(n): return n.get("kind") == "fire" and n.get("dir") != null).is_empty(), "no charge, no fireball")
	p.power = "arrow"
	p.charges = 1
	## mushroom at col 99 has 8 tiles of flat ground in front of it (no hills blocking the shot)
	var far: Node = level._enemies.filter(func(e): return is_instance_valid(e) and e.kind == "mushroom" and e.position.x > 6000)[0]
	p.teleport(far.position + Vector2(-500, 0))
	p.look.flip_h = false
	await _wait(0.1)
	level._shoot()
	await _wait(0.9)
	_check(far.dead, "a fire arrow hits an animal far away")


func _test_boss() -> void:
	var level := await _open(4)
	var p: CharacterBody2D = level.player
	var fight: Node2D = level._boss_fight
	p.safe_time = 999.0 # the test isn't about dodging bombs
	p.teleport(Vector2(fight.left + 4 * TILE, 10 * TILE))
	await _wait(3.5)
	_check(fight.boss != null and is_instance_valid(fight.boss), "Yuva drops into the arena")
	_check(level.kitty.powered, "Kitty turns into Super Kitty")
	var stunned := false
	for i in 160: # watch for up to 16 seconds (boss leap and bomb timing varies by RNG)
		await _wait(0.1)
		if fight.boss.mode == "stunned":
			stunned = true
			break
	_check(stunned, "Super Kitty pounces on Yuva and leaves him dizzy")
	for i in 3:
		for t in 40:
			if fight.boss.invuln <= 0 and fight.boss.is_on_floor():
				break
			await _wait(0.1)
		p.teleport(Vector2(fight.boss.position.x, fight.boss.head_y - 4))
		p.velocity.y = 300
		await _wait(0.3)
	_check(fight.boss.defeated, "three stomps beat Yuva")
	await _wait(2.5)
	_check(level._done, "beating Yuva finishes the level")
