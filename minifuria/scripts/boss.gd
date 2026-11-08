class_name Boss
extends Node
## Chefe de mundo: carro gigante (modelo 1,6x), muita vida e ataques próprios — diferentes das armas
## equipáveis — sempre AVISADOS no chão antes de acertar (dá para desviar):
##   BRUTUS (van):        TREMOR — círculo onde você VAI passar, depois o chão explode e arremessa
##                        BARRIS GIGANTES — rola 3 barris para trás quando você está atrás dele
##   XERIFE DE AÇO:       ÍMÃ — raio que te puxa e segura a velocidade (escape com salto/escudo ou distância)
##                        BLOQUEIO — fileira de pregos na pista inteira, com UMA brecha
##   O IMPERADOR:         METEOROS — 4 círculos à sua frente, meteoros caem depois de 1,3 s
##                        MURO DE FOGO — deixa a pista em chamas atrás dele por alguns segundos

var car: Car
var game: Node
var w: Object       # Weapons
var cd := {}
var magnet_t := 0.0
var magnet_target: Car = null
var fire_t := 0.0
var fire_acc := 0.0
var _beam: MeshInstance3D
var balls: Array = []      # bolas de neve rolando (AVALANCHE)


func setup(c: Car, g: Node) -> void:
	car = c
	game = g
	w = g.weapons
	cd = {"a": 5.0, "b": 8.0}


func _target() -> Car:
	# o humano mais perto (atrás ou na frente)
	var best: Car = null
	var bd := 1e9
	for h in game.humans:
		if h.wrecked:
			continue
		var d: float = h.global_position.distance_to(car.global_position)
		if d < bd:
			bd = d
			best = h
	return best


## ponto da pista onde o carro estará daqui a "ahead" segundos (para o aviso cair no caminho dele)
func _predict(c: Car, ahead: float, lat_jitter := 0.0) -> Dictionary:
	var tr: Track = game.track
	var s: float = c.s_track + maxf(c.linear_velocity.length(), 12.0) * ahead
	var lat: float = clampf(c.lat + lat_jitter, -tr.HALF + 2.0, tr.HALF - 2.0)
	return tr.at(s, lat)


func _physics_process(dt: float) -> void:
	if car == null or game.mode != "race" or car.wrecked:
		_magnet_off()
		return
	for k in cd:
		cd[k] = maxf(0.0, float(cd[k]) - dt)
	var t := _target()
	if t == null:
		return
	var d: float = t.global_position.distance_to(car.global_position)
	var rel: float = wrapf(t.s_track - car.s_track, -game.track.length * 0.5, game.track.length * 0.5)   # >0: alvo na frente
	match car.kind:
		"boss_brutus":
			if cd.a <= 0.0 and d < 75.0:
				cd.a = randf_range(5.5, 7.5)
				_quake(t)
			if cd.b <= 0.0 and rel < -3.0 and rel > -70.0:
				cd.b = randf_range(5.5, 7.5)
				_barrels()
		"boss_xerife":
			if cd.a <= 0.0 and d < 38.0 and d > 6.0:
				cd.a = randf_range(9.0, 11.0)
				_magnet_on(t)
			if cd.b <= 0.0 and d < 90.0:
				cd.b = randf_range(7.0, 9.0)
				_spikewall(t)
		"boss_imperador":
			if cd.a <= 0.0 and d < 90.0:
				cd.a = randf_range(6.0, 7.5)
				_meteors(t)
			if cd.b <= 0.0 and rel < 0.0 and rel > -80.0:
				cd.b = randf_range(8.0, 10.0)
				fire_t = 2.2
		"boss_croc":
			if cd.a <= 0.0 and d < 80.0:
				cd.a = randf_range(5.5, 7.0)
				_mud(t)
			if cd.b <= 0.0 and d < 26.0 and absf(rel) < 18.0:
				cd.b = randf_range(6.0, 8.0)
				_lunge(t)
		"boss_avalanche":
			if cd.a <= 0.0 and rel < -10.0 and rel > -120.0:
				cd.a = randf_range(6.0, 7.5)
				_snowballs(t)
			if cd.b <= 0.0 and d < 90.0:
				cd.b = randf_range(7.0, 9.0)
				_ice(t)
		"boss_blackout":
			if cd.a <= 0.0 and d < 24.0:
				cd.a = randf_range(8.0, 10.0)
				_emp()
			if cd.b <= 0.0 and d < 90.0:
				cd.b = randf_range(9.0, 11.0)
				_lasers(t)
	_magnet_step(dt)
	_fire_step(dt)
	_balls_step(dt)


