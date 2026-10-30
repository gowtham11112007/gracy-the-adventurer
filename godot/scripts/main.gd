extends Node
## Main game controller: manages transitions between Title Screen, Story Cutscenes, World Map, Levels, RPG Pages, and Results Cards.
## - Default on launch: Grand Title Screen.
## - Title Screen: Play (World Map), Story (Intro), Wardrobe (Cottage), Shrine (Chapel).
## - Level finish: Celebratory Victory Results Card (Score, Gems, Stars).
## - Boss finish: World 1 Ending Cutscene (Janika rescue & hug, Kitty kidnapped!).
## - Testing args still work: level=N col=X power=fire autorun (slash) screen=map/cottage/chapel/story/title.
## - Back (Esc, or the phone's Back button): closes the newest pop-up, else the screen's go_back() decides
##   (a room pauses, the wardrobe / candles / story return to the title, the title ignores it).

var _current_screen: Node2D
var _level: Node2D
var _keep_power := false


func _ready() -> void:
	Game.back_pressed.connect(_on_back)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("outfit="): # (testing) wear an outfit for this run only, without saving it
			Game.save.outfit = a.get_slice("=", 1)
	for a in args:
		if a.begins_with("room="): # (testing) start in a world room: room=m2, with entry=left|right|bench
			var entry := ""
			for b in args:
				if b.begins_with("entry="):
					entry = b.get_slice("=", 1)
			open_room(a.get_slice("=", 1), entry)
			if "autorun" in args:
				_autorun()
			for b in args:
				if b.begins_with("power="): # (testing) with magic charged, so its button shows
					_level.player.power = b.get_slice("=", 1)
					_level.player.charges = 3
					_level._update_hud()
			if "pause" in args: # (testing) open the pause menu once the room has faded in
				get_tree().create_timer(1.5).timeout.connect(func() -> void: _level.open_pause_menu())
			return
	if "screen=worldmap" in args: # (testing) the new world map: a few rooms explored, or all with "all"
		var backdrop := preload("res://scripts/ui.gd").backdrop("teal_forest", Color(0.5, 0.55, 0.65))
		backdrop.scale = Vector2(get_viewport().get_visible_rect().size.x / 1280.0, get_viewport().get_visible_rect().size.y / 720.0)
		add_child(backdrop)
		for id in ["m1", "m2", "m3", "m4", "w1", "w2", "w3", "w4", "w6", "s1"]:
			Game.discover_room(id)
		Game.unlock_ability("dash")
		var map := preload("res://scripts/map_screen.gd").new()
		map.show_all = "all" in args
		add_child(map)
		return
	if "screen=title" in args:
		open_title_screen()
		if "goto=map" in args: # (testing) go on to the map after a second, through the wipe
			get_tree().create_timer(1.0).timeout.connect(open_world_map)
		return
	if "screen=map" in args:
		open_world_map()
		return
	if "screen=cottage" in args:
		open_rpg_cottage()
		return
	if "screen=chapel" in args:
		open_rpg_chapel()
		return
	if "screen=story" in args:
		open_story("intro")
		return
	if "screen=ending" in args:
		open_story("world1end")
		return
	if "screen=results" in args: # (testing) the card after 1-1
		show_results(0, 12400, 37, true)
		return
	if "level=beta" in args:
		open_beta_level()
		for a in args:
			if a.begins_with("col="):
				_level.player.teleport(Vector2(int(a.get_slice("=", 1)) * 64 + 32, 640))
			if a.begins_with("power="):
				_level.player.power = a.get_slice("=", 1)
				_level.player.charges = 3
				_level._update_hud()
				_keep_power = true
		if "autorun" in args:
			_autorun()
		return

	var test_level := -1
	for a in args:
		if a.begins_with("level="):
			test_level = int(a.get_slice("=", 1)) - 1
	if test_level >= 0 or "autorun" in args:
		open_level(maxi(0, test_level))
		for a in args:
			if a.begins_with("col="):
				_level.player.teleport(Vector2(int(a.get_slice("=", 1)) * 64 + 32, 640))
			if a.begins_with("power="):
				_level.player.power = a.get_slice("=", 1)
				_level.player.charges = 3
				_level._update_hud()
				_keep_power = true
		if "autorun" in args:
			_autorun()
		if "pause" in args: # (testing) open the pause menu after a moment
			get_tree().create_timer(1.5).timeout.connect(func() -> void: _level.open_pause_menu())
	else:
		open_title_screen()


## Test pilot: hold right and jump now and then, so a recording shows her running and jumping.
func _autorun() -> void:
	Input.action_press("right")
	while is_inside_tree():
		await get_tree().create_timer(0.9).timeout
		await get_tree().physics_frame
		if _keep_power and _level and is_instance_valid(_level.player) and _level.player.charges <= 0:
			_level.player.charges = 3
			_level._update_hud()
		if "slash" in OS.get_cmdline_user_args(): # (testing) swing the sword instead of jumping
			Input.action_press("attack")
		else:
			Input.action_press("jump")
		Input.action_press("shoot")
		if _level and is_instance_valid(_level.player):
			_level._shoot()
		await get_tree().create_timer(0.35).timeout
		await get_tree().physics_frame
		Input.action_release("jump")
		Input.action_release("attack")
		Input.action_release("shoot")


func open_title_screen() -> void:
	var title: Node2D = load("res://scripts/title_screen.gd").new()
	title.start_game.connect(func() -> void: open_room(Game.save.get("bench", "m1"), "bench")) # Continue: at her last bench
	title.new_game_started.connect(func(_slot: int) -> void: open_story("intro")) # a new game starts with the story
	title.open_story.connect(func() -> void: open_story("intro"))
	title.open_wardrobe.connect(open_rpg_cottage)
	title.open_shrine.connect(open_rpg_chapel)
	_show(title)


