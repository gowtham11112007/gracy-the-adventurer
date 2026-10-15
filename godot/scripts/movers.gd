extends Node2D
## Moving grass platforms: they glide back and forth (or up and down), easing at each end,
## and Janani rides along. [column, row, width, tiles right, tiles down, seconds per trip]

const TILE := 64

var _list: Array[Dictionary] = []


func build(def: Dictionary, look: String) -> void:
	for m: Array in def.get("movers", []):
		var body := AnimatableBody2D.new()
		body.sync_to_physics = true # she gets carried along
		body.position = Vector2(m[0] * TILE, m[1] * TILE)
		var box := RectangleShape2D.new()
		box.size = Vector2(m[2] * TILE, TILE)
		var shape := CollisionShape2D.new()
		shape.shape = box
		shape.position = box.size / 2.0
		body.add_child(shape)
		for i in int(m[2]):
			var pic := Sprite2D.new()
			pic.texture = Game.texture(look)
			pic.centered = false
			pic.scale = Vector2.ONE * TILE / pic.texture.get_width() # keep the piece's own shape
			pic.position = Vector2(i * TILE, 0)
			body.add_child(pic)
		add_child(body)
		_list.append({ "body": body, "start": body.position, "move": Vector2(m[3], m[4]) * TILE,
			"period": float(m[5]) * 2.0, "t": 0.0 })


func _physics_process(delta: float) -> void:
	for m in _list:
		m.t += delta
		var w: float = TAU / m.period
		m.body.position = m.start + m.move * (1.0 - cos(w * m.t)) / 2.0
