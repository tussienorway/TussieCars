class_name NetManager
extends Node

signal players_changed
signal discovered(hosts: Array)
signal status_changed(text: String)
signal race_begin(config: Dictionary)
signal race_result_received(result: Dictionary)
signal disconnected

var role := "idle"
var peer: ENetMultiplayerPeer
var self_name := "Driver"
var self_paint := "cyan"
var track_id := "harbor_loop"
var port := NetDefs.PORT
var players: Array = []
var remote_inputs: Dictionary = {}
var pending_snap := {}
var has_snap := false
var last_result := {}
var has_result := false
var discovered_hosts: Array = []

var _udp: PacketPeerUDP
var _listening := false
var _broadcast_time := 0.0
var _lobby_push_cd := 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_conn_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


func reset() -> void:
	leave()
	role = "idle"
	players.clear()
	remote_inputs.clear()
	pending_snap = {}
	has_snap = false
	has_result = false
	last_result = {}
	discovered_hosts.clear()
	emit_signal("players_changed")


func local_ips() -> Array:
	var out := []
	for addr in IP.get_local_addresses():
		if addr.contains(".") and not addr.begins_with("127."):
			out.append(addr)
	return out


func host_lobby(host_name: String, paint: String, wanted_track: String, wanted_port: int) -> String:
	leave()
	self_name = NetDefs.clean_player_name(host_name)
	self_paint = NetDefs.clean_paint(paint)
	track_id = wanted_track
	port = clampi(wanted_port, 1024, 65535)
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, NetDefs.MAX_HUMANS)
	if err != OK:
		return "Could not open port %d." % port
	multiplayer.multiplayer_peer = peer
	role = "host"
	players = [{"peer_id": 1, "name": self_name, "paint": self_paint, "index": 0}]
	remote_inputs.clear()
	_broadcast_time = 0.0
	_lobby_push_cd = 0.0
	_set_status("Hosting on port %d." % port)
	emit_signal("players_changed")
	return ""


func join_lobby(ip: String, wanted_port: int, join_name: String, paint: String) -> String:
	leave()
	var clean_ip := ip.strip_edges()
	if clean_ip == "":
		return "Enter the host IP address."
	self_name = NetDefs.clean_player_name(join_name)
	self_paint = NetDefs.clean_paint(paint)
	port = clampi(wanted_port, 1024, 65535)
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(clean_ip, port)
	if err != OK:
		return "Could not connect to %s." % clean_ip
	multiplayer.multiplayer_peer = peer
	role = "client_connecting"
	_set_status("Connecting to %s:%d ..." % [clean_ip, port])
	return ""


func leave() -> void:
	stop_discovery()
	if peer != null:
		peer.close()
		peer = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	if role != "idle":
		role = "idle"
		emit_signal("disconnected")


func is_host() -> bool:
	return role == "host" or role == "host_racing"


func is_client() -> bool:
	return role == "client" or role == "client_racing" or role == "client_connecting"


func is_racing() -> bool:
	return role == "host_racing" or role == "client_racing"


func back_to_lobby() -> void:
	if role == "host_racing":
		role = "host"
	elif role == "client_racing":
		role = "client"
	has_snap = false
	has_result = false
	pending_snap = {}
	last_result = {}


func my_index() -> int:
	for p in players:
		if int(p.get("peer_id", -1)) == multiplayer.get_unique_id():
			return int(p.get("index", 0))
	if role == "client_connecting":
		return 0
	return 0


func start_listening() -> void:
	if _listening:
		return
	_udp = PacketPeerUDP.new()
	var err := _udp.bind(NetDefs.DISCOVERY_PORT)
	if err != OK:
		return
	_listening = true
	discovered_hosts.clear()


func stop_discovery() -> void:
	_listening = false
	if _udp != null:
		_udp.close()
		_udp = null


func _process(delta: float) -> void:
	if _listening and _udp != null:
		while _udp.get_available_packet_count() > 0:
			var pkt := _udp.get_packet()
			var from := _udp.get_packet_ip()
			var parsed = JSON.parse_string(pkt.get_string_from_ascii())
			if typeof(parsed) == TYPE_DICTIONARY:
				var info := NetDefs.parse_discovery(parsed)
				if not info.is_empty():
					info["ip"] = from
					_add_discovered(info)
	if role == "host":
		_broadcast_time -= delta
		if _broadcast_time <= 0.0:
			_broadcast_time = 2.0
			_send_beacon()
		_lobby_push_cd -= delta
		if _lobby_push_cd <= 0.0:
			_lobby_push_cd = 0.5
			_push_lobby.rpc(players, track_id)


func _send_beacon() -> void:
	var sock := PacketPeerUDP.new()
	sock.set_broadcast_enabled(true)
	var pkt := JSON.stringify(NetDefs.discovery_packet(self_name + "'s race", track_id, players.size(), port))
	sock.set_dest_address("255.255.255.255", NetDefs.DISCOVERY_PORT)
	sock.put_packet(pkt.to_ascii_buffer())
	sock.close()


func _add_discovered(info: Dictionary) -> void:
	for i in discovered_hosts.size():
		if str(discovered_hosts[i].get("ip", "")) == str(info.get("ip", "")) and int(discovered_hosts[i].get("port", 0)) == int(info.get("port", 0)):
			discovered_hosts[i] = info
			emit_signal("discovered", discovered_hosts)
			return
	discovered_hosts.append(info)
	emit_signal("discovered", discovered_hosts)


