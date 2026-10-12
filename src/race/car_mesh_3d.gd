class_name CarFactory3D
extends RefCounted

# Pro-built Kenney race cars (CC0, see assets/kenney/CREDITS.md), nose toward +X.
# Returns {root, suspension, body_mat, wheels (spinners), steer (front pivots),
#          flame, flame_mat, smoke, blob}
# Kenney wheels are baked into the model, so wheels/steer are empty and the
# suspension node is the lean pivot for the whole body.

static var _mats := {}
static var _scenes := {}
static var _prop_id := 0

# Kenney models face +Z; the holder yaws them onto the sim +X nose axis.
const KENNEY_YAW := PI * 0.5
const KENNEY_LEN := 50.0
const KENNEY := {
	"dart": {"model": "race-future", "tint": false},
	"viper": {"model": "raceCarRed", "tint": false},
	"mule": {"model": "raceCarGreen", "tint": true},
	"fang": {"model": "raceCarWhite", "tint": true},
}


static func kenney_path(body: String) -> String:
	var spec: Dictionary = KENNEY.get(body, KENNEY["dart"])
	return "res://assets/kenney/%s.glb" % str(spec["model"])


static func kenney_wants_tint(body: String) -> bool:
	var spec: Dictionary = KENNEY.get(body, KENNEY["dart"])
	return bool(spec["tint"])


static func _kenney_scene(body: String) -> PackedScene:
	var path := kenney_path(body)
	if not _scenes.has(path):
		if ResourceLoader.exists(path):
			_scenes[path] = load(path)
		else:
			_scenes[path] = null
	return _scenes[path]


static func prop_scene(model: String) -> PackedScene:
	var path := "res://assets/kenney/%s.glb" % model
	if not _scenes.has(path):
		if ResourceLoader.exists(path):
			_scenes[path] = load(path)
		else:
			_scenes[path] = null
	return _scenes[path]


static func add_prop(parent: Node3D, model: String, pos: Vector3, yaw: float, s: float) -> Node3D:
	var root := Node3D.new()
	_prop_id += 1
	root.name = "Prop_%s_%d" % [model, _prop_id]
	root.position = pos
	root.rotation.y = yaw
	var scene := prop_scene(model)
	if scene != null:
		var node := scene.instantiate() as Node3D
		node.scale = Vector3.ONE * s
		root.add_child(node)
	parent.add_child(root)
	return root


static func mat(key: String, color: Color, emission: float = 0.0, metallic: float = 0.0, roughness: float = 0.6) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


static func _paint_mat(paint: String, dark: bool) -> StandardMaterial3D:
	var base := TrackBuilder3D.paint_named(paint)
	var color := base.darkened(0.35) if dark else base
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.3 if not dark else 0.2
	m.roughness = 0.3 if not dark else 0.55
	if not dark:
		# Automotive clearcoat + a soft rim give the body panels a glossy,
		# reflective "showroom" read. Both work on the Compatibility/WebGL2 renderer.
		m.clearcoat_enabled = true
		m.clearcoat = 0.85
		m.clearcoat_roughness = 0.06
		m.rim_enabled = true
		m.rim = 0.22
		m.rim_tint = 0.4
	return m


static func build(body: String, paint: String) -> Dictionary:
	var scene := _kenney_scene(body)
	if scene != null:
		return build_kenney(body, paint, scene)
	return build_procedural(body, paint)


