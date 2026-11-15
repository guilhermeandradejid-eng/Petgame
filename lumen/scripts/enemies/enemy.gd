class_name Enemy
extends Node3D
## Inimigo. A IA roda so no host; os clientes interpolam a posicao e tocam as animacoes.
## Os ataques sao anunciados a todos (cl_eattack): cada cliente mostra o aviso no chao
## e confere, na hora do golpe, se o SEU heroi esta na area (esquiva justa para todos).

var eid := 0
var kind := "broto"
var def: Dictionary = {}
var hp := 10.0
var max_hp := 10.0
var radius := 0.4
var height := 1.0
var dmg_mul := 1.0
var dead := false
var champion := false
var is_boss := false
var is_dummy := false

var model: Node3D
var anim: AnimationPlayer
var cur_anim := ""
var hp_bar: Node3D

# --- IA (host)
var st := "spawn"
var st_t := 0.0
var target: Player
var retarget_t := 0.0
var cds: Array = []
var atk: Dictionary = {}
var atk_i := -1
var atk_dir := Vector3.FORWARD
var atk_fired := false
var kb_vel := Vector3.ZERO
var stun_t := 0.0
var slow_t := 0.0
var burn_t := 0.0
var burn_dps := 0.0
var burn_by := 0
var poison_t := 0.0
var poison_dps := 0.0
var dot_acc := 0.0
var poise := 0.0
var speed := 3.0
var strafe := 1.0
var phase := 1
var global_cd := 0.6
var yaw := 0.0

# --- fantoche
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_moving := false
var flags := 0
var atk_token := 0
var charge_t := 0.0
var charge_hit := false
var charge_dmg := 0.0
var charge_kb := 0.0
var _flash_tw: Tween

func setup(d: Dictionary) -> void:
	eid = int(d["id"])
	kind = str(d["kind"])
	name = "E%d" % eid
	def = DB.ENEMIES.get(kind, DB.ENEMIES["broto"])
	champion = bool(d.get("champ", false))
	is_boss = bool(def.get("boss", false))
	is_dummy = kind == "dummy"
	max_hp = float(d["hp"])
	hp = float(d.get("cur", max_hp))
	dmg_mul = float(d.get("dmg", 1.0))
	radius = float(def["radius"]) * (1.25 if champion else 1.0)
	height = float(def["height"]) * (1.25 if champion else 1.0)
	poise = float(def.get("poise", 0.0))
	if champion:
		poise = maxf(poise, 0.6)
	speed = float(def["speed"])
	position = d["pos"]
	net_pos = position
	yaw = float(d.get("yaw", 0.0))
	net_yaw = yaw
	rotation.y = yaw
	for a in def["atk"]:
		cds.append(randf_range(0.4, 1.2) + float(a.get("min_cd", 0.0)))
	strafe = 1.0 if randf() < 0.5 else -1.0

func _ready() -> void:
	_build_visual()
	if bool(def.get("no_spawn_anim", false)):
		st = "chase"
		play("idle-loop")
	else:
		play("spawn")
		Fx.spawn_puff(global_position, radius, Color(str(def.get("color", "ffffff"))))

func _build_visual() -> void:
	var path := "res://assets/models/enemy_%s.glb" % kind
	if is_dummy and KitLib.has("props", "dummy"):
		model = Node3D.new()
		model.add_child(KitLib.make("props", "dummy"))
	elif ResourceLoader.exists(path):
		model = (load(path) as PackedScene).instantiate()
		model.rotation.y = PI
		Mats.apply_env(model)
		anim = Mats.find_of(model, "AnimationPlayer")
	else:
		model = _fallback_visual()
	add_child(model)
	if champion:
		model.scale = Vector3.ONE * 1.25
		Fx.champion_aura(self, radius)
	_set_cull_margin(model)
	if not is_dummy:
		hp_bar = Fx.make_hp_bar(self, height + 0.35, 1.6 if (is_boss or bool(def.get("elite", false))) else 0.9)
		hp_bar.visible = false

func _set_cull_margin(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).extra_cull_margin = 2.0
	for c in n.get_children():
		_set_cull_margin(c)