func _warn(text: String) -> void:
	if game.auto_test:
		print("BOSSATK %s t=%.1f %s" % [car.kind, game.race_t, text])
	for h in game.humans:
		if h.local_idx >= 0 and h.global_position.distance_to(car.global_position) < 90.0:
			game.pop_for(h, text, Color("#ff5a5a"))
	game.sfx.play("beep", -4.0, 0.6)


# ------------------------------------------------------------------ BRUTUS
func _quake(t: Car) -> void:
	var a := _predict(t, 1.0)
	w.hazard("quake", car, a.pos, 9.0, 1.0, 0.25, {"n": a.up, "fwd": a.tan, "col": Color(1.0, 0.45, 0.1)})
	car.juice_squash(1.8)
	_warn("TREMOR! SAIA DO CÍRCULO")


func _barrels() -> void:
	var b := car.global_transform.basis
	for i in 3:
		var side := float(i - 1)
		var p: Vector3 = car.global_position - b.z * (car.sp.len * 0.55 + 1.5) + b.x * side * 2.6 + b.y * 1.2
		var v: Vector3 = car.linear_velocity * 0.25 - b.z * 11.0 + b.x * side * 3.5
		w.launch_barrel(car, p, v, b.y)
	game.sfx.play("drop", -2.0, 0.6)
	_warn("BARRIS GIGANTES!")


# ------------------------------------------------------------------ XERIFE
func _magnet_on(t: Car) -> void:
	magnet_target = t
	magnet_t = 2.6
	_warn("ÍMÃ! PULE, USE ESCUDO OU SE AFASTE")
	if _beam == null:
		_beam = MeshInstance3D.new()
		var im := ImmediateMesh.new()
		_beam.mesh = im
		_beam.material_override = w._add_mat(Color(0.35, 0.6, 1.0), 2.2)
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.add_child(_beam)


func _magnet_off() -> void:
	magnet_t = 0.0
	if _beam:
		_beam.visible = false


func _magnet_step(dt: float) -> void:
	if magnet_t <= 0.0 or magnet_target == null or not is_instance_valid(magnet_target):
		_magnet_off()
		return
	magnet_t -= dt
	var t := magnet_target
	var d: Vector3 = car.global_position - t.global_position
	if d.length() > 42.0 or t.wrecked or t.shield_t > 0.0 or not t.on_ground:
		_magnet_off()
		return
	# puxa para o chefe e segura a velocidade (o motor "afoga")
	var pull := Vector3(d.x, 0, d.z).normalized()
	t.apply_central_force(pull * t.mass * 14.0)
	var v := t.linear_velocity
	t.linear_velocity = v * (1.0 - 0.9 * dt)
	# feixe em zigue-zague entre os dois
	_beam.visible = true
	var im := _beam.mesh as ImmediateMesh
	im.clear_surfaces()
	var a: Vector3 = car.global_position + Vector3.UP * 2.0
	var b: Vector3 = t.global_position + Vector3.UP * 0.8
	var cam_f: Vector3 = -game.cam.global_basis.z
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = [a]
	for i in range(1, 8):
		pts.append(a.lerp(b, i / 8.0) + Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)))
	pts.append(b)
	for i in pts.size() - 1:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var n := (p1 - p0).cross(cam_f).normalized() * 0.28
		for vv in [p0 - n, p0 + n, p1 + n, p0 - n, p1 + n, p1 - n]:
			im.surface_set_color(Color(0.5, 0.8, 1.0, 0.9))
			im.surface_add_vertex(vv)
	im.surface_end()


