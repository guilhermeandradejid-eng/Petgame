extends Node3D
# A Mata de Lume vista do terraço da Poça: terreno contínuo (terraço, degraus, floresta de fungos, Poço, parede
# distante), rochas, lajes, musgo e grama em MultiMesh, fungos acesos, a coluna de pedra com a estaca da guilda,
# os fios de lanternas, o acampamento rival, a Cascata, a Coluna do Meio-Dia, o Sino pela fenda e as 3 lâminas.
const A := "res://assets/"
static var sh_cache := {}
var pc := false
var lite := false
var dados := {}
var agua_mat: ShaderMaterial
var laminas := []
var feixe: MeshInstance3D
var fogs := []
const COLUNA := Vector3(6.0, 0.0, -118.0)
const POCA := Vector3(0.3, -0.07, 0.2)

static func sh(n: String) -> Shader:
	if not sh_cache.has(n):
		sh_cache[n] = load("res://shaders/%s.gdshader" % n)
	return sh_cache[n]

static func bl(p: Array) -> Vector3:
	return Vector3(p[0], p[2], -p[1])

static func mat_para(mn: String, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	match mn:
		"resina":
			m.shader = sh("resina")
		"emis":
			m.shader = sh("emis")
		"metal":
			m.shader = sh("mini"); m.set_shader_parameter("metal", 1.0)
		"mini":
			m.shader = sh("mini")
		_:
			m.shader = sh("terreno")
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m

static func malha(n: String, extra := {}, forcar := "") -> ArrayMesh:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(A + "glb/" + n + ".glb"), st)
	var sc := doc.generate_scene(st) as Node3D
	var mi: MeshInstance3D = sc.find_children("*", "MeshInstance3D", true, false)[0]
	var m: ArrayMesh = mi.mesh.duplicate()
	for i in m.get_surface_count():
		var mn: String = m.surface_get_material(i).resource_name if m.surface_get_material(i) else "cor"
		if forcar != "" and mn == "cor":
			mn = forcar
		m.surface_set_material(i, mat_para(mn, extra))
	sc.free()
	return m

