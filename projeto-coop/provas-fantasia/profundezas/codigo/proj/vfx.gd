extends Node3D
# Efeitos de Plumbdeep, deterministas por quadro (o mesmo quadro sai igual no Compatibility e no Forward+):
# partículas em MultiMesh (chuva, esporos, folhas, gesso, pó, faíscas, resina, nuvem de esporos), fitas viradas
# para a câmera (raios, linha do Prumo, borrão dos punhais, arco do frasco) e a frente da Respiração.
static var sh_cache := {}
static func sh(n: String) -> Shader:
	if not sh_cache.has(n):
		sh_cache[n] = load("res://shaders/%s.gdshader" % n)
	return sh_cache[n]

class Nuvem:
	var mmi: MultiMeshInstance3D
	var mat: ShaderMaterial
	var n := 0
	func _init(pai: Node3D, tipo: int, cont: int, tam: Vector2, cor := Color.WHITE) -> void:
		n = cont
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var q := QuadMesh.new(); q.size = tam
		mm.mesh = q
		mm.instance_count = cont
		mat = ShaderMaterial.new(); mat.shader = load("res://shaders/particula.gdshader")
		mat.set_shader_parameter("tipo", tipo)
		mat.set_shader_parameter("cor", cor)
		q.material = mat
		mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(mmi)
		for i in cont:
			por(i, Vector3(0, -9999, 0), 0.0)
	func por(i: int, p: Vector3, s: float) -> void:
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * max(s, 0.0001)), p))
	func esconder() -> void:
		for i in n:
			por(i, Vector3(0, -9999, 0), 0.0)

static func hh(i: int, k: int) -> float:
	var x := sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453
	return x - floor(x)

var C
var pc := false
var lite := false
var chuva: Nuvem
var esporos: Nuvem
var folhas: Nuvem
var gesso: Nuvem
var po: Nuvem
var faisca: Nuvem
var resina: Nuvem
var nuvem: Nuvem
var nuvem_pts: Nuvem
var fitas: MeshInstance3D
var fitas_add: MeshInstance3D
var im: ImmediateMesh
var im_add: ImmediateMesh
var frente: MeshInstance3D
var n_chuva := 1500
var cam: Camera3D
var respingo: Nuvem

func iniciar(cena, _pc: bool, _lite: bool) -> void:
	C = cena; pc = _pc; lite = _lite
	n_chuva = 1700 if pc else (700 if lite else 1200)
	chuva = Nuvem.new(self, 0, n_chuva, Vector2(0.018, 0.45))
	esporos = Nuvem.new(self, 1, 520 if pc else 220, Vector2(0.04, 0.04), Color(0.5, 0.8, 0.78))
	folhas = Nuvem.new(self, 3, 160 if pc else 60, Vector2(1.6, 1.6), Color(0.45, 0.42, 0.3))
	gesso = Nuvem.new(self, 4, 160 if pc else 90, Vector2(0.09, 0.09), Color("cfc6b4"))
	po = Nuvem.new(self, 6, 50 if pc else 24, Vector2(0.9, 0.9), Color(0.5, 0.55, 0.6))
	respingo = Nuvem.new(self, 4, 120 if pc else 60, Vector2(0.05, 0.05), Color(0.7, 0.8, 0.88))
	faisca = Nuvem.new(self, 5, 72, Vector2(0.15, 0.15), Color(0.4, 0.92, 0.95))
	resina = Nuvem.new(self, 7, 40, Vector2(0.07, 0.07), Color("e09a2a"))
	nuvem = Nuvem.new(self, 6, 40 if pc else 24, Vector2(1.1, 1.1), Color(0.34, 0.44, 0.46))
	nuvem_pts = Nuvem.new(self, 1, 160 if pc else 80, Vector2(0.09, 0.09), Color(0.6, 0.9, 0.82))
	im = ImmediateMesh.new(); im_add = ImmediateMesh.new()
	fitas = MeshInstance3D.new(); fitas.mesh = im
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	fitas.material_override = m
	fitas.extra_cull_margin = 2000.0
	add_child(fitas)
	fitas_add = MeshInstance3D.new(); fitas_add.mesh = im_add
	var m2 := StandardMaterial3D.new(); m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m2.vertex_color_use_as_albedo = true
	m2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; m2.cull_mode = BaseMaterial3D.CULL_DISABLED; m2.no_depth_test = false
	m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fitas_add.material_override = m2
	fitas_add.extra_cull_margin = 2000.0
	add_child(fitas_add)
	# frente da Respiração: anel de névoa morna rente ao chão
	frente = MeshInstance3D.new()
	frente.mesh = anel(1.0, 0.82, 64)
	var fm := ShaderMaterial.new(); fm.shader = sh("nevoa")
	fm.set_shader_parameter("densidade", 0.0); fm.set_shader_parameter("escala", 0.35)
	fm.set_shader_parameter("cor", Color(0.62, 0.66, 0.6)); fm.set_shader_parameter("borda_uv", Vector2(0.0001, 0.35))
	frente.material_override = fm
	frente.extra_cull_margin = 2000.0
	add_child(frente)

