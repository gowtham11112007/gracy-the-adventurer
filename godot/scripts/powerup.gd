extends CharacterBody2D
## A power-up out of a gift box. The cupcake, star and heart hop out and slide along the ground;
## the balloon and magnet float up above the box and bob there, a jump away.

const ART := { "cupcake": "cupcake", "star": "star", "heart": "heart", "balloon": "balloon_pink", "magnet": "star_lucky",
	"fire": "icon_fire", "arrow": "icon_arrow" }

var kind := "cupcake"
var level: Node2D
var from_x := 0.0          ## where Janani was: it hops away from her
var _floats := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # slides along the ground and blocks
	var circle := CircleShape2D.new()
	circle.radius = 20
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	var pic := Sprite2D.new()
	pic.texture = Game.texture(ART[kind])
	if pic.texture.get_height() > 70:
		pic.scale = Vector2.ONE * 70.0 / pic.texture.get_height()
	add_child(pic)
	# a slightly bigger area that notices Janani
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var touch := CollisionShape2D.new()
	var big := CircleShape2D.new()
	big.radius = 28
	touch.shape = big
	area.add_child(touch)
	area.body_entered.connect(func(body: Node) -> void:
		if body == level.player:
			level.collect_powerup(self))
	add_child(area)

	_floats = kind in ["balloon", "magnet"]
	if _floats:
		var top := position.y - 64 * 1.6
		var tw := create_tween()
		tw.tween_property(self, "position:y", top, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			var bob := create_tween().set_loops()
			bob.tween_property(self, "position:y", top - 10, 0.8).set_trans(Tween.TRANS_SINE)
			bob.tween_property(self, "position:y", top, 0.8).set_trans(Tween.TRANS_SINE))
	else:
		position.y -= 64 # out of the top of the box
		velocity = Vector2(170.0 if from_x <= position.x else -170.0, -420.0)


func _physics_process(delta: float) -> void:
	if _floats:
		return
	velocity.y = minf(velocity.y + 1800.0 * delta, 900.0)
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	var before := velocity.x
	move_and_slide()
	if is_on_wall():
		velocity.x = -before # bounce off walls
