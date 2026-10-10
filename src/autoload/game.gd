extends Node

var career_path := "user://career.json"
var profile: Dictionary = {}
var last_entry := {"fee": 0, "note": ""}
var last_result: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Balance.load_data()
	TrackData.load_all()
	load_career()


func has_career() -> bool:
	return not profile.is_empty() and str(profile.get("driver", "")) != ""


func new_career(driver_name: String, difficulty: String, vehicle_id: String) -> void:
	var vehicle := Balance.vehicle(vehicle_id)
	var hp := float(vehicle.get("hp", 100))
	var keep_daily: Dictionary = profile.get("daily", {})
	var keep_streak: Dictionary = profile.get("daily_streak", {"date": "", "count": 0})
	profile = {
		"version": 1,
		"driver": driver_name.strip_edges() if driver_name.strip_edges() != "" else "Alex Rivera",
		"difficulty": difficulty,
		"money": int(Balance.num("starting_money", 2800)),
		"vehicle": vehicle_id,
		"owned": [vehicle_id],
		"hp": hp,
		"upgrades": {
			"engine": 0, "gearbox": 0, "brakes": 0, "tires": 0, "armor": 0,
			"hull": 0, "missiles": 1, "mines": 0, "rear": 0, "ammo_rack": 0, "pit": 0,
		},
		"ammo": {"missile": 18, "mine": 0, "rear": 0},
		"bailouts": int(Balance.num("bailouts", 3)),
		"scholarships": 0,
		"championships": {},
		"best_laps": {},
		"stats": {"races": 0, "wins": 0, "podiums": 0, "dnfs": 0},
		"notes": [],
		"daily": keep_daily,
		"daily_streak": keep_streak,
	}
	save_career()


