extends Node3D
# Efeitos da Tralha da Cheia: todos são objetos de brinquedo com forma (lasca pintada, fita de papel, coroa de
# água recortada, estrela de estalo, anel recortado, faixa de cais), nunca bolha brilhante. Avançam por quadro
# de simulação (60 Hz) e mudam de pose em degrau. Cada efeito usa a cor de quem o fez.

var cam: Camera3D
var itens: Array = []     # [{tipo, no, dados...}]
var rng := RandomNumberGenerator.new()
static var sh := {}
var lasca_mesh: Array = []

func S(n: String) -> Shader:
	if not sh.has(n):
		sh[n] = load("res://shaders/%s.gdshader" % n)
	return sh[n]

func mat(shader: String, p := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = S(shader)
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m

func _ready() -> void:
	rng.seed = 77
	for k in 8:
		lasca_mesh.append(_mk_lasca(k))

# ------------------------------------------------------------------ malhas
func _mk_lasca(seed_: int) -> ArrayMesh:
	# lasca de miriti: polígono irregular de 4 a 6 cantos, extrudado (faceta pintada em cima, creme cru nos lados)
	var r := RandomNumberGenerator.new(); r.seed = 300 + seed_
	var n := r.randi_range(4, 6)
	var pts: Array = []
	for i in n:
		var a := TAU * (float(i) + r.randf_range(-0.25, 0.25)) / n
		var rr := r.randf_range(0.5, 1.0)
		pts.append(Vector2(cos(a) * rr * 1.5, sin(a) * rr))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.13
	for side in [1.0, -1.0]:
		for i in range(1, n - 1):
			var a: Vector2 = pts[0]; var b: Vector2 = pts[i]; var c: Vector2 = pts[i + 1]
			st.set_color(Color(1, 1, 1))
			st.set_normal(Vector3(0, side, 0))
			if side > 0:
				st.add_vertex(Vector3(a.x, h, a.y)); st.add_vertex(Vector3(c.x, h, c.y)); st.add_vertex(Vector3(b.x, h, b.y))
			else:
				st.add_vertex(Vector3(a.x, -h, a.y)); st.add_vertex(Vector3(b.x, -h, b.y)); st.add_vertex(Vector3(c.x, -h, c.y))
	for i in n:
		var a: Vector2 = pts[i]; var b: Vector2 = pts[(i + 1) % n]
		var nn := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
		st.set_color(Color(0.93, 0.88, 0.78))
		st.set_normal(nn)
		st.add_vertex(Vector3(a.x, h, a.y)); st.add_vertex(Vector3(b.x, h, b.y)); st.add_vertex(Vector3(b.x, -h, b.y))
		st.add_vertex(Vector3(a.x, h, a.y)); st.add_vertex(Vector3(b.x, -h, b.y)); st.add_vertex(Vector3(a.x, -h, a.y))
	return st.commit()

func quad_chao(size: Vector2, pos: Vector3, m: Material, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = size
	mi.mesh = pm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

# ------------------------------------------------------------------ lascas (Despedida, golpe)
func lascas(pos: Vector3, cores: Array, n: int, forca: float, dir := Vector3.ZERO, escala := 1.0, mural := false) -> void:
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = lasca_mesh[rng.randi() % lasca_mesh.size()]
		var c: Color = cores[i % cores.size()]
		var m := mat("lasca", {"cor": c})
		mi.material_override = m
		var s := rng.randf_range(0.07, 0.15) * escala
		mi.scale = Vector3(s, s, s)
		mi.position = pos + Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.05, 0.1), rng.randf_range(-0.12, 0.12))
		add_child(mi)
		var a := rng.randf() * TAU
		var up := rng.randf_range(2.2, 4.4) * forca
		var out := rng.randf_range(1.0, 3.2) * forca
		var v := Vector3(cos(a) * out, up, sin(a) * out) + dir * forca * rng.randf_range(0.6, 1.4)
		var item := {"tipo": "lasca", "no": mi, "v": v, "w": Vector3(rng.randf_range(-14, 14), rng.randf_range(-14, 14), rng.randf_range(-14, 14)),
			"rot": Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU), "quiques": 0, "f": 0, "mat": m, "mural": false}
		if mural and i == 0:
			item["mural"] = true
			m.set_shader_parameter("brilho", 0.45)
			mi.scale *= 1.5
		itens.append(item)

