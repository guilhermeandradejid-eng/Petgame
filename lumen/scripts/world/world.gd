class_name World
extends Node3D
## O mundo em jogo: nivel atual (vila ou sala), herois, inimigos, projeteis.
## Concentra os RPCs de entidades: todos enderecam por id, entao nunca falha por
## "no nao encontrado" quando alguem ainda esta carregando.

signal prompt_changed(text)
signal hurt(frac)
signal revive_bar(target, frac)
signal room_event(kind, data)

const ESTATE_RATE := 1.0 / 14.0

var level: Level
var players_node: Node3D
var enemies_node: Node3D
var things: Node3D
var players: Dictionary = {}
var enemies: Dictionary = {}
var interactables: Array = []
var rig: CameraRig
var room_ctl: RoomCtl
var next_eid := 1
var _estate_t := 0.0
var _prompt_node: Node3D
var _prompt_text := ""

func _ready() -> void:
	Game.world = self
	players_node = Node3D.new()
	players_node.name = "Players"
	add_child(players_node)
	enemies_node = Node3D.new()
	enemies_node.name = "Enemies"
	add_child(enemies_node)
	things = Node3D.new()
	things.name = "Things"
	add_child(things)
	room_ctl = RoomCtl.new()
	room_ctl.name = "RoomCtl"
	room_ctl.world = self
	add_child(room_ctl)
	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)

# ------------------------------------------------------------------ niveis
func clear_all() -> void:
	_clear_level()
	for id in players.keys():
		players[id].queue_free()
	players = {}

func _clear_level() -> void:
	room_ctl.stop()
	if level:
		level.queue_free()
		level = null
	for e in enemies.values():
		e.queue_free()
	enemies = {}
	for c in things.get_children():
		c.queue_free()
	interactables = []
	_prompt_node = null
	set_prompt_text("")

func load_hub() -> void:
	_clear_level()
	level = Hub.new()
	level.name = "Level"
	add_child(level)
	level.build({})
	sync_players()
	_place_players(true)
	var me: Player = Game.me()
	if me:
		me.in_hub = true
		me.reset_run()
	if Net.is_host():
		room_ctl.start_hub()

func load_room(room: Dictionary, first: bool) -> void:
	_clear_level()
	var r := Room.new()
	level = r
	level.name = "Level"
	add_child(level)
	level.build(room)
	sync_players()
	_place_players(false)
	var me: Player = Game.me()
	if me:
		me.in_hub = false
		if first:
			me.reset_run()
		elif me.is_down():
			me.revive(0.5)
		me.procs.on_room_start()
	if Net.is_host():
		room_ctl.start_room(room)

func sync_players() -> void:
	for id in players.keys():
		if not Game.players.has(id):
			players[id].queue_free()
			players.erase(id)
	for id in Game.players:
		if players.has(id):
			players[id].apply_info(Game.players[id])
		else:
			var p := Player.new()
			p.setup(id, Game.players[id])
			p.position = spawn_point(players.size())
			players_node.add_child(p)
			players[id] = p
			if p.is_local:
				p.rig = rig
				rig.target = p
				rig.yaw = level.spawn_yaw if level else 0.0
			p.in_hub = Game.phase == Game.Phase.HUB

func _place_players(_hub: bool) -> void:
	var ids := players.keys()
	ids.sort()
	for i in ids.size():
		var p: Player = players[ids[i]]
		var sp := spawn_point(i)
		p.global_position = sp
		p.net_pos = sp
		p.velocity = Vector3.ZERO
		if p.is_local:
			p.face_yaw = level.spawn_yaw
			p.rotation.y = level.spawn_yaw
			rig.yaw = level.spawn_yaw
			rig.pitch = -0.3

func spawn_point(i: int) -> Vector3:
	if level == null or level.spawn_points.is_empty():
		return Vector3(i * 1.2, 0.1, 0)
	return level.spawn_points[i % level.spawn_points.size()]

# ------------------------------------------------------------------ consultas
func player_of(id: int) -> Player:
	return players.get(id)

func all_players() -> Array:
	return players.values()

func enemy_list() -> Array:
	return enemies.values()

func enemy_count() -> int:
	var n := 0
	for e: Enemy in enemies.values():
		if not e.dead and not e.is_dummy:
			n += 1
	return n

func nearest_enemy(pos: Vector3, max_d: float, exclude: Array = []) -> Enemy:
	var best: Enemy = null
	var bd := max_d
	for e: Enemy in enemies.values():
		if e.dead or exclude.has(e):
			continue
		var d := e.global_position.distance_to(pos) - e.radius
		if d < bd:
			bd = d
			best = e
	return best

