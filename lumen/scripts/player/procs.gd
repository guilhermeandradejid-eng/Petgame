class_name Procs
extends RefCounted
## Efeitos especiais das reliquias (gatilhos ao acertar, matar, esquivar, sofrer dano...).

var p: Player
var hit_n := 0
var forced_crit := false
var kill_stacks := 0
var hurt_cd := 0.0
var star_t := 6.0
var aura_t := 0.0
var orbit: Zone

func _init(player: Player) -> void:
	p = player

func has(id: String) -> bool:
	return p.relics.has(id)

func reset() -> void:
	hit_n = 0
	forced_crit = false
	kill_stacks = 0
	if is_instance_valid(orbit):
		orbit.queue_free()

func on_gain(id: String) -> void:
	if id == "laminas_gemeas":
		_start_orbit()
	if id == "manto_aurora":
		p.add_shield(p.max_hp * 0.3, 9999.0)

func on_room_start() -> void:
	kill_stacks = 0
	if has("manto_aurora"):
		p.add_shield(p.max_hp * 0.3, 9999.0)
	if has("laminas_gemeas"):
		_start_orbit()

func _start_orbit() -> void:
	if is_instance_valid(orbit):
		orbit.queue_free()
	orbit = Zone.make(p.global_position, 99999.0, 0.35)
	orbit.follow = p
	Fx.orbit_visual(orbit, 2.4, 2, Color("7df9ff"))
	orbit.on_tick = func() -> void:
		if is_instance_valid(p) and p.alive() and not p.in_hub:
			p.skills.hit_circle(p.global_position, 2.9, 0.45, "skill", {"kb": 1.0, "no_proc": true})
	Game.world.add_thing(orbit)

func tick(delta: float) -> void:
	hurt_cd = maxf(0.0, hurt_cd - delta)
	if p.in_hub:
		return
	if has("estrela_cadente"):
		star_t -= delta
		if star_t <= 0.0:
			star_t = 6.0
			var e: Enemy = Game.world.nearest_enemy(p.global_position, 16.0)
			if e:
				_star(e.global_position)
	if has("fio_dourado"):
		aura_t -= delta
		if aura_t <= 0.0:
			aura_t = 1.0
			for o: Player in Game.world.all_players():
				if o.alive() and o.global_position.distance_to(p.global_position) <= 9.0:
					Game.world.give_effect(o, "dmg", 0.12, 1.3)

func _star(pos: Vector3) -> void:
	pos.y = 0.0
	Fx.telegraph(pos, 2.4, 0.5, Color("ffd36b"), true)
	Fx.meteor(pos, 0.5, 1.4, Color("ffd36b"))
	await p.get_tree().create_timer(0.5).timeout
	if not is_instance_valid(p):
		return
	Fx.explosion(pos, 2.4, Color("ffd36b"))
	Sfx.play("explode", pos, 0.6)
	p.skills.hit_circle(pos, 2.4, 2.2, "skill", {"kb": 4.0, "from": pos, "no_proc": true})

func dmg_bonus() -> float:
	return minf(0.36, kill_stacks * 0.03) if has("tambor_guerra") else 0.0

func target_bonus(e: Enemy) -> float:
	var k := 1.0
	if has("lente_cacador") and e.hp >= e.max_hp * 0.95:
		k *= 1.35
	if has("gema_gelida") and e.is_slowed():
		k *= 1.3
	return k

func take_forced_crit() -> bool:
	if forced_crit:
		forced_crit = false
		return true
	return false

func on_hit(e: Enemy, dmg: float, crit: bool, kind: String) -> void:
	hit_n += 1
	var pos := e.global_position
	if has("sino_prata") and hit_n % 5 == 0:
		var top := pos + Vector3(0, 9.0, 0)
		Fx.lightning(top, pos + Vector3(0, e.height * 0.5, 0), Color("dff6ff"))
		Fx.spark(pos + Vector3(0, e.height * 0.5, 0), Color("dff6ff"))
		Sfx.play("zap", pos, 0.7)
		p.skills.hit(e, 1.6, "skill", {"kb": 1.0, "no_proc": true})
	if crit and has("trevo_dourado") and randf() < 0.3:
		Game.world.spawn_coins(pos, 2)
	if has("polvora_feerica") and randf() < 0.2:
		Fx.explosion(pos, 2.0, Color("ff9ad5"))
		Sfx.play("explode", pos, 0.5)
		p.skills.hit_circle(pos, 2.0, 0.6, "skill", {"kb": 2.0, "from": pos, "no_proc": true})
	if kind == "primary" and randf() < float(p.stats["p_chain"]):
		var last := pos + Vector3(0, e.height * 0.5, 0)
		var seen: Array = [e]
		var cur: Enemy = Game.world.nearest_enemy(pos, 6.0, seen)
		Sfx.play("zap", pos, 0.5)
		for i in 3:
			if cur == null:
				break
			seen.append(cur)
			var tp := cur.global_position + Vector3(0, cur.height * 0.5, 0)
			Fx.lightning(last, tp, Color("ffe95c"))
			p.skills.hit(cur, 0.6, "skill", {"kb": 0.5, "no_proc": true})
			last = tp
			cur = Game.world.nearest_enemy(cur.global_position, 6.0, seen)

func on_kill(e: Enemy) -> void:
	var pos := e.global_position
	if has("coracao_brasa"):
		Fx.explosion(pos, 2.6, Color("ff8a3d"))
		Sfx.play("explode", pos, 0.6)
		p.skills.hit_circle(pos, 2.6, 0.9, "skill", {"kb": 3.0, "from": pos, "no_proc": true, "status": "burn"})
	if has("semente_viva"):
		p.heal(3.0, false)
	if has("tambor_guerra"):
		kill_stacks += 1

func on_dodge(origin: Vector3) -> void:
	if has("lua_crescente"):
		forced_crit = true
	if has("pedra_trovao") and not p.in_hub:
		Fx.shockwave(origin, 3.2, Color("ffe95c"), 0.35)
		Fx.spark(origin + Vector3(0, 0.6, 0), Color("ffe95c"))
		Sfx.play("zap", origin, 0.7)
		p.skills.hit_circle(origin, 3.2, 1.3, "skill", {"kb": 2.0, "from": origin, "no_proc": true, "status": "stun", "status_t": 0.6})

func on_skill(_slot: String) -> void:
	pass

func skill_echo(slot: String) -> bool:
	if slot != "ult" and has("amuleto_eco") and randf() < 0.25:
		Fx.text(p.global_position + Vector3(0, 2.0, 0), "Eco!", Color("c07bff"), 0.9)
		return true
	return false

func on_hurt(_amount: float, _eid: int) -> void:
	if has("escudo_espelhado") and hurt_cd <= 0.0:
		hurt_cd = 4.0
		Game.world.local_nova(p, 4.0, 1.5, "stun", 0.8)

func on_revive_ally(target: Player) -> void:
	if has("elo_solidario"):
		p.heal(p.max_hp * 0.25)
		Game.world.give_effect(target, "heal", 0.25, 0.0)