func set_track(next: String) -> void:
	if role != "host":
		return
	track_id = next
	_push_lobby.rpc(players, track_id)
	emit_signal("players_changed")


func kick(index: int) -> void:
	if role != "host":
		return
	for p in players:
		if int(p.get("index", -1)) == index and int(p.get("peer_id", 1)) != 1:
			peer.disconnect_peer(int(p["peer_id"]))
			break


func begin_net_race() -> void:
	if role != "host":
		return
	if players.size() < 2:
		_set_status("Need at least 2 players to start.")
		return
	var humans := []
	for p in players:
		humans.append({"name": str(p.get("name", "Driver")), "paint": str(p.get("paint", "cyan")), "peer_id": int(p.get("peer_id", 1)), "index": int(p.get("index", 0))})
	humans.sort_custom(func(a, b): return int(a["index"]) < int(b["index"]))
	var config := {"track_id": track_id, "humans": humans, "difficulty": "pro", "tier": "club"}
	role = "host_racing"
	_begin_race.rpc(config)
	emit_signal("race_begin", config)


func _on_peer_connected(id: int) -> void:
	if role != "host":
		return
	var idx := players.size()
	if idx >= NetDefs.MAX_HUMANS:
		peer.disconnect_peer(id)
		return
	_request_identity.rpc_id(id)
	_lobby_push_cd = 0.0


func _on_peer_disconnected(id: int) -> void:
	if role != "host" and role != "host_racing":
		return
	var kept := []
	for p in players:
		if int(p.get("peer_id", -1)) != id:
			kept.append(p)
	players = kept
	_reindex()
	remote_inputs.erase(id)
	if role == "host":
		_push_lobby.rpc(players, track_id)
	emit_signal("players_changed")


func _on_connected() -> void:
	if role == "client_connecting":
		role = "client"
		_set_status("Connected. Waiting for the host.")
		_announce.rpc(self_name, self_paint)


func _on_conn_failed() -> void:
	_set_status("Connection failed. Check the IP and port.")
	role = "idle"
	emit_signal("disconnected")


func _on_server_gone() -> void:
	_set_status("Lost the host.")
	leave()
	emit_signal("disconnected")


func _reindex() -> void:
	players.sort_custom(func(a, b): return int(a.get("peer_id", 0)) < int(b.get("peer_id", 0)))
	for i in players.size():
		players[i]["index"] = i


func _set_status(text: String) -> void:
	emit_signal("status_changed", text)


@rpc("any_peer", "call_remote", "reliable")
func _request_identity() -> void:
	_announce.rpc_id(1, self_name, self_paint)


@rpc("any_peer", "call_remote", "reliable")
func _announce(join_name: String, paint: String) -> void:
	if role != "host":
		return
	var from := multiplayer.get_remote_sender_id()
	for p in players:
		if int(p.get("peer_id", -1)) == from:
			p["name"] = NetDefs.clean_player_name(join_name)
			p["paint"] = NetDefs.clean_paint(paint)
			_push_lobby.rpc(players, track_id)
			emit_signal("players_changed")
			return
	if players.size() >= NetDefs.MAX_HUMANS:
		return
	players.append({"peer_id": from, "name": NetDefs.clean_player_name(join_name), "paint": NetDefs.clean_paint(paint), "index": players.size()})
	_push_lobby.rpc(players, track_id)
	emit_signal("players_changed")


@rpc("authority", "call_remote", "reliable")
func _push_lobby(lobby: Array, next_track: String) -> void:
	players = lobby
	track_id = next_track
	emit_signal("players_changed")


@rpc("authority", "call_remote", "reliable")
func _begin_race(config: Dictionary) -> void:
	if role == "client":
		role = "client_racing"
	track_id = str(config.get("track_id", track_id))
	players.clear()
	for h in config.get("humans", []):
		players.append(h)
	has_snap = false
	has_result = false
	emit_signal("race_begin", config)


@rpc("any_peer", "call_remote", "unreliable")
func _submit_input(input: Dictionary) -> void:
	if role != "host_racing":
		return
	remote_inputs[multiplayer.get_remote_sender_id()] = NetDefs.sanitize_input(input)


@rpc("authority", "call_remote", "unreliable")
func _push_snap(snap: Dictionary) -> void:
	pending_snap = snap
	has_snap = true


@rpc("authority", "call_remote", "reliable")
func _push_result(result: Dictionary) -> void:
	last_result = result
	has_result = true
	emit_signal("race_result_received", result)


func send_input(input: Dictionary) -> void:
	if role != "client_racing":
		return
	_submit_input.rpc_id(1, NetDefs.sanitize_input(input))


func broadcast_snap(snap: Dictionary) -> void:
	if role != "host_racing":
		return
	_push_snap.rpc(snap)


func broadcast_result(result: Dictionary) -> void:
	if role != "host_racing":
		return
	_push_result.rpc(result)


func input_for(peer_id: int) -> Dictionary:
	return NetDefs.sanitize_input(remote_inputs.get(peer_id, NetDefs.neutral_input()))


func take_snapshot() -> Dictionary:
	has_snap = false
	var out := pending_snap
	pending_snap = {}
	return out


func take_result() -> Dictionary:
	has_result = false
	var out := last_result
	last_result = {}
	return out
