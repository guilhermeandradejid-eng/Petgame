extends Node3D
# Trecho de mundo aberto do Vau da Tempestade, todo gerado por código: terreno contínuo com relevo e rio, água,
# trigo em MultiMesh, pedras, ponte quebrada, casa de enxaimel, forca, árvores-agulha, marcos no horizonte
# (moinho queimado, Campanário Andante, Prensa Real, fumaças das forjas), céu, névoa em camadas, chuva e cinzas.

const SH := "res://shaders/"
var main
var pc := true
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var agua_mat: ShaderMaterial
var ceu_mat: ShaderMaterial
var moinho_pas: Node3D
var campanario: Node3D
var prensa_rosca: Node3D
var nevoas: Array = []
var chuva_mm: MultiMeshInstance3D
var cinza_mm: MultiMeshInstance3D
var trigo_mm: MultiMeshInstance3D
var trigo_mat: ShaderMaterial
var contorno_sh: Shader
var mundo_sh: Shader
var forjas: Array = []
var hz: Node3D
var hz_cam0 := Vector3.ZERO
var enforcados: Array = []
var gaiola: Node3D
var portao_luz := Vector3.ZERO
var corvo_l: Array = []

const ZN := -7.6    # margem norte (z) em x = 0
const ZS := 3.2     # margem sul

func lin(h: String) -> Color:
	return Color(h)   # uniforms vec3 com source_color (o motor converte)

func linv(h: String) -> Color:
	return Color(h).srgb_to_linear()   # cor de vértice: já em linear

# o rio dobra para o norte rio acima (leste) e para o sul a oeste: na câmera, uma diagonal que leva o olho ao fundo
func bend(x: float) -> float:
	var e := maxf(x - 6.0, 0.0)
	var b := -0.012 * minf(e, 14.0) * minf(e, 14.0) - 0.336 * maxf(e - 14.0, 0.0)
	var o := maxf(-x - 8.0, 0.0)
	return b + 0.01 * minf(o, 14.0) * minf(o, 14.0) + 0.28 * maxf(o - 14.0, 0.0)

func z_norte(x: float) -> float:
	return ZN + 1.5 * sin(0.11 * x + 1.0) + bend(x)

func z_sul(x: float) -> float:
	return ZS + 1.0 * sin(0.13 * x) + bend(x)

# estradas: a do sul sai do quadro por baixo; a do norte passa pela brecha da cerca, sobe ao forte em ruína e
# tem um ramo que sai do quadro para oeste
const ESTRADAS := [
	[Vector2(-0.8, 2.2), Vector2(-0.9, 6.0), Vector2(-1.6, 10.0), Vector2(-4.0, 14.5), Vector2(-9.0, 19.0), Vector2(-16.0, 23.0), Vector2(-30.0, 28.0)],
	[Vector2(-3.6, -7.2), Vector2(-3.3, -10.8), Vector2(-1.0, -13.6), Vector2(5.0, -15.4), Vector2(12.0, -16.8), Vector2(18.0, -17.4), Vector2(22.6, -16.9)],
	[Vector2(-3.3, -10.8), Vector2(-9.0, -12.6), Vector2(-18.0, -13.6), Vector2(-30.0, -13.0), Vector2(-50.0, -12.0)],
]
const FORTE := Vector3(25.0, 0, -17.0)
const ARVORE := Vector3(3.0, 0, -12.4)
const MOINHO := Vector3(15.0, 0, -29.0)

