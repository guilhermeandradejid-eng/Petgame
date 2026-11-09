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
var _mag_rings: Array = []
var _mag_t := 0.0
var balls: Array = []      # bolas de neve rolando (AVALANCHE)
# efeitos (peças de BossFx): estilhaços, meteoros caindo, bolotas de lama no ar, faixas de pregos, portões laser
var debris: Array = []
var meteors: Array = []
var blobs: Array = []
var strips: Array = []
var gates: Array = []


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
	if car != null:
		_step_fx(dt)
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
	game.sfx.play("warn", -4.0)
	if game.auto_test and "--bossshots" in OS.get_cmdline_user_args():
		# teste: fotos do aviso e do golpe de cada ataque
		var nm := "%s_%02d" % [car.kind, int(game.race_t)]
		for dl: float in [0.45, 1.35]:
			get_tree().create_timer(dl, false).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png("user://boss_%s_%.2f.png" % [nm, dl]))


# ------------------------------------------------------------------ BRUTUS
func _quake(t: Car) -> void:
	var a := _predict(t, 1.0)
	w.hazard("quake", car, a.pos, 9.0, 1.0, 0.9, {"n": a.up, "fwd": a.tan, "col": Color(1.0, 0.45, 0.1)})
	var qp: Vector3 = a.pos
	get_tree().create_timer(1.0, false).timeout.connect(func():
		if not game._on_screen(qp):
			return
		_debris("rock", qp, 12, 13.0)
		for k in 5:
			var ang := TAU * k / 5.0
			game.fx.burst("dust", qp + Vector3(cos(ang), 0.3, sin(ang)) * 5.5)
		game.fx.scorch(qp, 7.0))
	car.juice_squash(1.8)
	_warn("TREMOR! SAIA DO CÍRCULO")


func _barrels() -> void:
	var b := car.global_transform.basis
	for i in 3:
		var side := float(i - 1)
		var p: Vector3 = car.global_position - b.z * (car.sp.len * 0.55 + 1.5) + b.x * side * 2.6 + b.y * 1.2
		var v: Vector3 = car.linear_velocity * 0.25 - b.z * 11.0 + b.x * side * 3.5
		w.launch_barrel(car, p, v, b.y)
	game.sfx.play("deploy", -2.0, 0.6)
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
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.vertex_color_use_as_albedo = true
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_beam.material_override = bm
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.add_child(_beam)
		for i in 4:
			var r := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.55
			tm.outer_radius = 0.7
			tm.rings = 24
			tm.ring_segments = 6
			r.mesh = tm
			r.material_override = BossFx.glow_mat(Color(0.45, 0.75, 1.0), 4.0)
			r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			w.add_child(r)
			_mag_rings.append(r)


func _magnet_off() -> void:
	magnet_t = 0.0
	if _beam:
		_beam.visible = false
	for r in _mag_rings:
		(r as Node3D).visible = false


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
	# feixe: três fios em hélice girando em volta de um núcleo, e anéis de força correndo de você para o chefe
	_mag_t += dt
	_beam.visible = true
	var im := _beam.mesh as ImmediateMesh
	im.clear_surfaces()
	var a: Vector3 = car.global_position + Vector3.UP * 2.0
	var b: Vector3 = t.global_position + Vector3.UP * 0.8
	var ax := (b - a).normalized()
	var p1v := ax.cross(Vector3.UP).normalized()
	if p1v.length() < 0.1:
		p1v = Vector3.RIGHT
	var p2v := ax.cross(p1v).normalized()
	var cam_f: Vector3 = -game.cam.global_basis.z
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := 24
	for strand in 4:
		var pts: Array = []
		for i in N + 1:
			var u := float(i) / N
			var env := sin(u * PI)
			var off := Vector3.ZERO
			if strand > 0:
				var ph := float(strand) * TAU / 3.0 + _mag_t * 9.0 + u * TAU * 2.5
				off = (p1v * cos(ph) + p2v * sin(ph)) * 0.55 * env
			off += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.06 * env
			pts.append(a.lerp(b, u) + off)
		var wdt := 0.09 if strand == 0 else 0.07
		var cc := Color(0.85, 0.95, 1.0, 0.95) if strand == 0 else Color(0.35, 0.65, 1.0, 0.8)
		for i in N:
			var q0: Vector3 = pts[i]
			var q1: Vector3 = pts[i + 1]
			var n := (q1 - q0).cross(cam_f).normalized() * wdt
			for vv in [q0 - n, q0 + n, q1 + n, q0 - n, q1 + n, q1 - n]:
				im.surface_set_color(cc)
				im.surface_add_vertex(vv)
	im.surface_end()
	var basis := Basis(p1v, p2v, ax).orthonormalized() * Basis(Vector3.RIGHT, PI * 0.5)
	for i in _mag_rings.size():
		var r: MeshInstance3D = _mag_rings[i]
		var u := fmod(_mag_t * 0.9 + float(i) / _mag_rings.size(), 1.0)
		r.visible = true
		var sc := 0.4 + 0.8 * sin(u * PI)
		r.global_transform = Transform3D(basis.scaled(Vector3(sc, sc, sc)), b.lerp(a, u))
	if randf() < dt * 6.0 and game._on_screen(b):
		game.fx.sparks(b, -ax, 0.4)


