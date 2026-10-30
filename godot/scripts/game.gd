extends Node
## Shared by the whole game (the "Game" autoload): the art strips, the level data and the controls.

const TILE := 64
## Janani's outfits in unlock order (as in the Phaser game): she starts in the white kurti, and each
## World 1 level she clears unlocks the next one. Each has strips hero_<id>, hero_<id>_moves, hero_<id>_rope.
const OUTFITS := [
	# the Spriterrific Janani sets, for testing which one is best (data/hd.json, made by tools/prepare_hero2.py)
	{ "id": "beta", "name": "Beta 1", "desc": "White kurti", "beta": true },
	{ "id": "beta2", "name": "Beta 2", "desc": "White kurti 2", "beta": true },
	{ "id": "beta3", "name": "Beta 3", "desc": "Black dress", "beta": true },
	{ "id": "beta4", "name": "Beta 4", "desc": "\"25\" long run", "beta": true },
	{ "id": "beta5", "name": "Beta 5", "desc": "\"25\" idle", "beta": true },
	{ "id": "beta6", "name": "Beta 6", "desc": "\"25\" walk", "beta": true },
	{ "id": "beta7", "name": "Beta 7", "desc": "\"25\" smooth run", "beta": true },
]

var manifest: Dictionary   ## frame sizes of every sprite strip (data/manifest.json, made by tools/prepare_sprites.py)
var levels: Dictionary     ## every level as a tile grid (data/levels.json, made by tools/export_godot_data.mjs)
var skins: Dictionary      ## each level look made from the art packs (data/skins.json, made by tools/prepare_skins.py)
var hd: Dictionary         ## the new detailed (HD) Janani, per outfit (data/hd.json, made by tools/prepare_hero2.py)
var font: FontFile
const KITTY_SKINS := [
	{ "id": "orange", "name": "Ginger Tabby", "color": Color(0.95, 0.6, 0.2) },
	{ "id": "gray", "name": "Silver Tabby", "color": Color(0.7, 0.75, 0.8) },
	{ "id": "black", "name": "Midnight Black", "color": Color(0.25, 0.25, 0.3) },
	{ "id": "cream", "name": "Snow Cream", "color": Color(0.96, 0.92, 0.82) },
]

## carried from level to level in one play session (7 lives and 4 hearts: friendly for new players)
var state := { "lives": 7, "max_hearts": 4, "gems": 0 }
## saved player progress across sessions
const SLOTS := 3
const SAVE_DEFAULTS := {
	"cleared": [],   ## level ids finished (1-1 is always open; each cleared level opens the next)
	"crystals": {},
	"candles": [],
	"outfit": "beta7", # the "25" set: the one with the sword slash and ladder climb
	"kitty_skin": "orange",
	"rooms_seen": [],   ## world rooms she has walked into (the map fills in as she explores)
	"abilities": [],    ## what she has learned: "dash", "double_jump", "wall_jump"
	"room": "m1",       ## the room she is in (or last rested in)
	"bench": "m1",      ## the room of the bench she rested at last (where she returns after the title screen)
	"played": 0.0,   ## seconds played in this slot
	"saved_at": 0,   ## when this slot was last written (unix time)
}
## the progress of the slot being played (written to user://save_<slot>.json)
var save: Dictionary = SAVE_DEFAULTS.duplicate(true)
## 1..SLOTS; 0 means no slot is chosen yet (a fresh start: nothing is written until New Game picks one)
var slot := 0
## settings shared by every slot (user://settings.json)
var settings := { "music": true, "sound": true, "music_volume": 0.8, "sound_volume": 1.0, "shake": true, "last_slot": 0 }
var _textures := {}


