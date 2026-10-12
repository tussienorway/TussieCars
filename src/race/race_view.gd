class_name RaceView
extends Node3D

signal race_over(result: Dictionary)

# 3D presentation over the 2D RaceSim. Sim X/Y maps to world X/Z,
# car heading h maps to rotation.y = -h (car meshes face +X).

var sim := RaceSim.new()
var config: Dictionary = {}
var visuals := {}
var cam: Camera3D
var split_cams: Array = []
var reported := false
var hud_labels := {}
var countdown_label: Label
var wrong_label: Label
var pause_layer: CanvasLayer
var touch_layer: CanvasLayer
var touch_state := {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "fire_front": false, "fire_rear": false, "drop_mine": false, "boost": false, "drift": false}
var _last_skid := {}
var shot_nodes := {}
var mine_nodes := {}
var pickup_nodes := {}
var minimap: TextureRect
var minimap_image: Image
var minimap_tex: ImageTexture
var shake := 0.0
var cam_pos := Vector3.ZERO
var cam_fov := 62.0
var _beep := -1
var nitro_fill: ColorRect
var trick_label: Label
var callout_label: Label
var _callout_until := 0
var net_label: Label
var vignette: TextureRect
var speed_lines: ColorRect
var chase_slip := 0.0
var net_role := ""
var net_index := 0
var net: NetManager
var _snap_tick := 0
var sun: DirectionalLight3D
var skid_pool: Array = []
var skid_cursor := 0
var flash_pool: Array = []
var flash_cursor := 0
var burst_pool: Array = []
var burst_cursor := 0
var night := false
var rain := false
var rain_fx: CPUParticles3D = null
var crowds: Array = []
var _crowd_tick := 0
var recording := false
var ghost_rec: Array = []
var ghost_samples: Array = []
var ghost_node: Node3D = null
var _rec_last := -99.0
const REC_DT := 0.15
var start_lights: Array = []
var _me_finished := false
var rival_id := ""
var rival_ahead := true
var rival_label: Label = null
var cat_node: Node3D = null
var hit_flash := 0.0
var _rival_quiet_until := 0
var cine_t := -1.0
const CINE_HOLD := 3.2
const PODIUM_HOLD := 3.4
const VR_HINT := "RT gas  LT brake  stick steer  A nitro  B drift  R grip missile  L grip mine  X rear  Y view  Menu pause"
var letterbox: Array = []
var podium: Node3D = null
var vr := false
var vr_origin: XROrigin3D = null
var vr_cam: XRCamera3D = null
var vr_hands: Array = []
var vr_hud: VrPanel = null
var vr_yaw := 0.0
var vr_pos := Vector3.ZERO
var _vr_snap := true
var pad_mat: StandardMaterial3D
var blimp: Node3D
var blimp_angle := 0.0
var flags: Array = []


static func is_night_env(environment: String) -> bool:
	return environment == "industrial"


