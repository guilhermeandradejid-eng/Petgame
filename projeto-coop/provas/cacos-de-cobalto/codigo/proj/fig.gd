extends RefCounted
# Uma figura carregada do GLB: materiais, animação controlada por quadro (hit-stop local),
# ossos de mola (follow-through) e parâmetros do rosto.

var root: Node3D
var sk: Skeleton3D
var ap: AnimationPlayer
var body: ShaderMaterial
var hull: ShaderMaterial
var meta := {}
var springs: Array = []
var name := ""
var anim := ""
var t := 0.0          # tempo da animação (s)
var hold := 0         # quadros de hit-stop restantes
var shake := 0.0      # tremor do alvo durante o hit-stop (m)
var base_pos := Vector3.ZERO

const SPRING := {  # rigidez, amortecimento, gravidade (m/s²) por osso de mola
	"mola_lanterna": [90.0, 9.0, 4.0], "mola_balde": [70.0, 7.0, 5.0], "mola_avental": [140.0, 12.0, 1.0],
	"mola_saia_F": [180.0, 16.0, 0.5], "mola_saia_B": [180.0, 16.0, 0.5], "mola_lenco": [110.0, 8.0, 0.5],
	"mola_chapeu": [160.0, 10.0, 0.5], "mola_catavento": [60.0, 5.0, 0.5], "mola_garrafa": [120.0, 10.0, 1.0],
}

const PLAYER := {"lamparina": "#E43C9E", "bento": "#23C4DB", "nina": "#9A78E0", "galvao": "#9BE03C"}

func set_player(col: Color) -> void:
	body.set_shader_parameter("player_col", col)
	body.set_shader_parameter("rim_str", 1.0)

func setup(r: Node3D, n: String, mats: Dictionary, m: Dictionary) -> void:
	root = r
	name = n
	meta = m
	var sks := root.find_children("*", "Skeleton3D", true, false)
	sk = sks[0] if sks.size() > 0 else null
	var aps := root.find_children("*", "AnimationPlayer", true, false)
	ap = aps[0] if aps.size() > 0 else null
	if ap:
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	body = mats["corpo"]
	hull = mats["contorno"]
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for i in mesh.get_surface_count():
			var mm := mesh.surface_get_material(i)
			var nm: String = mm.resource_name if mm else ""
			mi.set_surface_override_material(i, hull if nm == "contorno" else body)
	if meta.has("face_rect"):
		var fr: Array = meta["face_rect"]
		body.set_shader_parameter("face_rect", Vector4(fr[0], fr[1], fr[2], fr[3]))
		var fs: Array = meta["face_size"]
		body.set_shader_parameter("face_size", Vector2(fs[0], fs[1]))
		for k in ["t_eyes", "t_mouth", "eye_gap", "eye_w", "eye_h", "mouth_w"]:
			if meta.has(k):
				body.set_shader_parameter(k, meta[k])
	if meta.has("player_regions") and meta.has("regions"):
		var modes := Vector2.ZERO
		var k := 0
		for pr in meta["player_regions"]:
			var rr: Array = meta["regions"][pr[0]]
			body.set_shader_parameter("player_rect%d" % k, Vector4(rr[0], rr[1], rr[2], rr[3]))
			modes[k] = float(pr[1])
			k += 1
		body.set_shader_parameter("player_mode", modes)
		set_player(Color(PLAYER.get(name, "#FFFFFF")))
	if sk:
		for b in sk.get_bone_count():
			var bn := sk.get_bone_name(b)
			if bn.begins_with("mola"):
				var p := sk.get_bone_parent(b)
				var ln := 0.2
				for c in sk.get_bone_children(b):
					ln = sk.get_bone_rest(c).origin.length()
				var cfg: Array = SPRING.get(bn, [120.0, 10.0, 1.0])
				springs.append({"b": b, "p": p, "len": 0.25, "k": cfg[0], "c": cfg[1], "g": cfg[2], "tip": Vector3.ZERO, "vel": Vector3.ZERO, "init": false})

func play(a: String, at := 0.0) -> void:
	anim = a
	t = at

func face(p: Dictionary) -> void:
	for k in p:
		body.set_shader_parameter(k, p[k])

func set_param(k: String, v) -> void:
	body.set_shader_parameter(k, v)
	if k == "invert":
		hull.set_shader_parameter("invert", v)

func pose_now() -> void:
	if ap and anim != "" and ap.has_animation(anim):
		if ap.current_animation != anim:
			ap.play(anim)
		ap.seek(min(t, ap.get_animation(anim).length), true)
		ap.advance(0.0)

func step(dt: float, speed := 1.0) -> void:
	# avança a animação; durante o hit-stop o tempo anda só 8% (o atacante não congela 100%)
	if hold > 0:
		hold -= 1
		t += dt * speed * 0.08
	else:
		t += dt * speed
	pose_now()

func spring_tick(dt: float) -> void:
	if not sk:
		return
	var gt := sk.global_transform
	for s in springs:
		var b: int = s["b"]
		var p: int = s["p"]
		var pg := sk.get_bone_global_pose(p) if p >= 0 else Transform3D.IDENTITY
		pg = pg.orthonormalized()
		var rest := sk.get_bone_rest(b)
		var bg := pg * rest
		var head := gt * bg.origin
		var rdir := (gt.basis * bg.basis * Vector3.UP).normalized()
		var L: float = s["len"]
		var target := head + rdir * L
		if not s["init"]:
			s["tip"] = target
			s["vel"] = Vector3.ZERO
			s["init"] = true
		var v: Vector3 = s["vel"]
		var tip: Vector3 = s["tip"]
		v += ((target - tip) * float(s["k"]) - v * float(s["c"]) + Vector3.DOWN * float(s["g"])) * dt
		tip += v * dt
		var d := (tip - head)
		if d.length() < 1e-4:
			d = rdir
		d = d.normalized()
		# limite de 75° para o pano não atravessar o corpo
		var ang := rdir.angle_to(d)
		if ang > deg_to_rad(75.0):
			d = rdir.slerp(d, deg_to_rad(75.0) / ang).normalized()
		tip = head + d * L
		s["tip"] = tip
		s["vel"] = v
		var qw := Quaternion(rdir, d)
		var bs := gt.basis.orthonormalized()
		var rsk := bs.inverse() * Basis(qw) * bs
		var local := pg.basis.inverse() * rsk * pg.basis * rest.basis
		sk.set_bone_pose_rotation(b, local.get_rotation_quaternion())

func bone_world(bn: String) -> Transform3D:
	var b := sk.find_bone(bn)
	return sk.global_transform * sk.get_bone_global_pose(b)
