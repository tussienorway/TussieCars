class_name App
extends Control

var host: Node
var content: Control
var dialog: Control
var race: RaceView
var pending: Dictionary = {}
var _smoke := false
var party := {}
var party_races := 0
var _net_result := {}
var net: NetManager
var _screen := "main"
var net_name := ""
var net_paint := "cyan"
var net_track := "harbor_loop"
var net_ip := ""
var net_port := 7777
var net_status := ""
var _net_refreshing := false


func bind_host(node: Node) -> void:
	host = node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.make_theme()
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/tracks/harbor_loop.png"):
		bg.texture = load("res://assets/tracks/harbor_loop.png")
		bg.modulate = Color(0.55, 0.6, 0.62)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.09, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	content = MarginContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 28)
	content.add_theme_constant_override("margin_right", 28)
	content.add_theme_constant_override("margin_top", 20)
	content.add_theme_constant_override("margin_bottom", 20)
	add_child(content)
	dialog = Control.new()
	dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.visible = false
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dialog)
	AudioDirector.play_music("music_menu")
	net = NetManager.new()
	add_child(net)
	net.players_changed.connect(_on_net_changed)
	net.discovered.connect(_on_net_discovered)
	net.status_changed.connect(_on_net_status)
	net.race_begin.connect(_on_net_begin)
	net.race_result_received.connect(_on_net_result)
	if str(Game.profile.get("driver", "")) != "":
		net_name = str(Game.profile.get("driver", ""))
	else:
		net_name = "Driver%d" % randi_range(10, 99)
	_load_net_prefs()
	AudioDirector.play_music("music_menu")
	show_main()


func show_main() -> void:
	_screen = "main"
	_fill(func(col):
		var brand := HBoxContainer.new()
		brand.add_theme_constant_override("separation", 0)
		var logo := _logo()
		logo.custom_minimum_size = Vector2(500, 104)
		brand.add_child(logo)
		brand.add_child(CatStage.new(140))
		col.add_child(brand)
		col.add_child(_subtitle("Armed club racing. Original cars, original circuits. Tussie the cat keeps an eye on every start."))
		col.add_child(_button("New Career", show_new_career))
		var cont := _button("Continue", _continue)
		cont.disabled = not Game.has_career()
		col.add_child(cont)
		var champ := _button("Championship", show_championships)
		champ.disabled = not Game.has_career()
		col.add_child(champ)
		var garage := _button("Garage", show_garage)
		garage.disabled = not Game.has_career()
		col.add_child(garage)
		col.add_child(_button("Exhibition", show_exhibition))
		col.add_child(_button("Daily Duel", show_daily))
		col.add_child(_button("Multiplayer", show_multiplayer))
		col.add_child(_button("How to Play", show_help))
		col.add_child(_button("Settings", show_settings))
		col.add_child(_button("Credits", show_credits))
		col.add_child(_button("Quit", _quit))
		col.add_child(_subtitle("Godot 4  ·  v%s" % str(ProjectSettings.get_setting("application/config/version"))))
	)


func show_new_career() -> void:
	_fill(func(col):
		col.add_child(_header("New career"))
		col.add_child(_subtitle("You start in a Sprint Dart with $%d. Three more cars unlock as you climb." % int(Balance.num("starting_money", 2800))))
		var name_box := LineEdit.new()
		name_box.placeholder_text = "Driver name"
		name_box.text = "Alex Rivera"
		name_box.custom_minimum_size = Vector2(0, 48)
		name_box.name = "DriverName"
		col.add_child(name_box)
		var diff := OptionButton.new()
		diff.name = "Difficulty"
		diff.add_item("Rookie — gentler rivals, more prize money")
		diff.add_item("Pro — the intended fight")
		diff.add_item("Ace — faster rivals, higher purses")
		diff.selected = 1
		col.add_child(diff)
		var car := _car_preview("dart", "cyan")
		col.add_child(car)
		col.add_child(_button("Start in the Sprint Dart", func(): _confirm_new(name_box.text, diff.selected)))
		col.add_child(_button("Back", show_main))
	)


func show_championships() -> void:
	if not Game.has_career():
		show_main()
		return
	_fill(func(col):
		col.add_child(_header("Championships"))
		col.add_child(_money_line())
		for spec in Balance.championships:
			var id := str(spec["id"])
			var unlocked := Game.championship_unlocked(id)
			var state := Game.champ_state(id)
			var panel := PanelContainer.new()
			var inner := VBoxContainer.new()
			panel.add_child(inner)
			var title := _label("%s" % spec["name"], 22)
			inner.add_child(title)
			inner.add_child(_subtitle(str(spec.get("blurb", ""))))
			var tracks: Array = spec.get("tracks", [])
			var race_index := int(state.get("race_index", 0))
			var total := tracks.size()
			var done := unlocked and race_index >= total
			if not unlocked:
				inner.add_child(_subtitle("Locked. Finish the previous series in the top 3."))
			else:
				var rank := Game.player_rank(id)
				inner.add_child(_subtitle("Points rank %s   ·   race %d/%d%s" % [str(rank) if rank < 90 else "-", mini(race_index + 1, total), total, "  ·  qualified" if bool(state.get("completed", false)) else ""]))
			if not unlocked:
				pass
			elif done:
				inner.add_child(_button("View standings", _standings_cb(id)))
				inner.add_child(_button("Start a new season", _restart_cb(id)))
			else:
				inner.add_child(_subtitle("Rival: %s  ·  bounty %s" % [Game.rival_name(id), Geom.money(Game.rival_bounty(id))]))
				inner.add_child(_button("Enter next race", _enter_cb(id)))
				inner.add_child(_button("Standings", _standings_cb(id)))
			col.add_child(panel)
		col.add_child(_button("Back", show_main))
	)


