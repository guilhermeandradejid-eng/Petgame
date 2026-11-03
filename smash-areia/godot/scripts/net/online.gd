class_name Online
extends Node
## Multiplayer online peer-to-peer, sem servidor próprio e sem abrir portas:
## WebRTC (extensão webrtc-native) + godot-matcha, que usa trackers públicos de
## WebTorrent só para o "aperto de mão" entre os jogadores. Custo zero.
##
## Modelo: o ANFITRIÃO simula a partida inteira (física, IA, regras) e manda
## 30 retratos por segundo da quadra; os CONVIDADOS desenham esses retratos
## (o mesmo "modo marionete" do replay) e mandam só os comandos dos seus
## jogadores. Cada PC pode ter 1 ou 2 jogadores locais (modo híbrido); vagas
## que sobram ficam com a CPU.
##
## Salas: cada sala tem um código curto (ex.: K7QPM). O código vira o id do
## anfitrião no tracker, então dá para entrar só digitando o código. Salas
## públicas também aparecem na lista do LOBBY (uma sala P2P de anúncios).

signal lobby_changed                 # lista de salas públicas mudou
signal room_changed                  # membros, vagas ou opções da sala mudaram
signal status(text: String)          # mensagens para a interface
signal match_started(cfg: Dictionary)
signal room_closed(reason: String)   # saiu da sala (ou a sala acabou)

const VERSION := 1
const APP_ID := "smashnaareia"
const LOBBY_ID := "smashnaareia.lobby.v1"
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const SNAP_HZ := 30.0
const INPUT_HZ := 30.0
const MAX_HUMANS := 4
const DEFAULT_TRACKERS := [
	"wss://tracker.openwebtorrent.com",
	"wss://tracker.webtorrent.dev",
	"wss://tracker.files.fm:7073/announce",
	"wss://tracker.btorrent.xyz",
]

enum Role { OFF, HOST, CLIENT }

var main: Node
var role := Role.OFF
var room: MatchaRoom
var lobby: MatchaRoom
var trackers: Array = DEFAULT_TRACKERS.duplicate()
var code := ""
var my_name := ""
var public_rooms := {}       # código -> {meta..., "t": hora em que chegou}
var members := {}            # rpc id -> {"name", "locals": [{"char", "look"}], "ready"}
var join_order: Array = []   # rpc ids na ordem de entrada (o anfitrião é o 1)
var opts := {"mode": "vs", "arena": 0, "len": 0, "diff": 1, "public": true, "name": ""}
var slots: Array = []        # 4 vagas (índice = jogador na quadra)
var in_match := false
var voice: VoiceChat
var t := 0.0
var announce_t := 0.0
var snap_t := 0.0
var input_t := 0.0
var join_timeout := 0.0
var events: Array = []       # eventos do quadro (anfitrião -> convidados)
var snaps: Array = []        # retratos recebidos (convidado), mais novo no fim
var last_snap_recv := 0.0
var bone_names: PackedStringArray = []
var _available := -1
var debug := OS.get_cmdline_user_args().has("--netdebug")


func dbg(a = "", b = "", c = "", d = "") -> void:
	if debug:
		printerr("NET ", a, " ", b, " ", c, " ", d)


func _init(m: Node) -> void:
	main = m
	name = "Online"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_host)
	multiplayer.connection_failed.connect(func(): _fail("Não foi possível conectar na sala."))
	multiplayer.server_disconnected.connect(func(): _fail("O anfitrião saiu da sala."))
	voice = VoiceChat.new(self)
	add_child(voice)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tracker="):
			trackers = [a.substr(10)]
	_load_name()


## O online funciona neste aparelho? (PC com a extensão WebRTC carregada)
func available() -> bool:
	if _available < 0:
		_available = 0
		if not OS.has_feature("mobile") and not OS.has_feature("web"):
			var pc := WebRTCPeerConnection.new()
			_available = 1 if pc.initialize({}) == OK else 0
			pc.close()
	return _available == 1


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


func active() -> bool:
	return role != Role.OFF


## Meu id na sala. No WebRTC do matcha cada lado numera os peers por conta
## própria, então o convidado usa o id que o anfitrião informou (s_welcome).
func my_id() -> int:
	if is_client():
		return net_id
	return 1


var net_id := 0


# ---------------------------------------------------------------- nome do jogador

func _load_name() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://online.cfg") == OK:
		my_name = String(cf.get_value("online", "name", ""))
	if my_name == "":
		var adj := ["SIRI", "TUBA", "ONDA", "SOL", "AREIA", "COCO", "BRISA", "MARÉ"]
		my_name = "%s%d" % [adj[randi() % adj.size()], 10 + randi() % 90]


