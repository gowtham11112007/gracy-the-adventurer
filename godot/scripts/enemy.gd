extends CharacterBody2D
## The meadow's troublemakers (same behaviour as game/src/objects/Enemy.js):
## mushrooms walk and turn at walls and ledges, hoppers also bounce, snails are spiky (no stomping),
## bees float in lazy loops, and divers shake as a warning, then swoop at where Janani was.

const KINDS := {
	"mushroom": { "art": "mushroom", "box": Vector2(48, 54), "speed": 70.0 },
	"hopper": { "art": "mushroom", "box": Vector2(48, 54), "speed": 85.0, "hops": true },
	"snail": { "art": "snail", "box": Vector2(66, 42), "speed": 42.0, "faces_right": true, "spiky": true },
	"bee": { "art": "bee", "box": Vector2(34, 28), "flies": true, "faces_right": true },
	"diver": { "art": "bee", "box": Vector2(34, 28), "flies": true, "faces_right": true, "dives": true },
}
const GRAVITY := 1800.0

var kind := "mushroom"
var level: Node2D          ## asks it about solid ground, and where Janani is
var dead := false
var info: Dictionary
var look: AnimatedSprite2D

var _dir := -1.0
var _hop_timer := 0.0
var _home: Vector2
var _t := 0.0
var _mode := "hover"
var _mode_time := 0.0
var _rest := 0.0
var _target: Vector2


func _ready() -> void:
	info = KINDS[kind]
	collision_layer = 4 # enemies don't block Janani; touching is handled by `touch`
	collision_mask = 1
	var box := RectangleShape2D.new()
	box.size = info.box
	var shape := CollisionShape2D.new()
	shape.shape = box
	shape.position.y = -box.size.y / 2.0
	add_child(shape)
	var size: Vector2 = Game.frame(info.art, 0).get_size()
	look = AnimatedSprite2D.new()
	look.centered = false
	look.offset = Vector2(-size.x / 2.0, -size.y) # feet on the bottom edge of the frame
	look.sprite_frames = Game.sprite_frames({ "move": [info.art, [0, 1, 2, 3, 4], 14 if info.get("flies") else 8, true],
		"defeated": [info.art, [5], 1, false] })
	look.play("move")
	add_child(look)
	if info.get("dives"):
		look.scale = Vector2(1.15, 1.15) # the diving bee is a bit bigger
	_home = position
	_t = randf() * 6.0
	_hop_timer = 0.8 + randf() * 0.9


## true if Janani landed on top of it (a stomp), false if she touched it any other way
func is_stomp(player: CharacterBody2D) -> bool:
	var top: float = position.y - (info.box as Vector2).y
	return player.velocity.y > 60 and player.position.y <= top + 34 and not info.get("spiky")


func _physics_process(delta: float) -> void:
	if dead:
		return
	if info.get("flies"):
		_fly(delta)
		move_and_slide()
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, 1100.0)
	if is_on_wall():
		_dir = signf(get_wall_normal().x) # turn around, away from the wall
	elif is_on_floor() and not level.is_solid_at(position + Vector2(_dir * (info.box.x / 2 + 6), 10)):
		_dir *= -1.0 # don't walk off ledges
	velocity.x = _dir * info.speed
	if info.get("faces_right"):
		look.flip_h = _dir < 0
	if info.get("hops") and is_on_floor():
		_hop_timer -= delta
		if _hop_timer <= 0:
			velocity.y = -560
			_hop_timer = 0.9 + randf() * 0.9
	move_and_slide()


func _fly(delta: float) -> void:
	var p: CharacterBody2D = level.player
	_t += delta
	match _mode:
		"hover":
			var reach := 60.0 if info.get("dives") else 100.0
			var to := _home + Vector2(sin(_t * 0.7) * reach, sin(_t * 2.0) * 18.0)
			velocity = (to - position) * 6.0
			look.flip_h = cos(_t * 0.7) < 0
			_rest -= delta
			if info.get("dives") and _rest <= 0 and absf(p.position.x - position.x) < 240 \
					and p.position.y > position.y + 40 and not p.frozen:
				_mode = "aim"
				_mode_time = 1.0 # a long, clear warning shake
				_target = p.position - Vector2(0, 40)
		"aim":
			velocity = Vector2.ZERO
			position.x += sin(_t * 80.0) * 1.5
			look.flip_h = _target.x < position.x
			_mode_time -= delta
			if _mode_time <= 0:
				_mode = "dive"
				_mode_time = 1.1
				velocity = (_target - position).normalized() * 340.0
		"dive":
			_mode_time -= delta
			if _mode_time <= 0 or position.distance_to(_target) < 20:
				_mode = "return"
		"return":
			velocity = (_home - position).normalized() * 230.0
			look.flip_h = _home.x < position.x
			if position.distance_to(_home) < 12:
				_mode = "hover"
				_rest = 3.0 # a breather before it can dive again


func defeat(stomped := false) -> void:
	if dead:
		return
	dead = true
	look.play("defeated")
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	var tw := create_tween()
	if info.get("flies"):
		# spins away and falls
		tw.tween_property(self, "position:y", position.y + 300, 0.8)
		tw.parallel().tween_property(self, "rotation_degrees", 200.0, 0.8)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.8)
	else:
		if stomped:
			tw.tween_property(look, "scale", Vector2(1.2, 0.55), 0.09) # squashed flat
		tw.tween_interval(0.5)
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