func load_career() -> bool:
	if not FileAccess.file_exists(career_path):
		return false
	var file := FileAccess.open(career_path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	if int(parsed.get("version", 0)) != 1:
		return false
	profile = parsed
	return true


func save_career() -> void:
	if profile.is_empty():
		return
	var file := FileAccess.open(career_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save career")
		return
	file.store_string(JSON.stringify(profile, "\t"))


func money() -> int:
	return int(profile.get("money", 0))


func upgrades() -> Dictionary:
	return profile.get("upgrades", {})


func upgrade_level(id: String) -> int:
	return int(upgrades().get(id, 0))


func player_spec() -> Dictionary:
	var spec := spec_for(str(profile.get("vehicle", "sprint_dart")), upgrades(), float(profile.get("hp", 100.0)), profile.get("ammo", {}), true)
	var diff := Balance.dict_at("difficulties.%s" % str(profile.get("difficulty", "pro")))
	spec["damage_taken"] = float(spec["damage_taken"]) * float(diff.get("damage_taken", 1.0))
	return spec


func spec_for(vehicle_id: String, ups: Dictionary, hp_now: float, ammo: Dictionary, is_player: bool) -> Dictionary:
	Balance.load_data()
	var vehicle := Balance.vehicle(vehicle_id)
	var phys := Balance.dict_at("physics")
	var weapons := Balance.dict_at("weapons")
	var engine_l := int(ups.get("engine", 0))
	var gear_l := int(ups.get("gearbox", 0))
	var brake_l := int(ups.get("brakes", 0))
	var tire_l := int(ups.get("tires", 0))
	var armor_l := int(ups.get("armor", 0))
	var hull_l := int(ups.get("hull", 0))
	var missile_l := int(ups.get("missiles", 1))
	var mine_l := int(ups.get("mines", 0))
	var rear_l := int(ups.get("rear", 0))
	var rack_l := int(ups.get("ammo_rack", 0))
	var max_hp := float(vehicle.get("hp", 100)) + float(hull_l) * 12.0
	return {
		"id": "player" if is_player else vehicle_id,
		"name": str(profile.get("driver", "Driver")) if is_player else str(vehicle.get("name", "Driver")),
		"is_player": is_player,
		"player_index": 0,
		"body": str(vehicle.get("body", "dart")),
		"paint": str(vehicle.get("paint", "cyan")),
		"personality": "balanced",
		"skill": 1.0,
		"weapon_bias": 0.0,
		"hp": clampf(hp_now, 0.0, max_hp),
		"max_hp": max_hp,
		"accel": float(phys.get("accel", 540)) * float(vehicle.get("accel", 1.0)) * (1.0 + 0.08 * float(engine_l)),
		"brake": float(phys.get("brake", 820)) * float(vehicle.get("brake", 1.0)) * (1.0 + 0.1 * float(brake_l)),
		"max_speed": float(phys.get("max_speed", 470)) * float(vehicle.get("speed", 1.0)) * (1.0 + 0.045 * float(gear_l)),
		"grip": float(phys.get("grip", 8.2)) * float(vehicle.get("grip", 1.0)) * (1.0 + 0.07 * float(tire_l)),
		"turn_rate": float(phys.get("turn_rate", 3.05)) * float(vehicle.get("turn", 1.0)),
		"damage_taken": float(vehicle.get("armor", 1.0)) / (1.0 + 0.14 * float(armor_l)),
		"missile_damage": float(weapons.get("missile", {}).get("damage", 22)) * (1.0 + 0.18 * float(maxi(missile_l - 1, 0))),
		"rear_damage": float(weapons.get("rear", {}).get("damage", 18)) * (1.0 + 0.16 * float(maxi(rear_l - 1, 0))),
		"mine_damage": float(weapons.get("mine", {}).get("damage", 34)) * (1.0 + 0.16 * float(maxi(mine_l - 1, 0))),
		"has_rear": rear_l > 0,
		"has_mines": mine_l > 0,
		"ammo_missile": int(ammo.get("missile", 0)),
		"ammo_rear": int(ammo.get("rear", 0)),
		"ammo_mine": int(ammo.get("mine", 0)),
		"cap_missile": 24 + rack_l * 6,
		"cap_rear": 12 + rack_l * 4,
		"cap_mine": 8 + rack_l * 3,
	}


func ai_spec(driver: Dictionary, tier_id: String) -> Dictionary:
	var diff := Balance.dict_at("difficulties.%s" % str(profile.get("difficulty", "pro")))
	var tier_row := Balance.dict_at("tiers.%s" % tier_id)
	var skill := float(driver.get("skill", 0.8)) * float(diff.get("ai_skill", 1.0))
	var speed_mul := float(tier_row.get("ai_speed", 1.0))
	var ups := upgrades()
	var player_power := 1.0 + 0.025 * float(upgrade_level("engine") + upgrade_level("gearbox"))
	var base := spec_for("sprint_dart", {"missiles": 2, "mines": 1, "rear": 1 if tier_id != "club" else 0, "hull": 1 if tier_id == "turbo" else 0}, 100.0, {}, false)
	base["id"] = str(driver["id"])
	base["name"] = str(driver["name"])
	base["is_player"] = false
	base["body"] = str(driver.get("body", "dart"))
	base["paint"] = str(driver.get("paint", "white"))
	base["personality"] = str(driver.get("style", "balanced"))
	base["skill"] = skill
	base["weapon_bias"] = float(diff.get("ai_weapon", 0.6))
	base["max_speed"] = float(base["max_speed"]) * speed_mul * skill * player_power
	base["accel"] = float(base["accel"]) * speed_mul * lerpf(0.92, 1.05, clampf(skill, 0.7, 1.1))
	base["hp"] = float(base["max_hp"])
	base["ammo_missile"] = 14
	base["ammo_mine"] = 5
	base["ammo_rear"] = 16 if tier_id != "club" else 0
	base["has_mines"] = true
	base["has_rear"] = tier_id != "club"
	base["damage_taken"] = 1.0
	return base


func champ_state(champ_id: String) -> Dictionary:
	if not profile.has("championships") or typeof(profile["championships"]) != TYPE_DICTIONARY:
		profile["championships"] = {}
	if not profile["championships"].has(champ_id):
		profile["championships"][champ_id] = {
			"race_index": 0,
			"points": {},
			"completed": false,
			"field": [],
			"best_rank": 99,
		}
	return profile["championships"][champ_id]


func championship_unlocked(champ_id: String) -> bool:
	var spec := Balance.championship(champ_id)
	var need := str(spec.get("unlock", ""))
	if need == "":
		return true
	return bool(champ_state(need).get("completed", false))


func season_over(champ_id: String) -> bool:
	var spec := Balance.championship(champ_id)
	return int(champ_state(champ_id).get("race_index", 0)) >= spec.get("tracks", []).size()


func next_track_id(champ_id: String) -> String:
	var spec := Balance.championship(champ_id)
	var tracks: Array = spec.get("tracks", [])
	if tracks.is_empty():
		return ""
	var index := int(champ_state(champ_id).get("race_index", 0))
	if index >= tracks.size():
		index = tracks.size() - 1
	return str(tracks[index])


func ensure_field(champ_id: String) -> Array:
	var state := champ_state(champ_id)
	var field: Array = state.get("field", [])
	if field.is_empty():
		field = _pick_field(champ_id)
		state["field"] = field
		save_career()
	var out := []
	for driver_id in field:
		var driver := Balance.driver(str(driver_id))
		if not driver.is_empty():
			out.append(driver)
	return out


func _pick_field(champ_id: String) -> Array:
	var tier_level := 1
	if champ_id == "national":
		tier_level = 2
	elif champ_id == "turbo":
		tier_level = 3
	elif champ_id == "masters":
		tier_level = 4
	var primary := []
	var rest := []
	for driver in Balance.drivers:
		if int(driver.get("tier", 1)) == tier_level:
			primary.append(driver)
		else:
			rest.append(driver)
	primary.sort_custom(func(a, b): return float(a["skill"]) > float(b["skill"]))
	rest.sort_custom(func(a, b): return abs(int(a["tier"]) - tier_level) < abs(int(b["tier"]) - tier_level))
	var picked := []
	for driver in primary + rest:
		if picked.size() >= 5:
			break
		picked.append(str(driver["id"]))
	return picked


func standings(champ_id: String) -> Array:
	var points: Dictionary = champ_state(champ_id).get("points", {})
	var rows := []
	if not points.has("player"):
		points["player"] = points.get("player", 0)
	for key in points.keys():
		var driver_name := str(profile.get("driver", "You"))
		if str(key) != "player":
			var driver := Balance.driver(str(key))
			driver_name = str(driver.get("name", key))
		rows.append({"id": str(key), "name": driver_name, "points": int(points[key]), "player": str(key) == "player"})
	rows.sort_custom(func(a, b):
		if int(a["points"]) == int(b["points"]):
			return bool(a["player"]) and not bool(b["player"])
		return int(a["points"]) > int(b["points"])
	)
	for i in rows.size():
		rows[i]["rank"] = i + 1
	return rows


func player_rank(champ_id: String) -> int:
	for row in standings(champ_id):
		if bool(row["player"]):
			return int(row["rank"])
	return 99


func begin_entry(champ_id: String) -> Dictionary:
	_prepare_hull()
	var fee := Economy.entry_fee(champ_id)
	var note := ""
	if money() < fee:
		if int(profile.get("bailouts", 0)) > 0:
			profile["bailouts"] = int(profile["bailouts"]) - 1
			fee = 0
			note = "A local sponsor covered the entry fee."
		else:
			profile["scholarships"] = int(profile.get("scholarships", 0)) + 1
			profile["money"] = fee
			note = "The yard advanced a scholarship so the grid would not lose you."
	profile["money"] = money() - fee
	last_entry = {"fee": fee, "note": note}
	save_career()
	return last_entry


func _prepare_hull() -> void:
	var spec := player_spec()
	var hp := float(profile.get("hp", spec["max_hp"]))
	if hp > 0.0:
		return
	var cost := Economy.repair_cost(float(spec["max_hp"]) * 0.45, upgrade_level("pit"))
	if money() >= cost:
		profile["money"] = money() - cost
		profile["hp"] = float(spec["max_hp"]) * 0.45
	else:
		profile["hp"] = max(30.0, float(spec["max_hp"]) * 0.35)


func build_roster(champ_id: String, two_player: bool) -> Array:
	var field := ensure_field(champ_id)
	var roster: Array = []
	for driver in field:
		roster.append(ai_spec(driver, champ_id))
	roster.sort_custom(func(a, b): return float(a["skill"]) > float(b["skill"]))
	var player := player_spec()
	player["id"] = "player"
	player["player_index"] = 0
	var insert_at := mini(3, roster.size())
	roster.insert(insert_at, player)
	if two_player:
		if roster.size() > 5:
			roster.pop_back()
		var guest := player_spec()
		guest["id"] = "player2"
		guest["name"] = "Guest"
		guest["is_player"] = true
		guest["player_index"] = 1
		guest["paint"] = "yellow"
		guest["body"] = "dart"
		roster.append(guest)
	for i in roster.size():
		roster[i]["player_index"] = int(roster[i].get("player_index", 0))
	return roster


func build_net_roster(humans: Array, tier_id: String = "club") -> Array:
	var roster: Array = []
	var paints_used := {}
	for i in mini(humans.size(), 4):
		var h: Dictionary = humans[i]
		var spec := player_spec()
		spec["id"] = "net%d" % i
		spec["name"] = NetDefs.clean_player_name(str(h.get("name", "Driver")))
		spec["is_player"] = true
		spec["player_index"] = i
		spec["paint"] = NetDefs.clean_paint(str(h.get("paint", "cyan")))
		spec["body"] = "dart"
		paints_used[spec["paint"]] = true
		roster.append(spec)
	var field := ensure_field("club")
	var added := 0
	for driver in field:
		if roster.size() >= 6:
			break
		var ai := ai_spec(driver, tier_id)
		if paints_used.has(str(ai.get("paint", ""))):
			ai["paint"] = "white"
		roster.append(ai)
		added += 1
		if added >= 4:
			break
	while roster.size() < 4:
		var ai := ai_spec(Balance.drivers[roster.size() % Balance.drivers.size()], tier_id)
		roster.append(ai)
	return roster


func net_paint_for(index: int) -> String:
	var paints := ["cyan", "yellow", "red", "green"]
	return paints[posmod(index, paints.size())]


func daily_key(today := {}) -> String:
	var d := today if not today.is_empty() else Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.get("year", 2026)), int(d.get("month", 1)), int(d.get("day", 1))]


