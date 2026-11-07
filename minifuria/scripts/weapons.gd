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


func setup(game_: Node, fx_: Fx, sfx_: Sfx, lib_: Node3D) -> void:
	game = game_
	fx = fx_
	sfx = sfx_
	lib = lib_
	oil_shader = load("res://shaders/ground_fx.gdshader")
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.albedo_color = Color(4.0, 3.0, 1.2, 1.0)
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 24:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.07, 1.0)
		mi.mesh = bm
		mi.material_override = tm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		tracers.append({"mi": mi, "t": 0.0})
	for i in 6:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.8, 0.4)
		l.omni_range = 6.0
		l.light_energy = 0.0
		add_child(l)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.1, 1.1)
		qm.material = fx._bb_mat(fx.fire_tex, true)
		q.mesh = qm
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.visible = false
		add_child(q)
		flashes.append({"l": l, "q": q, "t": 0.0})


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
	for t in tracers:
		if t.t > 0.0:
			t.t -= dt
			(t.mi as MeshInstance3D).visible = t.t > 0.0
	for f in flashes:
		if f.t > 0.0:
			f.t -= dt
			(f.l as OmniLight3D).light_energy = maxf(0.0, f.t) * 60.0
			(f.q as MeshInstance3D).visible = f.t > 0.0


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


func _muzzle_flash(pos: Vector3) -> void:
	var f: Dictionary = flashes[flash_i]
	flash_i = (flash_i + 1) % flashes.size()
	f.t = 0.05
	(f.l as OmniLight3D).global_position = pos
	(f.q as MeshInstance3D).global_position = pos
	(f.q as MeshInstance3D).scale = Vector3.ONE * randf_range(0.6, 1.1)


func _tracer(a: Vector3, b: Vector3) -> void:
	var t: Dictionary = tracers[tracer_i]
	tracer_i = (tracer_i + 1) % tracers.size()
	var mi: MeshInstance3D = t.mi
	var d := b - a
	var l := d.length()
	if l < 0.5:
		return
	# só um pedaço da trajetória, como uma bala de luz
	var seg := minf(l, 7.0)
	var mid := a + d.normalized() * randf_range(seg * 0.5, l - seg * 0.5)
	mi.global_transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT).scaled(Vector3(1, 1, seg)), mid)
	mi.visible = true
	t.t = 0.06


func _fire_mg(c: Car) -> void:
	c.fire_cd = 0.085
	c.ammo_f -= 1
	var mz: Vector3 = c.global_transform * c.muzzle_local
	var f := c.global_transform.basis.z
	var tgt := _target(c, 50.0, 0.982)
	var aim := f
	if tgt:
		aim = (tgt.global_position + tgt.global_transform.basis.y * 0.7 - mz).normalized()
	aim = (aim + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.012).normalized()
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(mz, mz + aim * 55.0, 1 | 2 | 4, [c.get_rid()])
	var res := space.intersect_ray(q)
	var endp := mz + aim * 55.0
	_muzzle_flash(mz)
	if res:
		endp = res.position
		var hc = res.collider
		if hc is Car:
			var dmg := 1.9 if c.role == "player" else 1.1
			var killed: bool = (hc as Car).apply_damage(dmg, endp, c)
			(hc as Car).apply_impulse(aim * 140.0, endp - (hc as Car).global_position)
			fx.sparks(endp, -aim, 0.25)
			if c == game.player:
				game.on_player_hit_enemy(hc, killed)
			elif hc == game.player:
				game.on_player_got_hit(dmg)
		else:
			if hc is RigidBody3D:
				(hc as RigidBody3D).apply_impulse(aim * 60.0)
			fx.sparks(endp, res.normal, 0.12)
	_tracer(mz, endp)
	if game._on_screen(mz):
		sfx.play("gun", -10.0 if c != game.player else -4.0, randf_range(0.9, 1.1))
	if c == game.player:
		game._shake(0.025)


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
	_muzzle_flash(mz)
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
		var q := PhysicsRayQueryParameters3D.create(p0, p1, 1 | 2 | 4, excl)
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
