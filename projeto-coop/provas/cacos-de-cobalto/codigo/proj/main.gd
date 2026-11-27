extends Node3D
# Prova de estilo "Cacos de Cobalto": monta a cena por código e captura.
# Args (depois de --): mode=sheet|beauty|stress|clip out=arquivo.png frames=N

const Fig := preload("res://fig.gd")
const Cena := preload("res://cena.gd")
var cena: Object
var shock_res := {}
const A := "res://assets/"
var args := {}
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sh := {}
var tex_cache := {}
var figs: Array = []
var extra_hulls: Array = []
var frame_i := 0
var frames := 6
var mode := "sheet"
var t_start := 0
var dt := 1.0 / 60.0

func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d

func _tex(n: String, mip := true) -> Texture2D:
	if tex_cache.has(n):
		return tex_cache[n]
	var img := Image.load_from_file(ProjectSettings.globalize_path(A + n))
	if mip:
		img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	tex_cache[n] = t
	return t

func _sm(n: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if not sh.has(n):
		sh[n] = load("res://shaders/%s.gdshader" % n)
	m.shader = sh[n]
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

func _ready() -> void:
	mode = _arg("mode", "sheet")
	frames = int(_arg("frames", "6"))
	_env()
	if mode == "sheet":
		_sheet()
	elif mode == "beauty":
		_beauty()
		if _arg("ss", "1") != "1":
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			get_viewport().scaling_3d_scale = float(_arg("ss", "1"))
		get_viewport().msaa_3d = Viewport.MSAA_4X
	elif mode == "poses":
		_poses()
	elif mode == "stress":
		_stress()
	elif mode == "clip":
		clip = load("res://clip.gd").new(self)
		clip.setup()
		get_viewport().msaa_3d = Viewport.MSAA_4X
	t_start = Time.get_ticks_msec()

# ------------------------------------------------------------------ ambiente
func _env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#C9C3B4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = false
	add_child(sun)
	# sol de fim de tarde a sudoeste, 50° de elevação (oeste = -X, sul = +Z)
	var az := deg_to_rad(225.0)
	var el := deg_to_rad(50.0)
	var to_sun := Vector3(-sin(az - PI) * cos(el), sin(el), cos(az - PI) * cos(el))
	el = deg_to_rad(float(_arg("sun_el", "50")))
	to_sun = Vector3(-0.62, 0.0, 0.62).normalized() * cos(el) + Vector3.UP * sin(el)
	sun.look_at_from_position(to_sun * 10.0, Vector3.ZERO)

# ------------------------------------------------------------------ figuras
func load_fig(n: String) -> Object:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(A + n + ".glb"), st)
	if err != OK:
		push_error("glb " + n)
	var r := doc.generate_scene(st, 60.0) as Node3D
	add_child(r)
	var meta := {}
	var mp := ProjectSettings.globalize_path(A + n + "_meta.json")
	if FileAccess.file_exists(mp):
		meta = JSON.parse_string(FileAccess.get_file_as_string(mp))
	var mats := {"corpo": _sm("figura", {"atlas": _tex(n + "_atlas.png")}), "contorno": _sm("contorno", {})}
	var f = Fig.new()
	f.setup(r, n, mats, meta)
	figs.append(f)
	return f

# ------------------------------------------------------------------ câmera de combate (camarote)
func _combat_cam(target: Vector3, dist: float, pitch_deg := 40.0, yaw_deg := 0.0, fov := 30.0) -> void:
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = fov
	cam.near = 0.5
	cam.far = 80.0
	var p := deg_to_rad(pitch_deg)
	var y := deg_to_rad(yaw_deg)
	var d := Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * dist
	cam.look_at_from_position(target + d, target)
	cam.current = true

