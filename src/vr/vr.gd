class_name VR
extends RefCounted

## Sim units are 1 px = 10 cm, so ten world units make one real metre in a race.
const WORLD_SCALE := 10.0
const RATE_QUEST := 72.0
const RATE_MAX := 90.0

static var sim := false
static var xr: XRInterface = null
static var refresh := 0.0


static func configure(root: Viewport) -> bool:
	sim = OS.get_cmdline_user_args().has("--vr-sim")
	xr = XRServer.find_interface("OpenXR")
	if headset():
		root.use_xr = true
		root.msaa_3d = Viewport.MSAA_2X
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var openxr := xr as OpenXRInterface
		if openxr != null:
			_pick_refresh(openxr)
			if not openxr.pose_recentered.is_connected(recenter):
				openxr.pose_recentered.connect(recenter)
		recenter()
	return active()


static func _pick_refresh(openxr: OpenXRInterface) -> void:
	var want := RATE_QUEST if OS.has_feature("android") else RATE_MAX
	var best := 0.0
	for rate in openxr.get_available_display_refresh_rates():
		var r := float(rate)
		if r <= want + 0.5 and r > best:
			best = r
	if best > 0.0:
		openxr.display_refresh_rate = best
	refresh = openxr.display_refresh_rate if openxr.display_refresh_rate > 0.0 else best
	if refresh >= 60.0:
		Engine.physics_ticks_per_second = int(round(refresh))
		Engine.max_physics_steps_per_frame = 4


static func headset() -> bool:
	return xr != null and xr.is_initialized()


static func active() -> bool:
	return sim or headset()


static func recenter() -> void:
	if headset():
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, false)


static func yaw_facing(forward: Vector3) -> float:
	return atan2(-forward.x, -forward.z)


static func deadzone(value: float, dead: float = 0.12) -> float:
	if absf(value) < dead:
		return 0.0
	return signf(value) * (absf(value) - dead) / (1.0 - dead)


static func view_mode() -> String:
	return str(Settings.data.get("vr_view", "chase"))
