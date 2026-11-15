class_name Skills
extends RefCounted
## Execucao das habilidades. Cada funcao roda tanto no dono (local = true: move o heroi
## e aplica dano) quanto nos fantoches dos outros jogadores (so animacao e efeitos).

var p: Player

func _init(player: Player) -> void:
	p = player

func _wait(t: float) -> Signal:
	return p.get_tree().create_timer(maxf(t, 0.001), false).timeout

func _world() -> Node:
	return Game.world

# ------------------------------------------------------------------ disparo
func use(slot: String) -> void:
	var id: String = p.slots[slot]
	var def: Dictionary = DB.SKILLS[id]
	var ctx := {"id": id, "slot": slot, "d": p.aim_flat(), "as": float(p.stats["aspd"]), "n": 0}
	if def.has("range"):
		ctx["pt"] = _ground_point(float(def["range"]))
	if def["fn"] == "combo":
		ctx["n"] = p.combo_i % (def["steps"] as Array).size()
	if def["fn"] == "shot" or def["fn"] == "backflip_shot":
		p.shot_count += 1
		ctx["k"] = p.shot_count
		ctx["aim"] = _aim_point()
	if def["fn"] == "blink":
		var dir: Vector3 = p.wish.normalized() if p.wish.length() > 0.1 else p.aim_flat()
		ctx["d"] = dir
		ctx["to"] = _blink_dest(dir, float(def["dist"]))
	if slot != "primary":
		p.start_cd(slot)
		p.procs.on_skill(slot)
	_world().cl_pevent.rpc("skill", ctx)
	_run(def, ctx, true)

func play_remote(ctx: Dictionary) -> void:
	var id := str(ctx.get("id", ""))
	if DB.SKILLS.has(id):
		_run(DB.SKILLS[id], ctx, false)

func _run(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var fn := "_" + str(def["fn"])
	if has_method(fn):
		call(fn, def, ctx, local)

func _ground_point(rng: float) -> Vector3:
	if Dev.bot or p.rig == null:
		var e: Enemy = _world().nearest_enemy(p.global_position, rng + 4.0)
		if e:
			var q := e.global_position
			var off := q - p.global_position
			off.y = 0.0
			if off.length() > rng:
				q = p.global_position + off.normalized() * rng
			q.y = 0.0
			return q
		return p.global_position + p.forward() * minf(rng, 6.0)
	return p.rig.ground_point(rng)

func _aim_point() -> Vector3:
	if Dev.bot or p.rig == null:
		var e: Enemy = _world().nearest_enemy(p.global_position, 40.0)
		if e:
			return e.global_position + Vector3(0, e.height * 0.5, 0)
		return p.global_position + p.forward() * 20.0 + Vector3(0, 1, 0)
	return p.rig.aim_point(60.0)

func _blink_dest(dir: Vector3, dist: float) -> Vector3:
	var from := p.global_position + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * dist, 1)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	var d := dist
	if hit:
		d = maxf(0.0, from.distance_to(hit["position"]) - 0.6)
	var dest := p.global_position + dir * d
	dest.y = maxf(p.global_position.y, 0.0)
	return dest

# ------------------------------------------------------------------ dano
func roll(mult: float, kind: String) -> Array:
	var s: Dictionary = p.stats
	var dmg: float = float(s["atk"]) * mult * randf_range(0.94, 1.06)
	dmg *= float(s["primary"]) if kind == "primary" else float(s["skill"])
	dmg *= 1.0 + p.buff_v("dmg") + p.procs.dmg_bonus()
	var crit := randf() < float(s["crit"]) or p.procs.take_forced_crit()
	if crit:
		dmg *= float(s["crit_dmg"])
	return [dmg, crit]

