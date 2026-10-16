extends CharacterBody2D
## Yuva (same as game/src/objects/Boss.js): throws bombs at Janani, leaps across the arena,
## and needs three stomps on the head. Confident at first, crying after the first stomp, dizzy after the second.

## frames of the red demon strip for each mood (assets/pack/yuva_demon.png, see tools/prepare_demon.py)
const FRAMES := [
	{ "idle": 0, "windup": 14, "throw": 12, "jump": 19 },
	{ "idle": 4, "windup": 14, "throw": 12, "jump": 19 },
	{ "idle": 8, "windup": 15, "throw": 12, "jump": 19 },
]
const STUNNED_FRAME := 23
const DEFEATED_FRAME := 21
const GRAVITY := 1800.0

var fight: Node2D          ## the boss fight: throws the bombs, knows where Janani is
var left := 0.0            ## the arena's edges
var right := 0.0
var hits := 0
var mode := "enter"
var invuln := 0.0
var defeated := false
var look: Sprite2D
var _timer := 0.0


func _ready() -> void:
	collision_layer = 4 # touching him is noticed like any enemy
	collision_mask = 1
	var box := RectangleShape2D.new()
	box.size = Vector2(72, 150)
	var shape := CollisionShape2D.new()
	shape.shape = box
	shape.position.y = -75
	add_child(shape)
	look = Sprite2D.new()
	look.centered = false
	look.offset = Vector2(-112, -216) # 224x220 frames, feet on the bottom edge
	look.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # pixel art stays crisp
	add_child(look)
	_frame(FRAMES[0].jump)


func _frame(i: int) -> void:
	look.texture = Game.frame("yuva_demon", i)


var frames: Dictionary:
	get: return FRAMES[mini(hits, 2)]


## the top of his head, for stomps
var head_y: float:
	get: return position.y - 150


func _physics_process(delta: float) -> void:
	if defeated:
		velocity.x = 0
		velocity.y += GRAVITY * delta
		move_and_slide()
		return
	var p: Node2D = fight.target()
	invuln -= delta
	look.visible = not (invuln > 0 and int(invuln / 0.08) % 2 == 1)
	if mode != "jump":
		look.flip_h = p.position.x < position.x # his art faces right
	_timer -= delta
	var on_floor := is_on_floor()

	match mode:
		"enter": # dropping into the arena
			if on_floor:
				_landed()
				_set_mode("idle", 0.9)
		"idle":
			_frame(frames.idle)
			if on_floor:
				velocity.x = 0
			if _timer <= 0:
				var leap := randf() < 0.28 + hits * 0.12
				_set_mode("jump" if leap else "windup", 0.65 - hits * 0.1)
				if leap:
					_leap()
		"windup":
			_frame(frames.windup)
			if _timer <= 0:
				_set_mode("throw", 0.38)
				_frame(frames.throw)
				# one bomb, then two once he's upset
				for i in mini(hits, 1) + 1:
					var aim := p.position.x + (i - hits / 2.0) * 110
					get_tree().create_timer(i * 0.17).timeout.connect(func() -> void:
						if not defeated:
							fight.throw_bomb(self, aim))
		"throw":
			if _timer <= 0:
				_set_mode("idle", 1.8 - hits * 0.2)
		"jump":
			_frame(frames.jump)
			if on_floor and velocity.y >= 0 and _timer <= 0:
				_landed()
				_set_mode("idle", 0.7 - hits * 0.15)
		"hurt":
			if on_floor and _timer <= 0:
				_set_mode("idle", 0.6)
		"stunned": # Super Kitty pounced on him: dizzy, wide open for a stomp
			_frame(STUNNED_FRAME)
			if on_floor:
				velocity.x = 0
			if _timer <= 0:
				_set_mode("idle", 0.9)
	velocity.y = minf(velocity.y + GRAVITY * delta, 1100.0)
	move_and_slide()


func _set_mode(m: String, seconds: float) -> void:
	mode = m
	_timer = seconds


## a big leap to the far side of the arena
func _leap() -> void:
	var mid := (left + right) / 2.0
	var target := right - 160 if position.x < mid else left + 160
	look.flip_h = target < position.x
	velocity = Vector2((target - position.x) / 1.2, -1000)
	_timer = 0.3


func _landed() -> void:
	fight.boss_landed(position)


## dizzy for a moment (not while he's dropping in or mid-leap); returns whether it worked
func stun(seconds: float) -> bool:
	if defeated or mode == "enter" or mode == "jump":
		return false
	_set_mode("stunned", seconds)
	velocity.x = 0
	return true


## stomped on the head: returns true when that was the last hit
func hit() -> bool:
	if invuln > 0 or defeated:
		return false
	hits += 1
	invuln = 1.5
	if hits >= 3:
		defeated = true
		_frame(DEFEATED_FRAME) # crouched, beaten
		look.visible = true
		return true
	# bounces away from Janani, crying
	_frame(FRAMES[hits].idle)
	var away := -1.0 if position.x < fight.target().position.x else 1.0
	velocity = Vector2(away * 320, -620)
	_set_mode("hurt", 0.4)
	return false