func _ready() -> void:
	add_child(BackKey.new())
	load_save()
	manifest = _load_json("res://data/manifest.json")
	levels = _load_json("res://data/levels.json")
	skins = _load_json("res://data/skins.json")
	manifest.merge(_load_json("res://data/pack_frames.json")) # the effects strips (tools/prepare_effects.py)
	if FileAccess.file_exists("res://data/extra_frames.json"):
		manifest.merge(_load_json("res://data/extra_frames.json")) # the demon boss strip (tools/prepare_demon.py)
	# the new, detailed Janani (Spriterrific, tools/prepare_hero2.py): outfits that have her use these strips
	if FileAccess.file_exists("res://data/hd.json"):
		hd = _load_json("res://data/hd.json")
		for outfit_id: String in hd:
			var cell: int = hd[outfit_id].cell
			for action: Dictionary in hd[outfit_id].actions.values():
				# (the sword slash is wider than her square cell: it says its own size)
				manifest[action.key] = { "frameWidth": int(action.get("w", cell)), "frameHeight": int(action.get("h", cell)), "frames": action.frames }
	var powers: Dictionary = _load_json("res://data/powers.json")
	for def: Dictionary in levels.solo:
		def.powers = powers.get(def.id, [])
	font = load("res://fonts/press_start_2p.woff2")
	_setup_controls()
	_init_audio()


var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _audio_streams := {}

func _init_audio() -> void:
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	apply_volumes() # the players exist now: use the saved volumes


## counts the time played in the current slot (saved with it)
func _process(delta: float) -> void:
	if slot >= 1:
		save.played = float(save.get("played", 0.0)) + delta


func play_sfx(name: String) -> void:
	if not settings.sound:
		return
	var path := "res://assets/audio/sfx/%s.wav" % name
	if not ResourceLoader.exists(path):
		return
	if not _audio_streams.has(path):
		_audio_streams[path] = load(path)
	var stream: AudioStream = _audio_streams[path]
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	if not _sfx_players.is_empty():
		_sfx_players[0].stream = stream
		_sfx_players[0].play()


func play_music(track: String) -> void:
	if not settings.music:
		return
	var path := "res://assets/audio/music/%s.wav" % track
	if not ResourceLoader.exists(path):
		# Default fallback
		path = "res://assets/audio/music/meadow.wav"
	if not ResourceLoader.exists(path):
		return
	if not _audio_streams.has(path):
		var s: AudioStreamWAV = load(path)
		if s:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = s.data.size() / 2
		_audio_streams[path] = s
	var stream: AudioStream = _audio_streams[path]
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	if _music_player:
		_music_player.stop()


## Starts the game: loads the settings, moves an old single save into slot 1 (once), and loads the slot
## played last, if there is one.
func load_save() -> void:
	_load_settings()
	if FileAccess.file_exists("user://save.json") and not FileAccess.file_exists(_slot_path(1)):
		DirAccess.rename_absolute("user://save.json", _slot_path(1)) # the save from before there were slots
		settings.last_slot = 1
	var last := int(settings.last_slot)
	if last >= 1 and last <= SLOTS and has_slot(last):
		load_slot(last)


func _slot_path(i: int) -> String:
	return "user://save_%d.json" % i


func has_slot(i: int) -> bool:
	return FileAccess.file_exists(_slot_path(i))


func has_any_save() -> bool:
	for i in range(1, SLOTS + 1):
		if has_slot(i):
			return true
	return false


## What a slot holds, for the slot list: {} when empty, else cleared / crystals / candles / saved_at.
func slot_summary(i: int) -> Dictionary:
	if not has_slot(i):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(i)))
	if not parsed is Dictionary:
		return {}
	var crystals := 0
	for k: String in parsed.get("crystals", {}):
		var seen: Array = []
		for n: Variant in parsed.crystals[k]:
			if not seen.has(int(n)):
				seen.append(int(n))
		crystals += seen.size()
	var at: Dictionary = preload("res://scripts/world.gd").room(String(parsed.get("room", "m1")))
	return { "cleared": (parsed.get("cleared", []) as Array).size(), "crystals": crystals,
		"candles": (parsed.get("candles", []) as Array).size(), "saved_at": int(parsed.get("saved_at", 0)),
		"played": float(parsed.get("played", 0.0)), "rooms": (parsed.get("rooms_seen", []) as Array).size(),
		"moves": (parsed.get("abilities", []) as Array).size(), "where": String(at.get("name", "")) }


## How much there is to find in the whole world: rooms, candles and big crystals (for "3 / 5" counters).
func world_totals() -> Dictionary:
	if _totals.is_empty():
		var crystals := 0
		if _rooms.is_empty():
			room_def("m1") # (loads data/rooms.json)
		for r: Dictionary in _rooms.values():
			for row: String in r.grid:
				crystals += row.count("X")
		_totals = { "rooms": _rooms.size(), "candles": 5, "crystals": crystals }
	return _totals