func _tick_lasca(it: Dictionary) -> void:
	var mi: MeshInstance3D = it["no"]
	var dt := 1.0 / 60.0
	it["f"] += 1
	if it["mural"] and it["f"] > 16:
		# a lasca que brilha voa para o Mural (canto de cima da tela)
		var alvo := cam.project_position(Vector2(150, 110) * (float(get_viewport().get_visible_rect().size.y) / 1080.0), 4.0)
		var p := mi.position
		var k := clampf(float(it["f"] - 16) / 30.0, 0.0, 1.0)
		mi.position = p.lerp(alvo, 0.08 + 0.25 * k * k)
		mi.rotation += Vector3(0.3, 0.4, 0.0)
		if it.has("rastro"):
			it["rastro"].append(mi.position)
		else:
			it["rastro"] = [mi.position]
		if p.distance_to(alvo) < 0.05 or it["f"] > 60:
			mi.visible = false
			it["morto"] = true
		return
	var v: Vector3 = it["v"]
	v.y -= 9.8 * dt
	var p := mi.position + v * dt
	var chao := 0.02 if (absf(p.z) < 2.8 and absf(p.x) < 11.0) else -0.55
	if p.y < chao + 0.01:
		p.y = chao + 0.01
		if chao < 0.0:
			v = v * 0.2
			v.y = -0.15
			it["afunda"] = true
		elif it["quiques"] < 2:
			v.y = -v.y * (0.42 if it["quiques"] == 0 else 0.25)
			v.x *= 0.55; v.z *= 0.55
			it["w"] *= 0.5
			it["quiques"] += 1
		else:
			v = Vector3.ZERO
			it["w"] = Vector3.ZERO
			# assenta deitada
			it["rot"] = Vector3(0, it["rot"].y, 0)
	if it.has("afunda"):
		p.y -= 0.004
	it["v"] = v
	mi.position = p
	it["rot"] += it["w"] * dt
	if it["f"] % 2 == 0:   # rotação em degrau (2s)
		mi.rotation = it["rot"]
	if it["f"] > 36:
		var k := 1.0 - float(it["f"] - 36) / 12.0
		if not it.has("s0"):
			it["s0"] = mi.scale
		mi.scale = it["s0"] * maxf(k, 0.0)
		if k <= 0.0:
			mi.visible = false
			it["morto"] = true

# ------------------------------------------------------------------ fita do passe (rastro da arma no ar)
func fita(arma: Node3D, cor: Color, verso: Color, comprimento := 0.9) -> Dictionary:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new(); mi.mesh = im
	mi.material_override = mat("fita", {"cor": cor, "verso": verso})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var it := {"tipo": "fita", "no": mi, "im": im, "arma": arma, "pts": [], "ax": [], "vivo": true, "comp": comprimento}
	itens.append(it)
	return it

func _tick_fita(it: Dictionary) -> void:
	var arma: Node3D = it["arma"]
	var pts: Array = it["pts"]; var ax: Array = it["ax"]
	if it["vivo"] and is_instance_valid(arma):
		var gt: Transform3D = arma.global_transform
		pts.append(gt * Vector3(0, it["comp"], 0))
		ax.append(gt.basis.y.normalized())
	elif pts.size() > 0:
		for k in 2:
			if pts.size() > 0:
				pts.pop_front(); ax.pop_front()
	while pts.size() > it.get("max", 9):
		pts.pop_front(); ax.pop_front()
	var im: ImmediateMesh = it["im"]
	im.clear_surfaces()
	if pts.size() < 3:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var tg: Vector3 = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
		var a: Vector3 = ax[i]
		var side := (a - tg * a.dot(tg)).normalized()
		if side.length() < 0.1:
			side = tg.cross(Vector3.UP).normalized()
		var u := float(i) / float(n - 1)
		var w := 0.17 * u * (2.0 - u)
		im.surface_set_uv(Vector2(u, 0.0)); im.surface_add_vertex(p - side * w)
		im.surface_set_uv(Vector2(u, 1.0)); im.surface_add_vertex(p + side * w)
	im.surface_end()

# ------------------------------------------------------------------ anel recortado de pegada
func anel_pegada(pos: Vector3, cor: Color) -> void:
	var m := mat("anel", {"cor": cor, "modo": 1, "raio": 0.3, "esp": 0.09, "cortes": 9.0})
	var mi := quad_chao(Vector2(2.6, 2.6), pos + Vector3(0, 0.03, 0), m)
	itens.append({"tipo": "anel", "no": mi, "mat": m, "f": 0})

func _tick_anel(it: Dictionary) -> void:
	it["f"] += 1
	var f: int = it["f"]
	var m: ShaderMaterial = it["mat"]
	var passo := f / 3
	m.set_shader_parameter("raio", [0.3, 0.52, 0.7, 0.82, 0.9, 0.95, 0.98][min(passo, 6)])
	m.set_shader_parameter("esp", [0.09, 0.08, 0.06, 0.045, 0.035, 0.025, 0.02][min(passo, 6)])
	if f > 21:
		it["no"].visible = false
		it["morto"] = true

