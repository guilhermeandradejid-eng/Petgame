extends Node
## Fluxo geral: menu -> vila (hub) -> run de salas -> resumo -> vila.
## O host e a autoridade do fluxo; os clientes recebem tudo por RPC confiavel.

signal roster_changed
signal phase_changed
signal room_changed
signal toast(text, color)
signal run_ended(summary)

enum Phase { MENU, HUB, RUN }

var phase: int = Phase.MENU
var players: Dictionary = {}     # peer id -> {name, cls, look}
var run: Dictionary = {}         # estado da run (plano, passo, sala atual, heat)
var room: Dictionary = {}        # sala atual
var world: World = null          # definido pela cena principal
var ui: Windows = null           # janelas (recompensa, loja, guarda-roupa...)
var paused_ui := false           # alguma janela aberta: trava controles do heroi

func _ready() -> void:
	Net.peer_left.connect(_on_peer_left)
	Net.joined.connect(_on_joined)
	Net.session_closed.connect(_on_session_closed)
	Net.join_failed.connect(func() -> void: toast.emit("Não consegui conectar.", Color("ff7a7a")))

func my_info() -> Dictionary:
	return {"name": str(Save.data["name"]).substr(0, 16), "cls": Save.data["cls"], "look": Save.net_look()}

func me() -> Node:
	return world.player_of(Net.my_id()) if world else null

func player_count() -> int:
	return max(1, players.size())

# ------------------------------------------------------------------ sessao
func host_game(port: int = Net.DEFAULT_PORT, with_player: bool = true) -> void:
	Net.host(port)
	players = {}
	if with_player:
		players[Net.my_id()] = my_info()
	_set_phase(Phase.HUB)
	world.load_hub()
	roster_changed.emit()

func join_game(address: String, port: int = Net.DEFAULT_PORT) -> Error:
	return Net.join(address, port)

func leave_game() -> void:
	Net.leave()

func _on_joined() -> void:
	srv_register.rpc_id(1, my_info())

func _on_session_closed(reason: String) -> void:
	players = {}
	run = {}
	room = {}
	if world:
		world.clear_all()
	_set_phase(Phase.MENU)
	if reason != "saiu":
		toast.emit(reason, Color("ff7a7a"))

func _on_peer_left(id: int) -> void:
	if not Net.is_host():
		return
	if players.has(id):
		var nm: String = players[id]["name"]
		players.erase(id)
		cl_roster.rpc(players)
		cl_toast.rpc("%s saiu da sala." % nm, "ffd36b")

func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit()

@rpc("any_peer", "call_remote", "reliable")
func srv_register(info: Dictionary) -> void:
	if not Net.is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= Net.MAX_PLAYERS and not players.has(id):
		return
	players[id] = _clean_info(info)
	cl_roster.rpc(players)
	cl_toast.rpc("%s entrou na sala." % players[id]["name"], "8dffb0")
	# coloca o recem-chegado no estado atual
	if phase == Phase.RUN:
		cl_load_room.rpc_id(id, run, room)
		world.send_snapshot_to(id)
	else:
		cl_enter_hub.rpc_id(id)

@rpc("any_peer", "call_remote", "reliable")
func srv_update_info(info: Dictionary) -> void:
	if not Net.is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id] = _clean_info(info)
		cl_roster.rpc(players)

func _clean_info(info: Dictionary) -> Dictionary:
	var cls: String = str(info.get("cls", "espadachim"))
	if not DB.CLASSES.has(cls):
		cls = "espadachim"
	var look: Dictionary = info.get("look", {}) if info.get("look", {}) is Dictionary else {}
	return {"name": str(info.get("name", "Viajante")).substr(0, 16), "cls": cls, "look": look}

## Chamado localmente quando o jogador troca de classe ou de roupa na vila.
func push_my_info() -> void:
	if not Net.active:
		return
	if Net.is_host():
		players[Net.my_id()] = my_info()
		cl_roster.rpc(players)
	else:
		srv_update_info.rpc_id(1, my_info())

@rpc("authority", "call_local", "reliable")
func cl_roster(p: Dictionary) -> void:
	players = p
	roster_changed.emit()
	if world:
		world.sync_players()

@rpc("authority", "call_local", "reliable")
func cl_toast(text: String, color: String) -> void:
	toast.emit(text, Color(color))

# ------------------------------------------------------------------ vila
@rpc("authority", "call_local", "reliable")
func cl_enter_hub() -> void:
	run = {}
	room = {}
	_set_phase(Phase.HUB)
	world.load_hub()
	room_changed.emit()

# ------------------------------------------------------------------ run
## Servidor dedicado: o host nao tem heroi proprio, entao qualquer jogador comanda a sala.
func is_dedicated() -> bool:
	return Net.active and not players.has(1)

func can_command() -> bool:
	return Net.is_host() or is_dedicated()

