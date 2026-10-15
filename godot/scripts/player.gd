extends CharacterBody2D
## Janani: running, jumping, her power-ups and hanging on ropes.
## Same numbers as the original game (game/src/objects/Player.js), so she moves the way the twins know.

signal jumped
signal landed(speed: float)
signal air_jumped

const GRAVITY := 1800.0
const RUN_SPEED := 300.0
const JUMP_SPEED := 1040.0
const MAX_FALL := 1100.0
const COYOTE := 0.14       ## seconds she can still jump after running off a ledge
const JUMP_BUFFER := 0.18  ## a jump pressed this long before landing still counts
const JUMP_HOLD := 0.3     ## a quick tap still gives (almost) the full jump
const SHORT_HOP := 520.0   ## letting go of jump early cuts the rise to this speed
const FALL_PULL := 1.25    ## falling pulls a little harder than rising: a firm, real-feeling arc
                           ## (same jump height; a little less air time, still clears 5-tile gaps)

var outfit := "kurti"
var _rope_outfit := "kurti"  ## whose rope frames she uses (the Beta outfit borrows the white kurti's)
var look: AnimatedSprite2D  ## the picture; the body itself is just a box for collisions
var frozen := false         ## cutscenes, level end
var hurt_time := 0.0        ## seconds of knockback (no control)
var safe_time := 0.0        ## seconds of flashing safety after a hit
# power-ups (from gift boxes)
var shield := false         ## cupcake: survives one extra hit
var star_time := 0.0        ## star: can't be hurt, and enemies she touches are knocked out
var float_time := 0.0       ## balloon: one extra jump in mid-air, and hold jump to glide down
var magnet_time := 0.0      ## magnet: gems fly to her
var power := "fire"        ## the magic she throws: "fire" (bouncing fireballs), or "arrow" from a gift box
var charges := 0           ## magic charges: one for each animal she defeats (up to 3); each throw uses one
# ropes (the level moves her while she hangs)
var hanging: Dictionary = {}   ## the rope she's holding: { rope, along }
var wants_release := false
var last_rope = null           ## can't grab the rope she just let go of until she lands
var leap_time := 0.0           ## just let go of a rope: the leap pose
var rope_look: Sprite2D        ## her picture while hanging (fists at the top)
var climbing := false          ## climbing a ladder
var level: Node2D

## true while she can't be hurt (flashing after a hit, or star power)
var safe: bool:
	get: return safe_time > 0 or star_time > 0

var _air_jumps := 0
var _balloon: Sprite2D
var _bubble: Node2D

var _squash := Vector2.ONE
var _coyote := 0.0
var _buffer := 0.0
var _hold := 0.0
var _jumping := false
var _air_time := 0.0
var _land_time := 0.0
var _was_on_floor := true
var _fall_speed := 0.0


func _ready() -> void:
	var box := RectangleShape2D.new()
	box.size = Vector2(40, 112)
	collision_layer = 2 # Janani's own layer: items, spikes and enemies look for her here
	collision_mask = 1  # she stands on the ground and blocks (layer 1)
	var shape := CollisionShape2D.new()
	shape.shape = box
	shape.position.y = -56 # the body's origin is at her feet
	add_child(shape)
	floor_snap_length = 8.0

	outfit = Game.outfit()
	# the rope frames: the Beta (detailed) Janani has none yet, so she borrows her base outfit's
	_rope_outfit = String(Game.hd[outfit].get("base", "kurti")) if Game.hd.has(outfit) else outfit
	look = AnimatedSprite2D.new()
	look.centered = false
	var detailed := Game.detailed_frames(outfit)
	if detailed: # the new detailed Janani: square cells, feet on the bottom edge
		var cell: int = Game.hd[outfit].cell
		look.sprite_frames = detailed
		look.offset = Vector2(-cell / 2.0, -cell)
	else: # frames are 104x150 with her feet on the bottom edge
		look.offset = Vector2(-52, -150)
		var hero := "hero_" + outfit
		var moves := hero + "_moves"
		var run_frames: int = Game.manifest[moves].get("run", 6)
		look.sprite_frames = Game.sprite_frames({
			"idle": [hero, [0, 0, 0, 0, 1, 0, 0, 2], 4, true],
			"walk": [hero, [7, 8, 9, 10], 7, true],
			"run": [moves, range(run_frames), 15.0 * run_frames / 6, true],
			"takeoff": [moves, [7], 1, false],
			"rise": [moves, [8], 1, false],
			"peak": [moves, [9], 1, false],
			"fall": [moves, [10], 1, false],
			"land": [moves, [11], 1, false],
			"hurt": [hero, [14], 1, false],
			"victory": [hero, [15], 1, false],
		})
	add_child(look)
	look.play("idle")

	# while hanging on a rope: frames with her fists at the top middle (150x200 cells)
	rope_look = Sprite2D.new()
	rope_look.centered = false
	rope_look.visible = false
	add_child(rope_look)
	# the balloon she holds while it lasts, and the cupcake shield's bubble
	_balloon = Sprite2D.new()
	_balloon.texture = Game.texture("balloon_pink")
	_balloon.visible = false
	add_child(_balloon)
	_bubble = preload("res://scripts/shield_bubble.gd").new()
	add_child(_bubble)


