class_name NetServer
extends Node
## Servidor de salas do Wreck 'n' Roll (WebSocket). Não simula a corrida: guarda as salas, repassa mensagens
## entre quem está na mesma sala e escolhe o anfitrião (quem simula a IA). Roda:
##   • dedicado:  godot --headless --path minifuria -- --server --port=9080   (ou o executável do jogo com os mesmos argumentos)
##   • no próprio jogo (PC/Android): botão "HOSPEDAR AQUI" no menu online (rede local)
## Protocolo (texto = JSON de controle, binário = dados do jogo):
##   cliente -> {"t":"hello","name"} {"t":"list"} {"t":"create","name","max"} {"t":"join","code"} {"t":"leave"}
##              {"t":"room","d":{...},"to":id?}  {"t":"lock","open":bool} (anfitrião)
##   servidor -> {"t":"welcome","id"} {"t":"rooms","list"} {"t":"joined","code","name","host","members","me"}
##              {"t":"peer_join","id","name"} {"t":"peer_leave","id"} {"t":"host","id"} {"t":"err","msg"} {"t":"room","from","d"}
##   binário: o cliente manda [tipo u8][dados]; o servidor repassa aos outros da sala como [tipo u8][remetente u16][dados]

const MAX_ROOM := 8
const VERSION := 1

var tcp := TCPServer.new()
var tls: TLSOptions = null
var pending: Array = []      # [{"peer": StreamPeer, "ws": WebSocketPeer, "t": float}]
var clients := {}            # id -> {"ws", "name", "room"}
var rooms := {}              # código -> {"name", "host", "members": [ids], "max", "open"}
var next_id := 1
var port := 9080
var verbose := true


func start(p: int, bind := "*", cert_path := "", key_path := "") -> Error:
	port = p
	if cert_path != "" and key_path != "":
		var cert := X509Certificate.new()
		var key := CryptoKey.new()
		if cert.load(cert_path) == OK and key.load(key_path) == OK:
			tls = TLSOptions.server(key, cert)
	var err := tcp.listen(p, bind)
	if verbose:
		print("[servidor] ouvindo na porta %d (%s) %s" % [p, "wss" if tls else "ws", "OK" if err == OK else "ERRO %d" % err])
	return err


func stop() -> void:
	for id in clients.keys():
		(clients[id].ws as WebSocketPeer).close()
	clients.clear()
	rooms.clear()
	tcp.stop()


func _process(_dt: float) -> void:
	if not tcp.is_listening():
		return
	while tcp.is_connection_available():
		var conn: StreamPeerTCP = tcp.take_connection()
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = 1 << 20
		ws.outbound_buffer_size = 1 << 20
		ws.max_queued_packets = 4096
		var stream: StreamPeer = conn
		if tls:
			var st := StreamPeerTLS.new()
			st.accept_stream(conn, tls)
			stream = st
		pending.append({"ws": ws, "stream": stream, "t": Time.get_ticks_msec(), "accepted": tls == null})
		if tls == null:
			ws.accept_stream(stream)
	# conexões ainda fazendo o "aperto de mão"
	for i in range(pending.size() - 1, -1, -1):
		var pd: Dictionary = pending[i]
		var ws: WebSocketPeer = pd.ws
		if not pd.accepted:
			var st: StreamPeerTLS = pd.stream
			st.poll()
			if st.get_status() == StreamPeerTLS.STATUS_CONNECTED:
				ws.accept_stream(st)
				pd.accepted = true
			elif st.get_status() != StreamPeerTLS.STATUS_HANDSHAKING:
				pending.remove_at(i)
			continue
		ws.poll()
		var stt := ws.get_ready_state()
		if stt == WebSocketPeer.STATE_OPEN:
			var id := next_id
			next_id += 1
			clients[id] = {"ws": ws, "name": "?", "room": ""}
			pending.remove_at(i)
			_send(id, {"t": "welcome", "id": id, "ver": VERSION})
		elif stt == WebSocketPeer.STATE_CLOSED or Time.get_ticks_msec() - int(pd.t) > 8000:
			pending.remove_at(i)
	for id in clients.keys():
		var cl: Dictionary = clients[id]
		var ws: WebSocketPeer = cl.ws
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_drop(id)
			continue
		while ws.get_available_packet_count() > 0:
			var pkt := ws.get_packet()
			if ws.was_string_packet():
				var d = JSON.parse_string(pkt.get_string_from_utf8())
				if d is Dictionary:
					_handle(id, d)
			else:
				_relay_bin(id, pkt)


