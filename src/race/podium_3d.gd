class_name Podium3D
extends RefCounted

## The victory stage shown after the finish orbit: top three cars on gold, silver,
## and bronze blocks, Tussie beside the winner, confetti, and name boards.

const STAGE_HEIGHT := 360.0
const BLOCKS := [
	{"place": 1, "x": 0.0, "h": 30.0, "color": Color("ffd23f")},
	{"place": 2, "x": -74.0, "h": 20.0, "color": Color("c9d3e0")},
	{"place": 3, "x": 74.0, "h": 13.0, "color": Color("d98a4a")},
]


static func top_three(cars: Array) -> Array:
	var field: Array = []
	for car in cars:
		if not (car as CarState).dnf:
			field.append(car)
	field.sort_custom(func(a, b): return (a as CarState).rank < (b as CarState).rank)
	return field.slice(0, 3)


static func build(cars: Array) -> Node3D:
	var stage := Node3D.new()
	stage.name = "Podium"
	var base := MeshInstance3D.new()
	base.name = "Stage"
	var disc := CylinderMesh.new()
	disc.top_radius = 170.0
	disc.bottom_radius = 150.0
	disc.height = 14.0
	base.mesh = disc
	base.position.y = -7.0
	base.material_override = _mat(Color("1c1828"), 0.0, 0.5, 0.35)
	stage.add_child(base)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 168.0
	ring.outer_radius = 173.0
	rim.mesh = ring
	rim.material_override = _mat(Color("ff60a0"), 2.4)
	stage.add_child(rim)
	var winners := top_three(cars)
	for i in BLOCKS.size():
		var spec: Dictionary = BLOCKS[i]
		var block := MeshInstance3D.new()
		block.name = "Block%d" % int(spec["place"])
		var box := BoxMesh.new()
		box.size = Vector3(66.0, float(spec["h"]), 56.0)
		block.mesh = box
		block.position = Vector3(float(spec["x"]), float(spec["h"]) * 0.5, 0.0)
		block.material_override = _mat(spec["color"], 0.35, 0.7, 0.3)
		stage.add_child(block)
		var number := Label3D.new()
		number.text = str(int(spec["place"]))
		number.font = UiKit.font()
		number.font_size = 96
		number.pixel_size = 0.16
		number.modulate = Color("140c1e")
		number.position = Vector3(float(spec["x"]), float(spec["h"]) * 0.5, 28.5)
		stage.add_child(number)
		if i >= winners.size():
			continue
		var car := winners[i] as CarState
		var built := CarFactory3D.build(car.body, car.paint)
		var model: Node3D = built["root"]
		model.name = "Car%d" % int(spec["place"])
		model.position = Vector3(float(spec["x"]), float(spec["h"]), 0.0)
		model.rotation.y = -PI * 0.5 + (0.35 if float(spec["x"]) < 0.0 else (-0.35 if float(spec["x"]) > 0.0 else 0.0))
		model.scale = Vector3.ONE * 0.95
		model.set_meta("car_id", car.id)
		stage.add_child(model)
		var board := Label3D.new()
		board.name = "Name%d" % int(spec["place"])
		board.text = car.driver_name.to_upper()
		board.font = UiKit.font()
		board.font_size = 48
		board.pixel_size = 0.2
		board.outline_size = 14
		board.modulate = Color("ffd23f") if car.is_player else Color("f4efe4")
		board.outline_modulate = Color("140c1e")
		board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		board.position = Vector3(float(spec["x"]), float(spec["h"]) + 46.0, 0.0)
		stage.add_child(board)
	var cat := Cat3D.build()
	cat.name = "PodiumCat"
	cat.scale = Vector3.ONE * 38.0
	cat.position = Vector3(124.0, 0.0, 18.0)
	cat.rotation.y = -0.7
	stage.add_child(cat)
	stage.add_child(_confetti())
	var key := SpotLight3D.new()
	key.position = Vector3(0, 220, 160)
	key.rotation = Vector3(-0.95, 0, 0)
	key.spot_range = 500.0
	key.spot_angle = 40.0
	key.light_energy = 6.0
	key.light_color = Color("fff0d8")
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 60, 120)
	fill.omni_range = 320.0
	fill.light_energy = 1.4
	fill.light_color = Color("ff9ad0")
	stage.add_child(fill)
	return stage


static func _confetti() -> CPUParticles3D:
	var fx := CPUParticles3D.new()
	fx.name = "Confetti"
	fx.amount = 220
	fx.lifetime = 3.2
	fx.position = Vector3(0, 150, 0)
	fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fx.emission_box_extents = Vector3(150, 6, 60)
	fx.direction = Vector3(0, -1, 0)
	fx.spread = 25.0
	fx.initial_velocity_min = 10.0
	fx.initial_velocity_max = 40.0
	fx.gravity = Vector3(0, -45, 0)
	fx.angular_velocity_min = -300.0
	fx.angular_velocity_max = 300.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color("ffd23f"), Color("ff60a0"), Color("7ee0ff"), Color("46e08a"), Color("ffb000")])
	fx.color_initial_ramp = ramp
	var piece := QuadMesh.new()
	piece.size = Vector2(4.0, 2.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	piece.material = mat
	fx.mesh = piece
	fx.emitting = true
	return fx


static func _mat(color: Color, glow: float, metallic: float = 0.0, roughness: float = 0.6) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat


static func shot(stage_origin: Vector3, t: float) -> Dictionary:
	var sweep := lerpf(-0.45, 0.35, clampf(t / 3.4, 0.0, 1.0))
	var dist := lerpf(260.0, 200.0, clampf(t / 3.4, 0.0, 1.0))
	var eye := stage_origin + Vector3(sin(sweep) * dist, 70.0, cos(sweep) * dist)
	return {"eye": eye, "look": stage_origin + Vector3(0, 32, 0)}