func set_my_name(n: String) -> void:
	n = n.strip_edges().to_upper().left(12)
	if n == "":
		return
	my_name = n
	var cf := ConfigFile.new()
	cf.set_value("online", "name", my_name)
	cf.save("user://online.cfg")
	if active():
		_send_my_info()


## Jogadores deste PC (1 ou 2), com personagem e visual escolhidos
func my_locals() -> Array:
	var out: Array = [{"char": GameData.char_index, "look": GameData.looks[0].duplicate()}]
	if GameData.online_locals >= 2:
		out.append({"char": GameData.char_index_p2, "look": GameData.looks[1].duplicate()})
	return out


# ---------------------------------------------------------------- lobby (lista de salas)

func open_lobby() -> void:
	if lobby != null or not available():
		return
	lobby = MatchaRoom.create_mesh_room({"identifier": LOBBY_ID, "tracker_urls": trackers, "pool_size": 6})
	lobby.peer_joined.connect(func(_id: int, peer: MatchaPeer):
		dbg("lobby peer joined")
		peer.on_event("room", _on_lobby_room)
		peer.on_event("close", _on_lobby_close)
		_announce_room()
	)
	status.emit("Procurando salas...")


func close_lobby() -> void:
	if lobby == null:
		return
	_lobby_send("close", [code])
	lobby.shutdown()
	lobby = null


func _lobby_send(ev: String, args: Array) -> void:
	if lobby == null:
		return
	for p in lobby.peers:
		var mp := p as MatchaPeer
		if mp.is_connected:
			mp.send_event(ev, args)


func _on_lobby_room(meta) -> void:
	dbg("lobby room", meta)
	if typeof(meta) != TYPE_DICTIONARY or not meta.has("code") or int(meta.get("v", 0)) != VERSION:
		return
	var m: Dictionary = meta
	m["t"] = t
	public_rooms[String(m["code"])] = m
	lobby_changed.emit()


func _on_lobby_close(c) -> void:
	if public_rooms.erase(String(c)):
		lobby_changed.emit()


func _announce_room() -> void:
	if not is_host() or not bool(opts["public"]) or in_match:
		return
	_lobby_send("room", [{
		"v": VERSION, "code": code, "name": String(opts["name"]), "host": my_name,
		"humans": _human_count(), "max": _max_humans(), "mode": opts["mode"], "arena": opts["arena"],
	}])


# ---------------------------------------------------------------- criar / entrar / sair

static func room_peer_id(c: String) -> String:
	return ("%s-room-%s" % [APP_ID, c.to_upper()]).sha1_text().substr(0, 20)


func host(public := true) -> void:
	leave()
	code = ""
	for i in 5:
		code += CODE_CHARS[randi() % CODE_CHARS.length()]
	opts["public"] = public
	opts["name"] = "SALA DE " + my_name
	room = MatchaRoom.create_server_room({"peer_id": room_peer_id(code), "identifier": APP_ID,
		"tracker_urls": trackers, "pool_size": 6})
	multiplayer.multiplayer_peer = room
	role = Role.HOST
	members = {1: {"name": my_name, "locals": my_locals(), "ready": true}}
	join_order = [1]
	in_match = false
	_compute_slots()
	open_lobby()
	voice.start()
	status.emit("Sala %s criada. Passe o código para os amigos!" % code)
	room_changed.emit()


func join(c: String) -> void:
	c = c.strip_edges().to_upper()
	if c.length() < 4:
		status.emit("Código inválido.")
		return
	leave()
	code = c
	room = MatchaRoom.create_client_room(room_peer_id(code), {"identifier": APP_ID, "tracker_urls": trackers})
	multiplayer.multiplayer_peer = room
	role = Role.CLIENT
	net_id = 0
	in_match = false
	members = {}
	slots = []
	join_timeout = 30.0
	status.emit("Conectando na sala %s..." % code)
	room_changed.emit()


func leave(reason := "") -> void:
	if role == Role.OFF:
		return
	var was_match := in_match
	if is_host():
		_lobby_send("close", [code])
	voice.stop()
	role = Role.OFF
	in_match = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if room:
		room.shutdown()
	room = null
	members = {}
	slots = []
	snaps.clear()
	events.clear()
	code = ""
	room_changed.emit()
	if reason != "" or was_match:
		room_closed.emit(reason)


func _fail(reason: String) -> void:
	status.emit(reason)
	leave(reason)


# ---------------------------------------------------------------- membros e vagas

