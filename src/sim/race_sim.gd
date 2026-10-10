class_name RaceSim
extends RefCounted

var track: TrackData
var cars: Array = []
var shots: Array = []
var mines: Array = []
var pickups: Array = []
var events: Array = []
var state := "countdown"
var countdown := 3.4
var race_time := 0.0
var time_limit := 240.0
var wet_grip := 1.0
var knockout := false
var knock_interval := 20.0
var next_knock := 20.0
var use_ai_for_players := false
var inputs: Dictionary = {}
var _shot_serial := 1
var _rng := RandomNumberGenerator.new()
var difficulty := "pro"
var tier := "club"
var ai_wobble := 0.035
var catchup := true


func setup(config: Dictionary) -> void:
	_rng.seed = 14021
	track = TrackData.get_track(str(config.get("track_id", "test_oval")))
	difficulty = str(config.get("difficulty", "pro"))
	tier = str(config.get("tier", "club"))
	catchup = difficulty != "ace"
	ai_wobble = {"ace": 0.0, "pro": 0.035, "rookie": 0.06}.get(difficulty, 0.035)
	time_limit = float(config.get("time_limit", 330.0))
	wet_grip = Balance.num("weather.rain_grip", 0.8) if str(config.get("weather", "clear")) == "rain" else 1.0
	knockout = bool(config.get("knockout", false))
	knock_interval = Balance.num("knockout.interval", 20.0)
	next_knock = knock_interval
	if knockout:
		time_limit = maxf(time_limit, knock_interval * 12.0)
	cars.clear()
	shots.clear()
	mines.clear()
	events.clear()
	pickups.clear()
	for raw in track.pickups:
		pickups.append({
			"x": float(raw["x"]),
			"y": float(raw["y"]),
			"kind": str(raw["kind"]),
			"taken": false,
			"respawn": 0.0,
		})
	var roster: Array = config.get("roster", [])
	var slots: Array = track.grid
	for i in roster.size():
		var spec: Dictionary = roster[i]
		var car := CarState.new()
		car.apply_spec(spec)
		var slot: Vector3 = slots[mini(i, slots.size() - 1)]
		if i >= slots.size():
			var last: Vector3 = slots[slots.size() - 1]
			var back := Vector2.from_angle(last.z) * (46.0 * float(i - slots.size() + 1))
			slot = Vector3(last.x - back.x, last.y - back.y, last.z)
		car.pos = Vector2(slot.x, slot.y)
		car.prev_pos = car.pos
		car.heading = slot.z
		car.next_cp = 1 if track.checkpoints.size() > 1 else 0
		car.lap_start = 0.0
		_seed_waypoint(car)
		cars.append(car)
	state = "countdown"
	countdown = 3.4
	race_time = 0.0


func start_now() -> void:
	state = "racing"
	countdown = 0.0


