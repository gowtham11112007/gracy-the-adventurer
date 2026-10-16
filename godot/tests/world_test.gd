extends SceneTree
## Checks the world map data (data/world.json) and its rules (scripts/world.gd), and that the map screen builds.
## Run from the godot folder:  Godot --headless --path . --script res://tests/world_test.gd

const World := preload("res://scripts/world.gd")
var _fails := 0


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	await process_frame
	root.get_node("Game").slot = 0 # nothing these checks do is written to a real save slot
	var rooms: Array = World.rooms()
	var ids: Array = rooms.map(func(r: Dictionary) -> String: return r.id)
	_check(rooms.size() >= 30, "the world has %d rooms" % rooms.size())

	var spots := {}
	var overlap := false
	for r: Dictionary in rooms:
		var key := "%d,%d" % [r.x, r.y]
		overlap = overlap or spots.has(key)
		spots[key] = true
	_check(not overlap, "no two rooms sit on the same map cell")

	var bad_edge := false
	var gates := ["", "dash", "double_jump", "wall_jump", "candles:3"]
	for e: Dictionary in World.edges():
		bad_edge = bad_edge or not (ids.has(e.from) and ids.has(e.to) and gates.has(e.gate))
	_check(not bad_edge, "every connection joins two real rooms and uses a known door")

	var solved := World.solve()
	_check(solved.reached.size() == rooms.size(), "all %d rooms can be reached by playing in order" % rooms.size())
	_check(solved.abilities.size() == 3, "she learns all three moves along the way")
	_check(solved.candles == 5, "all five candles can be found")

	# the doors really do hold things back
	_check(not World.reachable([], 0, World.start()).has("s1"), "the Sky Ruins are closed without dash")
	_check(World.reachable(["dash"], 0, World.start()).has("s1"), "dash opens the Sky Ruins")
	_check(not World.reachable(["dash", "double_jump", "wall_jump"], 2, World.start()).has("y3"), "Yuva's gate stays shut with only 2 candles")
	_check(World.reachable(["dash", "double_jump", "wall_jump"], 3, World.start()).has("y4"), "3 candles and every move reach Yuva's arena")

	# not one-sided: the world must spread in all four directions around the hub
	var hub: Dictionary = World.room("w2")
	var dirs := { "north": false, "south": false, "east": false, "west": false }
	for r: Dictionary in rooms:
		dirs.north = dirs.north or r.y < hub.y - 1
		dirs.south = dirs.south or r.y > hub.y + 1
		dirs.east = dirs.east or r.x > hub.x + 2
		dirs.west = dirs.west or r.x < hub.x - 2
	_check(dirs.north and dirs.south and dirs.east and dirs.west, "the world spreads in all four directions from the hub")

	var loops: int = World.edges().size() - rooms.size() + 1 # extra connections beyond a tree: loops and shortcuts
	_check(loops >= 3, "there are %d loops and shortcuts (not just long dead-end corridors)" % loops)

	var benches := 0
	var areas := {}
	for r: Dictionary in rooms:
		if r.has.has("bench"):
			benches += 1
			areas[r.area] = true
	_check(benches >= 5 and areas.size() >= 5, "%d benches across %d areas" % [benches, areas.size()])

	# the playable rooms: they match the world map, and their doors lead where the map says
	var game0: Node = root.get_node("Game")
	var built := 0
	var rooms_ok := true
	for r: Dictionary in rooms:
		var def: Dictionary = game0.room_def(r.id)
		if def.is_empty():
			continue
		built += 1
		rooms_ok = rooms_ok and def.grid.size() == 12 and def.grid.all(func(row: String) -> bool: return row.length() == int(def.width))
		for ex: Dictionary in def.exits:
			if ex.to.is_empty():
				continue
			var back: Dictionary = game0.room_def(ex.to)
			var joined := false
			for n: Dictionary in World.neighbors(r.id):
				joined = joined or n.room == ex.to
			var returns := false
			if not back.is_empty():
				for bx: Dictionary in back.exits:
					returns = returns or bx.to == r.id
			rooms_ok = rooms_ok and joined and (returns or back.is_empty())
	_check(built == rooms.size() and rooms_ok, "%d rooms are built, joined as the world map says, and every door has a way back" % built)

	# walking off the right edge of the Birthday Glade leads into Windmill Road, arriving on its left
	var m1: Node2D = load("res://scripts/level.gd").new()
	m1.def = game0.room_def("m1")
	root.add_child(m1)
	await physics_frame
	var heard := []
	m1.exited.connect(func(to: String, arrive: String) -> void: heard.append([to, arrive]))
	_check(is_equal_approx(m1.player.position.x, 3 * 64 + 32.0), "she starts in the Birthday Glade at its start")
	m1.player.position.x = (int(m1.def.width) - 0.2) * 64
	for i in 80:
		await physics_frame
	_check(heard == [["m2", "left"]], "walking off the right edge goes to Windmill Road, arriving on its left")
	m1.queue_free()

	# the Dash Shrine's east door needs the shrine's blessing: a wall until she has it, then open
	var keep_abilities: Array = game0.save.abilities.duplicate()
	game0.save.abilities = []
	var w6: Node2D = load("res://scripts/level.gd").new()
	w6.def = game0.room_def("w6")
	root.add_child(w6)
	await physics_frame
	w6.player.position.x = (int(w6.def.width) - 0.2) * 64
	await physics_frame
	await physics_frame
	_check(w6.player.position.x < int(w6.def.width) * 64 - 20 and not w6._done, "a closed door is a wall: she can't leave without the shrine's blessing")
	w6.player.position = Vector2(int(w6.def.shrine.col) * 64 + 32, 640)
	for i in 10:
		await physics_frame
	_check(game0.has_ability("dash"), "touching the Dash Shrine gives her its blessing")
	var heard6 := []
	w6.exited.connect(func(to: String, arrive: String) -> void: heard6.append(to))
	w6.player.position.x = (int(w6.def.width) - 0.2) * 64
	for i in 60:
		await physics_frame
	_check(heard6 == ["w7"], "and then the door opens to the Wide Gap")
	w6.queue_free()
	game0.save.abilities = keep_abilities

	# a doorway above: climb the ladder in Windmill Road, stand in the arch, press Up: Hilltop, arriving in
	# its lower doorway
	var m2u: Node2D = load("res://scripts/level.gd").new()
	m2u.def = game0.room_def("m2")
	root.add_child(m2u)
	await physics_frame
	var up_door: Dictionary = m2u.def.exits.filter(func(e: Dictionary) -> bool: return e.side == "up")[0]
	var heard_up := []
	m2u.exited.connect(func(to: String, arrive: String) -> void: heard_up.append([to, arrive]))
	m2u.player.teleport(Vector2(int(up_door.col) * 64 + 32, int(up_door.row) * 64 - 2))
	for i in 10:
		await physics_frame
	Input.action_press("up")
	await physics_frame
	await physics_frame
	Input.action_release("up")
	for i in 60:
		await physics_frame
	_check(heard_up == [["m4", "down"]], "Up in the doorway on the upper floor goes to the Hilltop above")
	m2u.queue_free()
	var m4: Node2D = load("res://scripts/level.gd").new()
	m4.def = game0.room_def("m4")
	m4.entry = "down"
	root.add_child(m4)
	await physics_frame
	var down_door: Dictionary = m4.def.exits.filter(func(e: Dictionary) -> bool: return e.side == "down")[0]
	_check(absf(m4.player.position.x - (int(down_door.col) * 64 + 32)) < 1, "she arrives in the Hilltop's lower doorway")
	m4.queue_free()

	# the ladder in Windmill Road takes her up to the second floor, and she can walk off it (holding Up the whole
	# way used to leave her stuck on the ladder top)
	var m2: Node2D = load("res://scripts/level.gd").new()
	m2.def = game0.room_def("m2")
	root.add_child(m2)
	await physics_frame
	var ladder_col := String(m2.def.grid[5]).find("L")
	m2.player.position = Vector2(ladder_col * 64 + 32, 640)
	Input.action_press("up")
	for i in 150:
		await physics_frame
	Input.action_release("up")
	_check(not m2.player.climbing and m2.player.is_on_floor() and m2.player.position.y < 330.0, "holding Up carries her up the ladder and onto the second floor")
	Input.action_press("right")
	for i in 25: # (a bit longer and she meets the snail up there)
		await physics_frame
	Input.action_release("right")
	_check(m2.player.position.x > ladder_col * 64 + 100, "and she walks along the upper floor")
	m2.queue_free()

	# the map screen builds and draws
	var game: Node = root.get_node("Game")
	var keep_slot: int = game.slot
	game.slot = 0 # nothing is written
	game.save.rooms_seen = ["m1", "m2"]
	game.save.room = "m2"
	var map: CanvasLayer = load("res://scripts/map_screen.gd").new()
	root.add_child(map)
	await process_frame
	await process_frame
	_check(map.get_child_count() >= 3, "the map screen builds")
	map.close()
	game.slot = keep_slot

	print("\n%s" % ("ALL WORLD TESTS PASSED" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)