# ------------------------------------------------------------------ estrela de estalo no contato
func estalo(pos: Vector3, cor: Color, tam := 0.9, quadros := 5) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(tam, tam)
	mi.mesh = qm
	var m := mat("estalo", {"cor": cor, "semente": rng.randf() * 10.0})
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	itens.append({"tipo": "estalo", "no": mi, "mat": m, "f": 0, "dur": quadros})

func _tick_estalo(it: Dictionary) -> void:
	it["f"] += 1
	var mi: MeshInstance3D = it["no"]
	mi.look_at(cam.global_position, Vector3.UP)
	mi.rotate_object_local(Vector3.UP, PI)
	var f: int = it["f"]
	var s: float = [1.0, 1.15, 0.85, 0.6, 0.4][min(f / 2, 4)]
	mi.scale = Vector3(s, s, s)
	it["mat"].set_shader_parameter("fase", float(f / 2))
	if f > it["dur"] * 2:
		mi.visible = false
		it["morto"] = true

# ------------------------------------------------------------------ coroa de respingo (água rasa)
func coroa(pos: Vector3, escala := 1.0) -> void:
	var raiz := Node3D.new(); raiz.position = pos; add_child(raiz)
	var tons := [Color("#9CC0B6"), Color("#EDE1C6"), Color("#5F8E8C")]
	var petalas: Array = []
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var mi := MeshInstance3D.new()
		mi.mesh = _petala()
		mi.material_override = mat("lasca", {"cor": tons[i % 3], "plano": 1.0})
		var piv := Node3D.new()
		piv.rotation.y = -a
		raiz.add_child(piv)
		piv.add_child(mi)
		mi.position = Vector3(0.22 * escala, 0, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		petalas.append(mi)
	var gotas: Array = []
	for i in 9:
		var g := MeshInstance3D.new()
		g.mesh = _gota()
		g.material_override = mat("lasca", {"cor": tons[i % 2], "plano": 1.0})
		raiz.add_child(g)
		var a := TAU * i / 9.0 + rng.randf() * 0.3
		gotas.append({"no": g, "v": Vector3(cos(a) * rng.randf_range(1.2, 2.2), rng.randf_range(3.0, 4.6), sin(a) * rng.randf_range(1.2, 2.2)) * escala, "p": Vector3.ZERO})
	var m := mat("anel", {"cor": Color("#9CC0B6"), "modo": 1, "raio": 0.2, "esp": 0.08, "cortes": 12.0})
	var aro := quad_chao(Vector2(3.0, 3.0) * escala, pos + Vector3(0, 0.02, 0), m)
	itens.append({"tipo": "coroa", "no": raiz, "petalas": petalas, "gotas": gotas, "aro": aro, "aro_m": m, "f": 0, "esc": escala})

func _petala() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0), Vector3(0.13, 0.35, 0.0), Vector3(0.02, 0.62, 0), Vector3(-0.06, 0.4, 0)]
	st.set_normal(Vector3(1, 0, 0))
	for i in range(1, pts.size() - 1):
		st.add_vertex(pts[0]); st.add_vertex(pts[i]); st.add_vertex(pts[i + 1])
	var m := st.commit()
	return m

func _gota() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 7
	for i in n:
		var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
		var r0: float = 0.05 * (1.0 + 0.8 * max(0.0, sin(a0))); var r1: float = 0.05 * (1.0 + 0.8 * max(0.0, sin(a1)))
		st.add_vertex(Vector3.ZERO); st.add_vertex(Vector3(cos(a0) * 0.05, sin(a0) * r0 * 1.6, 0)); st.add_vertex(Vector3(cos(a1) * 0.05, sin(a1) * r1 * 1.6, 0))
	return st.commit()

func _tick_coroa(it: Dictionary) -> void:
	it["f"] += 1
	var f: int = it["f"]
	var passo := f / 4   # 3 poses em degrau de 4 quadros para subir, e cai
	var alturas := [0.45, 1.0, 1.15, 0.8, 0.45, 0.2, 0.0]
	var aberturas := [10.0, 22.0, 34.0, 48.0, 60.0, 70.0, 75.0]
	var k: int = min(passo, 6)
	for mi in it["petalas"]:
		mi.scale = Vector3(1.0, alturas[k] * it["esc"], 1.0) * it["esc"]
		mi.rotation.z = -deg_to_rad(aberturas[k])
		mi.visible = alturas[k] > 0.01
	var dt := 1.0 / 60.0
	for g in it["gotas"]:
		var v: Vector3 = g["v"]
		v.y -= 9.8 * dt
		g["v"] = v
		g["p"] += v * dt
		if f % 2 == 0:
			g["no"].position = g["p"]
			g["no"].look_at(cam.global_position, Vector3.UP)
		g["no"].visible = g["p"].y > -0.1
	var m: ShaderMaterial = it["aro_m"]
	m.set_shader_parameter("raio", min(0.95, 0.2 + 0.08 * float(f / 3)))
	m.set_shader_parameter("esp", max(0.015, 0.08 - 0.005 * float(f / 3)))
	if f > 40:
		it["aro"].visible = false
	if f > 60:
		it["no"].visible = false
		it["morto"] = true

