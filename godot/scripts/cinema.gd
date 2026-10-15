extends Node2D
## A level's light and mood, for the cinematic look: a colour grade over the whole level (golden hour,
## cool wind, bright sky, desert sunset, moonlight), shafts of light, floating motes or fireflies, a dark
## vignette at the screen edges, and a soft light around Janani (strong at night, so she carries her own glow).
## Added by level.gd as a part; gems, crystals and candles get their glows in level._item().

const UI := preload("res://scripts/ui.gd")

## mood: [grade, rays colour (alpha = strength, 0 = none), motes colour, motes count, vignette, Janani's light]
const MOODS := {
	"day":    [Color(1.0, 0.94, 0.86), Color(1.0, 0.85, 0.55, 0.32), Color(1.0, 0.9, 0.6), 22, 0.45, Color(1.0, 0.85, 0.6, 0.10)],
	"windy":  [Color(0.88, 0.93, 0.98), Color(0.85, 0.95, 1.0, 0.0), Color(1, 1, 1), 0, 0.5, Color(1.0, 0.9, 0.7, 0.08)],
	"sky":    [Color(0.98, 0.97, 1.0), Color(1.0, 0.97, 0.85, 0.28), Color(1.0, 1.0, 0.9), 14, 0.35, Color(1.0, 0.95, 0.8, 0.08)],
	"golden": [Color(1.0, 0.84, 0.7), Color(1.0, 0.7, 0.4, 0.38), Color(1.0, 0.8, 0.5), 24, 0.55, Color(1.0, 0.75, 0.45, 0.14)],
	"dusk":   [Color(0.52, 0.58, 0.82), Color(0.7, 0.8, 1.0, 0.18), Color(0.75, 1.0, 0.65), 40, 0.7, Color(1.0, 0.85, 0.6, 0.38)],
}

var level: Node2D
var mood := "day"


func build(level_mood: String) -> void:
	mood = level_mood if MOODS.has(level_mood) else "day"
	var m: Array = MOODS[mood]
	var grade := CanvasModulate.new() # tints everything in the level (not the HUD)
	grade.color = m[0]
	add_child(grade)

	var vp := get_viewport_rect().size
	var over := CanvasLayer.new()
	over.layer = 2 # over the level, under the HUD
	add_child(over)
	if m[1].a > 0:
		over.add_child(UI.light_rays(vp, m[1], -0.35))
	if m[3] > 0:
		over.add_child(UI.fireflies(vp, m[3], m[2]))
	over.add_child(UI.vignette(vp, m[4]))


## the soft light that travels with Janani
func light_player(player: Node2D) -> void:
	var light := UI.glow(260, MOODS[mood][5])
	light.position = Vector2(0, -70)
	light.z_index = -1
	light.z_as_relative = true
	player.add_child(light)