func step(delta: float) -> void:
	events.clear()
	if state == "countdown":
		countdown -= delta
		if countdown <= 0.0:
			state = "racing"
			events.append({"type": "go"})
		return
	if state != "racing":
		return
	race_time += delta
	for car in cars:
		if car.finished or car.dnf:
			car.boosting = false
			car.drafting = false
			car.drifting = false
			car.vel = car.vel.move_toward(Vector2.ZERO, 700.0 * delta)
			car.pos += car.vel * delta
			continue
		var input := _input_for(car, delta)
		if car.recover_time > 0.0:
			input["reverse"] = true
			input["throttle"] = 0.0
			input["brake"] = 0.0
			input["boost"] = false
			input["drift"] = false
			input["steer"] = car.recover_steer
			car.recover_time -= delta
		var surf := track.surface_at(car.pos)
		if wet_grip < 1.0:
			surf = surf.duplicate()
			surf["grip"] = float(surf["grip"]) * wet_grip
		input["draft"] = _in_slipstream(car)
		car.prev_pos = car.pos
		CarSim.integrate(car, input, delta, surf)
		var hp_before: float = car.hp
		var human_driven: bool = car.is_player and not use_ai_for_players
		var wall_scale := Balance.num("wall_damage", 0.1) * (1.0 if human_driven else Balance.num("ai_wall_factor", 0.35))
		var impact := CarSim.move(car, delta, track, wall_scale)
		if impact > 140.0 or car.hp < hp_before - 1.0:
			events.append({"type": "crash", "pos": car.pos, "amount": impact, "id": car.id, "damage": hp_before - car.hp})
		_maybe_fire(car, input)
		_advance_wp(car)
		_cross_checkpoint(car)
		if car.vel.length() < 36.0:
			car.stuck_time += delta
		else:
			car.stuck_time = 0.0
		if car.stuck_time > 1.15 and (not car.is_player or use_ai_for_players):
			var nwp := track.waypoints.size()
			if nwp > 0:
				var home: Vector2 = track.waypoints[(car.wp_index + 5) % nwp] - car.pos
				if home.length() > 8.0:
					car.recover_steer = clampf(Geom.ang_diff(home.angle(), car.heading) * 2.4, -1.0, 1.0)
					var nudge: Vector2 = car.pos + home.normalized() * 28.0
					if not track.blocking(nudge):
						car.pos = nudge
						car.heading = home.angle()
						car.vel = home.normalized() * 70.0
			car.recover_time = 0.45
			car.stuck_time = 0.0
		if car.hp <= 0.0:
			_destroy(car)
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var before_a: float = cars[i].hp
			var before_b: float = cars[j].hp
			var contact := 0.0 if race_time < 2.0 else Balance.num("collision_damage", 0.05)
			CarSim.separate(cars[i], cars[j], contact)
			if cars[i].hp < before_a - 4.0 or cars[j].hp < before_b - 4.0:
				events.append({"type": "crash", "pos": (cars[i].pos + cars[j].pos) * 0.5, "amount": 160.0})
			if cars[i].hp <= 0.0:
				_destroy(cars[i])
			if cars[j].hp <= 0.0:
				_destroy(cars[j])
	_update_shots(delta)
	_update_mines(delta)
	_update_pickups(delta)
	_assign_ranks()
	if knockout:
		_knockout_tick()
	if state == "racing" and (_humans_done() or race_time >= time_limit):
		if knockout:
			var alive := alive_cars()
			alive.sort_custom(func(a, b): return a.rank < b.rank)
			if not alive.is_empty():
				alive[0].finished = true
				alive[0].finish_time = race_time
		if race_time >= time_limit:
			for car in cars:
				if not car.finished:
					car.dnf = true
		state = "finished"
		_assign_ranks()
		events.append({"type": "finished"})


func alive_cars() -> Array:
	return cars.filter(func(c): return not c.dnf and not c.finished)


func knockout_in() -> float:
	return maxf(0.0, next_knock - race_time)


func _knockout_tick() -> void:
	if race_time < next_knock:
		return
	next_knock += knock_interval
	var alive := alive_cars()
	if alive.size() > 1:
		alive.sort_custom(func(a, b): return a.rank > b.rank)
		var out: CarState = alive[0]
		out.dnf = true
		out.knocked_at = race_time
		out.vel *= 0.3
		events.append({"type": "knockout", "id": out.id, "name": out.driver_name, "pos": out.pos, "is_player": out.is_player})
		alive.remove_at(0)
	if alive.size() == 1:
		var survivor: CarState = alive[0]
		survivor.finished = true
		survivor.finish_time = race_time
		events.append({"type": "finish", "id": survivor.id, "time": race_time})
		state = "finished"
		_assign_ranks()
		events.append({"type": "finished"})


func _humans_done() -> bool:
	var any_human := false
	for car in cars:
		if car.is_player:
			any_human = true
			if not car.finished and not car.dnf:
				return false
	return any_human


func _input_for(car: CarState, delta: float) -> Dictionary:
	if car.is_player and not use_ai_for_players:
		var raw = inputs.get(car.player_index, {})
		return {
			"throttle": float(raw.get("throttle", 0.0)),
			"brake": float(raw.get("brake", 0.0)),
			"steer": float(raw.get("steer", 0.0)),
			"fire_front": bool(raw.get("fire_front", false)),
			"fire_rear": bool(raw.get("fire_rear", false)),
			"drop_mine": bool(raw.get("drop_mine", false)),
			"boost": bool(raw.get("boost", false)),
			"drift": bool(raw.get("drift", false)),
		}
	return _ai(car, delta)