static func flat(pos: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(pos.x, y, pos.y)


static func yaw_of(heading: float) -> float:
	return -heading


func setup(race_config: Dictionary) -> void:
	config = race_config
	net_role = str(race_config.get("net_role", ""))
	net_index = int(race_config.get("net_index", 0))
	net = race_config.get("net", null) as NetManager
	_me_finished = false
	cine_t = -1.0
	rival_id = str(race_config.get("rival_id", ""))
	rival_ahead = true
	vr = VR.active()
	sim.setup(race_config)
	night = is_night_env(sim.track.environment)
	if bool(race_config.get("force_night", false)):
		night = true
	rain = str(race_config.get("weather", "clear")) == "rain"
	recording = bool(race_config.get("daily", false))
	if recording:
		ghost_rec = []
		_rec_last = -99.0
	var ghost_in: Array = race_config.get("ghost", [])
	if not ghost_in.is_empty():
		ghost_samples = ghost_in
	_build_world()
	_build_cars()
	_build_camera()
	if vr:
		_build_vr()
	elif bool(race_config.get("two_player", false)):
		_build_split()
	_build_hud()
	if Settings.touch_active() or bool(race_config.get("force_touch", false)):
		_build_touch()
	_apply_safe_area()
	_sync_visuals(0.0)
	_keep_screen(true)
	var env := sim.track.environment
	var music := "music_coastal"
	if env == "desert":
		music = "music_desert"
	elif env == "industrial":
		music = "music_industrial"
	AudioDirector.play_music(music)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if net_role == "client":
		_push_net_client()
		_apply_net_snapshot()
		_sync_visuals(delta)
		_sync_projectiles()
		_consume_events()
		_update_hud()
		_update_camera(delta)
		_check_net_finished()
		return
	_push_inputs()
	if net_role == "host":
		_gather_remote_inputs()
	sim.step(delta)
	if recording and sim.state == "racing":
		_record_ghost()
	if net_role == "host" and net != null:
		_snap_tick += 1
		if _snap_tick % NetDefs.SNAP_EVERY == 0 and sim.state == "racing":
			net.broadcast_snap(NetDefs.build_snapshot(sim))
	_sync_visuals(delta)
	_sync_projectiles()
	_consume_events()
	_update_hud()
	_update_camera(delta)
	if sim.state == "finished":
		if net_role == "host" and net != null:
			_finish_net_host()
		elif not cine_holding():
			_report()


func cine_holding() -> bool:
	if bool(config.get("instant_results", false)):
		return false
	return cine_t >= 0.0 and cine_t < cine_total()


func podium_enabled() -> bool:
	return not vr and split_cams.is_empty() and net_role == "" and not bool(config.get("instant_results", false))


func cine_total() -> float:
	return CINE_HOLD + (PODIUM_HOLD if podium_enabled() else 0.0)


func _process(delta: float) -> void:
	_animate_world(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _push_inputs() -> void:
	sim.use_ai_for_players = bool(config.get("assist", false))
	if sim.use_ai_for_players:
		return
	sim.inputs[0] = _merged_drive()
	if bool(config.get("two_player", false)):
		sim.inputs[1] = Settings.read_drive(1)
	if net_role == "host":
		sim.inputs[net_index] = _merged_drive()


func _merged_drive() -> Dictionary:
	var drive := Settings.read_drive(0)
	drive["throttle"] = maxf(float(drive["throttle"]), float(touch_state["throttle"]))
	drive["brake"] = maxf(float(drive["brake"]), float(touch_state["brake"]))
	drive["steer"] = clampf(float(drive["steer"]) + float(touch_state["steer"]), -1.0, 1.0)
	drive["fire_front"] = bool(drive["fire_front"]) or bool(touch_state["fire_front"])
	drive["fire_rear"] = bool(drive["fire_rear"]) or bool(touch_state["fire_rear"])
	drive["drop_mine"] = bool(drive["drop_mine"]) or bool(touch_state["drop_mine"])
	drive["boost"] = bool(drive["boost"]) or bool(touch_state["boost"])
	drive["drift"] = bool(drive["drift"]) or bool(touch_state["drift"])
	if vr:
		drive = _vr_drive(drive)
	if bool(config.get("demo_boost", false)):
		drive["throttle"] = 1.0
		drive["brake"] = 0.0
		drive["steer"] = 0.0
		drive["boost"] = true
	return drive


func _local_drive() -> Dictionary:
	sim.use_ai_for_players = bool(config.get("assist", false))
	return NetDefs.sanitize_input(_merged_drive())


func _push_net_client() -> void:
	if net == null:
		return
	net.send_input(_local_drive())


func _gather_remote_inputs() -> void:
	if net == null:
		return
	for p in net.players:
		var idx := int(p.get("index", 0))
		if idx == net_index:
			continue
		var peer_id := int(p.get("peer_id", -1))
		if peer_id <= 0:
			continue
		sim.inputs[idx] = net.input_for(peer_id)


func _apply_net_snapshot() -> void:
	if net == null or not net.has_snap:
		return
	NetDefs.apply_snapshot(sim, net.take_snapshot())


func _check_net_finished() -> void:
	if net == null:
		return
	if net.has_result:
		sim.state = "finished"
		_report()
	elif sim.state == "finished":
		_report()


func _finish_net_host() -> void:
	if net == null:
		_report()
		return
	var result := sim.result()
	result["mode"] = "net"
	result["champ_id"] = ""
	result["fee_paid"] = 0
	result["two_player"] = false
	net.broadcast_snap(NetDefs.build_snapshot(sim))
	net.broadcast_result(result)
	_report()


func _keep_screen(keep: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.screen_set_keep_on(keep)


func _apply_safe_area() -> void:
	if not Settings.touch_active():
		return
	if DisplayServer.get_name() == "headless":
		return
	var area := DisplayServer.get_display_safe_area()
	var cut := 0.0
	if area.size.x > 0.0:
		cut = maxf(0.0, float(DisplayServer.screen_get_size().x) - float(area.position.x + area.size.x))
	if touch_layer != null:
		touch_layer.offset_left = -cut * 0.15
		touch_layer.offset_right = -cut * 0.15


func _buzz(msecs: int) -> void:
	if vr:
		for hand in vr_hands:
			(hand as VrHand).buzz(clampf(float(msecs) / 120.0, 0.25, 1.0), float(msecs) / 1000.0)
		return
	if not Settings.touch_active():
		return
	if OS.has_feature("mobile") or OS.has_feature("android"):
		Input.vibrate_handheld(msecs)


## Standalone headsets render every frame twice on a phone GPU; blob shadows stay.
func quest_lean() -> bool:
	return vr and VR.headset() and OS.has_feature("android")


func _env_colors() -> Dictionary:
	if rain and not night:
		return {"sky_top": Color("4a5566"), "sky_hor": Color("8e98a4"), "ground": Color("2a3330"), "fog": Color("7a8590"), "sun": Color("c8d2e0")}
	if night:
		return {"sky_top": Color("0b1226"), "sky_hor": Color("31435f"), "ground": Color("14161c"), "fog": Color("1c2636"), "sun": Color("9fb8ff")}
	match sim.track.environment:
		"desert":
			return {"sky_top": Color("3f7fc4"), "sky_hor": Color("e8c98f"), "ground": Color("8a6f45"), "fog": Color("e0c090"), "sun": Color("fff0d8")}
		"industrial":
			return {"sky_top": Color("2b3444"), "sky_hor": Color("7d8898"), "ground": Color("23252b"), "fog": Color("565e6a"), "sun": Color("dfe8ff")}
		_:
			return {"sky_top": Color("3f8fd4"), "sky_hor": Color("bfe0ea"), "ground": Color("2c4a33"), "fog": Color("a8c8d0"), "sun": Color("fff4e0")}


func _build_world() -> void:
	var cols: Dictionary = _env_colors()
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	_apply_sky(env, cols)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.32 if night else 0.58
	env.fog_enabled = true
	env.fog_light_color = cols["fog"]
	env.fog_density = 0.00055 if rain else 0.00022
	env.fog_aerial_perspective = 0.35
	# Presets and the Compatibility fallback live in GraphicsQuality. Quest still
	# drops the expensive passes after the profile is built.
	var gfx := GraphicsQuality.apply_environment(env, night, rain, quest_lean())
	if bool(gfx.get("sdfgi", false)):
		env.ambient_light_energy = 0.22 if night else 0.36
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.light_color = cols["sun"]
	sun.light_energy = 0.45 if night else (0.72 if rain else 1.2)
	sun.rotation = Vector3(-0.95, -0.55, 0)
	sun.shadow_enabled = bool(gfx.get("shadows", true)) and not quest_lean()
	# A wide shadow range stretches texels thin on the Compatibility shadow path.
	# The chase camera only sees a few hundred units ahead.
	sun.directional_shadow_max_distance = float(gfx.get("shadow_distance", 220.0))
	sun.shadow_blur = float(gfx.get("shadow_blur", 1.0))
	if bool(gfx.get("soft_sun", false)):
		sun.light_angular_distance = 0.45
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_blend_splits = true
	sun.light_volumetric_fog_energy = 1.15 if bool(gfx.get("volumetric_fog", false)) else 0.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = cols["sky_hor"]
	fill.light_energy = 0.08 if night else 0.28
	fill.shadow_enabled = false
	fill.rotation = Vector3(-0.35, 2.4, 0.0)
	add_child(fill)
	var ground := MeshInstance3D.new()
	ground.mesh = TrackBuilder3D.build_ground(sim.track)
	ground.material_override = TrackBuilder3D.ground_material(rain)
	add_child(ground)
	var grass := MeshInstance3D.new()
	grass.name = "Grass"
	grass.mesh = TrackBuilder3D.build_cover(sim.track, "G")
	grass.material_override = TrackBuilder3D.grass_material(sim.track.environment)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)
	var asphalt := MeshInstance3D.new()
	asphalt.name = "Asphalt"
	asphalt.mesh = TrackBuilder3D.build_asphalt(sim.track)
	asphalt.material_override = TrackBuilder3D.asphalt_material(rain)
	asphalt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(asphalt)
	var walls := MeshInstance3D.new()
	walls.mesh = TrackBuilder3D.build_walls(sim.track)
	walls.material_override = TrackBuilder3D.ground_material()
	add_child(walls)
	var rails := MeshInstance3D.new()
	rails.mesh = TrackBuilder3D.build_rails(sim.track)
	rails.material_override = TrackBuilder3D.ground_material()
	add_child(rails)
	var pads := MeshInstance3D.new()
	pads.mesh = TrackBuilder3D.build_pads(sim.track)
	pad_mat = TrackBuilder3D.pad_material()
	pads.material_override = pad_mat
	add_child(pads)
	var skirt_mesh := PlaneMesh.new()
	var size := sim.track.pixel_size()
	skirt_mesh.size = Vector2(size.x * 3.0, size.y * 3.0)
	var skirt := MeshInstance3D.new()
	skirt.mesh = skirt_mesh
	var skirt_mat := StandardMaterial3D.new()
	skirt_mat.albedo_color = cols["ground"]
	skirt_mat.roughness = 1.0
	skirt.material_override = skirt_mat
	skirt.position = Vector3(size.x * 0.5, -9.0, size.y * 0.5)
	add_child(skirt)
	# One track-wide reflection probe (captured once) so the glossy clearcoat car
	# paint reflects the sky, walls, and ground around it instead of a flat tint.
	# ReflectionProbe renders on Compatibility/WebGL2; Low and Quest skip it.
	if bool(gfx.get("reflections", false)) and not quest_lean():
		var probe := ReflectionProbe.new()
		probe.size = Vector3(maxf(size.x, 400.0) + 200.0, 260.0, maxf(size.y, 400.0) + 200.0)
		probe.position = Vector3(size.x * 0.5, 90.0, size.y * 0.5)
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
		probe.max_distance = 2400.0
		add_child(probe)
	_build_start_line()
	_build_start_complex()
	_build_decor()
	_build_foliage(int(gfx.get("foliage", 16)))
	_build_surface_marks(bool(gfx.get("decal_nodes", false)) and not quest_lean())
	_build_pickups()
	_build_skids()
	_build_flashes()
	_build_bursts()
	_build_blimp()
	_build_flags()
	if rain:
		_build_rain()


func _apply_sky(env: Environment, cols: Dictionary) -> void:
	# Day and rain use a CC0 Poly Haven panorama. Night stays a procedural sky:
	# a daylight plate on an industrial circuit reads as the wrong time of day.
	var hdri := ""
	if not night and not rain:
		hdri = "res://assets/textures/sky_day.hdr"
	elif rain and not night:
		hdri = "res://assets/textures/sky_overcast.hdr"
	if hdri != "" and ResourceLoader.exists(hdri):
		var sky := Sky.new()
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = load(hdri)
		panorama.energy_multiplier = 0.72 if rain else 0.95
		sky.sky_material = panorama
		env.sky = sky
		return
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = cols["sky_top"]
	sky_mat.sky_horizon_color = cols["sky_hor"]
	sky_mat.ground_bottom_color = cols["ground"]
	sky_mat.ground_horizon_color = cols["sky_hor"]
	sky_mat.sun_angle_max = 26.0
	sky_mat.sun_curve = 0.06
	sky_mat.sky_curve = 0.16
	sky_mat.ground_curve = 0.12
	sky_mat.energy_multiplier = 0.62 if night else 1.22
	sky.sky_material = sky_mat
	env.sky = sky


func _cell_kind(tx: int, ty: int) -> String:
	var track := sim.track
	if ty < 0 or tx < 0 or ty >= track.rows.size() or tx >= track.width:
		return "B"
	var row := track.rows[ty]
	if tx >= row.length():
		return "G"
	return row.substr(tx, 1)


func _build_foliage(count: int) -> void:
	if count <= 0:
		return
	var track := sim.track
	var model := "treeLarge" if track.environment != "desert" else "treeSmall"
	if CarFactory3D.prop_scene(model) == null:
		model = "treeSmall"
	if CarFactory3D.prop_scene(model) == null:
		return
	var spots: Array[Vector2i] = []
	for ty in track.height:
		for tx in track.width:
			if _cell_kind(tx, ty) != "G":
				continue
			var beside := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if TrackBuilder3D.is_road_cell(_cell_kind(tx + dx, ty + dy)):
						beside = true
						break
				if beside:
					break
			if not beside:
				spots.append(Vector2i(tx, ty))
	if spots.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1202
	var n := mini(count, spots.size())
	var t := float(track.tile)
	for i in n:
		var pick := rng.randi_range(i, spots.size() - 1)
		var swap: Vector2i = spots[i]
		spots[i] = spots[pick]
		spots[pick] = swap
		var cell: Vector2i = spots[i]
		var which := model if rng.randf() > 0.45 or track.environment == "desert" else "treeSmall"
		if CarFactory3D.prop_scene(which) == null:
			which = model
		var height := rng.randf_range(78.0, 130.0)
		if which == "treeSmall":
			height = rng.randf_range(48.0, 82.0)
		_place_tree(which, Vector3((float(cell.x) + 0.5) * t, 0.0, (float(cell.y) + 0.5) * t), rng.randf() * TAU, height, i)


func _place_tree(model: String, pos: Vector3, yaw: float, target_height: float, index: int) -> void:
	var scene := CarFactory3D.prop_scene(model)
	if scene == null:
		return
	var root := Node3D.new()
	root.name = "Foliage_%s_%d" % [model, index]
	root.position = pos
	root.rotation.y = yaw
	var node := scene.instantiate() as Node3D
	var box := CarFactory3D._model_aabb(node)
	var s := target_height / maxf(box.size.y, 0.01)
	node.scale = Vector3.ONE * s
	root.add_child(node)
	add_child(root)


func _build_surface_marks(use_decals: bool) -> void:
	var oil := load("res://assets/textures/decal_oil.png") if ResourceLoader.exists("res://assets/textures/decal_oil.png") else null
	var chev := load("res://assets/textures/decal_chevron.png") if ResourceLoader.exists("res://assets/textures/decal_chevron.png") else null
	if oil == null and chev == null:
		return
	var track := sim.track
	var t := float(track.tile)
	var placed := 0
	for ty in track.height:
		if placed >= 8:
			break
		for tx in track.width:
			if _cell_kind(tx, ty) != "O":
				continue
			_add_mark(oil, Vector3((float(tx) + 0.5) * t, TrackBuilder3D.cell_height("O") + 0.35, (float(ty) + 0.5) * t), 36.0, use_decals, "oil%d" % placed)
			placed += 1
			if placed >= 8:
				break
	if sim.track.grid.is_empty() or chev == null:
		return
	var slot: Vector3 = sim.track.grid[0]
	var heading := float(slot.z)
	var face := Vector3(cos(heading), 0.0, sin(heading))
	for i in 3:
		var at := Vector3(slot.x, 0.4, slot.y) + face * (90.0 + float(i) * 70.0)
		var node := _add_mark(chev, at, 28.0, use_decals, "chev%d" % i)
		if node != null:
			node.rotation.y = -heading


func _add_mark(tex: Texture2D, pos: Vector3, width: float, use_decals: bool, tag: String) -> Node3D:
	if tex == null:
		return null
	if use_decals:
		var decal := Decal.new()
		decal.name = "SurfaceMark_%s" % tag
		decal.texture_albedo = tex
		decal.size = Vector3(width, 12.0, width * 0.72)
		decal.position = pos + Vector3(0, 6.0, 0)
		decal.rotation.x = PI
		decal.albedo_mix = 0.85
		decal.modulate = Color(1, 1, 1, 0.85)
		add_child(decal)
		return decal
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, width * 0.72)
	mesh.orientation = PlaneMesh.FACE_Y
	var card := MeshInstance3D.new()
	card.name = "SurfaceMark_%s" % tag
	card.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	card.material_override = mat
	card.position = pos
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card)
	return card


func _build_rain() -> void:
	var drop := BoxMesh.new()
	drop.size = Vector3(0.5, 9.0, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.78, 0.85, 0.95, 0.45)
	drop.material = m
	rain_fx = CPUParticles3D.new()
	rain_fx.name = "Rain"
	rain_fx.mesh = drop
	rain_fx.amount = 450 if OS.has_feature("mobile") else 1100
	rain_fx.lifetime = 0.9
	rain_fx.preprocess = 1.0
	rain_fx.local_coords = false
	rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_fx.emission_box_extents = Vector3(420, 10, 420)
	rain_fx.direction = Vector3(0.12, -1, 0.05)
	rain_fx.spread = 2.0
	rain_fx.gravity = Vector3(0, -600, 0)
	rain_fx.initial_velocity_min = 380.0
	rain_fx.initial_velocity_max = 460.0
	rain_fx.position = Vector3(0, 320, 0)
	add_child(rain_fx)


func _add_crowd(stand: Node3D) -> void:
	var s := 90.0
	var rows := 5
	var per_row := 14
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var body := BoxMesh.new()
	body.size = Vector3(3.2, 6.0, 2.6)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	body.material = mat
	mm.mesh = body
	mm.instance_count = rows * per_row
	var shirts := [Color("e2484f"), Color("ffd23b"), Color("35d0e0"), Color("ff60a0"), Color("f2efe6"), Color("46b25f"), Color("3d6fe2"), Color("ff7b2f")]
	var bases := []
	var i := 0
	for r in rows:
		var z := -0.09 - float(r) * 0.105
		var y := 0.2 + 0.87 * -z
		for c in per_row:
			var x := 0.08 + float(c) / float(per_row - 1) * 0.84 + randf_range(-0.012, 0.012)
			var at := (Vector3(x, y, z) + Vector3(-0.35, -0.01, -0.65)) * s + Vector3(0, 3.0, 0)
			mm.set_instance_transform(i, Transform3D(Basis(), at))
			mm.set_instance_color(i, shirts[randi() % shirts.size()])
			bases.append([at, randf() * TAU, randf_range(5.0, 9.0)])
			i += 1
	var node := MultiMeshInstance3D.new()
	node.name = "Crowd"
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stand.add_child(node)
	crowds.append({"mm": mm, "bases": bases})


