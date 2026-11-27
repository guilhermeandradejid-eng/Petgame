extends Node3D
# Efeitos da Tolda Viva. Todo efeito é um objeto de oficina: serragem e maravalha, gotas e rastro de
# Tinta, cacos de papel machê, papel de seda, poeira de palco. Simulação determinística a 60 Hz.
const Boneco = preload("res://boneco.gd")

var cam: Camera3D
var dt := 1.0 / 60.0
var rng := RandomNumberGenerator.new()

# ------------------------------------------------------------------ partículas num só desenho
var P: Array = []   # dicts
var pmesh: ImmediateMesh
var pmi: MeshInstance3D
var pmat: ShaderMaterial
const PAL := [Color("#E4B98A"), Color("#A86E47"), Color("#3550D8"), Color("#F2E6C8"), Color("#D7C6A3"), Color("#E5337F"), Color("#2E7D22"), Color("#5B4232")]
# índices: 0 madeira (serragem), 1 madeira escura (maravalha), 2 anilina, 3 creme, 4 cortiça (poeira), 5 magenta, 6 folha, 7 tábua escura

func setup(c: Camera3D, seed_ := 1) -> void:
	cam = c
	rng.seed = seed_
	pmesh = ImmediateMesh.new()
	pmi = MeshInstance3D.new(); pmi.mesh = pmesh
	pmat = ShaderMaterial.new(); pmat.shader = Boneco.sh("grao")
	pmat.set_shader_parameter("pal", PAL)
	pmi.material_override = pmat
	pmi.extra_cull_margin = 50.0
	add_child(pmi)

func emit(pos: Vector3, vel: Vector3, size: float, forma: int, ci: int, life := 2.0, aspect := 1.0, grav := 9.8, drag := 1.5, stick := true) -> void:
	P.append({"p": pos, "v": vel, "s": size, "f": forma, "c": ci, "life": life, "age": 0.0, "asp": aspect, "g": grav, "drag": drag,
		"rot": rng.randf() * TAU, "spin": rng.randf_range(-14, 14), "seed": rng.randf() * 0.99, "stick": stick, "chao": false})

func _step_particles(ts: float) -> void:
	var h := dt * ts
	for q in P:
		q["age"] += h
		if q["chao"]:
			continue
		var v: Vector3 = q["v"]
		v.y -= q["g"] * h
		v *= exp(-q["drag"] * h)
		q["v"] = v
		q["p"] += v * h
		q["rot"] += q["spin"] * h
		if q["p"].y < 0.02 and q["v"].y < 0.0:
			if q["stick"]:
				q["p"].y = 0.015; q["chao"] = true
			else:
				q["p"].y = 0.02; q["v"] = Vector3(v.x * 0.4, -v.y * 0.3, v.z * 0.4)
	P = P.filter(func(q): return q["age"] < q["life"])

func _draw_particles() -> void:
	pmesh.clear_surfaces()
	if P.is_empty():
		return
	pmesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var cx := cam.global_basis.x; var cy := cam.global_basis.y
	for q in P:
		var fade: float = clamp((q["life"] - q["age"]) / 0.3, 0.0, 1.0)
		var s: float = q["s"] * fade
		if s <= 0.001:
			continue
		var ax: Vector3; var ay: Vector3
		if q["chao"]:
			ax = Vector3(cos(q["rot"]), 0, sin(q["rot"])); ay = Vector3(-sin(q["rot"]), 0, cos(q["rot"]))
		else:
			ax = cx * cos(q["rot"]) + cy * sin(q["rot"]); ay = -cx * sin(q["rot"]) + cy * cos(q["rot"])
		ax *= s * q["asp"]; ay *= s
		var p: Vector3 = q["p"]
		var uv2 := Vector2(float(q["f"]) + q["seed"], float(q["c"]))
		var cs := [p - ax - ay, p + ax - ay, p + ax + ay, p - ax + ay]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			pmesh.surface_set_uv(uvs[idx]); pmesh.surface_set_uv2(uv2); pmesh.surface_add_vertex(cs[idx])
	pmesh.surface_end()

# ------------------------------------------------------------------ rastro de Tinta (fita)
var fitas: Array = []

func nova_fita(cor_borda: Color) -> Dictionary:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new(); mi.mesh = im
	# v2: a borda é o mesmo azul 30% mais escuro (padrão do shader); a cor do jogador saiu do rastro
	var m := ShaderMaterial.new(); m.shader = Boneco.sh("fita")
	m.set_shader_parameter("semente", rng.randf() * 10.0)
	mi.material_override = m; mi.extra_cull_margin = 50.0
	add_child(mi)
	var f := {"mi": mi, "im": im, "m": m, "pts": [], "ts": [], "w": 0.13, "vida": 1.0, "ativa": true, "q": 0, "hist": 15}
	fitas.append(f)
	return f

