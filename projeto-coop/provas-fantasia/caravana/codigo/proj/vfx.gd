extends Node3D
# Efeitos da prova Wickwain, deterministas por quadro (o mesmo quadro sai igual no Compatibility e no Forward+):
# partículas em MultiMesh (chuva, brasas, vapor, gotas de tinta, mariposas, rastro do Lance), línguas de fogo,
# marcas no chão (óleo, anéis de jogador, telegrafia, frente de pincel) e névoa pintada.
static var sh_cache := {}
static func sh(n: String) -> Shader:
	if not sh_cache.has(n):
		sh_cache[n] = load("res://shaders/%s.gdshader" % n)
	return sh_cache[n]

class Nuvem:
	var mmi: MultiMeshInstance3D
	var mat: ShaderMaterial
	var n := 0
	func _init(pai: Node3D, tipo: int, cont: int, tam: Vector2) -> void:
		n = cont
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		var q := QuadMesh.new(); q.size = tam
		mm.mesh = q
		mm.instance_count = cont
		mat = ShaderMaterial.new(); mat.shader = load("res://shaders/particula.gdshader")
		mat.set_shader_parameter("tipo", tipo)
		q.material = mat
		mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.custom_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(mmi)
	func por(i: int, p: Vector3, s: float, cust := Color(0, 0, 1, 0)) -> void:
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * max(s, 0.0001)), p))
		mmi.multimesh.set_instance_custom_data(i, cust)
	func esconder(i: int) -> void:
		por(i, Vector3(0, -50, 0), 0.0)

static func h(i: int, k: int) -> float:
	var x := sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453
	return x - floor(x)

var chuva: Nuvem
var brasas: Nuvem
var vapor: Nuvem
var gotas: Nuvem
var mariposas: Nuvem
var vagalumes: Nuvem
var rastro: Nuvem
var fogo := []           # [MeshInstance3D, ShaderMaterial, centro, altura, fase, nasce]
var calor: MeshInstance3D = null
var calor_mat: ShaderMaterial = null
var marcas := {}
var pc := false
var cont_chuva := 1800

func iniciar(_pc: bool, lite := false) -> void:
	pc = _pc
	cont_chuva = 1700 if pc else (600 if lite else 1100)
	chuva = Nuvem.new(self, 0, cont_chuva, Vector2(0.018, 0.42))
	brasas = Nuvem.new(self, 1, 110 if pc else 50, Vector2(0.07, 0.07))
	vapor = Nuvem.new(self, 2, 56 if pc else 28, Vector2(1.0, 1.0))
	gotas = Nuvem.new(self, 3, 40 if pc else 24, Vector2(0.08, 0.08))
	mariposas = Nuvem.new(self, 4, 24, Vector2(0.2, 0.15))
	vagalumes = Nuvem.new(self, 5, 9, Vector2(0.1, 0.1))
	rastro = Nuvem.new(self, 1, 40, Vector2(0.06, 0.06))

func evitar(lst: Array) -> void:
	# a fumaça some perto dos heróis (não cobre quem joga)
	for i in 4:
		var v := Vector4(0, -99, 0, 0)
		if i < lst.size():
			var p: Vector3 = lst[i]
			v = Vector4(p.x, p.y, p.z, 1.0)
		vapor.mat.set_shader_parameter("evita_%d" % i, v)

# ------------------------------------------------------------------ chuva inclinada pelo vento (riscos só na luz)
func passo_chuva(t: float, centro: Vector3) -> void:
	var vx := 2.6
	var vy := -9.0
	for i in cont_chuva:
		# metade perto do combate, metade em volta da Wain
		var perto := i % 3 != 0
		var bx := (h(i, 1) - 0.5) * (18.0 if perto else 30.0)
		var bz := (h(i, 2) - 0.5) * (14.0 if perto else 18.0) + (0.0 if perto else -25.0)
		var H := 8.0
		var ph := fposmod(h(i, 3) * H - t * -vy, H)
		var y := ph
		var x := bx + centro.x + (H - ph) * vx / -vy
		chuva.por(i, Vector3(x, y, bz + (centro.z if perto else 0.0)), 1.0)