func show_briefing(champ_id: String) -> void:
	var track := TrackData.get_track(Game.next_track_id(champ_id))
	if track == null:
		show_championships()
		return
	var fee := Economy.entry_fee(champ_id)
	_fill(func(col):
		col.add_child(_header(track.track_name))
		col.add_child(_subtitle("%s  ·  %d laps  ·  %s" % [track.environment.capitalize(), track.laps, Balance.championship(champ_id).get("name", "")]))
		col.add_child(_money_line())
		col.add_child(_subtitle("Entry %s. Win pays %s." % [Geom.money(fee), Geom.money(Economy.payout(1, champ_id, str(Game.profile.get("difficulty", "pro"))))]))
		var rivals := ""
		for driver in Game.ensure_field(champ_id):
			rivals += str(driver["name"]) + "   "
		col.add_child(_subtitle("Field: " + rivals))
		var rival_line := _subtitle("RIVAL: %s — finish ahead for a %s bounty." % [Game.rival_name(champ_id), Geom.money(Game.rival_bounty(champ_id))])
		rival_line.name = "RivalLine"
		rival_line.add_theme_color_override("font_color", Color("ff5a6a"))
		col.add_child(rival_line)
		var buddy := CheckBox.new()
		buddy.text = "Local co-driver replaces the last rival"
		buddy.name = "Buddy"
		col.add_child(buddy)
		col.add_child(_subtitle("P1 WASD, Space drift, Shift nitro, C missile, X mine, V rear.  P2 IJKL, M drift, N nitro, U missile, O mine, P rear.  Slipstream fills nitro behind a rival."))
		col.add_child(_button("Start race", func(): _start_career(champ_id, buddy.button_pressed)))
		col.add_child(_button("Back", func(): show_championships()))
	)


func show_garage() -> void:
	if not Game.has_career():
		show_main()
		return
	var spec := Game.player_spec()
	_fill(func(col):
		col.add_child(_header("Garage"))
		col.add_child(_money_line())
		col.add_child(_car_preview(str(spec["body"]), str(spec["paint"])))
		col.add_child(_subtitle("%s   HP %d/%d   accel %d   speed %d   grip %0.1f" % [
			Balance.vehicle(str(Game.profile.get("vehicle", ""))).get("name", ""),
			int(Game.profile.get("hp", 0)), int(spec["max_hp"]), int(spec["accel"]), int(spec["max_speed"]), float(spec["grip"])
		]))
		var repair_cost := Economy.repair_cost(float(spec["max_hp"]) - float(Game.profile.get("hp", 0)), Game.upgrade_level("pit"))
		col.add_child(_button("Repair hull  %s" % Geom.money(repair_cost), func():
			if Game.repair_full():
				AudioDirector.play_sfx("buy")
			else:
				AudioDirector.play_sfx("denied")
			show_garage()
		))
		for kind in ["missile", "mine", "rear"]:
			var names := {"missile": "Front missiles", "mine": "Mines", "rear": "Rear missiles"}
			var label := str(names[kind])
			var have := int(Game.profile.get("ammo", {}).get(kind, 0))
			var cap := int(spec.get("cap_%s" % kind, 0))
			var price := int(Balance.num("ammo_price.%s" % kind, 0))
			col.add_child(_button("%s  %d/%d   buy %s" % [label, have, cap, Geom.money(price)], _ammo_cb(kind)))
		for vehicle in Balance.vehicles:
			var id := str(vehicle["id"])
			var owned_list: Array = Game.profile.get("owned", [])
			var owned := owned_list.has(id)
			var text := str(vehicle["name"])
			if owned and id == str(Game.profile.get("vehicle", "")):
				text += "  (selected)"
			elif owned:
				text += "  (owned)"
			else:
				text += "  %s" % Geom.money(int(vehicle["price"]))
			col.add_child(_button(text, _vehicle_cb(id)))
		var ups: Dictionary = Balance.data.get("upgrades", {})
		for upgrade_id in ups.keys():
			var row: Dictionary = ups[upgrade_id]
			var level := Game.upgrade_level(str(upgrade_id))
			var maxed := level >= int(row.get("max", 5))
			var cost := Economy.upgrade_cost(str(upgrade_id), level)
			var text := "%s  %d/%d" % [row.get("label", upgrade_id), level, int(row.get("max", 5))]
			text += "  MAX" if maxed else "  %s" % Geom.money(cost)
			col.add_child(_subtitle(str(row.get("blurb", ""))))
			col.add_child(_button(text, _upgrade_cb(str(upgrade_id))))
		col.add_child(_button("Back", show_main))
	)


func show_exhibition() -> void:
	if not Game.has_career():
		Game.new_career("Guest Driver", "pro", "sprint_dart")
	_fill(func(col):
		col.add_child(_header("Exhibition"))
		col.add_child(_subtitle("A local race. No entry fee and no championship points."))
		var buddy := CheckBox.new()
		buddy.text = "Two players, split screen"
		if not VR.active():
			col.add_child(buddy)
		var wet := CheckBox.new()
		wet.name = "Rain"
		wet.text = "Rain: wet asphalt, less grip"
		col.add_child(wet)
		var ko := CheckBox.new()
		ko.name = "Knockout"
		ko.text = "Knockout: last place is out every 20 s, last car standing wins"
		col.add_child(ko)
		col.add_child(_subtitle("Pick a track:"))
		var grid := GridContainer.new()
		grid.name = "TrackGrid"
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for track in Game.exhibition_tracks():
			var pick := _button("%s  ·  %s" % [track.track_name, track.environment.capitalize()], _exhibit_cb(track.id, buddy, wet, ko))
			pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pick.custom_minimum_size = Vector2(316, 48)
			grid.add_child(pick)
		col.add_child(grid)
		col.add_child(_button("Back", show_main))
	)


func show_daily() -> void:
	_screen = "daily"
	var spec := Game.daily_spec()
	var track := TrackData.get_track(str(spec["track_id"]))
	var best := Game.daily_best(str(spec["key"]))
	var streak := Game.daily_streak()
	_fill(func(col):
		col.add_child(_header("Daily Duel"))
		col.add_child(_subtitle("One fresh race every day. Beat your ghost, keep the streak alive."))
		col.add_child(_label(str(spec["key"]), 16))
		col.add_child(_subtitle(str(track.track_name) if track != null else str(spec["track_id"])))
		col.add_child(_subtitle(Game.daily_mutator_blurb(str(spec["mutator"]))))
		if best.is_empty():
			col.add_child(_subtitle("No time set today. The track is yours."))
		else:
			col.add_child(_subtitle("Today's best: %s. Beat it." % Geom.clock(float(best.get("time", 0.0)))))
		var count := int(streak.get("count", 0))
		if count > 0:
			col.add_child(_subtitle("Streak: %d day%s" % [count, "" if count == 1 else "s"]))
		col.add_child(_button("Race today's duel", _daily_start_cb(spec)))
		col.add_child(_button("Back", show_main))
	)