func _on_peer_connected(id: int) -> void:
	dbg("peer_connected", id, role)
	if is_host():
		status.emit("Alguém está entrando...")


func _on_connected_to_host() -> void:
	dbg("connected_to_host")
	join_timeout = 0.0
	_send_my_info()
	status.emit("Conectado! Aguardando o anfitrião começar.")


func _send_my_info() -> void:
	if is_client():
		c_hello.rpc_id(1, {"v": VERSION, "name": my_name, "locals": my_locals()})
	elif is_host():
		members[1] = {"name": my_name, "locals": my_locals(), "ready": true}
		_compute_slots()
		_broadcast_room()


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	var nm := String(members.get(id, {}).get("name", "?"))
	members.erase(id)
	join_order.erase(id)
	voice.remove_peer(id)
	if in_match:
		main.net_player_left(id)   # vagas dele viram CPU
	else:
		_compute_slots()
	status.emit("%s saiu da sala." % nm)
	_broadcast_room()


func _human_count() -> int:
	var n := 0
	for id in members:
		n += (members[id]["locals"] as Array).size()
	return n


func _max_humans() -> int:
	return 2 if opts["mode"] == "coop" else MAX_HUMANS


## Monta as 4 vagas: no VS cada PC fica de um lado (alternando por ordem de
## entrada); no CO-OP todos jogam juntos contra a CPU. O resto é CPU.
func _compute_slots() -> void:
	slots = []
	for i in 4:
		slots.append({"team": 0 if i < 2 else 1, "kind": "cpu", "owner": 0, "local": 0, "name": "CPU"})
	var team_fill := [0, 0]
	var k := 0
	for id in join_order:
		if not members.has(id):
			continue
		var m: Dictionary = members[id]
		var want := 0 if opts["mode"] == "coop" else k % 2
		k += 1
		var locs: Array = m["locals"]
		for li in locs.size():
			var team := want
			if team_fill[team] >= 2:
				team = 1 - team
				if team_fill[team] >= 2 or opts["mode"] == "coop":
					continue
			var si: int = team * 2 + team_fill[team]
			team_fill[team] += 1
			var nm := String(m["name"]) + ("" if locs.size() == 1 else " %d" % (li + 1))
			slots[si] = {"team": team, "kind": "human", "owner": id, "local": li, "name": nm,
				"char": int(locs[li]["char"]), "look": locs[li]["look"]}


func _broadcast_room() -> void:
	if not is_host():
		return
	var data := {"code": code, "opts": opts, "members": members, "order": join_order, "slots": slots,
		"in_match": in_match}
	_bcast(&"s_room", [data])
	room_changed.emit()
	_announce_room()


func set_option(key: String, value) -> void:
	if not is_host() or in_match:
		return
	opts[key] = value
	_compute_slots()
	_broadcast_room()


## O anfitrião começa a partida: sorteia os personagens da CPU e manda a todos
func start_match() -> void:
	if not is_host():
		return
	_compute_slots()
	var used: Array = []
	for s in slots:
		if s["kind"] == "human":
			used.append(int(s["char"]))
	var free: Array = []
	for c in GameData.CHARACTERS.size():
		if not used.has(c):
			free.append(c)
	free.shuffle()
	var final: Array = []
	for s in slots:
		var d: Dictionary = s.duplicate(true)
		if d["kind"] == "cpu":
			d["char"] = free.pop_back() if not free.is_empty() else randi() % GameData.CHARACTERS.size()
			d["look"] = {"outfit": randi() % GameData.OUTFITS.size(), "palette": randi() % 3,
				"racket": randi() % GameData.RACKETS.size(), "racket_color": -1}
			d["name"] = GameData.CHARACTERS[int(d["char"])]["name"]
		final.append(d)
	var cfg := {"slots": final, "arena": opts["arena"], "len": opts["len"], "diff": opts["diff"],
		"mode": opts["mode"]}
	in_match = true
	_lobby_send("close", [code])
	_bcast(&"s_start", [cfg])
	_begin(cfg)


func _begin(cfg: Dictionary) -> void:
	in_match = true
	snaps.clear()
	events.clear()
	match_started.emit(cfg)


## Fim da partida / volta para a sala (anfitrião decide)
func back_to_room() -> void:
	if not is_host():
		return
	in_match = false
	_compute_slots()
	_bcast(&"s_back", [])
	main.net_back_to_room()
	_broadcast_room()


# ---------------------------------------------------------------- RPCs: sala