func open_story(story_mode := "intro") -> void:
	var story: Node2D = load("res://scripts/story.gd").new()
	story.mode = story_mode
	story.finished.connect(func(m: String) -> void:
		if m == "intro":
			open_room("m1", "") # the story ends in the Birthday Glade, where the game begins
		else:
			open_title_screen())
	_show(story)


## A room of the world (data/rooms.json): walking off its left or right edge leads to the next room.
## `entry` is where she appears: "left", "right", "bench", or "" for the room's own start.
func open_room(room_id: String, entry := "") -> void:
	var def: Dictionary = Game.room_def(room_id)
	if def.is_empty():
		def = Game.room_def("m1") # (a room that isn't built yet: start again at the Birthday Glade)
		room_id = "m1"
		entry = "bench"
	var level: Node2D = preload("res://scripts/level.gd").new()
	level.def = def
	level.entry = entry
	level.exited.connect(func(to: String, arrive: String) -> void: open_room(to, arrive))
	level.restart_requested.connect(func() -> void: open_room(room_id, entry))
	level.quit_requested.connect(open_title_screen)
	level.finished.connect(func() -> void: # Yuva beaten in his arena: the twins' reunion
		await get_tree().create_timer(1.8).timeout
		open_story("world1end"))
	_show(level)


func open_world_map() -> void:
	var map: Node2D = load("res://scripts/world_map.gd").new()
	map.level_selected.connect(open_level)
	map.open_rpg_cottage.connect(open_rpg_cottage)
	map.open_rpg_chapel.connect(open_rpg_chapel)
	map.open_beta_map.connect(open_beta_level)
	map.back_to_title.connect(open_title_screen)
	_show(map)


func open_rpg_cottage() -> void:
	var cottage: Node2D = load("res://scripts/rpg_cottage.gd").new()
	cottage.back_to_map.connect(open_title_screen)
	_show(cottage)


func open_rpg_chapel() -> void:
	var chapel: Node2D = load("res://scripts/rpg_chapel.gd").new()
	chapel.back_to_map.connect(open_title_screen)
	_show(chapel)


func open_level(index: int) -> void:
	var level: Node2D = preload("res://scripts/level.gd").new()
	level.def = Game.levels.solo[index]
	level.finished.connect(func() -> void:
		var cur_id: String = level.def.id
		if not Game.save.cleared.has(cur_id): # (the next level opens because this one is cleared)
			Game.save.cleared.append(cur_id)
		Game.write_save()
		var lvl_score: int = level.score
		var lvl_gems: int = level.gems
		var has_candle: bool = Game.save.candles.has(cur_id)
		await get_tree().create_timer(1.8).timeout
		show_results(index, lvl_score, lvl_gems, has_candle)
	)
	level.restart_requested.connect(func() -> void: open_level(index))
	level.quit_requested.connect(open_world_map)
	_show(level)


func open_beta_level() -> void:
	var level: Node2D = preload("res://scripts/level.gd").new()
	level.def = Game.beta_level()
	level.finished.connect(func() -> void:
		var lvl_score: int = level.score
		var lvl_gems: int = level.gems
		await get_tree().create_timer(1.8).timeout
		show_results(-1, lvl_score, lvl_gems, false)
	)
	level.restart_requested.connect(open_beta_level)
	level.quit_requested.connect(open_world_map)
	_show(level)


func show_results(level_idx: int, score: int, gems: int, candle: bool) -> void:
	var results: Node2D = load("res://scripts/results_card.gd").new()
	if level_idx >= 0 and level_idx < Game.levels.solo.size():
		results.level_id = Game.levels.solo[level_idx].id
		results.level_name = Game.levels.solo[level_idx].get("name", "STAGE %d" % (level_idx + 1)).to_upper()
	else:
		results.level_id = "beta"
		results.level_name = "SKY RUINS (BETA)"
	results.final_score = score
	results.gems_collected = gems
	results.candle_found = candle

	results.next_level.connect(func() -> void:
		if level_idx >= 0 and level_idx == 4: # Boss defeated!
			open_story("world1end")
		elif level_idx >= 0 and level_idx + 1 < Game.levels.solo.size():
			open_level(level_idx + 1)
		else:
			open_world_map())
	results.return_to_map.connect(open_world_map)

	_show(results)


var _wipe: ColorRect
var _wiping := false

## Swaps to a new screen through a fade to night blue: the old screen fades out, the new one is put in and
## fades in. The very first screen appears straight away.
func _show(screen: Node) -> void:
	if _wiping:
		screen.free()
		return
	var old := _current_screen
	_current_screen = screen
	_level = screen if screen.get_script() == preload("res://scripts/level.gd") else null
	if old:
		_wiping = true
		await _sweep(true)
		old.queue_free()
	add_child(screen)
	if old:
		await _sweep(false)
		_wiping = false


func _sweep(cover: bool) -> void:
	if not _wipe:
		var layer := CanvasLayer.new()
		layer.layer = 90
		add_child(layer)
		_wipe = ColorRect.new()
		_wipe.color = Color("#0a1320")
		_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wipe.modulate.a = 0.0
		layer.add_child(_wipe)
	_wipe.size = get_viewport().get_visible_rect().size # the whole screen, however wide the phone is
	_wipe.visible = true
	var tw := create_tween()
	tw.tween_property(_wipe, "modulate:a", 1.0 if cover else 0.0, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if not cover:
		_wipe.visible = false # gone completely once the new screen shows


## Back with no pop-up open: the screen decides what it means (see Game.go_back)
func _on_back() -> void:
	if _wiping or not is_instance_valid(_current_screen):
		return
	if _current_screen.has_method("go_back"):
		_current_screen.go_back()
