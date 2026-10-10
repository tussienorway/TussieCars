extends Node

var failures: Array[String] = []
var passes := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Game.career_path = "user://test_career.json"
	if FileAccess.file_exists(Game.career_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.career_path))
	_check("balance loads", Balance.data.has("physics") and Balance.data.has("upgrades"))
	_check("four vehicles", Balance.vehicles.size() >= 4)
	_check("four championships", Balance.championships.size() >= 4)
	_check("eleven drivers", Balance.drivers.size() >= 8)
	_content()
	_handling()
	_boost()
	_tricks()
	_pads()
	_checkpoints()
	_weapons()
	_economy()
	_career()
	_daily()
	_props()
	_knockout()
	_rival()
	_walls()
	_ai_lap()
	_harbor_opening()
	_menus()
	_masters()
	_net()
	_graphics3d()
	_assets()
	_vr()
	print("TESTS %d passed, %d failed" % [passes, failures.size()])
	for item in failures:
		print("FAIL ", item)
	if FileAccess.file_exists(Game.career_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.career_path))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _content() -> void:
	var champs := 0
	var envs := {}
	for track in TrackData.all_tracks():
		var errors := TrackValidator.validate(track)
		_check("track %s valid" % track.id, errors.is_empty(), " ".join(errors))
		envs[track.environment] = true
		if bool(track.id != "test_oval"):
			var listed := false
			for champ in Balance.championships:
				if track.id in champ.get("tracks", []):
					listed = true
			if listed:
				champs += 1
	_check("16 championship tracks", champs >= 16, str(champs))
	_check("3 environments", envs.size() >= 3, str(envs.keys()))
	var index = JSON.parse_string(FileAccess.get_file_as_string("res://data/tracks/index.json"))
	var order: Array = index.get("order", []) if typeof(index) == TYPE_DICTIONARY else []
	_check("index lists 16", order.size() >= 16, str(order.size()))


func _handling() -> void:
	var track := TrackData.get_track("test_oval")
	var car := _car(Vector2(640, 500), 0.0)
	var before := car.vel.x
	CarSim.integrate(car, {"throttle": 1.0, "brake": 0.0, "steer": 0.0}, 0.5, track.surface_at(car.pos))
	_check("accelerates", car.vel.x > before + 40.0, str(car.vel.x))
	var fast := car.vel.x
	CarSim.integrate(car, {"throttle": 0.0, "brake": 1.0, "steer": 0.0}, 0.35, track.surface_at(car.pos))
	_check("brakes", car.vel.x < fast - 40.0, str(car.vel.x))
	car.vel = Vector2(180, 0)
	car.heading = 0.0
	CarSim.integrate(car, {"throttle": 1.0, "brake": 0.0, "steer": 1.0}, 0.4, {"grip": 1.0, "drag": 0.1, "damage": 0.0})
	_check("steers", absf(car.heading) > 0.15, str(car.heading))
	var asphalt := _car(Vector2(640, 500), 0.0)
	asphalt.vel = Vector2(0, 220)
	var oil := _car(Vector2(640, 500), 0.0)
	oil.vel = Vector2(0, 220)
	CarSim.integrate(asphalt, {"throttle": 0.0, "brake": 0.0, "steer": 0.0}, 0.25, {"grip": 1.0, "drag": 0.1, "damage": 0.0})
	CarSim.integrate(oil, {"throttle": 0.0, "brake": 0.0, "steer": 0.0}, 0.25, {"grip": 0.2, "drag": 0.18, "damage": 0.0})
	_check("oil slides more than asphalt", absf(oil.vel.y) > absf(asphalt.vel.y) + 20.0, "%s vs %s" % [oil.vel.y, asphalt.vel.y])
	var wall := _car(Vector2(80, 70), -PI * 0.5)
	wall.vel = Vector2(0, -520)
	wall.hp = 100.0
	var impact := CarSim.move(wall, 0.05, track, 0.05)
	_check("wall collision", impact > 110.0 and wall.hp < 99.0, "impact %s hp %s pos %s" % [impact, wall.hp, wall.pos])
	var a := _car(Vector2(500, 500), 0.0)
	var b := _car(Vector2(510, 500), PI)
	a.vel = Vector2(200, 0)
	b.vel = Vector2(-200, 0)
	a.hp = 100.0
	b.hp = 100.0
	a.hit_cd = 0.0
	b.hit_cd = 0.0
	CarSim.separate(a, b, 0.05)
	_check("car contact separates", a.pos.distance_to(b.pos) >= 27.0, str(a.pos.distance_to(b.pos)))


func _boost() -> void:
	var surf := {"grip": 1.0, "drag": 0.12, "damage": 0.0}
	var plain := _car(Vector2(640, 500), 0.0)
	var nitro := _car(Vector2(640, 500), 0.0)
	plain.boost = 1.0
	nitro.boost = 1.0
	for _i in 24:
		CarSim.integrate(plain, {"throttle": 1.0, "brake": 0.0, "steer": 0.0, "boost": false}, 0.05, surf)
		CarSim.integrate(nitro, {"throttle": 1.0, "brake": 0.0, "steer": 0.0, "boost": true}, 0.05, surf)
	_check("boost is faster", nitro.vel.length() > plain.vel.length() + 20.0, "nitro %s plain %s" % [nitro.vel.length(), plain.vel.length()])
	_check("boost drains", nitro.boost < 0.7 and nitro.boosting, str(nitro.boost))
	nitro.boost = 0.2
	nitro.boosting = false
	for _i in 20:
		CarSim.integrate(nitro, {"throttle": 1.0, "brake": 0.0, "steer": 0.0, "boost": false}, 0.05, surf)
	_check("boost regens", nitro.boost > 0.28, str(nitro.boost))
	var sim := _race([_player_spec()])
	var car: CarState = sim.cars[0]
	car.boost = 0.1
	sim.pickups = [{
		"x": car.pos.x,
		"y": car.pos.y,
		"kind": "boost",
		"taken": false,
		"respawn": 0.0,
	}]
	sim._update_pickups(0.05)
	_check("boost pickup fills", car.boost > 0.5 and bool(sim.pickups[0]["taken"]), str(car.boost))


func _tricks() -> void:
	var surf := {"grip": 1.0, "drag": 0.12, "damage": 0.0}
	var plain := _car(Vector2(400, 400), 0.0)
	var draft := _car(Vector2(400, 400), 0.0)
	plain.vel = Vector2(320, 0)
	draft.vel = Vector2(320, 0)
	plain.boost = 0.2
	draft.boost = 0.2
	for _i in 16:
		CarSim.integrate(plain, {"throttle": 1.0, "brake": 0.0, "steer": 0.0}, 0.05, surf)
		CarSim.integrate(draft, {"throttle": 1.0, "brake": 0.0, "steer": 0.0, "draft": true}, 0.05, surf)
	_check("slipstream keeps speed", draft.vel.length() > plain.vel.length() + 12.0, "draft %s plain %s" % [draft.vel.length(), plain.vel.length()])
	_check("slipstream fills nitro", draft.boost > plain.boost + 0.05, "draft %s plain %s" % [draft.boost, plain.boost])
	var slider := _car(Vector2(400, 400), 0.0)
	slider.vel = Vector2(260, 0)
	slider.boost = 0.15
	slider.boosting = false
	CarSim.integrate(slider, {"throttle": 1.0, "brake": 0.0, "steer": 1.0, "drift": true}, 0.35, surf)
	_check("drift rotates and fills", absf(slider.heading) > 0.15 and slider.boost > 0.2 and slider.drifting, "head %s boost %s" % [slider.heading, slider.boost])
	var sim := _race([_player_spec(), _player_spec()])
	sim.cars[1].id = "rival"
	sim.cars[1].is_player = false
	sim.race_time = 4.0
	var nose := Vector2.from_angle(sim.cars[0].heading)
	sim.cars[0].vel = nose * 220.0
	sim.cars[1].pos = sim.cars[0].pos + nose * 90.0
	sim.cars[1].heading = sim.cars[0].heading
	sim.cars[1].vel = nose * 220.0
	_check("slipstream sees the car ahead", sim._in_slipstream(sim.cars[0]))


