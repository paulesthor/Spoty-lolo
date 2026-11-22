extends Node
# Online coop (autoload "Net"). The host's PC runs the whole game; each comrade who joins runs
# their own copy of the map, moves their own comrade, and draws what the host sends:
# capitalists, pickups, chests, health, levels, card choices. Up to 4 comrades.
#
#   host:   Net.host(name, char, skin)  -> lobby -> Net.start_game()
#   client: Net.join(ip, name, char, skin) -> lobby -> waits for the host
#
# Transport: ENet (UDP) on PORT. The host tries to open the port on the router by UPnP;
# otherwise the port has to be forwarded by hand (or both PCs share a virtual LAN).

signal lobby_changed
signal status_changed

const PORT := 24517
const MAX_PLAYERS := 4
const SNAP_RATE := 15.0          # snapshots per second sent to each comrade
const INTEREST := 48.0           # capitalists sent to a comrade: those within this radius of them

var active := false              # an online game is set up (host or client)
var is_host := false
var my_idx := 0
var lobby: Array = []            # [{peer, name, char, skin}] index = comrade index; host is 0
var settings := {"zone": 1, "tier": 1}
var status := ""
var public_ip := ""
var local_ip := ""
var game                         # the running game scene (it registers itself)
var run_seed := 0
var in_game := false
var ready_peers := {}            # host: peers that finished loading the zone
var _snap_t := 0.0
var _state_t := 0.0
var _upnp: UPNP
var _upnp_thread: Thread
var _buffer: Array = []          # client: events received before the game scene is ready

func is_client() -> bool:
	return active and not is_host

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and not a.begins_with("172.17.")):
			local_ip = a
			break

func _set_status(t: String):
	status = t
	status_changed.emit()

# ---------------------------------------------------------------- hosting / joining
func host(pname: String, char_id: String, skin: int) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		_set_status("Impossible d'ouvrir le port %d (déjà utilisé ?)" % PORT)
		return false
	multiplayer.multiplayer_peer = peer
	active = true; is_host = true; my_idx = 0
	lobby = [{"peer": 1, "name": pname, "char": char_id, "skin": skin}]
	_set_status("Partie ouverte. Donne ton adresse à tes camarades.")
	lobby_changed.emit()
	_open_router_port()
	return true

func join(ip: String, pname: String, char_id: String, skin: int) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var parts := ip.strip_edges().split(":")
	var port := PORT if parts.size() < 2 else int(parts[1])
	var err := peer.create_client(parts[0], port)
	if err != OK:
		_set_status("Adresse invalide.")
		return false
	multiplayer.multiplayer_peer = peer
	active = true; is_host = false
	set_meta("hello", [pname, char_id, skin])
	_set_status("Connexion à %s…" % parts[0])
	return true

func leave():
	if multiplayer.multiplayer_peer and active:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	if _upnp and public_ip != "":
		_upnp.delete_port_mapping(PORT, "UDP")
	active = false; is_host = false; in_game = false
	lobby.clear(); ready_peers.clear(); _buffer.clear()
	game = null
	Meta.run_party = []

# UPnP in a thread (it can take a few seconds): opens the UDP port on the box and finds the public address
func _open_router_port():
	_upnp_thread = Thread.new()
	_upnp_thread.start(func():
		var u := UPNP.new()
		var r := u.discover(2000, 2)
		var msg := ""
		if r == UPNP.UPNP_RESULT_SUCCESS and u.get_gateway() and u.get_gateway().is_valid_gateway():
			var m := u.add_port_mapping(PORT, PORT, "Communiste Land", "UDP")
			var ext := u.query_external_address()
			if m == UPNP.UPNP_RESULT_SUCCESS:
				msg = "ok|" + ext
			else:
				msg = "noport|" + ext
		else:
			msg = "nogw|"
		call_deferred("_upnp_done", msg, u))