func _open(id: int) -> bool:
	return clients.has(id) and (clients[id].ws as WebSocketPeer).get_ready_state() == WebSocketPeer.STATE_OPEN


func _send(id: int, d: Dictionary) -> void:
	if _open(id):
		(clients[id].ws as WebSocketPeer).send_text(JSON.stringify(d))


func _room_send(code: String, d: Dictionary, except := -1) -> void:
	if not rooms.has(code):
		return
	var txt := JSON.stringify(d)
	for m in rooms[code].members:
		if m != except and _open(m):
			(clients[m].ws as WebSocketPeer).send_text(txt)


func _relay_bin(id: int, pkt: PackedByteArray) -> void:
	var code: String = clients[id].room
	if code == "" or pkt.size() < 1 or pkt.size() > 4096:
		return
	var out := PackedByteArray()
	out.resize(pkt.size() + 2)
	out[0] = pkt[0]
	out.encode_u16(1, id)
	for i in range(1, pkt.size()):
		out[i + 2] = pkt[i]
	for m in rooms[code].members:
		if m != id and _open(m):
			(clients[m].ws as WebSocketPeer).send(out)


func _code() -> String:
	var abc := "ABCDEFGHJKLMNPQRSTUVWXYZ"
	for tries in 50:
		var c := ""
		for i in 4:
			c += abc[randi() % abc.length()]
		if not rooms.has(c):
			return c
	return str(randi() % 100000)


func _handle(id: int, d: Dictionary) -> void:
	var cl: Dictionary = clients[id]
	match String(d.get("t", "")):
		"hello":
			cl.name = String(d.get("name", "?")).left(16)
		"list":
			var lst: Array = []
			for code in rooms:
				var r: Dictionary = rooms[code]
				lst.append({"code": code, "name": r.name, "n": r.members.size(), "max": r.max, "open": r.open})
			_send(id, {"t": "rooms", "list": lst})
		"create":
			_leave(id)
			var code := _code()
			rooms[code] = {"name": String(d.get("name", "Sala de " + cl.name)).left(24), "host": id, "members": [id],
				"max": clampi(int(d.get("max", MAX_ROOM)), 2, MAX_ROOM), "open": true}
			cl.room = code
			_joined(id, code)
			if verbose:
				print("[servidor] sala %s criada por %s" % [code, cl.name])
		"join":
			var code := String(d.get("code", "")).to_upper().strip_edges()
			if not rooms.has(code):
				_send(id, {"t": "err", "msg": "Sala %s não existe" % code})
				return
			var r: Dictionary = rooms[code]
			if not r.open:
				_send(id, {"t": "err", "msg": "A corrida já começou nessa sala"})
				return
			if r.members.size() >= r.max:
				_send(id, {"t": "err", "msg": "Sala cheia"})
				return
			_leave(id)
			r.members.append(id)
			cl.room = code
			_room_send(code, {"t": "peer_join", "id": id, "name": cl.name}, id)
			_joined(id, code)
		"leave":
			_leave(id)
		"lock":
			var code: String = cl.room
			if rooms.has(code) and rooms[code].host == id:
				rooms[code].open = bool(d.get("open", true))
		"room":
			var code: String = cl.room
			if code == "":
				return
			var msg := {"t": "room", "from": id, "d": d.get("d", {})}
			if d.has("to"):
				var to := int(d.to)
				if rooms[code].members.has(to):
					_send(to, msg)
			else:
				_room_send(code, msg, id)
		"ping":
			_send(id, {"t": "pong", "c": d.get("c", 0)})


func _joined(id: int, code: String) -> void:
	var r: Dictionary = rooms[code]
	var mem: Array = []
	for m in r.members:
		mem.append({"id": m, "name": clients[m].name})
	_send(id, {"t": "joined", "code": code, "name": r.name, "host": r.host, "members": mem, "me": id, "max": r.max})


func _leave(id: int) -> void:
	var cl: Dictionary = clients.get(id, {})
	if cl.is_empty() or cl.room == "":
		return
	var code: String = cl.room
	cl.room = ""
	if not rooms.has(code):
		return
	var r: Dictionary = rooms[code]
	r.members.erase(id)
	if r.members.is_empty():
		rooms.erase(code)
		if verbose:
			print("[servidor] sala %s fechada" % code)
		return
	_room_send(code, {"t": "peer_leave", "id": id})
	if r.host == id:
		r.host = r.members[0]
		_room_send(code, {"t": "host", "id": r.host})


func _drop(id: int) -> void:
	_leave(id)
	clients.erase(id)