func _ai(car: CarState, _delta: float) -> Dictionary:
	var n := track.waypoints.size()
	if n == 0:
		return {"throttle": 1.0, "brake": 0.0, "steer": 0.0}
	var look := 4 + int(clampf(car.vel.length() / 180.0, 0.0, 3.0))
	if car.personality == "cautious":
		look += 2
	elif car.personality == "aggressive":
		look -= 1
	look = maxi(look, 2)
	var target: Vector2 = track.waypoints[(car.wp_index + look) % n]
	var forward := Vector2.from_angle(car.heading)
	var right := Vector2(-forward.y, forward.x)
	var ahead := _car_ahead(car)
	if ahead.has("dist") and float(ahead["dist"]) < 150.0:
		var side := -1.0 if float(ahead["lateral"]) > 0.0 else 1.0
		if car.personality == "cautious":
			side *= 0.6
		target += right * 36.0 * side
	var desired := target - car.pos
	var steer := clampf(Geom.ang_diff(desired.angle(), car.heading) * 2.5, -1.0, 1.0)
	if _blocked(car.pos, forward + right * 0.55, 52.0) and not _blocked(car.pos, forward - right * 0.55, 52.0):
		steer = -1.0
	elif _blocked(car.pos, forward - right * 0.55, 52.0) and not _blocked(car.pos, forward + right * 0.55, 52.0):
		steer = 1.0
	elif _blocked(car.pos, forward, 40.0):
		steer = -1.0 if _blocked(car.pos, right, 28.0) else 1.0
	var a: Vector2 = track.waypoints[(car.wp_index + 3) % n] - track.waypoints[car.wp_index]
	var b: Vector2 = track.waypoints[(car.wp_index + 9) % n] - track.waypoints[(car.wp_index + 3) % n]
	var turn := 0.0
	if a.length() > 2.0 and b.length() > 2.0:
		turn = absf(Geom.ang_diff(b.angle(), a.angle()))
	var corner := 0.48
	if car.personality == "aggressive":
		corner = 0.66
	elif car.personality == "cautious":
		corner = 0.36
	var speed_mul := lerpf(1.0, corner, clampf(turn / 1.2, 0.0, 1.0))
	var surf := track.surface_at(car.pos)
	if float(surf["grip"]) < 0.75:
		speed_mul *= 0.82
	if catchup:
		var leader := _leader_progress()
		var gap := leader - _progress(car)
		if gap > 2500.0:
			speed_mul *= 1.05
		elif gap < -1800.0:
			speed_mul *= 0.97
	var target_speed := car.max_speed * speed_mul * clampf(car.skill, 0.62, 1.1)
	var speed := car.vel.dot(forward)
	var throttle := 1.0
	var brake := 0.0
	if speed > target_speed:
		throttle = 0.1
		brake = clampf((speed - target_speed) / 160.0, 0.0, 1.0)
	if surf["id"] == "G" or surf["id"] == "W":
		var home: Vector2 = track.waypoints[car.wp_index] - car.pos
		steer = clampf(Geom.ang_diff(home.angle(), car.heading) * 3.0, -1.0, 1.0)
		throttle = 0.7
		brake = 0.0
	var boost := false
	var clear_ahead := not ahead.has("dist") or float(ahead.get("dist", 999.0)) > 170.0
	var boost_floor := 0.45
	if car.personality == "cautious":
		boost_floor = 0.82
	elif car.personality == "aggressive":
		boost_floor = 0.32
	if race_time > 4.0 and turn < 0.18 and clear_ahead and car.boost >= boost_floor and throttle > 0.85 and brake <= 0.05 and speed > 170.0 and float(surf["grip"]) >= 0.75:
		boost = true
	var fire_front := false
	var fire_rear := false
	var drop_mine := false
	var urge := 1.3
	if car.personality == "aggressive":
		urge = 2.1
	elif car.personality == "cautious":
		urge = 0.65
	if car.weapon_bias > 0.15 and _rng.randf() < car.weapon_bias * _delta * urge * Balance.num("ai_fire_rate", 0.45):
		if _enemy_in_cone(car, 0.84, 36.0, 280.0) != null and car.ammo_missile > 0 and car.cd_missile <= 0.0:
			fire_front = true
		var behind := _enemy_in_cone(car, -0.72, 24.0, 150.0)
		if behind != null and car.has_mines and car.ammo_mine > 0 and car.cd_mine <= 0.0:
			drop_mine = true
		if behind != null and car.has_rear and car.ammo_rear > 0 and car.cd_rear <= 0.0:
			fire_rear = true
	steer = clampf(steer + _rng.randf_range(-ai_wobble, ai_wobble), -1.0, 1.0)
	return {
		"throttle": throttle,
		"brake": brake,
		"steer": steer,
		"fire_front": fire_front,
		"fire_rear": fire_rear,
		"drop_mine": drop_mine,
		"boost": boost,
	}


