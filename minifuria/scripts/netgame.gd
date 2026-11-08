class_name NetGame
extends Node
## Corrida online (até 8 pessoas por sala): telas de conexão e lobby + sincronização da corrida.
## Autoridade distribuída: cada máquina simula a física dos SEUS carros e manda o estado 20x por segundo;
## o anfitrião da sala simula a IA. Os carros dos outros chegam como "fantasmas cinemáticos" interpolados
## (100 ms de atraso), batem e levam tiro normalmente; o dano em cada carro é decidido pelo dono dele.

const SEND_HZ := 20.0
const DELAY := 0.1
const K_STATE := 1
const CAR_NAMES := {"faisca": "FAÍSCA", "trovao": "TROVÃO", "vespa": "VESPA"}

var game: Node
var hud: Hud
var net: Net
var voice: Voice
var server: NetServer = null
var racing := false
var profiles := {}          # id -> {"name", "car", "front", "rear", "nitro", "up"}
var my_car := ""
var sel_track := 0
var ai_fill := true
var send_acc := 0.0
var clock := {}             # id -> diferença de relógio estimada (local - remetente)
var _rx := false            # tratando mensagem recebida (não reenviar)
var auto := {}              # testes automáticos: {"host": bool, "wait": n}
# telas
var scr_conn: Control
var scr_lobby: Control
var name_e: LineEdit
var url_e: LineEdit
var code_e: LineEdit
var status_l: Label
var rooms_box: VBoxContainer
var room_btns: Control
var lobby_title: Label
var lobby_list: Label
var car_l: Label
var track_b: Button
var ai_b: Button
var start_b: Button
var voice_b: Button
var voice_b2: Button
var lobby_info: Label
var talk_l: Label


func setup(g: Node, h: Hud) -> void:
	game = g
	hud = h
	net = Net.new()
	add_child(net)
	net.msg.connect(_on_msg)
	net.bin.connect(_on_bin)
	net.status_changed.connect(_on_status)
	voice = Voice.new()
	add_child(voice)
	voice.setup(g, net)
	_build_conn()
	_build_lobby()
	talk_l = hud._label(15, Color("#7dff6a"), Color(0, 0, 0, 0.7))
	talk_l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	talk_l.offset_left = 18
	talk_l.offset_top = -120
	talk_l.offset_bottom = -90
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--netclient="):
			var u := a.substr(12)
			auto = {"host": "--nethost" in args, "wait": 2}
			for b in args:
				if b.begins_with("--netwait="):
					auto.wait = int(b.substr(10))
			var nm := "HOST" if auto.host else "CLIENTE%d" % (randi() % 100)
			for b in args:
				if b.begins_with("--name="):
					nm = b.substr(7)
			name_e.text = nm
			net.connect_to(u, nm)


func in_room() -> bool:
	return net.in_room()


func is_host() -> bool:
	return net.is_host()


# ------------------------------------------------------------------ telas
func _row(parent: Node, sep := 12) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", sep)
	parent.add_child(r)
	return r