func _animate_crowds() -> void:
	_crowd_tick += 1
	if crowds.is_empty() or posmod(_crowd_tick, 3) != 0:
		return
	var hype := 1.0 if sim.state != "racing" else 0.35
	for crowd in crowds:
		var mm: MultiMesh = crowd["mm"]
		var bases: Array = crowd["bases"]
		for i in bases.size():
			var b: Array = bases[i]
			var hop := maxf(0.0, sin(sim.race_time * float(b[2]) + float(b[1]))) * 3.0 * hype
			mm.set_instance_transform(i, Transform3D(Basis(), (b[0] as Vector3) + Vector3(0, hop, 0)))


func _build_blimp() -> void:
	var size := sim.track.pixel_size()
	var root := Node3D.new()
	root.position = Vector3(size.x * 0.5, 210, size.y * 0.5)
	add_child(root)
	var hull := SphereMesh.new()
	hull.radius = 60.0
	hull.height = 90.0
	var hull_node := MeshInstance3D.new()
	hull_node.mesh = hull
	hull_node.scale = Vector3(1.6, 0.75, 0.75)
	hull_node.material_override = CarFactory3D.mat("blimp", Color("e8e2d4"), 0.0, 0.1, 0.6)
	root.add_child(hull_node)
	var stripe := BoxMesh.new()
	stripe.size = Vector3(150, 8, 70)
	var stripe_node := MeshInstance3D.new()
	stripe_node.mesh = stripe
	stripe_node.material_override = CarFactory3D.mat("blimpstripe", Color("ffb000"), 1.2)
	root.add_child(stripe_node)
	CarFactory3D.box(root, Vector3(30, 6, 40), Vector3(-70, 0, 0), CarFactory3D.mat("blimptail", Color("c8102e"), 0.3))
	blimp = root


func _build_flags() -> void:
	if sim.track.grid.is_empty():
		return
	var slot: Vector3 = sim.track.grid[0]
	var heading := float(slot.z)
	var across := Vector3(-sin(heading), 0, cos(heading))
	var colors := [Color("ffb000"), Color("35d0e0"), Color("e2484f"), Color("46e08a")]
	for i in 4:
		var side := -1.0 if i < 2 else 1.0
		var base := Vector3(slot.x, 0, slot.y) + across * side * (150.0 + float(i % 2) * 60.0)
		var pole := CylinderMesh.new()
		pole.top_radius = 2.0
		pole.bottom_radius = 2.5
		pole.height = 95.0
		var pole_node := MeshInstance3D.new()
		pole_node.mesh = pole
		pole_node.material_override = CarFactory3D.mat("flagpole", Color("c8ccd2"), 0.0, 0.7, 0.4)
		pole_node.position = base + Vector3(0, 47, 0)
		add_child(pole_node)
		var cloth_mesh := PlaneMesh.new()
		cloth_mesh.size = Vector2(34, 20)
		cloth_mesh.orientation = PlaneMesh.FACE_Z
		var cloth := MeshInstance3D.new()
		cloth.mesh = cloth_mesh
		var cm := StandardMaterial3D.new()
		cm.albedo_color = colors[i]
		cm.emission_enabled = true
		cm.emission = colors[i]
		cm.emission_energy_multiplier = 0.5
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		cloth.material_override = cm
		cloth.position = base + Vector3(0, 82, 0) + Vector3(17, 0, 0)
		add_child(cloth)
		cloth.set_meta("phase", float(i) * 1.7)
		cloth.set_meta("base_yaw", -heading)
		flags.append(cloth)


func _build_start_line() -> void:
	if sim.track.grid.is_empty():
		return
	var slot: Vector3 = sim.track.grid[0]
	var center := Vector3(slot.x, 0.6, slot.y)
	var heading := float(slot.z)
	var across := Vector3(-sin(heading), 0, cos(heading))
	var white := CarFactory3D.mat("line_white", Color("f2f2f2"), 0.0, 0.0, 0.8)
	var black := CarFactory3D.mat("line_black", Color("111114"), 0.0, 0.0, 0.8)
	var cells := 10
	var width := 26.0
	for i in cells:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(12.0, 1.0, width)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = white if posmod(i, 2) == 0 else black
		node.position = center + across * (float(i) - float(cells - 1) * 0.5) * width
		node.rotation.y = -heading
		add_child(node)
	# Gantry with the track name over the line.
	var pole_mat := CarFactory3D.mat("gantry", Color("3a3f47"), 0.0, 0.6, 0.5)
	var banner_mat := CarFactory3D.mat("banner", Color("c8102e"), 0.3)
	for side in [-1.0, 1.0]:
		var pole := BoxMesh.new()
		pole.size = Vector3(6, 120, 6)
		var pole_node := MeshInstance3D.new()
		pole_node.mesh = pole
		pole_node.material_override = pole_mat
		pole_node.position = center + across * side * (float(cells) * width * 0.5 + 8.0) + Vector3(0, 60, 0)
		add_child(pole_node)
	var banner := BoxMesh.new()
	banner.size = Vector3(float(cells) * width + 22.0, 22, 4)
	var banner_node := MeshInstance3D.new()
	banner_node.mesh = banner
	banner_node.material_override = banner_mat
	banner_node.position = center + Vector3(0, 112, 0)
	banner_node.rotation.y = -heading
	add_child(banner_node)
	# Start lights: red through the countdown, green at the gun.
	var face := Vector3(cos(heading), 0, sin(heading))
	for i in 3:
		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = 5.0
		bulb_mesh.height = 10.0
		var bulb := MeshInstance3D.new()
		bulb.mesh = bulb_mesh
		var bulb_mat := StandardMaterial3D.new()
		bulb_mat.albedo_color = Color("3a0d12")
		bulb_mat.emission_enabled = true
		bulb_mat.emission = Color("ff2a35")
		bulb_mat.emission_energy_multiplier = 0.2
		bulb.material_override = bulb_mat
		bulb.position = center + Vector3(0, 112, 0) - face * 3.0 + across * (float(i) - 1.0) * 30.0
		add_child(bulb)
		start_lights.append(bulb)


func _build_start_complex() -> void:
	if sim.track.grid.is_empty():
		return
	var slot: Vector3 = sim.track.grid[0]
	var center := Vector3(slot.x, 0.0, slot.y)
	var heading := float(slot.z)
	var across := Vector3(-sin(heading), 0, cos(heading))
	var face := Vector3(cos(heading), 0, sin(heading))
	var gap := 135.0 * float(sim.track.tile) / 42.0
	for side in [-1.0, 1.0]:
		var face_yaw := -heading + (PI if side > 0.0 else 0.0)
		var stand := CarFactory3D.add_prop(self, "grandStand", center + across * side * (gap + 60.0) + face * 30.0, face_yaw, 90.0)
		_add_crowd(stand)
		CarFactory3D.add_prop(self, "flagCheckers", center + across * side * (gap + 12.0) + face * 10.0, -heading, 42.0)
		for i in 6:
			CarFactory3D.add_prop(self, "debris-tire", center + across * side * (gap + 28.0) + face * (50.0 + float(i) * 38.0), randf() * TAU, 30.0)
		for b in [150.0, 260.0]:
			CarFactory3D.add_prop(self, "billboard", center + across * side * (gap + 52.0) + face * b, face_yaw, 55.0)
		CarFactory3D.add_prop(self, "cone", center + across * side * (gap - 12.0), 0.0, 30.0)
	cat_node = Cat3D.build()
	cat_node.scale = Vector3.ONE * 62.0
	cat_node.position = center - across * (gap + 4.0) + face * 95.0
	var to_track := across
	cat_node.rotation.y = atan2(to_track.x, to_track.z) - 0.5
	add_child(cat_node)


func _decor_node(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"palm":
			var trunk := CylinderMesh.new()
			trunk.top_radius = 4.0
			trunk.bottom_radius = 6.0
			trunk.height = 70.0
			var trunk_node := MeshInstance3D.new()
			trunk_node.mesh = trunk
			trunk_node.material_override = CarFactory3D.mat("trunk", Color("6b4a2e"), 0.0, 0.0, 0.9)
			trunk_node.position = Vector3(0, 35, 0)
			root.add_child(trunk_node)
			var top := SphereMesh.new()
			top.radius = 22.0
			top.height = 18.0
			var top_node := MeshInstance3D.new()
			top_node.mesh = top
			top_node.material_override = CarFactory3D.mat("palmleaf", Color("2f8f3f"), 0.0, 0.0, 0.85)
			top_node.position = Vector3(0, 76, 0)
			root.add_child(top_node)
		"cactus":
			var arm := CapsuleMesh.new()
			arm.radius = 7.0
			arm.height = 56.0
			var arm_node := MeshInstance3D.new()
			arm_node.mesh = arm
			arm_node.material_override = CarFactory3D.mat("cactus", Color("3f8f4f"), 0.0, 0.0, 0.85)
			arm_node.position = Vector3(0, 28, 0)
			root.add_child(arm_node)
		"rock":
			var stone := SphereMesh.new()
			stone.radial_segments = 7
			stone.rings = 4
			stone.radius = 14.0
			stone.height = 20.0
			var stone_node := MeshInstance3D.new()
			stone_node.mesh = stone
			stone_node.material_override = CarFactory3D.mat("rock", Color("7d838c"), 0.0, 0.0, 0.95)
			stone_node.position = Vector3(0, 6, 0)
			stone_node.rotation.y = randf() * TAU
			root.add_child(stone_node)
		"buoy":
			var body := CylinderMesh.new()
			body.top_radius = 8.0
			body.bottom_radius = 11.0
			body.height = 22.0
			var body_node := MeshInstance3D.new()
			body_node.mesh = body
			body_node.material_override = CarFactory3D.mat("buoy", Color("e2542a"), 0.2)
			body_node.position = Vector3(0, 4, 0)
			root.add_child(body_node)
		"building":
			var h := randf_range(90.0, 190.0)
			CarFactory3D.box(root, Vector3(70, h, 70), Vector3(0, h * 0.5 - 2.0, 0), CarFactory3D.mat("building", Color("5a6068"), 0.0, 0.0, 0.9))
			CarFactory3D.box(root, Vector3(72, 6, 72), Vector3(0, h - 2.0, 0), CarFactory3D.mat("roof", Color("3a3f47"), 0.0, 0.0, 0.9))
		"tank":
			var shell := CylinderMesh.new()
			shell.top_radius = 20.0
			shell.bottom_radius = 20.0
			shell.height = 60.0
			var shell_node := MeshInstance3D.new()
			shell_node.mesh = shell
			shell_node.rotation = Vector3(0, 0, PI * 0.5)
			shell_node.material_override = CarFactory3D.mat("tank", Color("8a7a5a"), 0.0, 0.5, 0.5)
			shell_node.position = Vector3(0, 20, 0)
			root.add_child(shell_node)
		"lamp":
			var post := CarFactory3D.add_prop(root, "lightPostModern", Vector3.ZERO, 0.0, 118.0)
			var head := SphereMesh.new()
			head.radius = 7.0
			head.height = 14.0
			var head_node := MeshInstance3D.new()
			head_node.mesh = head
			head_node.material_override = CarFactory3D.mat("lampbulb", Color("ffe9a8"), 2.4)
			head_node.position = Vector3(0, 87, 11)
			post.add_child(head_node)
		_:
			CarFactory3D.box(root, Vector3(22, 22, 22), Vector3(0, 11, 0), CarFactory3D.mat("crate", Color("8a6a3f"), 0.0, 0.0, 0.9))
	return root


func _build_decor() -> void:
	for item in sim.track.decor:
		var node := _decor_node(str(item.get("kind", "crate")))
		node.position = Vector3(float(item.get("x", 0.0)), 0.0, float(item.get("y", 0.0)))
		node.rotation.y = randf() * TAU
		add_child(node)


func _pickup_color(kind: String) -> Color:
	match kind:
		"missile":
			return Color("ffb000")
		"mine":
			return Color("ff5a2a")
		"repair":
			return Color("46e08a")
		_:
			return Color("35d0e0")


func _build_pickups() -> void:
	for pickup in sim.pickups:
		var kind := str(pickup.get("kind", "missile"))
		var pivot := Node3D.new()
		pivot.position = Vector3(float(pickup.get("x", 0.0)), 16.0, float(pickup.get("y", 0.0)))
		add_child(pivot)
		var gem_mesh := BoxMesh.new()
		gem_mesh.size = Vector3(13, 13, 13)
		var gem := MeshInstance3D.new()
		gem.mesh = gem_mesh
		var gem_mat := StandardMaterial3D.new()
		var color := _pickup_color(kind)
		gem_mat.albedo_color = color
		gem_mat.emission_enabled = true
		gem_mat.emission = color
		gem_mat.emission_energy_multiplier = 2.4
		gem.material_override = gem_mat
		gem.rotation = Vector3(0.6, 0.6, 0)
		pivot.add_child(gem)
		pivot.set_meta("kind", kind)
		pivot.set_meta("phase", randf() * TAU)
		pivot.set_meta("base_y", 16.0)
		pickup_nodes[pickup] = pivot


func _build_skids() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(9, 3.4)
	for _i in 200:
		var node := MeshInstance3D.new()
		node.mesh = mesh
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.05, 0.06, 0.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = m
		node.visible = false
		node.position = Vector3(0, -50, 0)
		add_child(node)
		skid_pool.append(node)


func _build_flashes() -> void:
	for _i in 6:
		var mesh := SphereMesh.new()
		mesh.radius = 10.0
		mesh.height = 20.0
		var node := MeshInstance3D.new()
		node.mesh = mesh
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.7, 0.25, 0.85)
		m.emission_enabled = true
		m.emission = Color("ff8c1a")
		m.emission_energy_multiplier = 3.0
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = m
		node.visible = false
		add_child(node)
		node.set_meta("age", 99.0)
		flash_pool.append(node)