func _spikewall(t: Car) -> void:
	var a := _predict(t, 1.6)
	var tr: Track = game.track
	var gap := randf_range(-tr.HALF + 3.5, tr.HALF - 3.5)
	# aviso: faixa vermelha atravessando a pista inteira, a brecha fica sem pregos
	var h: Dictionary = w.hazard("spikewall", car, a.pos, tr.HALF + 1.0, 1.4, 4.5,
		{"n": a.up, "fwd": a.tan, "rz": 1.2, "gap": -gap, "col": Color(1.0, 0.15, 0.15)})
	var deco := Node3D.new()
	w.add_child(deco)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.82, 0.86)
	mat.metallic = 1.0
	mat.roughness = 0.25
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.16
	cm.height = 0.55
	cm.radial_segments = 6
	var lf: Vector3 = a.left
	var x := -tr.HALF
	while x <= tr.HALF:
		if absf(x - gap) > 2.6:
			for k in 2:
				var s := MeshInstance3D.new()
				s.mesh = cm
				s.material_override = mat
				deco.add_child(s)
				s.global_position = (a.pos as Vector3) + lf * x + (a.tan as Vector3) * (k * 0.8 - 0.4) + (a.up as Vector3) * 0.2
		x += 0.9
	# a brecha ganha cones verdes de sinalização
	for sgn: float in [-1.0, 1.0]:
		var cone := game.lib.get_node("prop_cone").duplicate() as Node3D
		deco.add_child(cone)
		cone.global_position = (a.pos as Vector3) + lf * (gap + sgn * 2.6)
	deco.visible = false
	h.deco = deco
	get_tree().create_timer(1.4, false).timeout.connect(func(): if is_instance_valid(deco): deco.visible = true)
	_warn("BLOQUEIO À FRENTE! PROCURE A BRECHA")


# ------------------------------------------------------------------ CROCODILO
func _mud(t: Car) -> void:
	for i in 3:
		var a := _predict(t, 0.8 + i * 0.45, randf_range(-6.0, 6.0))
		w.hazard("mud", car, a.pos, 4.0, 0.9, 6.0, {"n": a.up, "fwd": a.tan, "rz": 4.0, "col": Color(0.5, 0.33, 0.12)})
	_warn("LAMA! DESVIE DAS POÇAS")


func _lunge(t: Car) -> void:
	# marca a faixa entre o chefe e você; 0,8 s depois ele dá o bote nela
	var tr: Track = game.track
	var a := tr.at(t.s_track + 6.0, t.lat)
	w.hazard("lane", car, a.pos, 3.0, 0.8, 0.6, {"n": a.up, "fwd": a.tan, "rz": 9.0, "col": Color(1.0, 0.5, 0.1)})
	_warn("BOTE! SAIA DA FAIXA")


# ------------------------------------------------------------------ AVALANCHE
func _snowballs(t: Car) -> void:
	# 3 bolas descem pela pista na sua direção, deixando UMA faixa livre
	var tr: Track = game.track
	var lanes := [-tr.HALF * 0.66, 0.0, tr.HALF * 0.66]
	var free := randi() % 3
	for i in 3:
		if i == free:
			continue
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 2.2
		sm.height = 4.4
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.97, 1.0)
		m.roughness = 0.85
		mi.material_override = m
		w.add_child(mi)
		balls.append({"node": mi, "s": car.s_track - car.sp.len, "lat": float(lanes[i]), "t": 0.0, "spin": 0.0})
	# aviso: as duas faixas ocupadas acendem logo à sua frente
	for i in 3:
		if i == free:
			continue
		var a := tr.at(t.s_track + 25.0, float(lanes[i]))
		w.hazard("lane", null, a.pos, tr.HALF * 0.3, 1.2, 0.1, {"n": a.up, "fwd": a.tan, "rz": 14.0, "col": Color(0.6, 0.85, 1.0)})
	_warn("BOLAS DE NEVE! FIQUE NA FAIXA LIVRE")


