extends RefCounted
## The world's rules, from data/world.json (designed with tools/design_world_map.py): which rooms there are, where
## they sit on the map, which rooms join, and which doors need an ability (dash, double_jump, wall_jump) or
## lit candles ("candles:3"). Use it as  const World := preload("res://scripts/world.gd")
## The solver (`solve`) plays the whole game on paper: it proves every room can be reached.

const PATH := "res://data/world.json"

static var _data: Dictionary = {}
static var _by_id: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		for r: Dictionary in _data.rooms:
			_by_id[r.id] = r
	return _data


static func rooms() -> Array:
	return data().rooms


static func edges() -> Array:
	return data().edges


static func start() -> String:
	return data().start


static func room(id: String) -> Dictionary:
	data()
	return _by_id.get(id, {})


## The colour of a room's area.
static func area_color(area: String) -> Color:
	return Color(data().areas[area].color)


## Rooms next to this one, each as { "room": id, "gate": "" or the thing the door needs }.
static func neighbors(id: String) -> Array:
	var out: Array = []
	for e: Dictionary in edges():
		if e.from == id:
			out.append({ "room": e.to, "gate": e.gate })
		elif e.to == id:
			out.append({ "room": e.from, "gate": e.gate })
	return out


## Does a door open with these abilities and this many lit candles?
static func gate_open(gate: String, abilities: Array, candles: int) -> bool:
	if gate.is_empty():
		return true
	if gate.begins_with("candles:"):
		return candles >= int(gate.get_slice(":", 1))
	return abilities.has(gate)


## Every room she can walk to from `from` with these abilities and candles.
static func reachable(abilities: Array, candles: int, from: String) -> Array:
	var seen: Array = [from]
	var todo: Array = [from]
	while not todo.is_empty():
		var here: String = todo.pop_back()
		for n: Dictionary in neighbors(here):
			if not seen.has(n.room) and gate_open(n.gate, abilities, candles):
				seen.append(n.room)
				todo.append(n.room)
	return seen


## Plays the game on paper: explore, pick up every ability and candle on the way, explore again...
## Returns { "reached": rooms, "abilities": what she learned, "candles": how many }.
static func solve() -> Dictionary:
	var abilities: Array = []
	var candles := 0
	var reached: Array = reachable(abilities, candles, start())
	var changed := true
	while changed:
		changed = false
		for id: String in reached:
			for item: String in room(id).has:
				if item.begins_with("ability:") and not abilities.has(item.get_slice(":", 1)):
					abilities.append(item.get_slice(":", 1))
					changed = true
		candles = 0
		for id: String in reached:
			if room(id).has.has("candle"):
				candles += 1
		var more := reachable(abilities, candles, start())
		if more.size() > reached.size():
			reached = more
			changed = true
	return { "reached": reached, "abilities": abilities, "candles": candles }