# ------------------------------------------------------------------ borrão (smear) de 1 quadro da arma
func smear(pts_a: Array, pts_b: Array, pivo: Vector3, cor: Color, cor2: Color) -> void:
	# Borrão de 1 quadro: só a parte de fora da arma (a pá), varrida em arco em volta do pivô (ombro), no último
	# trecho do arco antes do contato. Pá cheia na cor da arma, mais 3 riscos de velocidade que afinam para trás.
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new(); mi.mesh = im
	mi.material_override = mat("fx", {"cor": cor, "cor2": cor2, "dois_lados": true})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var N := 10
	var u0 := 0.3
	var n := pts_a.size()
	var rows: Array = []
	for j in N + 1:
		var u := lerpf(u0, 1.0, float(j) / N)
		var row: Array = []
		for i in n:
			var a: Vector3 = pts_a[i] - pivo; var b: Vector3 = pts_b[i] - pivo
			var la := a.length(); var lb := b.length()
			var d := a.normalized().slerp(b.normalized(), u)
			row.append(pivo + d * lerpf(la, lb, u))
		rows.append(row)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# pá cheia: entre os 2 últimos pontos, afinando para trás
	for j in N:
		var w0 := float(j) / N
		var w1 := float(j + 1) / N
		var t0: Vector3 = rows[j][n - 1]; var t1: Vector3 = rows[j + 1][n - 1]
		var b0: Vector3 = rows[j][n - 3].lerp(t0, clampf(1.0 - w0 * 2.5, 0.0, 1.0)); var b1: Vector3 = rows[j + 1][n - 3].lerp(t1, clampf(1.0 - w1 * 2.5, 0.0, 1.0))
		im.surface_add_vertex(b0); im.surface_add_vertex(t0); im.surface_add_vertex(t1)
		im.surface_add_vertex(b0); im.surface_add_vertex(t1); im.surface_add_vertex(b1)
	# riscos de velocidade no cabo
	for i in [n - 4, n - 5]:
		if i < 1:
			continue
		for j in N:
			var w := 0.012 * float(j + 1) / N
			var p0: Vector3 = rows[j][i]; var p1: Vector3 = rows[j + 1][i]
			var up := (p1 - p0).cross(Vector3.UP).normalized() * w + Vector3(0, w, 0)
			im.surface_add_vertex(p0 - up); im.surface_add_vertex(p1 - up); im.surface_add_vertex(p1 + up)
			im.surface_add_vertex(p0 - up); im.surface_add_vertex(p1 + up); im.surface_add_vertex(p0 + up)
	im.surface_end()
	itens.append({"tipo": "smear", "no": mi, "f": 0})

# ------------------------------------------------------------------ balão "me passa!"
func balao(alvo: Node3D, altura: float, cor: Color, quadros: int, desl := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(0.62, 0.62)
	mi.mesh = qm
	mi.material_override = mat("balao", {"cor": cor})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	itens.append({"tipo": "balao", "no": mi, "alvo": alvo, "h": altura, "f": 0, "dur": quadros, "desl": desl})

func _tick_balao(it: Dictionary) -> void:
	it["f"] += 1
	var mi: MeshInstance3D = it["no"]
	var f: int = it["f"]
	var s: float = [0.5, 1.2, 0.95, 1.0][min(f / 3, 3)]
	if f > it["dur"] - 6:
		s = [0.8, 0.4][min((f - it["dur"] + 6) / 3, 1)]
	mi.scale = Vector3(s, s, s)
	mi.global_position = it["alvo"].global_position + it["desl"] + Vector3(0, it["h"] + 0.04 * float((f / 8) % 2), 0)
	mi.look_at(cam.global_position, Vector3.UP)
	mi.rotate_object_local(Vector3.UP, PI)
	if f > it["dur"]:
		mi.visible = false
		it["morto"] = true

# ------------------------------------------------------------------ avanço por quadro
func tick() -> void:
	for it in itens:
		if it.get("morto", false):
			continue
		match it["tipo"]:
			"lasca": _tick_lasca(it)
			"fita": _tick_fita(it)
			"anel": _tick_anel(it)
			"estalo": _tick_estalo(it)
			"coroa": _tick_coroa(it)
			"balao": _tick_balao(it)
			"smear":
				it["f"] += 1
				if it["f"] > 1:
					it["no"].visible = false
					it["morto"] = true