func _scene_base() -> void:
	cena = Cena.new(self)
	cena.puddles = [[-0.9, -2.6, 2.7, 1.7, 1.0], [0.9, -2.2, 1.4, 1.2, 1.0], [-2.5, -2.1, 1.0, 0.9, 1.0], [-0.2, -3.6, 1.3, 0.8, 1.0]]
	cena.oil_spots = [[-6.3, -4.4, 0.9, 0.55, 1.0]]
	cena.burn_spots = [[-4.9, 0.1, 1.5, 0.9, 1.0], [-6.6, -2.4, 1.0, 0.8, 1.0]]
	cena.salt_spots = [[3.4, 0.5, 1.7, 0.9, 1.0], [5.6, -4.6, 1.6, 1.0, 1.0], [4.6, -0.4, 0.8, 0.6, 0.9]]
	cena.build(_tex("piso_atlas.png"), _tex("parede_atlas.png"), _tex("painel_barco.png"), _tex("placa.png"), Callable(self, "_sm"))

func _prop(n: String, pos: Vector3, yaw := 0.0, sc := 1.0) -> Object:
	var f = load_fig(n)
	f.root.position = pos
	f.root.rotation.y = deg_to_rad(yaw)
	f.root.scale = Vector3.ONE * sc
	return f

func _char(n: String, pos: Vector3, yaw: float, anim: String, frame: float, preroll := 0.35) -> Object:
	var f = load_fig(n)
	f.root.position = pos
	f.root.rotation.y = deg_to_rad(yaw)
	f.base_pos = pos
	f.play(anim, max(0.0, frame / 60.0 - preroll))
	f.set_meta("target_t", frame / 60.0)
	return f

func _yaw_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return rad_to_deg(atan2(d.x, d.z))

var vfx: Object
var clip: Object
var beauty_heroes := {}
var beauty_enemies := {}
var beauty_built := false
var shadow_decals: Array = []

func _beauty_env(pc: bool) -> void:
	if pc:
		sun.shadow_enabled = true
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 40.0
		sun.shadow_bias = 0.03
		sun.shadow_normal_bias = 1.0
		env.glow_enabled = true
		env.glow_intensity = 0.55
		env.glow_strength = 1.0
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = 1.05
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		for i in 7:
			env.set_glow_level(i, i >= 1 and i <= 4)