func dist_estrada(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 99.0
	for e in ESTRADAS:
		for i in e.size() - 1:
			var a: Vector2 = e[i]; var b: Vector2 = e[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best

func altura(x: float, z: float) -> float:
	var zn := z_norte(x)
	var zs := z_sul(x)
	var n := noise.get_noise_2d(x * 3.0, z * 3.0)
	if z > zn and z < zs:
		var fundo := 0.2 if absf(x) < 10.0 else 0.2 + 0.35 * smoothstep(10.0, 18.0, absf(x))
		var borda := minf(z - zn, zs - z)
		return -0.07 - fundo * smoothstep(0.0, 1.6, borda) + n * 0.03
	if z >= zs:
		var t := z - zs
		return 0.05 + 0.32 * smoothstep(0.0, 2.5, t) + 0.25 * smoothstep(3.0, 10.0, t) + n * 0.12 + 0.6 * noise.get_noise_2d(x * 0.6, z * 0.6) * smoothstep(2.0, 6.0, t)
	var u := zn - z
	var hh := 0.05 + 0.45 * smoothstep(0.0, 2.2, u) + 0.5 * smoothstep(4.0, 18.0, u) * (0.6 + 0.6 * noise.get_noise_2d(x * 0.4, z * 0.4)) + n * 0.14
	hh += 0.9 * noise.get_noise_2d(x * 0.05 + 3.0, z * 0.05) * smoothstep(14.0, 30.0, u)     # colinas longe
	var df := Vector2(x - FORTE.x, z - FORTE.z).length()
	hh += 1.5 * exp(-df * df / 70.0)                                                           # morro do forte
	var dm := Vector2(x - MOINHO.x, z - MOINHO.z).length()
	hh += 1.8 * exp(-dm * dm / 90.0)
	var de := dist_estrada(x, z) if u < 30.0 else 99.0
	hh -= 0.06 * smoothstep(1.3, 0.4, de)                                                      # a estrada afunda no barro
	return hh

func setup(m, is_pc: bool) -> void:
	main = m
	pc = is_pc
	rng.seed = 1977
	noise.seed = 31
	noise.frequency = 0.08
	contorno_sh = load(SH + "contorno.gdshader")
	mundo_sh = load(SH + "mundo.gdshader")

# ------------------------------------------------------------------ utilidades
func mat_mundo(wash: String, amt := 1.0, distante := 0.0, extra := 0.0, esc := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = mundo_sh
	var c := lin(wash) if wash != "" else Color(1, 1, 1)
	m.set_shader_parameter("aguada", Color(c.r, c.g, c.b))
	m.set_shader_parameter("aguada_a", amt if wash != "" else 0.0)
	m.set_shader_parameter("distante", distante)
	m.set_shader_parameter("extra", extra)
	m.set_shader_parameter("esc", esc)
	return m

func contorno(mi: MeshInstance3D, px := 1.4, distante := false) -> MeshInstance3D:
	# casca invertida: mesma malha, cor de vértice alfa = 1, cull_front no shader
	var src: Mesh = mi.mesh
	var am := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var n: int = arr[Mesh.ARRAY_VERTEX].size()
		var cols := PackedColorArray()
		cols.resize(n)
		cols.fill(Color(0.137, 0.11, 0.09, 1.0))
		arr[Mesh.ARRAY_COLOR] = cols
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var h := MeshInstance3D.new()
	h.mesh = am
	var cm := ShaderMaterial.new()
	cm.shader = contorno_sh
	cm.set_shader_parameter("px_1080", px)
	h.material_override = cm
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(h)
	var mo = mi.material_override
	if distante or (mo is ShaderMaterial and (mo.shader != mundo_sh or float(mo.get_shader_parameter("distante")) > 0.5)):
		cm.set_shader_parameter("curvar", 0.0)
	return h

func caixa(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, px := 1.4) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	pai.add_child(mi)
	if px > 0.0:
		contorno(mi, px)
	return mi

func cilindro(pai: Node3D, r0: float, r1: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, seg := 10, px := 1.4) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r1
	cm.bottom_radius = r0
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	pai.add_child(mi)
	if px > 0.0:
		contorno(mi, px)
	return mi

func prisma(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, px := 1.4) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = tam
	mi.mesh = pm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	pai.add_child(mi)
	if px > 0.0:
		contorno(mi, px)
	return mi

# ------------------------------------------------------------------ terreno
func _eixo(fino0: float, fino1: float, passo: float, lim0: float, lim1: float) -> PackedFloat32Array:
	# eixo da grade: fino no meio, células crescendo 18% por passo para fora (o longe é coberto pela névoa)
	var v := PackedFloat32Array()
	var x := fino0
	var st := passo
	var esq: Array = []
	while x > lim0:
		st *= 1.18; x -= st; esq.push_front(maxf(x, lim0))
	for e in esq: v.append(e)
	x = fino0
	while x < fino1:
		v.append(x); x += passo
	st = passo
	while x < lim1:
		v.append(x); st *= 1.18; x += st
	v.append(lim1)
	return v

func terreno(passo := 0.35) -> void:
	var xs := _eixo(-26.0, 26.0, passo, -110.0, 110.0)
	var zs_ := _eixo(-30.0, 16.0, passo, -150.0, 40.0)
	var nx := xs.size(); var nz := zs_.size()
	var cores := [linv("#A8834F"), linv("#7D8A5A"), linv("#C9A55A"), linv("#6E4A33")]
	var zn2 := FastNoiseLite.new(); zn2.seed = 5; zn2.frequency = 0.11
	var verts := PackedVector3Array(); var uvs := PackedVector2Array(); var uv2s := PackedVector2Array(); var cols := PackedColorArray(); var nors := PackedVector3Array()
	verts.resize(nx * nz); uvs.resize(nx * nz); uv2s.resize(nx * nz); cols.resize(nx * nz); nors.resize(nx * nz)
	var H := PackedFloat32Array(); H.resize(nx * nz)
	for j in nz:
		for i in nx:
			H[j * nx + i] = altura(xs[i], zs_[j])
	for j in nz:
		for i in nx:
			var i0 := maxi(i - 1, 0); var i1 := mini(i + 1, nx - 1); var j0 := maxi(j - 1, 0); var j1 := mini(j + 1, nz - 1)
			var dx := (H[j * nx + i1] - H[j * nx + i0]) / (xs[i1] - xs[i0])
			var dz := (H[j1 * nx + i] - H[j0 * nx + i]) / (zs_[j1] - zs_[j0])
			nors[j * nx + i] = Vector3(-dx, 1.0, -dz).normalized()
	for j in nz:
		for i in nx:
			var x := xs[i]
			var z := zs_[j]
			var k := j * nx + i
			var h := H[k]
			verts[k] = Vector3(x, h, z)
			uvs[k] = Vector2(x, h)
			var zs := z_sul(x)
			var zn := z_norte(x)
			var de := dist_estrada(x, z) if absf(x) < 60.0 and z > -40.0 else 99.0
			# margem sul retomada: manchas planas de aguada; a linha de tinta é irregular
			var lim := zs - 0.4 + 0.5 * zn2.get_noise_2d(x * 2.0, 7.0)
			var col := Color(1, 1, 1, 0)
			var ex := 0.0
			if z > lim:
				var v := zn2.get_noise_2d(x, z) * 0.5 + 0.5
				var kk := 0 if v < 0.32 else (1 if v < 0.55 else (2 if v < 0.64 else 3))
				if z > zs + 1.0 and de > 1.3 and z < zs + 14.0:
					kk = 3 if v < 0.62 else 0   # chão do trigal (sombra-queimada: low key)
				if de < 1.1:
					kk = 3                      # estrada de terra até o vau
				var c: Color = cores[kk]
				col = Color(c.r, c.g, c.b, 1.0)
				ex = -0.1    # terra retomada (low key: a luz vem das tochas e velas, não do chão)
			elif z < zn + 0.3:
				ex = 0.1 + 0.25 * clampf((zn - z) / 6.0, 0.0, 1.0)   # terra descorada, fria
			cols[k] = col
			uv2s[k] = Vector2(ex, de)
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = nors; arr[Mesh.ARRAY_TEX_UV] = uvs; arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_COLOR] = cols; arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	var m := ShaderMaterial.new()
	m.shader = load(SH + "terreno.gdshader")
	mi.material_override = m
	mi.extra_cull_margin = 400.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	print("PROBE terreno ", nx, "x", nz)

func agua() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(220, 190)
	pm.subdivide_width = 160
	pm.subdivide_depth = 140
	mi.mesh = pm
	mi.position = Vector3(0, -0.02, -55.0)
	agua_mat = ShaderMaterial.new()
	agua_mat.shader = load(SH + "agua.gdshader")
	agua_mat.set_shader_parameter("cor_rio", lin("#6F8894"))
	agua_mat.set_shader_parameter("margem", Vector2(ZN, ZS))
	mi.material_override = agua_mat
	mi.extra_cull_margin = 400.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ------------------------------------------------------------------ trigo
func trigo(n := 5000) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# um pé: dois planos cruzados, finos, com espiga mais larga no alto
	for k in 2:
		var ang := k * PI * 0.5
		var dx := Vector3(cos(ang), 0, sin(ang))
		var pts := [[0.0, 0.009], [0.5, 0.008], [0.58, 0.03], [0.88, 0.026], [1.0, 0.003]]
		for i in pts.size() - 1:
			var a: Array = pts[i]; var b: Array = pts[i + 1]
			var h0: float = a[0] * 0.62; var h1: float = b[0] * 0.62
			var p0: Vector3 = -dx * float(a[1]) + Vector3(0, h0, 0); var p1: Vector3 = dx * float(a[1]) + Vector3(0, h0, 0)
			var p2: Vector3 = dx * float(b[1]) + Vector3(0, h1, 0); var p3: Vector3 = -dx * float(b[1]) + Vector3(0, h1, 0)
			for q in [[p0, a[0]], [p1, a[0]], [p2, b[0]], [p0, a[0]], [p2, b[0]], [p3, b[0]]]:
				st.set_uv(Vector2(0, q[1]))
				st.add_vertex(q[0])
	var mesh := st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var pos: Array = []
	var tent := 0
	while pos.size() < n and tent < n * 6:
		tent += 1
		var x := rng.randf_range(-30.0, 30.0)
		var z := rng.randf_range(z_sul(x) + 1.1, 19.0)
		if dist_estrada(x, z) < 1.5:
			continue   # estrada
		if Vector2(x + 3.6, z - 3.9).length() < 1.6:
			continue   # pedra da Sineira
		if x > -4.5 and x < 4.5 and z < 7.8 and z > 4.6:
			continue   # onde a milícia espera
		if noise.get_noise_2d(x * 1.5, z * 1.5) < -0.35:
			continue   # clareiras
		pos.append(Vector3(x, altura(x, z) - 0.02, z))
	mm.instance_count = pos.size()
	for i in pos.size():
		var s := rng.randf_range(0.8, 1.25)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.15), s))
		mm.set_instance_transform(i, Transform3D(b, pos[i]))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), 0, 0))
	trigo_mm = MultiMeshInstance3D.new()
	trigo_mm.multimesh = mm
	trigo_mat = ShaderMaterial.new()
	trigo_mat.shader = load(SH + "trigo.gdshader")
	trigo_mat.set_shader_parameter("cor_espiga", lin("#C9A55A"))
	trigo_mat.set_shader_parameter("cor_tinta", lin("#231C17"))
	trigo_mm.material_override = trigo_mat
	trigo_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trigo_mm.extra_cull_margin = 50.0
	add_child(trigo_mm)

