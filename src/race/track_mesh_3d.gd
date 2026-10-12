class_name TrackBuilder3D
extends RefCounted

# Procedural 3D meshes for a track. The 2D RaceSim stays the authority:
# sim X/Y maps to world X/Z, one unit per pixel.


static func paint_named(paint: String) -> Color:
	match paint:
		"cyan":
			return Color("35d0e0")
		"red":
			return Color("e2484f")
		"yellow":
			return Color("ffb000")
		"green":
			return Color("46b25f")
		"blue":
			return Color("3d6fe2")
		"violet":
			return Color("9b5de5")
		"orange":
			return Color("ff7b2f")
		"white":
			return Color("e8e8e8")
		"olive":
			return Color("8a8a4d")
		_:
			return Color("35d0e0")


static func ground_palette(environment: String) -> Dictionary:
	match environment:
		"desert":
			return {
				"road": Color("4a4440"), "road_alt": Color("443f3b"),
				"grass": Color("c2a06b"), "grass_alt": Color("b5945f"),
				"sand": Color("d4b075"), "dirt": Color("a07a4e"),
				"water": Color("2a9fd6"), "kerb_a": Color("c23b3b"),
				"kerb_b": Color("e8e2d4"), "oil": Color("1c1a20"),
				"base": Color("8a6f45"),
			}
		"industrial":
			return {
				"road": Color("33363e"), "road_alt": Color("2e3138"),
				"grass": Color("3a4a44"), "grass_alt": Color("34423d"),
				"sand": Color("6b6257"), "dirt": Color("57503f"),
				"water": Color("1f6f9f"), "kerb_a": Color("c9a13b"),
				"kerb_b": Color("2b2d33"), "oil": Color("101014"),
				"base": Color("23252b"),
			}
		_:
			return {
				"road": Color("35383e"), "road_alt": Color("303338"),
				"grass": Color("35853f"), "grass_alt": Color("2f7a3a"),
				"sand": Color("b8945e"), "dirt": Color("7d633d"),
				"water": Color("1f66c2"), "kerb_a": Color("c23b3b"),
				"kerb_b": Color("e8e2d4"), "oil": Color("1c1a20"),
				"base": Color("27432d"),
			}


static func cell_height(kind: String) -> float:
	match kind:
		"W":
			return -6.0
		"G":
			return -2.0
		"S", "D":
			return -1.0
		"C":
			return 1.5
		"O", "F", "N":
			return 0.3
		_:
			return 0.0


static func cell_color(kind: String, pal: Dictionary, checker: bool) -> Color:
	match kind:
		"A", "F", "N":
			return pal["road_alt"] if checker else pal["road"]
		"C":
			return pal["kerb_a"] if checker else pal["kerb_b"]
		"S":
			return pal["sand"]
		"D":
			return pal["dirt"]
		"O":
			return pal["oil"]
		"W":
			return pal["water"]
		"B":
			return pal["base"]
		_:
			return pal["grass_alt"] if checker else pal["grass"]


static func build_ground(track: TrackData) -> ArrayMesh:
	var pal := ground_palette(track.environment)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var t := float(track.tile)
	for ty in track.height:
		var row := track.rows[ty] if ty < track.rows.size() else ""
		for tx in track.width:
			var kind := row.substr(tx, 1) if tx < row.length() else "G"
			var y := cell_height(kind)
			var checker := posmod(tx + ty, 2) == 0
			# One even asphalt tone and mowing bands on grass instead of a tile checker.
			if kind in ["A", "F", "N"]:
				checker = false
			elif not kind in ["C", "S", "D", "O", "W", "B"]:
				checker = posmod(int(floor(float(tx + ty) / 5.0)), 2) == 0
			var color := cell_color(kind, pal, checker)
			if kind in ["A", "F", "N"]:
				var k := 0.93 + _hash01(tx, ty) * 0.12
				color = Color(color.r * k, color.g * k, color.b * k, color.a)
			var base := verts.size()
			verts.append(Vector3(tx * t, y, ty * t))
			verts.append(Vector3(tx * t, y, (ty + 1) * t))
			verts.append(Vector3((tx + 1) * t, y, (ty + 1) * t))
			verts.append(Vector3((tx + 1) * t, y, ty * t))
			for _i in 4:
				normals.append(Vector3.UP)
				colors.append(color)
			indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _wall_top_color(track: TrackData, tx: int, ty: int, pal: Dictionary) -> Color:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var nx: int = tx + d.x
		var ny: int = ty + d.y
		var kind := "B"
		if nx >= 0 and ny >= 0 and nx < track.width and ny < track.rows.size():
			var row := track.rows[ny]
			if nx < row.length():
				kind = row.substr(nx, 1)
		if kind != "B":
			return pal["kerb_a"] if posmod(tx + ty, 2) == 0 else pal["kerb_b"]
	return Color("9aa0a8")


