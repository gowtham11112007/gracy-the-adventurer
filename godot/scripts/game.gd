extends Node
## Shared by the whole game (the "Game" autoload): the art strips, the level data and the controls.

const TILE := 64
## Janani's outfits in unlock order (as in the Phaser game): she starts in the white kurti, and each
## World 1 level she clears unlocks the next one. Each has strips hero_<id>, hero_<id>_moves, hero_<id>_rope.
const OUTFITS := [
	{ "id": "beta", "name": "Janani (Beta)", "beta": true },
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
var save := {
	"cleared": [],   ## level ids finished (1-1 is always open; each cleared level opens the next)
	"crystals": {},
	"candles": [],
	"outfit": "beta",
	"kitty_skin": "orange",
	"music": true,
	"sound": true
}
var _textures := {}


func _ready() -> void:
	load_save()
	manifest = _load_json("res://data/manifest.json")
	levels = _load_json("res://data/levels.json")
	skins = _load_json("res://data/skins.json")
	manifest.merge(_load_json("res://data/pack_frames.json")) # the effects strips (tools/prepare_effects.py)
	# the new, detailed Janani (Spriterrific, tools/prepare_hero2.py): outfits that have her use these strips
	if FileAccess.file_exists("res://data/hd.json"):
		hd = _load_json("res://data/hd.json")
		for outfit_id: String in hd:
			var cell: int = hd[outfit_id].cell
			for action: Dictionary in hd[outfit_id].actions.values():
				manifest[action.key] = { "frameWidth": cell, "frameHeight": cell, "frames": action.frames }
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


func play_sfx(name: String) -> void:
	if save.has("sound") and not save.sound:
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
	if save.has("music") and not save.music:
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


func load_save() -> void:
	if FileAccess.file_exists("user://save.json"):
		var json_str := FileAccess.get_file_as_string("user://save.json")
		var parsed: Variant = JSON.parse_string(json_str)
		if parsed is Dictionary:
			save.merge(parsed, true)


func write_save() -> void:
	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save, "\t"))


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
	return sprite_frames({
		"idle": [hurt, [0, 1, 2, 3, 4, 5, 4, 3, 2, 1], 6, true],
		"walk": [run, range(a.run.frames), 8, true],
		"run": [run, range(a.run.frames), 16, true],
		"takeoff": [jump, [6, 7], 16, false],
		"rise": [jump, [10, 11, 12], 12, false],
		"peak": [jump, [14, 15, 16], 10, false],
		"fall": [jump, [17, 18, 19], 12, false],
		"land": [jump, [20, 21, 22], 16, false],
		"hurt": [hurt, [8, 9, 10, 11, 12], 24, false],
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
		"shoot": [KEY_X, KEY_J]
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: int in keys[action]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)


func beta_level() -> Dictionary:
	if FileAccess.file_exists("res://data/beta_level.json"):
		var l: Variant = _load_json("res://data/beta_level.json")
		if l is Dictionary:
			return l
	return levels.solo[2]