func _daily_start_cb(spec: Dictionary) -> Callable:
	return func():
		var tier := Game.top_tier()
		var roster := Game.apply_daily_mutator(Game.build_roster(tier, false), str(spec["mutator"]))
		var best := Game.daily_best(str(spec["key"]))
		_launch({
			"track_id": str(spec["track_id"]),
			"mode": "daily",
			"champ_id": "",
			"two_player": false,
			"assist": true,
			"difficulty": str(Game.profile.get("difficulty", "pro")),
			"tier": tier,
			"fee_paid": 0,
			"daily": true,
			"daily_key": str(spec["key"]),
			"ghost": best.get("ghost", []),
			"force_night": str(spec["mutator"]) == "night",
			"weather": "rain" if str(spec["mutator"]) == "monsoon" else "clear",
			"roster": roster,
		})


func show_multiplayer() -> void:
	_screen = "multiplayer"
	if net == null:
		show_main()
		return
	if net.role == "idle":
		net.start_listening()
	_fill(func(col):
		col.add_child(_header("Multiplayer"))
		col.add_child(_subtitle("Same WiFi, zero setup: the host taps once, everyone else taps the lobby name. Up to 4 drivers."))
		col.add_child(_subtitle("1) Host starts a lobby.  2) Friends open Multiplayer on the same WiFi.  3) Tap the lobby, race."))
		col.add_child(_subtitle("Every race in a session scores Party Grand Prix points (15-12-10-8). Keep rematching to crown a champion."))
		_party_block(col)
		var name_box := LineEdit.new()
		name_box.placeholder_text = "Driver name"
		name_box.text = net_name
		name_box.custom_minimum_size = Vector2(0, 48)
		name_box.text_changed.connect(func(t):
			net_name = t
			_save_net_prefs()
		)
		col.add_child(name_box)
		var paints := NetDefs.PAINTS
		var paint_opt := OptionButton.new()
		for paint in paints:
			paint_opt.add_item(paint.capitalize())
		paint_opt.selected = maxi(0, paints.find(net_paint))
		paint_opt.item_selected.connect(func(idx):
			net_paint = paints[idx]
			_save_net_prefs()
		)
		col.add_child(paint_opt)
		var tracks := TrackData.all_tracks()
		tracks.sort_custom(func(a, b): return a.track_name < b.track_name)
		var track_opt := OptionButton.new()
		var track_ids := []
		for track in tracks:
			track_opt.add_item(track.track_name)
			track_ids.append(track.id)
		var sel := maxi(0, track_ids.find(net_track if net.role == "idle" else net.track_id))
		track_opt.selected = sel
		track_opt.disabled = net.role != "idle" and net.role != "host"
		track_opt.item_selected.connect(func(idx):
			net_track = track_ids[idx]
			if net.role == "host":
				net.set_track(net_track)
		)
		col.add_child(track_opt)
		var port_box := LineEdit.new()
		port_box.placeholder_text = "Port (default 7777)"
		port_box.text = str(net_port)
		port_box.custom_minimum_size = Vector2(0, 48)
		port_box.text_changed.connect(func(t):
			net_port = clampi(int(t) if t.is_valid_int() else 7777, 1024, 65535)
			_save_net_prefs()
		)
		col.add_child(port_box)
		if net.role == "idle":
			col.add_child(_button("QUICK HOST — one tap race", _net_quick_host_cb()))
			col.add_child(_button("Host with options below", _net_host_cb()))
			var ip_box := LineEdit.new()
			ip_box.placeholder_text = "Host IP for manual join, e.g. 192.168.1.20"
			ip_box.text = net_ip
			ip_box.custom_minimum_size = Vector2(0, 48)
			ip_box.text_changed.connect(func(t): net_ip = t.strip_edges())
			col.add_child(ip_box)
			col.add_child(_button("Join by IP", _net_join_cb()))
			var ips := net.local_ips()
			if not ips.is_empty():
				col.add_child(_subtitle("This device: " + "   ".join(ips)))
			if net.discovered_hosts.is_empty():
				col.add_child(_subtitle("Searching WiFi for lobbies ..."))
				col.add_child(_button("Rescan", _net_rescan_cb()))
			else:
				col.add_child(_subtitle("Tap a lobby to join (%d found):" % net.discovered_hosts.size()))
				for found in net.discovered_hosts:
					var label := "JOIN  %s  ·  %s  ·  %d/4" % [str(found.get("name", "Host")), _track_name(str(found.get("track", ""))), int(found.get("humans", 1))]
					col.add_child(_button(label, _net_found_cb(found)))
				col.add_child(_button("Rescan", _net_rescan_cb()))
		else:
			col.add_child(_subtitle("Players (%d/4):" % net.players.size()))
			for p in net.players:
				var who := "%s  ·  %s%s" % [str(p.get("name", "?")), str(p.get("paint", "")), "  (you)" if int(p.get("peer_id", -1)) == multiplayer.get_unique_id() else ""]
				col.add_child(_label(who, 14))
			col.add_child(_subtitle("Track: %s" % _track_name(net.track_id)))
			if net.role == "host":
				var ips := net.local_ips()
				if not ips.is_empty():
					col.add_child(_subtitle("Friends join with no IP: same WiFi, open Multiplayer, tap this lobby. Manual IP: " + "   ".join(ips)))
				var start := _button("Start race (%d/4)" % net.players.size(), _net_start_cb())
				start.disabled = net.players.size() < 2
				col.add_child(start)
			elif net.role == "client_connecting":
				col.add_child(_subtitle("Connecting ..."))
			else:
				col.add_child(_subtitle("Waiting for the host to start."))
			col.add_child(_button("Leave", _net_leave_cb()))
		if net_status != "":
			col.add_child(_subtitle(net_status))
		col.add_child(_button("Back", _net_back_cb()))
	)


func _track_name(track_id: String) -> String:
	var track := TrackData.get_track(track_id)
	if track == null:
		return track_id
	return track.track_name


func _on_net_changed() -> void:
	if _screen == "multiplayer" and race == null and not _net_refreshing:
		_net_refreshing = true
		show_multiplayer()
		_net_refreshing = false


