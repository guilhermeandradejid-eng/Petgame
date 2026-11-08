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
	_magnet_step(dt)
	_fire_step(dt)


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