func anel(R: float, r: float, N: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in N:
		var a0 := TAU * i / N; var a1 := TAU * (i + 1) / N
		var o0 := Vector3(cos(a0), 0, sin(a0)); var o1 := Vector3(cos(a1), 0, sin(a1))
		var u0 := float(i) / N; var u1 := float(i + 1) / N
		for v in [[o0 * r, u0, 0.0], [o1 * r, u1, 0.0], [o1 * R, u1, 1.0], [o0 * r, u0, 0.0], [o1 * R, u1, 1.0], [o0 * R, u0, 1.0]]:
			st.set_uv(Vector2(v[1], v[2])); st.add_vertex(v[0])
	return st.commit()

# ------------------------------------------------------------------ fitas viradas para a câmera
var _fitas_abertas := false
func fitas_inicio() -> void:
	im.clear_surfaces(); im_add.clear_surfaces()
	_n_norm = 0; _n_add = 0
	_buf_norm = []; _buf_add = []

var _buf_norm := []
var _buf_add := []
var _n_norm := 0
var _n_add := 0
func fita(pts: Array, larg: Array, cores: Array, aditiva := true) -> void:
	if pts.size() < 2:
		return
	(_buf_add if aditiva else _buf_norm).append([pts, larg, cores])

func fitas_fim() -> void:
	var cp: Vector3 = C.cam.global_position
	for pair in [[im, _buf_norm], [im_add, _buf_add]]:
		var mesh: ImmediateMesh = pair[0]
		var buf: Array = pair[1]
		if buf.is_empty():
			continue
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for it in buf:
			var pts: Array = it[0]; var larg: Array = it[1]; var cores: Array = it[2]
			for i in pts.size() - 1:
				var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
				var d := (b - a).normalized()
				var va := d.cross((cp - a).normalized()).normalized()
				var wa: float = larg[i] * 0.5; var wb: float = larg[i + 1] * 0.5
				var ca: Color = cores[i]; var cb: Color = cores[i + 1]
				var q := [[a - va * wa, ca], [a + va * wa, ca], [b + va * wb, cb], [a - va * wa, ca], [b + va * wb, cb], [b - va * wb, cb]]
				for v in q:
					mesh.surface_set_color(v[1]); mesh.surface_add_vertex(v[0])
		mesh.surface_end()

func raio(a: Vector3, b: Vector3, seed: int, larg: float, cor: Color, segs := 7, amp := 0.18) -> void:
	# relâmpago quebrado de a até b (Estalo)
	var pts := [a]
	var L := []; var cs := []
	L.append(larg); cs.append(cor)
	var side := (b - a).cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	for k in range(1, segs):
		var t := float(k) / segs
		var off := side * (hh(seed, k) - 0.5) * 2.0 * amp + Vector3(0, (hh(seed, k + 50) - 0.5) * amp, 0)
		pts.append(a.lerp(b, t) + off)
		L.append(larg); cs.append(cor)
	pts.append(b); L.append(larg * 0.4); cs.append(cor)
	fita_cel(pts, L, cor)

func fita_cel(pts: Array, L: Array, cor: Color) -> void:
	# 3 passadas chapadas: beirada escura do tom, corpo no tom e miolo claro (bíblia de VFX da v2)
	var a := cor.a
	var esc := Color(cor.r * 0.18, cor.g * 0.32, cor.b * 0.4, a * 0.9)
	var mio := Color(0.92 + cor.r * 0.08, 0.98, 1.0, a)
	var L1 := []; var L2 := []; var L3 := []; var c1 := []; var c2 := []; var c3 := []
	for i in L.size():
		L1.append(L[i] * 2.3); L2.append(L[i] * 1.35); L3.append(L[i] * 0.5)
		c1.append(esc); c2.append(Color(cor.r, cor.g, cor.b, a)); c3.append(mio)
	fita(pts, L1, c1, false); fita(pts, L2, c2, false); fita(pts, L3, c3, false)

# ------------------------------------------------------------------ atmosfera
func h_chao(x: float, z: float) -> float:
	if C.has_method("h"):
		return maxf(C.h(x, z), -1.0)
	return 0.0

func passo(f: int) -> void:
	var t := f / 60.0
	var resp_x: float = C.resp_x
	# v2: nada de chuva caindo numa caverna fechada. Gotas caem em CORTINAS dos rasgos do teto (onde há o fio de luz
	# fria), mais um gotejar esparso; respingos no chão onde a cortina bate. Dentro da Coluna, poeira dourada.
	var CT: Array = C.mundo.cortinas
	for i in n_chuva:
		var tipo := i % 10
		var x: float; var z: float; var y: float; var s := 1.0
		if tipo == 0:
			var a := hh(i, 1) * TAU; var r := sqrt(hh(i, 2)) * 11.0
			x = 6.0 + cos(a) * r; z = -118.0 + sin(a) * r
			y = -130.0 + fposmod(hh(i, 3) * 200.0 - t * 30.0, 200.0); s = 6.0
		elif tipo < 8 and CT.size() > 0:
			var c: Array = CT[i % CT.size()]
			var cp: Vector3 = c[0]
			x = cp.x + (hh(i, 1) - 0.5) * float(c[1]); z = cp.z + (hh(i, 2) - 0.5) * 0.5
			y = fposmod(hh(i, 3) * 22.0 - t * (10.0 + 3.0 * hh(i, 9)), 22.0) + h_chao(x, z)
			s = 0.8 + 0.5 * hh(i, 8)
		else:
			x = (hh(i, 1) - 0.5) * 34.0 + C.cam_alvo.x; z = (hh(i, 2) - 0.5) * 26.0 - 2.0
			y = fposmod(hh(i, 3) * 26.0 - t * 11.0, 26.0) - 2.0
			s = 0.7
		chuva.por(i, Vector3(x, y, z), s)
	for i in respingo.n:
		var p := Vector3(0, -9999, 0)
		if CT.size() > 0:
			var c: Array = CT[i % CT.size()]
			var cp: Vector3 = c[0]
			var ph := fposmod(t * 2.2 + hh(i, 21), 1.0)
			var a := hh(i, 22) * TAU
			var o := Vector3(cp.x + (hh(i, 23) - 0.5) * float(c[1]), 0.0, cp.z)
			o.y = h_chao(o.x, o.z)
			p = o + Vector3(cos(a), 0, sin(a)) * ph * 0.35 + Vector3(0, 0.5 * ph - 1.6 * ph * ph + 0.02, 0)
		respingo.por(i, p, 1.0)
	# esporos da Expira subindo como neve ao contrário (do Poço e entre os fungos); sobem mais depois da frente
	var sobe := 0.45 + 0.6 * resp_x
	for i in esporos.n:
		var perto := i % 3 != 0
		var x: float; var z: float; var y: float
		if perto:
			x = (hh(i, 4) - 0.5) * 30.0; z = (hh(i, 5) - 0.5) * 24.0 - 3.0
			y = -4.0 + fposmod(hh(i, 6) * 10.0 + t * sobe * (0.7 + 0.6 * hh(i, 12)), 10.0)
			x += sin(t * 0.7 + i) * 0.3
			esporos.por(i, Vector3(x, y, z), 0.8 + hh(i, 7))
		else:
			x = (hh(i, 4) - 0.5) * 220.0; z = -30.0 - hh(i, 5) * 150.0
			y = -130.0 + fposmod(hh(i, 6) * 120.0 + t * 3.0 * sobe, 120.0)
			esporos.por(i, Vector3(x, y, z), 9.0)
	# folhas de fungo caindo devagar dentro da Coluna
	for i in folhas.n:
		var a := hh(i, 8) * TAU + t * 0.2; var r := sqrt(hh(i, 9)) * 10.0
		var y := -130.0 + fposmod(hh(i, 10) * 330.0 - t * 4.0, 330.0)
		folhas.por(i, Vector3(6.0 + cos(a) * r, y, -118.0 + sin(a) * r), 1.0 + hh(i, 11))
	# frente da Respiração
	var fr: float = C.resp_r
	if false and fr > 0.0 and fr < 600.0:
		frente.scale = Vector3(fr + 3.0, 1.0, fr + 3.0)
		frente.position = Vector3(C.resp_o.x, 0.35 - clampf(fr - 14.0, 0.0, 400.0) * 0.18, C.resp_o.y)
		frente.material_override.set_shader_parameter("densidade", 0.55 * clampf(1.0 - fr / 260.0, 0.0, 1.0))
	else:
		frente.material_override.set_shader_parameter("densidade", 0.0)