static func _push_box(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, origin: Vector3, size: Vector3, side: Color, top: Color) -> void:
	var x0 := origin.x
	var y0 := origin.y
	var z0 := origin.z
	var x1 := origin.x + size.x
	var y1 := origin.y + size.y
	var z1 := origin.z + size.z
	var corners := [
		Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1),
		Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1),
	]
	var faces := [
		[0, 1, 5, 4, Vector3(0, 0, -1)], [2, 3, 7, 6, Vector3(0, 0, 1)],
		[3, 0, 4, 7, Vector3(-1, 0, 0)], [1, 2, 6, 5, Vector3(1, 0, 0)],
		[4, 5, 6, 7, Vector3.UP],
	]
	for face in faces:
		var base := verts.size()
		var normal: Vector3 = face[4]
		var color := top if normal == Vector3.UP else side
		for vi in [face[0], face[1], face[2], face[3]]:
			verts.append(corners[vi])
			normals.append(normal)
			colors.append(color)
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


static func build_walls(track: TrackData) -> ArrayMesh:
	var pal := ground_palette(track.environment)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var t := float(track.tile)
	var side := Color("7d838c")
	for ty in track.height:
		var row := track.rows[ty] if ty < track.rows.size() else ""
		for tx in track.width:
			var kind := row.substr(tx, 1) if tx < row.length() else "G"
			if kind != "B":
				continue
			_push_box(verts, normals, colors, indices,
				Vector3(tx * t, 0.0, ty * t), Vector3(t, 26.0, t),
				side, _wall_top_color(track, tx, ty, pal))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static var _detail: NoiseTexture2D = null


static func _hash01(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 1000) / 1000.0


static func detail_texture() -> NoiseTexture2D:
	if _detail != null:
		return _detail
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.80, 0.80, 0.80))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	tex.generate_mipmaps = true
	_detail = tex
	return tex


