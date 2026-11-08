class_name Weapons
extends Node3D
## Armas (estilo Rock n' Roll Racing): metralhadora, lança-foguetes, minas e óleo.
## Munição limitada por volta; a IA também atira.

var game: Node
var fx: Fx
var sfx: Sfx
var lib: Node3D
var rockets: Array = []
var mines: Array = []
var oils: Array = []
var tracers: Array = []
var tracer_i := 0
var flashes: Array = []
var flash_i := 0
var oil_shader: Shader
var numbers: Array = []
var num_i := 0
var acc := {}             # dano acumulado do jogador por alvo (para os números)
var spikes: Array = []     # pregos no chão
var barrels: Array = []    # barris rolando
var rings: Array = []      # ondas de choque (efeito visual)
var bolts: Array = []      # raios elétricos (efeito visual)
var hazards: Array = []
var uses := {}             # contagem de uso por arma (testes)    # perigos de chefes: {"kind", "pos", "r", "t", "dur", "owner", "node"}
var reticle: MeshInstance3D
var ret_pulse := 0.0
var ret_t := 0.0


func setup(game_: Node, fx_: Fx, sfx_: Sfx, lib_: Node3D) -> void:
	game = game_
	fx = fx_
	sfx = sfx_
	lib = lib_
	oil_shader = load("res://shaders/oil.gdshader")
	# balas traçantes: fitas que viajam do cano até o impacto
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.albedo_texture = fx.tracer_tex
	tmat.albedo_color = Color(4.0, 3.0, 1.4, 1.0)
	tmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tmesh := fx._streak_mesh(0.22, 1.0)
	tmesh.surface_set_material(0, tmat)
	for i in 40:
		var mi := MeshInstance3D.new()
		mi.mesh = tmesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		tracers.append({"mi": mi, "t": -1.0})
	# clarão de tiro: estrela virada para a câmera + cone de fogo na direção do cano + luz
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_texture = fx.star_tex
	smat.albedo_color = Color(3.5, 2.6, 1.2, 1.0)
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	smat.no_depth_test = true
	var cmat := tmat.duplicate() as StandardMaterial3D
	cmat.albedo_color = Color(4.0, 2.2, 0.6, 1.0)
	var cmesh := fx._streak_mesh(0.5, 1.0)
	cmesh.surface_set_material(0, cmat)
	for i in 8:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.35)
		l.omni_range = 7.0
		l.light_energy = 0.0
		add_child(l)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.6, 1.6)
		qm.material = smat
		q.mesh = qm
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.visible = false
		add_child(q)
		var cone := MeshInstance3D.new()
		cone.mesh = cmesh
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.visible = false
		add_child(cone)
		flashes.append({"l": l, "q": q, "cone": cone, "t": 0.0})
	# números de dano
	var font := load("res://fonts/Bungee.woff2") as Font
	for i in 12:
		var lb := Label3D.new()
		lb.font = font
		lb.font_size = 64
		lb.pixel_size = 0.02
		lb.outline_size = 14
		lb.outline_modulate = Color(0.15, 0.02, 0.05, 0.9)
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.visible = false
		add_child(lb)
		numbers.append({"lb": lb, "t": 0.0})
	# mira travada
	reticle = MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(3.4, 3.4)
	reticle.mesh = rq
	var rm := ShaderMaterial.new()
	rm.shader = load("res://shaders/reticle.gdshader")
	reticle.material_override = rm
	reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reticle.visible = false
	add_child(reticle)


func clear() -> void:
	for r in rockets:
		(r.node as Node).queue_free()
	for m in mines:
		(m.node as Node).queue_free()
	for o in oils:
		(o.node as Node).queue_free()
	rockets.clear()
	mines.clear()
	oils.clear()
	for arr in [spikes, barrels, rings, bolts, hazards]:
		for it in arr:
			if it.has("node") and is_instance_valid(it.node):
				(it.node as Node).queue_free()
		arr.clear()
	acc.clear()
	for t in tracers:
		t.t = -1.0
		(t.mi as MeshInstance3D).visible = false
	if reticle:
		reticle.visible = false


# ------------------------------------------------------------------ disparo
func _target(car: Car, max_d: float, cos_cone: float) -> Car:
	var best: Car = null
	var bd := max_d
	var f := car.global_transform.basis.z
	for o in game.cars:
		if o == car or o.wrecked or (o.role == "traffic" and car.role != "player"):
			continue
		var d: Vector3 = o.global_position + Vector3.UP * 0.6 - car.global_position
		var dist := d.length()
		if dist < bd and d.normalized().dot(f) > cos_cone:
			bd = dist
			best = o
	return best


func update(dt: float) -> void:
	for car in game.cars:
		var c: Car = car
		if c.wrecked or c.role == "traffic" or (c.freeze and not c.net_remote):
			continue
		if c.role == "rival" and not c.net_remote and not c.human:
			_ai(c)
		if c.emp_t > 0.0:
			c.ctrl.fire = false
			c.ctrl.drop = false
			c.ctrl.special = false
		if c.ctrl.fire and c.fire_cd <= 0.0 and c.ammo_f > 0:
			match c.front_type:
				"mg":
					_fire_mg(c)
				"zap":
					_fire_zap(c)
				"flame":
					_fire_flame(c)
				"rocket":
					_fire_rocket(c)
		_flame_fx(c)
		if c.shield_t > 0.0:
			_shield_ram(c)
		if c.nitroing and c.nitro_type == "ram":
			_ram_hit(c)
		_shield_fx(c)
		if c.ctrl.drop and c.drop_cd <= 0.0 and c.ammo_r > 0:
			_drop(c)
	_step_rockets(dt)
	_step_mines(dt)
	_step_oils(dt)
	_step_spikes(dt)
	_step_barrels(dt)
	_step_rings(dt)
	_step_bolts(dt)
	_step_hazards(dt)
	_step_tracers(dt)
	for f in flashes:
		if f.t > 0.0:
			f.t -= dt
			(f.l as OmniLight3D).light_energy = maxf(0.0, f.t) * 90.0
			(f.q as MeshInstance3D).visible = f.t > 0.0
			(f.cone as MeshInstance3D).visible = f.t > 0.0
	_step_numbers(dt)
	_step_reticle(dt)