# ------------------------------------------------------------------ pedras
func pedra(pos: Vector3, tam: Vector3, seed: int, wash := "", px := 1.3, achata := 0.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 14; sm.rings = 8
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nz := FastNoiseLite.new(); nz.seed = seed; nz.frequency = 0.9
	for i in v.size():
		var p := v[i]
		var d := 1.0 + 0.28 * nz.get_noise_3dv(p * 1.3) + 0.1 * nz.get_noise_3dv(p * 3.7)
		p *= d
		if p.y > 0.35:
			p.y = lerpf(p.y, 0.35 + (p.y - 0.35) * 0.4, achata)
		v[i] = p * tam
	arr[Mesh.ARRAY_VERTEX] = v
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat_mundo(wash, 1.0, 0.0, -0.2, 0.8)
	mi.position = pos
	add_child(mi)
	contorno(mi, px)
	return mi

func pedras() -> void:
	# pedra seca da Sineira na margem sul
	pedra(Vector3(-3.6, -0.05, 3.9), Vector3(1.05, 0.42, 0.8), 3, "#6E4A33", 1.5, 0.8)
	# pedras de passagem atravessando o vau
	var a := Vector3(-2.2, 0, 2.3); var b := Vector3(-3.6, 0, -7.0)
	for i in 9:
		var p := a.lerp(b, i / 8.0) + Vector3(rng.randf_range(-0.4, 0.4), -0.1, 0)
		pedra(p, Vector3(0.35, 0.16, 0.3) * rng.randf_range(0.8, 1.2), 40 + i, "" if p.z < -1.0 else "#E9DFC9", 1.2, 0.7)
	# seixos e blocos nas margens
	for i in 26:
		var x := rng.randf_range(-20, 20)
		var nort := rng.randf() < 0.55
		var z := z_norte(x) - rng.randf_range(-0.6, 2.5) if nort else z_sul(x) + rng.randf_range(-0.5, 1.2)
		var s := rng.randf_range(0.25, 0.75)
		pedra(Vector3(x, altura(x, z) - 0.05, z), Vector3(s, s * 0.6, s * 0.85), 100 + i, "" if nort else ("#7D8A5A" if i % 3 == 0 else "#A8834F"), 1.2)

# ------------------------------------------------------------------ ponte quebrada (30 m rio acima), forca, agulhas
func ponte() -> void:
	var raiz := Node3D.new()
	raiz.position = Vector3(20.0, 0, -5.6)
	raiz.rotation_degrees = Vector3(0, -14, 0)
	add_child(raiz)
	var pedra_m := mat_mundo("", 0.0, 0.0, 0.35, 0.5)
	# pilares e arcos (o do meio caiu)
	for zz in [-7.5, -2.5, 2.5, 7.5]:
		caixa(raiz, Vector3(1.6, 3.2, 1.3), Vector3(0, 0.8, zz), pedra_m)
		prisma(raiz, Vector3(1.6, 0.8, 1.3), Vector3(0, 2.8, zz), pedra_m, Vector3(0, 0, 0))
	caixa(raiz, Vector3(1.8, 0.45, 5.4), Vector3(0, 2.6, -5.0), pedra_m)
	caixa(raiz, Vector3(1.8, 0.45, 5.4), Vector3(0, 2.6, 5.0), pedra_m)
	caixa(raiz, Vector3(1.8, 0.45, 1.6), Vector3(0, 2.45, -1.6), pedra_m, Vector3(-18, 0, 0))
	caixa(raiz, Vector3(1.8, 0.45, 1.4), Vector3(0, 2.4, 1.5), pedra_m, Vector3(22, 0, 0))
	for k in 6:
		caixa(raiz, Vector3(0.2, 0.5, 0.2), Vector3(0.8, 3.05, -7.2 + k * 0.6), pedra_m)
	# pedaços caídos no rio
	for k in 3:
		caixa(raiz, Vector3(0.9, 0.5, 0.7), Vector3(rng.randf_range(-0.8, 0.8), -0.05, rng.randf_range(-0.7, 0.7)), pedra_m, Vector3(rng.randf_range(-30, 30), rng.randf_range(0, 90), 15))
	# dois enforcados de tinta balançando no arco (silhuetas pequenas)
	for k in 2:
		var e := Node3D.new()
		e.position = Vector3(-0.6, 2.4, -6.3 + k * 1.1)
		raiz.add_child(e)
		var tm := mat_mundo("", 0.0, 0.0, 2.5, 0.4)
		cilindro(e, 0.008, 0.008, 0.6, Vector3(0, -0.3, 0), tm, Vector3.ZERO, 4, 0.8)
		caixa(e, Vector3(0.2, 0.32, 0.14), Vector3(0, -0.8, 0), tm, Vector3.ZERO, 1.0)
		var cab := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.15; sm.height = 0.3; cab.mesh = sm
		cab.material_override = tm; cab.position = Vector3(0, -0.52, 0); e.add_child(cab); contorno(cab, 1.0)
		enforcados.append(e)

func casa(pos: Vector3, yaw: float) -> void:
	# casa de enxaimel (vigas de tinta sobre reboco de papel) com telhado de cobre em azinhavre
	var r := Node3D.new(); r.position = pos; r.rotation_degrees = Vector3(0, yaw, 0); add_child(r)
	var reboco := mat_mundo("#E9DFC9", 0.9, 0.0, 0.0, 0.5)
	var viga := mat_mundo("#6E4A33", 1.0, 0.0, 0.3, 0.3)
	var cobre := mat_mundo("#5E8F7E", 1.0, 0.0, 0.0, 0.4)
	caixa(r, Vector3(3.0, 2.6, 2.4), Vector3(0, 1.3, 0), reboco)
	for x in [-1.45, -0.5, 0.5, 1.45]:
		caixa(r, Vector3(0.14, 2.6, 0.06), Vector3(x, 1.3, 1.22), viga, Vector3.ZERO, 0.0)
	caixa(r, Vector3(3.0, 0.14, 0.06), Vector3(0, 1.3, 1.22), viga, Vector3.ZERO, 0.0)
	for s in [-1, 1]:
		caixa(r, Vector3(0.12, 1.4, 0.06), Vector3(s * 1.0, 1.95, 1.23), viga, Vector3(0, 0, s * 35), 0.0)
	prisma(r, Vector3(3.4, 2.4, 2.8), Vector3(0, 3.8, 0), cobre)
	caixa(r, Vector3(0.5, 1.0, 0.5), Vector3(0.8, 4.4, -0.3), mat_mundo("#A8834F", 1.0, 0.0, 0.2, 0.3))
	caixa(r, Vector3(0.6, 0.8, 0.08), Vector3(-0.9, 1.9, 1.24), mat_mundo("#E2672B", 1.0, 0.0, -2.0, 0.3), Vector3.ZERO, 1.0)   # janela acesa

func agulhas() -> void:
	# árvores mortas finíssimas espalhadas pela margem norte e pela várzea ao longe
	var tm := mat_mundo("", 0.0, 0.0, 1.2, 0.3)
	for i in 14:
		var x: float = [-19.0, -14.0, -10.5, 7.5, 10.0, 21.0, 25.0, -24.0, -2.0, 12.0, 30.0, -8.0, 3.0, 19.0][i] + rng.randf_range(-1, 1)
		var z := z_norte(x) - rng.randf_range(1.5, 4.0) - (0.0 if i < 7 else rng.randf_range(8.0, 22.0))
		if dist_estrada(x, z) < 2.0:
			continue
		var h := rng.randf_range(2.2, 4.2) * (1.0 if i < 7 else 1.5)
		var t := Node3D.new(); t.position = Vector3(x, altura(x, z), z); add_child(t)
		cilindro(t, 0.12 * h / 3.0, 0.02, h, Vector3(0, h * 0.5, 0), tm, Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)), 6, 1.0)
		for k in 3:
			var y := h * rng.randf_range(0.45, 0.85)
			cilindro(t, 0.04, 0.005, h * 0.3, Vector3(0, y, 0), tm, Vector3(0, rng.randf() * 360, rng.randf_range(35, 60)), 5, 0.8)