## Acerta um inimigo. opts: kb (forca), from (origem do empurrao), status, status_t, pull.
func hit(e: Enemy, mult: float, kind: String, opts: Dictionary = {}) -> void:
	if e == null or e.dead:
		return
	var r := roll(mult * p.procs.target_bonus(e), kind)
	var dmg: float = r[0]
	var crit: bool = r[1]
	var from: Vector3 = opts.get("from", p.global_position)
	var kbv := e.global_position - from
	kbv.y = 0.0
	kbv = kbv.normalized() * float(opts.get("kb", 1.5)) if kbv.length() > 0.01 else Vector3.ZERO
	if opts.get("pull", false):
		kbv = -kbv
	var status := str(opts.get("status", ""))
	var st_t := float(opts.get("status_t", 0.0))
	if kind == "primary" and status == "":
		var s: Dictionary = p.stats
		if randf() < float(s["p_burn"]):
			status = "burn"
		elif randf() < float(s["p_chill"]):
			status = "chill"
		elif randf() < float(s["p_poison"]):
			status = "poison"
	_world().request_hit(e.eid, dmg, 1 if crit else 0, kbv, status, st_t, p)
	p.dmg_done += dmg
	if float(p.stats["lifesteal"]) > 0.0:
		p.heal(dmg * float(p.stats["lifesteal"]), false)
	if not opts.get("no_proc", false):
		p.procs.on_hit(e, dmg, crit, kind)

func hit_circle(center: Vector3, r: float, mult: float, kind: String, opts: Dictionary = {}) -> int:
	var n := 0
	for e: Enemy in _world().enemy_list():
		if e.dead:
			continue
		var d := e.global_position - center
		d.y = 0.0
		if d.length() <= r + e.radius:
			if not opts.has("from"):
				opts["from"] = center
			hit(e, mult, kind, opts)
			n += 1
	return n

func hit_arc(center: Vector3, dir: Vector3, r: float, angle: float, mult: float, kind: String, opts: Dictionary = {}) -> int:
	var n := 0
	var cosa := cos(deg_to_rad(angle * 0.5))
	for e: Enemy in _world().enemy_list():
		if e.dead:
			continue
		var d := e.global_position - center
		d.y = 0.0
		var l := d.length()
		if l > r + e.radius:
			continue
		if angle < 359.0 and l > e.radius + 0.6 and d.normalized().dot(dir) < cosa:
			continue
		hit(e, mult, kind, opts)
		n += 1
	return n

func hit_line(a: Vector3, b: Vector3, width: float, mult: float, kind: String, opts: Dictionary = {}) -> int:
	var n := 0
	var ab := b - a
	ab.y = 0.0
	var l2 := ab.length_squared()
	for e: Enemy in _world().enemy_list():
		if e.dead:
			continue
		var ap := e.global_position - a
		ap.y = 0.0
		var t := clampf(ap.dot(ab) / l2, 0.0, 1.0) if l2 > 0.0001 else 0.0
		var c := a + ab * t
		c.y = 0.0
		var ep := e.global_position
		ep.y = 0.0
		if c.distance_to(ep) <= width * 0.5 + e.radius:
			hit(e, mult, kind, opts)
			n += 1
	return n

func _impact(n: int, strength: float = 0.25) -> void:
	if n <= 0:
		return
	p.visual.hitstop(0.05 + strength * 0.08)
	if p.rig:
		p.rig.add_trauma(strength)

func _col(def: Dictionary) -> Color:
	return Color(str(def.get("color", DB.CLASSES[p.cls]["color"])))

func _kind(ctx: Dictionary) -> String:
	return "primary" if str(ctx.get("slot", "")) == "primary" else "skill"

