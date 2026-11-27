extends Node3D
# Miniatura carregada do GLB em tempo de execução (trilhas STEP viram NEAREST a 60 fps), com materiais por
# instância (mini_pintada), molas de continuidade e pose por tempo.
const Mola = preload("res://mola.gd")
const A := "res://assets/"
static var shaders := {}

const HEROIS := ["escorador", "cristaleira", "coveira", "gancheiro"]
const COR_J := {"ambar": Color("f0a030"), "veneno": Color("7cd04a"), "cobalto": Color("3e7cf0"), "giz": Color("f2eee6")}
const ABERTURA := {"coveira": 0.62, "escorador": 0.8}
# v2: proporção por classe (Escorador atarracado e largo, Cristaleira alta e estreita, Coveira encurvada, Gancheiro magro)
const PROPORCAO := {"escorador": Vector3(1.14, 0.93, 1.1), "cristaleira": Vector3(0.9, 1.08, 0.9), "coveira": Vector3(1.0, 0.97, 1.0), "gancheiro": Vector3(0.88, 1.04, 0.88)}
# v2: ícone de silhueta exagerado só no modelo de jogo (a folha de modelo fica com a proporção real)
const ICONE := {"escorador": [["viga", Vector3(1.3, 1.38, 1.3)]], "cristaleira": [["hat", Vector3(1.22, 1.18, 1.22)]],
	"coveira": [["hat", Vector3(1.42, 1.1, 1.42)]], "gancheiro": [["rolo", Vector3(1.22, 1.22, 1.22)]]}
const CURVA := {"coveira": [["chest", Vector3(0.32, 0, 0)], ["neck", Vector3(-0.12, 0, 0)], ["head", Vector3(-0.14, 0, 0)]]}

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
var jogo := false
var cena_raiz: Node3D

static func sh(n: String) -> Shader:
	if not shaders.has(n):
		shaders[n] = load("res://shaders/%s.gdshader" % n)
	return shaders[n]

func setup(n: String, mask_col = null):
	nome = n
	heroi = n in HEROIS
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(A + "glb/" + n + ".glb"), state)
	if err != OK:
		push_error("glb " + n)
	var sc := doc.generate_scene(state, 60.0) as Node3D
	add_child(sc)
	cena_raiz = sc
	sc.scale = PROPORCAO.get(n, Vector3.ONE)
	var aps := sc.find_children("*", "AnimationPlayer", true, false)
	ap = aps[0] if aps.size() > 0 else null
	var sks := sc.find_children("*", "Skeleton3D", true, false)
	skel = sks[0] if sks.size() > 0 else null
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		for i in m.get_surface_count():
			var mn: String = m.surface_get_material(i).resource_name if m.surface_get_material(i) else "cor"
			var mat: Material
			var sm := ShaderMaterial.new()
			if mask_col != null:
				if mn == "contorno":
					sm.shader = sh("contorno"); sm.set_shader_parameter("cor", Color(mask_col.r, mask_col.g, mask_col.b, 1.0))
				else:
					var s := StandardMaterial3D.new()
					s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					s.albedo_color = mask_col
					mi.set_surface_override_material(i, s)
					continue
			else:
				match mn:
					"contorno":
						sm.shader = sh("contorno")
					"olho":
						sm.shader = sh("olho")
						sm.set_shader_parameter("tipo", 0)
						sm.set_shader_parameter("abertura", ABERTURA.get(n, 1.0))
					"emis":
						sm.shader = sh("emis")
					_:
						sm.shader = sh("mini")
						sm.set_shader_parameter("metal", 1.0 if mn == "metal" else 0.0)
						if heroi:
							sm.set_shader_parameter("heroi", 1.0)
							sm.set_shader_parameter("piso", 0.35)
						elif n in ["ouvidor", "bocalume"]:
							sm.set_shader_parameter("rim_frio", 1.0)
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

func xray(cor: Color) -> void:
	# silhueta chapada na cor do jogador quando o cenário tampa o herói
	var m := ShaderMaterial.new(); m.shader = sh("xray"); m.set_shader_parameter("cor", cor)
	m.render_priority = 10
	for mn in mats:
		if mn in ["cor", "metal", "orelha"]:
			for sm in mats[mn]:
				sm.next_pass = m
	xray_mat = m

var xray_mat: ShaderMaterial = null
func xray_passo(cam: Camera3D) -> void:
	if xray_mat:
		var c := cam.global_transform.affine_inverse() * (global_position + Vector3(0, 0.45, 0))
		xray_mat.set_shader_parameter("perto", -c.z - 1.3)

func param(mat_names: Array, k: String, v) -> void:
	for mn in mat_names:
		if mats.has(mn):
			for m in mats[mn]:
				m.set_shader_parameter(k, v)

func todos(k: String, v) -> void:
	param(["cor", "metal", "orelha"], k, v)

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
	extra_pose()

func extra_pose() -> void:
	# por cima da animação: corcunda da Coveira (sempre) e ícones exagerados (só no jogo)
	if skel == null:
		return
	for c in CURVA.get(nome, []):
		var i := skel.find_bone(c[0])
		if i >= 0:
			skel.set_bone_pose_rotation(i, skel.get_bone_pose_rotation(i) * Quaternion.from_euler(c[1]))
	if jogo:
		for c in ICONE.get(nome, []):
			var i := skel.find_bone(c[0])
			if i >= 0:
				skel.set_bone_pose_scale(i, c[1])

func dur(a: String) -> float:
	return ap.get_animation(a).length if ap and ap.has_animation(a) else 0.0

func spring(b: String, f: float, z: float, g := 0.0) -> void:
	mola.add_spring(skel, b, f, z, g)

func springs_default() -> void:
	match nome:
		"escorador":
			spring("chama", 2.2, 0.35, -1.5); spring("saco", 2.6, 0.25, 1.5)
		"cristaleira":
			spring("chapeu2", 2.0, 0.35, 0.5); spring("geodo", 1.3, 0.2, 2.5); spring("barra", 2.2, 0.3, 1.0)
			spring("manga.L", 2.6, 0.25, 1.0); spring("manga.R", 2.6, 0.25, 1.0)
		"coveira":
			spring("corrente", 0.9, 0.08, 4.0); spring("turibulo", 1.6, 0.15, 3.0); spring("veu", 2.0, 0.3, 1.0); spring("etiquetas", 2.6, 0.2, 1.5)
		"gancheiro":
			spring("gancho", 1.8, 0.18, 3.0); spring("ponta.L", 3.0, 0.22, 1.0); spring("ponta.R", 3.0, 0.22, 1.0)
		"ouvidor":
			pass
		"bocalume":
			spring("haste2", 2.0, 0.25, 0.5); spring("isca", 1.6, 0.15, 3.0)

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

func osso_pose(b: String, q: Quaternion) -> void:
	# rotação extra de um osso por cima da animação (orelhas do Ouvidor, olhar)
	var i := skel.find_bone(b)
	if i >= 0:
		skel.set_bone_pose_rotation(i, skel.get_bone_rest(i).basis.get_rotation_quaternion() * q)