# ------------------------------------------------------------------ pontos de interesse em 3 profundidades
func _galho(pai: Node3D, a: Vector3, d: Vector3, L: float, r: float, nivel: int, mat: Material, rr: RandomNumberGenerator, px := 1.2) -> void:
	# galho torto: 3 gomos com desvio; filhos nos 2 últimos gomos
	var p := a
	var dir := d.normalized()
	for g in 3:
		var dd := (dir + Vector3(rr.randf_range(-0.35, 0.35), rr.randf_range(-0.15, 0.25), rr.randf_range(-0.35, 0.35))).normalized()
		var q := p + dd * L / 3.0
		var r0 := r * (1.0 - g / 3.0 * 0.6); var r1 := r * (1.0 - (g + 1) / 3.0 * 0.6)
		var mi := cilindro(pai, r0, r1, L / 3.0 + r0, (p + q) * 0.5, mat, Vector3.ZERO, 6, px)
		mi.basis = Basis(Quaternion(Vector3.UP, dd)) * Basis.from_scale(Vector3.ONE)
		if nivel > 0 and g >= 1:
			for c in 2:
				var nd := (dd + Vector3(rr.randf_range(-1, 1), rr.randf_range(-0.2, 0.6), rr.randf_range(-1, 1))).normalized()
				_galho(pai, q, nd, L * rr.randf_range(0.45, 0.65), r1 * 0.7, nivel - 1, mat, rr, px * 0.85)
		p = q
		dir = dd

func arvore_forca() -> void:
	# carvalho morto da encruzilhada com uma gaiola de enforcado, corda e corvos (8 m de distância da ação)
	var rr := RandomNumberGenerator.new(); rr.seed = 404
	var r := Node3D.new(); r.position = Vector3(ARVORE.x, altura(ARVORE.x, ARVORE.z) - 0.1, ARVORE.z); add_child(r)
	var tm := mat_mundo("", 0.0, 0.0, 1.0, 0.35)
	cilindro(r, 0.42, 0.26, 3.6, Vector3(0, 1.8, 0), tm, Vector3(0, 0, -4), 9, 1.8)
	var topo := Vector3(0.15, 3.5, 0.0)
	for k in 4:
		var d := Vector3(cos(k * 1.7 + 0.4), 0.55 + 0.25 * rr.randf(), sin(k * 1.7 + 0.4))
		_galho(r, topo - Vector3(0, k * 0.35, 0), d, 2.6 + rr.randf(), 0.13, 2, tm, rr, 1.2)
	# galho da forca, horizontal para a estrada, com corda e gaiola
	var braco := cilindro(r, 0.1, 0.06, 2.8, Vector3(1.3, 2.9, 0.4), tm, Vector3(0, 0, 84), 6, 1.3)
	var g := Node3D.new(); g.position = Vector3(2.4, 2.9, 0.45); g.scale = Vector3.ONE * 1.35; r.add_child(g)
	cilindro(g, 0.012, 0.012, 0.7, Vector3(0, -0.35, 0), tm, Vector3.ZERO, 4, 0.8)
	var ferro := mat_mundo("", 0.0, 0.0, 1.6, 0.25)
	for k in 7:
		var a := k * TAU / 7.0
		cilindro(g, 0.012, 0.012, 1.0, Vector3(cos(a) * 0.26, -1.2, sin(a) * 0.26), ferro, Vector3.ZERO, 4, 0.8)
	cilindro(g, 0.28, 0.28, 0.05, Vector3(0, -0.7, 0), ferro, Vector3.ZERO, 10, 0.9)
	cilindro(g, 0.28, 0.28, 0.05, Vector3(0, -1.7, 0), ferro, Vector3.ZERO, 10, 0.9)
	prisma(g, Vector3(0.56, 0.25, 0.56), Vector3(0, -0.55, 0), ferro, Vector3.ZERO, 0.9)
	# o preso: um crânio e costelas de tinta
	var osso := mat_mundo("#E9DFC9", 0.8, 0.0, 0.2, 0.2)
	var cab := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.12; sm.height = 0.24; cab.mesh = sm
	cab.material_override = osso; cab.position = Vector3(0.05, -1.05, 0); g.add_child(cab); contorno(cab, 1.0)
	caixa(g, Vector3(0.2, 0.3, 0.12), Vector3(0.02, -1.35, 0), osso, Vector3(0, 0, 12), 1.0)
	enforcados.append(g)
	gaiola = g