func _fallback_visual() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = maxf(height, radius * 2.0)
	mi.mesh = cap
	mi.position.y = cap.height * 0.5
	mi.material_override = Mats.toon(Color(str(def.get("color", "ff8888"))))
	root.add_child(mi)
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = radius * 0.16
		sm.height = radius * 0.32
		eye.mesh = sm
		eye.material_override = Mats.toon(Color("1b1730"))
		eye.position = Vector3(sx * radius * 0.4, cap.height * 0.72, radius * 0.86)
		root.add_child(eye)
	return root

# ------------------------------------------------------------------ animacao
func _res(a: String) -> String:
	if anim == null:
		return ""
	if anim.has_animation(a):
		return a
	var b := a.trim_suffix("-loop")
	return b if anim.has_animation(b) else ""

func play(a: String, blend: float = 0.12, restart: bool = false) -> void:
	a = _res(a)
	if a == "":
		return
	if cur_anim == a and anim.is_playing() and not restart:
		return
	cur_anim = a
	anim.play(a, blend)
	if restart:
		anim.seek(0.0, true)

func anim_len(a: String, fallback: float = 0.6) -> float:
	a = _res(a)
	if a != "":
		return anim.get_animation(a).length
	return fallback

func is_slowed() -> bool:
	return (flags & 6) != 0 if not Net.is_host() else (slow_t > 0.0 or stun_t > 0.0)

# ------------------------------------------------------------------ laco
func _physics_process(delta: float) -> void:
	if dead:
		return
	if Net.is_host():
		_ai(delta)
		position += kb_vel * delta
		kb_vel = kb_vel.move_toward(Vector3.ZERO, 26.0 * delta)
		_collide()
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-12.0 * delta))
		net_pos = position
	else:
		position = position.lerp(net_pos, 1.0 - exp(-12.0 * delta))
		rotation.y = lerp_angle(rotation.y, net_yaw, 1.0 - exp(-12.0 * delta))
		if st != "attack" and st != "stun" and st != "spawn":
			play("move-loop" if net_moving else "idle-loop")
		st_t += delta
		if st == "spawn" and st_t > 0.7:
			st = "chase"
	_charge_check(delta)

func _collide() -> void:
	var lvl: Level = Game.world.level
	if lvl == null:
		return
	position.y = float(def.get("float", 0.0))
	for o in lvl.obstacles:
		var d: Vector3 = position - o["pos"]
		d.y = 0.0
		var m: float = float(o["r"]) + radius * 0.8
		var l := d.length()
		if l < m and l > 0.001:
			position += d / l * (m - l)
	position = lvl.clamp_inside(position, radius + 0.4)

func _separate(delta: float) -> Vector3:
	var push := Vector3.ZERO
	for o: Enemy in Game.world.enemy_list():
		if o == self or o.dead:
			continue
		var d := position - o.position
		d.y = 0.0
		var m := radius + o.radius
		var l := d.length()
		if l < m and l > 0.001:
			push += d / l * (m - l) * 4.0
	return push

# ------------------------------------------------------------------ IA (host)
func _ai(delta: float) -> void:
	st_t += delta
	_dots(delta)
	if is_dummy:
		hp = minf(max_hp, hp + max_hp * 0.3 * delta)
		return
	for i in cds.size():
		cds[i] = maxf(0.0, float(cds[i]) - delta)
	global_cd = maxf(0.0, global_cd - delta)
	slow_t = maxf(0.0, slow_t - delta)
	if stun_t > 0.0:
		stun_t -= delta
		if stun_t <= 0.0 and st == "stun":
			_set_state("chase")
		return
	retarget_t -= delta
	if retarget_t <= 0.0 or target == null or not is_instance_valid(target) or not target.alive():
		retarget_t = 1.2
		target = _pick_target()
	match st:
		"spawn":
			if st_t > minf(anim_len("spawn", 0.6), 1.2 if not is_boss else 2.2):
				_set_state("chase")
		"chase":
			if target == null:
				play("idle-loop")
				return
			_think(delta)
		"attack":
			_attack_update(delta)
		"charge":
			_charge_update(delta)
		"stun":
			_set_state("chase")

