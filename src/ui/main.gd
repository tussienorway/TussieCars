extends Node

var app: App
var flat_layer: CanvasLayer
var lobby: VrLobby


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--probe") or args.has("--test"):
		set_process(false)
		if args.has("--probe"):
			add_child(load("res://tools/probe_tracks.gd").new())
		else:
			add_child(load("res://tests/suite.gd").new())
		return
	app = App.new()
	if VR.configure(get_viewport()):
		_mount_vr()
	else:
		_mount_flat()
	app.bind_host(self)
	if args.has("--smoke"):
		app.call_deferred("start_smoke")
	elif args.has("--vr-smoke"):
		app.call_deferred("start_vr_smoke")


func enter_webxr() -> void:
	VR.start_webxr(get_viewport(), _on_vr_session, _on_vr_failed, _on_vr_ended)


func _on_vr_session() -> void:
	_mount_vr()


func _on_vr_failed(message: String) -> void:
	if app != null:
		app.vr_notice(message)


func _on_vr_ended() -> void:
	get_viewport().use_xr = false
	if app != null and (app.race == null or not is_instance_valid(app.race)):
		_mount_flat()


func _mount_flat() -> void:
	if app.get_parent() != null:
		app.get_parent().remove_child(app)
	if lobby != null and is_instance_valid(lobby):
		lobby.queue_free()
		lobby = null
	flat_layer = CanvasLayer.new()
	flat_layer.layer = 30
	add_child(flat_layer)
	flat_layer.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _mount_vr() -> void:
	if lobby != null and is_instance_valid(lobby):
		return
	if app.get_parent() != null:
		app.get_parent().remove_child(app)
	if flat_layer != null and is_instance_valid(flat_layer):
		flat_layer.queue_free()
		flat_layer = null
	lobby = VrLobby.new()
	add_child(lobby)
	lobby.host_app(app)
