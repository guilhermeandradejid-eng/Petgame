extends RefCounted
# Clipe "Eu preparo o chão, você detona": Bento joga a cal (o chão molha pelo rejunte), Tia Lamparina
# gira a lamparina e lança a faísca, a Condução corre pelas juntas (reta na junta corrida, em
# zigue-zague na amarração), as Lascas levam o choque (hit-stop local, negativo, estilhaço) e o
# Bento, untado, fica ileso (Isolante). Tudo por quadro, determinístico (Movie Maker, 60 fps).

var m: Node3D
var vfx: Object
var cena: Object
var lamp: Object
var bento: Object
var lascas: Array = []
var T := 0.0
var trauma := 0.0
var cam_base: Transform3D
var rng := RandomNumberGenerator.new()
var dyn: Array = []           # malhas refeitas a cada quadro (raios, rastros)
var tip_hist: Array = []      # posições da lanterna
var pole_hist: Array = []     # (base, ponta) do cabo
var wet_arr := PackedFloat32Array()
var shock_res := {}
var events := {}
var spark: MeshInstance3D
var spark_shadow: MeshInstance3D
var stars: Array = []         # [nó, nascimento, vida]
var tele_l1: MeshInstance3D
var cal_drops: Array = []
var bursts: Array = []        # [estilhaços, nascimento]
var cracks: Array = []        # [nó, nascimento, duração]
var puffs: Array = []         # [nó, nascimento, duração]
var ghosts: Array = []        # malhas-fantasma da lanterna (smear)
var flash_until := {}         # figura -> T até quando fica no lampejo branco
var kick := 0                 # quadros de tremor seco de 3 px na soltura

const T_BALDE := 0.20        # Bento começa a jogar a cal
const T_SOLTA_CAL := 0.20 + 25.0 / 60.0
const T_LAMP := 1.18         # Lamparina começa o golpe
const T_SOLTA := 1.18 + 17.0 / 60.0
const T_VOO := 0.42
const T_IMPACTO := 1.18 + 17.0 / 60.0 + 0.42
const BP := Vector3(-0.9, 0, -2.4)
const LP := Vector3(-3.75, 0, -3.05)
const IMPACT := Vector3(-2.15, 0, -1.95)
const SPLASH := Vector3(-0.35, 0, -1.55)

func _init(main_node: Node3D) -> void:
	m = main_node