func _set_state(s: String) -> void:
	st = s
	st_t = 0.0

func _pick_target() -> Player:
	var best: Player = null
	var bd := 1e9
	for p: Player in Game.world.all_players():
		if not p.alive():
			continue
		var d := p.global_position.distance_to(global_position)
		if p == target:
			d *= 0.7
		if d < bd:
			bd = d
			best = p
	return best

func _move(dir: Vector3, spd: float, delta: float) -> void:
	var mult := (0.55 if slow_t > 0.0 else 1.0)
	var v := dir * spd * mult + _separate(delta)
	position += v * delta
	if dir.length() > 0.1:
		yaw = atan2(-dir.x, -dir.z)
		play("move-loop")
	else:
		play("idle-loop")

func _face(to: Vector3) -> Vector3:
	var d := to - position
	d.y = 0.0
	if d.length() > 0.01:
		d = d.normalized()
		yaw = atan2(-d.x, -d.z)
	return d

func _think(delta: float) -> void:
	var to := target.global_position - position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else Vector3.FORWARD
	var ai := str(def["ai"])
	var rng := float(def["range"])
	# escolhe um ataque disponivel
	if global_cd <= 0.0:
		var pick := _choose_attack(dist)
		if pick >= 0:
			_start_attack(pick, dir)
			return
	match ai:
		"ranged":
			var keep := float(def.get("keep", 7.0))
			if dist > rng * 0.85:
				_move(dir, speed, delta)
			elif dist < keep * 0.7:
				_move(-dir, speed * 0.9, delta)
			else:
				var side := dir.cross(Vector3.UP) * strafe
				_move(side, speed * 0.55, delta)
				yaw = atan2(-dir.x, -dir.z)
				if randf() < delta * 0.25:
					strafe = -strafe
		"charger":
			if dist > 6.0:
				_move(dir, speed, delta)
			elif dist < 2.0:
				_move(Vector3.ZERO, 0.0, delta)
				_face(target.global_position)
			else:
				var side2 := (dir.cross(Vector3.UP) * strafe + dir * 0.35).normalized()
				_move(side2, speed * 0.8, delta)
		_:
			if dist > rng * 0.72:
				_move(dir, speed * (1.25 if (is_boss and phase >= 3) else 1.0), delta)
			else:
				_move(Vector3.ZERO, 0.0, delta)
				_face(target.global_position)

func _choose_attack(dist: float) -> int:
	var options: Array = []
	for i in (def["atk"] as Array).size():
		if float(cds[i]) > 0.0:
			continue
		var a: Dictionary = def["atk"][i]
		match str(a["shape"]):
			"circle":
				if dist <= float(a.get("off", 0.0)) + float(a["r"]) * 0.85 + float(a.get("lunge", 0.0)) * 0.6:
					options.append(i)
			"cone":
				if dist <= float(a["r"]) * 0.8 and (not a.has("close") or dist <= float(a["close"])):
					options.append(i)
			"proj":
				if dist <= float(def["range"]) and dist >= 2.5:
					options.append(i)
			"charge":
				if dist >= 4.5 and dist <= float(def["range"]):
					options.append(i)
			"rain":
				if phase >= int(a.get("phase", 1)):
					options.append(i)
			"summon":
				if phase >= int(a.get("phase", 2)) and Game.world.enemy_count() < 7:
					options.append(i)
	if options.is_empty():
		return -1
	return options[randi() % options.size()]

func _start_attack(i: int, dir: Vector3) -> void:
	atk_i = i
	atk = DB.enemy_attack(kind, i)
	atk_dir = dir
	atk_fired = false
	yaw = atan2(-dir.x, -dir.z)
	rotation.y = yaw
	var haste := 0.75 if (is_boss and phase >= 3) else 1.0
	cds[i] = float(atk["cd"]) * haste * randf_range(0.9, 1.25)
	global_cd = float(atk["len"]) + (0.5 if not is_boss else 0.7 * haste)
	_set_state("attack")
	var tp := target.global_position if target else position + dir * 5.0
	Game.world.cl_eattack.rpc(eid, i, position, dir, tp)

