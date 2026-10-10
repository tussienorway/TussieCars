extends Node

var path := "user://settings.json"
var data := {
	"master": 0.85,
	"music": 0.55,
	"sfx": 0.85,
	"fullscreen": false,
	"shake": true,
	"touch": "auto",
	"binds": {},
	"net_name": "",
	"net_paint": "cyan",
	"net_port": 7777,
	"net_track": "harbor_loop",
	"vr_view": "chase",
}
var listening := ""
var _joy_ready := false

const DEFAULTS := {
	"accelerate": [KEY_W, KEY_UP],
	"brake": [KEY_S, KEY_DOWN],
	"steer_left": [KEY_A, KEY_LEFT],
	"steer_right": [KEY_D, KEY_RIGHT],
	"fire_front": [KEY_C],
	"fire_rear": [KEY_V],
	"drop_mine": [KEY_X],
	"boost": [KEY_SHIFT],
	"drift": [KEY_SPACE],
	"pause": [KEY_ESCAPE],
	"p2_accelerate": [KEY_I],
	"p2_brake": [KEY_K],
	"p2_steer_left": [KEY_J],
	"p2_steer_right": [KEY_L],
	"p2_fire_front": [KEY_U],
	"p2_fire_rear": [KEY_P],
	"p2_drop_mine": [KEY_O],
	"p2_boost": [KEY_N],
	"p2_drift": [KEY_M],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_inputs()
	apply_audio()
	apply_window()


func load_settings() -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for key in data.keys():
		if parsed.has(key):
			data[key] = parsed[key]


func save_settings() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if bool(data.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func apply_audio() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	AudioServer.set_bus_volume_db(0, _db(float(data.get("master", 0.8))))
	var music := AudioServer.get_bus_index("Music")
	var sfx := AudioServer.get_bus_index("SFX")
	if music >= 0:
		AudioServer.set_bus_volume_db(music, _db(float(data.get("music", 0.5))))
	if sfx >= 0:
		AudioServer.set_bus_volume_db(sfx, _db(float(data.get("sfx", 0.8))))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _db(value: float) -> float:
	if value <= 0.001:
		return -80.0
	return linear_to_db(value)


func apply_inputs() -> void:
	var binds: Dictionary = data.get("binds", {})
	for action in DEFAULTS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		var existing := InputMap.action_get_events(action)
		for event in existing:
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		var keys = binds.get(action, DEFAULTS[action])
		for key in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(key) as Key
			InputMap.action_add_event(action, ev)
	if _joy_ready:
		return
	_joy_ready = true
	_joy_button("accelerate", JOY_BUTTON_A, 0)
	_joy_button("brake", JOY_BUTTON_B, 0)
	_joy_button("fire_front", JOY_BUTTON_RIGHT_SHOULDER, 0)
	_joy_button("drop_mine", JOY_BUTTON_LEFT_SHOULDER, 0)
	_joy_button("fire_rear", JOY_BUTTON_X, 0)
	_joy_button("boost", JOY_BUTTON_Y, 0)
	_joy_button("drift", JOY_BUTTON_LEFT_STICK, 0)
	_joy_axis("steer_left", "steer_right", JOY_AXIS_LEFT_X, 0)
	_joy_button("p2_accelerate", JOY_BUTTON_A, 1)
	_joy_button("p2_brake", JOY_BUTTON_B, 1)
	_joy_button("p2_fire_front", JOY_BUTTON_RIGHT_SHOULDER, 1)
	_joy_button("p2_drop_mine", JOY_BUTTON_LEFT_SHOULDER, 1)
	_joy_button("p2_fire_rear", JOY_BUTTON_X, 1)
	_joy_button("p2_boost", JOY_BUTTON_Y, 1)
	_joy_button("p2_drift", JOY_BUTTON_LEFT_STICK, 1)
	_joy_axis("p2_steer_left", "p2_steer_right", JOY_AXIS_LEFT_X, 1)
	_joy_button("pause", JOY_BUTTON_START, -1)


func _joy_button(action: String, button: JoyButton, device: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = device
	InputMap.action_add_event(action, ev)


func _joy_axis(neg_action: String, pos_action: String, axis: JoyAxis, device: int) -> void:
	var neg := InputEventJoypadMotion.new()
	neg.axis = axis
	neg.axis_value = -1.0
	neg.device = device
	InputMap.action_add_event(neg_action, neg)
	var pos := InputEventJoypadMotion.new()
	pos.axis = axis
	pos.axis_value = 1.0
	pos.device = device
	InputMap.action_add_event(pos_action, pos)


func read_drive(player_index: int) -> Dictionary:
	var prefix := "" if player_index == 0 else "p2_"
	var device := 0 if player_index == 0 else 1
	var throttle := 1.0 if Input.is_action_pressed(prefix + "accelerate") else 0.0
	var brake := 1.0 if Input.is_action_pressed(prefix + "brake") else 0.0
	var steer := Input.get_axis(prefix + "steer_left", prefix + "steer_right")
	if Input.get_connected_joypads().has(device):
		throttle = maxf(throttle, maxf(0.0, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)))
		brake = maxf(brake, maxf(0.0, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)))
	return {
		"throttle": throttle,
		"brake": brake,
		"steer": clampf(steer, -1.0, 1.0),
		"fire_front": Input.is_action_pressed(prefix + "fire_front"),
		"fire_rear": Input.is_action_pressed(prefix + "fire_rear"),
		"drop_mine": Input.is_action_pressed(prefix + "drop_mine"),
		"boost": Input.is_action_pressed(prefix + "boost"),
		"drift": Input.is_action_pressed(prefix + "drift"),
	}


func touch_active() -> bool:
	if VR.active():
		return false
	var mode := str(data.get("touch", "auto"))
	if mode == "on":
		return true
	if mode == "off":
		return false
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func set_bind(action: String, keycode: int) -> void:
	if not data.has("binds") or typeof(data["binds"]) != TYPE_DICTIONARY:
		data["binds"] = {}
	data["binds"][action] = [keycode]
	apply_inputs()
	save_settings()


func key_label(action: String) -> String:
	var binds: Dictionary = data.get("binds", {})
	var keys = binds.get(action, DEFAULTS.get(action, []))
	if keys.is_empty():
		return "-"
	return OS.get_keycode_string(int(keys[0]) as Key)


func shake_enabled() -> bool:
	return bool(data.get("shake", true))
