class_name RoomCtl
extends Node
## Logica da sala no host: ondas de inimigos, sala vencida, votacao das portas, derrota.

var world: World
var active := false
var in_hub := false
var room: Dictionary = {}
var state := "idle"      # intro, fight, clear, done
var waves: Array = []
var wave_i := -1
var timer := 0.0
var pending := 0
var votes: Dictionary = {}
var vote_t := -1.0
var go_t := -1.0
var down_t := 0.0
var boss: Enemy
var _vote_push := 0.0

func stop() -> void:
	active = false
	state = "idle"
	votes = {}
	vote_t = -1.0
	go_t = -1.0
	boss = null
	pending = 0

func start_hub() -> void:
	stop()
	in_hub = true
	active = true
	state = "done"
	var lvl := world.level
	if lvl is Hub:
		world.server_spawn("dummy", (lvl as Hub).dummy_point, {"yaw": (lvl as Hub).dummy_yaw})

func start_room(r: Dictionary) -> void:
	stop()
	in_hub = false
	active = true
	room = r
	var type := str(r.get("type", "combat"))
	if type in ["shop", "rest", "treasure"]:
		state = "clear"
		world.cl_room_event.rpc("clear", {"quiet": true})
		return
	_plan_waves(type)
	state = "intro"
	timer = 1.8

func _plan_waves(type: String) -> void:
	waves = []
	var depth := float(room.get("depth", 0))
	var n := Game.player_count()
	var heat := float(Game.run.get("heat", 0))
	var biome: Dictionary = DB.BIOMES[str(room.get("biome", "forest"))]
	var pool: Array = biome["pool"]
	var budget := (5.0 + depth * 1.5) * (1.0 + 0.5 * (n - 1)) * (1.0 + 0.15 * heat)
	if Dev.args.has("easy"):
		budget *= 0.4
	if type == "boss":
		waves.append([{"kind": "guardiao", "boss": true}])
		return
	var count := 2 + (1 if depth >= 5 else 0)
	if type == "elite":
		var w: Array = [{"kind": "sentinela"}]
		w.append_array(_fill(biome["elite_adds"], budget * 0.45, 0.0))
		waves.append(w)
		waves.append(_fill(pool, budget * 0.5, 0.1 + heat * 0.05))
		return
	for i in count:
		waves.append(_fill(pool, budget / count * (0.85 + 0.3 * i), 0.03 * depth + heat * 0.04))

func _fill(pool: Array, budget: float, champ_chance: float) -> Array:
	var out: Array = []
	var guard := 0
	while budget > 0.5 and guard < 60 and pool.size() > 0:
		guard += 1
		var k: String = pool[randi() % pool.size()]
		var cost := float(DB.ENEMIES[k]["cost"])
		if cost > budget + 1.0:
			continue
		var champ := randf() < champ_chance and cost >= 2.0
		out.append({"kind": k, "champ": champ})
		budget -= cost * (2.2 if champ else 1.0)
	if out.is_empty() and pool.size() > 0:
		out.append({"kind": pool[0]})
	return out

func _spawn_wave(i: int) -> void:
	wave_i = i
	var list: Array = waves[i]
	var pts := world.level.enemy_spawn_points(list.size())
	pending = list.size()
	world.cl_room_event.rpc("wave", {"i": i + 1, "n": waves.size()})
	for k in list.size():
		_spawn_later(list[k], pts[k], 0.12 * k)

func _spawn_later(d: Dictionary, pos: Vector3, delay: float) -> void:
	await get_tree().create_timer(delay + 0.05, false).timeout
	if not active or state != "fight":
		pending = maxi(0, pending - 1)
		return
	pending = maxi(0, pending - 1)
	if d.get("boss", false):
		var p := Vector3(0, 0, -world.level.base_r * 0.45)
		boss = world.server_spawn(str(d["kind"]), p, {"yaw": PI})
		world.cl_room_event.rpc("boss", {"eid": boss.eid if boss else -1})
		return
	world.server_spawn(str(d["kind"]), pos, {"champ": bool(d.get("champ", false))})