func fita_ponto(f: Dictionary, p: Vector3, centro: Vector3) -> void:
	# as poses são seguradas: a ponta salta entre poses; o rastro interpola o arco em volta do ombro
	var pts: Array = f["pts"]
	var ts: Array = f["ts"]
	if pts.size() > 0 and pts[0].distance_to(p) < 0.01:
		return
	if pts.size() > 0:
		var a: Vector3 = pts[0] - centro; var b: Vector3 = p - centro
		var aa := atan2(a.x, a.z); var ab := atan2(b.x, b.z)
		var da := wrapf(ab - aa, -PI, PI)
		var ra := Vector2(a.x, a.z).length(); var rb := Vector2(b.x, b.z).length()
		for i in range(1, 9):
			var t := float(i) / 8.0
			var ang := aa + da * t
			var r: float = lerp(ra, rb, t)
			var y: float = lerp(a.y, b.y, t)
			pts.push_front(centro + Vector3(sin(ang) * r, y, cos(ang) * r))
			ts.push_front(f["q"])
	else:
		pts.push_front(p)
		ts.push_front(f["q"])

func _draw_fitas(ts: float) -> void:
	for f in fitas:
		var im: ImmediateMesh = f["im"]
		im.clear_surfaces()
		# v2: só 0,25 s de histórico (15 quadros), para não cobrir os aliados
		f["q"] += 1
		var tq: Array = f["ts"]
		while tq.size() > 0 and f["q"] - tq[-1] > f["hist"]:
			tq.pop_back(); f["pts"].pop_back()
		if not f["ativa"]:
			f["vida"] = max(0.0, f["vida"] - dt * ts * 2.6)
			f["m"].set_shader_parameter("vida", f["vida"])
		var pts: Array = f["pts"]
		if pts.size() < 2 or f["vida"] <= 0.0:
			continue
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n := pts.size()
		for i in n:
			var p: Vector3 = pts[i]
			var tg: Vector3 = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
			var side: Vector3 = tg.cross(Vector3.UP).normalized() * float(f["w"])
			var u := float(i) / float(n - 1)
			im.surface_set_uv(Vector2(u, 0)); im.surface_add_vertex(p - side)
			im.surface_set_uv(Vector2(u, 1)); im.surface_add_vertex(p + side)
		im.surface_end()

# ------------------------------------------------------------------ objetos com vida própria
var objs: Array = []   # {node, kind, age, ...}

func seda_estrela(pos: Vector3, cor: Color, tam: float, sem: float, dur := 0.5, delay := 0.0) -> void:
	var m := ShaderMaterial.new(); m.shader = Boneco.sh("seda")
	m.set_shader_parameter("tint", cor); m.set_shader_parameter("shape", 1); m.set_shader_parameter("seed", sem); m.set_shader_parameter("opacity", 0.82)
	var mi := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(tam, tam); mi.mesh = q
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	mi.basis = cam.global_basis.rotated(cam.global_basis.z, sem)
	mi.scale = Vector3.ONE * 0.001
	objs.append({"n": mi, "k": "estrela", "age": -delay, "dur": dur, "tam": tam})

func seda_retalho(pos: Vector3, vel: Vector3, cor: Color, tam: float, sem: float) -> void:
	var m := ShaderMaterial.new(); m.shader = Boneco.sh("seda")
	m.set_shader_parameter("tint", cor); m.set_shader_parameter("shape", 0 if int(sem * 10) % 4 else 2); m.set_shader_parameter("seed", sem); m.set_shader_parameter("opacity", 0.85)
	var mi := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(tam * (2.4 if int(sem * 10) % 4 == 0 else 1.0), tam); mi.mesh = q
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	objs.append({"n": mi, "k": "retalho", "age": 0.0, "v": vel, "rot": Vector3(rng.randf() * 6, rng.randf() * 6, rng.randf() * 6), "spin": Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9)), "dur": 0.9})

func onda(pos: Vector3, ca: Color, cb: Color, r1: float, dur := 0.45) -> void:
	# v2: anel de choque em 2 cores de matéria; ca/cb (jogadores) só nos 2 primeiros quadros
	var m := ShaderMaterial.new(); m.shader = Boneco.sh("onda")
	m.set_shader_parameter("cor_a", ca); m.set_shader_parameter("cor_b", cb); m.set_shader_parameter("sem", rng.randf() * 10.0)
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(r1 * 2.2, r1 * 2.2); mi.mesh = pm
	mi.material_override = m; add_child(mi); mi.global_position = pos + Vector3(0, 0.02, 0)
	objs.append({"n": mi, "k": "onda", "age": 0.0, "dur": dur, "m": m})

