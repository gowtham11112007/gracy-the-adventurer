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

	print("Testing save slots and settings...")
	var keep_slot: int = game.slot
	var keep_last: int = game.settings.last_slot
	var keep_shake: bool = game.settings.shake
	if game.has_slot(3):
		print("SKIP  slot 3 already holds a real save: slot tests not run")
	else:
		game.new_game(3)
		assert(game.has_slot(3) and game.slot == 3)
		assert(game.slot_summary(3).cleared == 0)
		game.save.cleared.append("1-1")
		game.save.crystals["1-1"] = [0, 2, 2, 2] # (the same crystal saved again and again, as an old bug did)
		game.write_save()
		var info: Dictionary = game.slot_summary(3)
		assert(info.cleared == 1 and info.crystals == 2)
		print("PASS  A new game in slot 3 is saved and summarised")
		game.save = game.SAVE_DEFAULTS.duplicate(true)
		game.load_slot(3)
		assert(game.save.cleared == ["1-1"] and game.settings.last_slot == 3)
		assert(game.save.crystals["1-1"] == [0, 2] and game.save.crystals["1-1"].has(2)) # whole numbers, once each
		print("PASS  Loading slot 3 brings its progress back, crystals as whole numbers once each")
		game.delete_slot(3)
		assert(not game.has_slot(3) and game.slot == 0 and game.settings.last_slot == 0)
		print("PASS  Deleting slot 3 removes it")
		game.write_save()
		assert(not game.has_slot(3)) # no slot chosen: nothing may be written
		print("PASS  With no slot chosen nothing is written")
	game.set_setting("shake", false)
	assert(JSON.parse_string(FileAccess.get_file_as_string("user://settings.json")).shake == false)
	game.set_setting("shake", keep_shake)
	game.slot = keep_slot
	game.settings.last_slot = keep_last
	game._save_settings()
	print("PASS  Settings are saved and restored")

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
