extends CharacterBody2D
## Janani's magic: a fireball that bounces along the ground, or a fire arrow that flies straight and far
## through up to three enemies. Knocks out enemies it touches and leaves Yuva dizzy for a moment.

const SPEED := { "fire": 560.0, "arrow": 980.0 }
const LIFE := { "fire": 2.2, "arrow": 1.1 }

var kind := "fire"
var dir := 1.0
var level: Node2D
var _life := 0.0
var _hits := 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # bounces on the ground, stops at walls
	var circle := CircleShape2D.new()
	circle.radius = 14
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	var anim := AnimatedSprite2D.new()
	var strip := "fireball" if kind == "fire" else "fire_arrow"
	anim.sprite_frames = Game.sprite_frames({ "fly": [strip, range(8), 16, true] })
	anim.flip_h = kind == "arrow" and dir > 0 # the arrow art points left
	anim.play("fly")
	add_child(anim)
	# a bigger area that notices enemies (and Yuva)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 4
	var touch := CollisionShape2D.new()
	var big := CircleShape2D.new()
	big.radius = 24
	touch.shape = big
	area.add_child(touch)
	area.body_entered.connect(_hit)
	add_child(area)
	velocity = Vector2(SPEED[kind] * dir, 200.0 if kind == "fire" else 0.0)
	_life = LIFE[kind]


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0:
		_pop()
		return
	if kind == "fire":
		velocity.y = minf(velocity.y + 1800.0 * delta, 900.0)
	move_and_slide()
	if is_on_wall():
		_pop()
	elif kind == "fire" and is_on_floor():
		velocity.y = -460.0 # hop, hop along the ground


func _hit(body: Node) -> void:
	if body.has_method("defeat") and not body.dead:
		body.defeat()
		level.add_score(200)
		level.boom(body.position + Vector2(0, -30), 0.6)
	elif body.has_method("stun"): # Yuva: no damage, but dizzy for a moment
		if body.stun(1.2):
			level.pop_text(body.position + Vector2(0, -190), "DIZZY!")
	else:
		return
	_hits += 1
	if kind == "fire" or _hits >= 3:
		_pop()


func _pop() -> void:
	if is_queued_for_deletion():
		return
	level.puff_at(position, 8, Color(1.0, 0.6, 0.2))
	queue_free()
