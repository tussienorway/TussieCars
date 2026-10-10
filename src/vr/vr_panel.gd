class_name VrPanel
extends Node3D

## A flat screen in 3D that hosts 2D UI in its own SubViewport and accepts laser input.

static var panels: Array = []

var viewport: SubViewport
var mesh: MeshInstance3D
var size_world := Vector2(2.4, 1.35)
var _last_px := Vector2(-1, -1)
var _held := false


func _init(px: Vector2i = Vector2i(1280, 720), world_size: Vector2 = Vector2(2.4, 1.35), transparent: bool = false) -> void:
	name = "VrPanel"
	size_world = world_size
	process_mode = Node.PROCESS_MODE_ALWAYS
	viewport = SubViewport.new()
	viewport.name = "Screen"
	viewport.size = px
	viewport.transparent_bg = transparent
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_embed_subwindows = true
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(viewport)
	mesh = MeshInstance3D.new()
	mesh.name = "Surface"
	var quad := QuadMesh.new()
	quad.size = world_size
	mesh.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewport.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.render_priority = 10
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


func _enter_tree() -> void:
	if not panels.has(self):
		panels.append(self)


func _exit_tree() -> void:
	panels.erase(self)
	release()


## Intersects a global ray with the panel plane. Empty when it misses.
func hit(origin: Vector3, dir: Vector3) -> Dictionary:
	return hit_local(global_transform, size_world, Vector2(viewport.size), origin, dir)


static func hit_local(xf: Transform3D, world_size: Vector2, px: Vector2, origin: Vector3, dir: Vector3) -> Dictionary:
	var inv := xf.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 0.00001:
		return {}
	var t := -o.z / d.z
	if t <= 0.0:
		return {}
	var p := o + d * t
	var uv := Vector2(p.x / world_size.x + 0.5, 0.5 - p.y / world_size.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return {}
	var point := xf * p
	return {"dist": point.distance_to(origin), "point": point, "px": uv * px}


func pointer(px: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = px
	motion.global_position = px
	motion.relative = Vector2.ZERO if _last_px.x < 0.0 else px - _last_px
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _held else 0
	viewport.push_input(motion, true)
	_last_px = px
	if pressed != _held:
		_held = pressed
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = px
		click.global_position = px
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		viewport.push_input(click, true)


func scroll(steps: int) -> void:
	if _last_px.x < 0.0 or steps == 0:
		return
	for i in absi(steps):
		for down in [true, false]:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_UP if steps > 0 else MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = down
			wheel.factor = 1.0
			wheel.position = _last_px
			wheel.global_position = _last_px
			viewport.push_input(wheel, true)


func release() -> void:
	if _held and _last_px.x >= 0.0:
		pointer(_last_px, false)
	if _last_px.x >= 0.0 and viewport != null and viewport.is_inside_tree():
		var away := InputEventMouseMotion.new()
		away.position = Vector2(-50, -50)
		away.global_position = away.position
		viewport.push_input(away, true)
	_last_px = Vector2(-1, -1)
	_held = false
