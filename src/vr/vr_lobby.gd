class_name VrLobby
extends Node3D

## The headset menu room: the regular App runs on a big screen, Tussie sits beside it
## and your current car turns on a plinth. Races swap this world out for their own.

const SCREEN_PX := Vector2i(960, 540)
const SCREEN_M := Vector2(2.4, 1.35)
const FLOOR_Y := -1.45

var world: Node3D
var panel: VrPanel
var origin: XROrigin3D
var camera: XRCamera3D
var hands: Array = []
var cat: Node3D
var turntable: Node3D
var app: App
var racing := false
var _car_key := ""
var _t := 0.0
var _car_check := 0.0


func _ready() -> void:
	name = "VrLobby"
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node3D.new()
	world.name = "LobbyWorld"
	add_child(world)
	_build_room()
	panel = VrPanel.new(SCREEN_PX, SCREEN_M, false)
	panel.name = "MenuScreen"
	panel.position = Vector3(0, 0.05, -2.3)
	panel.rotation.x = -0.06
	add_child(panel)
	_build_frame()
	cat = Cat3D.build()
	cat.scale = Vector3.ONE * 0.62
	cat.position = Vector3(1.85, FLOOR_Y + 0.5, -1.8)
	cat.rotation.y = -0.75
	world.add_child(cat)
	turntable = Node3D.new()
	turntable.name = "Turntable"
	turntable.position = Vector3(-4.3, FLOOR_Y + 0.12, -4.4)
	world.add_child(turntable)
	_refresh_car()
	origin = XROrigin3D.new()
	origin.name = "Origin"
	world.add_child(origin)
	camera = XRCamera3D.new()
	camera.name = "Head"
	camera.fov = 78.0
	camera.near = 0.05
	camera.far = 400.0
	origin.add_child(camera)
	for right in [false, true]:
		var hand := VrHand.new(right, 1.0)
		origin.add_child(hand)
		hands.append(hand)
	_activate()


func host_app(target: App) -> void:
	app = target
	panel.viewport.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _activate() -> void:
	origin.current = true
	camera.current = true
	VR.recenter()


func _process(delta: float) -> void:
	_t += delta
	var in_race := app != null and app.race != null and is_instance_valid(app.race)
	if in_race and not racing:
		racing = true
		remove_child(world)
		panel.visible = false
		panel.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif not in_race and racing:
		racing = false
		add_child(world)
		panel.visible = true
		panel.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_activate()
		_refresh_car()
	if racing:
		return
	if cat != null:
		Cat3D.animate(cat, _t, camera.global_position)
	turntable.rotation.y += delta * 0.35
	_car_check -= delta
	if _car_check <= 0.0:
		_car_check = 1.5
		_refresh_car()


func _refresh_car() -> void:
	var vehicle := Balance.vehicle(str(Game.profile.get("vehicle", "sprint_dart")))
	var body := str(vehicle.get("body", "dart"))
	var paint := str(vehicle.get("paint", "cyan"))
	var key := body + "/" + paint
	if key == _car_key:
		return
	_car_key = key
	for child in turntable.get_children():
		child.queue_free()
	var built := CarFactory3D.build(body, paint)
	var car: Node3D = built["root"]
	car.scale = Vector3.ONE * 0.065
	turntable.add_child(car)


func _build_room() -> void:
	var env := WorldEnvironment.new()
	env.name = "LobbyEnv"
	var e := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color("1a1030")
	mat.sky_horizon_color = Color("ff7a4a")
	mat.ground_horizon_color = Color("3a2238")
	mat.ground_bottom_color = Color("0c0814")
	mat.sun_angle_max = 20.0
	sky.sky_material = mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.6
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.5, 0.7, 0)
	sun.light_color = Color("ffd2a8")
	sun.light_energy = 1.1
	world.add_child(sun)
	var floor_node := MeshInstance3D.new()
	floor_node.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_node.mesh = plane
	floor_node.position.y = FLOOR_Y
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("16131f")
	floor_mat.metallic = 0.4
	floor_mat.roughness = 0.25
	floor_node.material_override = floor_mat
	world.add_child(floor_node)
	for i in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 3.4 + i * 2.6
		torus.outer_radius = torus.inner_radius + 0.05
		ring.mesh = torus
		ring.position.y = FLOOR_Y + 0.01
		ring.material_override = VrHand._glow([Color("ffb000"), Color("ff60a0"), Color("7ee0ff")][i], 2.0)
		world.add_child(ring)
	var plinth := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 2.3
	cyl.height = 0.24
	plinth.mesh = cyl
	plinth.position = Vector3(-4.3, FLOOR_Y, -4.4)
	var plinth_mat := StandardMaterial3D.new()
	plinth_mat.albedo_color = Color("262033")
	plinth_mat.metallic = 0.6
	plinth_mat.roughness = 0.3
	plinth.material_override = plinth_mat
	world.add_child(plinth)
	var spot := OmniLight3D.new()
	spot.position = Vector3(-4.3, FLOOR_Y + 3.0, -3.0)
	spot.light_color = Color("7ee0ff")
	spot.light_energy = 2.5
	spot.omni_range = 7.0
	world.add_child(spot)
	var cushion := MeshInstance3D.new()
	var pillow := CylinderMesh.new()
	pillow.top_radius = 0.55
	pillow.bottom_radius = 0.6
	pillow.height = 0.5
	cushion.mesh = pillow
	cushion.position = Vector3(1.85, FLOOR_Y + 0.25, -1.8)
	var cushion_mat := StandardMaterial3D.new()
	cushion_mat.albedo_color = Color("7a2848")
	cushion_mat.roughness = 0.9
	cushion.material_override = cushion_mat
	world.add_child(cushion)
	var warm := OmniLight3D.new()
	warm.position = Vector3(1.6, FLOOR_Y + 1.8, -1.0)
	warm.light_color = Color("ffd2a8")
	warm.light_energy = 1.6
	warm.omni_range = 4.0
	world.add_child(warm)


func _build_frame() -> void:
	var frame := MeshInstance3D.new()
	frame.name = "ScreenFrame"
	var box := BoxMesh.new()
	box.size = Vector3(SCREEN_M.x + 0.08, SCREEN_M.y + 0.08, 0.05)
	frame.mesh = box
	frame.position = Vector3(0, 0, -0.035)
	frame.material_override = VrHand._glow(Color("ff60a0"), 1.4)
	panel.add_child(frame)
	var title := Label3D.new()
	title.name = "Title"
	title.text = "TUSSIECARS"
	title.font = UiKit.font()
	title.font_size = 96
	title.pixel_size = 0.0035
	title.modulate = Color("ffb000")
	title.outline_modulate = Color("140c1e")
	title.outline_size = 18
	title.position = Vector3(0, SCREEN_M.y * 0.5 + 0.22, 0)
	panel.add_child(title)
	var hint := Label3D.new()
	hint.name = "Hint"
	hint.text = "Point and pull the trigger to click   ·   thumbstick scrolls   ·   hold the Meta button to recenter"
	hint.font = UiKit.font()
	hint.font_size = 32
	hint.pixel_size = 0.0022
	hint.modulate = Color(1, 1, 1, 0.8)
	hint.position = Vector3(0, -SCREEN_M.y * 0.5 - 0.12, 0)
	panel.add_child(hint)