func _beauty() -> void:
	var pc := RenderingServer.get_current_rendering_method() != "gl_compatibility"
	_beauty_env(pc)
	_scene_base()
	vfx = load("res://vfx.gd").new(self, Callable(self, "_sm"))
	var tgt := Vector3(float(_arg("tx", "-0.5")), 0.55, float(_arg("tz", "-2.5")))
	_combat_cam(tgt, float(_arg("dist", "11.5")), float(_arg("pitch", "40")), float(_arg("yaw", "0")))
	if pc and _arg("dof", "1") == "1":
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_near_enabled = true
		ca.dof_blur_near_distance = float(_arg("dofn", "9.2"))
		ca.dof_blur_near_transition = 2.0
		ca.dof_blur_far_enabled = true
		ca.dof_blur_far_distance = float(_arg("doff", "17.5"))
		ca.dof_blur_far_transition = 5.0
		ca.dof_blur_amount = 0.05
		cam.attributes = ca
	# ---- cenário: adereços
	_prop("porta", Vector3(5.0, 0, -5.97))
	_prop("caixote", Vector3(-3.9, 0, -5.55), 8, 0.85)
	_prop("barril", Vector3(-6.5, 0, -4.7), 20)
	_prop("barril", Vector3(-5.7, 0, -5.35), -30)
	_prop("caixote", Vector3(6.9, 0, -4.9), 12)
	_prop("cabeco", Vector3(1.7, 0, 0.9), 0)
	_prop("rede", Vector3(-5.2, 0, 0.6), 30)
	_prop("caixote", Vector3(4.6, 0, 1.4), -18, 0.9)
	var bc = _prop("borda_cais", Vector3(-6.4 + 0.55 * 2.0, 0.0, 2.0), rad_to_deg(atan2(1.0, 0.55)) - 90.0)
	bc.root.position = Vector3(-6.4 + 0.55 * 0.0 + 0.05, -0.05, 0.0)
	# ---- heróis (P1 Lamparina: magenta + quadrado; P2 Bento: ciano + triângulo)
	var impact := Vector3(-2.45, 0, -2.1)
	var lp := Vector3(-5.2, 0, -4.35)
	var lamp = _char("lamparina", lp, _yaw_to(lp, impact) + float(_arg("lyaw", "-15")), "lancar", float(_arg("lf", "19")))
	lamp.face({"eye_open": 0.15, "mouth_open": 0.7, "mouth_curve": 0.6, "brow": -0.5})
	var bp := Vector3(-1.2, 0, -2.75)
	var bento = _char("bento", bp, float(_arg("byaw", "20")), _arg("ba", "idle"), float(_arg("bf", "20")))
	bento.face({"eye_open": 0.18, "mouth_curve": 0.7, "brow": 0.4, "look": Vector2(0.5, 0)})
	bento.set_param("oil", 1.0)
	beauty_heroes = {"lamp": lamp, "bento": bento}
	vfx.decal(0, lp, Vector2(1.25, 1.25), {"col": Color("#E43C9E"), "symbol": 0})
	vfx.decal(0, bp, Vector2(1.0, 1.0), {"col": Color("#23C4DB"), "symbol": 1})
	# ---- inimigos
	var l1 = _char("lasca", Vector3(0.55, 0, -3.05), _yaw_to(Vector3(0.55, 0, -3.05), bp), "golpeado", 4)
	var l2 = _char("lasca", Vector3(1.5, 0, -1.75), _yaw_to(Vector3(1.5, 0, -1.75), bp) + 20, "golpeado", 8)
	var l3 = _char("lasca", Vector3(-3.7, 0, -0.9), _yaw_to(Vector3(-3.7, 0, -0.9), lp), "telegrafia", 22)
	var l5 = _char("lasca", Vector3(-1.4, 0, 0.2), _yaw_to(Vector3(-1.4, 0, 0.2), lp) , "pulo", 13)
	var l4 = _char("lasca", Vector3(1.0, 0, -4.6), _yaw_to(Vector3(1.0, 0, -4.6), bp), "pulo", 16)
	l1.set_param("invert", 1.0)   # l1 no negativo (quadros 1-2 do golpe); l2 já no quadro 3: cor própria, fenda aberta
	l3.set_param("lacre", 1.0)
	var cr = _char("crosta", Vector3(2.7, 0, -1.5), _yaw_to(Vector3(2.7, 0, -1.5), bp) - 10, "telegrafia", 32)
	cr.set_param("lacre", 0.0)
	var ld = _char("ladrilheiro", Vector3(2.9, 0, -4.5), _yaw_to(Vector3(2.9, 0, -4.5), bp) + 10, "erguer", 30)
	beauty_enemies = {"l1": l1, "l2": l2, "l3": l3, "l4": l4, "cr": cr, "ld": ld}
	# telegrafias vermelho-lacre (formas que se fecham)
	vfx.decal(1, cr.base_pos, Vector2(3.2, 3.2), {"col": Color("#C42036"), "progress": 0.62})
	var ldir: Vector3 = (bp - ld.base_pos).normalized()
	vfx.decal(2, ld.base_pos + ldir * 1.35, Vector2(1.1, 2.2), {"col": Color("#C42036"), "progress": 0.55, "aspect": 0.5}, atan2(ldir.x, ldir.z))
	var l3dir: Vector3 = (lp - l3.base_pos).normalized()
	vfx.decal(2, l3.base_pos + l3dir * 0.75, Vector2(0.55, 1.2), {"col": Color("#C42036"), "progress": 0.4, "aspect": 0.46}, atan2(l3dir.x, l3dir.z))
	# sombras de contato (multiplicam por cobalto)
	for f in figs:
		if f.name in ["lamparina", "bento", "lasca", "crosta", "ladrilheiro"]:
			var en: bool = f.name in ["lasca", "crosta", "ladrilheiro"]
			var sz := 0.8 if f.name == "lasca" else (1.45 if f.name in ["crosta", "ladrilheiro"] else 1.05)
			shadow_decals.append(vfx.decal(5 if en else 3, f.base_pos, Vector2(sz, sz * 0.8), {"alpha": 0.6 if en else 0.55}))
	# ---- Condução: corre pelo rejunte da poça; trilhas principais até as vítimas
	shock_res = cena.conduct(Vector2(impact.x, impact.z), [Vector2(0.55, -3.05), Vector2(1.5, -1.75), Vector2(-1.2, -3.9), Vector2(2.3, -2.6), Vector2(-0.3, -1.0)])
	cena.floor_mat.set_shader_parameter("shock_t", float(_arg("st", "0.42")))
	cena.floor_mat.set_shader_parameter("time", 1.3)