func daily_spec(key := "") -> Dictionary:
	var k := key if key != "" else daily_key()
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(k))
	var tracks := []
	for champ in Balance.championships:
		for track_id in champ.get("tracks", []):
			tracks.append(str(track_id))
	tracks.sort()
	if tracks.is_empty():
		tracks = ["harbor_loop"]
	var muts := ["night", "minestorm", "wreckfest", "monsoon"]
	return {"key": k, "track_id": tracks[rng.randi_range(0, tracks.size() - 1)], "mutator": muts[rng.randi_range(0, muts.size() - 1)]}


func daily_mutator_blurb(mutator: String) -> String:
	match mutator:
		"night":
			return "NIGHT: floodlights on, underglow humming. Same track, darker mood."
		"minestorm":
			return "MINESTORM: rivals carry extra mines and gratefully share them."
		"monsoon":
			return "MONSOON: pouring rain, mirror-wet asphalt, and a fifth less grip. Brake early."
		_:
			return "WRECKFEST: every rival is aggressive and fully loaded. Good luck."


func daily_best(key := "") -> Dictionary:
	var k := key if key != "" else daily_key()
	return profile.get("daily", {}).get(k, {})


func daily_streak() -> Dictionary:
	return profile.get("daily_streak", {"date": "", "count": 0})


