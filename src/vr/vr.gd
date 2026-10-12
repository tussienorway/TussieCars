class_name VR
extends RefCounted

## Sim units are 1 px = 10 cm, so ten world units make one real metre in a race.
const WORLD_SCALE := 10.0
const RATE_QUEST := 72.0
const RATE_MAX := 90.0

static var sim := false
static var xr: XRInterface = null
static var refresh := 0.0
static var _xr_viewport: Viewport
static var _webxr_hooked := false
static var _started_cb := Callable()
static var _failed_cb := Callable()
static var _ended_cb := Callable()


static func configure(root: Viewport) -> bool:
	sim = OS.get_cmdline_user_args().has("--vr-sim")
	_xr_viewport = root
	if sim:
		return true
	# OpenXR is already running on Quest and PC VR. Do not start WebXR here:
	# that call needs a click, and a missing headset must not block the flat game.
	xr = XRServer.find_interface("OpenXR")
	if headset():
		_enable_xr_viewport(root)
		return true
	xr = null
	return false


static func webxr_available() -> bool:
	return OS.has_feature("web") and XRServer.find_interface("WebXR") != null


## Ask the browser for an immersive session. Flat play keeps running if this fails.
static func start_webxr(root: Viewport, started: Callable, failed: Callable, ended: Callable) -> void:
	var webxr := XRServer.find_interface("WebXR")
	if webxr == null:
		if failed.is_valid():
			failed.call("WebXR is not available in this browser.")
		return
	_xr_viewport = root
	_started_cb = started
	_failed_cb = failed
	_ended_cb = ended
	xr = webxr
	webxr.set("session_mode", "immersive-vr")
	webxr.set("requested_reference_space_types", "bounded-floor, local-floor, local")
	webxr.set("required_features", "")
	webxr.set("optional_features", "local-floor, bounded-floor")
	if not _webxr_hooked:
		webxr.connect("session_started", _on_session_started)
		webxr.connect("session_failed", _on_session_failed)
		webxr.connect("session_ended", _on_session_ended)
		_webxr_hooked = true
	if not bool(webxr.call("initialize")):
		xr = null
		if failed.is_valid():
			failed.call("Could not start VR. Keep playing on screen.")


static func _on_session_started() -> void:
	if _xr_viewport != null:
		_enable_xr_viewport(_xr_viewport)
	if _started_cb.is_valid():
		_started_cb.call()


static func _on_session_failed(message: String) -> void:
	if xr != null and xr.get_class() == "WebXRInterface":
		xr = null
	var text := message if message != "" else "VR headset was not started."
	if _failed_cb.is_valid():
		_failed_cb.call(text + " Keep playing on screen.")


static func _on_session_ended() -> void:
	if _xr_viewport != null:
		_xr_viewport.use_xr = false
	if xr != null and xr.get_class() == "WebXRInterface":
		xr = null
	if _ended_cb.is_valid():
		_ended_cb.call()


static func _enable_xr_viewport(root: Viewport) -> void:
	root.use_xr = true
	root.msaa_3d = Viewport.MSAA_2X
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# OpenXRInterface is not in the web export, so this stays untyped.
	if xr != null and xr.get_class() == "OpenXRInterface":
		_pick_refresh(xr)
		if not xr.is_connected("pose_recentered", recenter):
			xr.connect("pose_recentered", recenter)
		recenter()


static func _pick_refresh(openxr: Object) -> void:
	var want := RATE_QUEST if OS.has_feature("android") else RATE_MAX
	var best := 0.0
	for rate in openxr.call("get_available_display_refresh_rates"):
		var r := float(rate)
		if r <= want + 0.5 and r > best:
			best = r
	if best > 0.0:
		openxr.set("display_refresh_rate", best)
	var current := float(openxr.get("display_refresh_rate"))
	refresh = current if current > 0.0 else best
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