# ------------------------------------------------------------------ fogo (Labareda): chamas em billboard Y
func criar_fogo(centros: Array, alturas: Array, nasce: float) -> void:
	var q := QuadMesh.new(); q.size = Vector2(1, 1); q.center_offset = Vector3(0, 0.5, 0)
	for i in centros.size():
		var mi := MeshInstance3D.new()
		mi.mesh = q
		var mt := ShaderMaterial.new(); mt.shader = sh("fogo")
		mt.set_shader_parameter("fase", h(i, 9))
		mt.set_shader_parameter("energia", 1.7 if pc else 1.0)
		mt.set_shader_parameter("largura", 0.5)
		mi.material_override = mt
		mi.extra_cull_margin = 100.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.sorting_offset = 0.5
		add_child(mi)
		mi.position = centros[i]
		fogo.append([mi, mt, centros[i], alturas[i], h(i, 9), nasce + h(i, 4) * 0.12])
	if pc:
		# distorção de calor (só Forward+)
		calor = MeshInstance3D.new()
		calor.mesh = q
		calor_mat = ShaderMaterial.new(); calor_mat.shader = sh("calor")
		calor.material_override = calor_mat
		calor.extra_cull_margin = 100.0
		calor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		calor.sorting_offset = 2.0
		var c := Vector3.ZERO
		for p in centros:
			c += p
		calor.position = c / max(centros.size(), 1) + Vector3(0, 0.6, 0)
		calor.scale = Vector3(3.2, 3.0, 3.2)
		calor.visible = false
		add_child(calor)

func passo_fogo(t: float) -> void:
	var vmax := 0.0
	for f in fogo:
		var mi: MeshInstance3D = f[0]
		var mt: ShaderMaterial = f[1]
		var nasce: float = f[5]
		var a: float = t - nasce
		var vida := 0.0
		if a > 0.0:
			vida = clamp(a / 0.12, 0.0, 1.0)
			# ruge: passa do tamanho e assenta; depois respira devagar
			vida *= 1.0 + 0.3 * exp(-a * 4.0) * sin(a * 18.0 + 1.0) + 0.06 * sin(t * 5.0 + f[4] * 20.0)
		var H: float = f[3] * vida
		mi.visible = vida > 0.01
		mi.scale = Vector3(H * 0.62, max(H, 0.001), H * 0.62)
		mt.set_shader_parameter("tempo", t)
		mt.set_shader_parameter("vida", clamp(vida, 0.0, 1.0))
		vmax = max(vmax, vida)
	if calor:
		calor.visible = vmax > 0.2
		calor_mat.set_shader_parameter("tempo", t)

# ------------------------------------------------------------------ brasas, fumaça e gotas de tinta
func fonte_fogo(i: int, centro: Vector3, raio: float) -> Vector3:
	if fogo.size() > 0:
		var f: Array = fogo[i % fogo.size()]
		return f[2]
	var ang := h(i, 2) * TAU
	return centro + Vector3(cos(ang), 0, sin(ang)) * h(i, 3) * raio

func passo_brasas(t: float, centro: Vector3, t0: float, raio: float) -> void:
	# nascem nas chamas (no contato com o chão e no corpo), sobem com ruído de rotacional, vida de 1 a 2 s
	for i in brasas.n:
		var L := 1.0 + h(i, 6) * 1.0
		var e := t - t0
		var a := fposmod(e + h(i, 1) * L, L)
		if t0 < 0.0 or e < a:
			brasas.esconder(i)
			continue
		var ciclo: float = floor((e + h(i, 1) * L) / L)
		var s: float = h(i, 7) * 10.0 + ciclo * 1.37
		var base := fonte_fogo(i + int(ciclo) * 3, centro, raio)
		var p := base + Vector3((h(i, 2) - 0.5) * 0.5, 0.05 + h(i, 3) * 0.6, (h(i, 4) - 0.5) * 0.4)
		# rotacional falso: dois giros de frequência diferente que crescem com a idade
		p += Vector3(sin(a * 3.3 + s) * 0.22 * a + cos(a * 7.1 + s * 2.0) * 0.06, 0.0, cos(a * 2.9 + s) * 0.2 * a)
		p += Vector3(0.55 * a, (1.0 + h(i, 5) * 0.8) * a - 0.12 * a * a, -0.15 * a)
		var vid := a / L
		brasas.por(i, p, 0.6 + h(i, 8) * 0.9, Color(vid, h(i, 9), 0.6 + h(i, 10) * 0.8, 0))

func passo_vapor(t: float, centro: Vector3, t0: float, raio: float) -> void:
	# fumaça: sai da ponta das chamas, sobe e é levada pelo vento da chuva, cresce e se desfaz
	for i in vapor.n:
		var L := 2.6
		var e := t - t0
		var a := fposmod(e + h(i, 1) * L, L)
		if t0 < 0.0 or e < a:
			vapor.esconder(i)
			continue
		var ciclo: float = floor((e + h(i, 1) * L) / L)
		var base := fonte_fogo(i * 2 + int(ciclo), centro, raio)
		var Hf := 1.4
		if fogo.size() > 0:
			Hf = fogo[(i * 2 + int(ciclo)) % fogo.size()][3]
		var p := base + Vector3((h(i, 2) - 0.5) * 0.4, Hf * 0.85 + 0.8 * a, (h(i, 3) - 0.5) * 0.3)
		p += Vector3(0.75 * a + sin(a * 1.7 + i) * 0.15, 0.0, -0.22 * a)
		vapor.por(i, p, 0.55 + a * 0.6, Color(a / L, h(i, 4), 1.0, 0))

