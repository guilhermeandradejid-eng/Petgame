extends Node3D
# O Brejo das Lamparinas Afogadas: terreno contínuo, água, passarelas, juncos e capim em MultiMesh (vento),
# árvores mortas, pedras, lanternas afogadas, a Wain com Graxo e estandartes, e os marcos do horizonte.
const A := "res://assets/"
static var sh_cache := {}
var pc := false
var dados := {}
var estandartes: Array = []
var graxo: Node3D
var farol_feixe: MeshInstance3D
var mats_agua: Array = []

static func sh(n: String) -> Shader:
	if not sh_cache.has(n):
		sh_cache[n] = load("res://shaders/%s.gdshader" % n)
	return sh_cache[n]

static func mat_para(mn: String, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	match mn:
		"contorno":
			m.shader = sh("contorno")
		"emis":
			m.shader = sh("emis")
		"olho":
			m.shader = sh("olho")
		_:
			m.shader = sh("pintado")
			m.set_shader_parameter("metal", 1.0 if mn == "metal" else 0.0)
	for k in extra:
		if mn != "emis" or k == "energia":
			m.set_shader_parameter(k, extra[k])
	return m

static func carregar(n: String, extra := {}) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(A + "glb/" + n + ".glb"), st)
	var sc := doc.generate_scene(st) as Node3D
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		for i in m.get_surface_count():
			var mn: String = m.surface_get_material(i).resource_name if m.surface_get_material(i) else "cor"
			mi.set_surface_override_material(i, mat_para(mn, extra))
		mi.extra_cull_margin = 16384.0
	return sc

static func malha(n: String, extra := {}) -> ArrayMesh:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(A + "glb/" + n + ".glb"), st)
	var sc := doc.generate_scene(st) as Node3D
	var mi: MeshInstance3D = sc.find_children("*", "MeshInstance3D", true, false)[0]
	var m: ArrayMesh = mi.mesh.duplicate()
	for i in m.get_surface_count():
		var mn: String = m.surface_get_material(i).resource_name if m.surface_get_material(i) else "cor"
		m.surface_set_material(i, mat_para(mn, extra))
	sc.free()
	return m