func enemy_in_front(pos: Vector3, dir: Vector3, max_d: float) -> Enemy:
	var best: Enemy = null
	var score := -1e9
	for e: Enemy in enemies.values():
		if e.dead:
			continue
		var d := e.global_position - pos
		d.y = 0.0
		var l := d.length()
		if l > max_d + e.radius:
			continue
		var s := d.normalized().dot(dir) * 10.0 - l * 0.35
		if d.normalized().dot(dir) > 0.5 and s > score:
			score = s
			best = e
	return best if best else nearest_enemy(pos, max_d * 0.5)

func add_thing(n: Node) -> void:
	things.add_child(n)

func shake_near(pos: Vector3, amount: float, rng: float) -> void:
	var me: Player = Game.me()
	if me and rig:
		var d := me.global_position.distance_to(pos)
		rig.add_trauma(amount * clampf(1.0 - d / rng, 0.0, 1.0))

func hub_combat_ok(_p: Player) -> bool:
	return true

# ------------------------------------------------------------------ interacao
func register_interactable(n: Node3D) -> void:
	interactables.append(n)

func nearest_interactable(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for n in interactables:
		if not is_instance_valid(n) or not n.call("can_interact"):
			continue
		var d: float = n.global_position.distance_to(pos)
		if d < float(n.get("interact_radius")) and d < bd:
			bd = d
			best = n
	return best

func set_prompt(n: Node3D) -> void:
	if n == _prompt_node and (n == null or str(n.call("prompt")) == _prompt_text):
		return
	_prompt_node = n
	set_prompt_text("[E] " + str(n.call("prompt")) if n else "")

func set_prompt_text(t: String) -> void:
	if t == _prompt_text:
		return
	_prompt_text = t
	prompt_changed.emit(t)

func hud_hurt(frac: float) -> void:
	hurt.emit(frac)

func revive_progress(target: Player, frac: float) -> void:
	revive_bar.emit(target, frac)

func on_local_down() -> void:
	Game.toast.emit("Você caiu! Um aliado pode te levantar.", Color("ff7a7a"))

# ------------------------------------------------------------------ herois: estado e eventos
@rpc("any_peer", "call_remote", "unreliable_ordered")
func cl_pstate(pos: Vector3, yaw: float, loco: int, flags: int, hp: float, max_hp: float, shield: float) -> void:
	var p: Player = players.get(multiplayer.get_remote_sender_id())
	if p and not p.is_local:
		p.apply_net_state(pos, yaw, loco, flags, hp, max_hp, shield)

@rpc("any_peer", "call_remote", "reliable")
func cl_pevent(kind: String, data: Dictionary) -> void:
	var p: Player = players.get(multiplayer.get_remote_sender_id())
	if p and not p.is_local:
		p.on_remote_event(kind, data)

func give_effect(target: Player, kind: String, v: float, t: float) -> void:
	if target.is_local:
		cl_effect(kind, v, t)
	else:
		cl_effect.rpc_id(target.peer_id, kind, v, t)

@rpc("any_peer", "call_remote", "reliable")
func cl_effect(kind: String, v: float, t: float) -> void:
	var me: Player = Game.me()
	if me == null:
		return
	match kind:
		"heal":
			me.heal(me.max_hp * v)
		"shield":
			me.add_shield(me.max_hp * v, t)
		"dmg":
			me.buff("dmg", v, t)
		"haste":
			me.buff("haste", v, t)

@rpc("any_peer", "call_remote", "reliable")
func cl_revived(frac: float) -> void:
	var me: Player = Game.me()
	if me:
		me.revive(frac)

func local_nova(p: Player, r: float, mult: float, status: String, st_t: float) -> void:
	Fx.shockwave(p.global_position, r, Color("ffe38a"), 0.4)
	Sfx.play("slam", p.global_position, 0.7)
	p.skills.hit_circle(p.global_position, r, mult, "skill", {"kb": 6.0, "status": status, "status_t": st_t, "no_proc": true})

# ------------------------------------------------------------------ dano em inimigos
func request_hit(eid: int, dmg: float, flags: int, kb: Vector3, status: String, st_t: float, by: Player) -> void:
	var e: Enemy = enemies.get(eid)
	if e == null or e.dead:
		return
	# retorno imediato para quem bateu
	Fx.spark(e.global_position + Vector3(0, e.height * 0.55, 0), Color("fff2c8") if (flags & 1) == 0 else Color("ffd23e"))
	Sfx.play("hit_crit" if (flags & 1) != 0 else "hit", e.global_position, 0.75)
	if Net.is_host():
		server_damage(e, dmg, flags, kb, status, st_t, by.peer_id)
	else:
		srv_hit.rpc_id(1, eid, dmg, flags, kb, status, st_t)

@rpc("any_peer", "call_remote", "reliable")
func srv_hit(eid: int, dmg: float, flags: int, kb: Vector3, status: String, st_t: float) -> void:
	if not Net.is_host():
		return
	var e: Enemy = enemies.get(eid)
	if e and not e.dead:
		server_damage(e, clampf(dmg, 0.0, 99999.0), flags, kb.limit_length(30.0), status, st_t, multiplayer.get_remote_sender_id())

func server_damage(e: Enemy, dmg: float, flags: int, kb: Vector3, status: String, st_t: float, by: int) -> void:
	if e.dead:
		return
	e.apply_hit(dmg, flags, kb, status, st_t, by)
	if e.hp <= 0.0 and not e.is_dummy:
		cl_ehit.rpc(e.eid, dmg, 0.0, flags, by)
		cl_edie.rpc(e.eid, by)
		room_ctl.on_enemy_died(e)
	else:
		cl_ehit.rpc(e.eid, dmg, maxf(e.hp, 1.0), flags, by)

@rpc("authority", "call_local", "reliable")
func cl_ehit(eid: int, dmg: float, hp: float, flags: int, by: int) -> void:
	var e: Enemy = enemies.get(eid)
	if e:
		e.on_hit(dmg, hp, flags, by)

@rpc("authority", "call_local", "reliable")
func cl_edie(eid: int, by: int) -> void:
	var e: Enemy = enemies.get(eid)
	if e == null:
		return
	var pos := e.global_position
	var gold := int(e.def.get("gold", 1))
	e.on_die()
	enemies.erase(eid)
	var me: Player = Game.me()
	if me:
		# cada jogador ganha o proprio ouro: ninguem disputa saque
		spawn_coins(pos, gold)
		if by == Net.my_id():
			me.kills += 1
			me.procs.on_kill(e)
	room_event.emit("kill", {"boss": e.is_boss})

@rpc("authority", "call_local", "reliable")
func cl_eflinch(eid: int) -> void:
	var e: Enemy = enemies.get(eid)
	if e:
		e.on_flinch()

@rpc("authority", "call_local", "reliable")
func cl_ecancel(eid: int) -> void:
	var e: Enemy = enemies.get(eid)
	if e:
		e.on_cancel()

# ------------------------------------------------------------------ inimigos: nascer, estado, ataques
func server_spawn(kind: String, pos: Vector3, opts: Dictionary = {}) -> Enemy:
	var def: Dictionary = DB.ENEMIES[kind]
	var depth := float(Game.room.get("depth", 0))
	var n := Game.player_count()
	var hp := float(def["hp"]) * Game.heat_mult() * (1.0 + 0.55 * (n - 1)) * (1.0 + 0.10 * depth)
	if def.get("boss", false):
		hp = float(def["hp"]) * Game.heat_mult() * (1.0 + 0.75 * (n - 1))
	var champ := bool(opts.get("champ", false))
	if champ:
		hp *= 2.6
	if kind == "dummy":
		hp = float(def["hp"])
	var d := {"id": next_eid, "kind": kind, "pos": pos, "hp": hp, "champ": champ,
		"dmg": Game.heat_mult() * (1.0 + 0.06 * depth) * (1.3 if champ else 1.0), "yaw": float(opts.get("yaw", randf() * TAU))}
	next_eid += 1
	cl_espawn.rpc([d])
	return enemies.get(d["id"])

@rpc("authority", "call_local", "reliable")
func cl_espawn(list: Array) -> void:
	for d in list:
		if enemies.has(int(d["id"])):
			continue
		var e := Enemy.new()
		e.setup(d)
		enemies[e.eid] = e
		enemies_node.add_child(e)

func send_snapshot_to(id: int) -> void:
	var list: Array = []
	for e: Enemy in enemies.values():
		if e.dead:
			continue
		list.append({"id": e.eid, "kind": e.kind, "pos": e.position, "hp": e.max_hp, "cur": e.hp, "champ": e.champion,
			"dmg": e.dmg_mul, "yaw": e.yaw})
	if list.size() > 0:
		cl_espawn.rpc_id(id, list)
	room_ctl.send_state_to(id)

func _physics_process(delta: float) -> void:
	if not Net.is_host() or enemies.is_empty() or multiplayer.get_peers().is_empty():
		return
	_estate_t -= delta
	if _estate_t > 0.0:
		return
	_estate_t = ESTATE_RATE
	var arr := PackedFloat32Array()
	var count := 0
	for e: Enemy in enemies.values():
		if e.dead:
			continue
		arr.append(float(e.eid))
		arr.append(e.position.x)
		arr.append(e.position.y)
		arr.append(e.position.z)
		arr.append(e.yaw)
		arr.append(float(e.net_flags()))
		count += 1
		if count >= 40:
			cl_estate.rpc(arr)
			arr = PackedFloat32Array()
			count = 0
	if count > 0:
		cl_estate.rpc(arr)

@rpc("authority", "call_remote", "unreliable_ordered")
func cl_estate(arr: PackedFloat32Array) -> void:
	var i := 0
	while i + 5 < arr.size():
		var e: Enemy = enemies.get(int(arr[i]))
		if e:
			e.on_state(Vector3(arr[i + 1], arr[i + 2], arr[i + 3]), arr[i + 4], int(arr[i + 5]))
		i += 6

@rpc("authority", "call_local", "reliable")
func cl_eattack(eid: int, i: int, pos: Vector3, dir: Vector3, tpos: Vector3) -> void:
	var e: Enemy = enemies.get(eid)
	if e and not e.dead:
		e.on_attack(i, pos, dir, tpos)

@rpc("authority", "call_local", "reliable")
func cl_eproj(pos: Vector3, vel: Vector3, dmg: float, r: float, color: String, eid: int) -> void:
	var pr := Projectile.new()
	pr.setup_enemy(pos, vel, dmg, r, Color(color), eid)
	things.add_child(pr)

@rpc("authority", "call_local", "reliable")
func cl_hazard(pos: Vector3, r: float, delay: float, dmg: float, color: String, kind: String) -> void:
	_hazard(pos, r, delay, dmg, Color(color), kind)

func _hazard(pos: Vector3, r: float, delay: float, dmg: float, col: Color, kind: String) -> void:
	Fx.telegraph(pos, r, delay, Color("ff5a4a"), false)
	if kind == "crystal":
		Fx.meteor(pos, delay, r * 0.5, col)
	await get_tree().create_timer(delay, false).timeout
	Fx.explosion(pos, r, col)
	Sfx.play("explode", pos, 0.7)
	shake_near(pos, 0.5, 12.0)
	var me: Player = Game.me()
	if me and me.alive():
		var d := me.global_position - pos
		d.y = 0.0
		if d.length() <= r + 0.25:
			me.take_damage(dmg, pos, 6.0, -1)

@rpc("authority", "call_local", "reliable")
func cl_fx(kind: String, pos: Vector3, v: float) -> void:
	match kind:
		"bonk":
			Fx.burst(pos + Vector3(0, 0.6, 0), Color("ffffff"), v * 2.0)
			Fx.text(pos + Vector3(0, 1.8, 0), "BONK!", Color("ffe95c"), 1.0)
			Sfx.play("slam", pos)
			shake_near(pos, 0.5, 14.0)
		"roar":
			Fx.shockwave(pos, v, Color("7df9ff"), 0.8)
			Sfx.play("roar", pos)
			shake_near(pos, 0.9, 40.0)

# ------------------------------------------------------------------ projeteis e saque
func spawn_projectile(d: Dictionary) -> void:
	var pr := Projectile.new()
	pr.setup_player(d)
	things.add_child(pr)

func spawn_coins(pos: Vector3, amount: int) -> void:
	var me: Player = Game.me()
	if me == null or amount <= 0:
		return
	amount = maxi(1, int(round(amount * float(me.stats["gold"]))))
	var piles := mini(amount, 5)
	for i in piles:
		var c := Pickup.new()
		c.setup("coin", int(ceil(float(amount) / piles)) if i == 0 else amount / piles, pos)
		things.add_child(c)

func spawn_pickup(kind: String, value: int, pos: Vector3) -> void:
	var c := Pickup.new()
	c.setup(kind, value, pos)
	things.add_child(c)

# ------------------------------------------------------------------ fluxo da sala (vindo do host)
@rpc("authority", "call_local", "reliable")
func cl_room_event(kind: String, data: Dictionary) -> void:
	if level:
		level.on_room_event(kind, data)
	room_event.emit(kind, data)

@rpc("any_peer", "call_remote", "reliable")
func srv_portal(idx: int) -> void:
	if Net.is_host():
		room_ctl.portal_vote(multiplayer.get_remote_sender_id(), idx)

func vote_portal(idx: int) -> void:
	if Net.is_host():
		room_ctl.portal_vote(Net.my_id(), idx)
	else:
		srv_portal.rpc_id(1, idx)
