class_name VrHand
extends XRController3D

## A tracked controller with a laser pointer that clicks and scrolls any VrPanel.

const POSES := [&"aim", &"aim_pose", &"default", &"grip", &"grip_pose"]
const REACH_M := 30.0

static var active_hand: VrHand = null

var right := true
var meters := 1.0
var pointing := true
var laser: MeshInstance3D
var dot: MeshInstance3D
var body: MeshInstance3D
var target: VrPanel = null
var _down := false
var _scroll_cd := 0.0
var _pose_ready := false
var _sim_wheel := 0


func _init(is_right: bool = true, world_scale: float = 1.0) -> void:
	right = is_right
	meters = world_scale
	name = "RightHand" if is_right else "LeftHand"
	tracker = &"right_hand" if is_right else &"left_hand"
	pose = &"aim"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tint := Color("7ee0ff") if is_right else Color("ff9ad0")
	body = MeshInstance3D.new()
	body.name = "Grip"
	var box := BoxMesh.new()
	box.size = Vector3(0.035, 0.03, 0.11) * meters
	body.mesh = box
	body.position = Vector3(0, -0.01, 0.05) * meters
	body.material_override = _glow(Color("1c2230"), 0.0)
	add_child(body)
	laser = MeshInstance3D.new()
	laser.name = "Laser"
	var beam := BoxMesh.new()
	beam.size = Vector3(0.0035 * meters, 0.0035 * meters, 1.0)
	laser.mesh = beam
	laser.material_override = _glow(tint, 2.2, 0.75)
	laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(laser)
	dot = MeshInstance3D.new()
	dot.name = "Dot"
	var ball := SphereMesh.new()
	ball.radius = 0.012 * meters
	ball.height = 0.024 * meters
	dot.mesh = ball
	dot.material_override = _glow(Color.WHITE, 3.0)
	dot.top_level = true
	dot.visible = false
	add_child(dot)


static func _glow(color: Color, energy: float, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
	return mat


func _pick_pose() -> void:
	if _pose_ready:
		return
	var t := XRServer.get_tracker(tracker) as XRPositionalTracker
	if t == null:
		return
	for p in POSES:
		if t.has_pose(p):
			pose = p
			_pose_ready = true
			return


func tracked() -> bool:
	return get_has_tracking_data() or (VR.sim and right)


func trigger() -> float:
	if VR.sim and right:
		return 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.0
	return get_float(&"trigger")


func stick() -> Vector2:
	return get_vector2(&"primary")


func buzz(amplitude: float, seconds: float) -> void:
	if VR.headset():
		trigger_haptic_pulse(&"haptic", 0.0, clampf(amplitude, 0.0, 1.0), seconds, 0.0)


func _input(event: InputEvent) -> void:
	if not (VR.sim and right):
		return
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.pressed:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			_sim_wheel += 1
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_sim_wheel -= 1


func _sim_aim() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var from := cam.global_position + cam.global_transform.basis * (Vector3(0.18, -0.22, -0.1) * meters)
	var through := cam.project_ray_origin(mouse) + cam.project_ray_normal(mouse) * 3.0 * meters
	var dir := (through - from).normalized()
	if dir.length() < 0.5:
		return
	global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), from)


func _process(delta: float) -> void:
	_pick_pose()
	if VR.sim and right:
		_sim_aim()
	var show := pointing and tracked()
	body.visible = tracked()
	laser.visible = show
	if not show:
		dot.visible = false
		_drop_target()
		return
	var pull := trigger()
	var was_down := _down
	if pull > 0.6:
		_down = true
	elif pull < 0.4:
		_down = false
	if _down and not was_down:
		active_hand = self
	if active_hand == null or not is_instance_valid(active_hand) or not active_hand.is_inside_tree():
		active_hand = self
	var origin := global_position
	var dir := -global_transform.basis.z.normalized()
	var best := {}
	var best_panel: VrPanel = null
	for panel in VrPanel.panels:
		var p := panel as VrPanel
		if p == null or not p.is_visible_in_tree():
			continue
		var h := p.hit(origin, dir)
		if h.is_empty():
			continue
		if best.is_empty() or float(h["dist"]) < float(best["dist"]):
			best = h
			best_panel = p
	var length := REACH_M * meters
	if best_panel == null:
		dot.visible = false
		_drop_target()
	else:
		length = float(best["dist"])
		dot.visible = true
		dot.global_position = best["point"]
		if active_hand == self:
			if target != best_panel:
				_drop_target()
				target = best_panel
				buzz(0.15, 0.02)
			best_panel.pointer(best["px"], _down)
			if _down and not was_down:
				buzz(0.35, 0.04)
			_scroll(delta)
	laser.scale = Vector3(1.0, 1.0, maxf(length, 0.01))
	laser.position = Vector3(0, 0, -length * 0.5)


func _scroll(delta: float) -> void:
	if target == null:
		return
	if _sim_wheel != 0:
		target.scroll(_sim_wheel)
		_sim_wheel = 0
	var y := stick().y
	_scroll_cd -= delta
	if absf(y) > 0.45 and _scroll_cd <= 0.0:
		target.scroll(1 if y > 0.0 else -1)
		_scroll_cd = lerpf(0.16, 0.05, clampf((absf(y) - 0.45) / 0.5, 0.0, 1.0))


func _drop_target() -> void:
	if target != null and is_instance_valid(target):
		target.release()
	target = null


func _exit_tree() -> void:
	_drop_target()
	if active_hand == self:
		active_hand = null
