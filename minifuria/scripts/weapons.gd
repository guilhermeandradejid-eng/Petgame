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
var reticle: MeshInstance3D
var ret_pulse := 0.0
var ret_t := 0.0


func setup(game_: Node, fx_: Fx, sfx_: Sfx, lib_: Node3D) -> void:
	game = game_
	fx = fx_
	sfx = sfx_
	lib = lib_
	oil_shader = load("res://shaders/ground_fx.gdshader")
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
		if c.wrecked or c.role == "traffic" or c.freeze:
			continue
		if c.role == "rival":
			_ai(c)
		if c.ctrl.fire and c.fire_cd <= 0.0 and c.ammo_f > 0:
			if c.front_type == "mg":
				_fire_mg(c)
			else:
				_fire_rocket(c)
		if c.ctrl.drop and c.drop_cd <= 0.0 and c.ammo_r > 0:
			_drop(c)
	_step_rockets(dt)
	_step_mines(dt)
	_step_oils(dt)
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
	if game.mode != "race":
		return
	# a IA atira em rajadas e com pausas (dá tempo de reagir)
	var burst_on := fmod(game.time_g + c.seed_f * 3.1, 4.0) < 1.6
	if c.front_type == "mg":
		c.ctrl.fire = burst_on and _target(c, 36.0, 0.985) != null
	else:
		c.ctrl.fire = _target(c, 55.0, 0.97) != null and randf() < 0.02
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


func _fire_mg(c: Car) -> void:
	c.fire_cd = 0.085
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
	c.fire_cd = 0.55
	c.ammo_f -= 1
	var mz: Vector3 = c.global_transform * c.muzzle_local
	var f := c.global_transform.basis.z
	var node := lib.get_node("proj_rocket").duplicate() as Node3D
	add_child(node)
	node.global_position = mz
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
	qm.size = Vector2(0.9, 0.9)
	qm.material = fx._bb_mat(fx.fire_tex, true)
	fl.mesh = qm
	fl.position = Vector3(0, 0, -0.6)
	node.add_child(fl)
	var tgt := _target(c, 75.0, 0.93)
	rockets.append({"node": node, "vel": c.linear_velocity + f * 46.0, "owner": c, "t": 0.0, "target": tgt, "trail": trail})
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
		var spd := minf(vel.length() + 40.0 * dt, 70.0)
		var tg = r.target
		if tg != null and is_instance_valid(tg) and not tg.wrecked:
			var want: Vector3 = ((tg as Car).global_position + Vector3.UP * 0.7 - node.global_position).normalized()
			vel = vel.normalized().slerp(want, minf(1.0, 2.6 * dt)) * spd
		else:
			vel = vel.normalized() * spd
		r.vel = vel
		var p0 := node.global_position
		var p1 := p0 + vel * dt
		var excl := [] if r.t > 0.25 else [(r.owner as Car).get_rid()]
		var q := PhysicsRayQueryParameters3D.create(p0, p1, 1 | 2 | 4 | 16, excl)
		var res := space.intersect_ray(q)
		if res or r.t > 2.4:
			var at: Vector3 = res.position if res else p1
			_explode(at, r.owner, 34.0, 6.0, "rocket")
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
		m.set_shader_parameter("mode", 3)
		m.set_shader_parameter("strength", 1.0)
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
			if d.slide(o.n).length() < 3.3 and absf(d.dot(o.n)) < 1.5:
				if c.oil_t <= 0.0 and c == game.player:
					game.hud.popup("ESCORREGOU!", Color("#8a8aff"))
				c.oil_t = 0.9
