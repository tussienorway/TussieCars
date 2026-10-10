class_name TrackData
extends RefCounted

static var cache: Dictionary = {}

const WIDE_TILE := 54
const ROAD := "AOFN"

var id := ""
var track_name := ""
var environment := "coastal"
var laps := 3
var tile := 32
var width := 1
var height := 1
var rows: PackedStringArray = PackedStringArray()
var waypoints: PackedVector2Array = PackedVector2Array()
var checkpoints: Array = []
var grid: Array = []
var pickups: Array = []
var decor: Array = []
var image_path := ""


static func load_all() -> void:
	cache.clear()
	var dir := DirAccess.open("res://data/tracks")
	if dir == null:
		push_error("Track directory missing")
		return
	for file_name in dir.get_files():
		if not str(file_name).ends_with(".json") or str(file_name).begins_with("index"):
			continue
		var track := from_file("res://data/tracks/%s" % file_name)
		if track != null:
			cache[track.id] = track


static func ensure() -> void:
	if cache.is_empty():
		load_all()


static func get_track(track_id: String) -> TrackData:
	ensure()
	return cache.get(track_id)


static func all_tracks() -> Array:
	ensure()
	return cache.values()


static func from_file(path: String) -> TrackData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open %s" % path)
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Bad track %s" % path)
		return null
	return from_dict(parsed)


static func from_dict(raw: Dictionary) -> TrackData:
	var track := TrackData.new()
	track.id = str(raw.get("id", ""))
	track.track_name = str(raw.get("name", track.id))
	track.environment = str(raw.get("environment", "coastal"))
	track.laps = int(raw.get("laps", 3))
	var authored_tile := float(raw.get("tile", 32))
	track.tile = WIDE_TILE
	var k := float(WIDE_TILE) / authored_tile
	track.width = int(raw.get("width", 1))
	track.height = int(raw.get("height", 1))
	track.image_path = str(raw.get("image", ""))
	var packed := PackedStringArray()
	for row in raw.get("rows", []):
		packed.append(str(row))
	track.rows = packed
	var points := PackedVector2Array()
	for p in raw.get("waypoints", []):
		points.append(Vector2(float(p[0]), float(p[1])) * k)
	track.waypoints = points
	for cp in raw.get("checkpoints", []):
		track.checkpoints.append({
			"a": Vector2(float(cp["a"][0]), float(cp["a"][1])) * k,
			"b": Vector2(float(cp["b"][0]), float(cp["b"][1])) * k,
		})
	for slot in raw.get("grid", []):
		track.grid.append(Vector3(float(slot[0]) * k, float(slot[1]) * k, float(slot[2])))
	track.pickups = _scaled_points(raw.get("pickups", []), k)
	track.decor = _scaled_points(raw.get("decor", []), k)
	return track


static func _scaled_points(items: Array, k: float) -> Array:
	var out := []
	for item in items:
		var copy: Dictionary = (item as Dictionary).duplicate()
		copy["x"] = float(copy.get("x", 0.0)) * k
		copy["y"] = float(copy.get("y", 0.0)) * k
		out.append(copy)
	return out


func cell(point: Vector2) -> String:
	var tx := int(floor(point.x / float(tile)))
	var ty := int(floor(point.y / float(tile)))
	if tx < 0 or ty < 0 or tx >= width or ty >= height:
		return "B"
	if ty >= rows.size():
		return "B"
	var row := rows[ty]
	if tx >= row.length():
		return "B"
	return row.substr(tx, 1)


func blocking(point: Vector2) -> bool:
	return not is_road(cell(point))


static func is_road(kind: String) -> bool:
	return ROAD.contains(kind)


func surface_at(point: Vector2) -> Dictionary:
	var kind := cell(point)
	var table: Dictionary = Balance.dict_at("surfaces")
	if not table.has(kind):
		kind = "G"
	var row: Dictionary = table.get(kind, {"grip": 0.4, "drag": 1.0, "damage": 0})
	return {
		"id": kind,
		"grip": float(row.get("grip", 0.4)),
		"drag": float(row.get("drag", 1.0)),
		"damage": float(row.get("damage", 0.0)),
	}


func pixel_size() -> Vector2:
	return Vector2(width * tile, height * tile)
