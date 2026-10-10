extends Node

var music: AudioStreamPlayer
var engine: AudioStreamPlayer
var _pool: Array = []
var current := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	engine = AudioStreamPlayer.new()
	engine.bus = "SFX"
	add_child(engine)
	for _i in 12:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_pool.append(player)


func play_music(track_name: String) -> void:
	if current == track_name and music.playing:
		return
	current = track_name
	var stream := _stream("res://assets/audio/%s.wav" % track_name, true)
	if stream == null:
		return
	music.stream = stream
	music.play()


func stop_music() -> void:
	current = ""
	music.stop()


func play_sfx(sfx_name: String, pitch: float = 1.0, volume: float = 1.0) -> void:
	var stream := _stream("res://assets/audio/%s.wav" % sfx_name, false)
	if stream == null:
		return
	var player: AudioStreamPlayer = _pool[0]
	for candidate in _pool:
		if not candidate.playing:
			player = candidate
			break
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = _db(volume)
	player.play()


func set_engine(speed_ratio: float, throttle: float, active: bool) -> void:
	if not active:
		if engine.playing:
			engine.stop()
		return
	if engine.stream == null:
		engine.stream = _stream("res://assets/audio/engine.wav", true)
	if engine.stream != null and not engine.playing:
		engine.play()
	engine.pitch_scale = lerpf(0.62, 1.55, clampf(speed_ratio, 0.0, 1.0))
	engine.volume_db = _db(lerpf(0.15, 0.55, clampf(throttle, 0.0, 1.0)) * clampf(0.35 + speed_ratio, 0.0, 1.0))


func _stream(path: String, looping: bool) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path)
	if stream is AudioStreamWAV and looping:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _db(value: float) -> float:
	if value <= 0.001:
		return -80.0
	return linear_to_db(value)