func top_tier() -> String:
	for champ_id in ["masters", "turbo", "national", "club"]:
		if championship_unlocked(champ_id):
			return champ_id
	return "club"


func champ_of_track(track_id: String) -> String:
	for champ in Balance.championships:
		if track_id in champ.get("tracks", []):
			return str(champ["id"])
	return "club"


func apply_daily_mutator(roster: Array, mutator: String) -> Array:
	for spec in roster:
		if bool(spec.get("is_player", false)):
			if mutator == "minestorm":
				spec["ammo_mine"] = int(spec.get("ammo_mine", 0)) + 4
				spec["has_mines"] = true
			continue
		if mutator == "minestorm":
			spec["ammo_mine"] = 24
			spec["has_mines"] = true
		elif mutator == "wreckfest":
			spec["personality"] = "aggressive"
			spec["weapon_bias"] = 1.0
			spec["ammo_missile"] = 28
			spec["ammo_mine"] = 20
			spec["ammo_rear"] = 16
			spec["has_mines"] = true
			spec["has_rear"] = true
	return roster


func save_daily_result(key: String, race_result: Dictionary, ghost: Array) -> Dictionary:
	var player: Dictionary = race_result.get("player", {})
	var out := {"new_best": false, "beat_ghost": false, "streak": 0, "time": 0.0}
	if typeof(profile.get("daily")) != TYPE_DICTIONARY:
		profile["daily"] = {}
	if typeof(profile.get("daily_streak")) != TYPE_DICTIONARY:
		profile["daily_streak"] = {"date": "", "count": 0}
	if not bool(player.get("finished", false)) or bool(player.get("dnf", false)):
		return out
	var time := float(player.get("time", 0.0))
	out["time"] = time
	var prev: Dictionary = profile["daily"].get(key, {})
	var had_prev := not prev.is_empty()
	if not had_prev or time < float(prev.get("time", 1e9)):
		out["new_best"] = true
		out["beat_ghost"] = had_prev
		profile["daily"][key] = {"time": time, "ghost": ghost}
	var streak: Dictionary = profile["daily_streak"]
	var parts := key.split("-")
	var yesterday := key
	if parts.size() == 3:
		var noon := {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 12, "minute": 0, "second": 0}
		var back := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict(noon) - 86400.0)
		yesterday = "%04d-%02d-%02d" % [int(back.get("year", 2026)), int(back.get("month", 1)), int(back.get("day", 1))]
	if str(streak.get("date", "")) == yesterday:
		streak["count"] = int(streak.get("count", 0)) + 1
	elif str(streak.get("date", "")) != key:
		streak["count"] = 1
	streak["date"] = key
	out["streak"] = int(streak["count"])
	save_career()
	return out