func _balls_step(dt: float) -> void:
	var tr: Track = game.track
	for i in range(balls.size() - 1, -1, -1):
		var b: Dictionary = balls[i]
		b.t += dt
		b.s = float(b.s) - 22.0 * dt   # rola contra o sentido da corrida
		var a := tr.at(b.s, b.lat)
		var mi: MeshInstance3D = b.node
		mi.global_position = (a.pos as Vector3) + (a.up as Vector3) * 2.2
		b.spin += 22.0 * dt / 2.2
		mi.rotation = Vector3(-float(b.spin), 0, 0)
		var hit := false
		for c in game.cars:
			if c == car or c.wrecked:
				continue
			if c.global_position.distance_to(mi.global_position) < 3.4:
				c.apply_damage(24.0, mi.global_position, car)
				c.apply_central_impulse(((c.global_position - mi.global_position).normalized() + Vector3.UP * 0.8).normalized() * c.mass * 10.0)
				c.stun = maxf(c.stun, 0.5)
				hit = true
		if hit or b.t > 7.0:
			if game._on_screen(mi.global_position):
				game.fx.burst("dust", mi.global_position)
				game.fx.burst("smoke", mi.global_position)
				game.sfx.play("crash", -6.0, 1.3)
			mi.queue_free()
			balls.remove_at(i)


func _ice(t: Car) -> void:
	var a := _predict(t, 1.3)
	w.hazard("ice", car, a.pos, game.track.HALF + 1.0, 1.0, 6.0, {"n": a.up, "fwd": a.tan, "rz": 9.0, "col": Color(0.6, 0.9, 1.0)})
	_warn("GELO À FRENTE! NÃO ACELERE NA CURVA")


# ------------------------------------------------------------------ BLACKOUT
func _emp() -> void:
	w.hazard("emp", car, car.global_position, 22.0, 1.0, 0.1, {"n": Vector3.UP, "fwd": car.global_transform.basis.z, "col": Color(0.4, 0.8, 1.0)})
	_warn("PULSO EMP! SE AFASTE DELE")


func _lasers(t: Car) -> void:
	var tr: Track = game.track
	for k in 2:
		var a := tr.at(t.s_track + 45.0 + k * 35.0, 0.0)
		var h: Dictionary = w.hazard("laser", car, a.pos, tr.HALF + 1.0, 1.0, 6.0, {"n": a.up, "fwd": a.tan, "rz": 1.0, "col": Color(1.0, 0.2, 0.3)})
		# postes e o feixe (aceso só quando o portão está ligado)
		var deco := Node3D.new()
		w.add_child(deco)
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.1, 0.1, 0.14)
		pm.metallic = 0.6
		for sgn: float in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.6, 3.2, 0.6)
			post.mesh = bm
			post.material_override = pm
			deco.add_child(post)
			post.global_position = (a.pos as Vector3) + (a.left as Vector3) * sgn * (tr.HALF + 1.6) + (a.up as Vector3) * 1.6
		var beam := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3((tr.HALF + 1.6) * 2.0, 0.18, 0.18)
		beam.mesh = bb
		beam.material_override = w._add_mat(Color(1.0, 0.15, 0.25), 3.5)
		deco.add_child(beam)
		beam.global_transform = Transform3D(Basis(a.left, a.up, a.left.cross(a.up)), (a.pos as Vector3) + (a.up as Vector3) * 1.0)
		h.deco = deco
		h.beam = beam
	_warn("PORTÕES LASER! PASSE QUANDO APAGAREM")


# ------------------------------------------------------------------ IMPERADOR
func _meteors(t: Car) -> void:
	for i in 4:
		var a := _predict(t, 0.9 + i * 0.35, randf_range(-5.0, 5.0))
		w.hazard("meteor", car, a.pos, 4.2, 1.3 + i * 0.12, 0.3, {"n": a.up, "fwd": a.tan, "col": Color(1.0, 0.35, 0.05)})
	_warn("METEOROS! DESVIE DOS CÍRCULOS")


func _fire_step(dt: float) -> void:
	if fire_t <= 0.0:
		return
	fire_t -= dt
	fire_acc += dt
	if fire_acc < 0.22:
		return
	fire_acc = 0.0
	var tr: Track = game.track
	var a := tr.at(car.s_track - car.sp.len * 0.7, car.lat)
	w.hazard("fire", car, a.pos, 2.4, 0.15, 4.5, {"n": a.up, "fwd": a.tan, "rz": 2.2})