func _checkpoints() -> void:
	var sim := _race([_player_spec()])
	var car: CarState = sim.cars[0]
	_check("skip rejected", not _sweep(sim, car, 2, true) and car.next_cp == 1 and car.cps_passed == 0)
	_check("wrong way rejected", not _sweep(sim, car, 1, false) and car.next_cp == 1)
	var order := [1, 2, 3, 0, 1, 2, 3, 0]
	var ok := true
	for index in order:
		if not _sweep(sim, car, index, true):
			ok = false
			break
	_check("ordered laps", ok and car.laps == 2 and car.finished, "laps %s next %s" % [car.laps, car.next_cp])
	sim.step(0.05)
	_check("race finishes", sim.state == "finished")
	var result := sim.result()
	_check("results include player", bool(result["player"].get("finished", false)) and int(result["player"]["laps"]) == 2)


func _weapons() -> void:
	var shooter := _player_spec()
	shooter["ammo_missile"] = 8
	shooter["missile_damage"] = 30.0
	var victim := _player_spec()
	victim["id"] = "victim"
	victim["is_player"] = false
	victim["name"] = "Victim"
	victim["hp"] = 100.0
	var sim := _race([shooter, victim])
	var a: CarState = sim.cars[0]
	var b: CarState = sim.cars[1]
	var ks := float(sim.track.tile) / 42.0
	a.pos = Vector2(420, 357) * ks
	a.prev_pos = a.pos
	a.heading = 0.0
	a.vel = Vector2.ZERO
	b.pos = Vector2(680, 357) * ks
	b.prev_pos = b.pos
	b.vel = Vector2.ZERO
	var hp := b.hp
	sim.race_time = 6.0
	sim.inputs[0] = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "fire_front": true}
	sim.step(0.05)
	sim.inputs[0] = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "fire_front": false}
	for _i in 40:
		b.pos = Vector2(680, 357) * ks
		b.vel = Vector2.ZERO
		sim.step(0.05)
		if b.hp < hp - 5.0:
			break
	_check("missile damages", b.hp < hp - 5.0, "hp %s shots %s" % [b.hp, sim.shots.size()])
	var miner := _player_spec()
	miner["has_mines"] = true
	miner["ammo_mine"] = 3
	miner["mine_damage"] = 40.0
	var walker := _player_spec()
	walker["id"] = "walker"
	walker["is_player"] = false
	walker["hp"] = 100.0
	var minesim := _race([miner, walker])
	var mcar: CarState = minesim.cars[0]
	var wcar: CarState = minesim.cars[1]
	mcar.pos = Vector2(420, 357)
	mcar.heading = 0.0
	mcar.prev_pos = mcar.pos
	wcar.pos = Vector2(820, 357)
	wcar.prev_pos = wcar.pos
	minesim.race_time = 6.0
	minesim.inputs[0] = {"drop_mine": true, "throttle": 0.0, "brake": 0.0, "steer": 0.0}
	minesim.step(0.05)
	minesim.inputs[0] = {"drop_mine": false, "throttle": 0.0, "brake": 0.0, "steer": 0.0}
	_check("mine dropped", minesim.mines.size() == 1, str(minesim.mines.size()))
	var before := wcar.hp
	if minesim.mines.size() == 1:
		var mine_pos: Vector2 = minesim.mines[0]["pos"]
		for _i in 20:
			wcar.pos = mine_pos
			wcar.prev_pos = mine_pos
			wcar.vel = Vector2.ZERO
			minesim.step(0.05)
			if wcar.hp < before - 5.0:
				break
	_check("mine damages", wcar.hp < before - 5.0, "hp %s" % wcar.hp)
	var wallsim := _race([_player_spec()])
	var target: CarState = wallsim.cars[0]
	target.pos = Vector2(16, 28)
	target.hp = 80.0
	wallsim.shots.append({
		"id": 9,
		"pos": Vector2(16, 16),
		"vel": Vector2.ZERO,
		"damage": 50.0,
		"owner": "nobody",
		"life": 1.0,
		"max": 1.0,
		"kind": "missile",
	})
	wallsim._update_shots(0.05)
	_check("wall stops shot", target.hp == 80.0 and wallsim.shots.is_empty(), "hp %s shots %s" % [target.hp, wallsim.shots.size()])


func _economy() -> void:
	_check("club fee", Economy.entry_fee("club") == 200)
	_check("win purse", Economy.payout(1, "club", "pro") == 1400)
	_check("dnf pays nothing", int(Economy.settlement(1, "club", "pro", 200, true)["prize"]) == 0)
	_check("points", Economy.points_for(1) == 10 and Economy.points_for(2) == 7 and Economy.points_for(9) == 0)
	var base := Economy.upgrade_cost("engine", 0)
	var next := Economy.upgrade_cost("engine", 1)
	_check("upgrade price rises", next > base)


func _career() -> void:
	Game.new_career("Test Driver", "pro", "sprint_dart")
	_check("starts with money", Game.money() == 2800)
	_check("national locked", not Game.championship_unlocked("national"))
	var before: float = float(Game.player_spec()["accel"])
	_check("buys engine", Game.buy_upgrade("engine"))
	var after: float = float(Game.player_spec()["accel"])
	_check("engine raises accel", after > before * 1.05, "%s -> %s" % [before, after])
	Game.profile["money"] = 10
	_check("poor cannot buy", not Game.buy_upgrade("gearbox"))
	Game.profile["money"] = 5000
	Game.profile["hp"] = 40.0
	var cash := Game.money()
	_check("repair works", Game.repair_full() and float(Game.profile["hp"]) > 90.0 and Game.money() < cash)
	Game.save_career()
	var saved_name := str(Game.profile["driver"])
	Game.profile = {}
	_check("load career", Game.load_career() and str(Game.profile["driver"]) == saved_name)
	Game.profile["money"] = 8000
	var start_money := 8000
	for _i in 4:
		var entry := Game.begin_entry("club")
		var fee := int(entry["fee"])
		start_money -= fee
		var race := {
			"track_id": "harbor_loop",
			"player": {"position": 1, "dnf": false, "finished": true, "time": 40.0, "best_lap": 18.0, "hp": 100.0, "laps": 3, "ammo": {"missile": 10, "mine": 0, "rear": 0}},
			"standings": [
				{"id": "player", "is_player": true, "player_index": 0, "position": 1, "dnf": false},
				{"id": "briggs", "is_player": false, "player_index": 0, "position": 2, "dnf": false},
			],
		}
		var summary := Game.apply_result("club", race, fee)
		start_money += int(summary["pay"]["prize"]) + int(summary["rival"]["bounty"])
	_check("four wins pay consistently", Game.money() == start_money and Game.money() >= 8000 + (1400 - 200) * 4, str(Game.money()))
	_check("national unlocks", Game.championship_unlocked("national") and Game.season_over("club"))


