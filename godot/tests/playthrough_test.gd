extends SceneTree
## Plays the whole world: in every room, a robot Janani runs from one side to the other (both ways, wherever
## there's a door), hopping the obstacles and gaps by herself, and every doorway and bench is a place she
## can stand. Animals can't hurt her here (this is about the layouts, not the fights).
## Run from the godot folder:  Godot --headless --path . --script res://tests/playthrough_test.gd

const World := preload("res://scripts/world.gd")
const TILE := 64
var _fails := 0


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.slot = 0 # nothing is written to a real save
	game.save.abilities = ["dash", "double_jump", "wall_jump"]
	game.save.candles = ["a", "b", "c"]
	var stuck: Array = []
	var crossed := 0
	for r: Dictionary in World.rooms():
		var def: Dictionary = game.room_def(r.id)
		for ex: Dictionary in def.exits:
			if ex.side != "left" and ex.side != "right":
				continue
			var from := "right" if ex.side == "left" else "left"
			var ok: bool = await _cross(def, from, ex.side)
			crossed += 1
			if not ok:
				stuck.append("%s (%s to %s)" % [r.id, from, ex.side])
	_check(stuck.is_empty(), "she runs and hops across all %d room crossings %s" % [crossed, stuck])

	var bad_spots: Array = []
	for r: Dictionary in World.rooms():
		var def: Dictionary = game.room_def(r.id)
		var entries: Array = def.exits.map(func(e: Dictionary) -> String: return e.side)
		if not def.benches.is_empty():
			entries.append("bench")
		for entry: String in entries:
			var level := _open(def, entry)
			await physics_frame
			for i in 20:
				await physics_frame
			if not level.player.is_on_floor() or level.player.position.y > 11 * TILE:
				bad_spots.append("%s/%s" % [r.id, entry])
			level.free()
	_check(bad_spots.is_empty(), "she lands on solid floor at every door, doorway and bench %s" % [bad_spots])
	print("\n%s" % ("ALL PLAYTHROUGH TESTS PASSED" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)


func _open(def: Dictionary, entry: String) -> Node2D:
	var level: Node2D = load("res://scripts/level.gd").new()
	level.def = def
	level.entry = entry
	root.add_child(level)
	return level


## she runs from one side of the room to the other: true if she leaves through the far door in time
func _cross(def: Dictionary, from: String, to_side: String) -> bool:
	var level := _open(def, from)
	await physics_frame
	var left: Array = []
	level.exited.connect(func(_to: String, _arrive: String) -> void: left.append(true))
	var p: CharacterBody2D = level.player
	var dir := 1.0 if to_side == "right" else -1.0
	var run := "right" if dir > 0 else "left"
	var grid: Array = def.grid
	Input.action_press(run)
	var ok := false
	for i in 60 * 40: # 40 seconds at most
		p.safe_time = 9.0 # animals can't stop her
		var c := floori((p.position.x + dir * 60) / TILE)
		var pit_c := floori((p.position.x + dir * 24) / TILE)
		var ahead := c >= 0 and c < int(def.width) and "CRO^".contains(String(grid[9])[c])
		var pit := pit_c >= 0 and pit_c < int(def.width) and String(grid[10])[pit_c] == " "
		if (ahead or pit) and p.is_on_floor():
			Input.action_press("jump")
		elif p.is_on_floor():
			Input.action_release("jump")
		await physics_frame
		if not left.is_empty():
			ok = true
			break
	Input.action_release(run)
	Input.action_release("jump")
	level.free()
	return ok