static func build_kenney(body: String, paint: String, scene: PackedScene) -> Dictionary:
	var paint_color := TrackBuilder3D.paint_named(paint)
	var root := Node3D.new()
	root.name = "Car3D"
	var holder := Node3D.new()
	holder.name = "Suspension"
	holder.rotation.y = KENNEY_YAW
	root.add_child(holder)
	var model := scene.instantiate() as Node3D
	var box := _model_aabb(model)
	var s := KENNEY_LEN / maxf(box.size.z, 0.01)
	model.scale = Vector3.ONE * s
	holder.add_child(model)
	var body_mat: StandardMaterial3D = null
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(si)
			var dup := (orig as StandardMaterial3D).duplicate() if orig is StandardMaterial3D else null
			if dup == null:
				continue
			var keep := _is_kenney_keep(str(orig.resource_name))
			if not keep:
				# Glossy clearcoat over every body panel, on all four cars, reads as
				# modern car paint. Glass and tires are left matte.
				dup.clearcoat_enabled = true
				dup.clearcoat = 0.8
				dup.clearcoat_roughness = 0.06
				dup.rim_enabled = true
				dup.rim = 0.2
				dup.rim_tint = 0.4
			if kenney_wants_tint(body) and not keep:
				dup.albedo_color = paint_color
				dup.metallic = 0.3
				dup.roughness = 0.3
				if body_mat == null:
					body_mat = dup
			mi.set_surface_override_material(si, dup)
	if body_mat == null:
		body_mat = _paint_mat(paint, false)
	var flame_mat := _flame_mat()
	var flame := _add_flame(holder, flame_mat, Vector3(-KENNEY_LEN * 0.5 - 7.0, 8.0, 0.0))
	var smoke := _add_smoke(root, Vector3(-KENNEY_LEN * 0.5 - 2.0, 4.0, 0.0))
	var blob := _add_blob(root)
	return {
		"root": root, "suspension": holder, "body_mat": body_mat,
		"wheels": [], "steer": [], "flame": flame,
		"flame_mat": flame_mat, "smoke": smoke, "blob": blob,
	}


static func _is_kenney_keep(mat_name: String) -> bool:
	var low := mat_name.to_lower()
	return low.contains("tire") or low.contains("glass") or low.contains("window")


static func _model_aabb(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var mbox: AABB = mi.transform * mi.mesh.get_aabb()
		if first:
			box = mbox
			first = false
		else:
			box = box.merge(mbox)
	return box


static func _flame_mat() -> StandardMaterial3D:
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.55, 0.1, 0.9)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color("ff7b10")
	flame_mat.emission_energy_multiplier = 2.5
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return flame_mat


static func _add_flame(parent: Node3D, flame_mat: Material, pos: Vector3) -> MeshInstance3D:
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 1.5
	flame_mesh.bottom_radius = 6.0
	flame_mesh.height = 26.0
	var flame := MeshInstance3D.new()
	flame.mesh = flame_mesh
	flame.material_override = flame_mat
	flame.rotation = Vector3(0, 0, PI * 0.5)
	flame.position = pos
	flame.visible = false
	parent.add_child(flame)
	return flame


static func _add_smoke(parent: Node3D, pos: Vector3) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.amount = 14
	smoke.lifetime = 0.7
	smoke.explosiveness = 0.0
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 28.0
	smoke.gravity = Vector3(0, 30, 0)
	smoke.initial_velocity_min = 25.0
	smoke.initial_velocity_max = 60.0
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 7.0
	smoke.color = Color(0.85, 0.85, 0.88, 0.55)
	smoke.position = pos
	smoke.emitting = false
	parent.add_child(smoke)
	return smoke


static func _add_blob(parent: Node3D) -> MeshInstance3D:
	var blob_mesh := PlaneMesh.new()
	blob_mesh.size = Vector2(58, 36)
	var blob := MeshInstance3D.new()
	blob.mesh = blob_mesh
	var blob_mat := StandardMaterial3D.new()
	blob_mat.albedo_color = Color(0, 0, 0, 0.35)
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob.material_override = blob_mat
	blob.position = Vector3(0, 0.8, 0)
	parent.add_child(blob)
	return blob


