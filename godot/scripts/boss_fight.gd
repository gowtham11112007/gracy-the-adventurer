extends Node2D
## World 1's last stretch: Yuva's arena on the hill, Janika trapped in a bubble above it, the bombs,
## and Super Kitty, who turns shining silver-gray and helps: she pounces on Yuva's head (leaving him dizzy)
## and bats away bombs that land near Janani.

const TILE := 64
const GROUND_Y := 10 * TILE

var level: Node2D
var boss: CharacterBody2D
var left := 0.0
var right := 0.0
var started := false
var _pounce := 6.0     ## seconds until Super Kitty's next pounce on Yuva
var _bat := 0.0        ## seconds until she can bat away another bomb
var _bar: Array[ColorRect] = []
var _bar_layer: CanvasLayer


func build(def: Dictionary) -> void:
	left = def.boss[0] * TILE
	right = def.boss[1] * TILE
	# Janika, trapped in her bubble above the arena
	var jx := right - 230
	var holder := Node2D.new()
	holder.position = Vector2(jx, 250)
	add_child(holder)
	var bubble := preload("res://scripts/bubble.gd").new()
	bubble.radius = 92
	holder.add_child(bubble)
	var janika := Sprite2D.new()
	janika.texture = Game.frame("twin", 0)
	holder.add_child(janika)
	var bob := create_tween().set_loops()
	bob.tween_property(holder, "position:y", 236.0, 1.2).set_trans(Tween.TRANS_SINE)
	bob.tween_property(holder, "position:y", 250.0, 1.2).set_trans(Tween.TRANS_SINE)


## who Yuva goes after
func target() -> Node2D:
	return level.player


func update(p: CharacterBody2D, delta: float) -> void:
	if not started and p.position.x > left + 96:
		_start()
	if started and boss and not boss.defeated:
		_super_kitty(delta)


func _start() -> void:
	started = true
	# close the arena behind her, and keep the camera inside it
	var walls := StaticBody2D.new()
	for x: float in [left - 16, right + 16]:
		var box := RectangleShape2D.new()
		box.size = Vector2(32, 12 * TILE + 1200)
		var shape := CollisionShape2D.new()
		shape.shape = box
		shape.position = Vector2(x, 0)
		walls.add_child(shape)
	add_child(walls)
	level.set_camera_range(left, right)
	boss = preload("res://scripts/boss.gd").new()
	boss.fight = self
	boss.left = left
	boss.right = right
	boss.position = Vector2(right - 300, -200)
	boss.z_index = 3
	add_child(boss)
	_build_bar()
	level.banner("YUVA!", "Stomp on his head three times!", 2.2)
	if level.kitty:
		get_tree().create_timer(2.6).timeout.connect(func() -> void:
			if level.is_playing():
				level.kitty.power_up()
				level.flash(Color(0.9, 0.91, 1.0))
				level.banner("SUPER KITTY!", "She pounces on Yuva and bats bombs away", 2.2))


## Yuva's health along the top: three pips that go dark as she stomps him
func _build_bar() -> void:
	_bar_layer = CanvasLayer.new()
	add_child(_bar_layer)
	var name_tag := Game.label("YUVA", 14, Color("#ff7a7a"))
	name_tag.position = Vector2(500, 70)
	_bar_layer.add_child(name_tag)
	for i in 3:
		var pip := ColorRect.new()
		pip.color = Color("#ff4d6d")
		pip.size = Vector2(40, 14)
		pip.position = Vector2(570 + i * 46, 72)
		_bar_layer.add_child(pip)
		_bar.append(pip)


## Janani touched Yuva: a stomp if she landed on his head, otherwise she gets hurt
func touch(p: CharacterBody2D) -> void:
	if boss.defeated:
		return
	if p.velocity.y > 60 and p.position.y <= boss.head_y + 40:
		p.velocity.y = -820
		if boss.hit():
			_bar[boss.hits - 1].color = Color(0.2, 0.2, 0.2, 0.6)
			_won()
		elif boss.hits > 0:
			_bar[boss.hits - 1].color = Color(0.2, 0.2, 0.2, 0.6)
			level.add_score(5000)
			level.shake(0.15)
	elif boss.invuln <= 0 and boss.mode != "stunned":
		level.hurt_from(boss.position.x)


func boss_landed(at: Vector2) -> void:
	level.shake(0.22)
	level.puff_at(at, 18)


func throw_bomb(from: Node2D, aim_x: float) -> void:
	var bomb: CharacterBody2D = preload("res://scripts/bomb.gd").new()
	var dir := -1.0 if aim_x < from.position.x else 1.0
	bomb.position = from.position + Vector2(dir * 60, -130)
	bomb.velocity = Vector2((aim_x - bomb.position.x) / 1.0, -520)
	bomb.fight = self
	bomb.z_index = 4
	add_child(bomb)


## a bomb hit the ground: it fizzes for a moment (Super Kitty may bat it away first)
func bomb_landed(bomb: Node2D) -> void:
	var k: Node2D = level.kitty
	if k and k.powered and not k.busy and _bat <= 0 and absf(bomb.position.x - level.player.position.x) < 480:
		_bat = 2.5
		bomb.caught = true # she's got it: it won't go off
		k.dash(bomb.position + Vector2(0, 20), 0.38, func() -> void:
			if is_instance_valid(bomb):
				level.puff_at(bomb.position, 18, Color(1, 1, 1))
				level.pop_text(bomb.position + Vector2(0, -40), "MEOW!")
				bomb.queue_free())


func bomb_exploded(at: Vector2) -> void:
	level.boom(at + Vector2(0, -20), 1.0)
	level.shake(0.2)
	if at.distance_to(level.player.position + Vector2(0, -56)) < 80:
		level.hurt_from(at.x)


## every few seconds Super Kitty leaps on his head and leaves him dizzy: the perfect moment to stomp
func _super_kitty(delta: float) -> void:
	var k: Node2D = level.kitty
	_bat -= delta
	if not k or not k.powered or k.busy:
		return
	_pounce -= delta
	if _pounce <= 0 and boss.is_on_floor() and boss.mode in ["idle", "windup", "throw"]:
		_pounce = 7.0
		k.dash(Vector2(boss.position.x, boss.head_y + 30), 0.52, func() -> void:
			if boss.stun(2.4):
				level.puff_at(Vector2(boss.position.x, boss.head_y), 16, Color(1, 0.95, 0.5))
				level.shake(0.12)
				level.pop_text(Vector2(boss.position.x, boss.head_y - 40), "DIZZY!"))


func _won() -> void:
	for child in get_children():
		if child.has_method("explode"):
			child.queue_free() # clear the bombs
	level.add_score(5000)
	level.flash(Color.WHITE)
	level.banner("YOU BEAT YUVA!", "", 2.0)
	get_tree().create_timer(1.8).timeout.connect(level.boss_beaten)
