extends Node3D
# Personagem carregado do GLB em tempo de execução (trilhas STEP viram NEAREST a 60 fps), materiais por instância
# com o shader pintado_pela_luz, molas de continuidade e pose por tempo.
const Mola = preload("res://mola.gd")
const A := "res://assets/"
static var shaders := {}

const HEROIS := ["rodeira", "pavieiro", "sineira", "gatuno"]
const ESCALA := 1.3   # personagens 1,3x maiores que na v1 (o herói ocupa ~110 px em 1080p na câmera de combate)
const COR_JOG := {"carmim": Color("e0503c"), "ouro": Color("e8c34a"), "celeste": Color("5cb8ee"), "lilas": Color("b07be6")}
const COR_ESC := {"carmim": Color("5a1610"), "ouro": Color("5a4210"), "celeste": Color("0f3552"), "lilas": Color("3a1f58")}

var nome := ""
var ap: AnimationPlayer
var skel: Skeleton3D
var mola
var mats := {}      # nome do material -> Array[ShaderMaterial]
var anim := ""
var t := 0.0
var heroi := false
var anexo: BoneAttachment3D = null
var item: Node3D = null

static func sh(n: String) -> Shader:
	if not shaders.has(n):
		shaders[n] = load("res://shaders/%s.gdshader" % n)
	return shaders[n]

func setup(n: String, cor_jog := "", mask_col = null):
	nome = n
	heroi = n in HEROIS
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(A + "glb/" + n + ".glb"), state)
	if err != OK:
		push_error("glb " + n)
	var sc := doc.generate_scene(state, 60.0) as Node3D
	sc.scale = Vector3.ONE * ESCALA
	add_child(sc)
	var aps := sc.find_children("*", "AnimationPlayer", true, false)
	ap = aps[0] if aps.size() > 0 else null
	var sks := sc.find_children("*", "Skeleton3D", true, false)
	skel = sks[0] if sks.size() > 0 else null
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		for i in m.get_surface_count():
			var mn: String = m.surface_get_material(i).resource_name if m.surface_get_material(i) else "cor"
			var mat: Material
			if mask_col != null:
				if mn == "contorno":
					var cm := ShaderMaterial.new(); cm.shader = sh("contorno"); cm.set_shader_parameter("heroi", 1.0)
					cm.set_shader_parameter("cor_heroi", mask_col); cm.set_shader_parameter("px_heroi", 2.0); mat = cm
				else:
					var s := StandardMaterial3D.new()
					s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					s.albedo_color = mask_col
					mat = s
			else:
				var sm := ShaderMaterial.new()
				match mn:
					"contorno":
						sm.shader = sh("contorno")
						if heroi:
							sm.set_shader_parameter("heroi", 1.0)
							sm.set_shader_parameter("cor_heroi", COR_ESC.get(cor_jog, Color("2a1a14")))
							sm.set_shader_parameter("px_heroi", 4.0)
					"olho":
						sm.shader = sh("olho")
						sm.set_shader_parameter("tipo", 0 if heroi else 1)
					"emis":
						sm.shader = sh("emis")
					_:
						sm.shader = sh("pintado")
						sm.set_shader_parameter("metal", 1.0 if mn == "metal" else 0.0)
						if heroi:
							sm.set_shader_parameter("heroi", 1.0)
							sm.set_shader_parameter("borda", 1.0)
							sm.set_shader_parameter("tom_k", 1.15)
							sm.set_shader_parameter("cor_jogador", COR_JOG.get(cor_jog, Color("e8a24a")))
						else:
							sm.set_shader_parameter("massa", 1.0)
				mat = sm
				if not mats.has(mn):
					mats[mn] = []
				mats[mn].append(sm)
			mi.set_surface_override_material(i, mat)
		mi.extra_cull_margin = 1000.0
	if skel:
		mola = Mola.new()
		skel.add_child(mola)
	return self

func param(mat_names: Array, k: String, v) -> void:
	for mn in mat_names:
		if mats.has(mn):
			for m in mats[mn]:
				m.set_shader_parameter(k, v)

func todos(k: String, v) -> void:
	param(["cor", "metal", "contorno"], k, v)

func pose(a: String, tt: float) -> void:
	if ap == null:
		return
	if not ap.has_animation(a):
		push_error("sem animacao %s em %s" % [a, nome])
		return
	if anim != a:
		ap.play(a)
		anim = a
	t = tt
	ap.seek(tt, true)
	ap.pause()

func dur(a: String) -> float:
	return ap.get_animation(a).length if ap and ap.has_animation(a) else 0.0

func spring(b: String, f: float, z: float, g := 0.0) -> void:
	mola.add_spring(skel, b, f, z, g)

func springs_default() -> void:
	match nome:
		"rodeira":
			spring("capa1", 2.4, 0.25, 1.0); spring("capa2", 2.0, 0.2, 1.5); spring("tranca", 2.6, 0.2, 1.5)
		"pavieiro":
			spring("capa1", 2.4, 0.25, 1.0); spring("capa2", 2.0, 0.2, 1.5); spring("chama", 4.0, 0.25, -2.0); spring("barba", 3.0, 0.25, 1.0)
			spring("manga.L", 3.0, 0.25, 1.0); spring("manga.R", 3.0, 0.25, 1.0)
		"sineira":
			spring("capa1", 2.2, 0.3, 1.0); spring("capa2", 1.8, 0.25, 1.5); spring("sino", 1.4, 0.18, 3.0); spring("faixa", 2.4, 0.25, 1.5); spring("ponta", 2.8, 0.25, 1.0)
		"gatuno":
			spring("capa1", 2.6, 0.25, 1.0); spring("capa2", 2.2, 0.2, 1.5); spring("saco", 2.0, 0.22, 2.0)
			spring("orelha.L", 3.2, 0.2, 2.0); spring("orelha.R", 3.2, 0.2, 2.0)
		"fuligento":
			spring("cauda", 3.0, 0.2, 0.5)
		"apagador":
			spring("manto", 1.6, 0.25, 1.0)

func segurar(a: Node3D, osso := "prop") -> void:
	if anexo == null:
		anexo = BoneAttachment3D.new()
		skel.add_child(anexo)
		anexo.bone_name = osso
	if a.get_parent():
		a.get_parent().remove_child(a)
	anexo.add_child(a)
	a.transform = Transform3D.IDENTITY
	item = a

func soltar() -> Node3D:
	var a := item
	if a:
		var gt := a.global_transform
		anexo.remove_child(a)
		get_parent().add_child(a)
		a.global_transform = gt
	item = null
	return a

func osso_global(b: String) -> Transform3D:
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(b))