func caco(pos: Vector3, vel: Vector3, tam: float, mat: Material) -> void:
	# caco de papel machê: placa irregular com espessura (5 a 7 lados), casca de contorno junto
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := rng.randi_range(5, 7)
	var pts: Array = []
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.3, 0.3)
		var r := tam * rng.randf_range(0.55, 1.0)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	var th := tam * 0.28
	for side in [1.0, -1.0]:
		for i in n:
			var a2: Vector2 = pts[i]; var b2: Vector2 = pts[(i + 1) % n]
			var vs := [Vector3(0, side * th * 0.5 + side * tam * 0.15, 0), Vector3(a2.x, side * th * 0.5, a2.y), Vector3(b2.x, side * th * 0.5, b2.y)]
			if side < 0:
				vs = [vs[0], vs[2], vs[1]]
			for v in vs:
				st.set_normal(Vector3(0, side, 0)); st.set_color(Color.WHITE); st.add_vertex(v)
	for i in n:
		var a2: Vector2 = pts[i]; var b2: Vector2 = pts[(i + 1) % n]
		var nn := Vector3(a2.x + b2.x, 0, a2.y + b2.y).normalized()
		for v in [Vector3(a2.x, th * 0.5, a2.y), Vector3(b2.x, -th * 0.5, b2.y), Vector3(b2.x, th * 0.5, b2.y), Vector3(a2.x, th * 0.5, a2.y), Vector3(a2.x, -th * 0.5, a2.y), Vector3(b2.x, -th * 0.5, b2.y)]:
			st.set_normal(nn); st.set_color(Color.WHITE); st.add_vertex(v)
	var mesh := st.commit()
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat
	var ol := MeshInstance3D.new(); ol.mesh = mesh
	var om := ShaderMaterial.new(); om.shader = Boneco.sh("contorno_rigido"); ol.material_override = om
	mi.add_child(ol)
	add_child(mi); mi.global_position = pos
	objs.append({"n": mi, "k": "caco", "age": 0.0, "v": vel, "rot": Vector3(rng.randf() * 6, rng.randf() * 6, rng.randf() * 6),
		"spin": Vector3(rng.randf_range(-16, 16), rng.randf_range(-16, 16), rng.randf_range(-16, 16)), "dur": 99.0, "chao": false, "tam": tam})

func _step_objs(ts: float) -> void:
	var h := dt * ts
	for o in objs:
		o["age"] += h
		var n: Node3D = o["n"]
		var a: float = o["age"]
		match o["k"]:
			"estrela":
				if a < 0.0:
					continue
				var t: float = a / o["dur"]
				# abre em 3 quadros (passo de 15 poses/s), segura, encolhe
				var tq: float = floor(t * 12.0) / 12.0
				var s: float = (min(1.0, tq * 5.0) * (1.0 - smoothstep(0.65, 1.0, tq)))
				n.scale = Vector3.ONE * max(0.001, s)
				n.visible = t < 1.0
			"retalho":
				o["v"] += Vector3(0, -3.2, 0) * h
				o["v"] *= exp(-2.4 * h)
				n.global_position += o["v"] * h
				o["rot"] += o["spin"] * h
				n.rotation = Vector3(o["rot"].x, o["rot"].y, o["rot"].z)
				n.visible = a < o["dur"] and n.global_position.y > 0.02
			"onda":
				var t2: float = clamp(a / o["dur"], 0.0, 1.0)
				o["m"].set_shader_parameter("raio", 0.2 + 0.7 * (1.0 - pow(1.0 - t2, 3.0)))
				o["m"].set_shader_parameter("esp", 0.07 * (1.0 - t2) + 0.012)
				if a > 2.0 / 60.0:
					o["m"].set_shader_parameter("cor_a", Color("#F2E6C8")); o["m"].set_shader_parameter("cor_b", Color("#A86E47"))
				n.visible = t2 < 1.0
			"nuvem":
				if a < 0.0:
					n.visible = false
					continue
				var qd := int(floor(a * 12.0))
				n.visible = qd < 4
				o["m"].set_shader_parameter("quadro", float(min(qd, 3)))
				n.global_position = o["p0"] + Vector3(0, 0.18 * qd, 0)
			"respingo":
				var t3: float = a / o["dur"]
				o["m"].set_shader_parameter("t", clamp(t3, 0.0, 1.0))
				n.visible = t3 < 1.0
			"caco":
				if a > 0.7 and not o["chao"]:
					o["chao"] = true   # teto de vida: quem ainda quica depois de 0,7 s afunda também
				if o["chao"]:
					# v2: ninguém fica no chão como confete: afunda no praticável em 0,35 s (some até ~1,2 s depois do estouro)
					o["ct"] = o.get("ct", 0.0) + h
					var k: float = clamp((o["ct"] - 0.15) / 0.35, 0.0, 1.0)
					n.scale = Vector3.ONE * max(0.001, 1.0 - k)
					n.visible = k < 1.0
					continue
				o["v"] += Vector3(0, -9.8, 0) * h
				n.global_position += o["v"] * h
				o["rot"] += o["spin"] * h
				n.rotation = o["rot"]
				if n.global_position.y < o["tam"] * 0.2 and o["v"].y < 0.0:
					if abs(o["v"].y) > 1.2:
						o["v"] = Vector3(o["v"].x * 0.45, -o["v"].y * 0.35, o["v"].z * 0.45); o["spin"] *= 0.4
						n.global_position.y = o["tam"] * 0.2
					else:
						o["chao"] = true
						n.global_position.y = o["tam"] * 0.12
						n.rotation = Vector3(0, o["rot"].y, 0)