func _spikewall(t: Car) -> void:
	var a := _predict(t, 1.6)
	var tr: Track = game.track
	var gap := randf_range(-tr.HALF + 3.5, tr.HALF - 3.5)
	# aviso: faixa vermelha atravessando a pista inteira, a brecha fica sem pregos
	var h: Dictionary = w.hazard("spikewall", car, a.pos, tr.HALF + 1.0, 1.4, 4.5,
		{"n": a.up, "fwd": a.tan, "rz": 1.2, "gap": -gap, "col": Color(1.0, 0.15, 0.15)})
	var deco := Node3D.new()
	w.add_child(deco)
	var lf: Vector3 = a.left
	var up: Vector3 = a.up
	# faixa de pregos de polícia: placas sanfonadas com pontas, desenrola de um lado da pista até o outro
	var sd := BossFx.spike_strip(tr.HALF, gap, 2.6)
	deco.add_child(sd.root)
	(sd.root as Node3D).global_transform = Transform3D(Basis(lf, up, lf.cross(up)).orthonormalized(), (a.pos as Vector3) + up * 0.02)
	var from_left := randf() < 0.5
	BossFx.spike_strip_set(sd, 0.0, from_left)
	# a brecha ganha cones de sinalização
	for sgn: float in [-1.0, 1.0]:
		var cone := game.lib.get_node("prop_cone").duplicate() as Node3D
		deco.add_child(cone)
		cone.global_position = (a.pos as Vector3) + lf * (gap + sgn * 2.6)
		cone.visible = false
	h.deco = deco
	strips.append({"h": h, "d": sd, "t": 0.0, "left": from_left, "deco": deco, "pos": a.pos, "lf": lf, "sparked": false})
	_warn("BLOQUEIO À FRENTE! PROCURE A BRECHA")


# ------------------------------------------------------------------ CROCODILO
func _mud(t: Car) -> void:
	var mouth: Vector3 = car.global_position + car.global_transform.basis.z * car.sp.len * 0.55 + Vector3.UP * 1.6
	for i in 3:
		var a := _predict(t, 0.8 + i * 0.45, randf_range(-6.0, 6.0))
		w.hazard("mud", car, a.pos, 4.0, 0.9, 6.0, {"n": a.up, "fwd": a.tan, "rz": 4.0, "col": Color(0.5, 0.33, 0.12)})
		var bl := BossFx.mud_blob(game.fx)
		w.add_child(bl)
		bl.global_position = mouth
		blobs.append({"node": bl, "from": mouth, "to": a.pos, "t": 0.0, "dur": 0.9, "peak": 6.0 + i * 1.5})
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
		var sb := BossFx.snowball(game.fx, 2.2)
		w.add_child(sb.root)
		balls.append({"node": sb.root, "ball": sb.ball, "s": car.s_track - car.sp.len, "lat": float(lanes[i]), "t": 0.0, "bob": randf() * TAU})
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
		var mi: Node3D = b.node
		# rola de verdade: gira em volta do eixo perpendicular ao movimento e quica de leve nos torrões
		b.bob = float(b.bob) + dt * 9.0
		mi.global_position = (a.pos as Vector3) + (a.up as Vector3) * (2.2 + absf(sin(float(b.bob))) * 0.18)
		var axis := (a.up as Vector3).cross(-(a.tan as Vector3)).normalized()
		var ball: Node3D = b.ball
		ball.basis = (Basis(axis, 22.0 * dt / 2.2) * ball.basis).orthonormalized()
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
				game.fx.burst("smoke", mi.global_position)
				game.fx.burst("smoke", mi.global_position + Vector3.UP * 1.5)
				_debris("snow", mi.global_position, 10, 11.0)
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
	get_tree().create_timer(1.0, false).timeout.connect(func():
		if is_instance_valid(car) and not car.wrecked:
			game.fx.ring(car.global_position, Color(0.4, 0.8, 1.0, 1.0), 22.0)
			game.fx.sparkle(car.global_position + Vector3.UP * 2.0, Color(0.5, 0.9, 1.5))
			game.fx.hit_light(car.global_position + Vector3.UP * 3.0, Color(0.4, 0.8, 1.0), 6.0, 24.0, 0.4))
	_warn("PULSO EMP! SE AFASTE DELE")


