class_name Net
extends Node
## Cliente WebSocket do servidor de salas (veja net_server.gd para o protocolo). Funciona na web,
## no PC e no Android. Mensagens de controle chegam por "msg"; dados do jogo (estado dos carros, voz) por "bin".

signal msg(d: Dictionary)
signal bin(kind: int, from: int, data: PackedByteArray)
signal status_changed(state: String)

var ws: WebSocketPeer = null
var state := "off"      # off | connecting | open | closed
var my_id := 0
var room := {}          # {"code", "name", "host", "members": {id: name}}
var url := ""
var ping_ms := 0.0
var _ping_t := 0.0
var _hello_name := ""


func connect_to(u: String, player_name: String) -> Error:
	close()
	url = u.strip_edges()
	if not (url.begins_with("ws://") or url.begins_with("wss://")):
		url = "ws://" + url
	if url.count(":") < 2:
		url += ":9080"
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 1 << 20
	ws.outbound_buffer_size = 1 << 20
	ws.max_queued_packets = 4096
	_hello_name = player_name
	var err := ws.connect_to_url(url)
	state = "connecting" if err == OK else "closed"
	status_changed.emit(state)
	return err


func close() -> void:
	if ws:
		ws.close()
	ws = null
	state = "off"
	my_id = 0
	room = {}


func is_open() -> bool:
	return ws != null and state == "open"


func in_room() -> bool:
	return is_open() and not room.is_empty()


func is_host() -> bool:
	return in_room() and int(room.host) == my_id


func send(d: Dictionary) -> void:
	if is_open():
		ws.send_text(JSON.stringify(d))


func room_send(d: Dictionary, to := -1) -> void:
	var m := {"t": "room", "d": d}
	if to >= 0:
		m.to = to
	send(m)


func send_bin(kind: int, data: PackedByteArray) -> void:
	if not in_room():
		return
	var out := PackedByteArray([kind])
	out.append_array(data)
	ws.send(out)


func _process(dt: float) -> void:
	if ws == null:
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and state != "open":
		state = "open"
		send({"t": "hello", "name": _hello_name})
		status_changed.emit(state)
	elif st == WebSocketPeer.STATE_CLOSED and state != "closed":
		state = "closed"
		room = {}
		status_changed.emit(state)
		return
	if state != "open":
		return
	_ping_t -= dt
	if _ping_t <= 0.0:
		_ping_t = 2.0
		send({"t": "ping", "c": Time.get_ticks_msec()})
	while ws.get_available_packet_count() > 0:
		var pkt := ws.get_packet()
		if ws.was_string_packet():
			var d = JSON.parse_string(pkt.get_string_from_utf8())
			if d is Dictionary:
				_on_msg(d)
		elif pkt.size() >= 3:
			bin.emit(pkt[0], pkt.decode_u16(1), pkt.slice(3))


func _on_msg(d: Dictionary) -> void:
	match String(d.get("t", "")):
		"welcome":
			my_id = int(d.id)
		"pong":
			ping_ms = lerpf(ping_ms, float(Time.get_ticks_msec() - int(d.c)), 0.5 if ping_ms > 0.0 else 1.0)
		"joined":
			var mem := {}
			for m in d.members:
				mem[int(m.id)] = String(m.name)
			room = {"code": String(d.code), "name": String(d.name), "host": int(d.host), "members": mem, "max": int(d.get("max", 8))}
			my_id = int(d.me)
		"peer_join":
			if not room.is_empty():
				room.members[int(d.id)] = String(d.name)
		"peer_leave":
			if not room.is_empty():
				room.members.erase(int(d.id))
		"host":
			if not room.is_empty():
				room.host = int(d.id)
	msg.emit(d)
