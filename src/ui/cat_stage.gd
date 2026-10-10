class_name CatStage
extends SubViewportContainer

var cat: Node3D
var viewport: SubViewport
var _t := 0.0


func _init(size_px: int = 132) -> void:
	name = "CatStage"
	stretch = true
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.size = Vector2i(size_px, size_px)
	add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("ffe8d6")
	env.environment.ambient_light_energy = 0.55
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7, 0.6, 0)
	key.light_energy = 1.25
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.4, 0)
	rim.light_energy = 0.7
	rim.light_color = Color("ffd2a8")
	viewport.add_child(rim)
	cat = Cat3D.build()
	viewport.add_child(cat)
	var cam := Camera3D.new()
	cam.fov = 34.0
	var eye := Vector3(0.6, 0.95, 2.6)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.52, 0) - eye, Vector3.UP), eye)
	viewport.add_child(cam)
	cam.current = true


func _process(delta: float) -> void:
	_t += delta
	if cat == null:
		return
	cat.rotation.y = sin(_t * 0.5) * 0.45 + 0.25
	Cat3D.animate(cat, _t, Vector3(1.4 * sin(_t * 0.8), 0.8, 2.0))
