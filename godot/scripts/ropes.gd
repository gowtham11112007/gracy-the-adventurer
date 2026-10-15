extends Node2D
## Ropes hang from a peg and swing. Janani grabs one by jumping into it and lets go with jump,
## flying off with the rope's swing. [column, row of the peg, length in tiles, swing angle, seconds per swing]

const TILE := 64
const REACH := 72.0  ## generous on purpose, like rope swings in classic platformers

var level: Node2D
var _ropes: Array[Dictionary] = []


func build(def: Dictionary) -> void:
	for r: Array in def.get("ropes", []):
		var pic := Sprite2D.new()
		pic.texture = Game.texture("rope")
		pic.centered = false
		pic.offset = Vector2(-pic.texture.get_width() / 2.0, 0)
		pic.scale = Vector2(30.0 / pic.texture.get_width(), (r[2] * TILE + 22.0) / pic.texture.get_height())
		pic.position = Vector2(r[0] * TILE + TILE / 2.0, r[1] * TILE - 8)
		pic.z_index = 1
		add_child(pic)
		_ropes.append({ "pic": pic, "ax": r[0] * TILE + TILE / 2.0, "ay": r[1] * TILE * 1.0,
			"len": r[2] * TILE * 1.0, "amp": deg_to_rad(r[3]), "w": TAU / float(r[4]),
			"t": randf() * float(r[4]), "cool": 0.0, "angle": 0.0, "spin": 0.0, "id": _ropes.size() })


func _physics_process(delta: float) -> void:
	var p: CharacterBody2D = level.player
	for r in _ropes:
		r.t += delta
		r.cool -= delta
		r.angle = r.amp * sin(r.w * r.t)
		r.spin = r.amp * r.w * cos(r.w * r.t) # how fast it's swinging (radians per second)
		r.pic.rotation = -r.angle
	if p.frozen:
		return
	if p.hanging.is_empty() and not p.is_on_floor():
		_try_grab(p)
	if not p.hanging.is_empty():
		_swing(p)


## any part of her upper body (hands to waist) near the lower part of a rope grabs it
func _try_grab(p: CharacterBody2D) -> void:
	for r in _ropes:
		if r.cool > 0 or r.id == p.last_rope:
			continue # not the rope she just let go of
		var a := Vector2(r.ax, r.ay)
		var d: Vector2 = Vector2(sin(r.angle), cos(r.angle)) * r.len
		var best := { "dist": INF, "t": 0.0 }
		for hy: float in [p.position.y - 104, p.position.y - 80, p.position.y - 56]:
			var t := clampf((Vector2(p.position.x, hy) - a).dot(d) / d.length_squared(), 0.3, 1.0)
			var dist: float = (a + d * t).distance_to(Vector2(p.position.x, hy))
			if dist < best.dist:
				best = { "dist": dist, "t": t }
		if best.dist < REACH:
			p.hanging = { "rope": r, "along": best.t * r.len }
			p.wants_release = false
			p.velocity = Vector2.ZERO
			return


func _swing(p: CharacterBody2D) -> void:
	var r: Dictionary = p.hanging.rope
	var along: float = p.hanging.along
	var hands := Vector2(r.ax + sin(r.angle) * along, r.ay + cos(r.angle) * along)
	p.position = hands + Vector2(0, 100)
	# legs: straight on the way back, trailing at the fast bottom, kicked out toward the far end
	var ahead: float = (r.angle / r.amp) * (-1.0 if r.spin < 0 else 1.0)
	var frame := 2 if absf(ahead) < 0.35 else (1 if ahead > 0 else 0)
	p.hang_pose(hands, r.angle, frame, r.spin < 0)
	if p.wants_release:
		# let go with the rope's swing, plus a hop
		var vx := clampf(cos(r.angle) * r.spin * along * 1.15, -440.0, 440.0)
		var vy := minf(-sin(r.angle) * r.spin * along, 0.0) - 640.0
		p.hanging = {}
		p.wants_release = false
		p.last_rope = r.id
		r.cool = 0.45
		p.launch(Vector2(vx, vy))
		level.puff_at(p.position + Vector2(0, -100), 6)