func _ai(c: Car) -> void:
	c.ctrl.fire = false
	c.ctrl.drop = false
	c.ctrl.special = false
	if game.mode != "race":
		return
	# a IA atira em rajadas e com pausas (dá tempo de reagir)
	var burst_on := fmod(game.time_g + c.seed_f * 3.1, 4.0) < 1.6
	match c.front_type:
		"mg":
			c.ctrl.fire = burst_on and _target(c, 36.0, 0.985) != null
		"zap":
			c.ctrl.fire = _target(c, 26.0, 0.9) != null and randf() < 0.06
		"flame":
			c.ctrl.fire = _target(c, 10.0, 0.85) != null
		_:
			c.ctrl.fire = _target(c, 55.0, 0.97) != null and randf() < 0.02
	# especial comprado (a IA usa quando faz sentido)
	if c.special_type != "" and c.spec_ch > 0:
		var near := 0
		for o in game.cars:
			if o != c and not o.wrecked and o.role != "traffic" and o.global_position.distance_to(c.global_position) < 9.0:
				near += 1
		match c.special_type:
			"shock":
				c.ctrl.special = near >= 1 and randf() < 0.03
			"shield":
				c.ctrl.special = (c.health < c.max_health * 0.55 and near >= 1 and randf() < 0.04) or (near >= 2 and randf() < 0.01)
			"repair":
				c.ctrl.special = c.health < c.max_health * 0.4 and randf() < 0.05
	# mobilidade de salto: de vez em quando (o nitro comum fica com a IA de direção)
	if c.nitro_type == "jump" and c.nitro_ch > 0:
		c.ctrl.nitro = randf() < 0.004 and c.on_ground and not c.on_feature
	# mina/óleo quando alguém está colado atrás
	var b := -c.global_transform.basis.z
	for o in game.cars:
		if o == c or o.wrecked or o.role == "traffic":
			continue
		var d: Vector3 = o.global_position - c.global_position
		if d.length() < 18.0 and d.normalized().dot(b) > 0.9 and randf() < 0.02:
			c.ctrl.drop = true


func _muzzle_flash(pos: Vector3, aim: Vector3, big := false) -> void:
	var f: Dictionary = flashes[flash_i]
	flash_i = (flash_i + 1) % flashes.size()
	f.t = 0.05
	(f.l as OmniLight3D).global_position = pos
	var cb: Basis = game.cam.global_basis
	var s := randf_range(0.55, 0.95) * (1.6 if big else 1.0)
	var star: MeshInstance3D = f.q
	star.global_transform = Transform3D(cb.rotated(cb.z, randf() * TAU).scaled(Vector3(s, s, s)), pos)
	star.visible = true
	var cone: MeshInstance3D = f.cone
	var x := aim.cross(Vector3.UP if absf(aim.y) < 0.95 else Vector3.RIGHT).normalized()
	var ln := randf_range(0.9, 1.6) * (1.5 if big else 1.0)
	cone.global_transform = Transform3D(Basis(x, aim, x.cross(aim)).scaled(Vector3(1, ln, 1)), pos + aim * ln * 0.5)
	cone.visible = true


func _use(k: String) -> void:
	uses[k] = int(uses.get(k, 0)) + 1


func _fire_mg(c: Car) -> void:
	_use("mg")
	c.fire_cd = 0.085 / c.rate_mult
	c.ammo_f -= 1
	c.recoil = 1.0
	c.firing_t = 0.12
	if c.casings == null and c.weapon_node:
		c.casings = _make_casings()
		c.weapon_node.add_child(c.casings)
		c.casings.position = Vector3(0.25, 0.3, 0.0)
	var mz: Vector3 = c.global_transform * c.muzzle_local
	var f := c.global_transform.basis.z
	var tgt := _target(c, 50.0, 0.982)
	var aim := f
	if tgt:
		aim = (tgt.global_position + tgt.global_transform.basis.y * 0.7 - mz).normalized()
	aim = (aim + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.014).normalized()
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(mz, mz + aim * 55.0, 1 | 2 | 4 | 16, [c.get_rid()])
	var res := space.intersect_ray(q)
	var endp := mz + aim * 55.0
	var hit := {}
	if res:
		endp = res.position
		hit = {"collider": res.collider, "normal": res.normal}
	_muzzle_flash(mz, aim)
	# a bala viaja (~300 m/s); dano e impacto acontecem quando ela chega
	var tr: Dictionary = tracers[tracer_i]
	tracer_i = (tracer_i + 1) % tracers.size()
	tr.a = mz
	tr.b = endp
	tr.aim = aim
	tr.t = 0.0
	tr.dur = maxf(0.02, mz.distance_to(endp) / 300.0)
	tr.hit = hit
	tr.owner = c
	if game._on_screen(mz):
		sfx.play("gun", -11.0 if c != game.player else -5.0, randf_range(0.88, 1.12))
	if c == game.player:
		game._shake(0.03)


func _step_tracers(dt: float) -> void:
	for tr in tracers:
		if tr.t < 0.0:
			continue
		tr.t += dt
		var mi: MeshInstance3D = tr.mi
		var a: Vector3 = tr.a
		var b: Vector3 = tr.b
		var k: float = clampf(tr.t / tr.dur, 0.0, 1.0)
		var head := a.lerp(b, k)
		var aim: Vector3 = tr.aim
		var ln := minf(5.5, head.distance_to(a))
		if ln > 0.2:
			var x := aim.cross(Vector3.UP if absf(aim.y) < 0.95 else Vector3.RIGHT).normalized()
			mi.global_transform = Transform3D(Basis(x, aim, x.cross(aim)).scaled(Vector3(1, ln, 1)), head - aim * ln * 0.5)
			mi.visible = true
		if k >= 1.0:
			mi.visible = false
			tr.t = -1.0
			_bullet_impact(tr)


func _bullet_impact(tr: Dictionary) -> void:
	var hit: Dictionary = tr.hit
	if hit.is_empty():
		return
	var c: Car = tr.owner
	var p: Vector3 = tr.b
	var aim: Vector3 = tr.aim
	var hc = hit.collider
	if not is_instance_valid(hc):
		return
	var vis: bool = game._on_screen(p)
	if hc is Car:
		var tc: Car = hc
		var dmg := 1.9 if c.role == "player" else 1.1
		if is_instance_valid(c):
			dmg *= c.dmg_mult
		var killed := tc.apply_damage(dmg, p, c if is_instance_valid(c) else null)
		tc.apply_impulse(aim * 140.0, p - tc.global_position)
		if vis:
			fx.sparks(p, -aim + tc.global_transform.basis.y * 0.5, 0.18)
			_muzzle_flash(p - aim * 0.3, -aim)
		if c == game.player:
			sfx.play("tink", -8.0, randf_range(0.85, 1.25))
			ret_pulse = 1.0
			var e: Dictionary = acc.get(tc, {"dmg": 0.0, "t": 0.0})
			e.dmg += dmg
			acc[tc] = e
			if killed:
				_number(tc.global_position + Vector3.UP * 2.6, "DESTRUÍDO!", Color("#ffcf33"), 1.3)
				acc.erase(tc)
			game.on_player_hit_enemy(tc, killed)
		elif tc == game.player:
			game.on_player_got_hit(dmg)
			sfx.play("tink", -12.0, randf_range(0.7, 0.9))
	else:
		if hc is RigidBody3D:
			(hc as RigidBody3D).apply_impulse(aim * 60.0)
		if not vis:
			return
		var n: Vector3 = hit.normal
		if n.y > 0.6:
			# chão: poeirinha e lasca
			fx.burst("bulletdust", p + n * 0.1)
			fx.sparks(p, n + aim * 0.4, 0.05)
		else:
			# muro: ricochete com faísca
			fx.sparks(p, aim.bounce(n) if aim.dot(n) < 0.0 else n, 0.15)
			if randf() < 0.3:
				sfx.play("tink", -16.0, randf_range(1.2, 1.6))