func _in_slipstream(car: CarState) -> bool:
	if race_time < 2.2 or car.dnf or car.finished:
		return false
	var forward := Vector2.from_angle(car.heading)
	var right := Vector2(-forward.y, forward.x)
	var min_gap := Balance.num("slipstream.min_gap", 40.0)
	var max_gap := Balance.num("slipstream.max_gap", 148.0)
	var lane := Balance.num("slipstream.lane", 24.0)
	if car.vel.length() < 130.0:
		return false
	for other in cars:
		if other == car or other.dnf or other.finished:
			continue
		if other.vel.length() < 120.0:
			continue
		var rel: Vector2 = other.pos - car.pos
		var along := rel.dot(forward)
		if along < min_gap or along > max_gap:
			continue
		if absf(rel.dot(right)) > lane:
			continue
		if rel.normalized().dot(forward) < 0.82:
			continue
		return true
	return false


func _blocked(origin: Vector2, dir: Vector2, dist: float) -> bool:
	if dir.length() < 0.01:
		return false
	var step := dir.normalized()
	var count := int(dist / 16.0) + 1
	for i in range(1, count + 1):
		if track.blocking(origin + step * (dist * float(i) / float(count))):
			return true
	return false


func _car_ahead(car: CarState) -> Dictionary:
	var forward := Vector2.from_angle(car.heading)
	var right := Vector2(-forward.y, forward.x)
	var best = null
	var best_dist := 9999.0
	for other in cars:
		if other == car or other.dnf:
			continue
		var rel: Vector2 = other.pos - car.pos
		var along := rel.dot(forward)
		if along < 8.0 or along > 170.0:
			continue
		if absf(rel.dot(right)) > 36.0:
			continue
		if along < best_dist:
			best_dist = along
			best = {"dist": along, "lateral": rel.dot(right)}
	return best if best != null else {}


func _enemy_in_cone(car: CarState, dot_need: float, min_dist: float, max_dist: float) -> CarState:
	var forward := Vector2.from_angle(car.heading)
	if dot_need < 0.0:
		forward = -forward
		dot_need = absf(dot_need)
	for other in cars:
		if other == car or other.dnf or other.finished:
			continue
		var rel: Vector2 = other.pos - car.pos
		var dist := rel.length()
		if dist < min_dist or dist > max_dist:
			continue
		if rel.normalized().dot(forward) >= dot_need:
			return other
	return null


func _maybe_fire(car: CarState, input: Dictionary) -> void:
	if race_time < Balance.num("weapons_hold", 5.0):
		return
	if bool(input.get("fire_front", false)):
		_spawn_shot(car, Vector2.from_angle(car.heading), car.missile_damage, "missile")
	if bool(input.get("fire_rear", false)) and car.has_rear:
		_spawn_shot(car, -Vector2.from_angle(car.heading), car.rear_damage, "rear")
	if bool(input.get("drop_mine", false)) and car.has_mines:
		_drop_mine(car)


func _spawn_shot(car: CarState, dir: Vector2, damage: float, kind: String) -> void:
	if car.dnf:
		return
	var ammo_name := "ammo_missile" if kind == "missile" else "ammo_rear"
	var cd_name := "cd_missile" if kind == "missile" else "cd_rear"
	var ammo := int(car.get(ammo_name))
	if ammo <= 0 or float(car.get(cd_name)) > 0.0:
		return
	car.set(ammo_name, ammo - 1)
	var cd := Balance.num("weapons.%s.cooldown" % ("missile" if kind == "missile" else "rear"), 0.45)
	car.set(cd_name, cd)
	var speed := Balance.num("weapons.%s.speed" % ("missile" if kind == "missile" else "rear"), 720.0)
	shots.append({
		"id": _shot_serial,
		"pos": car.pos + dir * 22.0,
		"vel": dir * speed + car.vel * 0.2,
		"damage": damage,
		"owner": car.id,
		"life": Balance.num("weapons.%s.life" % ("missile" if kind == "missile" else "rear"), 1.2),
		"max": Balance.num("weapons.%s.life" % ("missile" if kind == "missile" else "rear"), 1.2),
		"kind": kind,
	})
	_shot_serial += 1
	events.append({"type": "shot", "pos": car.pos, "kind": kind})