func _on_net_discovered(_hosts: Array) -> void:
	_on_net_changed()


func _on_net_status(text: String) -> void:
	net_status = text
	_on_net_changed()


func _on_net_begin(config: Dictionary) -> void:
	_launch_net(config)


func _on_net_result(result: Dictionary) -> void:
	_net_result = result


const PARTY_POINTS := [15, 12, 10, 8, 6, 4]


func party_score(race_result: Dictionary) -> void:
	var humans := []
	for row in race_result.get("standings", []):
		if bool(row.get("is_player", false)):
			humans.append(row)
	if humans.size() < 2:
		return
	humans.sort_custom(func(a, b): return int(a.get("position", 99)) < int(b.get("position", 99)))
	for i in humans.size():
		var row: Dictionary = humans[i]
		var who := str(row.get("name", "Driver"))
		var entry: Dictionary = party.get(who, {"points": 0, "wins": 0, "races": 0})
		var pts: int = PARTY_POINTS[mini(i, PARTY_POINTS.size() - 1)]
		if bool(row.get("dnf", false)) and not bool(row.get("knocked", false)):
			pts = 1
		entry["points"] = int(entry["points"]) + pts
		entry["races"] = int(entry["races"]) + 1
		if i == 0:
			entry["wins"] = int(entry["wins"]) + 1
		party[who] = entry
	party_races += 1


func party_table() -> Array:
	var rows := []
	for who in party.keys():
		var e: Dictionary = party[who]
		rows.append({"name": who, "points": int(e["points"]), "wins": int(e["wins"])})
	rows.sort_custom(func(a, b): return a["points"] > b["points"] or (a["points"] == b["points"] and a["wins"] > b["wins"]))
	return rows


func party_reset() -> void:
	party.clear()
	party_races = 0


func _party_block(col: VBoxContainer) -> void:
	if party_races <= 0:
		return
	col.add_child(_label("PARTY GRAND PRIX — %d race%s" % [party_races, "" if party_races == 1 else "s"], 16))
	var rank := 1
	for row in party_table():
		var crown := "  ★" if rank == 1 else ""
		col.add_child(_label("%d  %s  %d pts  (%d win%s)%s" % [rank, row["name"], row["points"], row["wins"], "" if row["wins"] == 1 else "s", crown], 14))
		rank += 1


func _net_host_cb() -> Callable:
	return func():
		net_name = NetDefs.clean_player_name(net_name)
		_save_net_prefs()
		var err := net.host_lobby(net_name, net_paint, net_track, net_port)
		net_status = err
		show_multiplayer()


func _net_quick_host_cb() -> Callable:
	return func():
		net_name = NetDefs.clean_player_name(net_name)
		_save_net_prefs()
		var err := net.host_lobby(net_name, net_paint, net_track, net_port)
		if err == "":
			net_status = "Lobby live! Friends: same WiFi, open Multiplayer, tap this race."
		else:
			net_status = err
		show_multiplayer()


func _net_rescan_cb() -> Callable:
	return func():
		net.discovered_hosts.clear()
		net.stop_discovery()
		net.start_listening()
		net_status = "Scanning WiFi for lobbies ..."
		show_multiplayer()


func _save_net_prefs() -> void:
	Settings.data["net_name"] = NetDefs.clean_player_name(net_name)
	Settings.data["net_paint"] = NetDefs.clean_paint(net_paint)
	Settings.data["net_port"] = net_port
	Settings.data["net_track"] = net_track
	Settings.save_settings()


func _load_net_prefs() -> void:
	var saved := str(Settings.data.get("net_name", ""))
	if saved != "":
		net_name = saved
	net_paint = NetDefs.clean_paint(str(Settings.data.get("net_paint", net_paint)))
	net_port = clampi(int(Settings.data.get("net_port", net_port)), 1024, 65535)
	var saved_track := str(Settings.data.get("net_track", ""))
	if saved_track != "" and TrackData.get_track(saved_track) != null:
		net_track = saved_track


func _net_join_cb() -> Callable:
	return func():
		_save_net_prefs()
		var err := net.join_lobby(net_ip, net_port, net_name, net_paint)
		net_status = err
		show_multiplayer()


func _net_found_cb(found: Dictionary) -> Callable:
	return func():
		net_ip = str(found.get("ip", ""))
		net_port = int(found.get("port", 7777))
		_save_net_prefs()
		var err := net.join_lobby(net_ip, net_port, net_name, net_paint)
		net_status = err
		show_multiplayer()


func _net_start_cb() -> Callable:
	return func():
		net.begin_net_race()


func _net_leave_cb() -> Callable:
	return func():
		net.reset()
		net_status = ""
		show_multiplayer()


func _net_back_cb() -> Callable:
	return func():
		if net.role == "idle":
			net.stop_discovery()
			show_main()
		else:
			show_multiplayer()


func _launch_net(config: Dictionary) -> void:
	_screen = "race"
	var humans: Array = config.get("humans", [])
	var roster := Game.build_net_roster(humans, "club")
	var my_id := multiplayer.get_unique_id()
	var my_index := 0
	for h in humans:
		if int(h.get("peer_id", -1)) == my_id:
			my_index = int(h.get("index", 0))
	var role := "host" if net.is_host() else "client"
	_launch({
		"track_id": str(config.get("track_id", "harbor_loop")),
		"mode": "net",
		"champ_id": "",
		"two_player": false,
		"assist": false,
		"difficulty": str(config.get("difficulty", "pro")),
		"tier": str(config.get("tier", "club")),
		"fee_paid": 0,
		"time_limit": 240.0,
		"roster": roster,
		"net_role": role,
		"net_index": my_index,
		"net": net,
	})