func _make_casings() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.7
	p.local_coords = false
	p.emitting = false
	var m := BoxMesh.new()
	m.size = Vector3(0.05, 0.05, 0.13)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.3)
	mat.metallic = 0.9
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 0.4
	m.material = mat
	p.mesh = m
	p.direction = Vector3(1, 1.2, -0.3)
	p.spread = 18
	p.initial_velocity_min = 3.5
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -22, 0)
	p.angular_velocity_min = -900
	p.angular_velocity_max = 900
	p.particle_flag_rotate_y = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _number(pos: Vector3, txt: String, col: Color, scl := 1.0) -> void:
	var n: Dictionary = numbers[num_i]
	num_i = (num_i + 1) % numbers.size()
	var lb: Label3D = n.lb
	lb.text = txt
	lb.modulate = col
	lb.global_position = pos + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
	lb.scale = Vector3.ONE * 0.4 * scl
	lb.visible = true
	n.t = 0.0
	n.scl = scl


func _step_numbers(dt: float) -> void:
	for tc in acc.keys():
		var e: Dictionary = acc[tc]
		e.t += dt
		if e.t > 0.22:
			if is_instance_valid(tc) and not tc.wrecked:
				_number(tc.global_position + Vector3.UP * 2.4, str(int(ceil(e.dmg))), Color("#ffe27a"))
			acc.erase(tc)
	for n in numbers:
		var lb: Label3D = n.lb
		if not lb.visible:
			continue
		n.t += dt
		var t: float = n.t
		lb.global_position += Vector3.UP * dt * 2.2
		var pop := 1.0 + 0.6 * exp(-t * 14.0)
		lb.scale = Vector3.ONE * float(n.scl) * pop
		lb.modulate.a = clampf(1.0 - (t - 0.45) / 0.3, 0.0, 1.0)
		if t > 0.75:
			lb.visible = false


func _step_reticle(dt: float) -> void:
	var p: Car = game.player
	if p == null or game.mode != "race" or p.wrecked:
		reticle.visible = false
		return
	var tgt := _target(p, 50.0, 0.982) if p.front_type == "mg" else _target(p, 75.0, 0.93)
	ret_pulse = maxf(0.0, ret_pulse - dt * 6.0)
	ret_t += dt
	if tgt == null:
		reticle.visible = false
		return
	reticle.visible = true
	reticle.global_position = tgt.global_position + tgt.global_transform.basis.y * 0.8
	var s := 1.0 + ret_pulse * 0.35
	reticle.scale = Vector3(s, s, s)
	var m := reticle.material_override as ShaderMaterial
	m.set_shader_parameter("spin", ret_t * (6.0 if p.ctrl.fire else 1.5))
	m.set_shader_parameter("pulse", ret_pulse)
	m.set_shader_parameter("col", Color(1.0, 0.25, 0.2) if p.ctrl.fire else Color(1.0, 0.85, 0.3))


func _fire_rocket(c: Car) -> void:
	_use("rocket")
	c.fire_cd = 0.55 / c.rate_mult
	c.ammo_f -= 1
	var mz: Vector3 = c.global_transform * c.muzzle_local
	var f := c.global_transform.basis.z
	var node := lib.get_node("proj_rocket").duplicate() as Node3D
	add_child(node)
	node.global_position = mz
	node.scale = Vector3.ONE * 1.45
	# chama do motor: núcleo de fogo contínuo saindo pela cauda
	var fire := CPUParticles3D.new()
	fire.amount = 36
	fire.lifetime = 0.22
	fire.local_coords = false
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fq := QuadMesh.new()
	fq.size = Vector2(1, 1)
	fq.material = fx._bb_mat(fx.fire_tex, true)
	fire.mesh = fq
	fire.direction = Vector3(0, 0, -1)
	fire.spread = 8
	fire.initial_velocity_min = 4
	fire.initial_velocity_max = 8
	fire.gravity = Vector3.ZERO
	fire.scale_amount_min = 0.45
	fire.scale_amount_max = 0.75
	fire.scale_amount_curve = fx._curve([Vector2(0, 1.0), Vector2(1, 0.1)])
	fire.color_ramp = fx._ramp([Color(4, 3.6, 2.4, 1), Color(3.2, 1.3, 0.3, 0.9), Color(0.8, 0.2, 0.05, 0)])
	fire.position = Vector3(0, 0, -0.5)
	node.add_child(fire)
	fire.emitting = true
	var trail := fx.make_damage_smoke(true)
	trail.amount = 40
	trail.lifetime = 1.1
	trail.scale_amount_min = 0.35
	trail.scale_amount_max = 0.55
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.8
	trail.color_ramp = fx._ramp([Color(1, 1, 1, 0.0), Color(0.95, 0.95, 0.97, 0.8), Color(0.8, 0.8, 0.85, 0.0)], [0.0, 0.1, 1.0])
	node.add_child(trail)
	trail.emitting = true
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.25)
	glow.light_energy = 3.0
	glow.omni_range = 5.0
	node.add_child(glow)
	var fl := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.1, 1.1)
	qm.material = fx._bb_mat(fx.fire_tex, true)
	fl.mesh = qm
	fl.position = Vector3(0, 0, -0.62)
	fl.name = "Glow"
	node.add_child(fl)
	var tgt := _target(c, 75.0, 0.93)
	var v0 := maxf(0.0, c.linear_velocity.dot(f)) + 14.0
	rockets.append({"node": node, "vel": f * v0, "owner": c, "t": 0.0, "target": tgt, "trail": trail})
	_muzzle_flash(mz, f, true)
	c.recoil = 2.0
	sfx.play("rocket", -4.0 if c == game.player else -9.0)
	if c == game.player:
		game._shake(0.12)
		if tgt:
			game.hud.popup("ALVO: " + tgt.display_name, Color("#ff7a1a"))


