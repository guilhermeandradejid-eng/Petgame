class_name BattleManager
extends Node
## Encounters, Legend-of-Mana style: monsters idle on the field in groups. Walk up to one and the
## fight starts - a glowing arena closes around everyone, the camera frames it, nobody leaves until
## the group is beaten. The host owns the state machine; clients get start/end through RPCs.

const TRIGGER_M := 3.9
const ARENA_R := 4.7
const RESPAWN_TICKS := 780

var world: World
var encounters: Array = []      # [{center, names: [], state: idle|cooldown|battle, t: int}]
var active := false
var cur: Dictionary = {}
var _t := 0
var _engaged := false
var _arena: BattleArena
var _start_tick := 0
var _exp_pool := 0
var _rng := RandomNumberGenerator.new()
var wins := 0


func setup(w: World, centers: Array) -> void:
	world = w
	name = "BattleManager"
	_rng.seed = 4242
	for c in centers:
		encounters.append({"center": c, "names": [], "state": "idle", "t": 0, "exp": 0})
	if multiplayer.is_server():
		for enc in encounters:
			_spawn_group(enc)


func _spawn_group(enc: Dictionary) -> void:
	var n := _rng.randi_range(3, 4)
	enc["names"] = []
	enc["exp"] = 0
	for i in n:
		var kind := "capmook" if _rng.randf() < 0.5 else "hopkin"
		var ang := TAU * (float(i) / n) + _rng.randf_range(-0.3, 0.3)
		var off := Vector3(cos(ang), 0, sin(ang)) * _rng.randf_range(0.9, 1.9)
		var e := world._spawn_enemy(kind, enc["center"] + off + Vector3(0, 0.1, 0))
		e.encounter_id = encounters.find(enc)
		enc["names"].append(e.name)
		enc["exp"] += e.data.exp
	enc["state"] = "idle"


func _alive(names: Array) -> int:
	var n := 0
	for nm in names:
		var e := world.actors.get_node_or_null(String(nm)) as Enemy
		if e != null and not e.is_dead():
			n += 1
	return n


func _physics_process(_d: float) -> void:
	if not multiplayer.is_server():
		return
	_t += 1
	var players := get_tree().get_nodes_in_group("players")
	if active:
		_tick_battle(players)
		return
	for enc in encounters:
		if enc["state"] == "cooldown":
			enc["t"] -= 1
			if enc["t"] <= 0 and players.size() > 0:
				_spawn_group(enc)
		elif enc["state"] == "idle" and enc["t"] <= 0:
			for p in players:
				if p.is_dead():
					continue
				var d: Vector3 = p.global_position - enc["center"]
				d.y = 0.0
				if d.length() <= TRIGGER_M and _alive(enc["names"]) > 0:
					_start(enc)
					return
		elif enc["state"] == "idle":
			enc["t"] -= 1


func _start(enc: Dictionary) -> void:
	active = true
	cur = enc
	enc["state"] = "battle"
	_engaged = false
	_start_tick = 0
	rpc("rpc_battle_start", enc["center"], ARENA_R, enc["names"])


func _tick_battle(players: Array) -> void:
	_start_tick += 1
	if not _engaged and _start_tick >= 70:      # banner + camera move first, then they charge
		_engaged = true
		var i := 0
		for nm in cur["names"]:
			var e := world.actors.get_node_or_null(String(nm)) as Enemy
			if e != null and not e.is_dead():
				e.engage(i * 7)
				i += 1
	if _alive(cur["names"]) == 0:
		_end(true)
		return
	var any_alive := false
	for p in players:
		if not p.is_dead():
			any_alive = true
	if not any_alive:
		_end(false)


func _end(win: bool) -> void:
	active = false
	cur["state"] = "cooldown"
	cur["t"] = RESPAWN_TICKS if win else 360
	if not win:
		for nm in cur["names"]:
			var e := world.actors.get_node_or_null(String(nm)) as Enemy
			if e != null and not e.is_dead():
				e.standby()
		cur["state"] = "idle"
		cur["t"] = 420          # grace so the respawned party can regroup
	rpc("rpc_battle_end", win, int(cur["exp"]))


@rpc("authority", "call_local", "reliable")
func rpc_battle_start(center: Vector3, radius: float, names: Array) -> void:
	Game.arena_active = true
	Game.arena_center = center
	Game.arena_radius = radius
	Game.battle_damage = 0
	Game.combo_max = 0
	_start_tick = 0
	if _arena != null and is_instance_valid(_arena):
		_arena.queue_free()
	_arena = BattleArena.new()
	_arena.radius = radius
	world.fx.add_child(_arena)
	_arena.global_position = Vector3(center.x, 0, center.z)
	Sfx.play("battle_start")
	Juice.shake(0.5)
	Juice.fov_punch = -7.0
	Juice.chroma = 1.0
	Juice.screen_flash = 0.5
	Juice.ring(Vector3(center.x, 0.05, center.z), Color(1, 0.85, 0.4), radius * 2.0, 0.6, true)
	if world.battle_ui != null:
		world.battle_ui.battle_start()
	Game.log_event("battle_start", {"enemies": names.size()})


@rpc("authority", "call_local", "reliable")
func rpc_battle_end(win: bool, exp_value: int) -> void:
	Game.arena_active = false
	if _arena != null and is_instance_valid(_arena):
		_arena.close()
	_arena = null
	var lvl := 1
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_multiplayer_authority():
			if win:
				p.add_exp(exp_value)
				p.start_victory()
				p.hp = mini(p.max_hp, p.hp + int(p.max_hp * 0.25))
				p.mp = minf(p.max_mp, p.mp + p.max_mp * 0.5)
			lvl = p.level
	if win:
		wins += 1
		Sfx.play("victory_fanfare")
		Juice.shake(0.3)
		Juice.confetti(Game.arena_center)
	if world.battle_ui != null:
		world.battle_ui.battle_end(win, exp_value, lvl)
	Game.log_event("battle_end", {"win": win})