func request_start_run(heat: int = -1) -> void:
	if Net.is_host():
		start_run(heat)
	elif is_dedicated():
		srv_start.rpc_id(1, heat)
	else:
		toast.emit("Só o host pode abrir o portal.", Color("ffd36b"))

@rpc("any_peer", "call_remote", "reliable")
func srv_start(heat: int) -> void:
	if Net.is_host() and not players.has(1):
		start_run(clampi(heat, 0, 5))

@rpc("any_peer", "call_remote", "reliable")
func srv_return() -> void:
	if Net.is_host() and not players.has(1) and phase == Phase.RUN:
		return_to_hub()

func start_run(heat: int = -1) -> void:
	if not Net.is_host() or phase == Phase.RUN:
		return
	if heat < 0:
		heat = int(Save.data.get("heat", 0))
	var seed_v := randi()
	run = {"seed": seed_v, "heat": heat, "step": 0, "plan": make_plan(seed_v), "rooms_cleared": 0, "t0": Time.get_ticks_msec()}
	_go_room(run["plan"][0][0])

func make_plan(seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var rewards := ["boon", "boon", "boon", "spell", "relic", "gold"]
	var mk := func(type: String, biome: String, idx: int) -> Dictionary:
		var rw := "boon"
		match type:
			"combat": rw = rewards[rng.randi() % rewards.size()]
			"elite": rw = "relic"
			"boss": rw = "boss"
			"shop": rw = "shop"
			"rest": rw = "rest"
			"treasure": rw = "relic"
		return {"type": type, "biome": biome, "seed": rng.randi(), "depth": idx, "reward": rw}
	var layout := [
		[["combat", "forest"]],
		[["combat", "forest"], ["combat", "forest"]],
		[["combat", "forest"], ["shop", "forest"]],
		[["elite", "forest"]],
		[["rest", "forest"], ["shop", "forest"]],
		[["combat", "crystal"], ["combat", "crystal"]],
		[["combat", "crystal"], ["treasure", "crystal"]],
		[["elite", "crystal"]],
		[["rest", "crystal"]],
		[["boss", "boss"]],
	]
	var plan: Array = []
	for i in layout.size():
		var opts: Array = []
		for o in layout[i]:
			opts.append(mk.call(o[0], o[1], i))
		# portas com a mesma recompensa nao tem graca: sorteia de novo a segunda
		if opts.size() == 2 and opts[0]["type"] == "combat" and opts[1]["type"] == "combat":
			var guard := 0
			while opts[1]["reward"] == opts[0]["reward"] and guard < 8:
				opts[1]["reward"] = rewards[rng.randi() % rewards.size()]
				guard += 1
		plan.append(opts)
	return plan

func _go_room(r: Dictionary) -> void:
	room = r.duplicate(true)
	room["players"] = player_count()
	cl_load_room.rpc(run, room)

@rpc("authority", "call_local", "reliable")
func cl_load_room(r: Dictionary, rm: Dictionary) -> void:
	var first := phase != Phase.RUN
	run = r
	room = rm
	_set_phase(Phase.RUN)
	world.load_room(room, first)
	room_changed.emit()

## Host: a sala foi vencida e o grupo escolheu a porta 'choice'.
func advance(choice: int) -> void:
	if not Net.is_host() or phase != Phase.RUN:
		return
	run["rooms_cleared"] = int(run["rooms_cleared"]) + 1
	var step := int(run["step"]) + 1
	if step >= run["plan"].size():
		finish_run(true)
		return
	run["step"] = step
	var opts: Array = run["plan"][step]
	_go_room(opts[clampi(choice, 0, opts.size() - 1)])

func next_options() -> Array:
	if run.is_empty():
		return []
	var step := int(run["step"]) + 1
	if step >= run["plan"].size():
		return []
	return run["plan"][step]

func finish_run(victory: bool) -> void:
	if not Net.is_host() or phase != Phase.RUN:
		return
	var summary := {"victory": victory, "rooms": int(run.get("rooms_cleared", 0)), "heat": int(run.get("heat", 0)),
		"time": (Time.get_ticks_msec() - int(run.get("t0", 0))) / 1000.0}
	cl_run_end.rpc(summary)
	if not players.has(1):
		# servidor dedicado: ninguem aperta o botao do host, entao volta sozinho
		get_tree().create_timer(12.0).timeout.connect(func() -> void:
			if phase == Phase.RUN:
				return_to_hub())

@rpc("authority", "call_local", "reliable")
func cl_run_end(summary: Dictionary) -> void:
	run_ended.emit(summary)

## Host: todos viram o resumo; volta para a vila.
func return_to_hub() -> void:
	if Net.is_host():
		cl_enter_hub.rpc()
	elif is_dedicated():
		srv_return.rpc_id(1)

func heat_mult() -> float:
	return 1.0 + 0.28 * float(run.get("heat", 0))
