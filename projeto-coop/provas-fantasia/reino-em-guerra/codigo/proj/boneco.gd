extends Node3D
# Um boneco carregado do GLB em tempo de execução (trilhas CONSTANT a 60 fps), com materiais de gravura por
# instância (clarão, tinta prensada, unção), molas de continuidade e pose por tempo.
const Mola = preload("res://mola.gd")
const A := "res://assets/"
static var shaders := {}

var nome := ""
var ap: AnimationPlayer
var skel: Skeleton3D
var mola
var mats := {}
var anim := ""
var t := 0.0
var anexos := {}

static func sh(n: String) -> Shader:
	if not shaders.has(n):
		shaders[n] = load("res://shaders/%s.gdshader" % n)
	return shaders[n]

func setup(n: String, px := 1.5, cor_mask = null):
	nome = n
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
			var mn: String = m.surface_get_material(i).resource_name if m.surface_get_material(i) else "grav"
			var mat: Material
			if cor_mask != null:
				var s := StandardMaterial3D.new()
				s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				s.albedo_color = cor_mask
				if mn == "contorno":
					var cm := ShaderMaterial.new(); cm.shader = sh("contorno"); cm.set_shader_parameter("ink_col", cor_mask); cm.set_shader_parameter("px_1080", px)
					mat = cm
				else:
					mat = s
			else:
				var sm := ShaderMaterial.new()
				match mn:
					"contorno":
						sm.shader = sh("contorno"); sm.set_shader_parameter("px_1080", px)
					"plano":
						sm.shader = sh("plano")
					"chama":
						sm.shader = sh("chama")
					"verde":
						sm.shader = sh("verde")
					_:
						sm.shader = sh("boneco")
				mat = sm
				if not mats.has(mn):
					mats[mn] = []
				mats[mn].append(sm)
			mi.set_surface_override_material(i, mat)
		mi.extra_cull_margin = 3.0
	if n in ["piqueiro", "penitente", "carpideira"] and cor_mask == null:
		param(["grav"], "negativo", 1.0)   # mortos: gravura em negativo, tinta cheia com a luz cavada em linha de papel
		param(["contorno"], "px_1080", px * 1.5)
	if skel:
		mola = Mola.new()
		skel.add_child(mola)
	if n in ["piqueiro", "penitente", "carpideira"] and cor_mask == null:
		_halo(sc)
	return self

var halo_mat: ShaderMaterial
func _halo(sc: Node) -> void:
	# centro dos olhos (peças de material 'verde') no espaço do esqueleto em repouso -> preso ao osso da cabeça
	var soma := Vector3.ZERO; var n := 0
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		for i in m.get_surface_count():
			var mt := m.surface_get_material(i)
			if mt and mt.resource_name == "verde":
				var v: PackedVector3Array = m.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
				for p in v:
					soma += p
				n += v.size()
	if n == 0 or skel == null:
		return
	var c := soma / n
	var hb := skel.find_bone("head")
	var at := BoneAttachment3D.new(); skel.add_child(at); at.bone_name = "head"
	var rest := skel.get_bone_global_rest(hb)
	var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.42, 0.3) * (1.6 if nome == "carpideira" else 1.0); q.mesh = qm
	halo_mat = ShaderMaterial.new(); halo_mat.shader = load("res://shaders/halo.gdshader")
	q.material_override = halo_mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.extra_cull_margin = 2.0
	at.add_child(q)
	q.position = rest.affine_inverse() * c

func param(mat_names: Array, k: String, v) -> void:
	if k == "aceso" and "verde" in mat_names and halo_mat:
		halo_mat.set_shader_parameter("aceso", v)
	for mn in mat_names:
		if mats.has(mn):
			for m in mats[mn]:
				m.set_shader_parameter(k, v)

func todos(k: String, v) -> void:
	param(["grav", "contorno", "plano", "verde"], k, v)
	if k == "achata" and halo_mat:
		halo_mat.set_shader_parameter("aceso", 1.0 - float(v))

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
	ap.seek(clampf(tt, 0.0, ap.get_animation(a).length), true)
	ap.pause()

func dur(a: String) -> float:
	return ap.get_animation(a).length if ap and ap.has_animation(a) else 0.0

func spring(b: String, f: float, z: float, g := 0.0, w := 0.6) -> void:
	mola.add_spring(skel, b, f, z, g, w)

func springs_default() -> void:
	match nome:
		"porta":
			spring("asa", 4.0, 0.3); spring("asa2", 4.5, 0.3)
			spring("tabardo.F", 3.2, 0.3, 1.0); spring("tabardo.B", 3.2, 0.3, 1.0)
		"sineira":
			for s in ["F", "B", "L", "R"]:
				spring("saia." + s, 3.0, 0.28)
			spring("veu", 2.6, 0.25, 1.0)
		"sapador":
			spring("mochila", 3.6, 0.4, 0.0, 0.1); spring("barril.T", 4.0, 0.4, 0.0, 0.1); spring("aba", 3.5, 0.35)
			spring("lanterna", 2.2, 0.2, 1.0, 0.3); spring("cachecol1", 2.4, 0.25, 0.5, 2.5); spring("cachecol2", 2.0, 0.2, 0.5, 3.5)
		"bruxa":
			for i in range(1, 6):
				spring("chapeu%d" % i, 2.4 + i * 0.3, 0.3, 0.0, 0.12)
			spring("casaco.F", 2.6, 0.3, 1.0); spring("casaco.B", 2.4, 0.3, 1.0)
			spring("cabelo.L", 3.0, 0.3, 1.0); spring("cabelo.R", 3.0, 0.3, 1.0)
		"penitente":
			spring("capuz", 3.0, 0.3); spring("corrente", 2.2, 0.15, 3.0); spring("bola", 2.2, 0.15, 3.0)
		"carpideira":
			for s in ["B", "L", "R"]:
				spring("veu." + s, 1.6, 0.22, 0.5)

func anexar(a: Node3D, osso: String, xf = null) -> void:
	var at: BoneAttachment3D = anexos.get(osso)
	if at == null:
		at = BoneAttachment3D.new()
		skel.add_child(at)
		at.bone_name = osso
		anexos[osso] = at
	if a.get_parent():
		a.get_parent().remove_child(a)
	at.add_child(a)
	# o adereço foi modelado com a ponta para a frente do boneco (glTF +Z); o osso aponta para +Y local
	a.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO) if xf == null else xf

func osso_global(b: String) -> Transform3D:
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(b))