# ------------------------------------------------------------------ corpo a corpo
func _combo(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var st: Dictionary = def["steps"][int(ctx["n"])]
	var spd: float = float(st.get("speed", 1.0)) * float(ctx["as"])
	var dir: Vector3 = ctx["d"]
	var id := 0
	if local:
		p.face_dir(dir)
		id = p.begin_action(float(st["dur"]) / spd, float(st["cancel"]) / spd)
		p.combo_i = int(ctx["n"]) + 1
		p.combo_t = float(st["dur"]) / spd + 0.5
		p.lunge(float(st["lunge"]))
	else:
		p.busy_until = p.now + float(st["dur"]) / spd
	p.visual.play_once(st["anim"], 0.06, spd)
	Sfx.play("swing_heavy" if int(st["slash"]) == 2 else "swing", p.global_position, 0.8)
	await _wait(float(st["hit"]) / spd)
	if not is_instance_valid(p) or (local and not p.action_ok(id)):
		return
	var col := Color(DB.CLASSES[p.cls]["color"]).lightened(0.35)
	Fx.slash(p, int(st["slash"]), float(st["r"]), col)
	if int(st["slash"]) == 2:
		Fx.shockwave(p.global_position + p.forward() * 1.2, float(st["r"]) * 0.75, col, 0.35)
		Sfx.play("slam", p.global_position, 0.8)
	if local:
		var opts := {"kb": float(st.get("kb", 2.0))}
		if st.has("status"):
			opts["status"] = st["status"]
			opts["status_t"] = float(st.get("status_t", 1.0))
		var n := hit_arc(p.global_position, p.forward(), float(st["r"]), float(st["angle"]), float(st["mult"]), "primary", opts)
		_impact(n, float(st.get("shake", 0.22)))

func _dash_strike(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var dir: Vector3 = ctx["d"]
	var t := float(def["time"])
	var start := p.global_position
	var id := 0
	if local:
		p.face_dir(dir)
		id = p.begin_action(t + 0.32, t + 0.16)
		p.invuln_t = maxf(p.invuln_t, t + 0.08)
		p.carry(dir * float(def["dist"]) / t, t)
	else:
		p.busy_until = p.now + t + 0.3
	p.visual.play_once(def["anim"], 0.04, 1.5)
	Sfx.play("dash", p.global_position)
	Fx.trail(p, t + 0.1, _col(def).lightened(0.3))
	await _wait(t)
	if not is_instance_valid(p):
		return
	Fx.thrust(start, p.global_position, _col(def).lightened(0.3))
	if local:
		var n := hit_line(start, p.global_position + dir * 1.2, float(def["width"]), float(def["mult"]), "skill", {"kb": float(def["kb"])})
		_impact(n, 0.35)

func _whirl(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var time := float(def["time"])
	var id := 0
	if local:
		id = p.begin_action(time, time, 0.75, true)
	else:
		p.busy_until = p.now + time
	p.visual.play("spin-loop", 0.1, 1.5)
	var fx := Fx.whirl(p, float(def["r"]), time, _col(def).lightened(0.3))
	var el := 0.0
	while el < time:
		Sfx.play("swing", p.global_position, 0.6)
		if local:
			if not p.action_ok(id):
				break
			var n := hit_circle(p.global_position, float(def["r"]), float(def["mult"]), "skill", {"kb": 1.0})
			_impact(n, 0.1)
		await _wait(float(def["tick"]))
		if not is_instance_valid(p):
			return
		el += float(def["tick"])
	if is_instance_valid(fx):
		fx.queue_free()
	if local:
		p.end_action(id)
	else:
		p.busy_until = p.now

func _leap_slam(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var pt: Vector3 = ctx.get("pt", p.global_position + p.forward() * 5.0)
	var t := 0.42
	var id := 0
	var off := pt - p.global_position
	off.y = 0.0
	if local:
		p.face_dir(off if off.length() > 0.2 else p.forward())
		id = p.begin_action(t + 0.45, t + 0.3)
		p.invuln_t = maxf(p.invuln_t, t)
		p.carry(off / t, t)
		p.velocity.y = Player.GRAVITY * t * 0.5
	else:
		p.busy_until = p.now + t + 0.4
	p.visual.play_once(def["anim"], 0.05, 0.37 / t * 1.0)
	Fx.telegraph(pt, float(def["r"]), t, _col(def), true)
	Sfx.play("jump", p.global_position)
	await _wait(t)
	if not is_instance_valid(p):
		return
	var c := p.global_position
	c.y = 0.0
	Fx.shockwave(c, float(def["r"]), _col(def).lightened(0.2), 0.45)
	Fx.burst(c + Vector3(0, 0.3, 0), _col(def), float(def["r"]) * 0.6)
	Sfx.play("slam", c)
	if local:
		var n := hit_circle(c, float(def["r"]), float(def["mult"]), "skill", {"kb": float(def["kb"])})
		_impact(maxi(n, 1), 0.6)

func _blade_storm(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var time := float(def["time"])
	var id := 0
	if local:
		id = p.begin_action(time + 0.5, time + 0.35, 0.5, true)
		p.invuln_t = maxf(p.invuln_t, time + 0.3)
	else:
		p.busy_until = p.now + time + 0.4
	p.visual.play("spin-loop", 0.08, 2.2)
	var col := _col(def).lightened(0.35)
	var fx := Fx.whirl(p, float(def["r"]) * 0.8, time, col)
	Fx.telegraph(p.global_position, float(def["r"]), time, col, true, p)
	var el := 0.0
	while el < time:
		var a := randf() * TAU
		var q := p.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, float(def["r"]) * 0.8)
		Fx.cut(q + Vector3(0, 0.9, 0), col, randf_range(1.6, 2.6))
		Sfx.play("swing", q, 0.55)
		if local:
			if not p.action_ok(id):
				break
			var n := hit_circle(p.global_position, float(def["r"]), float(def["mult"]), "skill", {"kb": 0.5})
			_impact(n, 0.08)
		await _wait(float(def["tick"]))
		if not is_instance_valid(p):
			return
		el += float(def["tick"])
	if is_instance_valid(fx):
		fx.queue_free()
	p.visual.play_once("sword_atk3" if p.wt == "sword" else "slam", 0.05, 1.6)
	await _wait(0.2)
	if not is_instance_valid(p):
		return
	Fx.shockwave(p.global_position, float(def["r"]), col, 0.5)
	Fx.burst(p.global_position + Vector3(0, 0.8, 0), col, float(def["r"]) * 0.7)
	Sfx.play("explode", p.global_position)
	if local:
		var n2 := hit_circle(p.global_position, float(def["r"]), float(def["final"]), "skill", {"kb": 8.0})
		_impact(maxi(n2, 1), 0.8)

func _bash(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var dir: Vector3 = ctx["d"]
	var delay := float(def.get("delay", 0.17))
	var id := 0
	if local:
		p.face_dir(dir)
		id = p.begin_action(delay + 0.4, delay + 0.22)
		if def.has("guard"):
			p.guard_t = float(def["guard"])
			p.guard_v = 0.7
		p.lunge(1.2)
	else:
		p.busy_until = p.now + delay + 0.35
	p.visual.play_once(def["anim"], 0.05, 1.0)
	Sfx.play("swing_heavy", p.global_position)
	await _wait(delay)
	if not is_instance_valid(p) or (local and not p.action_ok(id)):
		return
	var col := _col(def).lightened(0.3)
	if def.get("vfx", "") == "gust":
		Fx.gust(p.global_position + Vector3(0, 0.8, 0), p.forward(), float(def["r"]), float(def["angle"]), col)
		Sfx.play("wind", p.global_position)
	else:
		Fx.cone(p.global_position, p.forward(), float(def["r"]), float(def["angle"]), col)
		Sfx.play("slam", p.global_position, 0.8)
	if local:
		var opts := {"kb": float(def.get("kb", 3.0))}
		if def.has("status"):
			opts["status"] = def["status"]
			opts["status_t"] = float(def.get("status_t", 1.0))
		var n := hit_arc(p.global_position, p.forward(), float(def["r"]), float(def["angle"]), float(def["mult"]), "skill", opts)
		_impact(n, 0.4)

# ------------------------------------------------------------------ projeteis
func _shot(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var primary := str(ctx.get("slot", "")) == "primary"
	var spd: float = float(def.get("anim_speed", 1.0)) * (float(ctx["as"]) if primary else 1.0)
	var rel: float = float(def["release"]) / (float(ctx["as"]) if primary else 1.0)
	var dur: float = float(def["dur"]) / (float(ctx["as"]) if primary else 1.0)
	var dir: Vector3 = ctx["d"]
	var id := 0
	if local:
		p.face_dir(dir)
		id = p.begin_action(dur, dur * 0.82)
	else:
		p.busy_until = p.now + dur
	p.visual.play_once(def["anim"], 0.05, spd)
	if str(def["proj"]).begins_with("arrow"):
		Sfx.play("bow_draw", p.global_position, 0.5)
	await _wait(rel)
	if not is_instance_valid(p) or (local and not p.action_ok(id)):
		return
	var muzzle := p.global_position + Vector3(0, 0.95, 0) + p.forward() * 0.55
	var aim: Vector3 = ctx.get("aim", muzzle + dir * 20.0)
	var d3 := aim - muzzle
	if d3.length() < 1.5 or d3.normalized().dot(dir) < 0.2:
		d3 = dir
	d3 = d3.normalized()
	d3.y = clampf(d3.y, -0.5, 0.45)
	var count := int(def.get("count", 1))
	if def.has("every3") and int(ctx.get("k", 1)) % 3 == 0:
		count = int(def["every3"])
	var spread := float(def.get("spread", 8.0))
	Sfx.play("arrow" if str(def["proj"]).begins_with("arrow") else "cast", p.global_position)
	for i in count:
		var ang := deg_to_rad((i - (count - 1) * 0.5) * spread)
		var dd := d3.rotated(Vector3.UP, ang)
		_world().spawn_projectile({
			"owner": p, "local": local, "kind": def["proj"], "pos": muzzle, "dir": dd,
			"speed": float(def["speed"]), "mult": float(def["mult"]), "pierce": int(def.get("pierce", 0)),
			"splash": float(def.get("splash", 0.0)), "status": str(def.get("status", "")), "kb": float(def.get("kb", 1.5)),
			"color": _col(def), "dkind": "primary" if primary else "skill",
		})

func _backflip_shot(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var dir: Vector3 = ctx["d"]
	var t := 0.45
	var id := 0
	var origin := p.global_position
	if local:
		p.face_dir(dir)
		id = p.begin_action(0.8, 0.62)
		p.invuln_t = maxf(p.invuln_t, 0.5)
		p.carry(-dir * float(def["dist"]) / t, t)
		p.velocity.y = Player.GRAVITY * t * 0.5
	else:
		p.busy_until = p.now + 0.8
	p.visual.play_once(def["anim"], 0.05, 1.0)
	Sfx.play("jump", p.global_position)
	Fx.dust(origin, 1.2)
	await _wait(0.3)
	if not is_instance_valid(p):
		return
	Sfx.play("arrow", p.global_position)
	var muzzle := p.global_position + Vector3(0, 1.0, 0)
	for i in 3:
		var target := origin + dir * (2.0 + i * 2.2) + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
		var dd := (target - muzzle).normalized()
		_world().spawn_projectile({
			"owner": p, "local": local, "kind": "arrow_big", "pos": muzzle, "dir": dd, "speed": 30.0,
			"mult": float(def["mult"]), "pierce": 0, "splash": float(def["r"]), "status": "", "kb": 4.0,
			"color": Color("ffb14a"), "dkind": "skill", "ground": true,
		})

# ------------------------------------------------------------------ magias de area
func _nova(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var delay := float(def["delay"])
	var id := 0
	if local:
		id = p.begin_action(delay + 0.4, delay + 0.25)
	else:
		p.busy_until = p.now + delay + 0.35
	p.visual.play_once(def["anim"], 0.06, 1.0)
	Fx.telegraph(p.global_position, float(def["r"]), delay, _col(def), true)
	await _wait(delay)
	if not is_instance_valid(p) or (local and not p.action_ok(id)):
		return
	var c := p.global_position
	Fx.shockwave(c, float(def["r"]), _col(def), 0.5)
	Fx.burst(c + Vector3(0, 0.4, 0), _col(def), float(def["r"]) * 0.5)
	Sfx.play("frost" if def.get("status", "") == "freeze" else "slam", c)
	if local:
		var n := hit_circle(c, float(def["r"]), float(def["mult"]), "skill",
			{"kb": 3.0, "status": def.get("status", ""), "status_t": float(def.get("status_t", 2.0))})
		_impact(maxi(n, 1), float(def.get("shake", 0.5)))

func _meteor(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var pt: Vector3 = ctx.get("pt", p.global_position + p.forward() * 8.0)
	var delay := float(def["delay"])
	var id := 0
	if local:
		p.face_dir(pt - p.global_position)
		id = p.begin_action(0.9, 0.7)
	else:
		p.busy_until = p.now + 0.9
	p.visual.play_once(def["anim"], 0.06, 1.0)
	Sfx.play("cast_big", p.global_position)
	Fx.telegraph(pt, float(def["r"]), delay, _col(def), true)
	Fx.meteor(pt, delay, float(def["r"]), _col(def))
	await _wait(delay)
	if not is_instance_valid(p):
		return
	Fx.explosion(pt, float(def["r"]), _col(def))
	Sfx.play("explode_big", pt)
	if p.rig or local:
		Game.world.shake_near(pt, 1.0, 30.0)
	if local:
		hit_circle(pt, float(def["r"]), float(def["mult"]), "skill", {"kb": 9.0, "status": def.get("status", ""), "from": pt})

func _star_rain(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var pt: Vector3 = ctx.get("pt", p.global_position + p.forward() * 6.0)
	if local:
		p.begin_action(0.6, 0.45)
	else:
		p.busy_until = p.now + 0.6
	p.visual.play_once(def["anim"], 0.06, 1.2)
	Sfx.play("cast_big", p.global_position)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pt)
	for i in int(def["count"]):
		var a := rng.randf() * TAU
		var q := pt + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, float(def["area"])) if i > 0 else pt
		_star(def, q, 0.5 + i * 0.16, local)

func _star(def: Dictionary, q: Vector3, delay: float, local: bool) -> void:
	await _wait(delay - 0.5)
	if not is_instance_valid(p):
		return
	Fx.telegraph(q, float(def["r"]), 0.5, _col(def), true)
	Fx.meteor(q, 0.5, float(def["r"]) * 0.6, _col(def))
	await _wait(0.5)
	if not is_instance_valid(p):
		return
	Fx.explosion(q, float(def["r"]), _col(def))
	Sfx.play("explode", q, 0.7)
	if local:
		hit_circle(q, float(def["r"]), float(def["mult"]), "skill", {"kb": 4.0, "from": q})

func _zone(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var pt: Vector3 = ctx.get("pt", p.global_position + p.forward() * 8.0)
	if local:
		p.face_dir(pt - p.global_position)
		p.begin_action(0.7, 0.55)
	else:
		p.busy_until = p.now + 0.7
	p.visual.play_once(def["anim"], 0.06, float(def.get("anim_speed", 1.0)))
	Sfx.play("bow_draw", p.global_position)
	await _wait(0.35)
	if not is_instance_valid(p):
		return
	var col := _col(def)
	var z := Zone.make(pt, float(def["time"]), float(def["tick"]))
	Fx.zone_visual(z, float(def["r"]), col, str(def.get("vfx", "")))
	Sfx.play("arrow_rain", pt)
	if local:
		z.on_tick = func() -> void:
			hit_circle(pt, float(def["r"]), float(def["mult"]), "skill", {"kb": 0.0, "status": def.get("status", ""), "from": pt, "no_proc": true})
	_world().add_thing(z)

func _sanctuary(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	if local:
		p.begin_action(0.75, 0.6)
	else:
		p.busy_until = p.now + 0.75
	p.visual.play_once(def["anim"], 0.06, 1.0)
	Sfx.play("holy", p.global_position)
	await _wait(0.27)
	if not is_instance_valid(p):
		return
	var pt := p.global_position
	pt.y = 0.0
	var r := float(def["r"])
	var z := Zone.make(pt, float(def["time"]), float(def["tick"]))
	Fx.zone_visual(z, r, _col(def), "sanctuary")
	# todo mundo calcula o proprio bonus: quem esta dentro recebe protecao e cura
	var heal_frac := float(def["heal"])
	z.on_tick = func() -> void:
		var me: Player = Game.me()
		if me and me.alive() and me.global_position.distance_to(pt) <= r + 0.3:
			me.buff("sanct", 1.0, float(def["tick"]) + 0.15)
			me.heal(me.max_hp * heal_frac * float(def["tick"]), false)
		if local:
			hit_circle(pt, r, float(def["mult"]) * float(def["tick"]), "skill", {"kb": 0.0, "from": pt, "no_proc": true})
	_world().add_thing(z)

func _heal_circle(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	if local:
		p.begin_action(0.7, 0.5)
	else:
		p.busy_until = p.now + 0.7
	p.visual.play_once(def["anim"], 0.06, 1.1)
	await _wait(0.26)
	if not is_instance_valid(p):
		return
	var r := float(def["r"])
	Fx.shockwave(p.global_position, r, _col(def), 0.6)
	Fx.heal_ring(p.global_position, r, _col(def))
	Sfx.play("heal", p.global_position)
	if local:
		for o: Player in _world().all_players():
			if o.global_position.distance_to(p.global_position) <= r and o.alive():
				_world().give_effect(o, "heal", float(def["heal"]), 0.0)

func _shield(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	if local:
		p.begin_action(0.7, 0.5)
	else:
		p.busy_until = p.now + 0.7
	p.visual.play_once(def["anim"], 0.06, 1.1)
	await _wait(0.26)
	if not is_instance_valid(p):
		return
	var r := float(def["r"])
	Fx.shockwave(p.global_position, r, _col(def), 0.6)
	Sfx.play("shield", p.global_position)
	if local:
		for o: Player in _world().all_players():
			if o.global_position.distance_to(p.global_position) <= r and o.alive():
				_world().give_effect(o, "shield", float(def["shield"]), float(def["time"]))

func _blink(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var from := p.global_position
	var to: Vector3 = ctx.get("to", from)
	var col := _col(def)
	Fx.blink(from, to, col)
	Sfx.play("blink", from)
	p.global_position = to
	p.net_pos = to
	if local:
		p.invuln_t = maxf(p.invuln_t, 0.3)
		p.velocity = Vector3.ZERO
		p.face_dir(ctx["d"])
		hit_circle(from, float(def["r"]), float(def["mult"]), "skill", {"kb": 3.0, "from": from})
	Fx.shockwave(from, float(def["r"]), col, 0.3)

func _chain(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	if local:
		p.face_dir(ctx["d"])
		p.begin_action(0.6, 0.45)
	else:
		p.busy_until = p.now + 0.6
	p.visual.play_once(def["anim"], 0.06, 1.3)
	await _wait(0.22)
	if not is_instance_valid(p):
		return
	Sfx.play("zap", p.global_position)
	var col := _col(def)
	var from := p.visual.bone_global("hand.L")
	var hit_set: Array = []
	var cur: Enemy = _world().enemy_in_front(p.global_position, ctx["d"], float(def["range"]))
	var last := from
	if cur == null:
		Fx.lightning(from, from + (ctx["d"] as Vector3) * 6.0 + Vector3(0, 0.3, 0), col)
		return
	for j in int(def["jumps"]):
		if cur == null:
			break
		hit_set.append(cur)
		var tp := cur.global_position + Vector3(0, cur.height * 0.55, 0)
		Fx.lightning(last, tp, col)
		Fx.spark(tp, col)
		if local:
			hit(cur, float(def["mult"]) * pow(0.9, j), "skill", {"kb": 1.0, "status": "stun", "status_t": 0.35})
		last = tp
		cur = _world().nearest_enemy(cur.global_position, float(def["jump_r"]), hit_set)

func _totem(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	if local:
		p.face_dir(ctx["d"])
		p.begin_action(0.5, 0.4)
	else:
		p.busy_until = p.now + 0.5
	p.visual.play_once(def["anim"], 0.06, 1.2)
	await _wait(0.2)
	if not is_instance_valid(p):
		return
	var pt := p.global_position + p.forward() * 2.2
	pt.y = 0.0
	var z := Zone.make(pt, float(def["time"]), float(def["tick"]))
	Fx.totem_visual(z, _col(def))
	Sfx.play("plant", pt)
	z.on_tick = func() -> void:
		var e: Enemy = _world().nearest_enemy(pt, float(def["range"]))
		if e == null or not is_instance_valid(p):
			return
		var muzzle := pt + Vector3(0, 1.3, 0)
		var dd := (e.global_position + Vector3(0, e.height * 0.5, 0) - muzzle).normalized()
		_world().spawn_projectile({"owner": p, "local": local, "kind": "thorn", "pos": muzzle, "dir": dd, "speed": 26.0,
			"mult": float(def["mult"]), "pierce": 0, "splash": 0.0, "status": "poison", "kb": 0.5, "color": _col(def), "dkind": "skill"})
	_world().add_thing(z)

func _orbit(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	if local:
		p.begin_action(0.5, 0.35)
	else:
		p.busy_until = p.now + 0.5
	p.visual.play_once(def["anim"], 0.06, 1.3)
	Sfx.play("shield", p.global_position)
	var z := Zone.make(p.global_position, float(def["time"]), float(def["tick"]))
	z.follow = p
	Fx.orbit_visual(z, float(def["r"]), int(def["count"]), _col(def))
	if local:
		z.on_tick = func() -> void:
			if is_instance_valid(p):
				hit_circle(p.global_position, float(def["r"]) + 0.5, float(def["mult"]), "skill", {"kb": 1.5, "no_proc": true})
	_world().add_thing(z)

func _vortex(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var pt: Vector3 = ctx.get("pt", p.global_position + p.forward() * 7.0)
	if local:
		p.face_dir(pt - p.global_position)
		p.begin_action(0.5, 0.4)
	else:
		p.busy_until = p.now + 0.5
	p.visual.play_once(def["anim"], 0.06, 1.2)
	await _wait(0.2)
	if not is_instance_valid(p):
		return
	var z := Zone.make(pt, float(def["time"]), float(def["tick"]))
	Fx.zone_visual(z, float(def["r"]), _col(def), "vortex")
	Sfx.play("vortex", pt)
	if local:
		z.on_tick = func() -> void:
			hit_circle(pt, float(def["r"]), float(def["mult"]), "skill", {"kb": 5.5, "pull": true, "from": pt, "no_proc": true})
	_world().add_thing(z)

func _beam(def: Dictionary, ctx: Dictionary, local: bool) -> void:
	var time := float(def["time"])
	var id := 0
	if local:
		p.face_dir(ctx["d"])
		id = p.begin_action(time, time, 0.3, false)
	else:
		p.busy_until = p.now + time
	p.visual.play("channel-loop", 0.1, 1.4)
	var fx := Fx.beam(p, float(def["range"]), float(def["width"]), time, _col(def))
	Sfx.play("beam", p.global_position)
	var el := 0.0
	while el < time:
		if local:
			if not p.action_ok(id):
				break
			p.face_dir(p.aim_flat(), false)
			var a := p.global_position
			var b := a + p.forward() * float(def["range"])
			hit_line(a, b, float(def["width"]), float(def["mult"]), "skill", {"kb": 0.6, "status": def.get("status", ""), "no_proc": true})
		await _wait(float(def["tick"]))
		if not is_instance_valid(p):
			return
		el += float(def["tick"])
	if is_instance_valid(fx):
		fx.queue_free()
	if local:
		p.end_action(id)
	else:
		p.busy_until = p.now
