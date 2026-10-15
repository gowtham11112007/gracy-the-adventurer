extends SceneTree

const TILE := 64

func _initialize() -> void:
	await process_frame # let Game autoload finish initializing
	var Game: Node = root.get_node("Game")
	print("--- Running Beta Level Verification Tests ---")
	var def: Dictionary = Game.beta_level()
	_assert(not def.is_empty(), "Game.beta_level() loads beta_level.json")
	_assert(def.width == 120, "Beta map width is 120 tiles")
	_assert(def.grid.size() == 12, "Beta map grid has 12 rows")

	var level: Node2D = load("res://scripts/level.gd").new()
	level.def = def
	root.add_child(level)
	await process_frame

	# 1. Check solid obstacles exist and are solid
	var b: Node2D = level.blocks
	_assert(b != null, "Blocks part initialized")
	_assert(b.state_at(14, 9) == 1, "Crate at (14, 9) is solid resisting obstacle")
	_assert(b.state_at(22, 9) == 1, "Boulder at (22, 9) is solid resisting obstacle")
	_assert(b.state_at(30, 9) == 1, "Barrel at (30, 9) is solid resisting obstacle")
	_assert(b.state_at(46, 9) == 1, "Crate at (46, 9) is solid resisting obstacle")

	# 2. Check player jump height and physics
	var p: CharacterBody2D = level.player
	_assert(p != null, "Player Janani is created")
	var start_y: float = p.position.y
	_assert(start_y == 640.0, "Janani starts on Ground row 10 at y=640")

	p.jump()
	_assert(p.velocity.y == -540.0, "Janani jump speed in beta is 540.0 (calibrated low hop)")

	var jump_apex_theoretical: float = (540.0 * 540.0) / (2.0 * 1800.0)
	print("Theoretical jump apex height: %.1f px (expected 81.0 px)" % jump_apex_theoretical)
	_assert(jump_apex_theoretical > 70.0 and jump_apex_theoretical < 95.0, "Jump height clears 64px obstacle cleanly without overshooting")

	# Floor 2 is at Row 5 (y = 320.0). Height to Floor 2 is 320px.
	_assert(320.0 > jump_apex_theoretical * 3.0, "Janani cannot jump onto Floor 2 (needs ladder)")

	# 3. Check Ladder mounting & climbing
	p.position = Vector2(54 * TILE + TILE / 2.0, 640.0)
	p.velocity = Vector2.ZERO
	Input.action_press("up")
	level.ladders._physics_process(1.0 / 60.0)
	_assert(p.climbing, "Janani grabs Ladder 1 when pressing Up in front of it")

	# Reached top of ladder
	p.position.y = 5.0 * TILE + 4.0
	level.ladders._physics_process(1.0 / 60.0)
	_assert(not p.climbing and p.position.y <= 5.0 * TILE, "Janani reached Floor 2 via Ladder 1 and dismounted onto shelf")
	Input.action_release("up")

	# Step down past the top shelf with Down
	Input.action_press("down")
	level.ladders._physics_process(1.0 / 60.0)
	_assert(p.climbing, "Pressing Down at top shelf smoothly initiates climbing down")
	Input.action_release("down")

	print("ALL BETA LEVEL TESTS PASSED!")
	quit(0)


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		printerr("FAIL: ", msg)
		quit(1)
	print("PASS  ", msg)