## The first save slot with nothing in it (0 when all are used).
func first_empty_slot() -> int:
	for i in range(1, SLOTS + 1):
		if not has_slot(i):
			return i
	return 0


## Plays a saved slot.
func load_slot(i: int) -> void:
	save = SAVE_DEFAULTS.duplicate(true)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(i)))
	if parsed is Dictionary:
		save.merge(parsed, true)
	# JSON turns whole numbers into decimals (2 becomes 2.0), which then never match "has(2)": make the crystal
	# numbers whole again, once each (older saves had the same crystal saved many times over)
	for level_id: String in save.crystals:
		var whole: Array = []
		for n: Variant in save.crystals[level_id]:
			if not whole.has(int(n)):
				whole.append(int(n))
		save.crystals[level_id] = whole
	slot = i
	settings.last_slot = i
	_save_settings()


## Starts a fresh game in slot i (what was there is replaced).
func new_game(i: int) -> void:
	save = SAVE_DEFAULTS.duplicate(true)
	state = { "lives": 7, "max_hearts": 4, "gems": 0 }
	slot = i
	settings.last_slot = i
	write_save()
	_save_settings()


## She walks into a world room: the map remembers it (true when it's the first time).
func discover_room(id: String) -> bool:
	save.room = id
	if save.rooms_seen.has(id):
		return false
	save.rooms_seen.append(id)
	write_save()
	return true


func has_ability(ability: String) -> bool:
	return save.abilities.has(ability)


## She learns a move at a shrine ("dash", "double_jump", "wall_jump"); true when it's new.
func unlock_ability(ability: String) -> bool:
	if save.abilities.has(ability):
		return false
	save.abilities.append(ability)
	write_save()
	return true


func delete_slot(i: int) -> void:
	if has_slot(i):
		DirAccess.remove_absolute(_slot_path(i))
	if slot == i:
		slot = 0
		save = SAVE_DEFAULTS.duplicate(true)
	if int(settings.last_slot) == i:
		settings.last_slot = 0
		_save_settings()


func write_save() -> void:
	if slot < 1:
		return # no slot chosen yet: nothing to write
	save.saved_at = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save, "\t"))


func _load_settings() -> void:
	if FileAccess.file_exists("user://settings.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
		if parsed is Dictionary:
			settings.merge(parsed, true)
	apply_volumes()


func _save_settings() -> void:
	var file := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))


## Changes one setting, saves it and applies it at once.
func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_save_settings()
	apply_volumes()


## The music and sound volumes (0 to 1) become the loudness of the players.
func apply_volumes() -> void:
	if _music_player:
		_music_player.volume_db = linear_to_db(maxf(0.0001, float(settings.music_volume)))
	for p in _sfx_players:
		p.volume_db = linear_to_db(maxf(0.0001, float(settings.sound_volume)))


func _load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## A picture by name. Looks in pack/, ui/, rpg/, kitty/ and assets/.
func texture(key: String) -> Texture2D:
	if key == "portrait_kitty":
		key = "portrait_kitty_%s" % kitty_skin()
	if not _textures.has(key):
		var paths: Array[String] = [
			"res://assets/pack/%s.png" % key,
			"res://assets/ui/%s.png" % key,
			"res://assets/rpg/%s.png" % key,
			"res://assets/kitty/%s.png" % key,
			"res://assets/%s.png" % key
		]
		for p: String in paths:
			if ResourceLoader.exists(p):
				_textures[key] = load(p)
				break
	return _textures.get(key)


## One picture out of a sprite strip (a row of equal cells; cell sizes come from manifest.json).
func frame(key: String, index: int, cell_width := 0) -> Texture2D:
	var info: Dictionary = manifest.get(key, {})
	var w: int = cell_width if cell_width else int(info.get("frameWidth", 0))
	if w == 0:
		return texture(key) # a single picture, not a strip
	var tex := AtlasTexture.new()
	tex.atlas = texture(key)
	tex.region = Rect2(index * w, 0, w, tex.atlas.get_height())
	return tex


## The outfit Janani wears, checked: falls back to the beta version.
func outfit() -> String:
	var id := String(save.get("outfit", "beta"))
	for o: Dictionary in OUTFITS:
		if o.id == id:
			return id
	return "beta"


## The coat skin Kitty wears (orange, gray, black, cream).
func kitty_skin() -> String:
	return String(save.get("kitty_skin", "orange"))