func _step_rockets(dt: float) -> void:
	var space := get_world_3d().direct_space_state
	for i in range(rockets.size() - 1, -1, -1):
		var r: Dictionary = rockets[i]
		r.t += dt
		var node: Node3D = r.node
		var vel: Vector3 = r.vel
		# acelera até 50 m/s: mais rápido que o carro na reta (40), mais lento que o nitro (~58)
		var rm: float = (r.owner as Car).rate_mult if is_instance_valid(r.owner) else 1.0
		var spd := move_toward(vel.length(), 50.0 * (1.0 + (rm - 1.0) * 0.7), 16.0 * rm * dt)
		var tg = r.target
		if tg != null and is_instance_valid(tg) and not tg.wrecked:
			var want: Vector3 = ((tg as Car).global_position + Vector3.UP * 0.7 - node.global_position).normalized()
			vel = vel.normalized().slerp(want, minf(1.0, 1.9 * dt)) * spd
		else:
			vel = vel.normalized() * spd
		r.vel = vel
		var p0 := node.global_position
		var p1 := p0 + vel * dt
		var excl := [] if r.t > 0.25 else [(r.owner as Car).get_rid()]
		var q := PhysicsRayQueryParameters3D.create(p0, p1, 1 | 2 | 4 | 16, excl)
		var res := space.intersect_ray(q)
		if res or r.t > 4.0:
			var at: Vector3 = res.position if res else p1
			_explode(at, r.owner, 34.0 * ((r.owner as Car).dmg_mult if is_instance_valid(r.owner) else 1.0), 6.0, "rocket")
			var tr: CPUParticles3D = r.trail
			tr.emitting = false
			tr.reparent(self)
			get_tree().create_timer(1.2, false).timeout.connect(tr.queue_free)
			node.queue_free()
			rockets.remove_at(i)
			continue
		node.global_position = p1
		node.look_at(p1 + vel, Vector3.UP if absf(vel.normalized().y) < 0.95 else Vector3.RIGHT)
		node.rotate_object_local(Vector3.UP, PI)
		node.rotate_object_local(Vector3(0, 0, 1), r.t * 15.0)   # gira em torno do próprio eixo
		node.scale = Vector3.ONE * 1.45
		var gl := node.get_node_or_null("Glow") as Node3D
		if gl:
			var w := randf_range(0.8, 1.25)
			gl.scale = Vector3(w, w, w)


func _explode(pos: Vector3, owner: Car, dmg: float, radius: float, style: String) -> void:
	fx.explosion(pos, false, style)
	if game._on_screen(pos):
		sfx.play("boom", -2.0 if style != "mine" else 0.0, randf_range(0.9, 1.15))
		var dp: float = pos.distance_to(game.player.global_position)
		game._shake(clampf(0.6 - dp * 0.03, 0.05, 0.6))
	for car in game.cars:
		var c: Car = car
		if c.wrecked:
			continue
		var d := c.global_position + Vector3.UP * 0.6 - pos
		var dist := d.length()
		if dist > radius:
			continue
		var k := 1.0 - dist / radius
		var mult := 0.75 if (c.role == "player" and owner != null and owner.role != "player") else 1.0
		var killed := c.apply_damage((dmg * k + 6.0) * mult, pos, owner)
		var push := (d.normalized() + Vector3.UP * (1.2 if style == "mine" else 0.6)).normalized()
		c.apply_impulse(push * c.mass * (9.0 if style == "mine" else 6.0) * k, Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.8, 0.8)))
		c.stun = maxf(c.stun, 0.4 * k)
		if owner == game.player and c != game.player:
			game.on_player_hit_enemy(c, killed)
		elif c == game.player:
			game.on_player_got_hit(dmg * k + 6.0)
	for pr in game.props:
		var rb: RigidBody3D = pr.rb
		var d2 := rb.global_position - pos
		if d2.length() < radius * 1.2:
			rb.apply_central_impulse((d2.normalized() + Vector3.UP) * rb.mass * 9.0)