func show_settings() -> void:
	_fill(func(col):
		col.add_child(_header("Settings"))
		col.add_child(_slider("Master", "master"))
		col.add_child(_slider("Music", "music"))
		col.add_child(_slider("Effects", "sfx"))
		var full := CheckBox.new()
		full.text = "Fullscreen"
		full.button_pressed = bool(Settings.data.get("fullscreen", false))
		full.toggled.connect(func(on):
			Settings.data["fullscreen"] = on
			Settings.apply_window()
			Settings.save_settings()
		)
		col.add_child(full)
		var shake := CheckBox.new()
		shake.text = "Screen shake"
		shake.button_pressed = bool(Settings.data.get("shake", true))
		shake.toggled.connect(func(on):
			Settings.data["shake"] = on
			Settings.save_settings()
		)
		col.add_child(shake)
		if VR.active():
			var view := OptionButton.new()
			view.name = "VrView"
			view.add_item("VR camera: chase (comfortable)")
			view.add_item("VR camera: cockpit (intense)")
			view.selected = 1 if VR.view_mode() == "cockpit" else 0
			view.item_selected.connect(func(idx):
				Settings.data["vr_view"] = ["chase", "cockpit"][idx]
				Settings.save_settings()
			)
			col.add_child(view)
		var touch := OptionButton.new()
		touch.add_item("Touch controls: auto")
		touch.add_item("Touch controls: on")
		touch.add_item("Touch controls: off")
		var mode := str(Settings.data.get("touch", "auto"))
		touch.selected = 0 if mode == "auto" else (1 if mode == "on" else 2)
		touch.item_selected.connect(func(idx):
			Settings.data["touch"] = ["auto", "on", "off"][idx]
			Settings.save_settings()
		)
		col.add_child(touch)
		col.add_child(_subtitle("Click a binding, then press a key. Gamepad buttons stay fixed."))
		for action in Settings.DEFAULTS.keys():
			col.add_child(_button("%s   %s" % [action, Settings.key_label(action)], _rebind_cb(action)))
		col.add_child(_button("Back", show_main))
	)


const HELP := [
	["Goal", "Finish ahead of the field. Most circuits are three laps; the lap counter in the HUD shows how many. Pass every checkpoint in order. Shortcuts do not count, and a red WRONG WAY means turn around."],
	["Keyboard", "W or Up accelerates, S or Down brakes and reverses, A D or the arrows steer. Space drifts, Shift fires nitro, C launches a front missile, X drops a mine, V fires a rear missile, and Esc pauses. Rebind keys in Settings."],
	["Gamepad", "Right trigger accelerates, left trigger brakes, and the left stick steers. Y is nitro, clicking the left stick drifts, RB fires missiles, LB drops mines, X fires rear missiles, and Start pauses."],
	["Touch", "Phones show a steering pad on the left and pedals and weapon buttons on the right. Hold ACCEL, slide your thumb on the pad to steer, and use BRAKE, BOOST, DRIFT, FIRE, MINE, and REAR."],
	["VR", "Right trigger is gas, left trigger is brake, and either stick steers. A is nitro, B is drift, right grip fires a missile, left grip drops a mine, and X fires a rear missile. Y switches between chase and roof camera, and Menu pauses. In menus, point and pull the trigger. Hold the Meta button to recenter."],
	["Nitro, drift, and slipstream", "Drift through corners to fill the yellow nitro bar, or sit right behind another car to fill it from the slipstream. Boost pads on the road launch you forward, and cyan pickups top the tank up. Spend it on the straights."],
	["Weapons and pickups", "Orange crates add missiles, red crates add mines, green crates repair the hull, and cyan crates add nitro. Missiles fly straight ahead, rear missiles cover your tail, and mines sit where you drop them."],
	["Damage", "The guard rails are solid. Hitting them at speed costs hull, and scraping along them wears it down. At zero HP the car is wrecked and earns nothing. Oil slides, water and sand slow you down, and grass and walls stop you."],
	["Career", "Start in the Sprint Dart with $2,800. Pay the entry fee, race for prize money and points, and finish a series in the top 3 to unlock the next one: Club Cup, National Series, Turbo Championship, and Masters Cup. Beat your named rival for a bounty. Spend winnings in the Garage on engine, top speed, brakes, tires, armor, hull, weapons, and new cars."],
	["Other modes", "Exhibition races any of the 16 circuits with no fee, with optional rain, knockout, and two-player split screen. Daily Duel is one seeded race a day against your own ghost. Multiplayer hosts or joins a race on the same WiFi with one tap, for up to 4 drivers."],
	["Tips", "Brake before the corner, not in it. Save a missile for the last straight. Repair in the Garage between races, because damage carries over. Tussie sits by every start grid and cheers you on."],
]


func show_help() -> void:
	_fill(func(col):
		col.add_child(_header("How to Play"))
		var order: Array = HELP.duplicate()
		var lead := "VR" if VR.active() else ("Touch" if Settings.touch_active() else "")
		for i in order.size():
			if str(order[i][0]) == lead:
				var entry: Array = order[i]
				order.remove_at(i)
				order.insert(1, entry)
				break
		for entry in order:
			var title := _label(str(entry[0]), 16)
			title.add_theme_color_override("font_color", Color("ffb000"))
			col.add_child(title)
			col.add_child(_subtitle(str(entry[1])))
		col.add_child(_button("Back", show_main))
	)


func show_credits() -> void:
	_fill(func(col):
		col.add_child(_header("Credits"))
		col.add_child(CatStage.new(160))
		col.add_child(_subtitle("Mascot: Tussie, a red-and-white long-haired cat and the real pet behind the name. Watches every start from the grass by the grid."))
		col.add_child(_subtitle("TussieCars is an original top-down combat racer."))
		col.add_child(_subtitle("It borrows the spirit of 1991 arcade racing — fast cars, prize money, and weapons — and none of that game's art, audio, names, or track layouts."))
		col.add_child(_subtitle("Cars, circuits, effects, and music in this build were generated for the project."))
		col.add_child(_subtitle("Typeface: Silkscreen by Jason Kottke, used under the SIL Open Font License."))
		col.add_child(_subtitle("Engine: Godot 4."))
		col.add_child(_button("Back", show_main))
	)


func show_standings(champ_id: String) -> void:
	_fill(func(col):
		col.add_child(_header(str(Balance.championship(champ_id).get("name", "Standings"))))
		for row in Game.standings(champ_id):
			col.add_child(_label("%d. %s    %d pts" % [int(row["rank"]), row["name"], int(row["points"])], 16))
		if Game.standings(champ_id).is_empty():
			col.add_child(_subtitle("No points yet. The season starts when you take the first grid."))
		col.add_child(_button("Back", show_championships))
	)