func set_kitty_skin(skin_id: String) -> void:
	save.kitty_skin = skin_id
	write_save()


## Animations for Kitty in her chosen coat skin (idle, walk, run, leap, jump, attack, hurt).
func kitty_frames(skin_id := "") -> SpriteFrames:
	var skin := skin_id if not skin_id.is_empty() else kitty_skin()
	var run_key := "kitty_%s_run" % skin
	var jump_key := "kitty_%s_jump" % skin
	var attack_key := "kitty_%s_attack" % skin
	var hurt_key := "kitty_%s_hurt" % skin
	var idle_key := "kitty_%s_idle" % skin
	if not manifest.has(run_key):
		skin = "orange"
		run_key = "kitty_orange_run"
		jump_key = "kitty_orange_jump"
		attack_key = "kitty_orange_attack"
		hurt_key = "kitty_orange_hurt"
		idle_key = "kitty_orange_idle"
	var run_cnt: int = manifest.get(run_key, {}).get("frames", 20)
	var jump_cnt: int = manifest.get(jump_key, {}).get("frames", 25)
	var attack_cnt: int = manifest.get(attack_key, {}).get("frames", 25)
	var hurt_cnt: int = manifest.get(hurt_key, {}).get("frames", 25)
	var idle_cnt: int = manifest.get(idle_key, {}).get("frames", 6)
	return sprite_frames({
		"idle": [idle_key, range(idle_cnt), 6, true],
		"walk": [run_key, range(run_cnt), 12, true],
		"run": [run_key, range(run_cnt), 24, true],
		"leap": [jump_key, [7, 8, 9, 10, 11, 12, 13, 14, 15, 16], 14, false],
		"jump": [jump_key, range(jump_cnt), 24, false],
		"attack": [attack_key, range(attack_cnt), 24, false],
		"hurt": [hurt_key, range(hurt_cnt), 24, false],
	})


## The detailed Janani's animations for an outfit that has her (hd), with the same names as the old ones
## (idle, walk, run, takeoff, rise, peak, fall, land, hurt, victory); null when the outfit hasn't got her.
## Her frames are square cells with her feet on the bottom edge: offset an AnimatedSprite2D by (-cell/2, -cell).
func detailed_frames(outfit_id: String) -> SpriteFrames:
	if not hd.has(outfit_id):
		return null
	var a: Dictionary = hd[outfit_id].actions
	var run: String = a.run.key
	var jump: String = a.jump.key
	var hurt: String = a.hurt.key # its first frames are her standing still
	var rf: int = int(a.run.frames)
	var jf: int = int(a.jump.frames)
	var hf: int = int(a.hurt.frames)
	# the frames between two points of a clip (0 = its start, 1 = its end): every set has its own frame counts
	var part := func(n: int, from: float, to: float) -> Array:
		var out: Array = []
		for i in range(int(n * from), maxi(int(n * from) + 1, int(n * to))):
			out.append(mini(i, n - 1))
		return out
	var run_fps := clampf(rf / 0.65, 12.0, 26.0) # one stride cycle takes about two thirds of a second
	var idle_def: Array = [hurt, part.call(hf, 0.0, 0.24) + part.call(hf, 0.12, 0.2), 6, true] # (still frames of the hurt clip)
	if a.has("idle"):
		idle_def = [a.idle.key, range(int(a.idle.frames)), float(a.idle.get("fps", 6)), true]
	var walk_def: Array = [run, range(rf), run_fps * 0.6, true]
	if a.has("walk"):
		walk_def = [a.walk.key, range(int(a.walk.frames)), float(a.walk.get("fps", 10)), true]
	# on a ladder: her own climbing frames (AutoSprite, the "25" sets), or the walk cycle
	var climb_def: Array = [walk_def[0], walk_def[1], walk_def[2], true]
	if a.has("climb"):
		climb_def = [a.climb.key, range(int(a.climb.frames)), float(a.climb.get("fps", 11)), true]
	# the sword slash: from the wind-up's end (frame 5) so the hit comes quickly; without one, a quick lunge
	var slash_def: Array = [jump, part.call(jf, 0.80, 0.92), 16, false]
	if a.has("slash"):
		slash_def = [a.slash.key, range(mini(5, int(a.slash.frames) - 1), int(a.slash.frames)), 36, false]
	return sprite_frames({
		"climb": climb_def,
		"slash": slash_def,
		"idle": idle_def,
		"walk": walk_def,
		"run": [run, range(rf), run_fps, true],
		"takeoff": [jump, part.call(jf, 0.24, 0.32), 16, false],
		"rise": [jump, part.call(jf, 0.40, 0.52), 12, false],
		"peak": [jump, part.call(jf, 0.56, 0.68), 10, false],
		"fall": [jump, part.call(jf, 0.68, 0.80), 12, false],
		"land": [jump, part.call(jf, 0.80, 0.92), 16, false],
		"hurt": [hurt, part.call(hf, 0.32, 0.52), 24, false],
		"victory": [jump, [0], 1, false],
	})