func _beauty_late() -> void:
	# efeitos que dependem da pose final (posição da lanterna, do corpo dos inimigos)
	var cp := cam.global_position
	var st := float(_arg("st", "0.42"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lamp = beauty_heroes["lamp"]
	var tip: Vector3 = lamp.bone_world("mola_lanterna").origin + Vector3(0, -0.1, 0)
	var impact := Vector3(-2.45, 0.02, -2.1)
	# rastro da faísca: parábola com sombra-bolha no chão; a faísca já tocou o chão
	var arc: PackedVector3Array = vfx.parabola(tip, impact, 1.1, 28)
	vfx.ribbon(arc, 0.05, 0.11, cp, {"dash": 7.0, "emit": 1.6, "seed": 3.0}, 0.9)
	# a faísca racha o azulejo onde cai: fenda acesa de antimônio e cacos do esmalte saltando
	vfx.crack(impact, 1.3, {"life": 0.34, "seed": 1.3, "rays": 5.0, "glow": vfx.ELEM["faisca"]}, true)
	var sh0: Array = vfx.shards(impact + Vector3(0, 0.04, 0), Vector3.ZERO, 9, 5, {"bisque": Color("#D7B49C")}, 2.0, 0.07)
	vfx.shards_at(sh0, 0.17)

	# vítimas: raio do chão até o corpo, em 2 ou 3 fitas quebradas
	for key in ["l1", "l2"]:
		var e = beauty_enemies[key]
		var top: Vector3 = e.root.global_position + Vector3(0, 0.45, 0)
		for k in 3:
			var a: Vector3 = e.base_pos + Vector3(rng.randf_range(-0.35, 0.35), 0.02, rng.randf_range(-0.35, 0.35))
			var pts: PackedVector3Array = vfx.bolt_points(a, top + Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.15), 0), 4, 0.16, rng)
			vfx.ribbon(pts, 0.06, 0.03, cp, {"emit": 2.4, "seed": float(k)}, 1.0)
		# caco: rachadura de tinta que se abre sobre o alvo e estilhaços vidrados com miolo de terracota
		var away: Vector3 = (e.base_pos - impact).normalized()
		var tl := 0.22 if key == "l1" else 0.38
		vfx.crack(top + Vector3(0, -0.05, 0), 0.75, {"life": tl, "seed": rng.randf() * 6.0, "rays": 5.0, "glow": vfx.ELEM["faisca"]})
		var shl: Array = vfx.shards(top + Vector3(0, -0.1, 0), away, 8, 31 if key == "l1" else 47, {}, 2.4, 0.06)
		vfx.shards_at(shl, 0.13 if key == "l1" else 0.24)
	# arcos que saltam de junta em junta na frente da Condução
	var best: PackedFloat32Array = shock_res["best"]
	var front: Array = []
	for n in best.size():
		var t := best[n]
		if t < st and t > st - 0.05:
			front.append(n)
	front.shuffle()
	var made := 0
	for n in front:
		if made >= 9:
			break
		var iv: int = n % 73 - 36
		var k: int = n / 73 - 48
		var p := Vector3(iv * 0.25, 0.02, k * 0.125)
		var q := p + Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.35, 0.35))
		var mid := (p + q) * 0.5 + Vector3(0, rng.randf_range(0.18, 0.4), 0)
		var pts := PackedVector3Array([p, mid, q])
		var jag: PackedVector3Array = vfx.bolt_points(p, mid, 3, 0.07, rng)
		jag.append_array(vfx.bolt_points(mid, q, 3, 0.07, rng))
		vfx.ribbon(jag, 0.035, 0.02, cp, {"emit": 2.2, "seed": float(made)}, 0.95)
		made += 1
	# Isolante: o choque chega no pé do Bento e desvia em volta (casca furta-cor)
	var bento = beauty_heroes["bento"]
	for k in 5:
		var a0 := rng.randf() * TAU
		var r := 0.42
		var pts := PackedVector3Array()
		for j in 9:
			var aa := a0 + j * 0.16
			pts.append(bento.base_pos + Vector3(cos(aa) * r, 0.05 + 0.25 * sin(j / 8.0 * PI) + rng.randf_range(-0.03, 0.03), sin(aa) * r))
		vfx.ribbon(pts, 0.03, 0.015, cp, {"emit": 2.0, "seed": 9.0 + k, "col": Color("#F3C631")}, 0.85)
	pass