func _lasers(t: Car) -> void:
	var tr: Track = game.track
	for k in 2:
		var a := tr.at(t.s_track + 45.0 + k * 35.0, 0.0)
		var h: Dictionary = w.hazard("laser", car, a.pos, tr.HALF + 1.0, 1.0, 6.0, {"n": a.up, "fwd": a.tan, "rz": 1.0, "col": Color(1.0, 0.2, 0.3)})
		# dois postes emissores que sobem do chão e o feixe entre eles (aceso só com o portão ligado)
		var deco := Node3D.new()
		w.add_child(deco)
		var bas := Basis(a.left, a.up, (a.left as Vector3).cross(a.up)).orthonormalized()
		var emits: Array = []
		var pylons: Array = []
		for sgn: float in [-1.0, 1.0]:
			var py := BossFx.laser_pylon(1.0)
			deco.add_child(py.root)
			(py.root as Node3D).global_transform = Transform3D(bas, (a.pos as Vector3) + (a.left as Vector3) * sgn * (tr.HALF + 1.6))
			(py.root as Node3D).scale = Vector3(1, 0.01, 1)
			emits.append(py.emit)
			emits.append(py.top)
			pylons.append(py.root)
		var beam := BossFx.laser_beam((tr.HALF + 1.6) * 2.0)
		deco.add_child(beam)
		beam.global_transform = Transform3D(bas, (a.pos as Vector3) + (a.up as Vector3) * 1.0)
		beam.visible = false
		h.deco = deco
		h.beam = beam
		gates.append({"h": h, "emits": emits, "pylons": pylons, "t": 0.0, "ends": [(a.pos as Vector3) + (a.left as Vector3) * (tr.HALF + 1.2) + (a.up as Vector3), (a.pos as Vector3) - (a.left as Vector3) * (tr.HALF + 1.2) + (a.up as Vector3)]})
	_warn("PORTÕES LASER! PASSE QUANDO APAGAREM")


# ------------------------------------------------------------------ IMPERADOR
func _meteors(t: Car) -> void:
	for i in 4:
		var a := _predict(t, 0.9 + i * 0.35, randf_range(-5.0, 5.0))
		var dl := 1.3 + i * 0.12
		w.hazard("meteor", car, a.pos, 4.2, dl, 0.5, {"n": a.up, "fwd": a.tan, "col": Color(1.0, 0.35, 0.05)})
		var mt := BossFx.meteor(game.fx)
		w.add_child(mt)
		var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 16.0
		var from: Vector3 = (a.pos as Vector3) + Vector3.UP * 42.0 + side
		mt.global_position = from
		meteors.append({"node": mt, "from": from, "to": a.pos, "t": 0.0, "dur": dl, "spin": Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))})
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
	var h: Dictionary = w.hazard("fire", car, a.pos, 2.4, 0.15, 4.5, {"n": a.up, "fwd": a.tan, "rz": 2.2})
	if game._on_screen(a.pos):
		var fl := BossFx.trail(game.fx, true, 9, 0.6, 1.6, 0.5, [Color(4, 3, 1.6, 0), Color(3.4, 1.4, 0.3, 1), Color(1.4, 0.3, 0.05, 0.0)], [0.0, 0.2, 1.0], 3.0, Vector3(0, 5, 0), 1.0)
		fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		fl.emission_box_extents = Vector3(2.0, 0.1, 1.8)
		fl.spread = 18.0
		w.add_child(fl)
		fl.global_position = (a.pos as Vector3) + (a.up as Vector3) * 0.3
		h.deco = fl
		get_tree().create_timer(4.0, false).timeout.connect(func(): if is_instance_valid(fl): fl.emitting = false)


# ------------------------------------------------------------------ efeitos (passo a passo)
func _debris(kind: String, pos: Vector3, n: int, speed: float) -> void:
	if not game._on_screen(pos):
		return
	for i in n:
		var mi := BossFx.chunk(kind)
		w.add_child(mi)
		mi.global_position = pos + Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1))
		var v := Vector3(randf_range(-1, 1), randf_range(0.7, 1.6), randf_range(-1, 1)).normalized() * speed * randf_range(0.5, 1.15)
		debris.append({"node": mi, "vel": v, "t": 0.0, "spin": Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)), "life": randf_range(0.8, 1.3)})