func _build_bursts() -> void:
	for _i in 8:
		var parts := CPUParticles3D.new()
		parts.amount = 22
		parts.lifetime = 0.55
		parts.one_shot = true
		parts.explosiveness = 0.9
		parts.direction = Vector3(0, 1, 0)
		parts.spread = 60.0
		parts.gravity = Vector3(0, -160, 0)
		parts.initial_velocity_min = 90.0
		parts.initial_velocity_max = 260.0
		parts.scale_amount_min = 2.0
		parts.scale_amount_max = 5.0
		parts.color = Color(1.0, 0.62, 0.2)
		parts.emitting = false
		add_child(parts)
		burst_pool.append(parts)


func _burst(at: Vector3, color: Color) -> void:
	var parts: CPUParticles3D = burst_pool[burst_cursor]
	burst_cursor = (burst_cursor + 1) % burst_pool.size()
	parts.position = at
	parts.color = color
	parts.restart()


func _flash(at: Vector3, size: float) -> void:
	var node: MeshInstance3D = flash_pool[flash_cursor]
	flash_cursor = (flash_cursor + 1) % flash_pool.size()
	node.position = at + Vector3(0, 10, 0)
	node.scale = Vector3.ONE * size
	node.visible = true
	node.set_meta("age", 0.0)
	node.set_meta("max", size)


func _stamp_skid(at: Vector2, heading: float) -> void:
	var node: MeshInstance3D = skid_pool[skid_cursor]
	skid_cursor = (skid_cursor + 1) % skid_pool.size()
	node.position = Vector3(at.x, 0.7, at.y)
	node.rotation.y = -heading
	node.visible = true
	var m := node.material_override as StandardMaterial3D
	m.albedo_color.a = 0.5
	node.set_meta("age", 0.0)


func _maybe_skid(car: CarState, lateral: float) -> void:
	if skid_pool.is_empty() or sim.state != "racing" or car.dnf:
		return
	var sliding := car.slip > 0.48 or car.drifting or (lateral > 58.0 and car.vel.length() > 100.0)
	var nitro_slide := car.boosting and lateral > 20.0 and car.vel.length() > 140.0
	if not sliding and not nitro_slide:
		return
	var last: Vector2 = _last_skid.get(car.id, Vector2(-99999, -99999))
	if car.pos.distance_to(last) < 14.0:
		return
	_last_skid[car.id] = car.pos
	var forward := Vector2.from_angle(car.heading)
	var right := Vector2(-forward.y, forward.x)
	_stamp_skid(car.pos - forward * 8.0 + right * 7.0, car.heading)
	_stamp_skid(car.pos - forward * 8.0 - right * 7.0, car.heading)


func _build_cars() -> void:
	for car in sim.cars:
		var built := CarFactory3D.build(car.body, car.paint)
		var root: Node3D = built["root"]
		root.position = flat(car.pos)
		root.rotation.y = yaw_of(car.heading)
		add_child(root)
		built["prev_speed"] = 0.0
		built["scrape_cd"] = 0.0
		var brake_mesh := BoxMesh.new()
		brake_mesh.size = Vector3(2, 4, 22)
		var brake_node := MeshInstance3D.new()
		brake_node.mesh = brake_mesh
		brake_node.material_override = CarFactory3D.mat("brakeglow", Color("ff5a2a"), 3.0)
		brake_node.position = Vector3(-24, 8, 0)
		brake_node.visible = false
		root.add_child(brake_node)
		built["brake"] = brake_node
		if car.is_player:
			built["marker"] = _make_marker()
			root.add_child(built["marker"])
			if night:
				built["spot"] = _make_headlight()
				root.add_child(built["spot"])
		if night:
			built["glow"] = _make_underglow(TrackBuilder3D.paint_named(car.paint))
			root.add_child(built["glow"])
		if car.id == rival_id and rival_id != "":
			var rmark := _make_marker()
			rmark.name = "RivalMarker"
			((rmark.get_child(0) as MeshInstance3D)).material_override = CarFactory3D.mat("rivalmark", Color("ff3048"), 2.6)
			built["marker"] = rmark
			root.add_child(rmark)
		if night or rain:
			_add_headlamps(root)
		if rain:
			built["spray"] = make_spray()
			root.add_child(built["spray"])
		visuals[car.id] = built
	if not ghost_samples.is_empty():
		_build_ghost()


func _add_headlamps(root: Node3D) -> void:
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 1.7
	lamp_mesh.height = 3.4
	var lamp_mat := CarFactory3D.mat("headlamp", Color("fff6d8"), 4.0)
	for side in [-1.0, 1.0]:
		var lamp := MeshInstance3D.new()
		lamp.name = "HeadlampL" if side < 0.0 else "HeadlampR"
		lamp.mesh = lamp_mesh
		lamp.material_override = lamp_mat
		lamp.position = Vector3(21, 7, side * 7.0)
		root.add_child(lamp)


static func make_spray() -> CPUParticles3D:
	var spray := CPUParticles3D.new()
	spray.name = "RainSpray"
	var quad := QuadMesh.new()
	quad.size = Vector2(16, 16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	puff.width = 64
	puff.height = 64
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = soft
	m.albedo_texture = puff
	quad.material = m
	spray.mesh = quad
	spray.amount = 40
	spray.lifetime = 0.6
	spray.local_coords = false
	spray.position = Vector3(-26, 3, 0)
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spray.emission_box_extents = Vector3(2, 1, 13)
	spray.direction = Vector3(-1, 0.8, 0)
	spray.spread = 24.0
	spray.gravity = Vector3(0, -220, 0)
	spray.initial_velocity_min = 50.0
	spray.initial_velocity_max = 110.0
	spray.scale_amount_min = 0.7
	spray.scale_amount_max = 1.5
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.9, 0.98, 0.32))
	fade.set_color(1, Color(0.85, 0.9, 0.98, 0.0))
	spray.color_ramp = fade
	spray.emitting = false
	return spray


func _ghost_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.35, 0.95, 1.0, 0.45)
	m.no_depth_test = false
	return m


func _build_ghost() -> void:
	var root := Node3D.new()
	root.name = "GhostCar"
	var gm := _ghost_material()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(30, 12, 52)
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = gm
	body.position = Vector3(0, 8, 0)
	root.add_child(body)
	var cab_mesh := BoxMesh.new()
	cab_mesh.size = Vector3(20, 9, 22)
	var cab := MeshInstance3D.new()
	cab.mesh = cab_mesh
	cab.material_override = gm
	cab.position = Vector3(0, 17, 2)
	root.add_child(cab)
	root.position = flat(Vector2(ghost_samples[0][1], ghost_samples[0][2]))
	root.rotation.y = yaw_of(float(ghost_samples[0][3]))
	add_child(root)
	ghost_node = root


func _record_ghost() -> void:
	var me := _me()
	if me == null or me.dnf:
		return
	if sim.race_time - _rec_last < REC_DT:
		return
	_rec_last = sim.race_time
	ghost_rec.append([snappedf(sim.race_time, 0.01), snappedf(me.pos.x, 0.5), snappedf(me.pos.y, 0.5), snappedf(me.heading, 0.01)])
	if ghost_rec.size() > 2400:
		ghost_rec.pop_front()


func _update_ghost(delta: float) -> void:
	if ghost_node == null or ghost_samples.is_empty():
		return
	var idx := clampi(int(sim.race_time / REC_DT), 0, ghost_samples.size() - 1)
	var s: Array = ghost_samples[idx]
	var target := Vector3(float(s[1]), 0.0, float(s[2]))
	ghost_node.position = ghost_node.position.lerp(target, minf(1.0, delta * 12.0))
	var want := yaw_of(float(s[3]))
	var cur: float = ghost_node.rotation.y
	ghost_node.rotation.y = cur + _ang_diff(want - cur) * minf(1.0, delta * 12.0)


func _ang_diff(a: float) -> float:
	while a > PI:
		a -= TAU
	while a < -PI:
		a += TAU
	return a


func _make_marker() -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 58, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(9, 13, 9)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.rotation = Vector3(0.5, 0.6, 0.0)
	node.material_override = CarFactory3D.mat("marker", Color("ffd23b"), 2.2)
	pivot.add_child(node)
	pivot.set_meta("phase", randf() * TAU)
	return pivot


func _make_underglow(paint: Color) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(64, 40)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = paint
	m.emission_enabled = true
	m.emission = paint
	m.emission_energy_multiplier = 1.4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = m
	node.position = Vector3(0, 1.1, 0)
	return node


func _make_headlight() -> SpotLight3D:
	var spot := SpotLight3D.new()
	spot.position = Vector3(22, 10, 0)
	spot.rotation.y = -PI * 0.5
	spot.spot_range = 380.0
	spot.spot_angle = 26.0
	spot.light_energy = 2.2
	spot.light_color = Color("fff2c8")
	spot.shadow_enabled = false
	return spot