## Manda só para os convidados que já estão na sala. (O matcha deixa várias
## "offers" ainda sem resposta registradas como peers; um broadcast tentaria
## mandar para elas também e falharia.)
func _bcast(method: StringName, args: Array) -> void:
	if method != &"s_snap" and method != &"s_events":
		dbg("bcast", method, members.keys())
	for id in members:
		if int(id) != 1 and room and room.has_peer(int(id)):
			callv("rpc_id", [int(id), method] + args)


@rpc("any_peer", "call_remote", "reliable")
func c_hello(info: Dictionary) -> void:
	dbg("c_hello", multiplayer.get_remote_sender_id(), info.get("name", ""))
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if int(info.get("v", 0)) != VERSION:
		s_reject.rpc_id(id, "Versão diferente do jogo. Atualize os dois PCs.")
		return
	if in_match and not members.has(id):
		s_reject.rpc_id(id, "A partida já começou. Espere acabar e entre de novo.")
		return
	var locs: Array = info.get("locals", [])
	locs = locs.slice(0, 2)
	# cabe? (no máximo 4 humanos; 2 no co-op)
	var others := _human_count() - (members[id]["locals"] as Array).size() if members.has(id) else _human_count()
	var room_left := _max_humans() - others
	if room_left <= 0:
		s_reject.rpc_id(id, "A sala está cheia.")
		return
	if locs.size() > room_left:
		locs = locs.slice(0, room_left)
	for l in locs:
		l["char"] = clampi(int(l.get("char", 0)), 0, GameData.CHARACTERS.size() - 1)
	var is_new := not members.has(id)
	s_welcome.rpc_id(id, id)
	members[id] = {"name": String(info.get("name", "?")).left(12), "locals": locs, "ready": false}
	if not join_order.has(id):
		join_order.append(id)
	_compute_slots()
	if is_new:
		status.emit("%s entrou na sala!" % members[id]["name"])
		main.sfx("ui_start", -6.0)
	_broadcast_room()


@rpc("authority", "call_remote", "reliable")
func s_room(data: Dictionary) -> void:
	dbg("s_room", (data.get("members", {}) as Dictionary).size())
	code = String(data.get("code", code))
	opts = data.get("opts", opts)
	members = data.get("members", {})
	join_order = data.get("order", [])
	slots = data.get("slots", [])
	voice.start()
	room_changed.emit()


@rpc("authority", "call_remote", "reliable")
func s_welcome(your_id: int) -> void:
	net_id = your_id
	dbg("welcome, my id on the host =", your_id)


@rpc("authority", "call_remote", "reliable")
func s_reject(reason: String) -> void:
	_fail(reason)


@rpc("authority", "call_remote", "reliable")
func s_start(cfg: Dictionary) -> void:
	_begin(cfg)


@rpc("authority", "call_remote", "reliable")
func s_back() -> void:
	in_match = false
	main.net_back_to_room()


# ---------------------------------------------------------------- partida: comandos

## Convidado: manda o analógico dos jogadores locais (30x por segundo)
func send_inputs(dt: float, locals: Array) -> void:
	input_t -= dt
	if input_t > 0.0 or not is_client():
		return
	input_t = 1.0 / INPUT_HZ
	var a := PackedFloat32Array()
	for p in locals:
		a.append(float(p.net_slot))
		a.append(p.stick.x)
		a.append(p.stick.y)
	c_input.rpc_id(1, a)


## Convidado: golpe / especial / peixinho / pulo de um jogador local
func send_action(slot: int, kind: String, arg := 0) -> void:
	if is_client():
		c_action.rpc_id(1, slot, kind, arg)


func _owns(id: int, slot: int) -> bool:
	return slot >= 0 and slot < slots.size() and int(slots[slot].get("owner", -1)) == id


@rpc("any_peer", "call_remote", "unreliable_ordered")
func c_input(a: PackedFloat32Array) -> void:
	if not is_host() or not in_match:
		return
	var id := multiplayer.get_remote_sender_id()
	for i in range(0, a.size() - 2, 3):
		var s := int(a[i])
		if _owns(id, s):
			main.net_stick(s, Vector2(a[i + 1], a[i + 2]).limit_length(1.0))


@rpc("any_peer", "call_remote", "reliable")
func c_action(slot: int, kind: String, arg: int) -> void:
	if not is_host() or not in_match:
		return
	if _owns(multiplayer.get_remote_sender_id(), slot):
		main.net_action(slot, kind, arg)


# ---------------------------------------------------------------- partida: retratos e eventos

## Anfitrião: guarda um evento (som, letreiro, efeito) para os convidados
func ev(kind: String, args: Array) -> void:
	if is_host() and in_match:
		events.append([kind, args])