# ------------------------------------------------------------------ estresse: 4 heróis, 20 inimigos, 3 efeitos
var stress_chars: Array = []   # [fig, tipo "h"/"e", índice]
func _stress() -> void:
	var mask := _arg("mask", "0") == "1"
	_scene_base()
	vfx = load("res://vfx.gd").new(self, Callable(self, "_sm"))
	cena.puddles = [[-0.6, -2.2, 2.6, 1.6, 1.0], [1.4, -1.6, 1.3, 1.0, 1.0]]
	cena.oil_spots = [[3.6, -3.4, 1.6, 1.1, 1.0], [-6.3, -4.4, 0.9, 0.55, 1.0]]
	cena.burn_spots = [[3.6, -3.4, 1.8, 1.25, 1.0]]
	cena.salt_spots = [[5.6, -4.9, 1.3, 0.7, 1.0], [-3.2, 1.4, 1.0, 0.6, 1.0]]
	cena.make_state()
	var tgt := Vector3(float(_arg("tx", "-0.3")), 0.5, float(_arg("tz", "-2.2")))
	_combat_cam(tgt, float(_arg("dist", "13")), float(_arg("pitch", "44")), 0.0)
	_prop("porta", Vector3(5.0, 0, -5.97))
	_prop("barril", Vector3(-6.5, 0, -4.7), 20)
	_prop("barril", Vector3(-5.7, 0, -5.35), -30)
	_prop("caixote", Vector3(-3.9, 0, -5.55), 8, 0.85)
	_prop("cabeco", Vector3(1.6, 0, 1.6), 0)
	_prop("rede", Vector3(-5.4, 0, 1.0), 30)
	# heróis com anel e símbolo de jogador
	var H := [["lamparina", Vector3(-3.6, 0, -3.3), "#E43C9E", 0, "lancar", 19.0],
		["bento", Vector3(-0.9, 0, -2.4), "#23C4DB", 1, "isolado", 30.0],
		["nina", Vector3(-2.4, 0, -0.4), "#9A78E0", 2, "idle", 10.0],
		["galvao", Vector3(1.2, 0, 0.1), "#9BE03C", 3, "idle", 20.0]]
	var center := Vector3(0.6, 0, -2.0)
	for i in H.size():
		var h: Array = H[i]
		var f = _char(h[0], h[1], _yaw_to(h[1], center), h[4], h[5])
		stress_chars.append([f, "h", i])
		var rc := Color(h[2])
		var ed := Color("#0D1029") if i < 3 else Color("#0D1029")
		vfx.decal(0, h[1], Vector2(1.25, 1.25) if h[0] != "nina" else Vector2(1.0, 1.0), {"col": rc, "symbol": h[3], "edge": ed})
		if h[0] == "bento":
			f.set_param("oil", 1.0)
	# 20 inimigos: 14 Lascas, 3 Ladrilheiros, 3 Crostas
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var E: Array = []
	var lasca_pos := [Vector3(0.6, 0, -3.0), Vector3(1.6, 0, -1.9), Vector3(0.0, 0, -1.2), Vector3(2.6, 0, -1.55), Vector3(3.0, 0, -0.8), Vector3(2.4, 0, 0.6),
		Vector3(-4.6, 0, -1.4), Vector3(-5.2, 0, -2.6), Vector3(-1.0, 0, 0.8), Vector3(4.1, 0, -1.9), Vector3(4.6, 0, -0.2), Vector3(-2.6, 0, -4.6), Vector3(0.4, 0, -4.6), Vector3(5.4, 0, -3.0)]
	for p in lasca_pos:
		E.append(["lasca", p])
	for p in [Vector3(2.4, 0, -4.7), Vector3(-1.2, 0, -5.0), Vector3(6.4, 0, -4.7)]:
		E.append(["ladrilheiro", p])
	for p in [Vector3(5.7, 0, -1.9), Vector3(-5.0, 0, 0.0), Vector3(3.0, 0, 1.0)]:
		E.append(["crosta", p])
	for j in E.size():
		var e: Array = E[j]
		var an := "pulo" if e[0] == "lasca" else ("erguer" if e[0] == "ladrilheiro" else "idle")
		var fr := rng.randf_range(4.0, 28.0)
		var f = _char(e[0], e[1], _yaw_to(e[1], Vector3(-1.0, 0, -2.0)) + rng.randf_range(-25, 25), an, fr)
		stress_chars.append([f, "e", j])
		if cena.wet_at(e[1].x, e[1].z) > 0.5 and e[0] == "lasca":
			f.set_param("lacre", 0.0)
	# a Crosta do incêndio telegrafa
	stress_chars[4 + 14][0].set_param("lacre", 0.0)
	stress_chars[4 + 14][0].set_param("lacre_mat", 0.5)
	vfx.decal(1, Vector3(5.7, 0, -1.9), Vector2(3.0, 3.0), {"col": Color("#C42036"), "progress": 0.5})
	for f in figs:
		if f.name in ["lamparina", "bento", "nina", "galvao", "lasca", "crosta", "ladrilheiro"]:
			var en: bool = f.name in ["lasca", "crosta", "ladrilheiro"]
			var sz := 0.8 if f.name in ["lasca", "nina"] else (1.4 if f.name in ["crosta", "ladrilheiro"] else 1.05)
			shadow_decals.append(vfx.decal(5 if en else 3, f.base_pos, Vector2(sz, sz * 0.8), {"alpha": 0.6 if en else 0.5}))
	# Condução na poça
	shock_res = cena.conduct(Vector2(-2.3, -2.4), [Vector2(0.6, -3.0), Vector2(1.6, -1.9), Vector2(0.0, -1.2), Vector2(2.3, -2.7)], 8.0, 4)
	cena.floor_mat.set_shader_parameter("shock_t", 0.42)
	# Incêndio no óleo: base em brasa (veios que respiram) e línguas de fogo pintadas, cada uma com fase própria
	stress_fx.append(vfx.decal(6, Vector3(3.6, 0, -3.4), Vector2(3.6, 2.6), {"time": 1.0, "alpha": 0.95}))
	var fire_r := RandomNumberGenerator.new()
	fire_r.seed = 3
	for k in 14:
		var a := fire_r.randf() * TAU
		var r := sqrt(fire_r.randf())
		var p := Vector3(3.6 + cos(a) * r * 1.35, 0, -3.4 + sin(a) * r * 0.9)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.0, 1.0)
		qm.center_offset = Vector3(0, 0.5, 0)
		q.mesh = qm
		q.material_override = _sm("fogo", {"time": 1.0, "seed": fire_r.randf() * 10.0})
		q.position = p
		var s := fire_r.randf_range(0.6, 0.95) * (1.2 - r * 0.45)
		q.scale = Vector3(s * 0.85, s * 1.35, 1.0)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)
		stress_fx.append(q)
	# Lufada da Nina: arcos de golpe na cor do jogador (lilás), alfa decrescente, só atrás e dos lados
	# dela (nunca cruzando a frente do corpo) e desenhados antes dela
	var npos := Vector3(-2.4, 0, -0.4)
	for arc_i in 2:
		var sp := PackedVector3Array()
		for i in 30:
			var u := i / 29.0
			var aa := PI * 1.15 + u * PI * 1.25 + arc_i * 0.5   # de trás para os lados (o lado da câmera fica livre)
			var rr := 0.75 + u * 0.55 + arc_i * 0.25
			sp.append(npos + Vector3(cos(aa) * rr, 0.25 + u * 0.35 + arc_i * 0.15, sin(aa) * rr * 0.8))
		var rb: MeshInstance3D = vfx.ribbon(sp, 0.2, 0.06, cam.global_position, {"col": Color("#9A78E0"), "core": Color("#E9E0FA"), "edge": Color("#3A2766"), "emit": 0.2, "dash": 0.0, "fade": 0.85, "seed": float(arc_i)}, 1.0)
		rb.material_override.render_priority = -1
		stress_fx.append(rb)
	# Condução: o azulejo racha onde a faísca caiu
	stress_fx.append(vfx.crack(Vector3(-2.3, 0, -2.4), 1.0, {"life": 0.34, "seed": 2.1, "rays": 5.0, "glow": vfx.ELEM["faisca"]}, true))
	var shs: Array = vfx.shards(Vector3(-2.3, 0.04, -2.4), Vector3.ZERO, 8, 9, {"bisque": Color("#D7B49C")}, 2.0, 0.07)
	vfx.shards_at(shs, 0.18)
	if mask:
		_mask_mode()