func _physics_process(delta: float) -> void:
	star_time -= delta
	float_time -= delta
	magnet_time -= delta
	leap_time -= delta
	if frozen:
		return
	if not hanging.is_empty():
		# on a rope: the only control is letting go with the jump button
		if Input.is_action_just_pressed("jump"):
			wants_release = true
		return
	if climbing:
		_coyote = 0
		_jumping = false
		move_and_slide()
		if absf(velocity.y) > 10:
			look.play("walk")
			look.speed_scale = 1.0
		else:
			look.pause()
		return
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit(_fall_speed)
		var hard := clampf(_fall_speed / 1100.0, 0.3, 1.0)
		_squash = Vector2(1 + 0.22 * hard, 1 - 0.20 * hard)
		if _fall_speed > 420 and absf(velocity.x) < 160:
			_land_time = 0.09 # a quick crouch after a big drop
	_was_on_floor = on_floor
	_fall_speed = velocity.y
	_coyote = COYOTE if on_floor else _coyote - delta
	_buffer = JUMP_BUFFER if Input.is_action_just_pressed("jump") else _buffer - delta
	_hold -= delta
	_land_time -= delta
	hurt_time -= delta
	safe_time -= delta
	_air_time = 0.0 if on_floor else _air_time + delta
	if on_floor:
		_air_jumps = 1
		last_rope = null # back on the ground: every rope can be grabbed again

	# ease toward the target speed so turning feels smooth, a little looser in the air
	var dir := 0.0 if hurt_time > 0 else Input.get_axis("left", "right")
	var grip := 14.0 if on_floor else 7.0
	if hurt_time > 0:
		grip = 0.0 # knocked back: no steering for a moment
	velocity.x += (dir * RUN_SPEED - velocity.x) * minf(1.0, grip * delta)
	if _buffer > 0 and _coyote > 0:
		jump()
	elif Input.is_action_just_pressed("jump") and not on_floor and float_time > 0 and _air_jumps > 0:
		_air_jumps -= 1 # balloon: one extra jump in mid-air
		jump(JUMP_SPEED * 0.85)
		air_jumped.emit()
	# a tap gives an accurate short hop; holding gives the full obstacle-clearing jump
	var is_beta: bool = level != null and level.def.get("id") == "beta"
	if _jumping and not Input.is_action_pressed("jump"):
		if is_beta:
			if velocity.y < -240.0:
				velocity.y = -240.0
		elif _hold <= 0 and velocity.y < -SHORT_HOP:
			velocity.y = -SHORT_HOP
	if velocity.y >= 0:
		_jumping = false
	var pull := GRAVITY * (FALL_PULL if velocity.y > 0 else 1.0)
	velocity.y = minf(velocity.y + pull * delta, MAX_FALL)
	if float_time > 0 and Input.is_action_pressed("jump") and velocity.y > 160:
		velocity.y = 160 # balloon: drift down gently while jump is held
	if dir != 0:
		look.flip_h = dir < 0
	move_and_slide()
	_animate(is_on_floor())


func jump(speed := -1.0) -> void:
	climbing = false
	var sp := speed
	if sp < 0:
		sp = 540.0 if (level and level.def.get("id") == "beta") else JUMP_SPEED
	velocity.y = -sp
	_buffer = 0
	_coyote = 0
	_jumping = true
	_hold = JUMP_HOLD
	_air_time = 0
	_squash = Vector2(0.82, 1.18) # spring upward on take-off
	Game.play_sfx("jump")
	jumped.emit()