func forte() -> void:
	# forte em ruína no morro (24 m): muralha partida, torre alta rachada e o portão escuro da masmorra
	var r := Node3D.new(); r.position = Vector3(FORTE.x, altura(FORTE.x, FORTE.z) - 0.2, FORTE.z); r.rotation_degrees = Vector3(0, -62, 0); add_child(r)
	var pd := mat_mundo("", 0.0, 0.0, 0.25, 0.55)
	var rr := RandomNumberGenerator.new(); rr.seed = 88
	# muralha em U com ameias quebradas
	for lado in [[Vector3(0, 0, 0), 0.0, 9.0], [Vector3(-4.5, 0, -3.5), 90.0, 7.0], [Vector3(4.5, 0, -3.5), 90.0, 7.0]]:
		var w := Node3D.new(); w.position = lado[0]; w.rotation_degrees = Vector3(0, lado[1], 0); r.add_child(w)
		var L: float = lado[2]
		var x := -L * 0.5
		while x < L * 0.5:
			var seg := rr.randf_range(0.9, 1.6)
			var hh := rr.randf_range(2.2, 3.6) if rr.randf() > 0.25 else rr.randf_range(0.6, 1.4)
			caixa(w, Vector3(seg, hh, 0.9), Vector3(x + seg * 0.5, hh * 0.5, 0), pd, Vector3(0, 0, rr.randf_range(-2, 2)), 1.2)
			if hh > 2.0 and rr.randf() > 0.4:
				caixa(w, Vector3(0.4, 0.5, 0.9), Vector3(x + seg * 0.3, hh + 0.25, 0), pd, Vector3.ZERO, 1.0)
			x += seg + (rr.randf_range(0.2, 0.9) if rr.randf() > 0.7 else 0.0)
	# torre alta (verticalidade da gravura: 13 m), com o topo quebrado em degrau e janelas de seteira
	var t := Node3D.new(); t.position = Vector3(3.6, 0, -1.2); r.add_child(t)
	cilindro(t, 1.7, 1.45, 10.0, Vector3(0, 5.0, 0), pd, Vector3.ZERO, 12, 1.4)
	caixa(t, Vector3(2.4, 2.4, 1.4), Vector3(-0.4, 11.0, 0.2), pd, Vector3(0, 0, 9), 1.3)
	caixa(t, Vector3(1.0, 1.4, 1.0), Vector3(0.6, 12.6, 0.4), pd, Vector3(0, 0, -6), 1.2)
	for k in 3:
		caixa(t, Vector3(0.14, 0.7, 0.2), Vector3(0, 3.0 + k * 2.6, 1.55), mat_mundo("", 0.0, 0.0, 3.5, 0.2), Vector3.ZERO, 0.0)
	# portão da masmorra: arco escuro com luz fraca lá dentro (a masmorra se abre na paisagem)
	var pg := Node3D.new(); pg.position = Vector3(-1.2, 0, 0.1); r.add_child(pg)
	caixa(pg, Vector3(0.8, 3.2, 1.2), Vector3(-1.2, 1.6, 0), pd, Vector3.ZERO, 1.3)
	caixa(pg, Vector3(0.8, 3.2, 1.2), Vector3(1.2, 1.6, 0), pd, Vector3.ZERO, 1.3)
	prisma(pg, Vector3(3.2, 1.0, 1.2), Vector3(0, 3.7, 0), pd, Vector3.ZERO, 1.3)
	caixa(pg, Vector3(1.6, 2.6, 0.3), Vector3(0, 1.3, -0.2), mat_mundo("", 0.0, 0.0, 4.0, 0.2), Vector3.ZERO, 0.0)
	portao_luz = r.to_global(Vector3(-1.2, 1.0, 0.8))
	# escombros
	for k in 9:
		pedra(r.to_global(Vector3(rr.randf_range(-6, 6), 0, rr.randf_range(0.8, 3.5))), Vector3(0.5, 0.3, 0.4) * rr.randf_range(0.7, 1.6), 300 + k, "", 1.2)

func moinho3d() -> void:
	# moinho de poste queimado no alto da colina (36 m), pás quebradas girando devagar contra o rasgo âmbar
	var r := Node3D.new(); r.position = Vector3(MOINHO.x, altura(MOINHO.x, MOINHO.z), MOINHO.z); r.rotation_degrees = Vector3(0, -50, 0); r.scale = Vector3.ONE * 1.35; add_child(r)
	var q := mat_mundo("", 0.0, 0.0, 1.1, 0.4)
	for k in 4:
		var a := k * PI * 0.5 + 0.4
		cilindro(r, 0.12, 0.1, 3.4, Vector3(cos(a) * 1.0, 1.4, sin(a) * 1.0), q, Vector3(sin(a) * 18, 0, -cos(a) * 18), 6, 1.2)
	cilindro(r, 0.3, 0.28, 4.0, Vector3(0, 2.4, 0), q, Vector3.ZERO, 8, 1.3)
	caixa(r, Vector3(2.8, 3.6, 2.4), Vector3(0, 5.6, 0), q, Vector3(0, 0, 5), 1.4)
	prisma(r, Vector3(3.2, 1.6, 2.7), Vector3(0, 8.2, 0), q, Vector3(0, 0, 5), 1.4)
	moinho_pas = Node3D.new(); moinho_pas.position = Vector3(0.2, 6.2, 1.4); r.add_child(moinho_pas)
	for i in 4:
		var p := Node3D.new(); p.rotation_degrees = Vector3(0, 0, i * 90 + 12); moinho_pas.add_child(p)
		var L := 5.2 if i != 2 else 2.0
		caixa(p, Vector3(0.22, L, 0.16), Vector3(0, L * 0.5, 0), q, Vector3.ZERO, 1.2)
		if i != 2:
			for j in 6:
				if (i == 1 and j > 3):
					continue
				caixa(p, Vector3(1.0, 0.08, 0.08), Vector3(0.45, 1.0 + j * 0.7, 0), q, Vector3.ZERO, 0.8)

func cerca() -> void:
	# cerca de varas na margem norte, com brecha onde a estrada passa; mourões tortos e varas caídas
	var tm := mat_mundo("#6E4A33", 0.5, 0.0, 0.6, 0.3)
	var rr := RandomNumberGenerator.new(); rr.seed = 61
	var x := -26.0
	var prev := Vector3.ZERO
	while x < 22.0:
		var z := z_norte(x) - 3.2 + 0.4 * sin(x * 0.4)
		var p := Vector3(x, altura(x, z), z)
		var na_brecha := dist_estrada(x, z) < 2.2
		if not na_brecha:
			var inc := Vector3(rr.randf_range(-12, 12), 0, rr.randf_range(-14, 14))
			if rr.randf() < 0.15: inc.z = rr.randf_range(25, 50)
			cilindro(self, 0.07, 0.05, 1.3, p + Vector3(0, 0.6, 0), tm, inc, 6, 1.1)
			if prev != Vector3.ZERO and rr.randf() > 0.2:
				for y in [0.45, 0.95]:
					var a := prev + Vector3(0, y, 0); var b := p + Vector3(0, y + rr.randf_range(-0.1, 0.1), 0)
					var mi := cilindro(self, 0.03, 0.03, a.distance_to(b), (a + b) * 0.5, tm, Vector3.ZERO, 5, 0.9)
					mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
			prev = p
		else:
			prev = Vector3.ZERO
		x += rr.randf_range(1.5, 2.1)