func _rig_pack(r: Rig) -> PackedFloat32Array:
	if bone_names.is_empty():
		var ks: Array = r.cur.keys()
		ks.sort()
		bone_names = PackedStringArray(ks)
	var a := PackedFloat32Array()
	a.resize(bone_names.size() * 3)
	for i in bone_names.size():
		var v: Vector3 = r.cur.get(bone_names[i], Vector3.ZERO)
		a[i * 3] = v.x
		a[i * 3 + 1] = v.y
		a[i * 3 + 2] = v.z
	return a


func rig_unpack(a: PackedFloat32Array, r: Rig) -> Dictionary:
	if bone_names.is_empty():
		var ks: Array = r.cur.keys()
		ks.sort()
		bone_names = PackedStringArray(ks)
	var d := {}
	for i in mini(bone_names.size(), a.size() / 3):
		d[bone_names[i]] = Vector3(a[i * 3], a[i * 3 + 1], a[i * 3 + 2])
	return d


func _process(dt: float) -> void:
	t += dt
	# salas públicas somem se pararem de ser anunciadas
	var gone := false
	for c in public_rooms.keys():
		if t - float(public_rooms[c]["t"]) > 12.0:
			public_rooms.erase(c)
			gone = true
	if gone:
		lobby_changed.emit()
	announce_t -= dt
	if announce_t <= 0.0:
		announce_t = 3.0
		_announce_room()
	if join_timeout > 0.0:
		join_timeout -= dt
		if join_timeout <= 0.0 and is_client() and members.is_empty():
			_fail("A sala %s não respondeu. Confira o código (e se o anfitrião está com a sala aberta)." % code)
	if not is_host() or not in_match:
		return
	# anfitrião: eventos todo quadro, retratos 30x por segundo
	if not events.is_empty():
		_bcast(&"s_events", [events])
		events = []
	snap_t -= dt
	if snap_t <= 0.0:
		snap_t = 1.0 / SNAP_HZ
		var data: Array = main.net_snapshot()
		var bytes := var_to_bytes(data)
		_bcast(&"s_snap", [bytes.compress(FileAccess.COMPRESSION_DEFLATE), bytes.size()])


@rpc("authority", "call_remote", "unreliable_ordered")
func s_snap(data: PackedByteArray, raw_size: int) -> void:
	if not is_client() or not in_match:
		return
	var snap = bytes_to_var(data.decompress(raw_size, FileAccess.COMPRESSION_DEFLATE))
	if typeof(snap) != TYPE_ARRAY:
		return
	if snaps.is_empty() and last_snap_recv == 0.0:
		printerr("NETTEST first snapshot (%d bytes)" % data.size())
	snaps.append({"recv": t, "d": snap})
	last_snap_recv = t
	if snaps.size() > 12:
		snaps.pop_front()


@rpc("authority", "call_remote", "reliable")
func s_events(evs: Array) -> void:
	if not is_client() or not in_match:
		return
	for e in evs:
		if typeof(e) == TYPE_ARRAY and e.size() == 2:
			main.net_event(String(e[0]), e[1])


## Convidado: dois retratos e o fator de mistura para desenhar agora
## (atraso de ~100 ms para sobrar um retrato à frente e o movimento ficar liso)
func snapshot_pair() -> Array:
	if snaps.is_empty():
		return []
	var render_t := t - 0.1
	for i in range(snaps.size() - 1, 0, -1):
		var a: Dictionary = snaps[i - 1]
		var b: Dictionary = snaps[i]
		if float(a["recv"]) <= render_t:
			var span := maxf(float(b["recv"]) - float(a["recv"]), 0.001)
			return [a["d"], b["d"], clampf((render_t - float(a["recv"])) / span, 0.0, 1.0)]
	return [snaps[0]["d"], snaps[0]["d"], 0.0]


# ---------------------------------------------------------------- voz

func send_voice(data: PackedByteArray) -> void:
	if is_host():
		_bcast(&"voice_pkt", [1, data])
	elif is_client():
		voice_pkt.rpc_id(1, 0, data)


@rpc("any_peer", "call_remote", "unreliable")
func voice_pkt(from: int, data: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_host():
		from = sender
		# o anfitrião repassa para os outros convidados (topologia em estrela)
		for id in members:
			if id != 1 and id != sender:
				voice_pkt.rpc_id(id, from, data)
	elif sender != 1:
		return
	if from == my_id():
		return
	voice.receive(from, data)


func member_name(id: int) -> String:
	return String(members.get(id, {}).get("name", "?"))