func _animate(on_floor: bool) -> void:
	var vx := absf(velocity.x)
	look.speed_scale = 1.0
	if hurt_time > 0:
		look.play("hurt")
	elif not on_floor:
		if _jumping and _air_time < 0.11:
			look.play("takeoff")
		elif velocity.y < -260:
			look.play("rise")
		elif velocity.y < 260:
			look.play("peak")
		else:
			look.play("fall")
	elif _land_time > 0:
		look.play("land")
	elif vx > 160:
		look.play("run")
		look.speed_scale = clampf(vx / 260.0, 0.8, 1.3) # legs keep pace with her speed
	elif vx > 25:
		look.play("walk")
	else:
		look.play("idle")


## Every drawn frame (smoother than the physics steps): a little squash and lean, and the power-up looks.
func _process(delta: float) -> void:
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, 9.0 * delta))
	look.scale = _squash
	var flashing := safe_time > 0 and star_time <= 0 and int(safe_time / 0.09) % 2 == 1
	var on_rope := not hanging.is_empty()
	var leaping := leap_time > 0 and not is_on_floor() and not frozen
	look.visible = not (flashing or on_rope or leaping)
	rope_look.visible = not flashing and (on_rope or leaping)
	if leaping:
		# the leap pose (frame 3 of the rope strip), drawn with her feet at her feet
		var info: Dictionary = Game.manifest["hero_%s_rope" % _rope_outfit]
		rope_look.texture = Game.frame("hero_%s_rope" % _rope_outfit, 3)
		rope_look.offset = Vector2(-75, -float(info.get("leapBottom", 190)))
		rope_look.position = Vector2.ZERO
		rope_look.rotation = 0
		rope_look.flip_h = look.flip_h
	# star power: a shifting rainbow shimmer
	var tint := Color.WHITE
	if star_time > 0:
		tint = Color.from_hsv(fmod(Time.get_ticks_msec() / 500.0, 1.0), 0.45, 1.0)
	look.modulate = tint
	rope_look.modulate = tint
	# the balloon she holds (it blinks when it's about to run out)
	var holding := float_time > 0 and not frozen
	_balloon.visible = holding and not (float_time < 2.0 and int(float_time / 0.12) % 2 == 1)
	var side := -1.0 if look.flip_h else 1.0
	_balloon.position = Vector2(side * 26, -175 + sin(Time.get_ticks_msec() / 300.0) * 5)
	_balloon.rotation_degrees = side * -6
	_bubble.visible = shield and not frozen
	var running := is_on_floor() and absf(velocity.x) > 160 and not frozen
	var bob: float = -absf(sin(Time.get_ticks_msec() / 75.0)) * 3.5 if running else 0.0
	look.rotation_degrees = clampf(velocity.x / 300.0, -1, 1) * 3.8 if running else 0.0
	look.position.y = bob


## pushed away from whatever hit her, then a moment of flashing safety
func knockback(from_x: float) -> void:
	hurt_time = 0.35
	safe_time = 2.0
	velocity = Vector2(-260.0 if position.x < from_x else 260.0, -420.0)
	_jumping = false
	Game.play_sfx("hurt")


## On a rope: her hands are at `hands`, swinging at `angle`; `frame` 0 hang, 1 legs forward, 2 legs trailing.
func hang_pose(hands: Vector2, angle: float, frame: int, facing_left: bool) -> void:
	rope_look.texture = Game.frame("hero_%s_rope" % _rope_outfit, frame)
	rope_look.offset = Vector2(-75, -6) # fists at the top middle of the frame
	rope_look.position = hands - position
	rope_look.rotation = -angle
	rope_look.flip_h = facing_left
	look.flip_h = facing_left


## Let go of a rope: fly off with its swing (a quick tap gives a shorter arc, like a jump)
func launch(v: Vector2) -> void:
	velocity = v
	_jumping = true
	_hold = 0.0
	leap_time = 0.32


## Put her somewhere instantly (a respawn), without the smoothing sliding her across the screen.
func teleport(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	reset_physics_interpolation()
