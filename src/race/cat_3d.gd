class_name Cat3D
extends RefCounted

const GINGER := Color("c9521f")
const GINGER_DARK := Color("8f3412")
const CREAM := Color("e2d6c4")
const PINK := Color("f29aa6")
const EYE := Color("7cc94a")


static func _fur(color: Color, key: String) -> StandardMaterial3D:
	var m := CarFactory3D.mat("cat_" + key, color, 0.0, 0.0, 0.97)
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.9
	return m


static func _blob(parent: Node3D, radius: float, pos: Vector3, scale: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.scale = scale
	node.material_override = material
	parent.add_child(node)
	return node


static func _cone(parent: Node3D, radius: float, height: float, pos: Vector3, rot: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.rotation = rot
	node.material_override = material
	parent.add_child(node)
	return node


static func _tufts(parent: Node3D, rng: RandomNumberGenerator, center: Vector3, radii: Vector3, count: int, front_white: bool, ginger: Material, cream: Material) -> void:
	for i in count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		var at := center + dir * radii
		var white := front_white and dir.z > 0.7 and absf(dir.x) < 0.4 and dir.y > -0.2
		var tuft := _blob(parent, rng.randf_range(0.05, 0.08), at, Vector3(0.75, 1.5, 0.75), cream if white else ginger)
		var hang := (dir + Vector3(0, -0.6, 0)).normalized()
		if hang.length() > 0.01 and absf(hang.dot(Vector3.UP)) < 0.999:
			tuft.quaternion = Quaternion(Vector3.UP, hang)


static func build() -> Node3D:
	var ginger := _fur(GINGER, "ginger")
	var dark := _fur(GINGER_DARK, "ginger_dark")
	var cream := _fur(CREAM, "cream")
	var pink := CarFactory3D.mat("cat_pink", PINK, 0.0, 0.0, 0.8)
	var eye := CarFactory3D.mat("cat_eye", EYE, 0.6, 0.0, 0.2)
	var pupil := CarFactory3D.mat("cat_pupil", Color("0d0b10"), 0.0, 0.0, 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var root := Node3D.new()
	root.name = "TussieCat"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	_blob(body, 0.32, Vector3(0, 0.36, -0.02), Vector3(1.0, 1.12, 1.1), ginger)
	_blob(body, 0.21, Vector3(-0.2, 0.2, -0.08), Vector3(1, 0.95, 1.25), ginger)
	_blob(body, 0.21, Vector3(0.2, 0.2, -0.08), Vector3(1, 0.95, 1.25), ginger)
	_blob(body, 0.2, Vector3(0, 0.46, 0.2), Vector3(0.95, 1.35, 0.7), cream)
	_blob(body, 0.14, Vector3(0, 0.22, 0.22), Vector3(1.1, 0.8, 0.8), cream)
	for x in [-0.1, 0.1]:
		var leg := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.065
		cap.height = 0.36
		leg.mesh = cap
		leg.position = Vector3(x, 0.17, 0.25)
		leg.material_override = cream
		body.add_child(leg)
		_blob(body, 0.08, Vector3(x, 0.035, 0.29), Vector3(1, 0.6, 1.25), cream)
	for x in [-0.27, 0.27]:
		_blob(body, 0.09, Vector3(x, 0.04, 0.05), Vector3(1, 0.55, 1.6), cream)
	for i in 3:
		_blob(body, 0.12, Vector3(0, 0.62 - i * 0.12, -0.3), Vector3(1.9, 0.35, 0.5), dark)
	_tufts(body, rng, Vector3(0, 0.36, -0.02), Vector3(0.33, 0.38, 0.35), 46, true, ginger, cream)
	var ruff := Node3D.new()
	ruff.name = "Ruff"
	ruff.position = Vector3(0, 0.63, 0.06)
	body.add_child(ruff)
	for i in 16:
		var a := TAU * float(i) / 16.0
		var dir := Vector3(sin(a), 0, cos(a))
		var front := cos(a) > 0.55
		var tuft := _blob(ruff, 0.075, dir * 0.2 + Vector3(0, -0.05, 0), Vector3(0.75, 2.0, 0.75), cream if front else ginger)
		tuft.rotation = Vector3(cos(a) * 0.75, 0, -sin(a) * 0.75)
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.1, -0.34)
	body.add_child(tail)
	var seg_pos := Vector3.ZERO
	for i in 9:
		var t := float(i) / 8.0
		seg_pos += Vector3(0.05 + t * 0.06, 0.035 + t * 0.07, -0.04 + t * 0.07)
		var r := lerpf(0.075, 0.13, sin(t * PI * 0.85))
		_blob(tail, r * (0.75 if i == 8 else 1.0), seg_pos, Vector3(1, 1, 1), cream if i == 8 else ginger)
		if i < 7 and i % 2 == 1:
			_blob(tail, r * 0.97, seg_pos, Vector3(1.04, 0.45, 1.04), dark)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.82, 0.1)
	root.add_child(head)
	_blob(head, 0.21, Vector3.ZERO, Vector3(1.12, 0.95, 1.0), ginger)
	_blob(head, 0.12, Vector3(-0.17, -0.06, 0.03), Vector3(0.8, 1.25, 0.9), ginger)
	_blob(head, 0.12, Vector3(0.17, -0.06, 0.03), Vector3(0.8, 1.25, 0.9), ginger)
	_blob(head, 0.115, Vector3(0, -0.07, 0.15), Vector3(1.3, 0.78, 0.85), cream)
	_blob(head, 0.07, Vector3(0, 0.06, 0.18), Vector3(0.55, 1.7, 0.5), cream)
	_blob(head, 0.028, Vector3(0, -0.035, 0.245), Vector3(1.3, 0.8, 0.8), pink)
	for x in [-0.085, 0.085]:
		_blob(head, 0.046, Vector3(x, 0.035, 0.172), Vector3(1.05, 1.0, 0.65), eye)
		_blob(head, 0.022, Vector3(x, 0.035, 0.2), Vector3(0.45, 1.25, 0.5), pupil)
		_blob(head, 0.008, Vector3(x + 0.012, 0.05, 0.212), Vector3.ONE, CarFactory3D.mat("cat_glint", Color.WHITE, 1.5))
	for side in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.name = "EarL" if side < 0.0 else "EarR"
		ear.position = Vector3(side * 0.12, 0.15, -0.01)
		ear.rotation = Vector3(-0.1, 0, -side * 0.32)
		head.add_child(ear)
		_cone(ear, 0.085, 0.17, Vector3(0, 0.06, 0), Vector3.ZERO, ginger)
		_cone(ear, 0.05, 0.11, Vector3(0, 0.05, 0.03), Vector3.ZERO, pink)
		_cone(ear, 0.022, 0.06, Vector3(0, 0.165, 0), Vector3.ZERO, dark)
		for k in 3:
			var whisker := CarFactory3D.box(head, Vector3(0.2, 0.004, 0.004), Vector3(side * 0.16, -0.06 - k * 0.018, 0.17), CarFactory3D.mat("cat_whisker", Color.WHITE, 0.4))
			whisker.rotation = Vector3(0, -side * 0.25, side * (0.12 - k * 0.12))
	return root


static func animate(cat: Node3D, t: float, look_at_global: Variant = null, excited: bool = false) -> void:
	if cat == null or not is_instance_valid(cat):
		return
	var tail := cat.get_node_or_null("Body/Tail") as Node3D
	if tail != null:
		var speed := 4.5 if excited else 1.5
		tail.rotation = Vector3(-0.35 + sin(t * speed * 0.5) * 0.15 - (0.5 if excited else 0.0), sin(t * speed) * 0.55, 0)
	var body := cat.get_node_or_null("Body") as Node3D
	if body != null:
		var breathe := 1.0 + sin(t * 2.2) * 0.012
		body.scale = Vector3(breathe, 1.0 / breathe, breathe)
	var head := cat.get_node_or_null("Head") as Node3D
	if head == null:
		return
	var yaw := sin(t * 0.4) * 0.4
	if look_at_global is Vector3:
		var local := cat.to_local(look_at_global as Vector3)
		yaw = clampf(atan2(local.x, local.z), -1.1, 1.1)
	head.rotation.y = lerp_angle(head.rotation.y, yaw, 0.12)
	head.rotation.z = sin(t * 0.7) * 0.08
	for ear_name in ["EarL", "EarR"]:
		var ear := head.get_node_or_null(ear_name) as Node3D
		if ear != null:
			var flick := 0.35 if fmod(t + (0.0 if ear_name == "EarL" else 1.7), 5.0) < 0.15 else 0.0
			ear.rotation.x = -0.1 - flick