func multi(mesh: Mesh, pts: Array, escala := 1.0, cast := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = pts.size()
	for i in pts.size():
		var p: Array = pts[i]
		var b := Basis(Vector3.UP, p[3]).scaled(Vector3.ONE * p[4] * escala)
		mm.set_instance_transform(i, Transform3D(b, Vector3(p[0], p[1], p[2])))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi

func construir(opts := {}) -> void:
	pc = opts.get("pc", false)
	var lite: bool = opts.get("lite", false)
	dados = JSON.parse_string(FileAccess.get_file_as_string(A + "mundo.json"))
	# terreno e passarelas
	var ter := carregar("terreno", {"freq": 4.5, "tom_k": 1.0, "molhado": 1.0, "chao": 1.0})
	add_child(ter)
	add_child(carregar("passarela", {"freq": 12.0}))
	# água rasa
	var ag := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(900, 700); pm.subdivide_width = 80; pm.subdivide_depth = 120
	ag.mesh = pm
	ag.position = Vector3(0, dados["agua_y"], -300)
	var am := ShaderMaterial.new(); am.shader = sh("agua")
	ag.material_override = am
	ag.extra_cull_margin = 16384.0
	mats_agua.append(am)
	add_child(ag)
	# vegetação e pedras (MultiMesh, vento nos juncos e no capim)
	var mj := malha("junco", {"vento_k": 0.35, "freq": 14.0, "fino": 1.0})
	multi(mj, dados["junco"], 1.0, true)
	multi(malha("capim", {"vento_k": 0.8, "freq": 16.0, "fino": 1.0}), dados["capim"], 1.0, false)
	var arv: Array = dados["arvore"]
	for k in 3:
		var sub := []
		for i in arv.size():
			if i % 3 == k:
				sub.append(arv[i])
		multi(malha("arvore%d" % k, {"freq": 10.0}), sub, 1.0, true)
	var ped: Array = dados["pedra"]
	for k in 3:
		var sub := []
		for i in ped.size():
			if i % 3 == k:
				sub.append(ped[i])
		multi(malha("pedra%d" % k, {"freq": 10.0}), sub, 1.0, true)
	var afo := malha("lanterna_afogada", {"energia": 1.1})
	multi(afo, dados["afogada"], 1.0, false)
	# plano médio e caminhos: pedras de pisar até o farol, postes de lanterna, ruína com braseiro, carroça tombada,
	# capela no fim do ramal; restos no chão (cera, cascas de Fuligento, estandartes rasgados); primeiro plano
	multi(malha("pedra2", {"freq": 6.0}), dados["degraus"], 1.0, true)
	multi(malha("poste", {"freq": 8.0}), dados["poste"], 1.0, true)
	multi(malha("poca_cera", {"freq": 6.0}), dados["poca_cera"], 1.0, false)
	multi(malha("casca", {"freq": 8.0}), dados["casca"], 1.0, false)
	multi(malha("estandarte_caido", {"freq": 8.0}), dados["estandarte_caido"], 1.0, false)
	if not lite:
		multi(malha("junco_alto", {"vento_k": 0.25, "freq": 6.0, "fino": 0.35, "tom_linha": 0.6}), dados["junco_alto"], 1.0, false)
	for nome in ["ruina", "carroca", "capela"]:
		var d: Array = dados[nome]
		var ob := carregar(nome, {"freq": 8.0})
		ob.position = Vector3(d[0], d[1], d[2])
		ob.rotation.y = d[3]
		ob.scale = Vector3.ONE * d[4]
		add_child(ob)
	# a Wain, Graxo e estandartes, 25 m atrás do combate
	var wain := carregar("wain", {"freq": 10.0})
	wain.position = Vector3(1.0, 0.33, -25.2)
	add_child(wain)
	graxo = carregar("graxo", {"freq": 8.0})
	graxo.position = Vector3(-7.0, 0.0, -25.4)
	add_child(graxo)
	for i in 4:
		var e := carregar("estandarte", {"vento_k": 0.0, "freq": 12.0})
		e.position = Vector3([-2.4, 0.9, 4.2, 7.2][i], 2.25, -24.4)
		e.rotation_degrees.y = [10.0, -20.0, 5.0, -10.0][i]
		add_child(e)
		estandartes.append(e)
	# marcos do horizonte: Farol Cego (esquerda), Gigante Ajoelhado (meio, longe), Torre Torta (direita)
	var far := carregar("farol", {"forca_pavio": 0.0, "freq": 2.0})
	far.position = Vector3(-70, -6, -160)
	far.scale = Vector3.ONE * 1.05
	add_child(far)
	var gig := carregar("gigante", {"forca_pavio": 0.0, "freq": 1.2})
	gig.position = Vector3(-78, -4, -300)
	gig.rotation_degrees.y = 35
	gig.scale = Vector3.ONE * 1.1
	add_child(gig)
	var tor := carregar("torre", {"forca_pavio": 0.0, "freq": 2.5})
	tor.position = Vector3(62, -2, -160)
	tor.scale = Vector3.ONE * 0.95
	tor.rotation_degrees.y = -70
	add_child(tor)
	# feixe pálido do farol varrendo a névoa do mar
	farol_feixe = MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(1, 1)
	var fm := ShaderMaterial.new(); fm.shader = sh("feixe"); fm.set_shader_parameter("forca", 0.55)
	farol_feixe.mesh = cone_feixe(120.0, 7.0)
	farol_feixe.material_override = fm
	farol_feixe.extra_cull_margin = 16384.0
	farol_feixe.position = Vector3(-70, 23.0, -160)
	add_child(farol_feixe)
	# Muralha de Treva: anel de hachuras no horizonte
	var mu := MeshInstance3D.new()
	mu.mesh = arco_muralha(330.0, 40.0)
	var mm := ShaderMaterial.new(); mm.shader = sh("muralha")
	mu.material_override = mm
	mu.extra_cull_margin = 16384.0
	add_child(mu)

func cone_feixe(L: float, larg: float) -> ArrayMesh:
	# fita larga em leque (dois planos cruzados) ao longo de +X local; UV.y ao longo
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plano in 2:
		var ax := Vector3(0, 1, 0) if plano == 0 else Vector3(0, 0, 1)
		var v0 := Vector3.ZERO
		var a := Vector3(L, 0, 0) - ax * larg
		var b := Vector3(L, 0, 0) + ax * larg
		st.set_uv(Vector2(0.5, 0)); st.add_vertex(v0 - ax * 0.4)
		st.set_uv(Vector2(0.0, 1)); st.add_vertex(a)
		st.set_uv(Vector2(1.0, 1)); st.add_vertex(b)
		st.set_uv(Vector2(0.5, 0)); st.add_vertex(v0 - ax * 0.4)
		st.set_uv(Vector2(1.0, 1)); st.add_vertex(b)
		st.set_uv(Vector2(0.5, 0)); st.add_vertex(v0 + ax * 0.4)
	return st.commit()

func arco_muralha(R: float, H: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var N := 64
	for i in N:
		var a0 := deg_to_rad(-60.0 + 120.0 * i / N) - PI / 2
		var a1 := deg_to_rad(-60.0 + 120.0 * (i + 1) / N) - PI / 2
		var p0 := Vector3(cos(a0) * R, -6, sin(a0) * R)
		var p1 := Vector3(cos(a1) * R, -6, sin(a1) * R)
		var u0 := float(i) / N; var u1 := float(i + 1) / N
		st.set_uv(Vector2(u0, 0)); st.add_vertex(p0)
		st.set_uv(Vector2(u1, 0)); st.add_vertex(p1)
		st.set_uv(Vector2(u1, 1)); st.add_vertex(p1 + Vector3(0, H, 0))
		st.set_uv(Vector2(u0, 0)); st.add_vertex(p0)
		st.set_uv(Vector2(u1, 1)); st.add_vertex(p1 + Vector3(0, H, 0))
		st.set_uv(Vector2(u0, 1)); st.add_vertex(p0 + Vector3(0, H, 0))
	return st.commit()

func passo(t: float) -> void:
	# farol varre devagar; Graxo respira
	if farol_feixe:
		farol_feixe.rotation = Vector3(0, deg_to_rad(-30.0 + 18.0 * sin(t * 0.35)), deg_to_rad(-6.0))
	if graxo:
		var b := 1.0 + 0.015 * sin(t * 1.6)
		graxo.scale = Vector3(1.0, b, 1.0 + (b - 1.0) * 0.6)
	for m in mats_agua:
		m.set_shader_parameter("tempo", t)