## A picture of Janani standing in an outfit (the wardrobe's cards).
func outfit_picture(outfit_id: String) -> Texture2D:
	if hd.has(outfit_id): # her standing frame, cropped close like the old 104x150 pictures
		var cell: int = hd[outfit_id].cell
		var tex := AtlasTexture.new()
		tex.atlas = texture(hd[outfit_id].actions.hurt.key)
		tex.region = Rect2(cell / 2.0 - 60, cell - 172, 120, 172)
		return tex
	return frame("hero_" + outfit_id, 0)


## Animations for an AnimatedSprite2D, as { name: [strip, frame numbers, frames per second, loops?] }.
func sprite_frames(defs: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in defs:
		var d: Array = defs[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, d[2])
		frames.set_animation_loop(anim, d[3])
		for i: int in d[1]:
			frames.add_frame(anim, frame(d[0], i))
	return frames


## A text label for signs and name tags in the level: carved Cinzel capitals with a dark outline, so they
## read on any background. (Sizes were chosen for the old pixel font, which ran bigger: hence the 1.5.)
func label(text: String, size := 16, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", preload("res://scripts/ui.gd").font("title"))
	l.add_theme_font_size_override("font_size", int(size * 1.5))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.06, 0.85))
	l.add_theme_constant_override("outline_size", maxi(5, size / 2))
	return l


## Keyboard controls (the phone's touch buttons press the same actions).
func _setup_controls() -> void:
	var keys := {
		"left": [KEY_LEFT, KEY_A],
		"right": [KEY_RIGHT, KEY_D],
		"up": [KEY_UP, KEY_W],
		"down": [KEY_DOWN, KEY_S],
		"jump": [KEY_UP, KEY_W, KEY_SPACE],
		"shoot": [KEY_X, KEY_J],
		"attack": [KEY_Z, KEY_K],
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: int in keys[action]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)


## A world room as a level definition (data/rooms.json, made by tools/build_rooms.py); {} if it isn't built yet.
func room_def(id: String) -> Dictionary:
	if _rooms.is_empty() and FileAccess.file_exists("res://data/rooms.json"):
		_rooms = _load_json("res://data/rooms.json")
	return _rooms.get(id, {})


var _rooms: Dictionary = {}

# ------------------------------------------------------------- going back ---

## Esc on a computer or the Back button on a phone, when no pop-up is open: the screen decides (main.gd)
signal back_pressed
## the pop-ups and the map that are open, newest last: Back closes the newest first
var overlays: Array[Node] = []
var _last_back := -1000


## Back: close the newest pop-up, or else tell the screen (a room pauses, a page returns to the title).
func go_back() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_back < 250: # (some phones send the Back button twice)
		return
	_last_back = now
	overlays = overlays.filter(func(n: Node) -> bool: return is_instance_valid(n) and n.is_inside_tree())
	if not overlays.is_empty():
		var top: Node = overlays.back()
		if top.get("can_close") != false:
			top.close()
		return
	back_pressed.emit()


## listens for Esc and the phone's Back button all the time, even while the game is paused
class BackKey extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key and key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_BACK):
			get_viewport().set_input_as_handled()
			get_parent().go_back()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_GO_BACK_REQUEST:
			get_parent().go_back()

var _totals: Dictionary = {}  ## world_totals(), worked out once


func beta_level() -> Dictionary:
	if FileAccess.file_exists("res://data/beta_level.json"):
		var l: Variant = _load_json("res://data/beta_level.json")
		if l is Dictionary:
			return l
	return levels.solo[2]