func inst(mesh: Mesh, pos: Vector3, rot := 0.0, s := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = rot
	mi.scale = Vector3.ONE * s
	mi.extra_cull_margin = 2000.0
	add_child(mi)
	return mi

func multi(mesh: Mesh, pts: Array, escala := 1.0, cast := true, filtro := -1) -> MultiMeshInstance3D:
	var sel := []
	for p in pts:
		if filtro < 0 or int(p[5]) == filtro:
			sel.append(p)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = sel.size()
	for i in sel.size():
		var p: Array = sel[i]
		var b := Basis(Vector3.UP, p[3]).scaled(Vector3.ONE * p[4] * escala)
		mm.set_instance_transform(i, Transform3D(b, bl(p)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (cast and pc) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi

func construir(opts := {}) -> void:
	pc = opts.get("pc", false)
	lite = opts.get("lite", false)
	dados = JSON.parse_string(FileAccess.get_file_as_string(A + "mundo.json"))
	inst(malha("terraco", {"esc": 1.0, "tom": 0.8, "placas": 0.0, "curv_k": 1.0}), Vector3.ZERO)
	inst(malha("abismo", {"esc": 0.06, "curv_k": 2.5, "tom": 1.0}), Vector3.ZERO)
	for k in 3:
		multi(malha("rocha%d" % k, {"esc": 1.2, "curv_k": 3.0, "tom": 0.8}), dados["pedra"], 1.0, true, k)
		multi2(malha("ladrilho%d" % k, {"esc": 2.0, "curv_k": 2.0, "tom": 0.62}), dados["ruina"], k)
		multi2(malha("fungo%d" % k, {"esc": 2.0, "energia": 0.85, "dessat": 0.38, "base_acesa": 0.45}, "mini"), dados["fungo_peq"], k)
		multi(malha("fungo%d" % k, {"esc": 0.3, "energia": 1.3, "base_acesa": 0.5, "nevoa_k": 0.45, "dessat": 0.3}, "mini"), dados["fungo_gig"], 1.0, false, k)
	multi2(malha("coluna_ruina", {"esc": 1.5, "curv_k": 2.0, "tom": 0.6}), dados["colunas"], 0, true)
	marcos()
	multi(malha("musgo", {"altura": 0.08, "vento_k": 0.3}, "tufo"), dados["musgo"], 1.0, false)
	var gm := malha("grama", {"altura": 0.09, "vento_k": 1.0}, "tufo")
	multi(gm, dados["grama"], 1.0, false)
	for i in gm.get_surface_count():
		gm.surface_get_material(i).shader = sh("tufo")
	# o Sino de Thessimor, 500 m abaixo, visto pela fenda (a escala é a do Sino, a distância a da fenda)
	var sino := inst(malha("sino", {}, "mini"), Vector3(7.2, -46.0, -16.0), 0.0, 7.0)
	sino.set_surface_override_material(0, null)
	var smat := ShaderMaterial.new(); smat.shader = sh("emis"); smat.set_shader_parameter("energia", 1.4)
	smat.set_shader_parameter("apagado", Color(0.5, 0.3, 0.12))
	for i in sino.mesh.get_surface_count():
		sino.set_surface_override_material(i, smat)
	luz_cartao(Vector3(7.2, -48.0, -16.0), Color(0.85, 0.55, 0.22), 18.0, 0.55)
	# a poça
	var ag := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(10.0, 7.0)
	ag.mesh = pm
	ag.position = POCA
	agua_mat = ShaderMaterial.new(); agua_mat.shader = sh("agua")
	agua_mat.set_shader_parameter("centro", POCA)
	ag.material_override = agua_mat
	add_child(ag)
	lanternas()
	cascata()
	goteiras()
	coluna_luz()
	laminas_nevoa()
	if pc:
		# [PC] névoa volumétrica de altura nos degraus e no penhasco (abaixo e atrás do plano de jogo)
		for d in [[Vector3(0, -7.0, -16.0), Vector3(70, 12, 18), 0.06], [Vector3(-8, -3.5, -9.5), Vector3(40, 4, 6), 0.035], [Vector3(14, -10.0, -30.0), Vector3(60, 16, 20), 0.05]]:
			var fv := FogVolume.new()
			fv.size = d[1]
			fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
			var fm := FogMaterial.new(); fm.density = d[2]; fm.albedo = Color(0.45, 0.52, 0.62); fm.emission = Color(0.015, 0.025, 0.035)
			fm.height_falloff = 0.08
			fv.material = fm
			fv.position = d[0]
			add_child(fv)

func multi2(mesh: Mesh, pts: Array, filtro := -1, altura := false) -> MultiMeshInstance3D:
	# instâncias com inclinação: [x, y, z, yaw, s, k, eixo_x, eixo_z, ângulo] (eixo no plano do chão, Godot)
	var sel := []
	for p in pts:
		if filtro < 0 or int(p[5]) == filtro:
			sel.append(p)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = sel.size()
	for i in sel.size():
		var p: Array = sel[i]
		var sc := Vector3.ONE * float(p[4])
		if altura:
			sc = Vector3(1.0, float(p[4]), 1.0)
		var b := Basis(Vector3.UP, p[3]).scaled(sc)
		var ax := Vector3(float(p[6]), 0.0, float(p[7]))
		if ax.length() > 0.01 and absf(float(p[8])) > 0.0:
			b = Basis(ax.normalized(), float(p[8])) * b
		mm.set_instance_transform(i, Transform3D(b, bl(p)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if pc else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi

var postes := []
var cortinas := []
func marcos() -> void:
	# ponte de tronco sobre a fenda, guincho da guilda na beira, postes de lanterna nas trilhas, o Dente e o povoado
	var p: Array = dados["ponte"]
	inst(malha("tronco", {"esc": 1.5, "curv_k": 2.0, "tom": 0.72}), bl(p), -float(p[3]))
	var g: Array = dados["guincho"]
	inst(malha("guincho", {"esc": 1.5, "curv_k": 2.0, "tom": 1.0}), bl(g), -float(g[3]))
	var pm := malha("poste", {"esc": 1.5, "curv_k": 2.0, "tom": 1.0})
	for q in dados["postes"]:
		inst(pm, bl(q), float(q[3]))
		var lp := bl(q) + Basis(Vector3.UP, float(q[3])) * Vector3(0.33, 1.36, 0.0)
		postes.append(lp)
		luz_cartao(lp, Color(1.0, 0.62, 0.25), 1.1, 0.9 if pc else 0.6)
	postes.append(bl(g) + Basis(Vector3.UP, -float(g[3])) * Vector3(0.0, 2.45, -1.6))
	luz_cartao(postes[-1], Color(1.0, 0.62, 0.25), 1.2, 0.9 if pc else 0.6)
	var dn: Array = dados["dente"]
	inst(malha("dente", {"esc": 0.03, "curv_k": 2.0, "tom": 0.9}), bl(dn), 0.3)
	# o povoado da parede distante: janelas em cachos (retângulos com caixilho, não pontos)
	var J: Array = dados["janelas"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new(); q.size = Vector2(1, 1.5)
	var m := ShaderMaterial.new(); m.shader = sh("janela")
	m.set_shader_parameter("forca", 2.4 if pc else 1.8)
	q.material = m
	mm.mesh = q
	mm.instance_count = J.size()
	for i in J.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 8.0 * float(J[i][3])), bl(J[i])))
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))
	add_child(mmi)
	for c in [[Vector3(-150, -110, -810), 70.0], [Vector3(30, -40, -820), 80.0], [Vector3(210, -190, -800), 60.0]]:
		luz_cartao(c[0], Color(1.0, 0.58, 0.22), c[1], 0.35 if pc else 0.25)
	luz_cartao(bl(dn) + Vector3(0, 260, 0), Color(1.0, 0.6, 0.25), 90.0, 0.18)
	# névoa que sobe do abismo pela beira do penhasco: volumes cel em pé, bordas recortadas
	for k in 4:
		var nv := cartao_nevoa(Vector3(-24.0 + k * 16.0, -6.0, -12.5 - k * 1.5), Vector2(26, 14), 0.55, 0.09, false)
		nv.material_override.set_shader_parameter("deriva", Vector2(0.4, -1.2))
		nv.material_override.set_shader_parameter("vertical", 1.0)

func luz_cartao(p: Vector3, c: Color, tam: float, forca: float, bb := true) -> MeshInstance3D:
	# brilho pintado num cartão aditivo (halo de lanterna, do Sino, da isca): igual nos dois renderers
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(tam, tam)
	mi.mesh = q
	var m := ShaderMaterial.new(); m.shader = sh("halo")
	m.set_shader_parameter("cor", c); m.set_shader_parameter("forca", forca); m.set_shader_parameter("billboard", 1.0 if bb else 0.0)
	mi.material_override = m
	mi.position = p
	mi.extra_cull_margin = 2000.0
	add_child(mi)
	return mi

func lanternas() -> void:
	var L: Array = dados["lanternas"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	var m := ShaderMaterial.new(); m.shader = sh("halo")
	m.set_shader_parameter("cor", Color(1.0, 0.6, 0.22)); m.set_shader_parameter("forca", 1.1 if pc else 0.45); m.set_shader_parameter("nucleo", 0.5)
	q.material = m
	mm.mesh = q
	mm.instance_count = L.size()
	for i in L.size():
		var p := bl(L[i])
		var s := 0.55 if p.y > -20.0 else 7.0
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p))
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))
	add_child(mmi)
	# a corda que liga as lanternas perto
	for r in dados["rival"]:
		luz_cartao(bl(r), Color(0.6, 0.75, 1.0), 12.0, 0.5)