func show_results(race_result: Dictionary, summary: Dictionary) -> void:
	_fill(func(col):
		var player: Dictionary = race_result.get("player", {})
		var dnf := bool(player.get("dnf", false)) and not bool(player.get("knocked", false))
		col.add_child(_title("DNF" if dnf else Geom.ordinal(int(player.get("position", 0)))))
		col.add_child(_subtitle(str(race_result.get("track_name", ""))))
		var pay: Dictionary = summary.get("pay", {})
		if str(race_result.get("mode", "")) == "net":
			col.add_child(_subtitle("Online race. No purse, no points — just glory."))
		elif str(race_result.get("mode", "")) == "daily":
			var daily: Dictionary = summary.get("daily", {})
			var line := "Daily Duel %s — %s" % [str(daily.get("key", "")), Geom.clock(float(daily.get("time", 0.0)))]
			col.add_child(_subtitle(line))
			if bool(daily.get("new_best", false)):
				col.add_child(_subtitle("New best today! Streak: %d day%s." % [int(daily.get("streak", 0)), "" if int(daily.get("streak", 0)) == 1 else "s"]))
			elif not dnf:
				col.add_child(_subtitle("Ghost unbeaten. Streak kept at %d. One more try?" % int(daily.get("streak", 0))))
			if int(daily.get("purse", 0)) > 0:
				col.add_child(_subtitle("Purse %s (streak bonus included)." % Geom.money(int(daily.get("purse", 0)))))
		elif str(race_result.get("mode", "")) == "career":
			col.add_child(_subtitle("Prize %s   fee %s   net %s   season points %d" % [
				Geom.money(int(pay.get("prize", 0))),
				Geom.money(int(pay.get("fee", 0))),
				Geom.money(int(pay.get("net", 0))),
				int(pay.get("points", 0)),
			]))
			var rival: Dictionary = summary.get("rival", {})
			if str(rival.get("name", "")) != "":
				var verdict := "Rival %s beaten! Bounty %s." % [rival["name"], Geom.money(int(rival.get("bounty", 0)))] if bool(rival.get("beaten", false)) else "%s got the better of you this time." % rival["name"]
				var rival_note := _subtitle(verdict)
				rival_note.name = "RivalVerdict"
				rival_note.add_theme_color_override("font_color", Color("ffd23f") if bool(rival.get("beaten", false)) else Color("ff5a6a"))
				col.add_child(rival_note)
			if str(summary.get("note", "")) != "":
				col.add_child(_subtitle(str(summary["note"])))
			if bool(summary.get("season_over", false)):
				if bool(summary.get("advanced", false)):
					col.add_child(_subtitle("Season complete. A top-three finish opens the next series."))
				else:
					col.add_child(_subtitle("Season complete. A top-three finish is required to move up. You can run the series again."))
		elif bool(pending.get("knockout", false)):
			col.add_child(_subtitle("Knockout. Last car standing takes it — no purse, just bragging rights."))
		else:
			col.add_child(_subtitle("Exhibition. Purse unchanged."))
		for row in race_result.get("standings", []):
			var tag := "DNF" if bool(row.get("dnf", false)) else Geom.clock(float(row.get("time", 0.0)))
			if bool(row.get("knocked", false)):
				tag = "OUT"
			col.add_child(_label("%d  %s  %s" % [int(row.get("position", 0)), row.get("name", ""), tag], 14))
		if str(race_result.get("mode", "")) == "net" or bool(race_result.get("two_player", false)):
			_party_block(col)
		col.add_child(_money_line())
		if str(race_result.get("mode", "")) == "career":
			col.add_child(_button("Garage", show_garage))
			col.add_child(_button("Championship", show_championships))
			col.add_child(_button("Main menu", show_main))
		elif str(race_result.get("mode", "")) == "net":
			col.add_child(_button("Back to lobby", show_multiplayer))
			col.add_child(_button("Main menu", _net_quit_cb()))
		elif str(race_result.get("mode", "")) == "daily":
			col.add_child(_button("Race again", show_daily))
			col.add_child(_button("Main menu", show_main))
		else:
			col.add_child(_button("Main menu", show_main))
	)


func start_smoke() -> void:
	_smoke = true
	if not Game.has_career():
		Game.new_career("Smoke", "pro", "sprint_dart")
	var smoke_track := "harbor_loop"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--smoke-track="):
			smoke_track = str(arg).get_slice("=", 1)
	show_main()
	await get_tree().create_timer(0.45).timeout
	await _capture("menu")
	show_championships()
	await get_tree().create_timer(0.3).timeout
	await _capture("championship")
	show_garage()
	await get_tree().create_timer(0.3).timeout
	await _capture("garage")
	show_settings()
	await get_tree().create_timer(0.3).timeout
	await _capture("settings")
	show_exhibition()
	await get_tree().create_timer(0.3).timeout
	await _capture("exhibition")
	show_help()
	await get_tree().create_timer(0.3).timeout
	await _capture("help")
	_launch({
		"track_id": smoke_track,
		"mode": "exhibition",
		"champ_id": "",
		"two_player": false,
		"assist": true,
		"difficulty": "pro",
		"tier": "club",
		"fee_paid": 0,
		"time_limit": 45.0,
		"rival_id": Game.rival_id("club"),
		"rival_bounty": Game.rival_bounty("club"),
		"roster": Game.build_roster("club", false),
	})
	await get_tree().create_timer(1.1).timeout
	await _capture("race")
	if race != null and is_instance_valid(race) and race.cat_node != null:
		get_tree().paused = true
		var kitty: Node3D = race.cat_node
		var eye := kitty.to_global(Vector3(0.9, 1.0, 2.4))
		race.cam.global_transform = Transform3D(Basis.looking_at(kitty.to_global(Vector3(0, 0.5, 0)) - eye, Vector3.UP), eye)
		race.cam.fov = 45.0
		await get_tree().create_timer(0.3, true).timeout
		await _capture("cat")
		get_tree().paused = false
	await get_tree().create_timer(8.0).timeout
	await _capture("race_mid")
	if race != null and is_instance_valid(race):
		var pilot := race._human(0)
		if pilot != null:
			pilot.boost = 1.0
			pilot.boosting = false
		race.config["assist"] = false
		race.config["demo_boost"] = true
		await get_tree().create_timer(0.45).timeout
		await _capture("race_boost")
		race.queue_free()
		race = null
	visible = true
	_launch({
		"track_id": "test_oval",
		"mode": "exhibition",
		"champ_id": "",
		"two_player": true,
		"assist": true,
		"difficulty": "pro",
		"tier": "club",
		"fee_paid": 0,
		"time_limit": 20.0,
		"roster": Game.build_roster("club", true),
	})
	await get_tree().create_timer(2.2).timeout
	await _capture("split")
	if race != null and is_instance_valid(race):
		race.queue_free()
		race = null
	_launch({
		"track_id": smoke_track,
		"mode": "exhibition",
		"champ_id": "",
		"two_player": false,
		"assist": true,
		"difficulty": "pro",
		"tier": "club",
		"fee_paid": 0,
		"time_limit": 30.0,
		"weather": "rain",
		"roster": Game.build_roster("club", false),
	})
	await get_tree().create_timer(5.5).timeout
	await _capture("rain")
	if race != null and is_instance_valid(race):
		var winner := race._human(0)
		if winner != null:
			winner.finished = true
			winner.finish_time = race.sim.race_time
		await get_tree().create_timer(1.6).timeout
		await _capture("finish")
		await get_tree().create_timer(3.4).timeout
		await _capture("podium")
	if race != null and is_instance_valid(race):
		race.queue_free()
		race = null
	_launch({
		"track_id": smoke_track,
		"mode": "exhibition",
		"champ_id": "",
		"two_player": false,
		"assist": true,
		"difficulty": "pro",
		"tier": "club",
		"fee_paid": 0,
		"knockout": true,
		"roster": Game.build_roster("club", false),
	})
	await get_tree().create_timer(5.0).timeout
	if race != null and is_instance_valid(race):
		race.sim.next_knock = race.sim.race_time + 0.3
	await get_tree().create_timer(0.8).timeout
	await _capture("knockout")
	get_tree().quit(0)