func _step_fx(dt: float) -> void:
	# estilhaços: balística simples, encolhem no fim
	for i in range(debris.size() - 1, -1, -1):
		var d: Dictionary = debris[i]
		var mi: Node3D = d.node
		d.t = float(d.t) + dt
		d.vel = (d.vel as Vector3) + Vector3(0, -26.0 * dt, 0)
		mi.global_position += (d.vel as Vector3) * dt
		mi.rotation += (d.spin as Vector3) * dt
		var life: float = d.life
		mi.scale = Vector3.ONE * clampf(1.0 - (float(d.t) - life * 0.6) / (life * 0.4), 0.0, 1.0)
		if float(d.t) > life:
			mi.queue_free()
			debris.remove_at(i)
	# meteoros: descem acelerando em diagonal e chegam junto com o golpe
	for i in range(meteors.size() - 1, -1, -1):
		var m: Dictionary = meteors[i]
		var nd: Node3D = m.node
		m.t = float(m.t) + dt
		var u := clampf(float(m.t) / float(m.dur), 0.0, 1.0)
		nd.global_position = (m.from as Vector3).lerp(m.to, u * u)
		var rk := nd.get_node("Rock") as Node3D
		rk.rotation += (m.spin as Vector3) * dt
		if u >= 1.0:
			_debris("lava", m.to, 8, 12.0)
			nd.queue_free()
			meteors.remove_at(i)
	# lama no ar: arco do focinho até a poça; ao cair, espirra
	for i in range(blobs.size() - 1, -1, -1):
		var b: Dictionary = blobs[i]
		var nd: Node3D = b.node
		b.t = float(b.t) + dt
		var u := clampf(float(b.t) / float(b.dur), 0.0, 1.0)
		nd.global_position = (b.from as Vector3).lerp(b.to, u) + Vector3.UP * (4.0 * float(b.peak) * u * (1.0 - u))
		(nd.get_node("Blob") as Node3D).scale = Vector3(1.0 - u * 0.2, 1.0 + u * 0.3, 1.0 - u * 0.2)
		if u >= 1.0:
			if game._on_screen(b.to):
				_debris("mud", (b.to as Vector3) + Vector3.UP * 0.4, 7, 8.0)
				game.fx.burst("dust", b.to)
			nd.queue_free()
			blobs.remove_at(i)
	# faixas de pregos: aparecem quando o aviso arma e desenrolam em 0,45 s com faíscas
	for i in range(strips.size() - 1, -1, -1):
		var st: Dictionary = strips[i]
		if not is_instance_valid(st.deco):
			strips.remove_at(i)
			continue
		st.t = float(st.t) + dt
		var u := clampf((float(st.t) - 1.4) / 0.45, 0.0, 1.0)
		if u > 0.0:
			BossFx.spike_strip_set(st.d, u, bool(st.left))
			for ch in (st.deco as Node).get_children():
				if ch != (st.d as Dictionary).root:
					(ch as Node3D).visible = true
			if not bool(st.sparked) and game._on_screen(st.pos):
				st.sparked = true
				for k in 3:
					game.fx.sparks((st.pos as Vector3) + (st.lf as Vector3) * randf_range(-6.0, 6.0) + Vector3.UP * 0.3, Vector3.UP, 0.6)
		if u >= 1.0:
			strips.remove_at(i)
	# portões laser: postes sobem do chão; emissores acendem com o feixe e piscam antes de ligar
	for i in range(gates.size() - 1, -1, -1):
		var g: Dictionary = gates[i]
		var h: Dictionary = g.h
		if not is_instance_valid(h.get("deco")):
			gates.remove_at(i)
			continue
		g.t = float(g.t) + dt
		var rise := clampf(float(g.t) / 0.4, 0.0, 1.0)
		rise = 1.0 - pow(1.0 - rise, 3.0)
		for py in g.pylons:
			(py as Node3D).scale = Vector3(1, maxf(0.01, rise), 1)
		var tt := float(h.t) - float(h.delay)
		var on := tt >= 0.0 and fmod(tt, 2.4) < 1.2
		var soon := tt < 0.0 or fmod(tt, 2.4) > 2.05
		var e := 5.0 if on else (1.0 + 2.5 * absf(sin(float(g.t) * 30.0)) if soon else 0.5)
		for em in g.emits:
			(em as StandardMaterial3D).emission_energy_multiplier = e
		if on and randf() < dt * 5.0:
			for p in g.ends:
				if game._on_screen(p):
					game.fx.sparks(p, Vector3.UP, 0.25)
