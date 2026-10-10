class_name TrackValidator
extends RefCounted

const DRIVABLE := "GADSCOWNF"


static func validate(track: TrackData) -> PackedStringArray:
	var errors := PackedStringArray()
	if track == null:
		errors.append("null track")
		return errors
	if track.id == "":
		errors.append("missing id")
	if track.rows.size() != track.height:
		errors.append("row count %d != height %d" % [track.rows.size(), track.height])
	for y in track.rows.size():
		if track.rows[y].length() != track.width:
			errors.append("row %d width" % y)
			break
	if track.waypoints.size() < 16:
		errors.append("too few waypoints")
	if track.checkpoints.size() < 4:
		errors.append("too few checkpoints")
	if track.grid.size() < 6:
		errors.append("grid shorter than 6")
	if track.laps < 1:
		errors.append("laps")
	var road := 0
	for row in track.rows:
		for i in row.length():
			var ch := row.substr(i, 1)
			if ch in "AO":
				road += 1
			if ch not in "GADSCOWNFB":
				errors.append("unknown tile %s" % ch)
				break
	if road < 120:
		errors.append("road too small")
	if track.waypoints.is_empty():
		return errors
	var seen := _reachable(track, track.waypoints[0])
	var missed := 0
	for i in track.waypoints.size():
		var p: Vector2 = track.waypoints[i]
		if track.blocking(p):
			errors.append("waypoint blocked")
			break
		if DRIVABLE.find(track.cell(p)) < 0:
			errors.append("waypoint off surface")
			break
		if i % 3 == 0 and not seen.has(_key(track, p)):
			missed += 1
	if missed > 0:
		errors.append("centerline disconnected")
	for cp in track.checkpoints:
		var mid: Vector2 = (cp["a"] + cp["b"]) * 0.5
		if track.blocking(mid) or DRIVABLE.find(track.cell(mid)) < 0:
			errors.append("checkpoint off road")
			break
		var hits := 0
		for s in 9:
			var p: Vector2 = cp["a"].lerp(cp["b"], float(s) / 8.0)
			if DRIVABLE.find(track.cell(p)) >= 0 and not track.blocking(p):
				hits += 1
		if hits < 2:
			errors.append("checkpoint does not cross the road")
			break
	for slot in track.grid:
		var p := Vector2(slot.x, slot.y)
		var ch := track.cell(p)
		if ch not in "AOFCDS":
			errors.append("grid slot on %s" % ch)
			break
	if not track.image_path.is_empty() and not ResourceLoader.exists(track.image_path):
		errors.append("missing image %s" % track.image_path)
	return errors


static func _key(track: TrackData, p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / float(track.tile))), int(floor(p.y / float(track.tile))))


static func _reachable(track: TrackData, start: Vector2) -> Dictionary:
	var origin := _key(track, start)
	var seen := {}
	if DRIVABLE.find(track.cell(start)) < 0:
		return seen
	var stack: Array[Vector2i] = [origin]
	seen[origin] = true
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		for delta in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var nxt: Vector2i = cell + delta
			if seen.has(nxt):
				continue
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= track.width or nxt.y >= track.height:
				continue
			var sample := Vector2((nxt.x + 0.5) * track.tile, (nxt.y + 0.5) * track.tile)
			if DRIVABLE.find(track.cell(sample)) >= 0:
				seen[nxt] = true
				stack.append(nxt)
	return seen