func _attack_update(delta: float) -> void:
	var hit_t := float(atk["hit"])
	var shape := str(atk["shape"])
	if shape == "proj" and target and st_t < hit_t:
		atk_dir = _face(target.global_position)
	if atk.has("lunge") and st_t >= hit_t - 0.12 and st_t < hit_t + 0.1:
		position += atk_dir * float(atk["lunge"]) / 0.22 * delta
	if not atk_fired and st_t >= hit_t:
		atk_fired = true
		match shape:
			"proj":
				var from := position + Vector3(0, height * 0.6, 0) + atk_dir * (radius + 0.3)
				var aim := (target.global_position + Vector3(0, 0.7, 0)) if target else from + atk_dir * 10.0
				var n := 3 if champion else 1
				for k in n:
					var d := (aim - from).normalized().rotated(Vector3.UP, deg_to_rad((k - (n - 1) * 0.5) * 16.0))
					Game.world.cl_eproj.rpc(from, d * float(atk["speed"]), float(atk["dmg"]) * dmg_mul, float(atk["r"]), str(atk.get("color", "ff9a3d")), eid)
			"charge":
				if target:
					atk_dir = _face(target.global_position)
				_set_state("charge")
				play("charge-loop")
				return
			"rain":
				_boss_rain()
			"summon":
				Game.world.room_ctl.boss_summon(self, int(atk.get("count", 3)))
	if st_t >= float(atk["len"]):
		_set_state("chase")

func _charge_update(delta: float) -> void:
	position += atk_dir * float(atk["speed"]) * (0.6 if slow_t > 0.0 else 1.0) * delta
	yaw = atan2(-atk_dir.x, -atk_dir.z)
	var lvl: Level = Game.world.level
	var blocked := false
	if lvl:
		var c := lvl.clamp_inside(position, radius + 0.5)
		blocked = c.distance_to(position) > 0.05
	if st_t >= float(atk["time"]) or blocked:
		play("charge_end", 0.08, true)
		_set_state("stun")
		stun_t = 0.55 if not blocked else 1.1
		if blocked:
			Game.world.cl_fx.rpc("bonk", position, radius)

func _boss_rain() -> void:
	var n := int(atk.get("count", 6)) + (phase - 1) * 3
	var spots: Array = []
	for p: Player in Game.world.all_players():
		if p.alive():
			spots.append(p.global_position)
	for k in n:
		var base: Vector3 = spots[k % spots.size()] if spots.size() > 0 else position
		var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (0.0 if k < spots.size() else randf_range(2.0, 7.0))
		var q := base + off
		q.y = 0.0
		Game.world.cl_hazard.rpc(q, float(atk["r"]), float(atk["delay"]) + k * 0.12, float(atk["dmg"]) * dmg_mul, "7df9ff", "crystal")

func _dots(delta: float) -> void:
	if burn_t <= 0.0 and poison_t <= 0.0:
		return
	dot_acc += delta
	burn_t = maxf(0.0, burn_t - delta)
	poison_t = maxf(0.0, poison_t - delta)
	if dot_acc >= 0.5:
		dot_acc = 0.0
		var d := 0.0
		if burn_t > 0.0:
			d += burn_dps * 0.5
		if poison_t > 0.0:
			d += poison_dps * 0.5
		if d > 0.0:
			Game.world.server_damage(self, d, 2, Vector3.ZERO, "", 0.0, burn_by)

