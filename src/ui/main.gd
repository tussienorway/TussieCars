extends Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--probe"):
		add_child(load("res://tools/probe_tracks.gd").new())
		return
	if args.has("--test"):
		add_child(load("res://tests/suite.gd").new())
		return
	var app := App.new()
	if VR.configure(get_viewport()):
		var lobby := VrLobby.new()
		add_child(lobby)
		lobby.host_app(app)
	else:
		var layer := CanvasLayer.new()
		layer.layer = 30
		add_child(layer)
		layer.add_child(app)
		app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.bind_host(self)
	if args.has("--smoke"):
		app.call_deferred("start_smoke")
	elif args.has("--vr-smoke"):
		app.call_deferred("start_vr_smoke")
