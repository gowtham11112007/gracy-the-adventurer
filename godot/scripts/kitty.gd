extends AnimatedSprite2D
## Kitty trots along behind Janani, copying her jumps a moment later, and sits when she stops.

const DELAY := 12  ## physics steps Kitty lags behind Janani's path
const GAP := 62.0  ## how far behind her she trots

var player: CharacterBody2D
var _trail: Array[Dictionary] = []
var _waiting := false  ## sat down while Janani swings on a rope
var powered := false   ## Super Kitty (the Yuva fight): silver-gray, glowing, and she helps
var busy := false      ## in the middle of a pounce or a bomb catch
var _aura: Node2D


func _ready() -> void:
	sprite_frames = Game.kitty_frames()
	centered = false
	offset = Vector2(-64, -128) # 128x128 frames, paws on the bottom edge
	scale = Vector2(1.0, 1.0)
	play("idle")
	snap()


func set_skin(skin_id: String) -> void:
	var cur := animation
	sprite_frames = Game.kitty_frames(skin_id)
	play(cur)


## jump straight to Janani (after a respawn)
func snap() -> void:
	_trail.clear()
	position = player.position - Vector2(GAP, 0)
	reset_physics_interpolation()


## Super Kitty: shining silver-gray with a soft white glow and sparkles
func power_up() -> void:
	powered = true
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/kitty_super.gdshader")
	material = mat
	_aura = preload("res://scripts/aura.gd").new()
	_aura.show_behind_parent = true
	add_child(_aura)
	var sparks := CPUParticles2D.new()
	sparks.position = Vector2(0, -40)
	sparks.amount = 10
	sparks.lifetime = 0.7
	sparks.spread = 180.0
	sparks.initial_velocity_min = 20.0
	sparks.initial_velocity_max = 60.0
	sparks.gravity = Vector2.ZERO
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 4.0
	sparks.color = Color(0.92, 0.94, 1.0)
	add_child(sparks)


## leap onto something (Yuva's head, a bomb), call `on_hit` there, then trot back to Janani
func dash(to: Vector2, seconds: float, on_hit: Callable) -> void:
	busy = true
	play("attack")
	flip_h = to.x > position.x
	var from := position
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		position = from.lerp(to, t) + Vector2(0, -sin(t * PI) * 120), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(on_hit)
	tw.tween_interval(0.25)
	tw.tween_callback(func() -> void:
		busy = false
		_trail.clear())


func _physics_process(_delta: float) -> void:
	if busy:
		return
	var p := player
	if not p.hanging.is_empty():
		if not _waiting:
			# sit down to wait at the last spot Janani stood on the ground
			for i in range(_trail.size() - 1, -1, -1):
				if not _trail[i].air:
					position = _trail[i].pos - Vector2(_trail[i].side * -GAP, 0)
					break
			flip_h = p.position.x > position.x
		_waiting = true
		play("idle")
		return
	if _waiting:
		if not p.is_on_floor():
			return
		_waiting = false
		snap()
	_trail.append({ "pos": p.position, "air": not p.is_on_floor(), "side": 1.0 if p.look.flip_h else -1.0 })
	if _trail.size() > DELAY:
		_trail.pop_front()
	var t: Dictionary = _trail[0]
	var prev_x := position.x
	position.x += (t.pos.x + t.side * GAP - position.x) * 0.18
	position.y = t.pos.y
	var step := absf(position.x - prev_x)
	if t.air:
		play("leap")
	elif step > 2.5:
		play("run") # a gallop when keeping up with a running Janani
	elif step > 0.8:
		play("walk")
	else:
		play("idle")
	# Kitty's art faces left: flip when she moves right, or to face Janani when sitting
	flip_h = position.x > prev_x if (step > 0.8 or t.air) else p.position.x > position.x