static func build_procedural(body: String, paint: String) -> Dictionary:
	var paint_mat := _paint_mat(paint, false)
	var dark_mat := _paint_mat(paint, true)
	var root := Node3D.new()
	root.name = "Car3D"
	var susp := Node3D.new()
	susp.name = "Suspension"
	susp.position = Vector3(0, 8, 0)
	root.add_child(susp)
	var glass_mat := mat("glass", Color("141e2a"), 0.0, 0.85, 0.18)
	var trim_mat := mat("trim", Color("1b1d22"), 0.0, 0.1, 0.8)
	var light_mat := mat("headlight", Color("fff2c0"), 2.0)
	var tail_mat := mat("taillight", Color("ff2a35"), 1.2)
	var stripe_mat := mat("stripe", Color("f2efe6"), 0.0, 0.0, 0.5)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.55, 0.1, 0.9)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color("ff7b10")
	flame_mat.emission_energy_multiplier = 2.5
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match body:
		"viper":
			_build_viper(susp, paint_mat, dark_mat, glass_mat, trim_mat, stripe_mat)
		"mule":
			_build_mule(susp, paint_mat, dark_mat, glass_mat, trim_mat, stripe_mat)
		"fang":
			_build_fang(susp, paint_mat, dark_mat, glass_mat, trim_mat, stripe_mat)
		_:
			_build_dart(susp, paint_mat, dark_mat, glass_mat, trim_mat, stripe_mat)
	# Lights: headlights at the nose (+X), tail strip at the rear.
	box(susp, Vector3(2, 3, 16), Vector3(23, 2, -6), light_mat)
	box(susp, Vector3(2, 3, 16), Vector3(23, 2, 6), light_mat)
	box(susp, Vector3(2, 3, 20), Vector3(-23, 3, 0), tail_mat)
	# Exhaust flame cone pointing back (-X), hidden until boosting.
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 1.5
	flame_mesh.bottom_radius = 6.0
	flame_mesh.height = 26.0
	var flame := MeshInstance3D.new()
	flame.mesh = flame_mesh
	flame.material_override = flame_mat
	flame.rotation = Vector3(0, 0, PI * 0.5)
	flame.position = Vector3(-36, 0, 0)
	flame.visible = false
	susp.add_child(flame)
	# Wheels: steer pivots at the corners, spinners so roll reads.
	var wheels := []
	var steer := []
	var corners := [Vector3(15, 0, -13), Vector3(15, 0, 13), Vector3(-15, 0, -13), Vector3(-15, 0, 13)]
	for i in corners.size():
		var pivot := Node3D.new()
		pivot.position = corners[i] + Vector3(0, -8, 0)
		root.add_child(pivot)
		var spinner := Node3D.new()
		pivot.add_child(spinner)
		_add_wheel(spinner)
		wheels.append(spinner)
		if i < 2:
			steer.append(pivot)
	# Blob shadow to ground the car under the sun shadow.
	var blob_mesh := PlaneMesh.new()
	blob_mesh.size = Vector2(58, 36)
	var blob := MeshInstance3D.new()
	blob.mesh = blob_mesh
	var blob_mat := StandardMaterial3D.new()
	blob_mat.albedo_color = Color(0, 0, 0, 0.35)
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob.material_override = blob_mat
	blob.position = Vector3(0, 0.8, 0)
	root.add_child(blob)
	# Drift/crash smoke emitter, driven by the race view.
	var smoke := CPUParticles3D.new()
	smoke.amount = 14
	smoke.lifetime = 0.7
	smoke.explosiveness = 0.0
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 28.0
	smoke.gravity = Vector3(0, 30, 0)
	smoke.initial_velocity_min = 25.0
	smoke.initial_velocity_max = 60.0
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 7.0
	smoke.color = Color(0.85, 0.85, 0.88, 0.55)
	smoke.position = Vector3(-18, 2, 0)
	smoke.emitting = false
	root.add_child(smoke)
	return {
		"root": root, "suspension": susp, "body_mat": paint_mat,
		"wheels": wheels, "steer": steer, "flame": flame,
		"flame_mat": flame_mat, "smoke": smoke, "blob": blob,
	}


static func _add_wheel(spinner: Node3D) -> void:
	var tire_mat := mat("tire", Color("16171b"), 0.0, 0.0, 0.9)
	var hub_mat := mat("hub", Color("c8ccd2"), 0.0, 0.7, 0.35)
	var tire := CylinderMesh.new()
	tire.top_radius = 7.0
	tire.bottom_radius = 7.0
	tire.height = 5.0
	var tire_node := MeshInstance3D.new()
	tire_node.mesh = tire
	tire_node.rotation = Vector3(PI * 0.5, 0, 0)
	tire_node.material_override = tire_mat
	spinner.add_child(tire_node)
	var hub := CylinderMesh.new()
	hub.top_radius = 3.0
	hub.bottom_radius = 3.0
	hub.height = 5.6
	var hub_node := MeshInstance3D.new()
	hub_node.mesh = hub
	hub_node.rotation = Vector3(PI * 0.5, 0, 0)
	hub_node.material_override = hub_mat
	spinner.add_child(hub_node)
	var spoke := BoxMesh.new()
	spoke.size = Vector3(11, 5.8, 1.6)
	var spoke_node := MeshInstance3D.new()
	spoke_node.mesh = spoke
	spoke_node.material_override = hub_mat
	spinner.add_child(spoke_node)