func _drop(c: Car) -> void:
	_use(c.rear_type)
	c.drop_cd = 0.7
	c.ammo_r -= 1
	var b := c.global_transform.basis
	var p: Vector3 = c.global_position - b.z * (c.sp.len * 0.5 + 1.0) + b.y * 1.0
	var space := get_world_3d().direct_space_state
	var res := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p - b.y * 4.0, 1, [c.get_rid()]))
	var n := b.y
	if res:
		p = res.position
		n = res.normal
	var basis := Basis(n.cross(b.z).normalized(), n, b.z.slide(n).normalized()).orthonormalized()
	if c.rear_type == "spikes":
		_drop_spikes(c, p, basis, n)
		return
	if c.rear_type == "barrel":
		_drop_barrel(c, p, n)
		return
	if c.rear_type == "mine":
		var node := lib.get_node("proj_mine").duplicate() as Node3D
		add_child(node)
		node.global_transform = Transform3D(basis, p + n * 0.02)
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.15, 0.1)
		l.omni_range = 3.0
		l.position = Vector3(0, 0.4, 0)
		node.add_child(l)
		mines.append({"node": node, "owner": c, "t": 0.0, "light": l, "n": n})
		sfx.play("drop", -6.0)
	else:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(7.0, 7.0)
		mi.mesh = pm
		var m := ShaderMaterial.new()
		m.shader = oil_shader
		m.set_shader_parameter("strength", 1.0)
		m.set_shader_parameter("spread", 0.15)
		m.set_shader_parameter("seed", randf() * 50.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_transform = Transform3D(basis.rotated(n, randf() * TAU), p + n * 0.1)
		oils.append({"node": mi, "owner": c, "t": 0.0, "pos": p, "n": n})
		sfx.play("splat", -4.0)
	if c == game.player:
		game.hud.popup("MINA!" if c.rear_type == "mine" else "ÓLEO!", Color("#ffcf33"))


func _step_mines(dt: float) -> void:
	for i in range(mines.size() - 1, -1, -1):
		var m: Dictionary = mines[i]
		m.t += dt
		var node: Node3D = m.node
		(m.light as OmniLight3D).light_energy = 3.0 if fmod(m.t, 0.5) < 0.12 else 0.2
		var gone: bool = m.t > 30.0
		if m.t > 0.7:
			for car in game.cars:
				var c: Car = car
				if c.wrecked or (c == m.owner and m.t < 1.6):
					continue
				if c.global_position.distance_to(node.global_position) < 2.4:
					_explode(node.global_position, m.owner, 30.0, 4.5, "mine")
					gone = true
					break
		if gone:
			node.queue_free()
			mines.remove_at(i)


func _step_oils(dt: float) -> void:
	for i in range(oils.size() - 1, -1, -1):
		var o: Dictionary = oils[i]
		o.t += dt
		var mi: MeshInstance3D = o.node
		var spread := minf(1.0, 0.15 + o.t * 1.8)   # a mancha se espalha ao cair
		if o.t < 0.6:
			(mi.material_override as ShaderMaterial).set_shader_parameter("spread", spread)
		if o.t > 12.0:
			(mi.material_override as ShaderMaterial).set_shader_parameter("strength", maxf(0.0, 1.0 - (o.t - 12.0)))
		if o.t > 13.0:
			mi.queue_free()
			oils.remove_at(i)
			continue
		for car in game.cars:
			var c: Car = car
			if c.wrecked or (c == o.owner and o.t < 1.5):
				continue
			var d: Vector3 = c.global_position - (o.pos as Vector3)
			if d.slide(o.n).length() < 3.3 * spread and absf(d.dot(o.n)) < 1.5:
				if c.oil_t <= 0.0:
					# entrou na graxa: rodopia para um lado, espirra e suja os pneus
					var up := c.global_transform.basis.y
					c.angular_velocity += up * (1.5 if randf() < 0.5 else -1.5) * clampf(c.linear_velocity.length() / 25.0, 0.4, 1.3)
					if game._on_screen(c.global_position):
						fx.burst("oil", c.global_position + up * 0.2, -c.linear_velocity.normalized())
						sfx.play("splat", -6.0, randf_range(0.9, 1.2))
					if c == game.player:
						game.hud.popup("ESCORREGOU!", Color("#8a8aff"))
						game._shake(0.18)
						game.oil_fx = 1.0
				c.oil_t = 1.1
				c.oily_t = 2.6


# ================================================================== armas únicas dos carros
func _add_mat(col: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r * energy, col.g * energy, col.b * energy, 1.0)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


## raio elétrico (Vespa): acerta na hora o alvo no cone e salta para mais um carro perto dele
func _fire_zap(c: Car) -> void:
	_use("zap")
	c.fire_cd = 0.55 / c.rate_mult
	c.ammo_f -= 1
	c.recoil = 1.2
	var mz: Vector3 = c.global_transform * c.muzzle_local
	var tgt := _target(c, 28.0, 0.88)
	if tgt == null:
		_bolt(mz, mz + c.global_transform.basis.z * 9.0 + Vector3.UP * randf_range(-1, 1), 0.6)
		sfx.play("zap", -10.0, randf_range(1.1, 1.3))
		return
	var hp: Vector3 = tgt.global_position + Vector3.UP * 0.8
	_bolt(mz, hp, 1.0)
	_zap_hit(c, tgt, 16.0 * c.dmg_mult)
	# corrente: pula para o carro mais perto do alvo
	var best: Car = null
	var bd := 12.0
	for o in game.cars:
		if o == c or o == tgt or o.wrecked or o.role == "traffic":
			continue
		var d: float = o.global_position.distance_to(tgt.global_position)
		if d < bd:
			bd = d
			best = o
	if best:
		_bolt(hp, best.global_position + Vector3.UP * 0.8, 0.7)
		_zap_hit(c, best, 9.0 * c.dmg_mult)
	sfx.play("zap", -4.0 if c == game.player else -9.0, randf_range(0.9, 1.1))
	if c == game.player:
		game._shake(0.06)


func _zap_hit(c: Car, t: Car, dmg: float) -> void:
	var killed := t.apply_damage(dmg, t.global_position + Vector3.UP, c, false)
	t.stun = maxf(t.stun, 0.25)
	if game._on_screen(t.global_position):
		fx.sparks(t.global_position + Vector3.UP, Vector3.UP, 1.0)
		fx.hit_light(t.global_position + Vector3.UP * 1.5, Color(0.4, 0.85, 1.0), 6.0, 9.0, 0.15)
	if c == game.player:
		_number(t.global_position + Vector3.UP * 2.2, str(int(dmg)), Color(0.5, 0.9, 1.0))
		game.on_player_hit_enemy(t, killed)


## desenha um raio em zigue-zague (fita voltada para a câmera)
func _bolt(a: Vector3, b: Vector3, w: float) -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mi.mesh = im
	mi.material_override = _add_mat(Color(0.45, 0.85, 1.0), 2.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var pts: Array = [a]
	var seg := 9
	var dir := b - a
	var side := dir.cross(Vector3.UP).normalized()
	for i in range(1, seg):
		var u := float(i) / seg
		pts.append(a + dir * u + side * randf_range(-0.6, 0.6) * w + Vector3.UP * randf_range(-0.5, 0.5) * w)
	pts.append(b)
	var cam_f: Vector3 = -game.cam.global_basis.z
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var width := (0.32 if k == 0 else 0.1) * w
		var col := Color(0.35, 0.7, 1.0, 0.7) if k == 0 else Color(1, 1, 1, 1)
		for i in pts.size() - 1:
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[i + 1]
			var nrm := (p1 - p0).cross(cam_f).normalized() * width
			for v in [p0 - nrm, p0 + nrm, p1 + nrm, p0 - nrm, p1 + nrm, p1 - nrm]:
				im.surface_set_color(col)
				im.surface_add_vertex(v)
	im.surface_end()
	bolts.append({"node": mi, "t": 0.0})


func _step_bolts(dt: float) -> void:
	for i in range(bolts.size() - 1, -1, -1):
		var b: Dictionary = bolts[i]
		b.t += dt
		var mi: MeshInstance3D = b.node
		mi.transparency = clampf(b.t / 0.16, 0.0, 1.0)
		if b.t > 0.16:
			mi.queue_free()
			bolts.remove_at(i)


## lança-chamas (Monstro): segurar o tiro solta um jato curto que queima quem estiver na frente
func _fire_flame(c: Car) -> void:
	_use("flame")
	c.fire_cd = 0.05
	c.ammo_f -= 1
	c.firing_t = 0.15
	if Engine.get_physics_frames() % 2 != 0:
		return
	var f := c.global_transform.basis.z
	var mz: Vector3 = c.global_transform * c.muzzle_local
	for o in game.cars:
		var t: Car = o
		if t == c or t.wrecked:
			continue
		var d: Vector3 = t.global_position + Vector3.UP * 0.6 - mz
		if d.length() < 11.0 * (1.0 + (c.rate_mult - 1.0) * 0.5) and d.normalized().dot(f) > 0.8:
			var killed := t.apply_damage(3.0 * c.dmg_mult * (1.0 + (c.rate_mult - 1.0) * 0.5), t.global_position + Vector3.UP, c, false)
			t.burn_t = maxf(t.burn_t, 1.6)
			t.burn_by = c
			if c == game.player:
				game.on_player_hit_enemy(t, killed)
	if game._on_screen(mz) and Engine.get_physics_frames() % 6 == 0:
		sfx.play("flame", -12.0 if c != game.player else -6.0, randf_range(0.9, 1.1))


func _flame_fx(c: Car) -> void:
	if c.front_type != "flame":
		return
	var p: CPUParticles3D = c.get_meta("flame_p") if c.has_meta("flame_p") else null
	if p == null:
		p = CPUParticles3D.new()
		p.amount = 70
		p.lifetime = 0.45
		p.local_coords = false
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		q.material = fx._bb_mat(fx.fire_tex, true)
		p.mesh = q
		p.direction = Vector3(0, 0.05, 1)
		p.spread = 9.0
		p.initial_velocity_min = 20.0
		p.initial_velocity_max = 26.0
		p.gravity = Vector3(0, 2, 0)
		p.damping_min = 12.0
		p.damping_max = 18.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 0.9
		p.scale_amount_curve = fx._curve([Vector2(0, 0.5), Vector2(0.5, 1.6), Vector2(1, 2.4)])
		p.color_ramp = fx._ramp([Color(4, 3.4, 2.2, 1), Color(3.0, 1.1, 0.25, 0.9), Color(0.5, 0.15, 0.05, 0.0)])
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.add_child(p)
		p.position = c.muzzle_local
		c.set_meta("flame_p", p)
	p.emitting = c.firing_t > 0.0 and c.ammo_f > 0 and not c.wrecked


## pregos (Vespa): quem passa fura os pneus (mais lento por 2,5 s) e leva um pouco de dano
func _drop_spikes(c: Car, p: Vector3, basis: Basis, n: Vector3) -> void:
	var node := Node3D.new()
	add_child(node)
	node.global_transform = Transform3D(basis, p + n * 0.02)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.77, 0.82)
	mat.metallic = 1.0
	mat.roughness = 0.25
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.12
	cm.height = 0.38
	cm.radial_segments = 6
	for i in 18:
		var s := MeshInstance3D.new()
		s.mesh = cm
		s.material_override = mat
		s.position = Vector3(randf_range(-2.0, 2.0), 0.15, randf_range(-1.6, 1.6))
		s.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
		node.add_child(s)
	spikes.append({"node": node, "owner": c, "t": 0.0, "pos": p, "n": n, "hit": {}})
	sfx.play("drop", -6.0, 1.3)
	if c == game.player:
		game.hud.popup("PREGOS!", Color("#ffcf33"))


func _step_spikes(dt: float) -> void:
	for i in range(spikes.size() - 1, -1, -1):
		var s: Dictionary = spikes[i]
		s.t += dt
		if s.t > 16.0:
			(s.node as Node).queue_free()
			spikes.remove_at(i)
			continue
		for car in game.cars:
			var c: Car = car
			if c.wrecked or (c == s.owner and s.t < 1.5) or s.hit.has(c):
				continue
			var d: Vector3 = c.global_position - (s.pos as Vector3)
			if d.slide(s.n).length() < 2.8 and absf(d.dot(s.n)) < 1.4:
				s.hit[c] = true
				c.flat_t = 2.5
				var killed := c.apply_damage(8.0, c.global_position, s.owner, false)
				if game._on_screen(c.global_position):
					fx.sparks(c.global_position, -c.linear_velocity.normalized() + Vector3.UP, 1.2)
					sfx.play("metal", -6.0, 1.4)
				if c == game.player or c.local_idx >= 0:
					game.pop_for(c, "PNEU FURADO!", Color("#ff7a7a"))
				if s.owner == game.player and c != game.player:
					game.on_player_hit_enemy(c, killed)


## barril rolante (Monstro): rola para trás pela pista e explode em quem encostar
func _drop_barrel(c: Car, p: Vector3, n: Vector3) -> void:
	var node := lib.get_node("prop_barrel").duplicate() as Node3D
	add_child(node)
	node.global_position = p + n * 0.6
	var back := -c.global_transform.basis.z
	var v: Vector3 = c.linear_velocity * 0.35 + back * 9.0
	barrels.append({"node": node, "owner": c, "t": 0.0, "vel": v.slide(n), "n": n, "spin": 0.0})
	sfx.play("drop", -4.0, 0.8)
	if c == game.player:
		game.hud.popup("BARRIL!", Color("#ffcf33"))


func launch_barrel(owner: Car, pos: Vector3, vel: Vector3, n: Vector3) -> void:
	var node := lib.get_node("prop_barrel").duplicate() as Node3D
	add_child(node)
	node.global_position = pos
	node.scale = Vector3.ONE * 1.4
	barrels.append({"node": node, "owner": owner, "t": 0.0, "vel": vel, "n": n, "spin": 0.0, "big": true})


func _step_barrels(dt: float) -> void:
	var space := get_world_3d().direct_space_state
	for i in range(barrels.size() - 1, -1, -1):
		var b: Dictionary = barrels[i]
		b.t += dt
		var node: Node3D = b.node
		var vel: Vector3 = b.vel
		var p := node.global_position + vel * dt
		# rola colado ao chão (raio para baixo)
		var res := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + (b.n as Vector3) * 1.5, p - (b.n as Vector3) * 3.0, 1))
		if res:
			p = res.position + res.normal * 0.55
			b.n = res.normal
		else:
			vel += Vector3.DOWN * 20.0 * dt
		b.vel = vel * (1.0 - 0.15 * dt)
		node.global_position = p
		b.spin += vel.length() * dt / 0.5
		var fwd := vel.normalized() if vel.length() > 0.5 else Vector3.FORWARD
		var nn: Vector3 = b.n
		var side := fwd.cross(nn).normalized()
		node.global_transform.basis = Basis(side, nn, fwd).orthonormalized().rotated(side, b.spin) * Basis(Vector3.RIGHT, PI / 2)
		node.scale = Vector3.ONE * (1.4 if b.get("big", false) else 1.0)
		var boom: bool = b.t > 5.0
		if b.t > 0.5:
			for car in game.cars:
				var c: Car = car
				if c.wrecked or (c == b.owner and b.t < 1.5):
					continue
				if c.global_position.distance_to(p) < (3.0 if b.get("big", false) else 2.4):
					boom = true
					break
		if boom:
			_explode(p, b.owner, 30.0 if b.get("big", false) else 26.0, 5.0, "rocket")
			node.queue_free()
			barrels.remove_at(i)