func estacas(pontos: Array) -> void:
	# primeiro plano: estacas de cerco afiadas e cardos secos nas bordas da tela (oclusores, dão a escala)
	var tm := mat_mundo("#6E4A33", 0.7, 0.0, 1.4, 0.25)
	var rr := RandomNumberGenerator.new(); rr.seed = 13
	for pt in pontos:
		var c: Vector3 = pt
		c.y = altura(c.x, c.z)
		for k in 6:
			var h := rr.randf_range(1.4, 2.6)
			var base := c + Vector3(rr.randf_range(-1.0, 1.0), -0.1, rr.randf_range(-0.6, 0.6))
			var inc := Vector3(rr.randf_range(-35, -15), rr.randf() * 360, rr.randf_range(-10, 10))
			var e := Node3D.new(); e.position = base; e.rotation_degrees = inc; add_child(e)
			cilindro(e, 0.09, 0.07, h, Vector3(0, h * 0.5, 0), tm, Vector3.ZERO, 6, 1.6)
			cilindro(e, 0.07, 0.0, 0.35, Vector3(0, h + 0.17, 0), tm, Vector3.ZERO, 6, 1.6)
		for k in 5:
			var b := c + Vector3(rr.randf_range(-1.6, 1.6), 0, rr.randf_range(-1, 1))
			var h := rr.randf_range(0.6, 1.2)
			cilindro(self, 0.012, 0.006, h, b + Vector3(0, h * 0.5, 0), tm, Vector3(rr.randf_range(-15, 15), 0, rr.randf_range(-15, 15)), 4, 1.0)

func arvore_perto(p: Vector3) -> void:
	# árvore morta junto da câmera: os galhos entram pelo canto de cima (moldura de primeiro plano)
	var rr := RandomNumberGenerator.new(); rr.seed = 777
	var r := Node3D.new(); r.position = Vector3(p.x, altura(p.x, p.z) - 0.2, p.z); add_child(r)
	var tm := mat_mundo("", 0.0, 0.0, 2.2, 0.5)
	_galho(r, Vector3.ZERO, Vector3(0.15, 1, 0.0), 6.5, 0.4, 0, tm, rr, 2.2)
	for k in 3:
		var d := Vector3(1.0, 0.25 + 0.15 * k, -0.3 + 0.3 * k)
		_galho(r, Vector3(0.4, 5.0 + k * 0.6, 0.0), d, 4.2, 0.12, 2, tm, rr, 2.0)

func estandarte_queimado(p: Vector3, inc: float, seed: int) -> void:
	# estandarte da guerra antiga, queimado e rasgado, num pique fincado
	var rr := RandomNumberGenerator.new(); rr.seed = seed
	var r := Node3D.new(); r.position = Vector3(p.x, altura(p.x, p.z) - 0.05, p.z); r.rotation_degrees = Vector3(0, rr.randf() * 360, inc); add_child(r)
	var tm := mat_mundo("", 0.0, 0.0, 1.4, 0.25)
	cilindro(r, 0.035, 0.03, 3.2, Vector3(0, 1.6, 0), tm, Vector3.ZERO, 5, 1.0)
	cilindro(r, 0.025, 0.025, 1.0, Vector3(-0.45, 3.0, 0), tm, Vector3(0, 0, 90), 5, 0.9)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	for i in n:
		var x0 := -0.95 * i / n; var x1 := -0.95 * (i + 1) / n
		var y0 := -0.9 - rr.randf_range(0.0, 0.6) * (0.4 + i / float(n)); var y1 := -0.9 - rr.randf_range(0.0, 0.6) * (0.4 + (i + 1) / float(n))
		for q in [Vector3(x0, 0, 0), Vector3(x1, 0, 0), Vector3(x1, y1, 0.05 * sin(i)), Vector3(x0, 0, 0), Vector3(x1, y1, 0.05 * sin(i)), Vector3(x0, y0, 0.05 * sin(i - 1))]:
			st.set_normal(Vector3(0, 0, 1)); st.add_vertex(q)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.position = Vector3(0, 3.0, 0)
	var pano := mat_mundo("#6E4A33", 0.6, 0.0, 1.0, 0.25)
	mi.material_override = pano
	r.add_child(mi)
	contorno(mi, 1.0)

# ------------------------------------------------------------------ horizonte (cartões de horizonte = geometria distante)
func no_horizonte(cam: Camera3D, sx: float, sy: float, dist: float) -> Vector3:
	var vp := cam.get_viewport().get_visible_rect().size
	return cam.project_position(Vector2(sx * vp.x, sy * vp.y), dist)

func vp_h(cam: Camera3D) -> float:
	return cam.get_viewport().get_visible_rect().size.y

func px_m(cam: Camera3D, dist: float) -> float:
	var vp := cam.get_viewport().get_visible_rect().size
	return 2.0 * dist * tan(deg_to_rad(cam.fov) * 0.5) / vp.y

func mat_silhueta(tom: float, pe: float) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = load(SH + "silhueta.gdshader")
	m.set_shader_parameter("tom", tom); m.set_shader_parameter("pe", pe)
	return m