func _drop_mine(car: CarState) -> void:
	if car.ammo_mine <= 0 or car.cd_mine > 0.0 or car.dnf:
		return
	car.ammo_mine -= 1
	car.cd_mine = 0.55
	var back := -Vector2.from_angle(car.heading)
	mines.append({
		"id": _shot_serial,
		"pos": car.pos + back * 20.0,
		"owner": car.id,
		"arm": Balance.num("weapons.mine.arm", 0.4),
		"life": Balance.num("weapons.mine.life", 16.0),
		"damage": car.mine_damage,
		"radius": Balance.num("weapons.mine.radius", 22.0),
	})
	_shot_serial += 1
	events.append({"type": "mine", "pos": car.pos})


func _update_shots(delta: float) -> void:
	var alive := []
	for shot in shots:
		shot["life"] = float(shot["life"]) - delta
		shot["pos"] = shot["pos"] + shot["vel"] * delta
		if float(shot["life"]) <= 0.0:
			events.append({"type": "explode", "pos": shot["pos"], "small": true})
			continue
		if track.blocking(shot["pos"]):
			events.append({"type": "explode", "pos": shot["pos"], "small": true})
			continue
		var hit := false
		for car in cars:
			if car.dnf:
				continue
			if str(shot["owner"]) == car.id and float(shot["life"]) > float(shot["max"]) - 0.12:
				continue
			if car.pos.distance_to(shot["pos"]) <= 18.0:
				_hurt(car, float(shot["damage"]))
				events.append({"type": "explode", "pos": shot["pos"], "small": false})
				hit = true
				break
		if not hit:
			alive.append(shot)
	shots = alive


func _update_mines(delta: float) -> void:
	var alive := []
	for mine in mines:
		mine["life"] = float(mine["life"]) - delta
		mine["arm"] = float(mine["arm"]) - delta
		if float(mine["life"]) <= 0.0:
			continue
		var boom := false
		if float(mine["arm"]) <= 0.0:
			for car in cars:
				if car.dnf:
					continue
				if str(mine["owner"]) == car.id and float(mine["life"]) > Balance.num("weapons.mine.life", 16.0) - 0.7:
					continue
				if car.pos.distance_to(mine["pos"]) <= float(mine["radius"]):
					_hurt(car, float(mine["damage"]))
					events.append({"type": "explode", "pos": mine["pos"], "small": false})
					boom = true
					break
		if not boom:
			alive.append(mine)
	mines = alive


func _update_pickups(delta: float) -> void:
	for pickup in pickups:
		if bool(pickup["taken"]):
			pickup["respawn"] = float(pickup["respawn"]) - delta
			if float(pickup["respawn"]) <= 0.0:
				pickup["taken"] = false
			continue
		var p := Vector2(float(pickup["x"]), float(pickup["y"]))
		for car in cars:
			if car.dnf or car.finished:
				continue
			if car.pos.distance_to(p) > 26.0:
				continue
			var kind := str(pickup["kind"])
			if kind == "repair":
				car.hp = minf(car.max_hp, car.hp + 28.0)
			elif kind == "mine":
				car.ammo_mine = mini(car.cap_mine, car.ammo_mine + 2)
				if car.ammo_mine > 0:
					car.has_mines = true
			elif kind == "boost":
				car.boost = minf(1.0, car.boost + 0.55)
			else:
				car.ammo_missile = mini(car.cap_missile, car.ammo_missile + 6)
			pickup["taken"] = true
			pickup["respawn"] = 12.0
			events.append({"type": "pickup", "pos": p, "kind": kind})
			break


func _hurt(car: CarState, amount: float) -> void:
	car.hp -= amount * car.damage_taken * Balance.num("weapon_damage_scale", 0.6)
	car.hit_cd = maxf(car.hit_cd, 0.15)
	if car.hp <= 0.0:
		_destroy(car)


func _destroy(car: CarState) -> void:
	if car.dnf:
		return
	car.dnf = true
	car.hp = 0.0
	car.vel *= 0.15
	events.append({"type": "destroyed", "pos": car.pos, "id": car.id})


