class_name GraphicsQuality
extends RefCounted

# One place that maps a Low/Medium/High/Ultra choice onto the renderer that is
# actually running. Forward+ (the Windows build) can take SSR, volumetric fog,
# SDFGI, TAA, FSR 2.2, motion blur, and Decal nodes. The web build is the
# Compatibility renderer and silently keeps the subset that renderer can draw.
# See docs/GRAPHICS_RESEARCH.md.

const PRESETS: Array[String] = ["low", "medium", "high", "ultra"]
const LUT_PATH := "res://assets/textures/grade_lut.png"


static func renderer() -> String:
	return str(RenderingServer.get_current_rendering_method())


static func default_for(method: String) -> String:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return "medium"
	if method == "forward_plus":
		return "high"
	return "medium"


static func active_preset() -> String:
	var raw := "auto"
	if Settings != null:
		raw = str(Settings.data.get("graphics", "auto")).to_lower()
	if raw in PRESETS:
		return raw
	return default_for(renderer())


static func profile(preset: String = "", renderer_name: String = "") -> Dictionary:
	var method := renderer_name if renderer_name != "" else renderer()
	var name := preset.to_lower()
	if name == "" or name == "auto" or name not in PRESETS:
		if preset == "" and renderer_name == "":
			name = active_preset()
		else:
			name = default_for(method)
	return profile_for(name, method)


static func profile_for(preset: String, method: String) -> Dictionary:
	var name := preset.to_lower()
	if name not in PRESETS:
		name = default_for(method)
	var level := PRESETS.find(name)
	var forward_plus := method == "forward_plus"
	# FSR 1 is a spatial upscale and runs on Compatibility. FSR 2.2 does not.
	var fsr2 := forward_plus and level >= 3
	var taa := forward_plus and level == 2
	var msaa := 0
	if not fsr2 and not taa:
		msaa = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][level]
	return {
		"preset": name,
		"level": level,
		"renderer": method,
		"forward_plus": forward_plus,
		"tonemap": "agx",
		"msaa": msaa,
		"taa": taa,
		"fsr2": fsr2,
		"fsr1": level == 0,
		"scale": 0.75 if level == 0 else 1.0,
		"glow": level >= 1,
		"glow_intensity": [0.0, 0.42, 0.55, 0.68][level],
		"glow_bloom": [0.0, 0.12, 0.2, 0.28][level],
		"ssao": level >= 1,
		"ssao_intensity": [0.0, 1.35, 2.1, 2.6][level],
		"ssil": forward_plus and level >= 3,
		"ssr": forward_plus and level >= 2,
		"volumetric_fog": forward_plus and level >= 2,
		"sdfgi": forward_plus and level >= 3,
		# Godot 4.7.2 has no Environment or CameraAttributes motion-blur property.
		# The 4.6 docs described one; this stable build does not ship it.
		"motion_blur": false,
		"reflections": level >= 1,
		"shadows": level >= 1,
		"shadow_blur": [1.4, 1.15, 0.7, 0.4][level],
		"shadow_distance": [140.0, 220.0, 300.0, 380.0][level],
		"soft_sun": forward_plus and level >= 2,
		"decal_nodes": forward_plus and level >= 2,
		"foliage": [6, 16, 28, 40][level],
		"adjustment": level >= 1,
		"hdri": true,
	}


static func apply_viewport(viewport: Viewport, preset: String = "", renderer_name: String = "") -> Dictionary:
	if viewport == null:
		return {}
	var p := profile(preset, renderer_name)
	viewport.msaa_3d = int(p["msaa"]) as Viewport.MSAA
	viewport.use_taa = bool(p["taa"])
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	if bool(p["fsr2"]):
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		viewport.scaling_3d_scale = 1.0
		viewport.fsr_sharpness = 0.35
	elif bool(p["fsr1"]):
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		viewport.scaling_3d_scale = float(p["scale"])
		viewport.fsr_sharpness = 0.2
	else:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = 1.0
	return p


static func apply_environment(env: Environment, night: bool, rain: bool, lean: bool, preset: String = "") -> Dictionary:
	var p := profile(preset)
	if lean:
		p = p.duplicate()
		p["glow"] = false
		p["ssao"] = false
		p["ssil"] = false
		p["ssr"] = false
		p["volumetric_fog"] = false
		p["sdfgi"] = false
		p["motion_blur"] = false
		p["reflections"] = false
		p["shadows"] = false
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.96 if night else 1.08
	env.tonemap_white = 6.0
	env.glow_enabled = bool(p["glow"])
	env.glow_intensity = float(p["glow_intensity"]) * (1.2 if night else 1.0)
	env.glow_bloom = float(p["glow_bloom"])
	env.glow_hdr_threshold = 0.85
	env.ssao_enabled = bool(p["ssao"])
	env.ssao_radius = 1.35 if bool(p["forward_plus"]) else 2.0
	env.ssao_intensity = float(p["ssao_intensity"])
	env.ssao_light_affect = 0.5
	env.ssao_horizon = 0.12
	env.ssil_enabled = bool(p["ssil"])
	env.ssil_radius = 2.5
	env.ssil_intensity = 1.15
	env.ssr_enabled = bool(p["ssr"])
	env.ssr_max_steps = 64 if int(p["level"]) >= 3 else 32
	env.ssr_fade_in = 0.08
	env.ssr_fade_out = 1.8
	env.ssr_depth_tolerance = 0.22
	env.volumetric_fog_enabled = bool(p["volumetric_fog"])
	env.volumetric_fog_density = 0.009 if rain else (0.0045 if night else 0.0032)
	if rain:
		env.volumetric_fog_albedo = Color(0.62, 0.66, 0.7)
	elif night:
		env.volumetric_fog_albedo = Color(0.42, 0.5, 0.72)
	else:
		env.volumetric_fog_albedo = Color(0.75, 0.8, 0.86)
	env.volumetric_fog_length = 850.0
	env.volumetric_fog_gi_inject = 0.3 if bool(p["sdfgi"]) else 0.0
	env.volumetric_fog_ambient_inject = 0.35
	env.sdfgi_enabled = bool(p["sdfgi"])
	if bool(p["sdfgi"]):
		env.sdfgi_use_occlusion = true
		env.sdfgi_bounce_feedback = 0.35
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 1.6
		env.sdfgi_cascade0_distance = 80.0
		env.sdfgi_max_distance = 720.0
		env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
		env.sdfgi_energy = 0.5
	env.adjustment_enabled = bool(p["adjustment"])
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.06
	if bool(p["adjustment"]) and ResourceLoader.exists(LUT_PATH):
		env.adjustment_color_correction = load(LUT_PATH)
	else:
		env.adjustment_color_correction = null
	return p