func horizonte(cam: Camera3D, hy: float) -> void:
	# os cartões de horizonte andam com a câmera (estão "no infinito"): ficam num nó que a cena desloca junto.
	# 4 planos de colina, do mais perto (mais tinta, crista de 2 px) ao mais longe (quase papel, crista de 1 px);
	# o pé de cada plano se desfaz em névoa. Nada de hachura vertical (lia como cerca).
	hz = Node3D.new(); add_child(hz); hz_cam0 = cam.global_position
	var vp := cam.get_viewport().get_visible_rect().size
	for camada in 4:
		var d: float = [80.0, 150.0, 280.0, 520.0][camada]
		var k := px_m(cam, d)
		var raiz := Node3D.new(); hz.add_child(raiz)
		var base := no_horizonte(cam, 0.5, hy + 0.006 - camada * 0.011, d)
		raiz.position = base
		raiz.look_at(Vector3(cam.global_position.x, base.y, cam.global_position.z), Vector3.UP)
		raiz.rotate_object_local(Vector3.UP, PI)
		var w := vp.x * k * 2.2
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var nn := 120
		var hh: float = [0.035, 0.05, 0.06, 0.045][camada] * vp.y * k
		var nzh := FastNoiseLite.new(); nzh.seed = 200 + camada; nzh.frequency = [7.0, 5.0, 3.5, 2.5][camada]
		var bt := -hh * 6.0
		var ys := PackedFloat32Array()
		for i in nn + 1:
			var u := float(i) / nn
			ys.append(hh * (0.45 + 0.6 * nzh.get_noise_1d(u) + 0.25 * nzh.get_noise_1d(u * 4.0 + 9.0)))
		for i in nn:
			var x0 := -w * 0.5 + w * i / nn; var x1 := -w * 0.5 + w * (i + 1) / nn
			var y0 := ys[i]; var y1 := ys[i + 1]
			var pe := -hh * 0.6
			var vv := func(y: float, yc: float) -> float: return clampf((y - pe) / maxf(yc - pe, 0.001), 0.0, 1.0)
			for q in [[Vector3(x0, bt, 0), 0.0], [Vector3(x1, y1, 0), 1.0], [Vector3(x1, bt, 0), 0.0], [Vector3(x0, bt, 0), 0.0], [Vector3(x0, y0, 0), 1.0], [Vector3(x1, y1, 0), 1.0]]:
				var pq: Vector3 = q[0]
				st.set_uv(Vector2(0, vv.call(pq.y, maxf(y0, y1)) if q[1] < 0.5 else 1.0))
				st.set_normal(Vector3(0, 0, 1)); st.add_vertex(pq)
		var mi := MeshInstance3D.new(); mi.mesh = st.commit()
		mi.material_override = mat_silhueta([0.62, 0.42, 0.26, 0.13][camada], [0.12, 0.06, 0.03, 0.0][camada])
		# crista em tinta, mais fina ao longe
		var sr := SurfaceTool.new(); sr.begin(Mesh.PRIMITIVE_TRIANGLES)
		var lw: float = k * [2.2, 1.6, 1.2, 0.9][camada]
		for i in nn:
			var x0 := -w * 0.5 + w * i / nn; var x1 := -w * 0.5 + w * (i + 1) / nn
			var y0 := ys[i]; var y1 := ys[i + 1]
			for q in [Vector3(x0, y0 - lw, 0.01), Vector3(x1, y1, 0.01), Vector3(x1, y1 - lw, 0.01), Vector3(x0, y0 - lw, 0.01), Vector3(x0, y0, 0.01), Vector3(x1, y1, 0.01)]:
				sr.add_vertex(q)
		var crista := MeshInstance3D.new(); crista.mesh = sr.commit()
		crista.material_override = mat_silhueta([1.0, 0.85, 0.6, 0.4][camada], [1.0, 0.85, 0.6, 0.4][camada])
		crista.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(crista)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
	# Prensa Real a 3 km (terço superior), Campanário Andante a 1,2 km à esquerda, fumaças das forjas à direita
	_prensa(cam, hy)
	_campanario(cam, hy)
	_fumacas(cam, hy)

func _moinho(cam: Camera3D, raiz: Node3D, hh: float, k: float, w: float) -> void:
	# moinho de poste queimado numa colina (150 m), pás girando devagar
	var m := Node3D.new()
	m.position = Vector3(w * 0.17, hh * 0.85, 0)
	var s := k * 52.0
	m.scale = Vector3(s, s, s)
	raiz.add_child(m)
	var q := mat_mundo("", 0.0, 0.66, 0.4, 0.06)
	cilindro(m, 0.05, 0.04, 0.6, Vector3(0, 0.3, 0), q, Vector3.ZERO, 6, 0.9)
	caixa(m, Vector3(0.4, 0.5, 0.36), Vector3(0, 0.82, 0), q, Vector3(0, 0, 4), 0.9)
	prisma(m, Vector3(0.46, 0.22, 0.4), Vector3(0, 1.18, 0), q, Vector3(0, 0, 4), 0.9)
	moinho_pas = Node3D.new(); moinho_pas.position = Vector3(0.02, 0.9, 0.22); m.add_child(moinho_pas)
	for i in 4:
		var p := Node3D.new(); p.rotation_degrees = Vector3(0, 0, i * 90 + 12); moinho_pas.add_child(p)
		caixa(p, Vector3(0.03, 0.6, 0.02), Vector3(0, 0.32, 0), q, Vector3.ZERO, 0.8)
		if i != 2:
			for j in 4:
				caixa(p, Vector3(0.14, 0.012, 0.012), Vector3(0.06, 0.15 + j * 0.13, 0), q, Vector3.ZERO, 0.0)

func _prensa(cam: Camera3D, hy: float) -> void:
	var d := 900.0
	var k := px_m(cam, d)
	var r := Node3D.new(); hz.add_child(r)
	r.position = no_horizonte(cam, 0.66, hy - 0.02, d)
	r.look_at(Vector3(cam.global_position.x, r.position.y, cam.global_position.z), Vector3.UP)
	var s := k * vp_h(cam) * 0.2    # altura na tela ~20%
	r.scale = Vector3(s, s, s)
	var m := mat_silhueta(0.3, 0.3)
	# torre em degraus alongada para cima, com contrafortes, a viga da prensa e o parafuso gigante
	caixa(r, Vector3(0.34, 0.5, 0.3), Vector3(0, 0.25, 0), m, Vector3.ZERO, 0.6)
	caixa(r, Vector3(0.26, 0.32, 0.24), Vector3(0, 0.66, 0), m, Vector3.ZERO, 0.6)
	caixa(r, Vector3(0.18, 0.18, 0.18), Vector3(0, 0.9, 0), m, Vector3.ZERO, 0.6)
	for sx in [-1, 1]:
		caixa(r, Vector3(0.05, 0.75, 0.05), Vector3(sx * 0.2, 0.38, 0.1), m, Vector3(0, 0, sx * -6), 0.5)
		caixa(r, Vector3(0.04, 0.3, 0.06), Vector3(sx * 0.16, 1.12, 0), m, Vector3.ZERO, 0.5)
	caixa(r, Vector3(0.46, 0.05, 0.08), Vector3(0, 1.27, 0), m, Vector3.ZERO, 0.6)
	prensa_rosca = Node3D.new(); prensa_rosca.position = Vector3(0, 1.0, 0); r.add_child(prensa_rosca)
	cilindro(prensa_rosca, 0.035, 0.035, 0.5, Vector3(0, 0.15, 0), m, Vector3.ZERO, 8, 0.5)
	for i in 9:
		caixa(prensa_rosca, Vector3(0.13, 0.014, 0.03), Vector3(0, -0.05 + i * 0.045, 0), m, Vector3(0, i * 40, 8), 0.0)
	caixa(prensa_rosca, Vector3(0.32, 0.03, 0.03), Vector3(0, 0.42, 0), m, Vector3.ZERO, 0.5)

func _campanario(cam: Camera3D, hy: float) -> void:
	var d := 400.0
	var k := px_m(cam, d)
	campanario = Node3D.new(); hz.add_child(campanario)
	campanario.position = no_horizonte(cam, 0.2, hy - 0.012, d)
	campanario.look_at(Vector3(cam.global_position.x, campanario.position.y, cam.global_position.z), Vector3.UP)
	var s := k * vp_h(cam) * 0.13
	campanario.scale = Vector3(s, s, s)
	var m := mat_silhueta(0.42, 0.42)
	caixa(campanario, Vector3(0.22, 0.6, 0.2), Vector3(0, 0.55, 0), m, Vector3(0, 0, -3), 0.7)
	caixa(campanario, Vector3(0.26, 0.2, 0.24), Vector3(0, 0.94, 0), m, Vector3(0, 0, -3), 0.7)
	prisma(campanario, Vector3(0.28, 0.32, 0.26), Vector3(0, 1.2, 0), m, Vector3(0, 0, -3), 0.7)
	# sino visível na janela do campanário
	cilindro(campanario, 0.06, 0.03, 0.08, Vector3(0, 0.92, 0.1), mat_silhueta(0.8, 0.8), Vector3.ZERO, 8, 0.0)
	# 4 varais compridos e a fila de carregadores (pontinhos de tinta)
	for sz in [-1, 1]:
		caixa(campanario, Vector3(0.9, 0.025, 0.025), Vector3(0, 0.26, sz * 0.08), m, Vector3.ZERO, 0.4)
	var tm := mat_silhueta(0.6, 0.6)
	for i in 14:
		var x := -0.42 + i * 0.065
		caixa(campanario, Vector3(0.025, 0.24, 0.025), Vector3(x, 0.14, 0.12 if i % 2 == 0 else -0.12), tm, Vector3.ZERO, 0.0)