func _chase_params(boosting: bool, speed_frac: float = 0.0) -> Dictionary:
	var pace := clampf(speed_frac, 0.0, 1.15)
	var fov := 56.0 + pace * 16.0 + (11.0 if boosting else 0.0)
	var dist := lerpf(152.0, 196.0, clampf(pace, 0.0, 1.0)) + (14.0 if boosting else 0.0)
	var height := lerpf(92.0, 118.0, clampf(pace, 0.0, 1.0)) + (6.0 if boosting else 0.0)
	return {"dist": dist, "height": height, "fov": fov}


func _place_chase(camera: Camera3D, target: Vector3, forward: Vector3, params: Dictionary, delta: float, snap: bool) -> void:
	var want := target - forward * float(params["dist"]) + Vector3.UP * float(params["height"])
	var from: Vector3 = camera.get_meta("chase_pos", Vector3.ZERO)
	if snap or from == Vector3.ZERO:
		from = want
	else:
		from = from.lerp(want, 1.0 - exp(-5.0 * delta))
	camera.set_meta("chase_pos", from)
	var kick := Vector3.ZERO
	if Settings.shake_enabled():
		if shake > 0.01:
			kick = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 9.0
		if chase_slip > 0.4:
			kick += Vector3(randf_range(-1.0, 1.0), randf_range(-0.25, 0.25), randf_range(-1.0, 1.0)) * (chase_slip - 0.4) * 3.4
	camera.position = from + kick
	camera.look_at(target + forward * 70.0 + kick * 0.5)
	cam_fov = lerpf(cam_fov, float(params["fov"]), 1.0 - exp(-3.0 * delta))
	camera.fov = cam_fov


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 9000.0
	add_child(cam)
	cam.current = true
	var me := _me()
	if me != null:
		var target := flat(me.pos, 10.0)
		var forward := Vector3(cos(me.heading), 0, sin(me.heading))
		_place_chase(cam, target, forward, _chase_params(false), 1.0, true)


func _build_split() -> void:
	cam.current = false
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	layer.add_child(box)
	var rect := get_viewport().get_visible_rect().size
	for i in 2:
		var container := SubViewportContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.stretch = true
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vp := SubViewport.new()
		vp.handle_input_locally = false
		vp.msaa_3d = GraphicsQuality.profile()["msaa"] as Viewport.MSAA
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.size = Vector2i(maxi(int(rect.x / 2.0) - 4, 32), maxi(int(rect.y), 32))
		container.add_child(vp)
		box.add_child(container)
		var follow := Camera3D.new()
		follow.fov = 62.0
		follow.far = 9000.0
		vp.add_child(follow)
		follow.current = true
		split_cams.append(follow)


func _ui_parent() -> Node:
	if vr_hud != null:
		return vr_hud.viewport
	return self


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	_ui_parent().add_child(layer)
	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 46
	bar.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.047, 0.055, 0.078, 0.9)))
	layer.add_child(bar)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)
	nitro_fill = ColorRect.new()
	nitro_fill.color = Color("ffb000")
	nitro_fill.position = Vector2(12, 38)
	nitro_fill.size = Vector2(8, 5)
	nitro_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(nitro_fill)
	for key in ["pos", "lap", "time", "hp", "nitro", "ammo", "speed"]:
		var label := Label.new()
		label.add_theme_font_override("font", UiKit.font())
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("f4efe4"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		hud_labels[key] = label
	net_label = Label.new()
	net_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	net_label.offset_top = 50
	net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	net_label.add_theme_font_override("font", UiKit.font())
	net_label.add_theme_font_size_override("font_size", 12)
	net_label.add_theme_color_override("font_color", Color("7ee0ff"))
	net_label.visible = false
	layer.add_child(net_label)
	countdown_label = Label.new()
	countdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_label.offset_top = -60
	countdown_label.offset_bottom = -60
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_override("font", UiKit.font())
	countdown_label.add_theme_font_size_override("font_size", 64)
	countdown_label.add_theme_color_override("font_color", Color("ffb000"))
	layer.add_child(countdown_label)
	if rival_id != "":
		rival_label = Label.new()
		rival_label.name = "RivalHud"
		rival_label.position = Vector2(12, 46)
		rival_label.add_theme_font_override("font", UiKit.font())
		rival_label.add_theme_font_size_override("font_size", 14)
		rival_label.add_theme_color_override("font_color", Color("ff5a6a"))
		rival_label.add_theme_color_override("font_outline_color", Color("140c1e"))
		rival_label.add_theme_constant_override("outline_size", 5)
		layer.add_child(rival_label)
	wrong_label = Label.new()
	wrong_label.text = "WRONG WAY"
	wrong_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wrong_label.offset_top = 70
	wrong_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrong_label.add_theme_font_override("font", UiKit.font())
	wrong_label.add_theme_font_size_override("font_size", 22)
	wrong_label.add_theme_color_override("font_color", Color("e23d4a"))
	wrong_label.visible = false
	layer.add_child(wrong_label)
	trick_label = Label.new()
	trick_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	trick_label.offset_top = 78
	trick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trick_label.add_theme_font_override("font", UiKit.font())
	trick_label.add_theme_font_size_override("font_size", 18)
	trick_label.add_theme_color_override("font_color", Color("7ee0ff"))
	trick_label.visible = false
	layer.add_child(trick_label)
	letterbox = []
	var bars_layer := CanvasLayer.new()
	bars_layer.layer = 12
	add_child(bars_layer)
	for top in ([] if vr else [true, false]):
		var band := ColorRect.new()
		band.name = "LetterboxTop" if top else "LetterboxBottom"
		band.color = Color(0.02, 0.01, 0.04, 1.0)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		band.offset_top = 0.0
		band.offset_bottom = 0.0
		band.set_meta("top", top)
		band.visible = false
		bars_layer.add_child(band)
		letterbox.append(band)
	callout_label = Label.new()
	callout_label.name = "Callout"
	callout_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	callout_label.offset_top = 112
	callout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	callout_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	callout_label.add_theme_font_override("font", UiKit.font())
	callout_label.add_theme_font_size_override("font_size", 26)
	callout_label.add_theme_color_override("font_color", Color("ff60a0"))
	callout_label.add_theme_color_override("font_outline_color", Color("140c1e"))
	callout_label.add_theme_constant_override("outline_size", 8)
	callout_label.visible = false
	layer.add_child(callout_label)
	if not vr:
		_build_grade(layer)
	minimap = TextureRect.new()
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.offset_left = -168
	minimap.offset_top = -120
	minimap.offset_right = -12
	minimap.offset_bottom = -12
	minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap.stretch_mode = TextureRect.STRETCH_SCALE
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(minimap)
	_make_minimap()
	var hint := Label.new()
	hint.text = "WASD drive   Space drift   Shift nitro   C missile   X mine   V rear"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 12
	hint.offset_top = -28
	hint.offset_right = 640
	hint.offset_bottom = -8
	hint.add_theme_font_override("font", UiKit.font())
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	if vr:
		hint.text = VR_HINT
		hint.offset_right = 1000
	if not Settings.touch_active():
		layer.add_child(hint)
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 40
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.visible = false
	_ui_parent().add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 280)
	panel.position = Vector2(-180, -140)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.theme = UiKit.make_theme()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color("1c2230")))
	pause_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiKit.font())
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	_pause_button(box, "Resume", _toggle_pause)
	_pause_button(box, "Retire", _retire)
	_pause_button(box, "Quit race", _quit_race)


func _pause_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(callback)
	parent.add_child(button)


func _build_touch() -> void:
	touch_layer = CanvasLayer.new()
	touch_layer.layer = 15
	add_child(touch_layer)
	var pad := Control.new()
	pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pad.offset_left = 24
	pad.offset_top = -220
	pad.offset_right = 280
	pad.offset_bottom = -24
	pad.mouse_filter = Control.MOUSE_FILTER_STOP
	touch_layer.add_child(pad)
	pad.gui_input.connect(_on_steer_pad.bind(pad))
	var hint := Label.new()
	hint.text = "STEER"
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_override("font", UiKit.font())
	pad.add_child(hint)
	_touch_button("ACCEL", {"throttle": 1.0}, Vector2(-210, -200), Vector2(150, 110))
	_touch_button("BRAKE", {"brake": 1.0}, Vector2(-210, -80), Vector2(150, 70))
	_touch_button("BOOST", {"boost": true}, Vector2(-510, -200), Vector2(130, 110))
	_touch_button("DRIFT", {"drift": true}, Vector2(-510, -80), Vector2(130, 70))
	_touch_button("FIRE", {"fire_front": true}, Vector2(-360, -200), Vector2(130, 80))
	_touch_button("MINE", {"drop_mine": true}, Vector2(-360, -110), Vector2(130, 64))
	_touch_button("REAR", {"fire_rear": true}, Vector2(-360, -40), Vector2(130, 64))


func _touch_button(text: String, flags: Dictionary, offset: Vector2, size: Vector2) -> void:
	var button := Button.new()
	button.text = text
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = offset.x
	button.offset_top = offset.y
	button.offset_right = offset.x + size.x
	button.offset_bottom = offset.y + size.y
	button.focus_mode = Control.FOCUS_NONE
	button.button_down.connect(func(): _touch_set(flags, true))
	button.button_up.connect(func(): _touch_set(flags, false))
	touch_layer.add_child(button)


func _touch_set(flags: Dictionary, down: bool) -> void:
	for key in flags.keys():
		var value = flags[key]
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			touch_state[key] = float(value) if down else 0.0
		else:
			touch_state[key] = down


func _on_steer_pad(event: InputEvent, pad: Control) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion:
		var pressed := true
		var at := Vector2.ZERO
		if event is InputEventScreenTouch:
			pressed = event.pressed
			at = event.position
		elif event is InputEventScreenDrag:
			at = event.position
		elif event is InputEventMouseButton:
			pressed = event.pressed
			at = event.position
		elif event is InputEventMouseMotion:
			pressed = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
			at = event.position
		if not pressed:
			touch_state["steer"] = 0.0
			return
		var local := at
		touch_state["steer"] = clampf((local.x - pad.size.x * 0.5) / maxf(pad.size.x * 0.35, 1.0), -1.0, 1.0)