# ------------------------------------------------------------------ especiais
func can_special(c: Car, kind: String) -> bool:
	match kind:
		"jump":
			return c.on_ground and not c.on_feature
		"repair":
			return c.health < c.max_health - 1.0
	return true


func special(c: Car, kind: String) -> void:
	_use(kind)
	# online: avisa as outras máquinas (lá o efeito pega nos carros que elas controlam)
	if game.online and game.online.racing and not c.net_remote:
		game.online.send_special(c, kind)
	var vis: bool = game._on_screen(c.global_position)
	match kind:
		"jump":
			# salto: pula minas, pregos, óleo e até carros
			var up: Vector3 = c.ground_n if c.on_ground else Vector3.UP
			c.apply_central_impulse(up * c.mass * 10.5 + c.global_transform.basis.z * c.mass * 2.5)
			c.juice_squash(1.4)
			if vis:
				fx.burst("dust", c.global_position)
				sfx.play("whoosh", -3.0, 1.2)
			game.pop_for(c, "SALTO!", Color("#2ee6ff"))
		"shield":
			c.shield_t = 3.0
			c.invuln = maxf(c.invuln, 0.0)
			if vis:
				sfx.play("nitro", -4.0, 1.5)
				fx.hit_light(c.global_position + Vector3.UP, Color(0.4, 0.8, 1.0), 6.0, 10.0, 0.3)
			game.pop_for(c, "ESCUDO!", Color("#2ee6ff"))
		"shock":
			shock_wave(c, c.global_position, 12.0, 18.0, 1.0)
			game.pop_for(c, "ONDA DE CHOQUE!", Color("#ff9a1a"))
		"repair":
			# reparo de emergência: devolve 40% da blindagem e apaga fogo/pneu furado
			if not c.net_remote:
				c.health = minf(c.max_health, c.health + c.max_health * 0.4)
			c.burn_t = 0.0
			c.flat_t = 0.0
			if vis:
				fx.sparkle(c.global_position + Vector3.UP, Color(0.5, 1.5, 0.6))
				fx.hit_light(c.global_position + Vector3.UP, Color(0.4, 1.0, 0.5), 6.0, 10.0, 0.4)
				sfx.play("pickup", -4.0, 0.8)
			game.pop_for(c, "REPARO!", Color("#5dff6a"))


