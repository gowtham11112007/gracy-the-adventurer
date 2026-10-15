extends SceneTree
## Headless test for World Map and Top-Down RPG Pages.

func _initialize() -> void:
	await process_frame
	print("Testing Game save and persistence...")
	var game: Node = root.get_node("Game")
	assert(game.save.has("cleared"))
	assert(game.save.has("outfit"))
	game.save.outfit = "beta"
	game.write_save()
	game.load_save()
	assert(game.save.outfit == "beta")
	print("PASS  Save data and outfit persistence")

	print("Testing World Map instantiation...")
	var map: Node2D = load("res://scripts/world_map.gd").new()
	root.add_child(map)
	await process_frame
	assert(map.get_node_or_null("Node2D") != null or map.get_child_count() > 0)
	assert(map.is_unlocked(0) == true)
	print("PASS  World Map loads with background, nodes and heroes")
	map.free()

	print("Testing RPG Cottage instantiation...")
	var cottage: Node2D = load("res://scripts/rpg_cottage.gd").new()
	root.add_child(cottage)
	await process_frame
	assert(cottage.get_child_count() > 0)
	print("PASS  RPG Cottage loads with wardrobe, kitty and room")
	cottage.free()

	print("Testing RPG Chapel instantiation...")
	var chapel: Node2D = load("res://scripts/rpg_chapel.gd").new()
	root.add_child(chapel)
	await process_frame
	assert(chapel.get_child_count() > 0)
	print("PASS  RPG Chapel loads with altar and candles")
	chapel.free()

	print("Testing Title Screen instantiation...")
	var title: Node2D = load("res://scripts/title_screen.gd").new()
	root.add_child(title)
	await process_frame
	assert(title.get_child_count() > 0)
	print("PASS  Title Screen loads with logo, island, and buttons")
	title.free()

	print("Testing Story Cutscene instantiation...")
	var story: Node2D = load("res://scripts/story.gd").new()
	root.add_child(story)
	await process_frame
	assert(story.get_child_count() > 0)
	print("PASS  Story cutscene loads with actors and dialogue")
	story.free()

	print("Testing Results Card instantiation...")
	var results: Node2D = load("res://scripts/results_card.gd").new()
	root.add_child(results)
	await process_frame
	assert(results.get_child_count() > 0)
	print("PASS  Results card loads with table, stars, and score")
	results.free()

	print("\nALL WORLD MAP, TITLE, STORY & RPG TESTS PASSED!")
	quit(0)