static func _spoiler(susp: Node3D, width: float, paint_mat: Material, trim_mat: Material) -> void:
	box(susp, Vector3(6, 1.6, width), Vector3(-22, 12, 0), paint_mat)
	box(susp, Vector3(5, 6, 2), Vector3(-22, 8, -width * 0.32), trim_mat)
	box(susp, Vector3(5, 6, 2), Vector3(-22, 8, width * 0.32), trim_mat)


static func _build_dart(susp: Node3D, paint_mat: Material, dark_mat: Material, glass_mat: Material, trim_mat: Material, stripe_mat: Material) -> void:
	box(susp, Vector3(46, 9, 24), Vector3(0, 1, 0), paint_mat)
	box(susp, Vector3(20, 4, 26), Vector3(14, 0, 0), dark_mat)
	box(susp, Vector3(20, 7, 18), Vector3(-3, 8, 0), glass_mat)
	box(susp, Vector3(30, 1.2, 5), Vector3(2, 6, 0), stripe_mat)
	box(susp, Vector3(6, 5, 26), Vector3(-21, 0, 0), trim_mat)
	_spoiler(susp, 26.0, paint_mat, trim_mat)


static func _build_viper(susp: Node3D, paint_mat: Material, dark_mat: Material, glass_mat: Material, trim_mat: Material, stripe_mat: Material) -> void:
	box(susp, Vector3(50, 8, 22), Vector3(0, 1, 0), paint_mat)
	box(susp, Vector3(16, 4, 20), Vector3(20, 0, 0), dark_mat)
	box(susp, Vector3(16, 6, 16), Vector3(-7, 7, 0), glass_mat)
	box(susp, Vector3(34, 1.2, 4), Vector3(2, 5.5, 0), stripe_mat)
	box(susp, Vector3(5, 4, 24), Vector3(-24, 0, 0), trim_mat)
	_spoiler(susp, 30.0, paint_mat, trim_mat)


static func _build_mule(susp: Node3D, paint_mat: Material, dark_mat: Material, glass_mat: Material, trim_mat: Material, stripe_mat: Material) -> void:
	box(susp, Vector3(44, 13, 26), Vector3(-2, 3, 0), paint_mat)
	box(susp, Vector3(12, 5, 26), Vector3(20, 1, 0), dark_mat)
	box(susp, Vector3(14, 6, 22), Vector3(12, 11, 0), glass_mat)
	box(susp, Vector3(10, 1.2, 27), Vector3(-2, 10, 0), stripe_mat)
	box(susp, Vector3(5, 5, 28), Vector3(-24, 1, 0), trim_mat)


static func _build_fang(susp: Node3D, paint_mat: Material, dark_mat: Material, glass_mat: Material, trim_mat: Material, stripe_mat: Material) -> void:
	box(susp, Vector3(46, 8, 26), Vector3(0, 1, 0), paint_mat)
	box(susp, Vector3(18, 4, 28), Vector3(16, 0, 0), dark_mat)
	box(susp, Vector3(18, 7, 17), Vector3(-4, 7.5, 0), glass_mat)
	var fin_l := box(susp, Vector3(16, 6, 1.6), Vector3(-12, 7, -14), paint_mat)
	fin_l.rotation = Vector3(0.35, 0, 0)
	var fin_r := box(susp, Vector3(16, 6, 1.6), Vector3(-12, 7, 14), paint_mat)
	fin_r.rotation = Vector3(-0.35, 0, 0)
	box(susp, Vector3(30, 1.2, 5), Vector3(2, 5.5, 0), stripe_mat)
	box(susp, Vector3(5, 4, 28), Vector3(-23, 0, 0), trim_mat)
	_spoiler(susp, 28.0, paint_mat, trim_mat)