func _fumacas(cam: Camera3D, hy: float) -> void:
	for i in 2:
		var d := 600.0
		var k := px_m(cam, d)
		var r := MeshInstance3D.new()
		var qm := QuadMesh.new()
		var h := k * vp_h(cam) * 0.11
		qm.size = Vector2(h * 0.45, h)
		r.mesh = qm
		hz.add_child(r)
		r.position = no_horizonte(cam, [0.78, 0.92][i], hy - 0.01, d) + Vector3(0, h * 0.5, 0)
		r.look_at(cam.global_position, Vector3.UP)
		r.rotate_object_local(Vector3.UP, PI)
		var m := ShaderMaterial.new(); m.shader = load(SH + "aquatinta.gdshader")
		m.set_shader_parameter("modo", 1)
		m.set_shader_parameter("cor", lin(["#E8B23A", "#D9472B"][i]))
		m.set_shader_parameter("cor2", lin("#231C17"))
		m.set_shader_parameter("dens", 0.75)
		m.set_shader_parameter("curvar", 0.0)
		m.set_shader_parameter("fase", i * 3.0)
		r.material_override = m
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		forjas.append(r)

# ------------------------------------------------------------------ céu, névoa, chuva, cinzas
func ceu(env: Environment) -> void:
	var sk := Sky.new()
	ceu_mat = ShaderMaterial.new()
	ceu_mat.shader = load(SH + "ceu.gdshader")
	sk.sky_material = ceu_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sk
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED

func camada_nevoa(y: float, dens: float, esc: float, deriva: Vector2, area: Vector2, centro: Vector3, cor: String, cor2: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = area
	mi.mesh = pm
	mi.position = centro + Vector3(0, y, 0)
	var m := ShaderMaterial.new(); m.shader = load(SH + "aquatinta.gdshader")
	m.set_shader_parameter("modo", 0)
	m.set_shader_parameter("cor", lin(cor))
	m.set_shader_parameter("cor2", lin(cor2))
	m.set_shader_parameter("dens", dens)
	m.set_shader_parameter("escala", esc)
	m.set_shader_parameter("deriva", deriva)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 60.0
	add_child(mi)
	nevoas.append(mi)
	return mi

func nevoa(n_camadas := 3) -> void:
	# névoa em camadas que engrossa com a distância: rio (joelho), margem norte, vale do forte, várzea ao longe
	camada_nevoa(0.1, 0.22, 0.3, Vector2(0.9, 0.05), Vector2(80, 7), Vector3(0, 0, -5.0), "#E9DFC9", "#8E97A3")
	camada_nevoa(0.35, 0.26, 0.18, Vector2(0.6, -0.08), Vector2(90, 7), Vector3(0, 0, -11.0), "#E9DFC9", "#E9DFC9")
	if n_camadas > 2:
		camada_nevoa(0.9, 0.34, 0.12, Vector2(0.35, 0.02), Vector2(110, 14), Vector3(6, 0, -22.0), "#E9DFC9", "#E3C99A")
		camada_nevoa(2.0, 0.42, 0.08, Vector2(0.25, 0.0), Vector2(160, 24), Vector3(6, 0, -42.0), "#E9DFC9", "#E9DFC9")

func corvos(centro: Vector3, n: int, raio: float, alt: float) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# corvo em M: corpo e duas asas de tinta
	for q in [Vector3(0, 0, -0.12), Vector3(-0.32, 0.06, 0.02), Vector3(0, 0, 0.06), Vector3(0, 0, -0.12), Vector3(0, 0, 0.06), Vector3(0.32, 0.06, 0.02),
			Vector3(-0.32, 0.06, 0.02), Vector3(-0.5, -0.05, 0.1), Vector3(-0.2, 0.03, 0.05), Vector3(0.32, 0.06, 0.02), Vector3(0.2, 0.03, 0.05), Vector3(0.5, -0.05, 0.1)]:
		st.add_vertex(q)
	var mesh := st.commit()
	var m := ShaderMaterial.new(); m.shader = load(SH + "fx.gdshader"); m.set_shader_parameter("cor", Color("#231C17"))
	for i in n:
		var c := MeshInstance3D.new(); c.mesh = mesh; c.material_override = m
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(c)
		c.set_meta("c", centro); c.set_meta("r", raio * rng.randf_range(0.6, 1.2)); c.set_meta("a", alt + rng.randf_range(-0.8, 1.2)); c.set_meta("f", rng.randf() * TAU)
		corvo_l.append(c)

func particulas(n_chuva := 1400, n_cinza := 260) -> void:
	chuva_mm = _mm_part(n_chuva, 0)
	cinza_mm = _mm_part(n_cinza, 1)

func _mm_part(n: int, modo: int) -> MultiMeshInstance3D:
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	qm.center_offset = Vector3(0, 0.5, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = qm
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := ShaderMaterial.new(); m.shader = load(SH + "chuva.gdshader")
	m.set_shader_parameter("modo", modo)
	m.set_shader_parameter("tinta", lin("#231C17"))
	m.set_shader_parameter("papel", lin("#8E97A3"))
	m.set_shader_parameter("papel2", lin("#E9DFC9"))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 10000.0
	add_child(mi)
	return mi

func passo(t: float) -> void:
	for i in corvo_l.size():
		var c: MeshInstance3D = corvo_l[i]
		var a: float = t * (0.55 + 0.1 * i) + float(c.get_meta("f"))
		var ct: Vector3 = c.get_meta("c")
		c.position = ct + Vector3(cos(a) * float(c.get_meta("r")), float(c.get_meta("a")) + 0.3 * sin(a * 2.0), sin(a) * float(c.get_meta("r")))
		c.rotation.y = -a
		var bat := int(t * 60.0 / 5.0 + i) % 3
		c.scale = Vector3(1.0, [1.0, -0.6, 0.2][bat], 1.0) * 1.3
	if moinho_pas:
		moinho_pas.rotation.z = -t * 0.35
	if prensa_rosca:
		prensa_rosca.rotation.y = t * 0.25
	for i in enforcados.size():
		enforcados[i].rotation.x = sin(t * 1.3 + i * 1.7) * 0.12