static func ground_material(wet: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = detail_texture()
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.012
	mat.roughness = 0.22 if wet else 0.92
	mat.metallic = 0.12 if wet else 0.0
	mat.metallic_specular = 0.8 if wet else 0.4
	return mat


const ASPHALT_COLOR := "res://assets/textures/asphalt_color.jpg"
const ASPHALT_ROUGH := "res://assets/textures/asphalt_roughness.jpg"
const ASPHALT_NORMAL := "res://assets/textures/asphalt_normal.jpg"
const GRASS_COLOR := "res://assets/textures/grass_color.jpg"
const GRASS_NORMAL := "res://assets/textures/grass_normal.jpg"


static func asphalt_material(wet: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(ASPHALT_COLOR):
		mat.albedo_texture = load(ASPHALT_COLOR)
	mat.albedo_color = Color(0.62, 0.66, 0.7) if wet else Color(0.78, 0.78, 0.8)
	if ResourceLoader.exists(ASPHALT_ROUGH):
		mat.roughness_texture = load(ASPHALT_ROUGH)
	mat.roughness = 0.28 if wet else 0.9
	mat.metallic = 0.18 if wet else 0.02
	mat.metallic_specular = 0.7 if wet else 0.35
	if ResourceLoader.exists(ASPHALT_NORMAL):
		mat.normal_enabled = true
		mat.normal_texture = load(ASPHALT_NORMAL)
		mat.normal_scale = 0.35 if wet else 0.85
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.04
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


static func grass_material(environment: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(GRASS_COLOR):
		mat.albedo_texture = load(GRASS_COLOR)
	match environment:
		"desert":
			mat.albedo_color = Color(0.86, 0.78, 0.48)
		"industrial":
			mat.albedo_color = Color(0.42, 0.48, 0.4)
		_:
			mat.albedo_color = Color(0.72, 0.92, 0.62)
	if ResourceLoader.exists(GRASS_NORMAL):
		mat.normal_enabled = true
		mat.normal_texture = load(GRASS_NORMAL)
		mat.normal_scale = 0.7
	mat.roughness = 0.94
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.03
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


static func build_cover(track: TrackData, kind: String) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var t := float(track.tile)
	for ty in track.height:
		var row := track.rows[ty] if ty < track.rows.size() else ""
		for tx in track.width:
			var cell := row.substr(tx, 1) if tx < row.length() else "G"
			if cell != kind:
				continue
			var y := cell_height(cell) + 0.18
			var base := verts.size()
			verts.append(Vector3(tx * t, y, ty * t))
			verts.append(Vector3(tx * t, y, (ty + 1) * t))
			verts.append(Vector3((tx + 1) * t, y, (ty + 1) * t))
			verts.append(Vector3((tx + 1) * t, y, ty * t))
			for _i in 4:
				normals.append(Vector3.UP)
			indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func build_asphalt(track: TrackData) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var t := float(track.tile)
	for ty in track.height:
		var row := track.rows[ty] if ty < track.rows.size() else ""
		for tx in track.width:
			var kind := row.substr(tx, 1) if tx < row.length() else "G"
			if kind != "A" and kind != "F":
				continue
			var y := cell_height(kind) + 0.22
			var base := verts.size()
			verts.append(Vector3(tx * t, y, ty * t))
			verts.append(Vector3(tx * t, y, (ty + 1) * t))
			verts.append(Vector3((tx + 1) * t, y, (ty + 1) * t))
			verts.append(Vector3((tx + 1) * t, y, ty * t))
			for _i in 4:
				normals.append(Vector3.UP)
			indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func is_road_cell(kind: String) -> bool:
	return kind in ["A", "O", "F", "N"]


static func pad_cells(track: TrackData) -> Array:
	var out := []
	for ty in track.height:
		var row := track.rows[ty] if ty < track.rows.size() else ""
		for tx in track.width:
			if tx < row.length() and row.substr(tx, 1) == "N":
				out.append(Vector2i(tx, ty))
	return out


static func build_pads(track: TrackData) -> ArrayMesh:
	var cells := pad_cells(track)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var t := float(track.tile)
	for cell in cells:
		var base := verts.size()
		var y := 1.2
		verts.append(Vector3(cell.x * t, y, cell.y * t))
		verts.append(Vector3(cell.x * t, y, (cell.y + 1) * t))
		verts.append(Vector3((cell.x + 1) * t, y, (cell.y + 1) * t))
		verts.append(Vector3((cell.x + 1) * t, y, cell.y * t))
		for _i in 4:
			normals.append(Vector3.UP)
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func pad_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("40e0ff")
	m.emission_enabled = true
	m.emission = Color("40e0ff")
	m.emission_energy_multiplier = 1.6
	return m


static func build_rails(track: TrackData) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var t := float(track.tile)
	var post := Color("c23b3b")
	var post_alt := Color("e8e2d4")
	var rail := Color("9aa0a8")
	for ty in track.height:
		var row := track.rows[ty] if ty < track.rows.size() else ""
		for tx in track.width:
			var kind := row.substr(tx, 1) if tx < row.length() else "G"
			if not is_road_cell(kind):
				continue
			var edges := [
				[Vector2i(tx, ty - 1), Vector3(tx * t, 0, ty * t), Vector3((tx + 1) * t, 0, ty * t)],
				[Vector2i(tx, ty + 1), Vector3(tx * t, 0, (ty + 1) * t), Vector3((tx + 1) * t, 0, (ty + 1) * t)],
				[Vector2i(tx - 1, ty), Vector3(tx * t, 0, ty * t), Vector3(tx * t, 0, (ty + 1) * t)],
				[Vector2i(tx + 1, ty), Vector3((tx + 1) * t, 0, ty * t), Vector3((tx + 1) * t, 0, (ty + 1) * t)],
			]
			for edge in edges:
				var ncell: Vector2i = edge[0]
				var nkind := "B"
				if ncell.x >= 0 and ncell.y >= 0 and ncell.x < track.width and ncell.y < track.rows.size():
					var nrow := track.rows[ncell.y]
					if ncell.x < nrow.length():
						nkind = nrow.substr(ncell.x, 1)
				if nkind not in ["G", "S", "D", "W", "C"]:
					continue
				var a: Vector3 = edge[1]
				var b: Vector3 = edge[2]
				var mid := (a + b) * 0.5
				var pcolor := post if posmod(tx + ty, 2) == 0 else post_alt
				_push_box(verts, normals, colors, indices, mid + Vector3(-1.5, 0, -1.5), Vector3(3, 15, 3), pcolor, pcolor)
				var along := b - a
				var bar_center := (a + b) * 0.5 + Vector3(0, 12, 0)
				if absf(along.x) > absf(along.z):
					_push_box(verts, normals, colors, indices, bar_center + Vector3(-t * 0.5, -1.5, -1), Vector3(t, 3, 2), rail, rail)
				else:
					_push_box(verts, normals, colors, indices, bar_center + Vector3(-1, -1.5, -t * 0.5), Vector3(2, 3, t), rail, rail)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