func _upnp_done(msg: String, u: UPNP):
	if _upnp_thread: _upnp_thread.wait_to_finish(); _upnp_thread = null
	var p := msg.split("|")
	public_ip = p[1] if p.size() > 1 else ""
	match p[0]:
		"ok":
			_upnp = u
			_set_status("Box configurée automatiquement. Adresse à donner : %s" % public_ip)
		"noport":
			_set_status("La box refuse d'ouvrir le port %d (UDP). Ouvre-le à la main ou utilisez un réseau virtuel. Adresse : %s" % [PORT, public_ip])
		_:
			_set_status("Box introuvable (UPnP). Ouvre le port %d UDP à la main, ou passez par un réseau virtuel (Radmin VPN, ZeroTier…)." % PORT)

# ---------------------------------------------------------------- lobby
func _on_peer_connected(id: int):
	if is_host: _set_status("Un camarade se connecte…")

func _on_peer_disconnected(id: int):
	if not is_host: return
	for i in lobby.size():
		if lobby[i]["peer"] == id:
			if in_game and game:
				game.comrade_left(i)
				lobby[i]["peer"] = -1
			else:
				lobby.remove_at(i)
			break
	ready_peers.erase(id)
	_push_lobby()
	_set_status("Un camarade est parti.")

func _on_connected():
	var h: Array = get_meta("hello", ["Camarade", "stakhanov", 0])
	_rpc_hello.rpc_id(1, h[0], h[1], h[2])
	_set_status("Connecté. En attente de l'hôte…")

func _on_failed():
	_set_status("Connexion impossible. Vérifie l'adresse et que le port %d UDP est ouvert chez l'hôte." % PORT)
	active = false
	multiplayer.multiplayer_peer = null

func _on_server_lost():
	var was_in_game := in_game
	leave()
	_set_status("L'hôte a fermé la partie.")
	lobby_changed.emit()
	if was_in_game:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/online.tscn")

@rpc("any_peer", "reliable")
func _rpc_hello(pname: String, char_id: String, skin: int):
	if not is_host: return
	var id := multiplayer.get_remote_sender_id()
	if lobby.size() >= MAX_PLAYERS or in_game:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	if not Meta.CHARACTERS.has(char_id): char_id = "stakhanov"
	lobby.append({"peer": id, "name": pname.substr(0, 16), "char": char_id, "skin": clampi(skin, 0, 2)})
	_push_lobby()
	_set_status("%s a rejoint la partie." % pname)

@rpc("any_peer", "reliable")
func _rpc_pick(char_id: String, skin: int):
	if not is_host: return
	var id := multiplayer.get_remote_sender_id()
	for l in lobby:
		if l["peer"] == id and Meta.CHARACTERS.has(char_id):
			l["char"] = char_id; l["skin"] = clampi(skin, 0, 2)
	_push_lobby()

func pick(char_id: String, skin: int):
	if is_host:
		lobby[0]["char"] = char_id; lobby[0]["skin"] = skin
		_push_lobby()
	elif active:
		_rpc_pick.rpc_id(1, char_id, skin)

func set_setting(k: String, v):
	settings[k] = v
	_push_lobby()

func _push_lobby():
	lobby_changed.emit()
	if is_host and active: _rpc_lobby.rpc(lobby, settings)

@rpc("authority", "reliable")
func _rpc_lobby(l: Array, st: Dictionary):
	lobby = l
	settings = st
	for i in lobby.size():
		if lobby[i]["peer"] == multiplayer.get_unique_id(): my_idx = i
	lobby_changed.emit()

# ---------------------------------------------------------------- starting a zone
func _party() -> Array:
	var out := []
	for i in lobby.size():
		out.append({"char": lobby[i]["char"], "skin": lobby[i]["skin"], "name": lobby[i]["name"], "remote": i != my_idx, "peer": lobby[i]["peer"]})
	return out

# host: lobby -> first zone
func start_game():
	if not is_host: return
	Meta.run_zone = int(settings.get("zone", 1))
	Meta.run_tier = int(settings.get("tier", 1))
	Meta.run_endless = false
	Meta.run_char = lobby[0]["char"]
	Meta.carry = {}
	_launch(Meta.run_zone)

