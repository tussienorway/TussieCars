class_name Balance
extends RefCounted

static var data: Dictionary = {}
static var vehicles: Array = []
static var drivers: Array = []
static var championships: Array = []
static var loaded := false


static func load_data() -> void:
	if loaded:
		return
	data = _read_json("res://data/balance.json")
	vehicles = _read_json("res://data/vehicles.json")
	drivers = _read_json("res://data/drivers.json")
	championships = _read_json("res://data/championships.json")
	loaded = true


static func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing data file %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Bad JSON %s" % path)
		return {}
	return parsed


static func vehicle(id: String) -> Dictionary:
	load_data()
	for v in vehicles:
		if str(v["id"]) == id:
			return v
	return {}


static func driver(id: String) -> Dictionary:
	load_data()
	for d in drivers:
		if str(d["id"]) == id:
			return d
	return {}


static func championship(id: String) -> Dictionary:
	load_data()
	for c in championships:
		if str(c["id"]) == id:
			return c
	return {}


static func num(path: String, fallback: float) -> float:
	load_data()
	var node = data
	for part in path.split("."):
		if typeof(node) != TYPE_DICTIONARY or not node.has(part):
			return fallback
		node = node[part]
	return float(node)


static func dict_at(path: String) -> Dictionary:
	load_data()
	var node = data
	for part in path.split("."):
		if typeof(node) != TYPE_DICTIONARY or not node.has(part):
			return {}
		node = node[part]
	if typeof(node) == TYPE_DICTIONARY:
		return node
	return {}