func cascata() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3(-72.0, 0.0, -205.0)
	var N := 16
	var y0 := -380.0; var y1 := 320.0
	for i in N:
		var a0 := deg_to_rad(-70.0 + 140.0 * i / N); var a1 := deg_to_rad(-70.0 + 140.0 * (i + 1) / N)
		var p0 := c + Vector3(sin(a0) * 16.0, 0, cos(a0) * 8.0)
		var p1 := c + Vector3(sin(a1) * 16.0, 0, cos(a1) * 8.0)
		var u0 := float(i) / N; var u1 := float(i + 1) / N
		for v in [[p0, u0, y0], [p1, u1, y0], [p1, u1, y1], [p0, u0, y0], [p1, u1, y1], [p0, u0, y1]]:
			st.set_uv(Vector2(v[1], 0)); st.add_vertex(Vector3(v[0].x, v[2], v[0].z + (v[2] - y1) * -0.02))
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var m := ShaderMaterial.new(); m.shader = sh("cascata")
	mi.material_override = m
	mi.extra_cull_margin = 2000.0
	add_child(mi)
	# nuvem da base: cartões de névoa em pé
	for k in 5:
		var nv := cartao_nevoa(Vector3(-72.0 + (k - 2) * 20.0, -300.0 + k * 14.0, -198.0 + k * 4.0), Vector2(90, 70), 0.6, 0.05, false)
		nv.rotation_degrees.x = 0.0