# host: the door was taken, everybody moves on
func host_next_zone(z: int):
	if not is_host: return
	_launch(z, false)

func _launch(z: int, change_scene := true):
	run_seed = 1917 + randi() % 100000
	in_game = true
	ready_peers.clear()
	var params := {"seed": run_seed, "zone": z, "tier": Meta.run_tier, "endless": Meta.run_endless, "lobby": lobby}
	_rpc_start.rpc(params)
	Meta.run_party = _party()
	if change_scene:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main.tscn")

@rpc("authority", "reliable")
func _rpc_start(params: Dictionary):
	run_seed = params["seed"]
	lobby = params["lobby"]
	for i in lobby.size():
		if lobby[i]["peer"] == multiplayer.get_unique_id(): my_idx = i
	Meta.run_zone = params["zone"]
	Meta.run_tier = params["tier"]
	Meta.run_endless = params["endless"]
	Meta.carry = {}
	Meta.run_party = _party()
	in_game = true
	_buffer.clear()
	game = null
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# client: the zone is built, tell the host
func client_ready():
	if is_client(): _rpc_ready.rpc_id(1)

@rpc("any_peer", "reliable")
func _rpc_ready():
	ready_peers[multiplayer.get_remote_sender_id()] = true

func all_ready() -> bool:
	for l in lobby:
		if l["peer"] > 1 and not ready_peers.has(l["peer"]): return false
	return true

func register_game(g):
	game = g
	if is_client():
		for ev in _buffer: g.net_event(ev[0], ev[1])
		_buffer.clear()

# ---------------------------------------------------------------- in game: host -> comrades
func _peer_of(idx: int) -> int:
	return lobby[idx]["peer"] if idx < lobby.size() else -1

func to_player(idx: int, ev: String, args: Array):
	if not is_host or not active: return
	var pid := _peer_of(idx)
	if pid > 1: _rpc_ev.rpc_id(pid, ev, args)

func event_all(ev: String, args: Array):
	if not is_host or not active or not in_game: return
	for l in lobby:
		if l["peer"] > 1: _rpc_ev.rpc_id(l["peer"], ev, args)

@rpc("authority", "reliable")
func _rpc_ev(ev: String, args: Array):
	if game == null or not is_instance_valid(game):
		_buffer.append([ev, args])
		return
	game.net_event(ev, args)

@rpc("authority", "unreliable_ordered")
func _rpc_snap(s: Dictionary):
	if game and is_instance_valid(game): game.net_snapshot(s)

# ---------------------------------------------------------------- in game: comrade -> host
@rpc("any_peer", "unreliable_ordered")
func _rpc_state(st: Dictionary):
	if not is_host or game == null: return
	var idx := _idx_of(multiplayer.get_remote_sender_id())
	if idx > 0: game.net_state(idx, st)

@rpc("any_peer", "reliable")
func _rpc_cmd(cmd: String, args: Array):
	if not is_host or game == null: return
	var idx := _idx_of(multiplayer.get_remote_sender_id())
	if idx > 0: game.net_cmd(idx, cmd, args)

func send_cmd(cmd: String, args: Array):
	if is_client(): _rpc_cmd.rpc_id(1, cmd, args)

func _idx_of(pid: int) -> int:
	for i in lobby.size():
		if lobby[i]["peer"] == pid: return i
	return -1

func _process(d: float):
	if not active or not in_game or game == null or not is_instance_valid(game): return
	if is_host:
		_snap_t -= d
		if _snap_t <= 0.0:
			_snap_t = 1.0 / SNAP_RATE
			for i in range(1, lobby.size()):
				var pid: int = lobby[i]["peer"]
				if pid > 1 and ready_peers.has(pid):
					_rpc_snap.rpc_id(pid, game.build_snapshot(i))
	else:
		_state_t -= d
		if _state_t <= 0.0:
			_state_t = 1.0 / 30.0
			var st: Dictionary = game.local_net_state()
			if not st.is_empty(): _rpc_state.rpc_id(1, st)
