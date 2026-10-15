extends CharacterBody2D
## Yuva's bomb: arcs through the air, fizzes for a moment on the ground, then goes off.
## Touching Janani sets it off at once.

var fight: Node2D
var caught := false   ## Super Kitty has it: it won't go off
var _armed := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var circle := CircleShape2D.new()
	circle.radius = 22
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	var pic := Sprite2D.new()
	pic.texture = Game.texture("bomb")
	add_child(pic)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2 # Janani
	var touch := CollisionShape2D.new()
	touch.shape = circle
	area.add_child(touch)
	area.body_entered.connect(func(_body: Node) -> void: explode())
	add_child(area)


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + 1800.0 * delta, 1100.0)
	if _armed:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	else:
		rotation += signf(velocity.x) * TAU * delta # spins as it flies
	var fall := velocity.y
	move_and_slide()
	if is_on_floor() and not _armed:
		_armed = true
		velocity.y = -fall * 0.25 # a little bounce
		fight.bomb_landed(self)
		var pulse := create_tween().set_loops(3)
		pulse.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12)
		pulse.tween_property(self, "scale", Vector2.ONE, 0.12)
		get_tree().create_timer(0.65).timeout.connect(explode)


func explode() -> void:
	if caught or is_queued_for_deletion():
		return
	fight.bomb_exploded(position)
	queue_free()
