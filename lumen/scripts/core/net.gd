extends Node
## Camada de conexao: um jogador hospeda (servidor ENet) e os amigos entram pelo IP.
## O host tenta abrir a porta sozinho no roteador via UPnP (numa thread, pois bloqueia).

signal joined                    # conexao com o host concluida
signal join_failed
signal session_closed(reason)    # host caiu ou saimos
signal peer_joined(id)
signal peer_left(id)
signal upnp_result(ok, external_ip)

const DEFAULT_PORT := 24565
const MAX_PLAYERS := 4

var active := false
var hosting := false
var port := DEFAULT_PORT
var external_ip := ""
var upnp_ok := false
var _upnp_thread: Thread
var _upnp: UPNP

func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void: peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)

func my_id() -> int:
	return multiplayer.get_unique_id()

func is_host() -> bool:
	return multiplayer.is_server()

## Quem mandou o RPC em execucao (o proprio id quando a chamada e local).
func sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return my_id() if id == 0 else id

func host(p_port: int = DEFAULT_PORT, use_upnp: bool = true) -> Error:
	leave(false)
	port = p_port
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		# porta ocupada: joga offline mesmo assim (ninguem consegue entrar)
		push_warning("Nao consegui abrir a porta %d (%s). Jogando offline." % [port, error_string(err)])
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		active = true
		hosting = true
		return err
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	active = true
	hosting = true
	if use_upnp and DisplayServer.get_name() != "headless":
		_start_upnp()
	return OK

func join(address: String, p_port: int = DEFAULT_PORT) -> Error:
	leave(false)
	port = p_port
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	hosting = false
	return OK

func leave(emit: bool = true) -> void:
	if hosting and upnp_ok and _upnp:
		_upnp.delete_port_mapping(port, "UDP")
	upnp_ok = false
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var was := active
	active = false
	hosting = false
	if emit and was:
		session_closed.emit("saiu")

func _on_connected() -> void:
	active = true
	joined.emit()

func _on_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	join_failed.emit()

func _on_server_lost() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	session_closed.emit("O host encerrou a sala.")

# ------------------------------------------------------------------ UPnP
func _start_upnp() -> void:
	if _upnp_thread and _upnp_thread.is_started():
		return
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_setup.bind(port))

func _upnp_setup(p: int) -> void:
	var upnp := UPNP.new()
	var ok := false
	var ip := ""
	if upnp.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS:
		var gw := upnp.get_gateway()
		if gw and gw.is_valid_gateway():
			var r := upnp.add_port_mapping(p, p, "Lumen", "UDP", 0)
			if r == UPNP.UPNP_RESULT_SUCCESS:
				ok = true
			ip = upnp.query_external_address()
	_upnp_finished.call_deferred(upnp, ok, ip)

func _upnp_finished(upnp: UPNP, ok: bool, ip: String) -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
	_upnp = upnp
	upnp_ok = ok
	external_ip = ip
	upnp_result.emit(ok, ip)

func local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		out.append(a)
	return out

func _exit_tree() -> void:
	if _upnp_thread and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()