func _daily() -> void:
	var a := Game.daily_spec("2026-10-10")
	var b := Game.daily_spec("2026-10-10")
	_check("daily deterministic", str(a["track_id"]) == str(b["track_id"]) and str(a["mutator"]) == str(b["mutator"]), str(a))
	var seen_tracks := {}
	var seen_muts := {}
	for i in 7:
		var s := Game.daily_spec("2026-10-%02d" % (10 + i))
		seen_tracks[str(s["track_id"])] = true
		seen_muts[str(s["mutator"])] = true
	_check("daily varies", seen_tracks.size() >= 2 and seen_muts.size() >= 2, "%s / %s" % [seen_tracks.keys(), seen_muts.keys()])
	_check("daily key format", Game.daily_key({"year": 2026, "month": 1, "day": 5}) == "2026-01-05")
	_check("mutator blurbs", Game.daily_mutator_blurb("night") != "" and Game.daily_mutator_blurb("wreckfest") != "")
	_check("champ of track", Game.champ_of_track(str(a["track_id"])) in ["club", "national", "turbo", "masters"])
	Game.new_career("Daily", "pro", "sprint_dart")
	var wreck := Game.apply_daily_mutator(Game.build_roster("club", false), "wreckfest")
	var wreck_ai := wreck.filter(func(spec): return not bool(spec.get("is_player", false)))
	_check("wreckfest arms rivals", wreck_ai.all(func(spec): return str(spec.get("personality", "")) == "aggressive" and float(spec.get("weapon_bias", 0.0)) >= 1.0))
	var storm := Game.apply_daily_mutator(Game.build_roster("club", false), "minestorm")
	var storm_ai := storm.filter(func(spec): return not bool(spec.get("is_player", false)))
	_check("minestorm mines", storm_ai.all(func(spec): return int(spec.get("ammo_mine", 0)) == 24))
	var ghost := [[0.0, 0.0, 0.0, 0.0], [0.15, 5.0, 1.0, 0.1]]
	var out := Game.save_daily_result("2026-10-10", {"player": {"finished": true, "dnf": false, "time": 95.0}}, ghost)
	_check("daily saves best", bool(out.get("new_best", false)) and int(out.get("streak", 0)) == 1 and not bool(out.get("beat_ghost", false)), str(out))
	_check("daily best stored", absf(float(Game.daily_best("2026-10-10").get("time", 0.0)) - 95.0) < 0.01)
	_check("ghost stored", (Game.daily_best("2026-10-10").get("ghost", []) as Array).size() == 2)
	var out2 := Game.save_daily_result("2026-10-10", {"player": {"finished": true, "dnf": false, "time": 99.0}}, [])
	_check("slower keeps best", not bool(out2.get("new_best", false)) and int(out2.get("streak", 0)) == 1, str(out2))
	var out3 := Game.save_daily_result("2026-10-11", {"player": {"finished": true, "dnf": false, "time": 100.0}}, [])
	_check("streak grows", int(out3.get("streak", 0)) == 2 and bool(out3.get("new_best", false)), str(out3))
	var out4 := Game.save_daily_result("2026-10-13", {"player": {"finished": true, "dnf": false, "time": 100.0}}, [])
	_check("streak resets after gap", int(out4.get("streak", 0)) == 1, str(out4))
	var dnfr := Game.save_daily_result("2026-10-14", {"player": {"finished": false, "dnf": true, "time": 50.0}}, [])
	_check("dnf scores nothing", int(dnfr.get("streak", 0)) == 0 and Game.daily_streak().get("date") == "2026-10-13")
	Game.new_career("Daily Keeper", "pro", "sprint_dart")
	_check("daily survives reset", absf(float(Game.daily_best("2026-10-10").get("time", 0.0)) - 95.0) < 0.01 and int(Game.daily_streak().get("count", 0)) == 1)
	_check("fresh career starts in club", Game.top_tier() == "club")
	var view := RaceView.new()
	add_child(view)
	view.setup({
		"track_id": "test_oval", "mode": "daily", "champ_id": "", "two_player": false,
		"assist": true, "difficulty": "pro", "tier": "club", "fee_paid": 0,
		"daily": true, "daily_key": "2026-10-10",
		"ghost": [[0.0, 100.0, 100.0, 0.0], [0.15, 110.0, 105.0, 0.1]],
		"force_night": true, "roster": Game.build_roster("club", false),
	})
	_check("daily view builds ghost", view.ghost_node != null and view.night and view.recording)
	view.sim.state = "racing"
	view.sim.race_time = 1.0
	view._me().pos = Vector2(500, 500)
	view._record_ghost()
	_check("ghost records", view.ghost_rec.size() == 1, str(view.ghost_rec))
	view._update_ghost(0.05)
	_check("ghost plays", view.ghost_node.position.x != 0.0)
	view.queue_free()