## Host: aplica um acerto. flags: 1 = critico, 2 = dano continuo.
func apply_hit(dmg: float, hit_flags: int, kb: Vector3, status: String, st_time: float, by: int) -> void:
	if dead:
		return
	hp -= dmg
	if not is_dummy:
		kb_vel += kb * (1.0 - poise)
	match status:
		"burn":
			burn_t = 3.0
			burn_dps = maxf(burn_dps, dmg * 0.18)
			burn_by = by
		"poison":
			poison_t = 4.0
			poison_dps = minf(poison_dps + dmg * 0.08, dmg * 0.6)
			burn_by = by
		"chill":
			slow_t = maxf(slow_t, 3.0)
		"freeze":
			if is_boss or bool(def.get("elite", false)):
				slow_t = maxf(slow_t, 3.0)
			else:
				_stun(2.0)
		"stun":
			_stun((st_time if st_time > 0.0 else 1.0) * (1.0 - poise * 0.7))
	if (hit_flags & 2) == 0 and poise < 0.5 and st != "attack" and st != "charge" and stun_t <= 0.0 and not is_dummy:
		_stun(0.18)
		Game.world.cl_eflinch.rpc(eid)
	if is_boss:
		var f := hp / max_hp
		var np := 3 if f < 0.34 else (2 if f < 0.67 else 1)
		if np > phase:
			phase = np
			Game.world.room_ctl.boss_phase(self, phase)

func _stun(t: float) -> void:
	if t <= 0.02:
		return
	if st == "attack" and not atk_fired:
		Game.world.cl_ecancel.rpc(eid)
	stun_t = maxf(stun_t, t)
	_set_state("stun")

func net_flags() -> int:
	var f := 0
	if st == "chase" and cur_anim.begins_with("move"):
		f |= 1
	if slow_t > 0.0:
		f |= 2
	if stun_t > 0.0:
		f |= 4
	if burn_t > 0.0:
		f |= 8
	if poison_t > 0.0:
		f |= 16
	if st == "charge":
		f |= 32
	return f

# ------------------------------------------------------------------ eventos em todos os clientes
func on_state(pos: Vector3, p_yaw: float, f: int) -> void:
	net_pos = pos
	net_yaw = p_yaw
	net_moving = (f & 1) != 0
	if (f & 32) != 0 and st == "attack":
		play("charge-loop")
	flags = f
	Fx.status_marks(self, f)

func on_attack(i: int, pos: Vector3, dir: Vector3, tpos: Vector3) -> void:
	atk_token += 1
	var token := atk_token
	var a := DB.enemy_attack(kind, i)
	if not Net.is_host():
		position = position.lerp(pos, 0.7)
		net_pos = pos
		net_yaw = atan2(-dir.x, -dir.z)
		st = "attack"
		st_t = 0.0
	play(str(a["anim"]), 0.08, true)
	var hit_t := float(a["hit"])
	var shape := str(a["shape"])
	var col := Color("ff5a4a")
	var dmg := float(a["dmg"]) * dmg_mul
	var center := pos + dir * float(a.get("off", 0.0)) + (dir * float(a.get("lunge", 0.0)) * 0.8 if a.has("lunge") else Vector3.ZERO)
	match shape:
		"circle":
			Fx.telegraph(center, float(a["r"]), hit_t, col, false, null, self)
		"cone":
			Fx.telegraph_cone(pos, dir, float(a["r"]), float(a["angle"]), hit_t, col, self)
		"charge":
			Fx.telegraph_line(pos, dir, float(a["speed"]) * float(a["time"]) * 0.9, float(a["width"]), hit_t, col, self)
		"proj":
			Fx.charge_glow(self, hit_t, Color(str(a.get("color", "ff9a3d"))))
		"rain", "summon":
			Fx.charge_glow(self, hit_t, Color("7df9ff"))
	Sfx.play("enemy_windup", pos, 0.5)
	await get_tree().create_timer(hit_t, false).timeout
	if not is_instance_valid(self) or dead or token != atk_token:
		return
	match shape:
		"circle":
			Fx.shockwave(center, float(a["r"]), col.lightened(0.3), 0.3)
			Fx.dust(center, float(a["r"]) * 0.5)
			Sfx.play("slam", center, 0.8)
			_try_hit_local(center, float(a["r"]), 360.0, dir, dmg, float(a.get("kb", 4.0)))
			if a.get("wave", false):
				Fx.ground_wave(center, 11.0, 9.0, dmg * 0.6, eid)
		"cone":
			Fx.cone(pos, dir, float(a["r"]), float(a["angle"]), col.lightened(0.3))
			Sfx.play("swing_heavy", pos, 0.8)
			_try_hit_local(pos, float(a["r"]), float(a["angle"]), dir, dmg, float(a.get("kb", 4.0)))
		"charge":
			charge_t = float(a["time"])
			charge_hit = false
			charge_dmg = dmg
			charge_kb = float(a.get("kb", 8.0))
			Sfx.play("dash", pos)
		"proj":
			Sfx.play("cast", pos, 0.7)
	if a.has("shake"):
		Game.world.shake_near(center, float(a["shake"]), 16.0)
	await get_tree().create_timer(maxf(0.05, float(a["len"]) - hit_t), false).timeout
	if is_instance_valid(self) and not dead and token == atk_token and not Net.is_host():
		st = "chase"

