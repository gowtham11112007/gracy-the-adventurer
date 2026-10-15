extends SceneTree

func _initialize() -> void:
	await process_frame
	var chapel: Node2D = load("res://scripts/rpg_chapel.gd").new()
	root.add_child(chapel)
	await create_timer(0.2).timeout