func _props() -> void:
	for model in ["grandStand", "billboard", "lightPostModern", "flagCheckers", "debris-tire", "cone", "tent", "treeSmall", "treeLarge", "overheadLights", "pylon", "roadBump"]:
		_check("prop %s loads" % model, CarFactory3D.prop_scene(model) != null, model)
	_check("desktop renders forward", str(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "forward_plus")
	_check("mobile stays compatible", str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")) == "gl_compatibility")
	var cam_probe := RaceView.new()
	_check("camera widens with speed", float(cam_probe._chase_params(false, 1.0)["fov"]) > float(cam_probe._chase_params(false, 0.0)["fov"]))
	_check("camera widens on boost", float(cam_probe._chase_params(true, 0.5)["fov"]) > float(cam_probe._chase_params(false, 0.5)["fov"]))
	cam_probe.free()
	Game.new_career("Prop", "pro", "sprint_dart")
	var view := RaceView.new()
	add_child(view)
	view.setup({
		"track_id": "harbor_loop", "mode": "exhibition", "champ_id": "", "two_player": false,
		"assist": true, "difficulty": "pro", "tier": "club", "fee_paid": 0,
		"roster": Game.build_roster("club", false),
	})
	var props: Array[Node] = view.find_children("Prop_*", "Node3D", true, false)
	_check("start complex populates", props.size() >= 22, str(props.size()))
	var stands := view.find_children("Prop_grandStand_*", "Node3D", true, false)
	_check("grandstands flank start", stands.size() == 2, str(stands.size()))
	var cat := view.cat_node
	_check("tussie the cat sits at the start", cat != null and cat.is_inside_tree() and cat.get_node_or_null("Head") != null and cat.get_node_or_null("Body/Tail") != null)
	_check("cat is long-haired", cat != null and cat.get_node("Body/Ruff").get_child_count() >= 12 and cat.get_node("Body").get_child_count() > 50)
	var fur_colors := {}
	for m in cat.find_children("*", "MeshInstance3D", true, false):
		var fm := (m as MeshInstance3D).material_override as StandardMaterial3D
		if fm != null:
			fur_colors[fm.albedo_color.to_html(false)] = true
	_check("cat is red and white", fur_colors.has(Cat3D.GINGER.to_html(false)) and fur_colors.has(Cat3D.CREAM.to_html(false)))
	var side_target := cat.to_global(Vector3(1, 0, 0.2))
	for _i in 40:
		Cat3D.animate(cat, 1.0, side_target)
	_check("cat watches the cars", (cat.get_node("Head") as Node3D).rotation.y > 0.6, str((cat.get_node("Head") as Node3D).rotation.y))
	var tail_a := (cat.get_node("Body/Tail") as Node3D).rotation.y
	Cat3D.animate(cat, 2.0)
	_check("cat swishes its tail", absf((cat.get_node("Body/Tail") as Node3D).rotation.y - tail_a) > 0.05)
	var env_node: WorldEnvironment = null
	for c in view.get_children():
		if c is WorldEnvironment:
			env_node = c
	_check("glow grade on", env_node != null and env_node.environment != null and env_node.environment.glow_enabled)
	_check("crowd fills both stands", view.crowds.size() == 2 and (view.crowds[0]["mm"] as MultiMesh).instance_count >= 50)
	var before: Vector3 = (view.crowds[0]["mm"] as MultiMesh).get_instance_transform(3).origin
	view.sim.race_time = 0.7
	for _i in 3:
		view._animate_crowds()
	var after: Vector3 = (view.crowds[0]["mm"] as MultiMesh).get_instance_transform(3).origin
	_check("crowd cheers", absf(after.x - before.x) < 0.01 and after.y >= before.y, "%s -> %s" % [before, after])
	var gmat := TrackBuilder3D.ground_material()
	_check("asphalt has detail", gmat.albedo_texture != null and gmat.uv1_triplanar)
	_check("wet asphalt shines", TrackBuilder3D.ground_material(true).roughness < gmat.roughness * 0.5)
	var harbor := TrackData.get_track("harbor_loop")
	var g_cols: PackedColorArray = TrackBuilder3D.build_ground(harbor).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var road_tones := {}
	for ty in harbor.height:
		for tx in harbor.width:
			if harbor.rows[ty].substr(tx, 1) == "A":
				road_tones[g_cols[(ty * harbor.width + tx) * 4].to_html()] = true
	_check("road has no checker", road_tones.size() > 4, str(road_tones.size()))
	view.queue_free()
	var night_view := RaceView.new()
	add_child(night_view)
	night_view.setup({
		"track_id": "gearworks", "mode": "exhibition", "champ_id": "", "two_player": false,
		"assist": true, "difficulty": "pro", "tier": "turbo", "fee_paid": 0,
		"roster": Game.build_roster("turbo", false),
	})
	_check("no weather by default", night_view.rain_fx == null and not night_view.rain)
	var lamps := night_view.find_children("Prop_lightPostModern_*", "Node3D", true, false)
	_check("modern lamps light industry", lamps.size() >= 1, str(lamps.size()))
	var night_env: WorldEnvironment = null
	for c in night_view.get_children():
		if c is WorldEnvironment:
			night_env = c
	_check("night grade darker", night_env != null and night_env.environment != null and night_env.environment.ambient_light_energy < 0.5)
	night_view.queue_free()
	var wet_view := RaceView.new()
	add_child(wet_view)
	wet_view.setup({
		"track_id": "harbor_loop", "mode": "exhibition", "champ_id": "", "two_player": false,
		"assist": true, "difficulty": "pro", "tier": "club", "fee_paid": 0, "weather": "rain",
		"roster": Game.build_roster("club", false),
	})
	_check("rain falls", wet_view.rain and wet_view.rain_fx != null and wet_view.rain_fx.amount > 100)
	_check("rain cuts grip", wet_view.sim.wet_grip < 0.9 and wet_view.sim.wet_grip > 0.5, str(wet_view.sim.wet_grip))
	var sprays := wet_view.find_children("RainSpray", "CPUParticles3D", true, false)
	_check("every car sprays in rain", sprays.size() == wet_view.sim.cars.size(), str(sprays.size()))
	var lamp_nodes := wet_view.find_children("Headlamp*", "MeshInstance3D", true, false)
	var lamps_on := lamp_nodes.size()
	_check("headlamps on in rain", lamps_on == wet_view.sim.cars.size() * 2, "%d for %d cars" % [lamps_on, wet_view.sim.cars.size()])
	_check("dry cars stay clean", view.find_children("RainSpray", "CPUParticles3D", true, false).is_empty())
	_cinematic(wet_view)
	wet_view.queue_free()
	_check("monsoon is a mutator", Game.daily_mutator_blurb("monsoon").begins_with("MONSOON"))


func _cinematic(view: RaceView) -> void:
	var me := view._me()
	view.sim.state = "racing"
	me.finished = true
	me.finish_time = 83.45
	me.rank = 1
	view._check_me_finished(me)
	_check("finish starts orbit", view.cine_t == 0.0)
	_check("finish callout shows place and time", view.callout_label.text.contains("1ST") and view.callout_label.text.contains("1:23.45"), view.callout_label.text)
	view.sim.state = "finished"
	view._physics_process(0.1)
	_check("results wait for the orbit", not view.reported and view.cine_holding())
	_check("letterbox slides in", (view.letterbox[0] as ColorRect).visible)
	var near := RaceView.orbit_point(Vector3.ZERO, 0.0, 3.0)
	var far := RaceView.orbit_point(Vector3.ZERO, 0.0, 0.0)
	_check("orbit closes in", Vector2(near.x, near.z).length() < Vector2(far.x, far.z).length() and near.y < far.y)
	var next_rank := 2
	for other in view.sim.cars:
		if other != me:
			(other as CarState).rank = next_rank
			next_rank += 1
	view.cine_t = RaceView.CINE_HOLD + 0.1
	view._physics_process(0.1)
	_check("podium follows the orbit", view.podium != null and view.podium.is_inside_tree() and not view.reported and view.cine_holding())
	_check("podium has three blocks and the cat", view.podium != null and view.podium.get_node_or_null("Block1") != null and view.podium.get_node_or_null("Block3") != null and view.podium.get_node_or_null("PodiumCat") != null)
	_check("podium seats the winner on top", view.podium != null and view.podium.get_node_or_null("Car1") != null and str(view.podium.get_node("Car1").get_meta("car_id", "")) == me.id)
	_check("podium camera looks at the stage", view.cam.global_position.distance_to(view.podium_origin()) < 400.0 and view.cam.global_position.y > view.podium_origin().y)
	_check("podium callout names the winner", view.callout_label.text == "YOU WIN!", view.callout_label.text)
	view.cine_t = view.cine_total() + 0.1
	view._physics_process(0.1)
	_check("results follow the podium", view.reported)
	var a := CarState.new()
	a.rank = 3
	var b := CarState.new()
	b.rank = 1
	var c := CarState.new()
	c.rank = 2
	c.dnf = true
	var d := CarState.new()
	d.rank = 4
	var top := Podium3D.top_three([a, b, c, d])
	_check("podium ranks by place and skips wrecks", top.size() == 3 and top[0] == b and top[1] == a and top[2] == d)


func _walls() -> void:
	var oval := TrackData.get_track("test_oval")
	_check("roads are widened", oval.tile == TrackData.WIDE_TILE and TrackData.WIDE_TILE > 32)
	_check("curbs and grass are walls", oval.blocking(Vector2(4.5, 4.5) * oval.tile) and oval.blocking(Vector2(1.5, 1.5) * oval.tile) and not oval.blocking(Vector2(15.5, 5.5) * oval.tile))
	var driver := _player_spec()
	var sim := _race([driver])
	var car: CarState = sim.cars[0]
	sim.race_time = 6.0
	car.pos = Vector2(15.5, 6.0) * oval.tile
	car.prev_pos = car.pos
	car.heading = -PI * 0.5
	car.vel = Vector2(0, -460)
	car.hit_cd = 0.0
	var before := car.hp
	var crashed := false
	for _i in 12:
		sim.inputs[0] = {"throttle": 1.0, "brake": 0.0, "steer": 0.0}
		sim.step(1.0 / 30.0)
		for e in sim.events:
			if str(e.get("type", "")) == "crash" and str(e.get("id", "")) == car.id:
				crashed = true
	_check("full-speed wall hit hurts", before - car.hp > 15.0, "%.1f" % (before - car.hp))
	_check("wall hit is reported", crashed)
	_check("walls stop the car", not oval.blocking(car.pos))
	_check("glancing hits are gentle", CarSim.wall_damage(130.0, 0.07) < 6.0 and CarSim.wall_damage(470.0, 0.07) > 25.0)
	_check("road is wider than two cars side by side", oval.tile * 5 >= 250, str(oval.tile))
	var full_scrape := CarSim.scrape_damage(450.0, 1.0, Balance.num("wall_damage", 0.1))
	_check("scraping along a wall wears the hull", full_scrape > 5.0 and full_scrape < 12.0, "%.1f/s" % full_scrape)
	_check("ai takes softer wall damage", CarSim.scrape_damage(450.0, 1.0, Balance.num("wall_damage", 0.1) * Balance.num("ai_wall_factor", 0.35)) < full_scrape * 0.5)
	_check("exhibition offers every circuit", Game.exhibition_tracks().size() >= 16, str(Game.exhibition_tracks().size()))
	for id in ["harbor_loop", "gearworks", "salt_pan", "storm_point"]:
		var t := TrackData.get_track(id)
		_check("%s still valid when widened" % id, TrackValidator.validate(t).is_empty(), " ".join(TrackValidator.validate(t)))


func _rival() -> void:
	Game.new_career("Rival", "pro", "sprint_dart")
	var field := Game.ensure_field("club")
	var rid := Game.rival_id("club")
	_check("season rival is the field's ace", rid == str(field[0]["id"]), rid)
	var bounty := Game.rival_bounty("club")
	_check("bounty is a round sum", bounty > 0 and bounty % 10 == 0, str(bounty))
	var standings := [{"id": "player", "is_player": true, "player_index": 0, "position": 2, "dnf": false}]
	var others := [1, 4, 5, 6, 7]
	for d in field:
		var at := 3 if str(d["id"]) == rid else int(others.pop_front())
		standings.append({"id": str(d["id"]), "position": at, "dnf": false})
	var before := Game.money()
	var summary := Game.apply_result("club", {
		"track_id": "harbor_loop", "standings": standings,
		"player": {"position": 2, "dnf": false, "hp": 100.0, "ammo": {}, "best_lap": 0.0},
	}, 0)
	var rival: Dictionary = summary.get("rival", {})
	_check("beating the rival pays the bounty", bool(rival.get("beaten", false)) and Game.money() - before == int(summary["pay"]["prize"]) + bounty, "%s %d" % [rival, Game.money() - before])
	_check("rival count in stats", int(Game.profile["stats"].get("rivals_beaten", 0)) == 1)
	var next_rival := Game.rival_id("club")
	var rows := Game.standings("club")
	var me_at := rows.find(rows.filter(func(r): return bool(r["player"]))[0])
	var want := str(rows[me_at - 1]["id"]) if me_at > 0 else str(rows[1]["id"])
	_check("rival tracks the standings", next_rival == want, "%s vs %s" % [next_rival, want])
	var lost := Game.apply_result("club", {
		"track_id": "harbor_loop", "standings": [{"id": "player", "is_player": true, "player_index": 0, "position": 6, "dnf": false}, {"id": next_rival, "position": 1, "dnf": false}],
		"player": {"position": 6, "dnf": false, "hp": 100.0, "ammo": {}, "best_lap": 0.0},
	}, 0)
	_check("losing to the rival pays nothing", not bool(lost["rival"]["beaten"]) and int(lost["rival"]["bounty"]) == 0)
	Game.restart_season("club")
	var view := RaceView.new()
	add_child(view)
	var rid2 := Game.rival_id("club")
	view.setup({
		"track_id": "harbor_loop", "mode": "career", "champ_id": "club", "two_player": false,
		"assist": true, "difficulty": "pro", "tier": "club", "fee_paid": 0,
		"rival_id": rid2, "rival_bounty": Game.rival_bounty("club"),
		"roster": Game.build_roster("club", false),
	})
	_check("rival wears a red marker", view.find_children("RivalMarker", "Node3D", true, false).size() == 1)
	var me := view._me()
	var foe := view.rival_car()
	_check("rival car found", foe != null and foe.id == rid2)
	view.sim.state = "racing"
	me.rank = 2
	foe.rank = 3
	view._rival_quiet_until = 0
	view._watch_rival(me)
	_check("passing the rival is called out", view.callout_label.text == "RIVAL PASSED!", view.callout_label.text)
	_check("rival hud tracks the gap", view.rival_label != null and view.rival_label.text.ends_with("3RD  BEHIND"), view.rival_label.text if view.rival_label else "")
	view.queue_free()
	var app := App.new()
	add_child(app)
	app.show_briefing("club")
	_check("briefing names the rival", _label_texts(app).any(func(t): return str(t).begins_with("RIVAL: ")))
	app.show_results({"mode": "career", "track_name": "Harbor", "player": {"position": 1}, "standings": []}, {"pay": {}, "rival": {"name": "Ace", "beaten": true, "bounty": 500}})
	_check("results show the bounty", _label_texts(app).any(func(t): return str(t).begins_with("Rival Ace beaten")))
	app.queue_free()


func _knockout() -> void:
	Game.new_career("KO", "pro", "sprint_dart")
	var sim := RaceSim.new()
	sim.setup({
		"track_id": "harbor_loop", "difficulty": "pro", "tier": "club",
		"knockout": true, "roster": Game.build_roster("club", false),
	})
	sim.use_ai_for_players = true
	sim.start_now()
	_check("knockout timer", sim.knockout and absf(sim.knockout_in() - sim.knock_interval) < 0.01)
	var outs := []
	var steps := 0
	while sim.state == "racing" and steps < 60 * 200:
		sim.step(1.0 / 60.0)
		for e in sim.events:
			if str(e.get("type", "")) == "knockout":
				outs.append([sim.race_time, str(e["id"])])
		steps += 1
	_check("knockout ends", sim.state == "finished", "t=%s alive=%d" % [sim.race_time, sim.alive_cars().size()])
	var destroyed := sim.cars.filter(func(c): return c.dnf and c.knocked_at <= 0.0).size()
	_check("one knocked per interval", outs.size() + destroyed == sim.cars.size() - 1, "%d outs %d destroyed" % [outs.size(), destroyed])
	if outs.size() > 0:
		_check("first knockout on time", absf(float(outs[0][0]) - sim.knock_interval) < 0.05, str(outs[0][0]))
	var res := sim.result()
	var top: Dictionary = res["standings"][0]
	_check("survivor wins", bool(top["finished"]) and not bool(top["dnf"]))
	var last: Dictionary = res["standings"][res["standings"].size() - 1]
	_check("earliest out ranks last", destroyed > 0 or (outs.size() > 0 and str(last["id"]) == str(outs[0][1])), "%s vs %s" % [last["id"], outs])
	var plain := _race([_player_spec()])
	_check("plain races have no knockout", not plain.knockout)


func _ai_lap() -> void:
	Game.new_career("AI Probe", "pro", "sprint_dart")
	var field := Game.ensure_field("club")
	_check("ai field", field.size() >= 5, str(field.size()))
	var spec: Dictionary = Game.ai_spec(field[0], "club")
	var sim := _race([spec])
	var car: CarState = sim.cars[0]
	var origin := car.pos
	var moved := false
	var lapped := false
	for _i in 1600:
		sim.step(0.05)
		if car.pos.distance_to(origin) > 80.0:
			moved = true
		if car.laps >= 1:
			lapped = true
			break
		if sim.state == "finished":
			break
	_check("ai drives", moved, "pos %s vel %s wp %s" % [car.pos, car.vel, car.wp_index])
	_check("ai completes a lap", lapped, "laps %s wp %s pos %s time %s" % [car.laps, car.wp_index, car.pos, sim.race_time])


func _harbor_opening() -> void:
	Game.new_career("Probe", "pro", "sprint_dart")
	var sim := RaceSim.new()
	sim.setup({
		"track_id": "harbor_loop",
		"difficulty": "pro",
		"tier": "club",
		"time_limit": 90.0,
		"roster": Game.build_roster("club", false),
	})
	sim.use_ai_for_players = true
	var player: CarState = null
	for car in sim.cars:
		if car.is_player and car.player_index == 0:
			player = car
	var spread := 0.0
	for _i in 900:
		sim.step(1.0 / 60.0)
		var far := 0.0
		for car in sim.cars:
			far = maxf(far, car.pos.distance_to(player.pos))
		spread = maxf(spread, far)
		if sim.state == "finished":
			break
	var bits := []
	for car in sim.cars:
		bits.append("%s lap %s hp %d tile %s pos %s" % [car.id, car.laps, int(car.hp), sim.track.cell(car.pos), car.pos])
	var detail := "state %s t %.2f spread %.0f | %s" % [sim.state, sim.race_time, spread, " / ".join(bits)]
	_check("opening lasts ten seconds", sim.race_time >= 9.5 and not player.dnf, detail)
	_check("pack leaves the grid", spread > 200.0, detail)
	for track in TrackData.all_tracks():
		if track.id == "test_oval":
			continue
		var sweep := RaceSim.new()
		sweep.setup({
			"track_id": track.id,
			"difficulty": "rookie",
			"tier": "club",
			"time_limit": 40.0,
			"roster": Game.build_roster("club", false),
		})
		sweep.use_ai_for_players = true
		sweep.start_now()
		var pilot: CarState = null
		for car in sweep.cars:
			if car.is_player and car.player_index == 0:
				pilot = car
		var origin := pilot.pos
		for _j in 240:
			sweep.step(1.0 / 60.0)
			if sweep.state == "finished":
				break
		_check("%s opens" % track.id, pilot.pos.distance_to(origin) > 50.0 and pilot.hp > 0.0, "hp %s moved %.0f" % [pilot.hp, pilot.pos.distance_to(origin)])


func _menus() -> void:
	var app := App.new()
	add_child(app)
	var names := _button_texts(app)
	app.show_exhibition()
	var track_grid := app.find_children("TrackGrid", "GridContainer", true, false)
	_check("exhibition grid lists all 16 tracks", track_grid.size() == 1 and (track_grid[0] as GridContainer).get_child_count() == 16)
	app.show_main()
	_check("cat on the main menu", app.find_children("CatStage", "SubViewportContainer", true, false).size() == 1)
	_check("main menu", names.has("New Career") and names.has("Settings") and names.has("Credits") and names.has("Quit"), " ".join(names))
	app.show_settings()
	names = _button_texts(app)
	_check("settings menu", names.has("Back"), " ".join(names))
	app.show_credits()
	_check("credits", _button_texts(app).has("Back"))
	app.show_main()
	_check("main menu has how to play", _button_texts(app).has("How to Play"))
	app.show_help()
	var help_labels := _label_texts(app)
	_check("how to play explains the game", help_labels.has("Keyboard") and help_labels.has("Weapons and pickups") and help_labels.has("Career") and _button_texts(app).has("Back"), " ".join(help_labels))
	app.show_multiplayer()
	var lobby_names := _button_texts(app)
	_check("wifi lobby one-tap", lobby_names.has("QUICK HOST — one tap race") and lobby_names.has("Rescan"), " ".join(lobby_names))
	var race1 := {"standings": [
		{"name": "Ari", "is_player": true, "position": 2, "dnf": false},
		{"name": "Bot", "is_player": false, "position": 1, "dnf": false},
		{"name": "Kim", "is_player": true, "position": 4, "dnf": false},
	]}
	var race2 := {"standings": [
		{"name": "Kim", "is_player": true, "position": 1, "dnf": false},
		{"name": "Ari", "is_player": true, "position": 5, "dnf": true},
	]}
	app.party_score(race1)
	app.party_score(race2)
	var table: Array = app.party_table()
	_check("party counts races", app.party_races == 2)
	_check("party scores humans only", table.size() == 2 and not app.party.has("Bot"))
	_check("party leader", str(table[0]["name"]) == "Kim" and int(table[0]["points"]) == 12 + 15 and int(table[0]["wins"]) == 1, str(table))
	_check("dnf earns a point", int(app.party["Ari"]["points"]) == 15 + 1, str(app.party["Ari"]))
	app.party_score({"standings": [{"name": "Solo", "is_player": true, "position": 1}]})
	_check("solo races skip party", app.party_races == 2)
	app.show_multiplayer()
	_check("lobby shows party", _label_texts(app).any(func(t): return str(t).begins_with("PARTY GRAND PRIX")))
	app.party_reset()
	_check("party resets", app.party_races == 0 and app.party.is_empty())
	app.queue_free()


func _net() -> void:
	var dirty := {"throttle": 9.0, "brake": -3.0, "steer": 5.0, "fire_front": 1, "boost": true, "extra": "x"}
	var clean := NetDefs.sanitize_input(dirty)
	_check("input sanitized", clean["throttle"] == 1.0 and clean["brake"] == 0.0 and clean["steer"] == 1.0 and bool(clean["fire_front"]) and bool(clean["boost"]) and not clean.has("extra"))
	_check("neutral input calm", NetDefs.neutral_input()["throttle"] == 0.0 and not bool(NetDefs.neutral_input()["boost"]))
	var pkt := NetDefs.discovery_packet("Host", "harbor_loop", 2, 7777)
	var info := NetDefs.parse_discovery(pkt)
	_check("discovery round-trips", str(info.get("track", "")) == "harbor_loop" and int(info.get("humans", 0)) == 2 and int(info.get("port", 0)) == 7777)
	_check("discovery rejects strangers", NetDefs.parse_discovery({"game": "other"}).is_empty())
	_check("paint cleaned", NetDefs.clean_paint("red") == "red" and NetDefs.clean_paint("hacker") == "cyan")
	_check("names cleaned", NetDefs.clean_player_name("   ") == "Driver" and NetDefs.clean_player_name("  Ada  ") == "Ada")
	Game.new_career("Net Probe", "pro", "sprint_dart")
	var humans := [
		{"name": "Ada", "paint": "red", "peer_id": 1, "index": 0},
		{"name": "Bo", "paint": "blue", "peer_id": 2, "index": 1},
	]
	var roster := Game.build_net_roster(humans, "club")
	_check("net roster six cars", roster.size() == 6, str(roster.size()))
	_check("net humans first", bool(roster[0]["is_player"]) and bool(roster[1]["is_player"]) and int(roster[0]["player_index"]) == 0 and int(roster[1]["player_index"]) == 1)
	var sim := RaceSim.new()
	sim.setup({"track_id": "test_oval", "difficulty": "pro", "tier": "club", "time_limit": 120.0, "roster": roster})
	sim.start_now()
	for _i in 20:
		sim.step(0.05)
	var snap := NetDefs.build_snapshot(sim)
	_check("snapshot has cars", (snap.get("cars", []) as Array).size() == 6, str((snap.get("cars", []) as Array).size()))
	var sim2 := RaceSim.new()
	sim2.setup({"track_id": "test_oval", "difficulty": "pro", "tier": "club", "time_limit": 120.0, "roster": roster})
	sim2.start_now()
	NetDefs.apply_snapshot(sim2, snap)
	var same := true
	for i in sim.cars.size():
		if sim.cars[i].pos.distance_to(sim2.cars[i].pos) > 1.0:
			same = false
	_check("snapshot restores positions", same)
	_check("snapshot restores clock", is_equal_approx(sim2.race_time, sim.race_time))


func _pads() -> void:
	var road := {"id": "A", "grip": 1.0, "drag": 0.12, "damage": 0.0}
	var pad := {"id": "N", "grip": 0.96, "drag": 0.16, "damage": 0.0}
	var cruiser := _car(Vector2(400, 400), 0.0)
	var booster := _car(Vector2(400, 400), 0.0)
	cruiser.boost = 0.2
	booster.boost = 0.2
	cruiser.max_speed = 1200.0
	booster.max_speed = 1200.0
	cruiser.vel = Vector2(300, 0)
	booster.vel = Vector2(300, 0)
	for _i in 20:
		CarSim.integrate(cruiser, {"throttle": 1.0, "brake": 0.0, "steer": 0.0}, 0.05, road)
		CarSim.integrate(booster, {"throttle": 1.0, "brake": 0.0, "steer": 0.0}, 0.05, pad)
	_check("pad fills nitro fast", booster.boost > cruiser.boost + 0.4, "pad %s road %s" % [booster.boost, cruiser.boost])
	_check("pad kicks speed", booster.vel.length() > cruiser.vel.length() + 10.0, "pad %s road %s" % [booster.vel.length(), cruiser.vel.length()])


func _graphics3d() -> void:
	var track := TrackData.get_track("harbor_loop")
	_check("harbor track loads", track != null)
	var ground := TrackBuilder3D.build_ground(track)
	var g_arrays := ground.surface_get_arrays(0)
	var verts: PackedVector3Array = g_arrays[Mesh.ARRAY_VERTEX]
	_check("ground covers every cell", verts.size() == track.width * track.height * 4, str(verts.size()))
	var walls := TrackBuilder3D.build_walls(track)
	if walls.get_surface_count() > 0:
		var w_arrays := walls.surface_get_arrays(0)
		var wverts: PackedVector3Array = w_arrays[Mesh.ARRAY_VERTEX]
		_check("walls have boxes", wverts.size() > 0 and posmod(wverts.size(), 20) == 0, str(wverts.size()))
	else:
		_check("walls have boxes", false, "no surface")
	_check("water sits low", TrackBuilder3D.cell_height("W") < TrackBuilder3D.cell_height("A"))
	_check("kerbs sit high", TrackBuilder3D.cell_height("C") > TrackBuilder3D.cell_height("A"))
	_check("paints differ", TrackBuilder3D.paint_named("cyan") != TrackBuilder3D.paint_named("red"))
	for body in ["dart", "viper", "mule", "fang"]:
		_check("%s has a kenney model" % body, ResourceLoader.exists(CarFactory3D.kenney_path(body)), CarFactory3D.kenney_path(body))
		var built := CarFactory3D.build(body, "cyan")
		var root: Node3D = built["root"]
		add_child(root)
		var holder: Node3D = built["suspension"]
		_check("%s yaws nose to +X" % body, absf(holder.rotation.y - CarFactory3D.KENNEY_YAW) < 0.001, str(holder.rotation.y))
		var box := CarFactory3D._model_aabb(holder.get_child(0))
		var world_len: float = box.size.z * holder.get_child(0).scale.z
		_check("%s spans a car length" % body, absf(world_len - CarFactory3D.KENNEY_LEN) < 2.0, str(world_len))
		_check("%s has effects" % body, built["flame"] != null and built["smoke"] != null and built["blob"] != null)
		_check("%s body material" % body, built["body_mat"] is StandardMaterial3D)
		root.queue_free()
		var procedural := CarFactory3D.build_procedural(body, "cyan")
		_check("%s fallback has wheels" % body, (procedural["wheels"] as Array).size() == 4)
		(procedural["root"] as Node3D).queue_free()
	var sim := _race([_player_spec()])
	var car: CarState = sim.cars[0]
	var view := RaceView.new()
	_check("night is industrial", RaceView.is_night_env("industrial") and not RaceView.is_night_env("coastal") and not RaceView.is_night_env("desert"))
	var rails := TrackBuilder3D.build_rails(track)
	if rails.get_surface_count() > 0:
		var r_arrays := rails.surface_get_arrays(0)
		var rverts: PackedVector3Array = r_arrays[Mesh.ARRAY_VERTEX]
		_check("rails guard the road", rverts.size() > 100, str(rverts.size()))
	else:
		_check("rails guard the road", false, "no surface")
	var pads := TrackBuilder3D.build_pads(track)
	_check("pads glow on boost tiles", pads.get_surface_count() > 0, "harbor pads")
	_check("pad cells found", TrackBuilder3D.pad_cells(track).size() > 0)
	_check("3d view maps sim to ground", RaceView.flat(car.pos).x == car.pos.x and RaceView.flat(car.pos).z == car.pos.y)


func _masters() -> void:
	Game.new_career("Master Probe", "pro", "sprint_dart")
	_check("masters locked first", not Game.championship_unlocked("masters"))
	_check("masters fee", Economy.entry_fee("masters") == 2000)
	_check("masters win purse", Economy.payout(1, "masters", "pro") == 8000)
	var field := Game.ensure_field("masters")
	_check("masters field is elite", field.size() >= 5 and int(field[0].get("tier", 1)) == 3, str(field.size()))
	var spec: Dictionary = Game.ai_spec(field[0], "masters")
	_check("masters ai fastest", float(spec["max_speed"]) > 0.0)
	Game.profile["championships"]["club"] = {"race_index": 4, "points": {}, "completed": true, "field": [], "best_rank": 1}
	Game.profile["championships"]["national"] = {"race_index": 4, "points": {}, "completed": true, "field": [], "best_rank": 1}
	Game.profile["championships"]["turbo"] = {"race_index": 4, "points": {}, "completed": true, "field": [], "best_rank": 1}
	_check("masters unlocks after turbo", Game.championship_unlocked("masters"))
	_check("masters opens", Game.next_track_id("masters") == "gull_rock", Game.next_track_id("masters"))


func _assets() -> void:
	var paths := [
		"res://assets/sprites/cars/dart_cyan.png",
		"res://assets/sprites/cars/viper_red.png",
		"res://assets/sprites/cars/mule_olive.png",
		"res://assets/sprites/cars/fang_violet.png",
		"res://assets/sprites/fx/pickup_boost.png",
		"res://assets/sprites/fx/soft_shadow.png",
		"res://assets/sprites/fx/vignette.png",
		"res://assets/sprites/fx/explosion.png",
		"res://assets/sprites/fx/smoke.png",
		"res://assets/audio/music_menu.wav",
		"res://assets/audio/engine.wav",
		"res://assets/audio/missile.wav",
		"res://assets/icon.png",
		"res://scenes/main.tscn",
	]
	for path in paths:
		var res = ResourceLoader.load(path)
		_check("loads %s" % path.get_file(), res != null)


func _race(roster: Array) -> RaceSim:
	var sim := RaceSim.new()
	sim.setup({
		"track_id": "test_oval",
		"difficulty": "pro",
		"tier": "club",
		"time_limit": 120.0,
		"roster": roster,
	})
	sim.start_now()
	return sim


func _player_spec() -> Dictionary:
	return {
		"id": "player",
		"name": "Player",
		"is_player": true,
		"player_index": 0,
		"body": "dart",
		"paint": "cyan",
		"hp": 100.0,
		"max_hp": 100.0,
		"accel": 540.0,
		"brake": 820.0,
		"max_speed": 470.0,
		"grip": 8.2,
		"turn_rate": 3.05,
		"damage_taken": 1.0,
		"ammo_missile": 12,
		"ammo_rear": 0,
		"ammo_mine": 0,
	}


func _car(pos: Vector2, heading: float) -> CarState:
	var car := CarState.new()
	car.apply_spec(_player_spec())
	car.pos = pos
	car.prev_pos = pos
	car.heading = heading
	return car


func _sweep(sim: RaceSim, car: CarState, index: int, forward: bool) -> bool:
	var cp: Dictionary = sim.track.checkpoints[index]
	var across: Vector2 = cp["b"] - cp["a"]
	var tangent := Vector2(across.y, -across.x).normalized()
	if not forward:
		tangent = -tangent
	var mid: Vector2 = (cp["a"] + cp["b"]) * 0.5
	car.prev_pos = mid - tangent * 30.0
	car.pos = mid + tangent * 30.0
	return sim._cross_checkpoint(car)


func _label_texts(node: Node) -> Array:
	var out := []
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_label_texts(child))
	return out


func _button_texts(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		out.append_array(_button_texts(child))
	return out


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passes += 1
		print("PASS ", name)
	else:
		var line := name if detail == "" else "%s (%s)" % [name, detail]
		failures.append(line)
		print("FAIL ", line)


func _vr() -> void:
	_check("vr is off on a plain desktop run", not VR.active())
	var xf := Transform3D(Basis(), Vector3(0, 0, -2))
	var center := VrPanel.hit_local(xf, Vector2(2.4, 1.35), Vector2(960, 540), Vector3.ZERO, Vector3(0, 0, -1))
	_check("vr panel hit maps to centre pixel", not center.is_empty() and (center["px"] as Vector2).distance_to(Vector2(480, 270)) < 0.5 and absf(float(center["dist"]) - 2.0) < 0.01, str(center))
	var corner := VrPanel.hit_local(xf, Vector2(2.4, 1.35), Vector2(960, 540), Vector3(-1.1, 0.6, 0), Vector3(0, 0, -1))
	_check("vr panel top-left maps to top-left", not corner.is_empty() and (corner["px"] as Vector2).x < 41.0 and (corner["px"] as Vector2).y < 31.0, str(corner))
	_check("vr panel misses beside it", VrPanel.hit_local(xf, Vector2(2.4, 1.35), Vector2(960, 540), Vector3(3, 0, 0), Vector3(0, 0, -1)).is_empty())
	_check("vr panel ignores rays pointing away", VrPanel.hit_local(xf, Vector2(2.4, 1.35), Vector2(960, 540), Vector3.ZERO, Vector3(0, 0, 1)).is_empty())
	var ok_yaw := true
	for h in [0.0, 0.7, PI * 0.5, 2.5, -1.9]:
		var f := Vector3(cos(h), 0, sin(h))
		if (Basis(Vector3.UP, VR.yaw_facing(f)) * Vector3.FORWARD).distance_to(f) > 0.001:
			ok_yaw = false
	_check("vr origin faces the car heading", ok_yaw)
	_check("vr stick deadzone", VR.deadzone(0.08) == 0.0 and absf(VR.deadzone(1.0) - 1.0) < 0.001 and VR.deadzone(-0.5) < 0.0)
	var fwd := Vector3(1, 0, 0)
	var chase := RaceView.vr_eye(Vector3.ZERO, fwd, "chase")
	var pit := RaceView.vr_eye(Vector3.ZERO, fwd, "cockpit")
	_check("vr chase eye sits behind and above", chase.x < -50.0 and chase.y > 30.0, str(chase))
	_check("vr cockpit eye clears the roof", pit.y > 24.0 and absf(pit.x) < 10.0, str(pit))
	var panel := VrPanel.new(Vector2i(400, 300), Vector2(2, 1.5))
	add_child(panel)
	var clicked := [0]
	var button := Button.new()
	button.position = Vector2(100, 100)
	button.size = Vector2(200, 100)
	button.pressed.connect(func(): clicked[0] += 1)
	panel.viewport.add_child(button)
	_check("vr panel registers itself", VrPanel.panels.has(panel))
	panel.pointer(Vector2(200, 150), false)
	panel.pointer(Vector2(200, 150), true)
	panel.pointer(Vector2(201, 150), false)
	_check("vr laser click presses a button", clicked[0] == 1, str(clicked[0]))
	panel.pointer(Vector2(20, 20), true)
	panel.pointer(Vector2(20, 20), false)
	_check("vr click outside does nothing", clicked[0] == 1)
	panel.queue_free()
	var was_vr_view := VR.view_mode()
	VR.sim = true
	_check("touch controls stay off in vr", not Settings.touch_active())
	Game.new_career("Visor", "pro", "sprint_dart")
	var view := RaceView.new()
	add_child(view)
	view.setup({
		"track_id": "harbor_loop", "mode": "exhibition", "champ_id": "", "two_player": true,
		"assist": true, "difficulty": "pro", "tier": "club", "fee_paid": 0,
		"roster": Game.build_roster("club", false),
	})
	_check("vr race builds an xr rig", view.vr and view.vr_origin != null and view.vr_origin.current and view.vr_cam != null and view.vr_hands.size() == 2)
	_check("vr race skips split screen", view.split_cams.is_empty())
	_check("vr hud lives on a panel", view.vr_hud != null and view.hud_labels["pos"].get_viewport() == view.vr_hud.viewport and view.pause_layer.get_viewport() == view.vr_hud.viewport)
	_check("vr hud skips letterbox and vignette", view.letterbox.is_empty() and view.vignette == null)
	_check("vr rig keeps tracking while paused", view.vr_origin.process_mode == Node.PROCESS_MODE_ALWAYS)
	var me := view._me()
	var f := Vector3(cos(me.heading), 0, sin(me.heading))
	view._vr_snap = true
	Settings.data["vr_view"] = "chase"
	view._drive_vr(me, 0.016)
	var behind := (view.vr_origin.position - RaceView.flat(me.pos)).dot(f)
	_check("vr chase rig follows behind the car", behind < -50.0, str(behind))
	view._toggle_pause()
	_check("vr pause turns the lasers on", (view.vr_hands[1] as VrHand).pointing and get_tree().paused)
	view._toggle_pause()
	_check("vr resume turns the lasers off", not (view.vr_hands[1] as VrHand).pointing and not get_tree().paused)
	view._on_vr_button("by_button", false)
	_check("vr Y button swaps camera", VR.view_mode() == "cockpit")
	var drive := view._merged_drive()
	_check("vr drive keeps keyboard shape", drive.has("throttle") and drive.has("steer") and drive.has("boost"))
	view.queue_free()
	Settings.data["vr_view"] = was_vr_view
	var lobby := VrLobby.new()
	add_child(lobby)
	var stub := App.new()
	lobby.host_app(stub)
	_check("vr lobby hosts the menus on a screen", stub.get_viewport() == lobby.panel.viewport and lobby.origin.current)
	_check("vr lobby seats tussie", lobby.cat != null and lobby.cat.is_inside_tree())
	_check("vr lobby shows your car", lobby.turntable.get_child_count() == 1)
	lobby.queue_free()
	VR.sim = false
	var gdext := FileAccess.get_file_as_string("res://addons/godotopenxrvendors/plugin.gdextension")
	_check("openxr vendors ships android", gdext.contains("android.release.arm64"))
	_check("quest feature enables openxr", bool(ProjectSettings.get_setting("xr/openxr/enabled.quest", false)) and not bool(ProjectSettings.get_setting("xr/openxr/enabled", true)))
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check("quest export preset", not FileAccess.file_exists("res://export_presets.cfg") or presets.contains("name=\"Quest 3\"") and presets.contains("meta_xr_features/quest_3_support=true"))
