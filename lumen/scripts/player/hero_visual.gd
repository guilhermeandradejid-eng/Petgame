class_name HeroVisual
extends Node3D
## O boneco do heroi: carrega hero.glb (todas as pecas num so esqueleto), liga/desliga
## as pecas conforme o visual escolhido, pinta os materiais e toca as animacoes.

const HERO_SCENE := "res://assets/models/hero.glb"
const FIXED := {
	"metal": Color("c3cede"), "leather": Color("7d5334"), "eye": Color("2b2238"), "white": Color("ffffff"),
	"dark": Color("2f2a3d"), "mouth": Color("8c3b3b"), "glow": Color("9ffbff"),
}
const DEFAULT_LOOK := {
	"hair": "hair_bagunca", "hat": "", "ears": "", "acc": "", "top": "top_tunica", "bottom": "bottom_botas",
	"back": "", "eyes": "eyes_round", "weapon": "sword_ferro",
	"skin": "f6c9a4", "hair_c": "7a4a2e", "primary": "3f86d9", "secondary": "f3ead6", "accent": "f2b632", "iris": "5fb0e8",
}

var skel: Skeleton3D
var anim: AnimationPlayer
var meshes: Dictionary = {}
var mats: Dictionary = {}
var look: Dictionary = {}
var current := ""
var model: Node3D
var _blink := 2.0
var _eyes: Array = []
var _stop_t := 0.0
var _saved_speed := 1.0

func _ready() -> void:
	var ps: PackedScene = load(HERO_SCENE)
	model = ps.instantiate()
	add_child(model)
	model.rotation.y = PI   # o glTF olha para +Z; no jogo a frente e -Z
	skel = Mats.find_of(model, "Skeleton3D")
	anim = Mats.find_of(model, "AnimationPlayer")
	_collect(model)
	_make_materials()
	_setup_springs()
	for b in ["eye.L", "eye.R", "eye_L", "eye_R"]:
		var i := skel.find_bone(b)
		if i >= 0:
			_eyes.append(i)
	if look.is_empty():
		apply_look(DEFAULT_LOOK)
	_blink = randf_range(1.0, 4.0)

func _collect(n: Node) -> void:
	if n is MeshInstance3D:
		meshes[String(n.name)] = n
		(n as MeshInstance3D).visible = false
		(n as MeshInstance3D).extra_cull_margin = 1.5
	for c in n.get_children():
		_collect(c)

func _make_materials() -> void:
	for k in ["skin", "hair", "primary", "secondary", "accent", "iris"]:
		mats[k] = Mats.toon(Color.WHITE, {"rim": 0.8})
	for k in FIXED:
		mats[k] = Mats.toon(FIXED[k], {"rim": 0.8})
	mats["metal"].set_shader_parameter("gloss", 0.9)
	mats["glow"].set_shader_parameter("shade_boost", 2.0)
	mats["glow"].set_shader_parameter("tint", Color.WHITE)
	mats["iris"].set_shader_parameter("shade_boost", 0.25)
	mats["white"].set_shader_parameter("shade_boost", 0.35)
	mats["vcol"] = Mats.toon(Color.WHITE, {"rim": 0.8})
	for nm in meshes:
		var mi: MeshInstance3D = meshes[nm]
		for si in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(si)
			var mname := src.resource_name if src else "vcol"
			mi.set_surface_override_material(si, mats.get(mname, mats["vcol"]))

func _setup_springs() -> void:
	var chains := [["hair1", "hair2", 2.2, 0.5], ["cape1", "cape3", 1.6, 0.45], ["tail1", "tail2", 2.4, 0.5], ["hat1", "hat1", 3.0, 0.5]]
	var valid: Array = []
	for c in chains:
		if skel.find_bone(c[0]) >= 0 and skel.find_bone(c[1]) >= 0:
			valid.append(c)
	if valid.is_empty():
		return
	var sb := SpringBoneSimulator3D.new()
	sb.name = "Springs"
	skel.add_child(sb)
	sb.set_setting_count(valid.size())
	for i in valid.size():
		var c: Array = valid[i]
		sb.set_root_bone_name(i, c[0])
		sb.set_end_bone_name(i, c[1])
		sb.set_extend_end_bone(i, true)
		sb.set_end_bone_length(i, 0.16)
		sb.set_stiffness(i, c[2])
		sb.set_drag(i, c[3])
		sb.set_gravity(i, 0.35)
		sb.set_radius(i, 0.03)