func _seed_waypoint(car: CarState) -> void:
	var best := 0
	var best_d := INF
	for i in track.waypoints.size():
		var d := car.pos.distance_squared_to(track.waypoints[i])
		if d < best_d:
			best_d = d
			best = i
	car.wp_index = best


func _advance_wp(car: CarState) -> void:
	var n := track.waypoints.size()
	if n == 0:
		return
	var best := 0
	var best_d := INF
	for k in 12:
		var idx := (car.wp_index + k) % n
		var d := car.pos.distance_squared_to(track.waypoints[idx])
		if d < best_d:
			best_d = d
			best = k
	car.wp_index = (car.wp_index + best) % n
	car.wp_travel += best


func _cross_checkpoint(car: CarState) -> bool:
	if track.checkpoints.is_empty() or car.finished:
		return false
	var index := car.next_cp
	var cp: Dictionary = track.checkpoints[index]
	if not Geom.segments_intersect(car.prev_pos, car.pos, cp["a"], cp["b"]):
		return false
	var across: Vector2 = cp["b"] - cp["a"]
	var tangent := Vector2(across.y, -across.x)
	if (car.pos - car.prev_pos).dot(tangent) <= 0.0:
		return false
	car.cps_passed += 1
	car.next_cp = (index + 1) % track.checkpoints.size()
	if index == 0:
		car.laps += 1
		var lap_time := race_time - car.lap_start
		if lap_time > 1.0 and (car.best_lap <= 0.0 or lap_time < car.best_lap):
			car.best_lap = lap_time
		car.lap_start = race_time
		events.append({"type": "lap", "id": car.id, "laps": car.laps})
		if not knockout and car.laps >= track.laps:
			car.finished = true
			car.finish_time = race_time
			events.append({"type": "finish", "id": car.id, "time": race_time})
	return true


func _progress(car: CarState) -> float:
	if car.finished:
		return 100000000.0 - car.finish_time
	if car.dnf:
		if car.knocked_at > 0.0:
			return -1000.0 + car.knocked_at
		return -100000.0 + float(car.wp_travel) * 0.01
	var cp: Dictionary = track.checkpoints[car.next_cp]
	var mid: Vector2 = (cp["a"] + cp["b"]) * 0.5
	var frac := 1.0 - clampf(car.pos.distance_to(mid) / 3000.0, 0.0, 1.0)
	return float(car.laps) * 100000.0 + float(car.cps_passed) * 1000.0 + frac * 100.0


func _leader_progress() -> float:
	var best := -999999.0
	for car in cars:
		best = maxf(best, _progress(car))
	return best


func _assign_ranks() -> void:
	var order: Array = cars.duplicate()
	order.sort_custom(func(a, b): return _progress(a) > _progress(b))
	for i in order.size():
		order[i].rank = i + 1


func result() -> Dictionary:
	_assign_ranks()
	var standings := []
	for car in cars:
		standings.append({
			"id": car.id,
			"name": car.driver_name,
			"is_player": car.is_player,
			"player_index": car.player_index,
			"position": car.rank,
			"dnf": car.dnf,
			"knocked": car.knocked_at > 0.0,
			"finished": car.finished,
			"time": car.finish_time,
			"laps": car.laps,
			"best_lap": car.best_lap,
			"hp": car.hp,
			"body": car.body,
			"paint": car.paint,
		})
	standings.sort_custom(func(a, b): return int(a["position"]) < int(b["position"]))
	var player = null
	for car in cars:
		if car.is_player and car.player_index == 0:
			player = car
			break
	return {
		"track_id": track.id,
		"track_name": track.track_name,
		"laps_required": track.laps,
		"time": race_time,
		"standings": standings,
		"player": _car_blob(player),
	}


func _car_blob(car: CarState) -> Dictionary:
	if car == null:
		return {}
	return {
		"position": car.rank,
		"dnf": car.dnf,
		"knocked": car.knocked_at > 0.0,
		"finished": car.finished,
		"time": car.finish_time if car.finished else race_time,
		"best_lap": car.best_lap,
		"hp": car.hp,
		"max_hp": car.max_hp,
		"laps": car.laps,
		"ammo": {"missile": car.ammo_missile, "mine": car.ammo_mine, "rear": car.ammo_rear},
	}