func _sync_visuals(delta: float) -> void:
	for car in sim.cars:
		var visual: Dictionary = visuals.get(car.id, {})
		if visual.is_empty():
			continue
		var root: Node3D = visual["root"]
		var want := flat(car.pos)
		if net_role == "client":
			if Vector2(root.position.x, root.position.z).distance_squared_to(car.pos) > 160000.0:
				root.position = want
			else:
				root.position = root.position.lerp(want, 0.6)
		else:
			root.position = want
		root.rotation.y = yaw_of(car.heading)
		var susp: Node3D = visual["suspension"]
		var forward := Vector2.from_angle(car.heading)
		var right := Vector2(-forward.y, forward.x)
		var lateral: float = car.vel.x * right.x + car.vel.y * right.y
		var speed: float = car.vel.length()
		var prev: float = float(visual.get("prev_speed", 0.0))
		var accel: float = (speed - prev) / maxf(delta, 0.001) if delta > 0.0 else 0.0
		visual["prev_speed"] = speed
		var decel := (prev - speed) / maxf(delta, 0.001) if delta > 0.0 else 0.0
		var brake_node := visual.get("brake") as MeshInstance3D
		if brake_node != null:
			brake_node.visible = decel > 260.0 and speed > 80.0 and sim.state == "racing"
		var scrape_cd := float(visual.get("scrape_cd", 0.0)) - delta
		if speed > 220.0 and sim.state == "racing" and not car.dnf:
			var nose: Vector2 = car.pos + Vector2(cos(car.heading), sin(car.heading)) * 22.0
			if sim.track.blocking(nose) and scrape_cd <= 0.0:
				_burst(flat(nose, 8.0), Color(1.0, 0.85, 0.4))
				AudioDirector.play_sfx("crash", 1.0, 0.25)
				scrape_cd = 0.45
		visual["scrape_cd"] = scrape_cd
		susp.rotation.x = clampf(lateral * 0.00045, -0.1, 0.1)
		susp.rotation.z = clampf(accel * 0.00003, -0.05, 0.07)
		susp.position.y = 8.0 + sin(sim.race_time * 9.0 + car.pos.x * 0.02) * (0.5 if speed > 60.0 else 0.15)
		var wheels: Array = visual["wheels"]
		var pivots: Array = visual["steer"]
		var steer_angle := 0.0
		if not car.dnf and sim.state == "racing":
			if car.is_player:
				steer_angle = _steer_of(car.player_index)
			else:
				steer_angle = clampf(lateral / maxf(speed, 60.0), -1.0, 1.0) * 0.8
		for pivot in pivots:
			(pivot as Node3D).rotation.y = -steer_angle * 0.45
		for spinner in wheels:
			(spinner as Node3D).rotate_z(-speed * delta / 7.0)
		var flame: MeshInstance3D = visual["flame"]
		var lit: bool = car.boosting and (not car.dnf) and sim.state == "racing"
		flame.visible = lit
		if lit:
			var flick := 0.72 + 0.28 * sin(sim.race_time * 42.0 + car.pos.x * 0.05)
			flame.scale = Vector3(flick, 0.85 + flick * 0.2, 0.85 + flick * 0.2)
		var smoke: CPUParticles3D = visual["smoke"]
		var cell := str(sim.track.cell(car.pos))
		var loose := cell == "S" or cell == "D" or cell == "G" or cell == "O"
		var smoking: bool = sim.state == "racing" and not car.dnf and (car.drifting or car.slip > 0.46 or car.hp < car.max_hp * 0.35 or (loose and speed > 80.0))
		smoke.emitting = smoking
		smoke.amount = 28 if car.slip > 0.46 or car.drifting else 14
		smoke.color = _dust_color(car.pos)
		var spray := visual.get("spray") as CPUParticles3D
		if spray != null:
			spray.emitting = speed > 140.0 and not car.dnf and sim.state == "racing"
		var marker := visual.get("marker") as Node3D
		if marker != null and is_instance_valid(marker):
			var phase := float(marker.get_meta("phase", 0.0)) + delta * 3.0
			marker.set_meta("phase", phase)
			marker.position.y = 58.0 + sin(phase) * 4.0
			marker.rotation.y = phase * 0.7
			marker.visible = sim.state != "finished"
		var body_mat := visual["body_mat"] as StandardMaterial3D
		if car.dnf:
			body_mat.albedo_color = Color(0.2, 0.18, 0.18)
		_maybe_skid(car, lateral)
	for pickup in sim.pickups:
		var pivot: Node3D = pickup_nodes.get(pickup)
		if pivot:
			pivot.visible = not bool(pickup["taken"])
	_update_ghost(delta)


func _dust_color(at: Vector2) -> Color:
	match sim.track.cell(at):
		"S", "D":
			return Color(0.78, 0.66, 0.45, 0.6)
		"G":
			return Color(0.55, 0.62, 0.5, 0.55)
		"W":
			return Color(0.6, 0.75, 0.9, 0.6)
		"O":
			return Color(0.15, 0.14, 0.18, 0.6)
		_:
			return Color(0.85, 0.85, 0.88, 0.55)


func _steer_of(player_index: int) -> float:
	if bool(config.get("two_player", false)) and player_index == 1:
		var drive := Settings.read_drive(1)
		return clampf(float(drive["steer"]), -1.0, 1.0)
	var drive0 := _merged_drive()
	return clampf(float(drive0["steer"]), -1.0, 1.0)


func _animate_world(delta: float) -> void:
	_animate_crowds()
	if cat_node != null:
		var me := _me()
		var target: Variant = flat(me.pos, 10.0) if me != null else null
		Cat3D.animate(cat_node, Time.get_ticks_msec() / 1000.0, target, cine_t >= 0.0)
	if pad_mat != null:
		pad_mat.emission_energy_multiplier = 1.3 + sin(sim.race_time * 5.0) * 0.7
	if blimp != null and is_instance_valid(blimp):
		blimp_angle += delta * 0.045
		var size := sim.track.pixel_size()
		var radius := minf(size.x, size.y) * 0.5
		blimp.position = Vector3(size.x * 0.5 + cos(blimp_angle) * radius, 210, size.y * 0.5 + sin(blimp_angle) * radius)
		blimp.rotation.y = -blimp_angle
	for cloth in flags:
		if not is_instance_valid(cloth):
			continue
		var phase := float(cloth.get_meta("phase", 0.0)) + delta * 6.0
		cloth.set_meta("phase", phase)
		cloth.rotation.y = float(cloth.get_meta("base_yaw", 0.0)) + sin(phase) * 0.35
	for pickup in sim.pickups:
		var pivot: Node3D = pickup_nodes.get(pickup)
		if pivot == null or not pivot.visible:
			continue
		var phase := float(pivot.get_meta("phase", 0.0)) + delta * 2.2
		pivot.set_meta("phase", phase)
		pivot.rotation.y = phase
		pivot.position.y = float(pivot.get_meta("base_y", 16.0)) + sin(phase * 1.4) * 5.0
	for id in mine_nodes.keys():
		var entry: Dictionary = mine_nodes.get(id, {})
		var lamp := entry.get("lamp") as MeshInstance3D
		if lamp != null and is_instance_valid(lamp):
			var lamp_mat := lamp.material_override as StandardMaterial3D
			if lamp_mat != null:
				lamp_mat.emission_energy_multiplier = 2.5 if int(sim.race_time * 3.0) % 2 == 0 else 0.4
	for node in flash_pool:
		var age := float(node.get_meta("age", 99.0))
		if age > 0.5:
			node.visible = false
			continue
		age += delta
		node.set_meta("age", age)
		var max_size := float(node.get_meta("max", 3.0))
		var k := clampf(age / 0.45, 0.0, 1.0)
		node.scale = Vector3.ONE * max_size * (1.0 + k * 1.6)
		var m := node.material_override as StandardMaterial3D
		m.albedo_color.a = 0.85 * (1.0 - k)
	for node in skid_pool:
		if not (node as MeshInstance3D).visible:
			continue
		var skid_age := float(node.get_meta("age", 0.0)) + delta
		node.set_meta("age", skid_age)
		var m2 := (node as MeshInstance3D).material_override as StandardMaterial3D
		if skid_age >= 2.6:
			(node as MeshInstance3D).visible = false
		else:
			m2.albedo_color.a = 0.5 * (1.0 - skid_age / 2.6)


func _sync_projectiles() -> void:
	var live := {}
	for shot in sim.shots:
		live[int(shot["id"])] = true
		var node: MeshInstance3D = shot_nodes.get(int(shot["id"]))
		if node == null:
			node = MeshInstance3D.new()
			var mesh := BoxMesh.new()
			if str(shot["kind"]) == "rear":
				mesh.size = Vector3(14, 6, 6)
				node.material_override = CarFactory3D.mat("shot_rear", Color("ff9c1a"), 2.5)
			else:
				mesh.size = Vector3(18, 6, 6)
				node.material_override = CarFactory3D.mat("shot_missile", Color("ffd23b"), 2.5)
			node.mesh = mesh
			add_child(node)
			shot_nodes[int(shot["id"])] = node
		var p: Vector2 = shot["pos"]
		var v: Vector2 = shot["vel"]
		node.position = Vector3(p.x, 8.0, p.y)
		if v.length_squared() > 1.0:
			node.rotation.y = -v.angle()
	for id in shot_nodes.keys():
		if not live.has(id):
			(shot_nodes[id] as MeshInstance3D).queue_free()
			shot_nodes.erase(id)
	var live_mines := {}
	for mine in sim.mines:
		live_mines[int(mine["id"])] = true
		var entry: Dictionary = mine_nodes.get(int(mine["id"]), {})
		if entry.is_empty():
			var root := Node3D.new()
			var body_mesh := CylinderMesh.new()
			body_mesh.top_radius = 8.0
			body_mesh.bottom_radius = 10.0
			body_mesh.height = 7.0
			var body_node := MeshInstance3D.new()
			body_node.mesh = body_mesh
			body_node.material_override = CarFactory3D.mat("minedark", Color("2a2d33"), 0.0, 0.2, 0.7)
			body_node.position = Vector3(0, 3.5, 0)
			root.add_child(body_node)
			var lamp_mesh := SphereMesh.new()
			lamp_mesh.radius = 3.5
			lamp_mesh.height = 7.0
			var lamp := MeshInstance3D.new()
			lamp.mesh = lamp_mesh
			var lamp_mat := StandardMaterial3D.new()
			lamp_mat.albedo_color = Color("ff2a35")
			lamp_mat.emission_enabled = true
			lamp_mat.emission = Color("ff2a35")
			lamp_mat.emission_energy_multiplier = 2.5
			lamp.material_override = lamp_mat
			lamp.position = Vector3(0, 9, 0)
			root.add_child(lamp)
			add_child(root)
			entry = {"root": root, "lamp": lamp}
			mine_nodes[int(mine["id"])] = entry
		var pos: Vector2 = mine["pos"]
		(entry["root"] as Node3D).position = Vector3(pos.x, 0.5, pos.y)
	for id in mine_nodes.keys():
		if not live_mines.has(id):
			(mine_nodes[id]["root"] as Node3D).queue_free()
			mine_nodes.erase(id)


