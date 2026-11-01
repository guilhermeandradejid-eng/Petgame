extends Node
## Thin wrapper over Godot's high-level multiplayer (ENet, listen-server, up to 4 players).

signal joined          # client connected to host
signal join_failed
signal host_lost

const PORT := 24565
const MAX_PLAYERS := 4

var mode := "offline"   # offline | host | client
var address := "127.0.0.1"


func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): joined.emit())
	multiplayer.connection_failed.connect(func(): mode = "offline"; join_failed.emit())
	multiplayer.server_disconnected.connect(func(): mode = "offline"; host_lost.emit())


func host(port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "host"
	return OK


func join(addr: String, port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "client"
	address = addr
	return OK


func go_offline() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = "offline"