func setup() -> void:
	rng.seed = 5
	m._scene_base()
	cena = m.cena
	vfx = load("res://vfx.gd").new(m, Callable(m, "_sm"))
	m.vfx = vfx
	m._beauty_env(RenderingServer.get_current_rendering_method() != "gl_compatibility")
	m._combat_cam(Vector3(-1.0, 0.5, -2.25), 7.6, 40.0, 0.0)
	cam_base = m.cam.global_transform
	# adereços ao fundo
	m._prop("porta", Vector3(5.0, 0, -5.97))
	m._prop("barril", Vector3(-5.9, 0, -4.9), 20)
	m._prop("caixote", Vector3(-3.6, 0, -5.55), 8, 0.85)
	# heróis
	lamp = m.load_fig("lamparina")
	lamp.root.position = LP
	lamp.base_pos = LP
	lamp.root.rotation.y = deg_to_rad(m._yaw_to(LP, IMPACT) - 15.0)
	lamp.play("idle", 0.0)
	bento = m.load_fig("bento")
	bento.root.position = BP
	bento.base_pos = BP
	bento.root.rotation.y = deg_to_rad(m._yaw_to(BP, SPLASH) - 10.0)
	bento.play("idle", 0.0)
	bento.set_param("oil", 1.0)
	bento.face({"eye_open": 1.0, "mouth_curve": 0.3})
	lamp.face({"eye_open": 1.0, "mouth_curve": 0.5})
	vfx.decal(0, LP, Vector2(1.25, 1.25), {"col": Color("#E43C9E"), "symbol": 0})
	vfx.decal(0, BP, Vector2(1.0, 1.0), {"col": Color("#23C4DB"), "symbol": 1})
	for p in [Vector3(1.0, 0, -2.75), Vector3(0.45, 0, -1.35), Vector3(1.6, 0, -1.85)]:
		var l = m.load_fig("lasca")
		l.root.position = p
		l.base_pos = p
		l.root.rotation.y = deg_to_rad(m._yaw_to(p, BP))
		l.play("pulo", rng.randf() * 0.5)
		l.set_meta("hit_t", -1.0)
		l.set_meta("kb", Vector3.ZERO)
		lascas.append(l)
	for f in m.figs:
		if f.name in ["lamparina", "bento", "lasca"]:
			var sz := 0.85 if f.name == "lasca" else 1.05
			var d = vfx.decal(3, f.base_pos, Vector2(sz, sz * 0.8), {"alpha": 0.5})
			f.set_meta("shadow", d)
	# poça: a cal chega a cada azulejo pelo rejunte, a partir do ponto onde cai
	cena.puddles = [[-0.5, -2.2, 2.5, 1.55, 1.0], [1.2, -2.1, 1.1, 1.0, 1.0], [-2.05, -1.95, 0.9, 0.8, 1.0], [0.6, -1.3, 0.9, 0.6, 1.0]]
	shock_res = cena.conduct(Vector2(IMPACT.x, IMPACT.z), [Vector2(1.0, -2.75), Vector2(0.45, -1.35), Vector2(1.6, -1.85), Vector2(BP.x, BP.z), Vector2(-0.2, -3.3)], 7.5, 3)
	wet_arr.resize(cena.NX * cena.NZ)
	for j in cena.NZ:
		for i in cena.NX:
			var x: float = cena.X0 + (i + 0.5) * cena.T
			var z: float = cena.Z0 + (j + 0.5) * cena.T
			var d := Vector2(x - SPLASH.x, z - SPLASH.z).length()
			wet_arr[j * cena.NX + i] = T_SOLTA_CAL + 0.22 + d / 3.2 + rng.randf() * 0.05
	_update_wet()
	cena.floor_mat.set_shader_parameter("shock_t", -10.0)
	# telegrafia da Lasca 1 (retângulo que se fecha em direção ao Bento)
	var l1 = lascas[0]
	var dir: Vector3 = (BP - l1.base_pos).normalized()
	tele_l1 = vfx.decal(2, l1.base_pos + dir * 0.8, Vector2(0.6, 1.3), {"col": Color("#C42036"), "progress": 0.0, "aspect": 0.46, "alpha": 0.0}, atan2(dir.x, dir.z))
	# faísca em voo (miolo quente com arcos curtos, não estrela)
	spark = vfx.spark(Vector3(0, -10, 0), 0.34, {"time": 0.0})
	# malhas-fantasma da lanterna para o smear (2 quadros ao longo do arco)
	for k in 3:
		var g := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.12, 0.2, 0.12)
		g.mesh = bx
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.albedo_color = Color(0.953, 0.776, 0.192, 0.55 - k * 0.15)
		gm.emission_enabled = true
		gm.emission = Color(0.953, 0.776, 0.192) * 0.8
		g.material_override = gm
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visible = false
		m.add_child(g)
		ghosts.append(g)
	spark_shadow = vfx.decal(3, Vector3(0, -10, 0), Vector2(0.35, 0.28), {"alpha": 0.45})

func _update_wet() -> void:
	var img: Image = cena.state_img
	for j in cena.NZ:
		for i in cena.NX:
			var x: float = cena.X0 + (i + 0.5) * cena.T
			var z: float = cena.Z0 + (j + 0.5) * cena.T
			var full: float = cena.blob(cena.puddles, x, z)
			var a: float = wet_arr[j * cena.NX + i]
			var w: float = full * clamp((T - a) / 0.12, 0.0, 1.0)
			var c := img.get_pixel(i, j)
			c.r = w
			img.set_pixel(i, j, c)
	cena.state_tex.update(img)

func _clear_dyn() -> void:
	for n in dyn:
		n.queue_free()
	dyn.clear()

func _ribbon(pts: PackedVector3Array, w0: float, w1: float, params := {}, inten := 1.0) -> void:
	if pts.size() < 2:
		return
	dyn.append(vfx.ribbon(pts, w0, w1, m.cam.global_position, params, inten))

func _star(pos: Vector3, size: float, life_s: float, params := {}) -> void:
	var s = vfx.star(pos, size, params)
	stars.append([s, T, life_s])