## investida (Monstro): arrancada curta com o para-choque pegando fogo — quem estiver na frente é atropelado
func ram_start(c: Car) -> void:
	_use("ram")
	if game._on_screen(c.global_position):
		sfx.play("nitro", -3.0, 0.7)
		fx.burst("dust", c.global_position)
		ring_fx(c.global_position + c.global_transform.basis.z * c.sp.len * 0.5, 3.0, Color(1.0, 0.45, 0.15))
	game.pop_for(c, "INVESTIDA!", Color("#ff7a1a"))


func _ram_hit(c: Car) -> void:
	var f := c.global_transform.basis.z
	for o in game.cars:
		var t: Car = o
		if t == c or t.wrecked:
			continue
		var d := t.global_position - c.global_position
		if d.length() > (c.sp.len + t.sp.len) * 0.55 or d.normalized().dot(f) < 0.35:
			continue
		var key := "rmh_%d" % t.get_instance_id()
		if float(c.get_meta(key, -9.0)) > game.time_g - 0.8:
			continue
		c.set_meta(key, game.time_g)
		var killed := t.apply_damage(16.0 if t.role != "traffic" else 40.0, t.global_position, c)
		t.apply_central_impulse((Vector3(d.x, 0, d.z).normalized() * 0.8 + f * 0.6 + Vector3.UP * 0.45).normalized() * t.mass * 10.0)
		t.stun = maxf(t.stun, 0.5)
		if game._on_screen(t.global_position):
			fx.sparks(t.global_position + Vector3.UP, d.normalized(), 1.5)
			sfx.play("metal", -2.0, 0.8)
			game._shake(0.25 if c == game.player or t == game.player else 0.0)
		if c == game.player:
			game.on_player_hit_enemy(t, killed)


## onda de choque: empurra e levanta quem está perto (também usada pelo chefe BRUTUS)
func shock_wave(owner: Car, pos: Vector3, radius: float, dmg: float, power: float) -> void:
	ring_fx(pos, radius, Color(1.0, 0.6, 0.2))
	if game._on_screen(pos):
		sfx.play("boom", -2.0, 0.7)
		fx.burst("dust", pos)
		var dp: float = pos.distance_to(game.player.global_position)
		game._shake(clampf(0.7 - dp * 0.02, 0.1, 0.7))
	for car in game.cars:
		var c: Car = car
		if c == owner or c.wrecked:
			continue
		var d := c.global_position - pos
		var dist := d.length()
		if dist > radius:
			continue
		var k := 1.0 - dist / radius
		var killed := c.apply_damage(dmg * k + 4.0, pos, owner)
		var push := (Vector3(d.x, 0, d.z).normalized() * 1.0 + Vector3.UP * 0.9).normalized()
		c.apply_central_impulse(push * c.mass * 11.0 * power * (0.4 + k))
		c.stun = maxf(c.stun, 0.6 * k)
		if owner == game.player:
			game.on_player_hit_enemy(c, killed)