func _edit(parent: Node, ph: String, w: float, txt := "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = ph
	e.text = txt
	e.custom_minimum_size = Vector2(w, 48)
	e.add_theme_font_size_override("font_size", 18)
	e.add_theme_stylebox_override("normal", hud._sb(Color(0, 0, 0, 0.45), 12, Color(1, 1, 1, 0.25), 2))
	e.add_theme_stylebox_override("focus", hud._sb(Color(0, 0, 0, 0.55), 12, Color("#ffcf33"), 2))
	parent.add_child(e)
	return e


func _small_text(parent: Node, txt: String, fs := 15) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", SystemFont.new())
	l.add_theme_font_size_override("font_size", fs)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	parent.add_child(l)
	return l


func _build_conn() -> void:
	scr_conn = hud._screen(0.8)
	var v := hud._vcenter(scr_conn, 12)
	var t := hud._label(46, Color("#ffcf33"), Color("#c74200"), v)
	t.text = "ONLINE"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var r1 := _row(v)
	name_e = _edit(r1, "seu nome", 220, String(game.save.get("net_name", "")))
	name_e.max_length = 14
	url_e = _edit(r1, "servidor (ex.: ws://192.168.0.10:9080)", 420, String(game.save.get("net_url", "ws://127.0.0.1:9080")))
	var r2 := _row(v)
	hud._btn("CONECTAR", r2, true, 240, 56).pressed.connect(_connect)
	if OS.get_name() != "Web":
		hud._btn("HOSPEDAR AQUI", r2, false, 260, 56).pressed.connect(_host_here)
	status_l = _small_text(v, "Conecte num servidor de salas (veja o README) ou hospede aqui para jogar na rede local.")
	room_btns = VBoxContainer.new()
	room_btns.add_theme_constant_override("separation", 8)
	v.add_child(room_btns)
	var r3 := _row(room_btns)
	hud._btn("CRIAR SALA", r3, true, 240, 56).pressed.connect(_create)
	code_e = _edit(r3, "código", 140)
	code_e.max_length = 5
	hud._btn("ENTRAR", r3, false, 160, 56).pressed.connect(func(): _join(code_e.text))
	hud._btn("ATUALIZAR", r3, false, 180, 56).pressed.connect(func(): net.send({"t": "list"}))
	rooms_box = VBoxContainer.new()
	rooms_box.add_theme_constant_override("separation", 6)
	room_btns.add_child(rooms_box)
	room_btns.visible = false
	var r4 := _row(v)
	hud._btn("VOLTAR", r4, false, 200, 52).pressed.connect(func(): leave(); net.close(); hud.show_screen("menu"))
	hud.extra_screens["online"] = scr_conn
	scr_conn.visible = false


func _build_lobby() -> void:
	scr_lobby = hud._screen(0.8)
	var v := hud._vcenter(scr_lobby, 12)
	lobby_title = hud._label(40, Color("#ffcf33"), Color("#c74200"), v)
	lobby_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_list = hud._label(20, Color.WHITE, Color(0, 0, 0, 0.6), v)
	lobby_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var r1 := _row(v)
	hud._btn("<", r1, false, 60, 52).pressed.connect(func(): _cycle_car(-1))
	car_l = hud._label(22, Color("#2ee6ff"), Color(0, 0, 0, 0.6), r1)
	car_l.custom_minimum_size = Vector2(220, 0)
	car_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._btn(">", r1, false, 60, 52).pressed.connect(func(): _cycle_car(1))
	track_b = hud._btn("PISTA", r1, false, 340, 52)
	track_b.pressed.connect(func(): if is_host(): hud.show_screen("tracks"))
	ai_b = hud._btn("IA", r1, false, 200, 52)
	ai_b.pressed.connect(func():
		if is_host():
			ai_fill = not ai_fill
			_send_lobby())
	var r2 := _row(v)
	voice_b = hud._btn(voice.label(), r2, false, 420, 52)
	voice_b.pressed.connect(_cycle_voice)
	var r3 := _row(v)
	hud._btn("SAIR DA SALA", r3, false, 240, 56).pressed.connect(func(): leave(); open())
	start_b = hud._btn("LARGAR!", r3, true, 280, 60)
	start_b.pressed.connect(start_race)
	lobby_info = _small_text(v, "")
	hud.extra_screens["lobby"] = scr_lobby
	scr_lobby.visible = false
	# voz também no menu de pausa da corrida
	voice_b2 = hud._btn(voice.label(), hud.pause_extra, false, 420, 52)
	voice_b2.pressed.connect(_cycle_voice)
	voice_b2.visible = false


func _cycle_voice() -> void:
	voice.cycle()
	voice_b.text = voice.label()
	voice_b2.text = voice.label()
	game.save.voice = voice.mode
	game._write_save()


func open() -> void:
	game.set_solo()
	if my_car == "":
		my_car = String(game.save.car)
	room_btns.visible = net.is_open()
	if voice.mode == "off" and String(game.save.get("voice", "off")) != "off":
		voice.set_mode(String(game.save.voice))
	voice_b.text = voice.label()
	hud.show_screen("lobby" if net.in_room() else "online")


func _connect() -> void:
	var nm := name_e.text.strip_edges()
	if nm == "":
		nm = "PILOTO%d" % (randi() % 100)
		name_e.text = nm
	game.save.net_name = nm
	game.save.net_url = url_e.text.strip_edges()
	game._write_save()
	status_l.text = "Conectando em %s ..." % url_e.text
	net.connect_to(url_e.text, nm)


func _host_here() -> void:
	if server == null:
		server = NetServer.new()
		add_child(server)
		if server.start(9080) != OK:
			status_l.text = "Não deu para abrir a porta 9080 (já está em uso?)"
			server.queue_free()
			server = null
			return
	var ips: Array = []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254"):
			ips.append(ip)
	url_e.text = "ws://127.0.0.1:9080"
	_connect()
	status_l.text = "Servidor aberto. Na mesma rede, os outros conectam em: %s" % ", ".join(ips.map(func(x): return "ws://%s:9080" % x))


func _create() -> void:
	net.send({"t": "create", "name": "Sala de " + name_e.text, "max": 8})


func _join(code: String) -> void:
	if code.strip_edges() != "":
		net.send({"t": "join", "code": code.strip_edges().to_upper()})


func leave() -> void:
	if net.in_room():
		net.send({"t": "leave"})
	net.room = {}
	racing = false
	profiles.clear()


func _cycle_car(step: int) -> void:
	var cars := ["faisca", "trovao", "vespa"]
	my_car = cars[posmod(cars.find(my_car) + step, 3)]
	_send_prof()
	_refresh_lobby()


# ------------------------------------------------------------------ mensagens de controle
func _on_status(st: String) -> void:
	if st == "open":
		status_l.text = "Conectado! Crie uma sala ou entre numa."
		room_btns.visible = true
		net.send({"t": "list"})
		if auto.has("host"):
			if auto.host:
				_create()
			else:
				net.send({"t": "list"})
	elif st == "closed":
		status_l.text = "Sem conexão com %s" % net.url
		room_btns.visible = false
		if racing:
			hud.popup("CONEXÃO PERDIDA", Color("#ff7a7a"))
		if hud.cur_screen == "lobby":
			hud.show_screen("online")


func _on_msg(d: Dictionary) -> void:
	match String(d.get("t", "")):
		"rooms":
			for ch in rooms_box.get_children():
				ch.queue_free()
			var any := false
			for r in d.list:
				if not bool(r.open):
					continue
				any = true
				var b := hud._btn("%s  ·  %s  ·  %d/%d" % [r.code, r.name, int(r.n), int(r.max)], rooms_box, false, 560, 46)
				var code := String(r.code)
				b.pressed.connect(func(): _join(code))
				if auto.has("host") and not auto.host:
					_join(code)
					return
			if not any:
				_small_text(rooms_box, "Nenhuma sala aberta. Crie uma!")
				if auto.has("host") and not auto.host:
					get_tree().create_timer(1.0).timeout.connect(func(): net.send({"t": "list"}))
		"err":
			status_l.text = String(d.msg)
			hud.popup(String(d.msg), Color("#ff7a7a"))
		"joined":
			profiles.clear()
			if my_car == "":
				my_car = String(game.save.car)
			_send_prof()
			if is_host():
				sel_track = game.track_idx
				_send_lobby()
			hud.show_screen("lobby")
			_refresh_lobby()
			if "--lobbyshot" in OS.get_cmdline_user_args():
				get_tree().create_timer(5.0).timeout.connect(func():
					get_viewport().get_texture().get_image().save_png("user://ui_lobby.png")
					get_tree().quit())
		"peer_join":
			_send_prof(int(d.id))
			if is_host():
				_send_lobby(int(d.id))
			hud.killfeed("%s entrou na sala" % d.name, Color("#7dff6a"))
			_refresh_lobby()
			if auto.get("host", false) and net.room.members.size() >= int(auto.wait):
				get_tree().create_timer(1.0).timeout.connect(start_race)
		"peer_leave":
			var id := int(d.id)
			profiles.erase(id)
			voice.drop_peer(id)
			_drop_cars_of(id)
			_refresh_lobby()
		"host":
			hud.killfeed("Novo anfitrião: %s" % net.room.members.get(int(d.id), "?"), Color("#2ee6ff"))
			_host_changed()
			_refresh_lobby()
		"room":
			_rx = true
			_on_room(int(d.from), d.d)
			_rx = false


func _send_prof(to := -1) -> void:
	var p := {"k": "prof", "name": name_e.text, "car": my_car, "front": game.save.front, "rear": game.save.rear,
		"nitro": game.save.nitro, "up": game.save.up}
	profiles[net.my_id] = p
	net.room_send(p, to)


func _send_lobby(to := -1) -> void:
	net.room_send({"k": "lobby", "track": sel_track, "ai": ai_fill}, to)
	_refresh_lobby()


func pick_track(i: int) -> void:
	sel_track = i
	game.load_track(i)
	_send_lobby()
	hud.show_screen("lobby")


func _on_room(from: int, d: Dictionary) -> void:
	match String(d.get("k", "")):
		"prof":
			profiles[from] = d
			_refresh_lobby()
		"lobby":
			if sel_track != int(d.track):
				sel_track = int(d.track)
				if not racing:
					game.load_track(sel_track)
			ai_fill = bool(d.ai)
			_refresh_lobby()
		"start":
			_begin(d)
		"died":
			var c := _car_by_slot(int(d.s))
			if c and not c.wrecked:
				var killer := _car_by_slot(int(d.ks)) if int(d.ks) >= 0 else null
				c.set_meta("fell", bool(d.get("fell", false)))
				game._on_died(c, killer)
		"fin":
			var c := _car_by_slot(int(d.s))
			if game.auto_test:
				print("NETFIN recv slot=%d car=%s done=%s racing=%s" % [int(d.s), c != null, c.get_meta("done", false) if c else false, racing])
			if c and not c.get_meta("done", false) and racing:
				c.set_meta("done", true)
				c.set_meta("fin_t", float(d.tm))
				c.lap = maxi(c.lap, game.LAPS)
				if game.mode == "race":
					game._mp_finished(c)
				elif hud.cur_screen == "results":
					game._show_results()   # chegada que veio depois do fim: atualiza a tabela
		"end":
			if racing and game.mode == "race":
				game._finish()
		"lobby_back":
			pass


func _refresh_lobby() -> void:
	if not net.in_room():
		return
	lobby_title.text = "SALA %s  ·  %s" % [net.room.code, net.room.name]
	var lines: Array = []
	var ids: Array = net.room.members.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = profiles.get(id, {})
		var nm: String = String(p.get("name", net.room.members[id]))
		var car: String = CAR_NAMES.get(String(p.get("car", "")), "...")
		lines.append("%s%s  ·  %s%s%s" % ["[ANFITRIÃO] " if id == int(net.room.host) else "", nm, car,
			"  (você)" if id == net.my_id else "", "  · FALANDO" if voice.is_talking(id) else ""])
	lobby_list.text = "\n".join(lines) + "\n%d/%d pessoas · ping %d ms" % [ids.size(), int(net.room.max), int(net.ping_ms)]
	car_l.text = CAR_NAMES.get(my_car, my_car)
	var td: Dictionary = TrackData.TRACKS[clampi(sel_track, 0, TrackData.TRACKS.size() - 1)]
	track_b.text = "PISTA: %s" % String(td.name).to_upper()
	ai_b.text = "IA: %s" % ("COMPLETA O GRID" if ai_fill else "SEM IA")
	start_b.visible = is_host()
	track_b.disabled = not is_host()
	ai_b.disabled = not is_host()
	lobby_info.text = "Você é o anfitrião: escolha a pista e largue quando todos estiverem prontos." if is_host() else "Aguardando o anfitrião escolher a pista e largar."


# ------------------------------------------------------------------ largada
func start_race() -> void:
	if not is_host():
		return
	var ids: Array = net.room.members.keys()
	ids.sort()
	var players: Array = []
	for i in ids.size():
		var id: int = ids[i]
		var p: Dictionary = profiles.get(id, {})
		players.append({"id": id, "name": String(p.get("name", net.room.members[id])).to_upper(), "car": String(p.get("car", "faisca")),
			"front": String(p.get("front", "mg")), "rear": String(p.get("rear", "mine")), "nitro": String(p.get("nitro", "short")),
			"up": p.get("up", {}), "color": game.HUMAN_COLORS[i % game.HUMAN_COLORS.size()]})
	var n_ai := clampi(6 - players.size(), 0, 4) if ai_fill else 0
	var d := {"k": "start", "track": sel_track, "ai": n_ai, "players": players}
	net.send({"t": "lock", "open": false})
	net.room_send(d)
	_begin(d)


func _begin(d: Dictionary) -> void:
	var players: Array = []
	for p in d.players:
		var q: Dictionary = (p as Dictionary).duplicate()
		q.id = int(q.id)
		q.local = q.id == net.my_id
		q.dev = "solo"
		players.append(q)
	game.session = {"kind": "online", "players": players, "ai": int(d.ai)}
	game.track_idx = int(d.track)
	clock.clear()
	racing = true
	game.start_race()
	voice_b2.visible = true


## chamado pelo jogo depois de criar os carros
func on_spawned() -> void:
	if game.session.kind != "online":
		return
	var host := int(net.room.get("host", 0))
	for c in game.rivals:
		c.owner_id = host
		c.net_remote = host != net.my_id
		if c.net_remote:
			c.role = "rival"
	for c in game.racers():
		c.net_buf = []
		if c.net_remote:
			c.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			c.freeze = true


func _car_by_slot(s: int) -> Car:
	for c in game.racers():
		if c.slot == s:
			return c
	return null


func _drop_cars_of(id: int) -> void:
	if not racing:
		return
	for c in game.humans:
		if c.owner_id == id:
			c.visible = false
			c.collision_layer = 0
			c.collision_mask = 0
			c.net_buf = []
			c.set_meta("left", true)
			# quem já terminou continua na classificação; quem não terminou fica como "saiu"
			if not c.get_meta("done", false):
				hud.killfeed("%s saiu da corrida" % c.display_name, Color("#ff7a7a"))
				c.set_meta("done", true)
				c.set_meta("fin_t", 9999.0)
				c.display_name += " (saiu)"
				if game.mode == "race":
					game._mp_finished(c)


func _host_changed() -> void:
	if not racing:
		return
	var host := int(net.room.host)
	for c in game.rivals:
		c.owner_id = host
		var mine := host == net.my_id
		if mine and c.net_remote:
			# a IA passa a ser simulada aqui (continua de onde estava)
			c.net_remote = false
			c.freeze = game.mode == "countdown"
			c.role = "rival"
			c.net_buf = []
		elif not mine:
			c.net_remote = true
			c.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			c.freeze = true


func on_respawn(c: Car) -> void:
	if racing and not c.net_remote:
		c.set_meta("tp", (int(c.get_meta("tp", 0)) + 1) % 256)


func on_died(c: Car, killer: Car) -> void:
	if racing and not _rx and not c.net_remote:
		net.room_send({"k": "died", "s": c.slot, "ks": killer.slot if killer else -1, "fell": bool(c.get_meta("fell", false))})


func send_fin(c: Car) -> void:
	if game.auto_test:
		print("NETFIN send slot=%d racing=%s rx=%s remote=%s room=%s" % [c.slot, racing, _rx, c.net_remote, net.in_room()])
	if racing and not _rx and not c.net_remote:
		net.room_send({"k": "fin", "s": c.slot, "tm": float(c.get_meta("fin_t", game.race_t))})


func on_finish() -> void:
	if not racing:
		return
	if is_host():
		net.room_send({"k": "end"})
	# volta ao lobby depois do resultado; a sala reabre para novas pessoas
	get_tree().create_timer(9.0, true, false, true).timeout.connect(_back_to_lobby)


func _back_to_lobby() -> void:
	if not racing:
		return
	racing = false
	voice_b2.visible = false
	if is_host():
		net.send({"t": "lock", "open": true})
	game.session = {"kind": "solo", "players": []}
	if auto.has("host"):
		get_tree().quit()
		return
	game.load_track(sel_track)
	hud.show_screen("lobby")
	_refresh_lobby()


# ------------------------------------------------------------------ estado dos carros
func physics(dt: float) -> void:
	if not racing or not net.in_room():
		return
	send_acc += dt
	if send_acc >= 1.0 / SEND_HZ:
		send_acc = 0.0
		_send_state()
	_apply_remote()
	_netlog()


func _now() -> float:
	return Time.get_ticks_usec() / 1e6


## teste: registra posições (dono e quem recebe) com o relógio do sistema, para comparar depois
func _netlog() -> void:
	if not "--netlog" in OS.get_cmdline_user_args() or Engine.get_physics_frames() % 15 != 0:
		return
	var t := Time.get_unix_time_from_system()
	for c in game.racers():
		var p: Vector3 = c.global_position
		print("NETLOG %.3f %d %s %d %.2f %.2f %.2f" % [t, net.my_id, "R" if c.net_remote else "O", c.slot, p.x, p.y, p.z])


func _send_state() -> void:
	var own: Array = []
	for c in game.racers():
		if not c.net_remote and c.owner_id == net.my_id and c.visible:
			own.append(c)
	if own.is_empty():
		return
	var b := StreamPeerBuffer.new()
	b.put_double(_now())
	b.put_u8(own.size())
	for c in own:
		var x: Transform3D = c.global_transform
		var q := x.basis.get_rotation_quaternion()
		b.put_u8(c.slot)
		b.put_float(x.origin.x)
		b.put_float(x.origin.y)
		b.put_float(x.origin.z)
		b.put_16(int(q.x * 32767.0))
		b.put_16(int(q.y * 32767.0))
		b.put_16(int(q.z * 32767.0))
		b.put_16(int(q.w * 32767.0))
		var v: Vector3 = c.linear_velocity
		b.put_float(v.x)
		b.put_float(v.y)
		b.put_float(v.z)
		b.put_16(int(clampf(c.v_f, -300.0, 300.0) * 100.0))
		b.put_8(int(clampf(c.steer_s, -1.0, 1.0) * 127.0))
		var fl := int(c.nitroing) | int(c.drifting) << 1 | int(c.wrecked) << 2 | int(c.ctrl.fire) << 3 | int(c.ctrl.drop) << 4 \
			| int(c.ctrl.brake > 0.0) << 5 | int(c.on_ground) << 6
		b.put_u8(fl)
		b.put_u8(int(clampf(c.health / maxf(c.max_health, 1.0), 0.0, 1.0) * 255.0))
		b.put_u8(clampi(c.ammo_f, 0, 255))
		b.put_u8(clampi(c.ammo_r, 0, 255))
		b.put_u8(clampi(c.nitro_ch, 0, 255))
		b.put_u8(clampi(c.lap, 0, 255))
		b.put_u8(int(c.get_meta("tp", 0)))
		b.put_float(c.dist)
	net.send_bin(K_STATE, b.data_array)


func _on_bin(kind: int, from: int, data: PackedByteArray) -> void:
	if kind != K_STATE or not racing:
		return
	var b := StreamPeerBuffer.new()
	b.data_array = data
	var ts := b.get_double()
	var now := _now()
	var off := now - ts
	# relógio do remetente: guarda o menor atraso visto (sobe devagar se a rede piorar)
	clock[from] = off if not clock.has(from) or off < float(clock[from]) else lerpf(float(clock[from]), off, 0.02)
	var n := b.get_u8()
	for i in n:
		var slot := b.get_u8()
		var pos := Vector3(b.get_float(), b.get_float(), b.get_float())
		var q := Quaternion(b.get_16() / 32767.0, b.get_16() / 32767.0, b.get_16() / 32767.0, b.get_16() / 32767.0).normalized()
		var vel := Vector3(b.get_float(), b.get_float(), b.get_float())
		var vf := b.get_16() / 100.0
		var st := b.get_8() / 127.0
		var fl := b.get_u8()
		var hp := b.get_u8() / 255.0
		var af := b.get_u8()
		var ar := b.get_u8()
		var nc := b.get_u8()
		var lap := b.get_u8()
		var tp := b.get_u8()
		var dist := b.get_float()
		var c := _car_by_slot(slot)
		if c == null or not c.net_remote or c.owner_id != from:
			continue
		if int(c.get_meta("tp", -1)) != tp:
			c.set_meta("tp", tp)
			c.net_buf = []
		c.net_buf.append({"t": ts, "p": pos, "q": q, "v": vel})
		if c.net_buf.size() > 20:
			c.net_buf.pop_front()
		c.v_f = vf
		c.steer_s = st
		c.nitroing = fl & 1 != 0
		c.drifting = fl & 2 != 0
		c.ctrl.fire = fl & 8 != 0
		c.ctrl.drop = fl & 16 != 0
		c.ctrl.brake = 1.0 if fl & 32 else 0.0
		var wrecked := fl & 4 != 0
		if not wrecked and c.wrecked:
			c.repair()
		c.health = hp * c.max_health
		c.ammo_f = af
		c.ammo_r = ar
		c.nitro_ch = nc
		c.lap = lap
		c.dist = dist


func _apply_remote() -> void:
	var now := _now()
	for c in game.racers():
		if not c.net_remote or c.net_buf.is_empty():
			continue
		var rt: float = now - float(clock.get(c.owner_id, 0.0)) - DELAY
		var buf: Array = c.net_buf
		var a: Dictionary = buf[0]
		var bb: Dictionary = buf[buf.size() - 1]
		var pos: Vector3
		var q: Quaternion
		if rt <= float(a.t):
			pos = a.p
			q = a.q
		elif rt >= float(bb.t):
			# sem pacote novo: continua pela velocidade por até 0,25 s
			var ex := minf(rt - float(bb.t), 0.25)
			pos = (bb.p as Vector3) + (bb.v as Vector3) * ex
			q = bb.q
		else:
			for i in range(buf.size() - 1):
				var s0: Dictionary = buf[i]
				var s1: Dictionary = buf[i + 1]
				if rt >= float(s0.t) and rt <= float(s1.t):
					var u := (rt - float(s0.t)) / maxf(float(s1.t) - float(s0.t), 1e-4)
					# Hermite com as velocidades: curva suave mesmo a 20 pacotes/s
					var dtt := float(s1.t) - float(s0.t)
					var p0: Vector3 = s0.p
					var p1: Vector3 = s1.p
					var m0: Vector3 = (s0.v as Vector3) * dtt
					var m1: Vector3 = (s1.v as Vector3) * dtt
					var u2 := u * u
					var u3 := u2 * u
					pos = p0 * (2 * u3 - 3 * u2 + 1) + m0 * (u3 - 2 * u2 + u) + p1 * (-2 * u3 + 3 * u2) + m1 * (u3 - u2)
					q = (s0.q as Quaternion).slerp(s1.q, u)
					break
		c.global_transform = Transform3D(Basis(q), pos)


# ------------------------------------------------------------------ por quadro
func frame(_rdt: float) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--netquit=") and racing and game.race_t > float(a.substr(10)):
			print("NETQUIT")
			get_tree().quit()
	if net.in_room() and hud.cur_screen == "lobby" and Engine.get_process_frames() % 15 == 0:
		_refresh_lobby()
	# voz por proximidade: volume e lado pela distância entre o seu carro e o de quem fala
	var talkers: Array = []
	if racing and game.player:
		var me: Vector3 = game.player.global_position
		var right: Vector3 = game.cam.global_basis.x
		for c in game.humans:
			if c.owner_id == net.my_id or c.owner_id == 0:
				continue
			var d: Vector3 = c.global_position - me
			var dist := d.length()
			var g := clampf(1.0 - (dist - Voice.NEAR) / (Voice.FAR - Voice.NEAR), 0.0, 1.0)
			voice.set_spatial(c.owner_id, g * g * (3.0 - 2.0 * g), clampf(d.dot(right) / 30.0, -0.8, 0.8))
			if voice.is_talking(c.owner_id) and g > 0.05:
				talkers.append(c.display_name)
	elif net.in_room():
		for id in net.room.members:
			voice.set_spatial(id, 1.0, 0.0)
	if voice.talking:
		talkers.push_front("VOCÊ")
	talk_l.visible = racing and talkers.size() > 0 and game.mode in ["race", "countdown", "finish"]
	talk_l.text = "VOZ: " + ", ".join(talkers)