func _confirm_new(driver_name: String, diff_index: int) -> void:
	var diffs := ["rookie", "pro", "ace"]
	var start := func():
		Game.new_career(driver_name, diffs[diff_index], "sprint_dart")
		AudioDirector.play_sfx("buy")
		show_championships()
	if Game.has_career():
		_ask("Replace the saved career?", "The current garage, money, and standings will be overwritten.", start)
	else:
		start.call()


func _continue() -> void:
	if Game.load_career():
		show_championships()
	else:
		show_main()


func _start_career(champ_id: String, two_player: bool) -> void:
	var entry := Game.begin_entry(champ_id)
	var roster := Game.build_roster(champ_id, two_player)
	_launch({
		"track_id": Game.next_track_id(champ_id),
		"mode": "career",
		"champ_id": champ_id,
		"two_player": two_player,
		"assist": false,
		"difficulty": str(Game.profile.get("difficulty", "pro")),
		"tier": champ_id,
		"fee_paid": int(entry.get("fee", 0)),
		"note": str(entry.get("note", "")),
		"rival_id": Game.rival_id(champ_id),
		"rival_bounty": Game.rival_bounty(champ_id),
		"roster": roster,
	})


func _launch(config: Dictionary) -> void:
	if host == null:
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	race = RaceView.new()
	host.add_child(race)
	race.race_over.connect(_on_race_over)
	race.setup(config)
	pending = config


func _on_race_over(race_result: Dictionary) -> void:
	var ghost_rec: Array = []
	if race != null and is_instance_valid(race) and str(race_result.get("mode", "")) == "daily":
		ghost_rec = (race as RaceView).ghost_rec.duplicate()
	if race != null and is_instance_valid(race):
		race.queue_free()
	race = null
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	AudioDirector.play_music("music_menu")
	var summary := {}
	if str(race_result.get("mode", "")) == "career" and Game.has_career():
		summary = Game.apply_result(str(race_result.get("champ_id", "")), race_result, int(race_result.get("fee_paid", 0)))
		summary["note"] = str(pending.get("note", ""))
	elif str(race_result.get("mode", "")) == "daily":
		var daily := Game.save_daily_result(str(pending.get("daily_key", Game.daily_key())), race_result, ghost_rec)
		daily["key"] = str(pending.get("daily_key", Game.daily_key()))
		var bonus := 0
		if Game.has_career():
			var player: Dictionary = race_result.get("player", {})
			var purse := Economy.payout(int(player.get("position", 6)), "club", str(Game.profile.get("difficulty", "pro")))
			bonus = purse + mini(int(daily.get("streak", 0)), 7) * 100
			Game.profile["money"] = int(Game.profile.get("money", 0)) + bonus
			Game.save_career()
		daily["purse"] = bonus
		summary["daily"] = daily
	if str(race_result.get("mode", "")) == "net":
		var authoritative: Dictionary = _net_result if not _net_result.is_empty() else race_result
		party_score(authoritative)
		_net_result = {}
	elif bool(race_result.get("two_player", false)) and str(race_result.get("mode", "")) == "exhibition":
		party_score(race_result)
	if _smoke:
		return
	if str(race_result.get("mode", "")) == "net" and net != null:
		net.back_to_lobby()
		_screen = "multiplayer"
	show_results(race_result, summary)


func _net_quit_cb() -> Callable:
	return func():
		if net != null:
			net.reset()
			net_status = ""
		party_reset()
		show_main()


func _fill(builder: Callable) -> void:
	_clear(content)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	content.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(640, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	center.add_child(col)
	builder.call(col)
	var buttons := _buttons(col)
	if not buttons.is_empty():
		buttons[0].grab_focus()


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()


func _title(text: String) -> Label:
	return _label(text, 42)


func _logo() -> Control:
	if not ResourceLoader.exists("res://assets/sprites/logo.png"):
		return _title("TUSSIECARS")
	var rect := TextureRect.new()
	rect.name = "Logo"
	rect.texture = load("res://assets/sprites/logo.png")
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.custom_minimum_size = Vector2(620, 104)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect


func _header(text: String) -> Label:
	return _label(text, 28)


func _subtitle(text: String) -> Label:
	var label := _label(text, 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("c8c0b0"))
	label.custom_minimum_size = Vector2(620, 0)
	return label


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiKit.font())
	label.add_theme_font_size_override("font_size", size)
	return label