func ring_fx(pos: Vector3, radius: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	mi.mesh = tm
	mi.material_override = _add_mat(col, 2.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.4
	mi.scale = Vector3(0.5, 0.3, 0.5)
	rings.append({"node": mi, "t": 0.0, "r": radius})


func _step_rings(dt: float) -> void:
	for i in range(rings.size() - 1, -1, -1):
		var r: Dictionary = rings[i]
		r.t += dt
		var mi: MeshInstance3D = r.node
		var u := clampf(r.t / 0.4, 0.0, 1.0)
		var s: float = lerpf(0.5, float(r.r), 1.0 - (1.0 - u) * (1.0 - u))
		mi.scale = Vector3(s, 0.3 + (1.0 - u) * 0.6, s)
		mi.transparency = u
		if r.t > 0.4:
			mi.queue_free()
			rings.remove_at(i)


## escudo: bolha azul; encostar em alguém com o escudo ligado causa dano de aríete
func _shield_fx(c: Car) -> void:
	var b: MeshInstance3D = c.get_meta("shield_b") if c.has_meta("shield_b") else null
	if c.shield_t <= 0.0:
		if b:
			b.visible = false
		return
	if b == null:
		b = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		b.mesh = sm
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/shield.gdshader")
		b.material_override = m
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.add_child(b)
		b.position = Vector3(0, c.sp.clr + c.sp.h * 0.5, 0)
		b.scale = Vector3(c.sp.wid * 0.75, c.sp.h * 1.6 + 0.6, c.sp.len * 0.65)
		c.set_meta("shield_b", b)
	b.visible = true
	(b.material_override as ShaderMaterial).set_shader_parameter("fade", clampf(c.shield_t / 0.4, 0.0, 1.0))


func _shield_ram(c: Car) -> void:
	for o in game.cars:
		var t: Car = o
		if t == c or t.wrecked or t.role == "traffic":
			continue
		if t.global_position.distance_to(c.global_position) < (c.sp.len + t.sp.len) * 0.45:
			var key := "ram_%d" % t.get_instance_id()
			if float(c.get_meta(key, -9.0)) > game.time_g - 0.6:
				continue
			c.set_meta(key, game.time_g)
			var killed := t.apply_damage(22.0, t.global_position, c)
			var d := (t.global_position - c.global_position)
			t.apply_central_impulse((Vector3(d.x, 0, d.z).normalized() + Vector3.UP * 0.3) * t.mass * 8.0)
			if game._on_screen(t.global_position):
				fx.sparks(t.global_position + Vector3.UP, d.normalized(), 1.5)
				sfx.play("metal", -3.0)
			if c == game.player:
				game.on_player_hit_enemy(t, killed)


# ------------------------------------------------------------------ perigos (ataques dos chefes)
## kinds: "quake" (anel avisado e depois choque), "meteor" (círculo avisado e depois explosão),
## "fire" (chão em chamas por um tempo), "magnet" (puxa carros para o dono), "spikewall" (fileira de pregos)
func hazard(kind: String, owner: Car, pos: Vector3, r: float, delay: float, dur: float, extra := {}) -> Dictionary:
	_use("boss_" + kind)
	var h := {"kind": kind, "owner": owner, "pos": pos, "r": r, "t": 0.0, "delay": delay, "dur": dur, "done": false}
	h.merge(extra)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/telegraph.gdshader")
	m.set_shader_parameter("col", extra.get("col", Color(1.0, 0.2, 0.1)))
	m.set_shader_parameter("mode", {"fire": 1.0, "spikewall": 2.0, "lane": 2.0, "laser": 2.0, "mud": 3.0, "ice": 4.0}.get(kind, 0.0))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var n: Vector3 = extra.get("n", Vector3.UP)
	var fwd: Vector3 = extra.get("fwd", Vector3.FORWARD)
	var x := fwd.cross(n).normalized()
	mi.global_transform = Transform3D(Basis(x, n, n.cross(x)).scaled(Vector3(r, 1, float(extra.get("rz", r)))), pos + n * 0.12)
	h.node = mi
	hazards.append(h)
	return h


func _step_hazards(dt: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var h: Dictionary = hazards[i]
		h.t += dt
		var mi: MeshInstance3D = h.node
		var m := mi.material_override as ShaderMaterial
		var arm := clampf(float(h.t) / maxf(float(h.delay), 0.01), 0.0, 1.0)
		m.set_shader_parameter("arm", arm)
		m.set_shader_parameter("tt", h.t)
		var pos: Vector3 = h.pos
		if not h.done and h.t >= h.delay:
			h.done = true
			match String(h.kind):
				"quake":
					shock_wave(h.owner, pos, float(h.r), 26.0, 1.3)
				"meteor":
					_meteor_hit(h)
				"spikewall":
					sfx.play("metal", -4.0, 0.8)
				"lane":
					if is_instance_valid(h.owner) and not (h.owner as Car).wrecked:
						var o: Car = h.owner
						var to: Vector3 = (pos - o.global_position)
						o.apply_central_impulse((Vector3(to.x, 0, to.z).normalized() * 16.0 + o.global_transform.basis.z * 6.0) * o.mass)
						o.shield_t = 1.0   # o bote derruba quem estiver na faixa (aríete)
						sfx.play("whoosh", 0.0, 0.6)
				"emp":
					ring_fx(pos, float(h.r), Color(0.4, 0.8, 1.0))
					sfx.play("zap", 0.0, 0.5)
					for car in game.cars:
						var c: Car = car
						if c == h.owner or c.wrecked:
							continue
						if c.global_position.distance_to((h.owner as Car).global_position if is_instance_valid(h.owner) else pos) < float(h.r):
							c.emp_t = 3.0
							c.stun = maxf(c.stun, 0.3)
							if c.local_idx >= 0:
								game.pop_for(c, "EMP! ARMAS DESLIGADAS", Color("#7fd8ff"))
								game._flash(Color(0.5, 0.8, 1.0), 0.3)
		if h.done:
			match String(h.kind):
				"fire":
					for car in game.cars:
						var c: Car = car
						if c == h.owner or c.wrecked:
							continue
						var d: Vector3 = (c.global_position - pos)
						if absf(d.dot(mi.global_basis.x.normalized())) < float(h.r) and absf(d.dot(mi.global_basis.z.normalized())) < float(h.get("rz", h.r)) and absf(d.y) < 2.5:
							c.burn_t = maxf(c.burn_t, 1.2)
							c.burn_by = h.owner
				"mud", "ice":
					for car in game.cars:
						var c: Car = car
						if c == h.owner or c.wrecked:
							continue
						var d: Vector3 = (c.global_position - pos)
						if absf(d.dot(mi.global_basis.x.normalized())) < float(h.r) and absf(d.dot(mi.global_basis.z.normalized())) < float(h.get("rz", h.r)) and absf(d.y) < 2.5:
							if h.kind == "mud":
								if c.mud_t <= 0.0 and c.local_idx >= 0:
									game.pop_for(c, "ATOLOU!", Color("#c8a060"))
									if c == game.player:
										game.oil_fx = 1.0
								c.mud_t = 0.4
							else:
								if c.ice_t <= 0.0 and c.local_idx >= 0:
									game.pop_for(c, "GELO!", Color("#bfe6ff"))
								c.ice_t = 0.35
				"laser":
					# portão: liga e desliga a cada 1,2 s; ligado, queima e atordoa quem passa
					var on := fmod(float(h.t) - float(h.delay), 2.4) < 1.2
					if h.has("beam"):
						(h.beam as Node3D).visible = on
					if on:
						for car in game.cars:
							var c: Car = car
							if c == h.owner or c.wrecked or float(c.get_meta("laser_t", -9.0)) > game.time_g - 1.0:
								continue
							var d: Vector3 = (c.global_position - pos)
							if absf(d.dot(mi.global_basis.z.normalized())) < 1.2 and absf(d.dot(mi.global_basis.x.normalized())) < float(h.r) and absf(d.y) < 3.0:
								c.set_meta("laser_t", game.time_g)
								c.apply_damage(18.0, c.global_position + Vector3.UP, h.owner, false)
								c.stun = maxf(c.stun, 0.5)
								fx.sparks(c.global_position + Vector3.UP, Vector3.UP, 1.4)
								if c.local_idx >= 0:
									game.pop_for(c, "LASER!", Color("#ff3355"))
				"spikewall":
					for car in game.cars:
						var c: Car = car
						if c == h.owner or c.wrecked or c.flat_t > 0.0:
							continue
						var d: Vector3 = (c.global_position - pos)
						var lx: float = d.dot(mi.global_basis.x.normalized())
						var lz: float = d.dot(mi.global_basis.z.normalized())
						var gap: float = float(h.get("gap", 0.0))
						if absf(lz) < float(h.get("rz", 1.0)) + 0.8 and absf(lx) < float(h.r) and absf(lx - gap) > 2.6 and absf(d.y) < 2.5:
							c.flat_t = 3.0
							c.apply_damage(12.0, c.global_position, h.owner, false)
							if c.local_idx >= 0:
								game.pop_for(c, "PNEU FURADO! USE A BRECHA", Color("#ff7a7a"))
		if h.t > float(h.delay) + float(h.dur):
			mi.queue_free()
			if h.has("deco") and is_instance_valid(h.deco):
				(h.deco as Node).queue_free()
			if h.has("beam") and is_instance_valid(h.beam):
				(h.beam as Node).queue_free()
			hazards.remove_at(i)


func _meteor_hit(h: Dictionary) -> void:
	var pos: Vector3 = h.pos
	fx.explosion(pos, true, "fireball")
	if game._on_screen(pos):
		sfx.play("boom", 0.0, 0.8)
		var dp: float = pos.distance_to(game.player.global_position)
		game._shake(clampf(0.8 - dp * 0.03, 0.05, 0.8))
	for car in game.cars:
		var c: Car = car
		if c == h.owner or c.wrecked:
			continue
		var d := c.global_position - pos
		if d.length() < float(h.r) + 1.0:
			c.apply_damage(30.0, pos, h.owner)
			c.apply_central_impulse((d.normalized() + Vector3.UP).normalized() * c.mass * 8.0)
			c.burn_t = maxf(c.burn_t, 1.5)
			c.burn_by = h.owner