func coluna_luz() -> void:
	feixe = MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 9.0; cm.bottom_radius = 12.0; cm.height = 420.0; cm.cap_top = false; cm.cap_bottom = false
	cm.radial_segments = 32
	feixe.mesh = cm
	feixe.position = COLUNA + Vector3(0, 80.0, 0)
	var m := ShaderMaterial.new(); m.shader = sh("feixe"); m.set_shader_parameter("forca", 0.24 if pc else 0.06)
	feixe.material_override = m
	feixe.extra_cull_margin = 2000.0
	add_child(feixe)
	# poça de luz no chão da floresta
	luz_cartao(COLUNA + Vector3(0, -128.0, 0), Color(1.0, 0.8, 0.45), 40.0, 0.2, false).rotation_degrees.x = -90.0

func cartao_nevoa(p: Vector3, tam: Vector2, dens: float, esc: float, horizontal := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = tam
	mi.mesh = q
	var m := ShaderMaterial.new(); m.shader = sh("nevoa")
	m.set_shader_parameter("densidade", dens); m.set_shader_parameter("escala", esc)
	if pc:
		m.set_shader_parameter("cor", Color(0.42, 0.48, 0.56))
	mi.material_override = m
	mi.position = p
	if horizontal:
		mi.rotation_degrees.x = -90.0
	mi.extra_cull_margin = 2000.0
	add_child(mi)
	return mi

# goteiras do teto: três rasgos no teto da caverna soltam cortinas de água e um fio de luz fria (no lugar da chuva)
const CORTINAS := [[Vector3(-7.4, 0.0, -1.9), 2.0], [Vector3(7.6, 0.0, 1.0), 1.4], [Vector3(-13.0, 0.0, 5.5), 2.6], [Vector3(2.5, 0.0, -9.5), 3.0]]
func goteiras() -> void:
	for c in CORTINAS:
		var pos: Vector3 = c[0]
		cortinas.append(c)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new(); q.size = Vector2(c[1], 40.0)
		mi.mesh = q
		var m := ShaderMaterial.new(); m.shader = sh("cortina")
		mi.material_override = m
		mi.position = pos + Vector3(0, 18.0, 0)
		mi.extra_cull_margin = 2000.0
		add_child(mi)
		# fio de luz fria que desce pelo rasgo
		var fx := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = c[1] * 0.35; cm.bottom_radius = c[1] * 0.9; cm.height = 40.0; cm.cap_top = false; cm.cap_bottom = false
		fx.mesh = cm
		var fm := ShaderMaterial.new(); fm.shader = sh("feixe")
		fm.set_shader_parameter("forca", 0.1 if pc else 0.05)
		fm.set_shader_parameter("cor", Color(0.55, 0.72, 0.85))
		fm.set_shader_parameter("y0", -1.0); fm.set_shader_parameter("y1", 40.0)
		fx.material_override = fm
		fx.position = pos + Vector3(0, 18.0, 0)
		fx.extra_cull_margin = 2000.0
		add_child(fx)

func laminas_nevoa() -> void:
	# 3 lâminas a 30, 120 e 400 m da câmera (todas abaixo e atrás do plano de jogo)
	var defs := [[Vector3(0, -14.0, -26.0), Vector2(140, 36), 0.45, 0.06], [Vector3(10, -80.0, -100.0), Vector2(520, 140), 0.5, 0.018], [Vector3(0, -250.0, -330.0), Vector2(1400, 500), 0.6, 0.006]]
	if lite:
		defs = [defs[0], defs[2]]
	for d in defs:
		var mi := cartao_nevoa(d[0], d[1], d[2], d[3])
		laminas.append(mi)

func passo(t: float) -> void:
	if agua_mat:
		agua_mat.set_shader_parameter("tempo", t)
	# poças de luz quente pintadas (iguais nos dois renderers): lq3..lq9 são os postes e o guincho
	for i in range(min(postes.size(), 7)):
		var lp: Vector3 = postes[i]
		var tremor := 1.0 + 0.04 * sin(t * 11.0 + i * 2.1) + 0.03 * sin(t * 17.0 + i)
		RenderingServer.global_shader_parameter_set("lq%d" % (i + 3), Vector4(lp.x, lp.y, lp.z, 2.7 * tremor))