# ------------------------------------------------------------------ visual
func apply_look(l: Dictionary) -> void:
	look = DEFAULT_LOOK.duplicate()
	for k in l:
		look[k] = l[k]
	for nm in meshes:
		(meshes[nm] as MeshInstance3D).visible = nm.begins_with("base_")
	var hair_mode := "keep"
	var hat: String = str(look.get("hat", ""))
	if hat != "" and meshes.has(hat):
		hair_mode = str(DB.cosmetics.get(hat, {}).get("hair", "keep"))
	for slot in ["hat", "ears", "acc", "top", "bottom", "back", "eyes", "weapon"]:
		var id := str(look.get(slot, ""))
		# orelhas no topo da cabeca somem sob chapeus que cobrem a cabeca
		if slot == "ears" and hat != "" and hair_mode != "keep" and bool(DB.cosmetics.get(id, {}).get("top", false)):
			continue
		if id != "" and not meshes.has(id):
			id = str(DEFAULT_LOOK.get(slot, ""))
		if id != "" and meshes.has(id):
			meshes[id].visible = true
	var hair := str(look.get("hair", ""))
	if hair != "" and not meshes.has(hair):
		hair = DEFAULT_LOOK["hair"]
	if hair != "" and meshes.has(hair) and hair_mode != "hide":
		meshes[hair].visible = true
		if hair_mode == "keep" and meshes.has(hair + "__top"):
			meshes[hair + "__top"].visible = true
	_tint("skin", look["skin"])
	_tint("hair", look["hair_c"])
	_tint("primary", look["primary"])
	_tint("secondary", look["secondary"])
	_tint("accent", look["accent"])
	_tint("iris", look["iris"])

func _tint(key: String, hex: Variant) -> void:
	var c := Color(str(hex)) if Color.html_is_valid(str(hex)) else Color.WHITE
	(mats[key] as ShaderMaterial).set_shader_parameter("tint", c)

func weapon_type() -> String:
	var w := str(look.get("weapon", ""))
	return str(DB.cosmetics.get(w, {}).get("wt", "sword"))

# ------------------------------------------------------------------ animacao
func has(a: String) -> bool:
	return _res(a) != ""

## O importador do Godot remove o sufixo "-loop" do nome: aceita as duas formas.
func _res(a: String) -> String:
	if anim == null:
		return ""
	if anim.has_animation(a):
		return a
	var b := a.trim_suffix("-loop")
	return b if anim.has_animation(b) else ""

## Toca um clipe em loop/continuo (nao reinicia se ja estiver tocando).
func play(a: String, blend: float = 0.15, speed: float = 1.0) -> void:
	a = _res(a)
	if a == "":
		return
	if current == a and anim.is_playing():
		anim.speed_scale = speed if _stop_t <= 0.0 else anim.speed_scale
		_saved_speed = speed
		return
	current = a
	_saved_speed = speed
	anim.play(a, blend)
	anim.speed_scale = speed if _stop_t <= 0.0 else 0.02

## Toca do comeco, mesmo que seja o mesmo clipe (ataques, esquiva).
func play_once(a: String, blend: float = 0.08, speed: float = 1.0) -> void:
	a = _res(a)
	if a == "":
		return
	current = a
	_saved_speed = speed
	anim.play(a, blend)
	anim.seek(0.0, true)
	anim.speed_scale = speed if _stop_t <= 0.0 else 0.02

func anim_len(a: String) -> float:
	a = _res(a)
	return anim.get_animation(a).length if a != "" else 0.5

## Congela a animacao por um instante (impacto de golpe).
func hitstop(t: float) -> void:
	if t <= 0.0:
		return
	if _stop_t <= 0.0:
		_saved_speed = anim.speed_scale
	_stop_t = max(_stop_t, t)
	anim.speed_scale = 0.02

func flash(color: Color = Color.WHITE, t: float = 0.12) -> void:
	Mats.set_instance_param(model, &"flash_color", color)
	Mats.set_instance_param(model, &"flash", 0.85)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: Mats.set_instance_param(model, &"flash", v), 0.85, 0.0, t)

func _process(delta: float) -> void:
	if _stop_t > 0.0:
		_stop_t -= delta
		if _stop_t <= 0.0:
			anim.speed_scale = _saved_speed
	# piscar
	_blink -= delta
	if _eyes.size() > 0:
		var s := 1.0
		if _blink < 0.12:
			s = 0.12
		if _blink < 0.0:
			_blink = randf_range(2.0, 5.5)
		for i in _eyes:
			skel.set_bone_pose_scale(i, Vector3(1, s, 1))

func bone_global(bone: String) -> Vector3:
	var i := skel.find_bone(bone)
	if i < 0:
		return global_position + Vector3.UP
	return skel.global_transform * skel.get_bone_global_pose(i).origin