func boss_phase(e: Enemy, phase: int) -> void:
	world.cl_fx.rpc("roar", e.position, 14.0)
	world.cl_room_event.rpc("boss_phase", {"p": phase})
	e.stun_t = 1.4
	e.st = "stun"
	e.play("roar", 0.1, true)
	boss_summon(e, 2 + phase + Game.player_count())

func boss_summon(e: Enemy, count: int) -> void:
	var pool: Array = DB.BIOMES["boss"]["pool"]
	for i in count:
		var a := randf() * TAU
		var p := e.position + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 8.0)
		p = world.level.clamp_inside(p, 1.5)
		world.server_spawn(pool[randi() % pool.size()], p, {})

func on_enemy_died(e: Enemy) -> void:
	if e == boss:
		boss = null
		for o: Enemy in world.enemy_list():
			if not o.dead and not o.is_dummy:
				world.server_damage(o, 99999.0, 2, Vector3.ZERO, "", 0.0, 0)
		state = "victory"
		timer = 4.5
		world.cl_room_event.rpc("boss_dead", {})

func _physics_process(delta: float) -> void:
	if not active or not Net.is_host():
		return
	if in_hub:
		return
	match state:
		"intro":
			timer -= delta
			if timer <= 0.0:
				state = "fight"
				_spawn_wave(0)
		"fight":
			if pending <= 0 and world.enemy_count() == 0:
				timer += delta
				if timer > 0.9:
					timer = 0.0
					if wave_i + 1 < waves.size():
						_spawn_wave(wave_i + 1)
					else:
						state = "clear"
						world.cl_room_event.rpc("clear", {})
			else:
				timer = 0.0
		"clear":
			_votes(delta)
		"victory":
			timer -= delta
			if timer <= 0.0:
				state = "done"
				Game.finish_run(true)
	# derrota: todos caidos
	if state in ["fight", "intro", "clear"] and Game.phase == Game.Phase.RUN:
		var any := false
		var all_down := true
		for p: Player in world.all_players():
			any = true
			if p.alive():
				all_down = false
		if any and all_down:
			down_t += delta
			if down_t > 2.2:
				state = "done"
				Game.finish_run(false)
		else:
			down_t = 0.0

func portal_vote(peer: int, idx: int) -> void:
	if state != "clear":
		return
	if idx < 0:
		votes.erase(peer)
	else:
		votes[peer] = idx
	if votes.is_empty():
		vote_t = -1.0
		go_t = -1.0
	elif vote_t < 0.0:
		vote_t = 12.0
	_push_votes()

func _push_votes() -> void:
	world.cl_room_event.rpc("votes", {"v": votes, "t": go_t if go_t >= 0.0 else vote_t})

func _votes(delta: float) -> void:
	if votes.is_empty():
		return
	var alive := 0
	for p: Player in world.all_players():
		if p.alive():
			alive += 1
	var decide := false
	if votes.size() >= maxi(alive, 1):
		if go_t < 0.0:
			go_t = 1.2
		go_t -= delta
		decide = go_t <= 0.0
	else:
		go_t = -1.0
		vote_t -= delta
		decide = vote_t <= 0.0
	_vote_push -= delta
	if _vote_push <= 0.0:
		_vote_push = 0.5
		_push_votes()
	if decide:
		var tally: Dictionary = {}
		for id in votes:
			tally[votes[id]] = int(tally.get(votes[id], 0)) + 1
		var best := 0
		var bn := -1
		for k in tally:
			if int(tally[k]) > bn:
				bn = int(tally[k])
				best = int(k)
		state = "done"
		Game.advance(best)

func send_state_to(id: int) -> void:
	if state == "clear":
		world.cl_room_event.rpc_id(id, "clear", {"quiet": true})
	if boss and is_instance_valid(boss):
		world.cl_room_event.rpc_id(id, "boss", {"eid": boss.eid})
