extends Node2D
## Ladders for climbing between floors. Janani grabs a ladder with Up or Down,
## climbs smoothly, and can hop off with Jump or step onto the upper platform at the top.

const TILE := 64
const CLIMB_SPEED := 200.0

var level: Node2D
var _ladders: Array[Rect2] = []
var _top_rungs: Dictionary = {} ## col -> highest row of ladder
var _bot_rungs: Dictionary = {} ## col -> lowest row of ladder
var _climb_col := -1
var _no_grab := false ## just stepped off the top: Up must be let go before a ladder grabs her again


func build(grid: PackedStringArray, width: int) -> void:
	_ladders.clear()
	_top_rungs.clear()
	_bot_rungs.clear()
	_climb_col = -1
	for child in get_children():
		child.queue_free()
	for r in grid.size():
		for c in width:
			if c < grid[r].length() and grid[r][c] == "L":
				var pic := Sprite2D.new()
				pic.texture = Game.texture("ladder")
				pic.centered = false
				pic.position = Vector2(c * TILE, r * TILE)
				pic.z_index = -1 # Janani climbs in front of the rungs
				add_child(pic)
				_ladders.append(Rect2(c * TILE, r * TILE, TILE, TILE))
				if not _top_rungs.has(c) or r < _top_rungs[c]:
					_top_rungs[c] = r
				if not _bot_rungs.has(c) or r > _bot_rungs[c]:
					_bot_rungs[c] = r

	# Build a one-way collision shelf at the top of each ladder so Janani can stand on it
	for c: int in _top_rungs:
		var top_r: int = _top_rungs[c]
		var shelf := StaticBody2D.new()
		shelf.collision_layer = 1
		shelf.collision_mask = 0
		var box := RectangleShape2D.new()
		box.size = Vector2(TILE, 8)
		var shape := CollisionShape2D.new()
		shape.shape = box
		shape.position = Vector2(c * TILE + TILE / 2.0, top_r * TILE + 4)
		shape.one_way_collision = true
		shape.one_way_collision_margin = 8.0
		shelf.add_child(shape)
		add_child(shelf)


func _physics_process(delta: float) -> void:
	var p: CharacterBody2D = level.player
	if not p or p.frozen:
		return

	var feet := p.position
	var center := Vector2(p.position.x, p.position.y - 56)
	var col := int(floor(p.position.x / TILE))
	var on_any_ladder := false
	var ladder_col := -1

	for box in _ladders:
		# generous grab area near ladder
		var grab_box := Rect2(box.position.x - 8, box.position.y - 8, box.size.x + 16, box.size.y + 16)
		if grab_box.has_point(feet) or grab_box.has_point(center):
			on_any_ladder = true
			ladder_col = int(box.position.x / TILE)
			break

	var wants_up := Input.is_action_pressed("up")
	var wants_down := Input.is_action_pressed("down")

	if not wants_up:
		_no_grab = false
	if not p.climbing:
		# Mount ladder when pressing up while in front of ladder
		if on_any_ladder and wants_up and not _no_grab:
			p.climbing = true
			_climb_col = ladder_col
			p.position.x = _climb_col * TILE + TILE / 2.0
			p.velocity = Vector2(0, -CLIMB_SPEED)
		# Or climbing down when standing on platform above a ladder
		elif _top_rungs.has(col) and wants_down and p.is_on_floor():
			var top_y: float = _top_rungs[col] * TILE
			if absf(feet.y - top_y) < 20:
				p.climbing = true
				_climb_col = col
				p.position.x = _climb_col * TILE + TILE / 2.0
				p.position.y = top_y + 16 # step down past the one-way shelf!
				p.velocity = Vector2(0, CLIMB_SPEED)
	else:
		if _climb_col < 0:
			_climb_col = col

		# Currently climbing
		# Pressing jump hops off the ladder (not the keyboard's Up key, which is also a jump key: tapping Up
		# again while climbing must keep her climbing)
		if Input.is_action_just_pressed("jump") and not Input.is_action_pressed("up"):
			p.climbing = false
			_climb_col = -1
			var h := Input.get_axis("left", "right")
			p.velocity = Vector2(h * 240.0, -380.0)
			return

		# Center on ladder
		p.position.x = lerpf(p.position.x, _climb_col * TILE + TILE / 2.0, minf(1.0, 18.0 * delta))
		p.velocity.x = 0

		# Move up / down
		if wants_up:
			p.velocity.y = -CLIMB_SPEED
		elif wants_down:
			p.velocity.y = CLIMB_SPEED
		else:
			p.velocity.y = 0

		# Reached top platform: step onto the floor shelf
		if _top_rungs.has(_climb_col):
			var top_y: float = _top_rungs[_climb_col] * TILE
			var sideways := Input.get_axis("left", "right")
			if p.position.y <= top_y + 8 and (wants_up or sideways != 0.0):
				p.climbing = false
				p.position.y = top_y
				p.velocity = Vector2(sideways * 160.0, 0.0) # (left or right at the top steps straight off the ladder)
				_climb_col = -1
				_no_grab = true # holding Up must not grab the ladder again
				return

		# Reached bottom floor: step onto the ground
		if _bot_rungs.has(_climb_col):
			var bot_y: float = (_bot_rungs[_climb_col] + 1) * TILE
			if p.position.y >= bot_y and wants_down:
				p.climbing = false
				p.position.y = bot_y
				p.velocity = Vector2.ZERO
				_climb_col = -1
				return