func step(ts := 1.0) -> void:
	_step_particles(ts)
	_step_objs(ts)

func draw(ts := 1.0) -> void:
	_draw_particles()
	_draw_fitas(ts)

# ------------------------------------------------------------------ v2: nuvem em flipbook e respingo
func nuvem(pos: Vector3, tam: float, delay := 0.0) -> void:
	var m := ShaderMaterial.new(); m.shader = Boneco.sh("nuvem"); m.set_shader_parameter("sem", rng.randf() * 10.0)
	var mi := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(tam, tam); mi.mesh = q
	mi.material_override = m; add_child(mi)
	mi.global_position = pos
	mi.basis = cam.global_basis.rotated(cam.global_basis.z, rng.randf() * TAU)
	mi.visible = false
	objs.append({"n": mi, "k": "nuvem", "age": -delay, "m": m, "p0": pos})

func respingo(pos: Vector3, tam: float, ang: float, dur := 0.55) -> void:
	var m := ShaderMaterial.new(); m.shader = Boneco.sh("respingo"); m.set_shader_parameter("sem", rng.randf() * 10.0)
	var mi := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(tam, tam); mi.mesh = q
	mi.material_override = m; add_child(mi)
	mi.global_position = pos
	mi.basis = cam.global_basis.rotated(cam.global_basis.z, ang)
	objs.append({"n": mi, "k": "respingo", "age": 0.0, "m": m, "dur": dur})

# ------------------------------------------------------------------ pacotes
func serragem(pos: Vector3, dir: Vector3, n := 70) -> void:
	# cone de Serragem: grãos claros que caem, cachos de maravalha que giram e quicam
	for i in n:
		var d := (dir + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.3, 1.4), rng.randf_range(-0.7, 0.7))).normalized()
		emit(pos, d * rng.randf_range(2.0, 6.0), rng.randf_range(0.016, 0.03), 0, 0 if i % 4 else 1, rng.randf_range(0.8, 1.2), rng.randf_range(1.6, 2.8), 9.8, 1.8)
	# v2: lascas de madeira (maravalha) maiores e escuras: a segunda forma do golpe de macete
	for i in n / 8:
		var d := (dir + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.6, 1.6), rng.randf_range(-0.8, 0.8))).normalized()
		emit(pos, d * rng.randf_range(2.5, 5.0), rng.randf_range(0.05, 0.08), 0, 1, rng.randf_range(0.9, 1.2), 2.8, 8.0, 1.2, false)

func poeira(pos: Vector3, n := 14, r := 0.5) -> void:
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.3
		var d := Vector3(cos(a), 0.15, sin(a))
		emit(pos + d * r * 0.3 + Vector3(0, 0.05, 0), d * rng.randf_range(1.2, 2.4), rng.randf_range(0.06, 0.11), 2, 4, rng.randf_range(0.35, 0.6), 1.0, -0.4, 4.0, false)

func gotas(pos: Vector3, vel: Vector3, n := 16) -> void:
	for i in n:
		var v := vel + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.5, 2.6), rng.randf_range(-1.2, 1.2))
		emit(pos + Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.1, 0.1)), v, rng.randf_range(0.022, 0.05), 1, 2, rng.randf_range(0.9, 1.3), 1.0, 9.8, 1.0, true)