func _consume_events() -> void:
	for event in sim.events:
		var kind := str(event.get("type", ""))
		var pos2: Vector2 = event.get("pos", Vector2.ZERO)
		var at := flat(pos2, 6.0)
		if kind == "explode" or kind == "destroyed":
			_flash(at, 3.2)
			_burst(at, Color(1.0, 0.6, 0.2))
			AudioDirector.play_sfx("explosion", randf_range(0.9, 1.1), 0.8)
			shake = minf(1.0, shake + 0.45)
			_buzz(60)
		elif kind == "crash":
			AudioDirector.play_sfx("crash", randf_range(0.85, 1.15), 0.55)
			_burst(at, Color(1.0, 0.85, 0.4))
			var hurt := float(event.get("damage", 0.0))
			var mine_car := _me()
			if mine_car != null and str(event.get("id", "")) == mine_car.id and hurt > 0.5:
				hit_flash = minf(1.0, 0.35 + hurt / 25.0)
				shake = minf(1.0, shake + 0.3 + hurt / 40.0)
				_buzz(40 + int(hurt * 3.0))
				if hurt >= 8.0:
					_callout("WALL HIT  -%d HP" % int(round(hurt)), Color("ff6a4a"), 900)
			else:
				shake = minf(1.0, shake + 0.08)
		elif kind == "shot":
			var sfx := "rear_missile" if str(event.get("kind", "")) == "rear" else "missile"
			AudioDirector.play_sfx(sfx, randf_range(0.95, 1.05), 0.6)
		elif kind == "mine":
			AudioDirector.play_sfx("mine_drop", 1.0, 0.6)
		elif kind == "pickup":
			AudioDirector.play_sfx("pickup", 1.0, 0.7)
		elif kind == "finish":
			AudioDirector.play_sfx("finish", 1.0, 0.8)
		elif kind == "go":
			AudioDirector.play_sfx("go", 1.0, 0.8)
			var rival := rival_car()
			if rival != null:
				_callout("RIVAL: %s  ·  BOUNTY %s" % [rival.driver_name.to_upper(), Geom.money(int(config.get("rival_bounty", 0)))], Color("ff5a6a"), 2600)
				_rival_quiet_until = Time.get_ticks_msec() + 3000
		elif kind == "lap":
			AudioDirector.play_sfx("countdown", 1.2, 0.4)
		elif kind == "knockout":
			_flash(at, 2.4)
			_burst(at, Color(1.0, 0.38, 0.63))
			AudioDirector.play_sfx("explosion", 0.7, 0.7)
			var me := _me()
			if me != null and str(event.get("id", "")) == me.id:
				_callout("YOU'RE OUT!", Color("e23d4a"))
				_buzz(120)
			else:
				_callout("KNOCKED OUT: %s" % str(event.get("name", "")).to_upper(), Color("ff60a0"))


func _callout(text: String, color: Color, msecs: int = 2200) -> void:
	if callout_label == null:
		return
	callout_label.text = text
	callout_label.add_theme_color_override("font_color", color)
	callout_label.visible = true
	_callout_until = Time.get_ticks_msec() + msecs


func _me() -> CarState:
	if net_role == "host" or net_role == "client":
		var mine := _human(net_index)
		if mine != null:
			return mine
	return _human(0)


func _update_hud() -> void:
	var player := _me()
	if player == null:
		return
	if net_label != null:
		if net_role == "host" and net != null:
			net_label.text = "NET HOST  %d/4" % net.players.size()
			net_label.visible = true
		elif net_role == "client" and net != null:
			net_label.text = "NET RACE"
			net_label.visible = true
		else:
			net_label.visible = false
	hud_labels["pos"].text = "%s / %d" % [Geom.ordinal(player.rank), sim.cars.size()]
	if sim.knockout:
		var left := sim.alive_cars().size()
		hud_labels["lap"].text = "OUT IN %ds  %d LEFT" % [int(ceil(sim.knockout_in())), left]
		var danger := not player.dnf and player.rank >= left and sim.knockout_in() < 5.0
		hud_labels["lap"].add_theme_color_override("font_color", Color("e23d4a") if danger else Color("f4efe4"))
	else:
		hud_labels["lap"].text = "LAP %d/%d" % [mini(player.laps + 1, sim.track.laps), sim.track.laps]
	if callout_label != null and callout_label.visible and Time.get_ticks_msec() > _callout_until:
		callout_label.visible = false
	hud_labels["time"].text = Geom.clock(sim.race_time)
	var hp_ratio := clampf(player.hp / maxf(player.max_hp, 1.0), 0.0, 1.0)
	hud_labels["hp"].text = "HP %d" % int(round(player.hp))
	hud_labels["hp"].add_theme_color_override("font_color", Color("e23d4a") if hp_ratio < 0.35 else Color("f4efe4"))
	var nitro := int(round(clampf(player.boost, 0.0, 1.0) * 100.0))
	hud_labels["nitro"].text = "N2O %d" % nitro
	hud_labels["nitro"].add_theme_color_override("font_color", Color("ffb000") if player.boosting else Color("f4efe4"))
	hud_labels["ammo"].text = "MSL %02d  MNE %02d  REAR %02d" % [player.ammo_missile, player.ammo_mine, player.ammo_rear]
	hud_labels["speed"].text = "%d km/h" % int(round(player.vel.length() * 0.78))
	hud_labels["speed"].add_theme_color_override("font_color", Color("ffb000") if player.boosting else Color("f4efe4"))
	if nitro_fill != null:
		nitro_fill.size.x = 8.0 + 150.0 * clampf(player.boost, 0.0, 1.0)
		nitro_fill.color = Color("ffb000") if player.boosting else Color("f0d48a")
	if trick_label != null:
		if player.drafting:
			trick_label.text = "SLIPSTREAM"
			trick_label.add_theme_color_override("font_color", Color("7ee0ff"))
			trick_label.visible = true
		elif player.drifting:
			trick_label.text = "DRIFT"
			trick_label.add_theme_color_override("font_color", Color("ffb000"))
			trick_label.visible = true
		else:
			trick_label.visible = false
	if vignette != null:
		var pace := clampf((player.vel.length() - 140.0) / 300.0, 0.0, 1.0)
		hit_flash = move_toward(hit_flash, 0.0, 0.035)
		vignette.modulate = Color(1.0, 1.0 - hit_flash * 0.8, 1.0 - hit_flash * 0.8, minf(1.0, 0.16 + pace * 0.7 + hit_flash * 0.6))
	if speed_lines != null:
		var streak := clampf((player.vel.length() - 150.0) / 280.0, 0.0, 1.0)
		if player.boosting:
			streak = clampf(streak + 0.28, 0.0, 1.0)
		(speed_lines.material as ShaderMaterial).set_shader_parameter("amount", streak)
	if sim.state == "countdown":
		var n := int(ceil(sim.countdown))
		countdown_label.text = "GO" if n <= 0 else str(n)
		countdown_label.visible = true
		if n > 0 and n != _beep:
			_beep = n
			AudioDirector.play_sfx("countdown", 1.0, 0.7)
	else:
		countdown_label.visible = false
	wrong_label.visible = _wrong_way(player)
	_update_minimap()
	_update_start_lights()
	_watch_rival(player)
	_check_me_finished(player)


func _update_start_lights() -> void:
	var mode := 0
	var energy := 0.2
	if sim.state == "countdown":
		mode = 1
		energy = 3.0
	elif sim.state == "racing" and sim.race_time < 2.0:
		mode = 2
		energy = 3.0
	for bulb in start_lights:
		var m := (bulb as MeshInstance3D).material_override as StandardMaterial3D
		if m == null:
			continue
		if mode == 1:
			m.emission = Color("ff2a35")
			m.albedo_color = Color("3a0d12")
		elif mode == 2:
			m.emission = Color("46e08a")
			m.albedo_color = Color("0d3a1c")
		else:
			m.emission = Color("ff2a35")
			m.albedo_color = Color("3a0d12")
		m.emission_energy_multiplier = energy


func rival_car() -> CarState:
	if rival_id == "":
		return null
	for car in sim.cars:
		if car.id == rival_id:
			return car
	return null


func _watch_rival(player: CarState) -> void:
	var rival := rival_car()
	if rival != null and rival_label != null:
		var standing := "OUT" if rival.dnf else Geom.ordinal(rival.rank).to_upper()
		var lead := rival.rank > player.rank or rival.dnf
		rival_label.text = "RIVAL %s  %s  %s" % [rival.driver_name.to_upper(), standing, "BEHIND" if lead else "AHEAD"]
		rival_label.add_theme_color_override("font_color", Color("ffd23f") if lead else Color("ff5a6a"))
	if rival == null or sim.state != "racing" or player.finished or player.dnf:
		return
	var ahead := rival.rank < player.rank and not rival.dnf
	if ahead == rival_ahead:
		return
	rival_ahead = ahead
	if Time.get_ticks_msec() < _rival_quiet_until:
		return
	_rival_quiet_until = Time.get_ticks_msec() + 4000
	if ahead:
		_callout("%s IS AHEAD" % rival.driver_name.to_upper(), Color("ff5a6a"), 1600)
	else:
		_callout("RIVAL PASSED!", Color("ffd23f"), 1600)
		_buzz(30)


func _check_me_finished(player: CarState) -> void:
	if _me_finished:
		return
	if player.finished or player.dnf:
		_me_finished = true
		if player.finished and not player.dnf:
			var at := flat(player.pos, 14.0)
			_burst(at, Color(1.0, 0.82, 0.25))
			_burst(at, Color(0.35, 0.85, 1.0))
			_burst(at, Color(1.0, 0.35, 0.55))
			_flash(at, 2.5)
			_start_cinematic(player)
	if sim.state == "racing":
		var ratio := player.vel.length() / maxf(player.max_speed, 1.0)
		var throttle := 1.0 if player.vel.length() > 40.0 else 0.2
		AudioDirector.set_engine(ratio, throttle, true)
	else:
		AudioDirector.set_engine(0.0, 0.0, false)


func _wrong_way(car: CarState) -> bool:
	if sim.track.waypoints.is_empty() or car.vel.length() < 70.0 or car.finished or car.dnf:
		return false
	var ahead: Vector2 = sim.track.waypoints[(car.wp_index + 2) % sim.track.waypoints.size()] - car.pos
	if ahead.length() < 1.0:
		return false
	return Vector2.from_angle(car.heading).dot(ahead.normalized()) < -0.45


func _human(index: int) -> CarState:
	for car in sim.cars:
		if car.is_player and car.player_index == index:
			return car
	if index == 0 and not sim.cars.is_empty():
		return sim.cars[0]
	return null


func _update_camera(delta: float) -> void:
	var p1 := _me()
	if p1 == null:
		return
	shake = move_toward(shake, 0.0, delta * 1.4)
	if rain_fx != null:
		rain_fx.global_position = flat(p1.pos, 320.0) + Vector3(cos(p1.heading), 0, sin(p1.heading)) * 160.0
	if vr:
		if cine_t >= 0.0:
			cine_t += delta
		_drive_vr(p1, delta)
	elif split_cams.size() == 2:
		var p2 := _human(1)
		_drive_chase(split_cams[0] as Camera3D, p1, delta)
		if p2 != null:
			_drive_chase(split_cams[1] as Camera3D, p2, delta)
	elif cine_t >= 0.0:
		cine_t += delta
		if podium_enabled() and cine_t >= CINE_HOLD:
			_drive_podium()
		else:
			_drive_orbit(cam, p1, delta)
	else:
		_drive_chase(cam, p1, delta)
	_update_letterbox(delta)


func _start_cinematic(player: CarState) -> void:
	if split_cams.size() == 2 or cine_t >= 0.0:
		return
	cine_t = 0.0
	cam.set_meta("orbit_base", player.heading + PI * 0.75)
	var place := Geom.ordinal(player.rank).to_upper()
	var color := Color("ffd23f") if player.rank == 1 else Color("7ee0ff")
	_callout("%s   %s" % [place, Geom.clock(player.finish_time)], color, int(CINE_HOLD * 1000.0) + 600)


static func orbit_point(center: Vector3, base: float, t: float) -> Vector3:
	var angle := base + t * 0.55
	var radius := lerpf(190.0, 120.0, clampf(t / 2.5, 0.0, 1.0))
	var height := lerpf(90.0, 42.0, clampf(t / 2.5, 0.0, 1.0))
	return center + Vector3(cos(angle) * radius, height, sin(angle) * radius)


