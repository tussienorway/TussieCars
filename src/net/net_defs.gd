class_name NetDefs
extends RefCounted

const PORT := 7777
const DISCOVERY_PORT := 7778
const MAX_HUMANS := 4
const MAX_CARS := 6
const SNAP_EVERY := 2

const PAINTS := ["cyan", "red", "yellow", "green", "blue", "violet", "orange", "white"]


static func sanitize_input(raw: Dictionary) -> Dictionary:
	return {
		"throttle": clampf(float(raw.get("throttle", 0.0)), 0.0, 1.0),
		"brake": clampf(float(raw.get("brake", 0.0)), 0.0, 1.0),
		"steer": clampf(float(raw.get("steer", 0.0)), -1.0, 1.0),
		"fire_front": bool(raw.get("fire_front", false)),
		"fire_rear": bool(raw.get("fire_rear", false)),
		"drop_mine": bool(raw.get("drop_mine", false)),
		"boost": bool(raw.get("boost", false)),
		"drift": bool(raw.get("drift", false)),
	}


static func neutral_input() -> Dictionary:
	return {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "fire_front": false, "fire_rear": false, "drop_mine": false, "boost": false, "drift": false}


static func car_snap(car: CarState) -> Dictionary:
	var flags := 0
	if car.boosting:
		flags |= 1
	if car.drifting:
		flags |= 2
	if car.drafting:
		flags |= 4
	if car.finished:
		flags |= 8
	if car.dnf:
		flags |= 16
	return {
		"id": car.id,
		"x": snappedf(car.pos.x, 0.1),
		"y": snappedf(car.pos.y, 0.1),
		"vx": snappedf(car.vel.x, 0.5),
		"vy": snappedf(car.vel.y, 0.5),
		"h": snappedf(car.heading, 0.001),
		"hp": snappedf(car.hp, 0.5),
		"b": snappedf(car.boost, 0.01),
		"f": flags,
		"lap": car.laps,
		"rank": car.rank,
		"ft": snappedf(car.finish_time, 0.01),
		"a": [car.ammo_missile, car.ammo_mine, car.ammo_rear],
	}


static func build_snapshot(sim: RaceSim) -> Dictionary:
	var cars := []
	for car in sim.cars:
		cars.append(car_snap(car))
	var shots := []
	for shot in sim.shots:
		var p: Vector2 = shot["pos"]
		var v: Vector2 = shot["vel"]
		shots.append({
			"p": [snappedf(p.x, 0.5), snappedf(p.y, 0.5)],
			"v": [snappedf(v.x, 1.0), snappedf(v.y, 1.0)],
			"d": float(shot["damage"]),
			"o": str(shot["owner"]),
			"l": snappedf(float(shot["life"]), 0.05),
			"k": str(shot["kind"]),
			"id": int(shot["id"]),
		})
	var mines := []
	for mine in sim.mines:
		var p: Vector2 = mine["pos"]
		mines.append({
			"p": [snappedf(p.x, 0.5), snappedf(p.y, 0.5)],
			"o": str(mine["owner"]),
			"arm": snappedf(float(mine["arm"]), 0.05),
			"l": snappedf(float(mine["life"]), 0.1),
			"d": float(mine["damage"]),
			"id": int(mine["id"]),
		})
	var taken := []
	for pickup in sim.pickups:
		taken.append(bool(pickup["taken"]))
	return {
		"t": snappedf(sim.race_time, 0.02),
		"s": sim.state,
		"c": snappedf(sim.countdown, 0.05),
		"cars": cars,
		"shots": shots,
		"mines": mines,
		"taken": taken,
	}


static func apply_snapshot(sim: RaceSim, snap: Dictionary) -> void:
	sim.race_time = float(snap.get("t", 0.0))
	sim.state = str(snap.get("s", "racing"))
	sim.countdown = float(snap.get("c", 0.0))
	var by_id := {}
	for car in sim.cars:
		by_id[car.id] = car
	for cs in snap.get("cars", []):
		var car: CarState = by_id.get(str(cs.get("id", "")))
		if car == null:
			continue
		car.pos = Vector2(float(cs.get("x", 0.0)), float(cs.get("y", 0.0)))
		car.vel = Vector2(float(cs.get("vx", 0.0)), float(cs.get("vy", 0.0)))
		car.heading = float(cs.get("h", 0.0))
		car.hp = float(cs.get("hp", 100.0))
		car.boost = float(cs.get("b", 1.0))
		var flags := int(cs.get("f", 0))
		car.boosting = (flags & 1) != 0
		car.drifting = (flags & 2) != 0
		car.drafting = (flags & 4) != 0
		car.finished = (flags & 8) != 0
		car.dnf = (flags & 16) != 0
		car.laps = int(cs.get("lap", 0))
		car.rank = int(cs.get("rank", 1))
		car.finish_time = float(cs.get("ft", 0.0))
		var ammo: Array = cs.get("a", [12, 0, 0])
		if ammo.size() >= 3:
			car.ammo_missile = int(ammo[0])
			car.ammo_mine = int(ammo[1])
			car.ammo_rear = int(ammo[2])
	sim.shots.clear()
	for s in snap.get("shots", []):
		var pp: Array = s.get("p", [0, 0])
		var vv: Array = s.get("v", [0, 0])
		sim.shots.append({
			"id": int(s.get("id", 0)),
			"pos": Vector2(float(pp[0]), float(pp[1])),
			"vel": Vector2(float(vv[0]), float(vv[1])),
			"damage": float(s.get("d", 20.0)),
			"owner": str(s.get("o", "")),
			"life": float(s.get("l", 1.0)),
			"max": 1.25,
			"kind": str(s.get("k", "missile")),
		})
	sim.mines.clear()
	for m in snap.get("mines", []):
		var pp: Array = m.get("p", [0, 0])
		sim.mines.append({
			"id": int(m.get("id", 0)),
			"pos": Vector2(float(pp[0]), float(pp[1])),
			"owner": str(m.get("o", "")),
			"arm": float(m.get("arm", 0.0)),
			"life": float(m.get("l", 16.0)),
			"damage": float(m.get("d", 34.0)),
			"radius": 22.0,
		})
	var taken: Array = snap.get("taken", [])
	for i in mini(taken.size(), sim.pickups.size()):
		sim.pickups[i]["taken"] = bool(taken[i])


static func discovery_packet(host_name: String, track_id: String, humans: int, port: int) -> Dictionary:
	return {"game": "tussiecars", "v": 1, "name": host_name.left(24), "track": track_id, "humans": humans, "port": port}


static func parse_discovery(raw: Dictionary) -> Dictionary:
	if str(raw.get("game", "")) != "tussiecars":
		return {}
	if int(raw.get("v", 0)) != 1:
		return {}
	return {
		"name": str(raw.get("name", "Host")).left(24),
		"track": str(raw.get("track", "harbor_loop")),
		"humans": clampi(int(raw.get("humans", 1)), 1, MAX_HUMANS),
		"port": clampi(int(raw.get("port", PORT)), 1024, 65535),
	}


static func clean_paint(paint: String) -> String:
	if paint in PAINTS:
		return paint
	return "cyan"


static func clean_player_name(raw: String) -> String:
	var name := str(raw).strip_edges().left(16)
	if name == "":
		return "Driver"
	return name
