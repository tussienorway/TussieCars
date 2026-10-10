extends Node

func _ready() -> void:
	var ids := []
	for champ in Balance.championships:
		for t in champ.get("tracks", []):
			ids.append(str(t))
	Game.new_career("Probe", "pro", "sprint_dart")
	for id in ids:
		var track := TrackData.get_track(id)
		if track == null:
			print("PROBE %s: NULL TRACK" % id)
			continue
		var sim := RaceSim.new()
		sim.setup({"track_id": id, "difficulty": "pro", "tier": "club", "roster": Game.build_roster("club", false), "assist": true})
		sim.use_ai_for_players = true
		var t := 0.0
		var kinds := {}
		var deaths := []
		var hp_prev := {}
		var loss := {"wall": 0.0, "other": 0.0}
		var wall := {}
		while sim.state != "finished" and t < 400.0:
			for c in sim.cars:
				hp_prev[c.id] = c.hp
			sim.step(1.0 / 30.0)
			t += 1.0 / 30.0
			var hits := {}
			for e in sim.events:
				var k := str(e.get("type", ""))
				if k == "crash" and e.has("id"):
					wall[str(e["id"])] = float(wall.get(str(e["id"]), 0.0)) + float(e.get("damage", 0.0))
				kinds[k] = int(kinds.get(k, 0)) + 1
				if k == "destroyed":
					deaths.append("%s@%.0f" % [str(e.get("id", e.get("name", "?"))), t])
			for c in sim.cars:
				var d: float = float(hp_prev[c.id]) - c.hp
				if d > 0.0:
					loss["other"] += d
		var fin := 0
		var stuck := []
		for c in sim.cars:
			if c.finished:
				fin += 1
			elif t >= 300.0:
				stuck.append("%s lap%d cp%d at %s cell=%s" % [c.id, c.laps, c.next_cp, c.pos.round(), track.cell(c.pos)])
		if not stuck.is_empty():
			print("PROBE %s STUCK: %s" % [id, stuck])
		var me: CarState = sim.cars.filter(func(c): return c.is_player)[0]
		print("PROBE %s: t=%.0f fin=%d deaths=%s hp_lost=%.0f wall=%s player_hp=%.0f/%.0f dmg_taken=%.2f" % [id, t, fin, deaths, loss["other"], wall, me.hp, me.max_hp, me.damage_taken])
	get_tree().quit()