var stress_fx: Array = []
func _mask_mode() -> void:
	env.background_color = Color.BLACK
	env.glow_enabled = false
	for n in get_children():
		if n is MeshInstance3D:
			n.visible = false
	for f in figs:
		var keep := false
		for sc in stress_chars:
			if sc[0] == f:
				keep = true
				var c := Color8(255, 0, 20 + int(sc[2]) * 40) if sc[1] == "h" else Color8(0, 255, 10 + int(sc[2]) * 10)
				var mm := StandardMaterial3D.new()
				mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mm.albedo_color = c
				for mi in f.root.find_children("*", "MeshInstance3D", true, false):
					for i in mi.mesh.get_surface_count():
						mi.set_surface_override_material(i, mm)
				var hm := _sm("contorno", {"ink_col": c})
				f.hull = hm
				for mi in f.root.find_children("*", "MeshInstance3D", true, false):
					for i in mi.mesh.get_surface_count():
						var sm0: Material = mi.mesh.surface_get_material(i)
						if sm0 and sm0.resource_name == "contorno":
							mi.set_surface_override_material(i, hm)
		if not keep:
			f.root.visible = false

# ------------------------------------------------------------------ poses-chave de um clipe (lado a lado)
var pose_list: Array = []
func _poses() -> void:
	var n := _arg("who", "lamparina")
	var an := _arg("anim", "lancar")
	var ts := _arg("t", "1,5,9,15,17,25,41,51").split(",")
	var yaw := float(_arg("yaw", "60"))
	var sp := float(_arg("sp", "1.3"))
	var x := 0.0
	for tf in ts:
		var f = load_fig(n)
		f.root.position = Vector3(x, 0, 0)
		f.root.rotation.y = deg_to_rad(yaw)
		f.play(an, float(tf) / 60.0)
		pose_list.append(f)
		x += sp
	cam = Camera3D.new()
	add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = max(float(_arg("size", "2.4")), (x - sp + 1.2) / (16.0 / 9.0))
	var cx := (x - sp) / 2.0
	var pitch := deg_to_rad(float(_arg("pitch", "15")))
	var cy := float(_arg("cy", "0.9"))
	cam.look_at_from_position(Vector3(cx, cy + sin(pitch) * 10.0, cos(pitch) * 10.0), Vector3(cx, cy, 0))
	cam.current = true

