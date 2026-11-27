extends Node3D
# Um boneco de miriti carregado do GLB em tempo de execução (trilhas STEP viram NEAREST a 60 fps), com o atlas
# pintado por faceta, materiais por instância (clarão, racha, dois tons), molas de continuidade e pose por tempo.
const Mola = preload("res://mola.gd")

const A := "res://assets/"
static var shaders := {}
static var tex_cache := {}

var nome := ""
var ap: AnimationPlayer
var skel: Skeleton3D
var mola
var mats := {}      # nome do material -> Array[ShaderMaterial]
var anim := ""
var t := 0.0
var arma: Node3D = null      # arma presa ao osso 'prop'
var anexo: BoneAttachment3D = null
var inimigo := false

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

func setup(n: String, mask_col = null, ink_px := 2.8):
	nome = n
	inimigo = n in ["bucho", "gaiola", "lata"]
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(A + "glb/" + n + ".glb"), state)
	if err != OK:
		push_error("glb " + n)
	var sc := doc.generate_scene(state, 60.0) as Node3D
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
					var cm := ShaderMaterial.new(); cm.shader = sh("contorno"); cm.set_shader_parameter("ink_col", mask_col)
					cm.set_shader_parameter("px_1080", ink_px); mat = cm
				else:
					var s := StandardMaterial3D.new()
					s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					s.albedo_color = mask_col
					mat = s
			else:
				var sm := ShaderMaterial.new()
				if mn == "contorno":
					sm.shader = sh("contorno")
					sm.set_shader_parameter("px_1080", ink_px)
				elif mn == "olho":
					sm.shader = sh("olho")
					sm.set_shader_parameter("tipo", 1 if inimigo else 0)
				else:
					sm.shader = sh("miriti")
					sm.set_shader_parameter("atlas", tex("tex/%s.png" % n))
				mat = sm
				if not mats.has(mn):
					mats[mn] = []
				mats[mn].append(sm)
			mi.set_surface_override_material(i, mat)
		mi.extra_cull_margin = 2.0
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
	param(["cor", "pano"], k, v)

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
		"marola":
			spring("lenco.L", 2.6, 0.22, 1.0); spring("lenco.R", 2.8, 0.22, 1.0)
			for s in ["F", "B", "L", "R"]:
				spring("skirt." + s, 3.4, 0.3)
			spring("back", 5.0, 0.4)
		"piaba":
			spring("snorkel", 3.2, 0.25)
			spring("flip.L", 4.5, 0.3); spring("flip.R", 4.5, 0.3)
		"remanso":
			spring("hat", 3.0, 0.3)
		"breu":
			spring("balde", 2.4, 0.25, 2.0); spring("estopa", 2.2, 0.2, 1.5)
		"bucho":
			spring("fin.L", 3.0, 0.25); spring("fin.R", 3.0, 0.25); spring("no", 2.6, 0.2)
		"gaiola":
			spring("olho", 3.0, 0.3)

# ------------------------------------------------------------------ arma presa ao osso da mão
func segurar(a: Node3D) -> void:
	if anexo == null:
		anexo = BoneAttachment3D.new()
		skel.add_child(anexo)
		anexo.bone_name = "prop"
	if a.get_parent():
		a.get_parent().remove_child(a)
	anexo.add_child(a)
	a.transform = Transform3D.IDENTITY
	arma = a

func soltar() -> Node3D:
	var a := arma
	if a:
		var gt := a.global_transform
		anexo.remove_child(a)
		get_tree().current_scene.add_child(a)
		a.global_transform = gt
	arma = null
	return a

func osso_global(b: String) -> Transform3D:
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(b))