func rival_id(champ_id: String) -> String:
	var field := ensure_field(champ_id)
	if field.is_empty():
		return ""
	var ids := field.map(func(d): return str(d["id"]))
	if int(champ_state(champ_id).get("race_index", 0)) == 0:
		return str(ids[0])
	var rows := standings(champ_id).filter(func(r): return bool(r["player"]) or ids.has(str(r["id"])))
	for i in rows.size():
		if bool(rows[i]["player"]):
			if i > 0:
				return str(rows[i - 1]["id"])
			if rows.size() > 1:
				return str(rows[1]["id"])
	return str(ids[0])


func rival_name(champ_id: String) -> String:
	return str(Balance.driver(rival_id(champ_id)).get("name", ""))


func rival_bounty(champ_id: String) -> int:
	var win := Economy.payout(1, champ_id, str(profile.get("difficulty", "pro")))
	return int(round(float(win) * Balance.num("rival.bounty", 0.4) / 10.0)) * 10


func _rival_outcome(champ_id: String, race_result: Dictionary) -> Dictionary:
	var rid := rival_id(champ_id)
	var out := {"id": rid, "name": str(Balance.driver(rid).get("name", "")), "beaten": false, "bounty": 0}
	if rid == "":
		return out
	var player: Dictionary = race_result.get("player", {})
	if bool(player.get("dnf", false)):
		return out
	for row in race_result.get("standings", []):
		if str(row.get("id", "")) == rid:
			if bool(row.get("dnf", false)) or int(player.get("position", 99)) < int(row.get("position", 0)):
				out["beaten"] = true
				out["bounty"] = rival_bounty(champ_id)
	return out


func apply_result(champ_id: String, race_result: Dictionary, fee_paid: int) -> Dictionary:
	var rival := _rival_outcome(champ_id, race_result)
	var player: Dictionary = race_result.get("player", {})
	var dnf := bool(player.get("dnf", false))
	var position := int(player.get("position", 6))
	var diff := str(profile.get("difficulty", "pro"))
	var pay := Economy.settlement(position, champ_id, diff, fee_paid, dnf)
	profile["money"] = money() + int(pay["prize"])
	profile["hp"] = float(player.get("hp", profile.get("hp", 100)))
	var ammo: Dictionary = player.get("ammo", profile.get("ammo", {}))
	profile["ammo"] = {
		"missile": int(ammo.get("missile", 0)),
		"mine": int(ammo.get("mine", 0)),
		"rear": int(ammo.get("rear", 0)),
	}
	var state := champ_state(champ_id)
	if typeof(state.get("points")) != TYPE_DICTIONARY:
		state["points"] = {}
	for row in race_result.get("standings", []):
		var key := "player" if bool(row.get("is_player", false)) and int(row.get("player_index", 0)) == 0 else str(row.get("id", ""))
		if key == "" or key == "player2":
			continue
		var gained := 0 if bool(row.get("dnf", false)) else Economy.points_for(int(row.get("position", 9)))
		state["points"][key] = int(state["points"].get(key, 0)) + gained
	state["race_index"] = int(state.get("race_index", 0)) + 1
	var stats: Dictionary = profile.get("stats", {})
	stats["races"] = int(stats.get("races", 0)) + 1
	if not dnf and position == 1:
		stats["wins"] = int(stats.get("wins", 0)) + 1
	if not dnf and position <= 3:
		stats["podiums"] = int(stats.get("podiums", 0)) + 1
	if dnf:
		stats["dnfs"] = int(stats.get("dnfs", 0)) + 1
	if bool(rival["beaten"]):
		stats["rivals_beaten"] = int(stats.get("rivals_beaten", 0)) + 1
		profile["money"] = money() + int(rival["bounty"])
	profile["stats"] = stats
	var track_id := str(race_result.get("track_id", ""))
	var best := float(player.get("best_lap", 0.0))
	if best > 0.0:
		var laps: Dictionary = profile.get("best_laps", {})
		var prev := float(laps.get(track_id, 0.0))
		if prev <= 0.0 or best < prev:
			laps[track_id] = best
		profile["best_laps"] = laps
	var rank := player_rank(champ_id)
	state["best_rank"] = mini(int(state.get("best_rank", 99)), rank)
	var finished_season := season_over(champ_id)
	if finished_season and rank <= int(Balance.num("advance_rank", 3)):
		state["completed"] = true
	last_result = {
		"pay": pay,
		"position": position,
		"dnf": dnf,
		"rank": rank,
		"season_over": finished_season,
		"advanced": finished_season and bool(state.get("completed", false)),
		"note": str(last_entry.get("note", "")),
		"rival": rival,
	}
	save_career()
	return last_result