# ------------------------------------------------------------------ folha de modelo (vistas ortográficas)
func _sheet() -> void:
	var who := _arg("who", "lamparina,bento").split(",")
	var yaws := [0.0, 35.0, 90.0]
	var x := 0.0
	for n in who:
		for y in yaws:
			var f = load_fig(n)
			f.root.position = Vector3(x, 0, 0)
			f.root.rotation.y = deg_to_rad(y)
			f.face({"eye_open": 1.0, "mouth_curve": 0.5})
			if _arg("anim", "") != "" and f.ap and f.ap.has_animation(_arg("anim", "")):
				f.play(_arg("anim", ""), float(_arg("at", "0")))
			x += float(_arg("sp", "1.1"))
		x += 0.3
	cam = Camera3D.new()
	add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(_arg("size", "2.3"))
	if _arg("fit", "1") == "1":
		cam.size = max(cam.size, (x - 0.3) / (16.0 / 9.0) + 0.2)
	var cx := (x - float(_arg("sp", "1.1")) - 0.3) / 2.0
	var pitch := deg_to_rad(float(_arg("pitch", "8")))
	var scy := float(_arg("cy", "0.95"))
	cam.look_at_from_position(Vector3(cx, scy + sin(pitch) * 10.0, cos(pitch) * 10.0), Vector3(cx, scy, 0))
	cam.current = true