func _money_line() -> Label:
	return _subtitle("%s  ·  %s  ·  %s" % [
		str(Game.profile.get("driver", "")),
		Geom.money(Game.money()),
		str(Balance.dict_at("difficulties.%s" % str(Game.profile.get("difficulty", "pro"))).get("label", "")),
	])


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(func():
		AudioDirector.play_sfx("ui_click", 1.0, 0.5)
		callback.call_deferred()
	)
	return button


func _car_preview(body: String, paint: String) -> TextureRect:
	var rect := TextureRect.new()
	var path := "res://assets/sprites/cars/%s_%s.png" % [body, paint]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(0, 0, 48, 48)
		rect.texture = atlas
	rect.custom_minimum_size = Vector2(96, 96)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect


func _slider(label_text: String, key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	var label := _label("%s  %d" % [label_text, int(float(Settings.data.get(key, 0.5)) * 100.0)], 14)
	box.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = float(Settings.data.get(key, 0.5)) * 100.0
	slider.custom_minimum_size = Vector2(0, 32)
	slider.value_changed.connect(func(v):
		Settings.data[key] = float(v) / 100.0
		label.text = "%s  %d" % [label_text, int(v)]
		Settings.apply_audio()
		Settings.save_settings()
	)
	box.add_child(slider)
	return box


func _ask(title: String, body: String, on_yes: Callable) -> void:
	_clear(dialog)
	dialog.visible = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(480, 200)
	panel.position = Vector2(-240, -100)
	dialog.add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	col.add_child(_header(title))
	col.add_child(_subtitle(body))
	col.add_child(_button("Confirm", func():
		dialog.visible = false
		on_yes.call()
	))
	col.add_child(_button("Cancel", func(): dialog.visible = false))


func _enter_cb(champ_id: String) -> Callable:
	return func(): show_briefing(champ_id)


func _standings_cb(champ_id: String) -> Callable:
	return func(): show_standings(champ_id)


func _restart_cb(champ_id: String) -> Callable:
	return func():
		Game.restart_season(champ_id)
		show_championships()


func _upgrade_cb(upgrade_id: String) -> Callable:
	return func():
		if Game.buy_upgrade(upgrade_id):
			AudioDirector.play_sfx("buy")
		else:
			AudioDirector.play_sfx("denied")
		show_garage()


func _ammo_cb(kind: String) -> Callable:
	return func():
		if Game.buy_ammo(kind):
			AudioDirector.play_sfx("buy")
		else:
			AudioDirector.play_sfx("denied")
		show_garage()


func _vehicle_cb(vehicle_id: String) -> Callable:
	return func():
		if vehicle_id in Game.profile.get("owned", []):
			Game.select_vehicle(vehicle_id)
			AudioDirector.play_sfx("ui_click")
		elif Game.buy_vehicle(vehicle_id):
			AudioDirector.play_sfx("buy")
		else:
			AudioDirector.play_sfx("denied")
		show_garage()


func _exhibit_cb(track_id: String, buddy: CheckBox, wet: CheckBox = null, ko: CheckBox = null) -> Callable:
	return func():
		var tier := "club"
		for champ in Balance.championships:
			if track_id in champ.get("tracks", []) and Game.championship_unlocked(str(champ["id"])):
				tier = str(champ["id"])
		_launch({
			"track_id": track_id,
			"mode": "exhibition",
			"champ_id": "",
			"two_player": buddy.button_pressed,
			"assist": false,
			"difficulty": str(Game.profile.get("difficulty", "pro")),
			"tier": tier,
			"fee_paid": 0,
			"weather": "rain" if wet != null and wet.button_pressed else "clear",
			"knockout": ko != null and ko.button_pressed,
			"roster": Game.build_roster(tier, buddy.button_pressed),
		})


func _rebind_cb(action: String) -> Callable:
	return func():
		Settings.listening = action
		_ask("Rebind %s" % action, "Press a key. Escape cancels.", func(): pass)
		set_process_unhandled_input(true)


func _input(event: InputEvent) -> void:
	if Settings.listening == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != KEY_ESCAPE:
			Settings.set_bind(Settings.listening, event.physical_keycode)
			AudioDirector.play_sfx("ui_click")
		Settings.listening = ""
		dialog.visible = false
		show_settings()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if Settings.listening != "":
		return
	if event.is_action_pressed("ui_cancel") and dialog.visible:
		dialog.visible = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and race == null and visible:
		show_main()
		get_viewport().set_input_as_handled()


func _quit() -> void:
	_ask("Leave the pits?", "Unsaved setting tweaks are already stored.", func(): get_tree().quit())


func _buttons(node: Node) -> Array:
	var found := []
	for child in node.get_children():
		if child is Button and not child.disabled:
			found.append(child)
		found.append_array(_buttons(child))
	return found


func start_vr_smoke() -> void:
	_smoke = true
	if not Game.has_career():
		Game.new_career("Smoke", "pro", "sprint_dart")
	show_main()
	await get_tree().create_timer(0.8).timeout
	await _capture("vr_lobby", true)
	show_settings()
	await get_tree().create_timer(0.4).timeout
	await _capture("vr_settings", true)
	Settings.data["vr_view"] = "chase"
	_launch({
		"track_id": "harbor_loop",
		"mode": "exhibition",
		"champ_id": "",
		"two_player": false,
		"assist": true,
		"difficulty": "pro",
		"tier": "club",
		"fee_paid": 0,
		"time_limit": 40.0,
		"roster": Game.build_roster("club", false),
	})
	await get_tree().create_timer(6.0).timeout
	await _capture("vr_race", true)
	if race != null and is_instance_valid(race):
		race._on_vr_button("by_button", false)
		await get_tree().create_timer(1.5).timeout
		await _capture("vr_cockpit", true)
		race._toggle_pause()
		await get_tree().create_timer(0.5, true).timeout
		await _capture("vr_pause", true)
		race._toggle_pause()
		Settings.data["vr_view"] = "chase"
		race._quit_race()
	await get_tree().create_timer(1.0).timeout
	await _capture("vr_back", true)
	get_tree().quit(0)


func _capture(shot_name: String, whole: bool = false) -> void:
	await RenderingServer.frame_post_draw
	var source := get_tree().root if whole else get_viewport()
	var image := source.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/tmp/turbo_smoke")
	image.save_png("/tmp/turbo_smoke/%s.png" % shot_name)
