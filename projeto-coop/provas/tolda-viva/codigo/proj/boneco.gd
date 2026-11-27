extends Node3D
# Um boneco carregado do GLB em tempo de execução (trilhas STEP viram NEAREST a 60 fps), com materiais
# próprios por instância (clarão, Tinta, Machê), molas de continuidade e controle de pose por tempo.
const Mola = preload("res://mola.gd")

const A := "res://assets/"
static var shaders := {}
static var tex_cache := {}

var nome := ""
var ap: AnimationPlayer
var skel: Skeleton3D
var mola
var mats := {}   # nome -> Array[ShaderMaterial]
var anim := ""
var t := 0.0

static func tex(n: String) -> Texture2D:
	if tex_cache.has(n):
		return tex_cache[n]
	var img := Image.load_from_file(ProjectSettings.globalize_path(A + n))
	img.generate_mipmaps()
	var tx := ImageTexture.create_from_image(img)
	tex_cache[n] = tx
	return tx

static func sh(n: String) -> Shader:
	if not shaders.has(n):
		shaders[n] = load("res://shaders/%s.gdshader" % n)
	return shaders[n]

const TECIDO := {"tarugo": "tex/xadrez.png", "anilina": "tex/chita.png", "retros": "tex/listrado.png", "pavio": "tex/poa.png",
	"traca": "tex/traca.png", "bastidor": "tex/bastidor.png"}

func setup(n: String, mask_col = null):
	nome = n
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(A + "glb/" + n + ".glb"), state)
	if err != OK:
		push_error("glb " + n)
	var sc := doc.generate_scene(state, 60.0) as Node3D
	add_child(sc)
	ap = sc.find_children("*", "AnimationPlayer", true, false)[0]
	skel = sc.find_children("*", "Skeleton3D", true, false)[0]
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		for i in m.get_surface_count():
			var mn: String = m.surface_get_material(i).resource_name if m.surface_get_material(i) else "cor"
			var mat: Material
			if mask_col != null:
				if mn == "contorno":
					var cm := ShaderMaterial.new(); cm.shader = sh("contorno"); cm.set_shader_parameter("ink_col", mask_col); mat = cm
				else:
					var s := StandardMaterial3D.new()
					s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					s.albedo_color = mask_col
					if mn == "olho":
						s.cull_mode = BaseMaterial3D.CULL_DISABLED
					mat = s
			else:
				var sm := ShaderMaterial.new()
				if mn == "contorno":
					sm.shader = sh("contorno")
				elif mn == "olho":
					sm.shader = sh("olho")
				else:
					sm.shader = sh("boneco")
					if mn == "pano" and TECIDO.has(n):
						sm.set_shader_parameter("use_tex", true)
						sm.set_shader_parameter("tecido", tex(TECIDO[n]))
				mat = sm
				if not mats.has(mn):
					mats[mn] = []
				mats[mn].append(sm)
			mi.set_surface_override_material(i, mat)
		mi.extra_cull_margin = 2.0
	mola = Mola.new()
	skel.add_child(mola)
	if mask_col == null:
		if nome.begins_with("caruncho"):
			# v2: laca vermelho-sangue com brilho duro e contraluz fria
			param(["cor"], "laca", 0.9)
			param(["cor"], "rim_amt", 0.55)
			param(["cor"], "shadow_tint", Color(0.42, 0.4, 0.6))
		elif nome in ["tarugo", "anilina", "retros", "pavio"]:
			param(["cor"], "veio", 0.05)
	return self

# v2: contorno extra na cor do jogador (1,6 px por fora do traço de tinta), recuado em profundidade
# para só a silhueta externa aparecer, não as linhas internas
func contorno_jogador(c: Color) -> void:
	if not mats.has("contorno"):
		return
	for m in mats["contorno"]:
		var np := ShaderMaterial.new(); np.shader = sh("contorno")
		np.set_shader_parameter("px_1080", 4.3)
		np.set_shader_parameter("ink_col", c)
		np.set_shader_parameter("recuo", 0.16)
		m.next_pass = np

func param(mat_names: Array, k: String, v) -> void:
	for mn in mat_names:
		if mats.has(mn):
			for m in mats[mn]:
				m.set_shader_parameter(k, v)

func pose(a: String, tt: float) -> void:
	if not ap.has_animation(a):
		push_error("sem animacao %s em %s" % [a, nome])
		return
	if anim != a:
		ap.play(a)
		anim = a
	t = tt
	ap.seek(tt, true)
	ap.pause()

func spring(b: String, f: float, z: float, g := 0.0) -> void:
	mola.add_spring(skel, b, f, z, g)

func springs_default() -> void:
	match nome:
		"tarugo", "anilina", "retros", "pavio":
			for s in ["F", "B", "L", "R"]:
				spring("skirt." + s, 3.2, 0.32)
			for s in ["L", "R"]:
				spring("thigh." + s, 2.2, 0.3, 2.0)
				spring("shin." + s, 2.8, 0.35, 2.0)
			if nome == "pavio":
				spring("cap1", 2.4, 0.25); spring("cap2", 2.6, 0.22); spring("cap3", 3.0, 0.2)
			elif nome == "anilina":
				spring("hat", 2.6, 0.32)
			elif nome == "retros":
				spring("hat", 4.0, 0.25)
		"caruncho", "caruncho_chifre":
			for s in ["L", "R"]:
				spring("ant1." + s, 3.0, 0.25); spring("ant2." + s, 3.6, 0.2)
		"traca":
			for s in ["L", "R"]:
				spring("ant." + s, 3.0, 0.3)