func cam_uniforms() -> void:
	var vh := float(get_viewport().get_visible_rect().size.y)
	var mo := 0.0
	var kp := 0.0
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		mo = cam.size / vh
	else:
		kp = 2.0 * tan(deg_to_rad(cam.fov) / 2.0) / vh
	for f in figs:
		f.hull.set_shader_parameter("vh", vh)
		f.hull.set_shader_parameter("mpp_ortho", mo)
		f.hull.set_shader_parameter("k_persp", kp)
	for m in extra_hulls:
		m.set_shader_parameter("vh", vh)
		m.set_shader_parameter("mpp_ortho", mo)
		m.set_shader_parameter("k_persp", kp)

func _process(_d: float) -> void:
	frame_i += 1
	cam_uniforms()
	if mode == "clip":
		clip.step(frame_i)
		if _arg("still", "") != "" and frame_i == int(_arg("still", "1")):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_arg("out", "/tmp/out.png"))
			print("PROBE ms=%d" % [Time.get_ticks_msec() - t_start])
			get_tree().quit()
		if frame_i >= frames:
			print("PROBE ms=%d frames=%d" % [Time.get_ticks_msec() - t_start, frame_i])
			get_tree().quit()
		return
	for f in figs:
		if f.has_meta("target_t"):
			f.t = min(f.t + dt, float(f.get_meta("target_t")))
		f.pose_now()
		f.spring_tick(dt)
	if mode == "stress":
		for q in stress_fx:
			if q is MeshInstance3D and q.material_override:
				q.material_override.set_shader_parameter("time", 1.0 + frame_i / 60.0)
	if mode == "beauty" and frame_i == frames - 2 and not beauty_built:
		beauty_built = true
		_beauty_late()
	if frame_i == frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(_arg("out", "/tmp/out.png"))
		print("PROBE ms=%d draws=%d" % [Time.get_ticks_msec() - t_start, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
		get_tree().quit()