func restart_season(champ_id: String) -> void:
	var state := champ_state(champ_id)
	var done := bool(state.get("completed", false))
	state["race_index"] = 0
	state["points"] = {}
	state["field"] = []
	state["completed"] = done
	save_career()


func buy_upgrade(upgrade_id: String) -> bool:
	var spec: Dictionary = Balance.dict_at("upgrades.%s" % upgrade_id)
	if spec.is_empty():
		return false
	var level := upgrade_level(upgrade_id)
	if level >= int(spec.get("max", 5)):
		return false
	var cost := Economy.upgrade_cost(upgrade_id, level)
	if money() < cost:
		return false
	profile["money"] = money() - cost
	profile["upgrades"][upgrade_id] = level + 1
	if upgrade_id == "hull":
		profile["hp"] = float(profile.get("hp", 100)) + 12.0
	if upgrade_id == "mines" and level == 0:
		profile["ammo"]["mine"] = int(profile["ammo"].get("mine", 0)) + 4
	if upgrade_id == "rear" and level == 0:
		profile["ammo"]["rear"] = int(profile["ammo"].get("rear", 0)) + 8
	if upgrade_id == "missiles":
		profile["ammo"]["missile"] = mini(player_spec()["cap_missile"], int(profile["ammo"].get("missile", 0)) + 4)
	save_career()
	return true


func buy_vehicle(vehicle_id: String) -> bool:
	var vehicle := Balance.vehicle(vehicle_id)
	if vehicle.is_empty():
		return false
	var owned: Array = profile.get("owned", [])
	if vehicle_id in owned:
		profile["vehicle"] = vehicle_id
		save_career()
		return true
	var need := str(vehicle.get("unlock", ""))
	if need != "" and not bool(champ_state(need).get("completed", false)):
		return false
	var price := int(vehicle.get("price", 0))
	if money() < price:
		return false
	profile["money"] = money() - price
	owned.append(vehicle_id)
	profile["owned"] = owned
	profile["vehicle"] = vehicle_id
	profile["hp"] = float(vehicle.get("hp", 100)) + float(upgrade_level("hull")) * 12.0
	save_career()
	return true


func select_vehicle(vehicle_id: String) -> bool:
	if vehicle_id not in profile.get("owned", []):
		return false
	profile["vehicle"] = vehicle_id
	save_career()
	return true


func repair_full() -> bool:
	var spec := player_spec()
	var missing := float(spec["max_hp"]) - float(profile.get("hp", 0))
	if missing <= 0.5:
		profile["hp"] = float(spec["max_hp"])
		return true
	var cost := Economy.repair_cost(missing, upgrade_level("pit"))
	if money() < cost:
		return false
	profile["money"] = money() - cost
	profile["hp"] = float(spec["max_hp"])
	save_career()
	return true


func buy_ammo(kind: String) -> bool:
	var pack := int(Balance.num("ammo_price.%s_pack" % kind, 0))
	var price := int(Balance.num("ammo_price.%s" % kind, 9999))
	if pack <= 0 or money() < price:
		return false
	var spec := player_spec()
	var cap := int(spec.get("cap_%s" % kind, 0))
	var have := int(profile["ammo"].get(kind, 0))
	if have >= cap:
		return false
	if kind == "mine" and upgrade_level("mines") <= 0:
		return false
	if kind == "rear" and upgrade_level("rear") <= 0:
		return false
	profile["money"] = money() - price
	profile["ammo"][kind] = mini(cap, have + pack)
	save_career()
	return true


func exhibition_tracks() -> Array:
	var out := []
	for champ in Balance.championships:
		for track_id in champ.get("tracks", []):
			var track := TrackData.get_track(str(track_id))
			if track != null:
				out.append(track)
	return out