func passo_gotas(t: float, centro: Vector3, t0: float, rmax: float) -> void:
	# respingos de tinta só na borda da frente de pincel, enquanto ela corre (0,4 s); vida curta
	for i in gotas.n:
		var tb := t0 + h(i, 4) * 0.4
		var a := t - tb
		if t0 < 0.0 or a < 0.0 or a > 0.3:
			gotas.esconder(i)
			continue
		var u: float = clamp((tb - t0) / 0.4, 0.0, 1.0)
		var r0 := rmax * (1.0 - pow(1.0 - u, 2.2))
		var ang := h(i, 2) * TAU
		var r := r0 + a * 1.6
		var y := 0.1 + 2.2 * a - 9.0 * a * a
		gotas.por(i, centro + Vector3(cos(ang) * r, max(y, 0.04), sin(ang) * r), 1.0, Color(a / 0.3, h(i, 3), 1.0, 0))

func passo_mariposas(t: float, centros: Array) -> void:
	for i in mariposas.n:
		var c: Vector3 = centros[i % centros.size()]
		var R := 0.7 + h(i, 1) * (2.2 if i % centros.size() == 0 else 1.0)
		var w := 0.9 + h(i, 2) * 1.4
		var a := t * w * (1.0 if i % 2 == 0 else -1.0) + h(i, 3) * TAU
		var p := c + Vector3(cos(a) * R, 0.6 + h(i, 4) * 2.4 + sin(t * 3.1 + i) * 0.3, sin(a) * R * 0.7)
		mariposas.por(i, p, 1.0)

func passo_vagalumes(t: float, centro: Vector3) -> void:
	# poucos vaga-lumes frios na Treva, longe do fogo
	vagalumes.mat.set_shader_parameter("tempo", t)
	for i in vagalumes.n:
		var ang := h(i, 1) * TAU
		var r := 4.5 + h(i, 2) * 3.5
		var p := centro + Vector3(cos(ang) * r * 1.3, 0.5 + h(i, 3) * 1.2, sin(ang) * r * 0.7)
		p += Vector3(sin(t * 0.5 + i) * 0.4, sin(t * 0.8 + i * 2.0) * 0.2, cos(t * 0.4 + i) * 0.3)
		vagalumes.por(i, p, 1.0, Color(0, h(i, 4), 1, 0))

func passo_rastro(t: float, pts: Array) -> void:
	for i in rastro.n:
		if i < pts.size():
			rastro.por(i, pts[i][0], pts[i][1], Color(0, h(i, 2), 1.0, 0))
		else:
			rastro.esconder(i)
	rastro.mat.set_shader_parameter("tempo", t)
	brasas.mat.set_shader_parameter("tempo", t)

# ------------------------------------------------------------------ marcas no chão
func marca(nome: String, tipo: int, pos: Vector3, tam: float, cor := Color.WHITE, extra := {}) -> ShaderMaterial:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(tam, tam)
	mi.mesh = pm
	var mt := ShaderMaterial.new(); mt.shader = sh("chao_fx")
	mt.set_shader_parameter("tipo", tipo)
	mt.set_shader_parameter("cor", cor)
	for k in extra:
		mt.set_shader_parameter(k, extra[k])
	mi.material_override = mt
	mi.extra_cull_margin = 100.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	marcas[nome] = mi
	return mt

func nevoa(pos: Vector3, tam: Vector2, olhar: Vector3, extra := {}) -> ShaderMaterial:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = tam
	mi.mesh = q
	var mt := ShaderMaterial.new(); mt.shader = sh("nevoa")
	for k in extra:
		mt.set_shader_parameter(k, extra[k])
	mi.material_override = mt
	mi.extra_cull_margin = 1000.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = pos
	var vp: Camera3D = get_viewport().get_camera_3d()
	mi.global_transform.basis = vp.global_transform.basis
	return mt

func bruma(pos: Vector3, tam: Vector2, extra := {}) -> ShaderMaterial:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = tam
	mi.mesh = pm
	var mt := ShaderMaterial.new(); mt.shader = sh("nevoa")
	for k in extra:
		mt.set_shader_parameter(k, extra[k])
	mi.material_override = mt
	mi.extra_cull_margin = 1000.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	return mt