func _hit(f: Object, frames: int, inv := true) -> void:
	# quadro 0: lampejo branco na silhueta do alvo; quadros 1 e 2: negativo de Faísca
	f.hold = frames
	f.shake = 0.05
	f.set_param("flash", 1.0)
	flash_until[f] = T + 0.5 / 60.0
	if inv:
		f.set_meta("inv_from", T + 0.5 / 60.0)
		f.set_meta("inv_until", T + 2.5 / 60.0)

func _crack(pos: Vector3, size: float, dur: float, params: Dictionary, ground := false) -> void:
	var c = vfx.crack(pos, size, params, ground)
	cracks.append([c, T, dur])

func _puff(pos: Vector3, size: float, dur: float, seed: float) -> void:
	var p = vfx.puff(pos, size, {"seed": seed})
	puffs.append([p, T, dur])

func _burst(pos: Vector3, dir: Vector3, n: int, seed: int, params := {}, speed := 2.2, sz := 0.06) -> void:
	bursts.append([vfx.shards(pos, dir, n, seed, params, speed, sz), T])

func step(frame_i: int) -> void:
	T = (frame_i - 1) / 60.0
	var dt := 1.0 / 60.0
	_clear_dyn()
	# ---------------- Bento: joga a cal
	if T >= T_BALDE and not events.has("balde"):
		events["balde"] = true
		bento.play("balde", 0.0)
		bento.face({"eye_open": 0.6, "mouth_curve": -0.2, "brow": -0.4})
	if T >= T_SOLTA_CAL and not events.has("cal"):
		events["cal"] = true
		bento.face({"eye_open": 0.3, "mouth_open": 0.4, "mouth_curve": 0.3})
		var mouth: Vector3 = bento.bone_world("mola_balde").origin
		for k in 9:
			var tgt := SPLASH + Vector3(rng.randf_range(-1.3, 1.3), 0.0, rng.randf_range(-0.8, 0.8))
			cal_drops.append([mouth, tgt, T, 0.2 + rng.randf() * 0.12, rng.randf_range(0.5, 1.0)])
	for d in cal_drops:
		var u: float = (T - float(d[2])) / float(d[3])
		if u >= 0.0 and u <= 1.15:
			var pts := PackedVector3Array()
			for s in 6:
				var uu: float = clamp(u - s * 0.06, 0.0, 1.0)
				var p: Vector3 = (d[0] as Vector3).lerp(d[1], uu)
				p.y += 4.0 * float(d[4]) * uu * (1.0 - uu)
				pts.append(p)
			_ribbon(pts, 0.11, 0.04, {"col": Color("#F6F3EC"), "core": Color("#FFFFFF"), "edge": Color("#3F9C80"), "emit": 0.0}, 1.0)
		if u >= 1.0 and d.size() <= 5:
			d.append(true)
			_puff((d[1] as Vector3) + Vector3(0, 0.12, 0), 0.42, 0.45, float(cal_drops.find(d)))
	_update_wet()
	# ---------------- Lamparina: golpe e faísca
	if T >= T_LAMP and not events.has("lamp"):
		events["lamp"] = true
		lamp.play("lancar", 0.0)
		lamp.face({"eye_open": 0.12, "mouth_curve": -0.3, "brow": -0.7})
	if T >= T_SOLTA and not events.has("solta"):
		events["solta"] = true
		lamp.hold = 3
		lamp.face({"eye_open": 0.1, "mouth_open": 0.8, "mouth_curve": 0.5, "brow": -0.6})
		trauma = max(trauma, 0.25)
		var tip0: Vector3 = lamp.bone_world("mola_lanterna").origin
		events["spark_from"] = tip0
		kick = 3
		_burst(tip0, (IMPACT - LP).normalized(), 5, 77, {"hot": 1.0}, 1.4, 0.035)
	if lamp.anim == "lancar" and lamp.t > 0.0:
		var tip: Vector3 = lamp.bone_world("mola_lanterna").origin
		tip_hist.push_front(tip)
		var pb: Transform3D = lamp.bone_world("prop.R")
		pole_hist.push_front([pb.origin, tip])
		if tip_hist.size() > 10:
			tip_hist.pop_back()
			pole_hist.pop_back()
		var lt: float = lamp.t * 60.0
		# arco da lanterna (rastro da arma, 6 a 12 quadros) do antecipar ao fim do giro
		if lt > 14.0 and lt < 34.0 and tip_hist.size() > 3:
			var pts := PackedVector3Array()
			for k in min(7, tip_hist.size()):
				var p: Vector3 = tip_hist[k]
				if pts.size() > 0 and p.distance_to(pts[pts.size() - 1]) > 0.9:
					break
				pts.append(p)
			_ribbon(pts, 0.16, 0.02, {"col": Color("#F3C631"), "emit": 1.6, "seed": 4.0}, 0.9)
		# smear: 2 quadros com 3 fantasmas da lanterna ao longo do arco (entre a pose anterior e a atual)
		# e um traço fino de cabo que acompanha a curva; nada de leque pesado
		for g in ghosts:
			g.visible = false
		if lt > 14.5 and lt < 16.5 and tip_hist.size() > 3:
			for k in 3:
				var a0: Vector3 = tip_hist[k + 1]
				var a1: Vector3 = tip_hist[k]
				var gp: Vector3 = a1.lerp(a0, 0.5) + Vector3(0, -0.1, 0)
				ghosts[k].visible = true
				ghosts[k].position = gp
			var arcp := PackedVector3Array()
			for k in min(4, tip_hist.size()):
				var pb0: Array = pole_hist[k]
				arcp.append((pb0[0] as Vector3).lerp(pb0[1], 0.55))
			_ribbon(arcp, 0.05, 0.03, {"col": Color("#6E5646"), "core": Color("#A89472"), "edge": Color("#0D1029"), "emit": 0.0, "dash": 0.0, "seed": 1.0}, 1.0)
	if events.has("solta") and T < T_IMPACTO:
		var u := (T - T_SOLTA) / T_VOO
		var a: Vector3 = events["spark_from"]
		var p := a.lerp(IMPACT + Vector3(0, 0.05, 0), u)
		p.y += 4.0 * 1.0 * u * (1.0 - u)
		spark.position = p
		spark.material_override.set_shader_parameter("time", T)
		spark_shadow.position = Vector3(p.x, 0.012, p.z)
		var pts: PackedVector3Array = vfx.parabola(a, IMPACT + Vector3(0, 0.05, 0), 1.0, 24)
		var cut := PackedVector3Array()
		for i in pts.size():
			var ui: float = float(i) / (pts.size() - 1)
			if ui <= u and ui >= u - 0.45:
				cut.append(pts[i])
		cut.append(p)
		_ribbon(cut, 0.03, 0.1, {"dash": 6.0, "emit": 1.6, "seed": 3.0}, 0.9)
	# ---------------- impacto e Condução
	if T >= T_IMPACTO and not events.has("impacto"):
		events["impacto"] = true
		spark.position = Vector3(0, -10, 0)
		spark_shadow.position = Vector3(0, -10, 0)
		trauma = max(trauma, 0.7)
		# o azulejo racha onde a faísca cai; cacos do esmalte saltam
		_crack(IMPACT, 1.2, 0.7, {"seed": 1.3, "rays": 5.0, "glow": vfx.ELEM["faisca"]}, true)
		_burst(IMPACT + Vector3(0, 0.04, 0), Vector3.ZERO, 9, 5, {"bisque": Color("#D7B49C")}, 2.0, 0.07)
	if events.has("impacto"):
		var st := T - T_IMPACTO
		cena.floor_mat.set_shader_parameter("shock_t", st)
		# arcos na frente da onda (quadros de raio a 30 por segundo)
		var best: PackedFloat32Array = shock_res["best"]
		var r2 := RandomNumberGenerator.new()
		r2.seed = int(T * 30.0) + 17
		var front: Array = []
		for n in best.size():
			if best[n] < st and best[n] > st - 0.06:
				front.append(n)
		for k in min(7, front.size()):
			var n: int = front[r2.randi() % front.size()]
			var p := Vector3((n % 73 - 36) * 0.25, 0.02, (n / 73 - 48) * 0.125)
			var q := p + Vector3(r2.randf_range(-0.45, 0.45), 0.0, r2.randf_range(-0.3, 0.3))
			var mid := (p + q) * 0.5 + Vector3(0, r2.randf_range(0.15, 0.35), 0)
			var jag: PackedVector3Array = vfx.bolt_points(p, mid, 3, 0.06, r2)
			jag.append_array(vfx.bolt_points(mid, q, 3, 0.06, r2))
			_ribbon(jag, 0.035, 0.02, {"emit": 2.2, "seed": float(k)}, 0.95)
		# vítimas
		for l in lascas:
			var arr: float = cena.arrival_at(shock_res, Vector2(l.base_pos.x, l.base_pos.z))
			if st >= arr and float(l.get_meta("hit_t")) < 0.0:
				l.set_meta("hit_t", T)
				l.play("golpeado", 0.0)
				_hit(l, 5)
				trauma = min(1.0, trauma + 0.35)
				l.set_meta("kb", (l.base_pos - Vector3(IMPACT.x, 0, IMPACT.z)).normalized() * 1.6)
				l.set_param("lacre", 0.0)
				var top0: Vector3 = l.base_pos + Vector3(0, 0.5, 0)
				_crack(top0, 0.8, 0.45, {"seed": rng.randf() * 6.0, "rays": 6.0, "glow": vfx.ELEM["faisca"]})
				_burst(top0, (l.base_pos - IMPACT).normalized(), 8, 100 + lascas.find(l), {}, 2.4, 0.06)
				if l == lascas[0]:
					tele_l1.visible = false
			var ht: float = l.get_meta("hit_t")
			if ht >= 0.0 and T - ht < 0.32:
				var top: Vector3 = l.root.global_position + Vector3(0, 0.45, 0)
				for k in 2:
					var a2: Vector3 = l.root.global_position + Vector3(r2.randf_range(-0.3, 0.3), 0.02, r2.randf_range(-0.3, 0.3))
					_ribbon(vfx.bolt_points(a2, top, 4, 0.14, r2), 0.06, 0.03, {"emit": 2.4, "seed": float(k)}, 1.0)
		# Isolante: o choque chega no Bento e desvia; ele leva um susto e depois faz pose
		var ab: float = cena.arrival_at(shock_res, Vector2(BP.x, BP.z))
		if st >= ab and not events.has("isolado"):
			events["isolado"] = true
			bento.play("isolado", 0.0)
			bento.face({"eye_open": 1.4, "mouth_open": 0.5, "mouth_curve": -0.4, "brow": 0.8})
			bento.set_param("oil", 2.0)
		if events.has("isolado"):
			var it := st - ab
			if it < 0.5:
				for k in 4:
					var a0 := r2.randf() * TAU
					var pts := PackedVector3Array()
					for j in 9:
						var aa := a0 + j * 0.17
						var rr := 0.42 + 0.05 * sin(j * 1.3)
						pts.append(BP + Vector3(cos(aa) * rr, 0.05 + 0.3 * sin(j / 8.0 * PI) + r2.randf_range(-0.03, 0.03), sin(aa) * rr))
					_ribbon(pts, 0.03, 0.015, {"emit": 2.0, "seed": 9.0 + k}, 0.9)
			if it > 12.0 / 60.0 and not events.has("pouso"):
				events["pouso"] = true
				_puff(BP + Vector3(-0.25, 0.1, 0.1), 0.45, 0.5, 3.0)
				_puff(BP + Vector3(0.25, 0.1, 0.05), 0.4, 0.5, 4.0)
			if it > 0.3 and not events.has("smug"):
				events["smug"] = true
				bento.face({"eye_open": 0.18, "mouth_curve": 0.8, "mouth_open": 0.0, "brow": 0.5, "look": Vector2(-0.6, 0)})
				bento.set_param("oil", 1.0)
				lamp.face({"eye_open": 0.2, "mouth_curve": 0.9, "mouth_open": 0.2, "brow": 0.2})
	# telegrafia da Lasca 1: agacha, borda acende em vermelho-lacre, retângulo se fecha
	var l1 = lascas[0]
	if T >= 1.05 and float(l1.get_meta("hit_t")) < 0.0:
		if not events.has("tele"):
			events["tele"] = true
			l1.play("telegrafia", 0.0)
		var pr: float = clamp((T - 1.05) / 1.2, 0.0, 1.0)
		tele_l1.material_override.set_shader_parameter("progress", pr)
		tele_l1.material_override.set_shader_parameter("alpha", 1.0)
		l1.set_param("lacre", 1.0 if fmod(T * 6.0, 1.0) < 0.6 else 0.35)
	# ---------------- figuras: animação, hit-stop local, tremor, recuo
	for f in m.figs:
		if not f.has_meta("shadow") and f.name != "lamparina" and f.name != "bento" and f.name != "lasca":
			continue
		var spd := 1.0
		if f.name == "lasca" and f.anim == "pulo":
			f.t = fmod(f.t, 1.0)
		f.step(dt, spd)
		var off := Vector3.ZERO
		if f.hold > 0 and f.shake > 0.0:
			off.x = f.shake * (1.0 if (int(T * 60.0) % 2) == 0 else -1.0)
			f.shake *= 0.8
		if flash_until.has(f) and T > float(flash_until[f]):
			f.set_param("flash", 0.0)
			flash_until.erase(f)
			if f.has_meta("inv_from"):
				f.set_param("invert", 1.0)
		if f.name == "lasca" and float(f.get_meta("hit_t")) >= 0.0 and not f.has_meta("pousou") and f.t > 22.0 / 60.0:
			f.set_meta("pousou", true)
			_puff(f.root.position + Vector3(0, 0.08, 0), 0.38, 0.45, f.base_pos.x)
		if f.has_meta("inv_until") and T > float(f.get_meta("inv_until")):
			f.set_param("invert", 0.0)
			f.remove_meta("inv_until")
		if f.name == "lasca" and float(f.get_meta("hit_t")) >= 0.0 and f.hold == 0:
			var since: float = T - float(f.get_meta("hit_t")) - 5.0 / 60.0
			var kb: Vector3 = f.get_meta("kb")
			var dist: float = 1.0 - exp(-max(since, 0.0) * 6.0)
			f.root.position = f.base_pos + kb * 0.3 * dist + off
		else:
			f.root.position = f.base_pos + off
		f.spring_tick(dt)
		if f.has_meta("shadow"):
			var sd: Node3D = f.get_meta("shadow")
			sd.position = Vector3(f.root.position.x, 0.012, f.root.position.z)
	# estrelas de impacto (vida curta, abrem e somem)
	for s in stars.duplicate():
		var life: float = (T - float(s[1])) / float(s[2])
		if life > 1.0:
			s[0].queue_free()
			stars.erase(s)
		else:
			s[0].material_override.set_shader_parameter("life", floor(life * 10.0) / 10.0)
	for b in bursts:
		vfx.shards_at(b[0], T - float(b[1]))
	for c in cracks:
		var lf: float = (T - float(c[1])) / float(c[2])
		c[0].visible = lf <= 1.0
		# quadro 0 = lampejo (1 quadro só); depois a fenda abre em poses de 12 por segundo
		var age: float = T - float(c[1])
		c[0].material_override.set_shader_parameter("life", 0.0 if age < 0.5 / 60.0 else max(0.13, floor(lf * 12.0) / 12.0))
	for pf in puffs:
		var lf2: float = (T - float(pf[1])) / float(pf[2])
		pf[0].visible = lf2 <= 1.0
		pf[0].material_override.set_shader_parameter("life", lf2)
	# câmera: tremor por trauma (deslocamento = ruído × trauma²), também durante o hit-stop
	trauma = max(0.0, trauma - 1.6 * dt)
	var sh := trauma * trauma
	var tq := T * 60.0
	var ox := (sin(tq * 1.7) + sin(tq * 3.1 + 1.0) * 0.5) * 0.10 * sh
	var oy := (sin(tq * 2.3 + 2.0) + sin(tq * 4.3) * 0.5) * 0.07 * sh
	var rot := sin(tq * 2.9 + 0.5) * 0.012 * sh
	if kick > 0:
		# tremor seco de 3 px junto com o hit-stop de 3 quadros da soltura (720p, câmera a 7,6 m)
		var mpp := 2.0 * tan(deg_to_rad(m.cam.fov) * 0.5) * 7.6 / 720.0
		ox += (3.0 if kick % 2 == 1 else -3.0) * mpp
		kick -= 1
	var tr := cam_base
	tr.origin += tr.basis.x * ox + tr.basis.y * oy
	tr.basis = tr.basis * Basis(Vector3(0, 0, 1), rot)
	m.cam.global_transform = tr
	cena.floor_mat.set_shader_parameter("time", T)
	cena.sea_mat.set_shader_parameter("time", T)
	for f in m.figs:
		f.body.set_shader_parameter("time", T)
