extends SceneTree

func _initialize() -> void:
	await process_frame
	var cottage: Node2D = load("res://scripts/rpg_cottage.gd").new()
	root.add_child(cottage)
	await create_timer(0.2).timeout