func _try_hit_local(center: Vector3, r: float, angle: float, dir: Vector3, dmg: float, kb: float) -> void:
	var me: Player = Game.me()
	if me == null or not me.alive():
		return
	var d := me.global_position - center
	var up := d.y
	d.y = 0.0
	if d.length() > r + 0.3 or up > 2.2:
		return
	if angle < 359.0 and d.length() > 0.8 and d.normalized().dot(dir) < cos(deg_to_rad(angle * 0.5)):
		return
	me.take_damage(dmg, global_position, kb, eid)

func _charge_check(delta: float) -> void:
	if charge_t <= 0.0:
		return
	charge_t -= delta
	if charge_hit:
		return
	var me: Player = Game.me()
	if me == null or not me.alive():
		return
	var d := me.global_position - global_position
	d.y = 0.0
	if d.length() < radius + 0.75 and me.global_position.y < 1.6:
		if me.take_damage(charge_dmg, global_position, charge_kb, eid):
			charge_hit = true

func on_cancel() -> void:
	atk_token += 1
	charge_t = 0.0
	Fx.cancel_telegraphs(self)

func on_flinch() -> void:
	if st != "attack":
		play("hit", 0.04, true)
		st = "stun"
		st_t = 0.0
		get_tree().create_timer(0.3).timeout.connect(func() -> void:
			if is_instance_valid(self) and st == "stun" and not Net.is_host():
				st = "chase")

func on_hit(dmg: float, new_hp: float, hit_flags: int, by: int) -> void:
	hp = new_hp
	if hp_bar:
		hp_bar.visible = hp < max_hp and not is_boss
		Fx.set_hp_bar(hp_bar, hp / max_hp)
	var mine := by == Net.my_id()
	var crit := (hit_flags & 1) != 0
	var dot := (hit_flags & 2) != 0
	var col := Color("ffffff") if mine else Color("b9c2d6")
	if crit:
		col = Color("ffd23e")
	if dot:
		col = Color("ff9a5a")
	Fx.number(global_position + Vector3(randf_range(-0.3, 0.3), height + 0.2, 0), dmg, col, crit, dot or not mine)
	if not dot:
		_flash()

func _flash() -> void:
	Mats.set_instance_param(model, &"flash", 0.9)
	if _flash_tw:
		_flash_tw.kill()
	_flash_tw = create_tween()
	var rest_lvl := float(get_meta("st_lvl", 0.0))
	_flash_tw.tween_method(func(v: float) -> void: Mats.set_instance_param(model, &"flash", v), 0.9, rest_lvl, 0.14)
	var tw := create_tween()
	model.scale = Vector3(1.12, 0.9, 1.12) * (1.25 if champion else 1.0)
	tw.tween_property(model, "scale", Vector3.ONE * (1.25 if champion else 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func on_die() -> void:
	if dead:
		return
	dead = true
	atk_token += 1
	charge_t = 0.0
	Fx.cancel_telegraphs(self)
	if hp_bar:
		hp_bar.visible = false
	play("die", 0.06, true)
	Sfx.play("enemy_die", global_position, 0.8)
	Fx.burst(global_position + Vector3(0, height * 0.5, 0), Color(str(def.get("color", "ffffff"))), radius * 2.2)
	var t := anim_len("die", 0.5) if _res("die") != "" else 0.15
	var tw := create_tween()
	tw.tween_interval(minf(t, 1.6))
	tw.tween_method(func(v: float) -> void: Mats.set_instance_param(model, &"dissolve", v), 0.0, 1.0, 0.5)
	tw.tween_callback(queue_free)