func _drive_orbit(camera: Camera3D, car: CarState, delta: float) -> void:
	if camera == null:
		return
	var center := flat(car.pos, 14.0)
	var want := orbit_point(center, float(camera.get_meta("orbit_base", 0.0)), cine_t)
	var from: Vector3 = camera.get_meta("chase_pos", want)
	from = from.lerp(want, 1.0 - exp(-3.0 * delta))
	camera.set_meta("chase_pos", from)
	camera.position = from
	camera.look_at(center)
	cam_fov = lerpf(cam_fov, 48.0, 1.0 - exp(-2.0 * delta))
	camera.fov = cam_fov


func _update_letterbox(delta: float) -> void:
	if letterbox.is_empty():
		return
	var want := 0.0
	if cine_t >= 0.0:
		want = clampf(cine_t / 0.6, 0.0, 1.0)
	if minimap != null:
		minimap.visible = want <= 0.0
	for bar in letterbox:
		var rect := bar as ColorRect
		var cur := float(rect.get_meta("amount", 0.0))
		cur = move_toward(cur, want, delta * 2.5)
		rect.set_meta("amount", cur)
		rect.visible = cur > 0.001
		var h := 64.0 * cur
		if bool(rect.get_meta("top", true)):
			rect.offset_bottom = h
		else:
			rect.offset_top = -h


func _drive_chase(camera: Camera3D, car: CarState, delta: float) -> void:
	if camera == null:
		return
	var forward := Vector3(cos(car.heading), 0, sin(car.heading))
	chase_slip = car.slip
	_place_chase(camera, flat(car.pos, 10.0), forward, _chase_params(car.boosting, car.vel.length() / 460.0), delta, false)


func _build_grade(hud: CanvasLayer) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	vignette = TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	if ResourceLoader.exists("res://assets/sprites/fx/vignette.png"):
		vignette.texture = load("res://assets/sprites/fx/vignette.png")
	vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vignette.modulate = Color(1, 1, 1, 0.2)
	layer.add_child(vignette)
	speed_lines = ColorRect.new()
	speed_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_lines.color = Color(1, 1, 1, 1)
	var streak_shader := Shader.new()
	streak_shader.code = "shader_type canvas_item;\nuniform float amount = 0.0;\nvoid fragment() {\n\tvec2 p = UV - vec2(0.5);\n\tfloat r = length(p);\n\tfloat ang = atan(p.y, p.x);\n\tfloat bands = abs(sin(ang * 22.0 + TIME * (1.5 + amount * 6.0)));\n\tfloat streak = smoothstep(0.18, 0.72, r) * smoothstep(0.55, 0.95, bands);\n\tCOLOR = vec4(0.9, 0.94, 1.0, streak * amount * amount * 0.42);\n}\n"
	var streak_mat := ShaderMaterial.new()
	streak_mat.shader = streak_shader
	streak_mat.set_shader_parameter("amount", 0.0)
	speed_lines.material = streak_mat
	layer.add_child(speed_lines)

func _make_minimap() -> void:
	var w := sim.track.width
	var h := sim.track.height
	minimap_image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	minimap_image.fill(Color(0.08, 0.1, 0.12, 0.9))
	for y in h:
		var row := sim.track.rows[y]
		for x in mini(w, row.length()):
			var ch := row.substr(x, 1)
			var color := Color(0.15, 0.35, 0.2)
			if ch in "AOF":
				color = Color(0.35, 0.36, 0.4)
			elif ch == "B":
				color = Color(0.55, 0.55, 0.58)
			elif ch == "W":
				color = Color(0.2, 0.45, 0.7)
			elif ch in "SD":
				color = Color(0.55, 0.42, 0.25)
			elif ch == "C":
				color = Color(0.7, 0.25, 0.22)
			elif ch == "O":
				color = Color(0.15, 0.12, 0.18)
			minimap_image.set_pixel(x, y, color)
	minimap_tex = ImageTexture.create_from_image(minimap_image)
	minimap.texture = minimap_tex


func _update_minimap() -> void:
	if minimap_image == null:
		return
	var frame := minimap_image.duplicate()
	for car in sim.cars:
		var tx := clampi(int(car.pos.x / float(sim.track.tile)), 0, frame.get_width() - 1)
		var ty := clampi(int(car.pos.y / float(sim.track.tile)), 0, frame.get_height() - 1)
		var color := Color("ffb000") if car.is_player else Color("e23d4a")
		if car.id == rival_id:
			color = Color("ff9ad0")
		frame.set_pixel(tx, ty, color)
	minimap_tex.update(frame)


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_layer.visible = paused
	for hand in vr_hands:
		(hand as VrHand).pointing = paused
	if paused:
		AudioDirector.play_sfx("ui_click")
		AudioDirector.set_engine(0, 0, false)


func _retire() -> void:
	get_tree().paused = false
	pause_layer.visible = false
	for hand in vr_hands:
		(hand as VrHand).pointing = false
	var me := _me()
	for car in sim.cars:
		if net_role == "host" or net_role == "client":
			if car == me:
				car.dnf = true
				car.hp = 0.0
		elif car.is_player and car.player_index == 0:
			car.dnf = true
			car.hp = 0.0
	sim.state = "finished"
	_report()


func _quit_race() -> void:
	_retire()


func _exit_tree() -> void:
	_keep_screen(false)


func _report() -> void:
	if reported:
		return
	reported = true
	get_tree().paused = false
	_keep_screen(false)
	AudioDirector.set_engine(0, 0, false)
	var result := sim.result()
	if net_role == "host" or net_role == "client":
		result["mode"] = "net"
		result["champ_id"] = ""
		result["fee_paid"] = 0
		result["two_player"] = false
	else:
		result["mode"] = str(config.get("mode", "exhibition"))
		result["champ_id"] = str(config.get("champ_id", ""))
		result["fee_paid"] = int(config.get("fee_paid", 0))
		result["two_player"] = bool(config.get("two_player", false))
	call_deferred("emit_signal", "race_over", result)


func _build_vr() -> void:
	var s := VR.WORLD_SCALE
	cam.current = false
	vr_origin = XROrigin3D.new()
	vr_origin.name = "VrOrigin"
	vr_origin.world_scale = s
	vr_origin.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(vr_origin)
	vr_origin.current = true
	vr_cam = XRCamera3D.new()
	vr_cam.name = "VrHead"
	vr_cam.fov = 80.0
	vr_cam.near = 0.05 * s
	vr_cam.far = 9000.0
	vr_origin.add_child(vr_cam)
	vr_cam.current = true
	for right in [false, true]:
		var hand := VrHand.new(right, s)
		hand.pointing = false
		hand.button_pressed.connect(_on_vr_button.bind(right))
		vr_origin.add_child(hand)
		vr_hands.append(hand)
	vr_hud = VrPanel.new(Vector2i(960, 540), Vector2(1.3, 0.73) * s, true)
	vr_hud.name = "VrHud"
	vr_hud.position = Vector3(0, -0.5, -1.4) * s
	vr_hud.rotation.x = -0.34
	vr_origin.add_child(vr_hud)
	_vr_snap = true
	var me := _me()
	if me != null:
		_drive_vr(me, 1.0)
	VR.recenter()


func _on_vr_button(button: String, right: bool) -> void:
	if button == "menu_button":
		_toggle_pause()
	elif button == "by_button" and not right and not get_tree().paused:
		Settings.data["vr_view"] = "cockpit" if VR.view_mode() == "chase" else "chase"
		Settings.save_settings()
		_vr_snap = true
		_callout("COCKPIT VIEW" if VR.view_mode() == "cockpit" else "CHASE VIEW", Color("7ee0ff"), 1200)


static func vr_eye(car_pos: Vector3, forward: Vector3, mode: String) -> Vector3:
	if mode == "cockpit":
		return car_pos + forward * 4.0 + Vector3.UP * 27.0
	return car_pos - forward * 100.0 + Vector3.UP * 48.0


func _drive_vr(car: CarState, delta: float) -> void:
	if vr_origin == null or car == null:
		return
	var forward := Vector3(cos(car.heading), 0, sin(car.heading))
	var mode := VR.view_mode()
	if cine_t >= 0.0 and not _vr_snap:
		return
	var want_pos := vr_eye(flat(car.pos), forward, mode)
	var want_yaw := VR.yaw_facing(forward)
	if _vr_snap:
		vr_pos = want_pos
		vr_yaw = want_yaw
		_vr_snap = false
	else:
		var turn := 14.0 if mode == "cockpit" else 5.0
		var follow := 30.0 if mode == "cockpit" else 7.0
		vr_yaw = lerp_angle(vr_yaw, want_yaw, 1.0 - exp(-turn * delta))
		vr_pos = vr_pos.lerp(want_pos, 1.0 - exp(-follow * delta))
	vr_origin.transform = Transform3D(Basis(Vector3.UP, vr_yaw), vr_pos)
	var built: Dictionary = visuals.get(car.id, {})
	var marker := built.get("marker", null) as Node3D
	if marker != null:
		marker.visible = mode != "cockpit"


func _vr_drive(drive: Dictionary) -> Dictionary:
	if vr_hands.size() < 2:
		return drive
	var left := vr_hands[0] as VrHand
	var right := vr_hands[1] as VrHand
	var ls := left.stick()
	var rs := right.stick()
	var steer := ls.x if absf(ls.x) >= absf(rs.x) else rs.x
	drive["steer"] = clampf(float(drive["steer"]) + VR.deadzone(steer), -1.0, 1.0)
	drive["throttle"] = maxf(float(drive["throttle"]), VR.deadzone(right.get_float(&"trigger"), 0.05))
	drive["brake"] = maxf(float(drive["brake"]), VR.deadzone(left.get_float(&"trigger"), 0.05))
	drive["boost"] = bool(drive["boost"]) or right.is_button_pressed(&"ax_button")
	drive["drift"] = bool(drive["drift"]) or right.is_button_pressed(&"by_button")
	drive["fire_front"] = bool(drive["fire_front"]) or right.get_float(&"grip") > 0.6
	drive["drop_mine"] = bool(drive["drop_mine"]) or left.get_float(&"grip") > 0.6
	drive["fire_rear"] = bool(drive["fire_rear"]) or left.is_button_pressed(&"ax_button")
	return drive


func podium_origin() -> Vector3:
	if not sim.track.grid.is_empty():
		var slot: Vector3 = sim.track.grid[0]
		return Vector3(slot.x, Podium3D.STAGE_HEIGHT, slot.y)
	var me := _me()
	return flat(me.pos if me != null else Vector2.ZERO, Podium3D.STAGE_HEIGHT)


func _drive_podium() -> void:
	var origin := podium_origin()
	if podium == null:
		podium = Podium3D.build(sim.cars)
		podium.position = origin
		add_child(podium)
		var winners := Podium3D.top_three(sim.cars)
		if not winners.is_empty():
			var champ := winners[0] as CarState
			var you_won := champ.is_player
			_callout("YOU WIN!" if you_won else "%s WINS" % champ.driver_name.to_upper(), Color("ffd23f"), int(PODIUM_HOLD * 1000.0) + 400)
			if you_won:
				AudioDirector.play_sfx("buy")
	var t := cine_t - CINE_HOLD
	var view := Podium3D.shot(origin, t)
	var eye: Vector3 = view["eye"]
	cam.transform = Transform3D(Basis.looking_at((view["look"] as Vector3) - eye, Vector3.UP), eye)
	cam.fov = 50.0
	var kitty := podium.get_node_or_null("PodiumCat") as Node3D
	if kitty != null:
		Cat3D.animate(kitty, cine_t, eye, true)
