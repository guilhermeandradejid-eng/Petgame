extends Node3D
## Mini Fúria: corrida isométrica de combate com mini carros.
## Fluxo: menu -> escolha da pista -> garagem (carro, armas, nitro, upgrades) -> corrida -> resultado ($).

const LAPS := 3
const PRIZE := [1000, 650, 400, 250, 120]
const KILL_BONUS := 150
const UP_PRICE := [400, 900, 1600]
const CAM_YAW := PI / 4.0
const CAM_PITCH := 0.62
const CAM_DIST := 70.0   # câmera ortográfica: mais perto = sombras do sol cobrindo a tela toda
const SAVE_PATH := "user://minifuria.json"

const RIVALS := [
	{"kind": "trovao", "color": "#2f6fd6", "name": "TROVÃO"},
	{"kind": "vespa", "color": "#ffb31a", "name": "VESPA"},
	{"kind": "trovao", "color": "#8a5cd6", "name": "CORISCO"},
	{"kind": "vespa", "color": "#2fbf71", "name": "JARARACA"},
]
const TRAFFIC := [
	["sedan", ["#5cc26b", "#f08a7a", "#7fc8d9", "#e6e1d6", "#9a7cf0"]],
	["taxi", ["#ffcf33"]],
	["policia", ["#f4f4f4"]],
	["picape", ["#8a5cd6", "#e2553b", "#3d8bd6"]],
	["van", ["#f08a7a", "#ffd23a", "#7fc8d9"]],
]

var lib: Node3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var cam: Camera3D
var hud: Hud
var sfx: Sfx
var fx: Fx
var weapons: Weapons
var world: Node3D
var track: Track
var track_idx := 0
var theme: Dictionary
var ground_shader: Shader
var road_shader: Shader

var cars: Array = []
var rivals: Array = []
var traffic: Array = []
var props: Array = []
var pickups: Array = []
var player: Car
var em := {}
var scrape_pool: Array = []

var mode := "menu"
var prev_mode := "race"
var save := {}
var stats := {}
var time_g := 0.0
var real := 0.0
var ts := 1.0
var ts_target := 1.0
var slow_t := 0.0
var hitstop := 0.0
var trauma := 0.0
var shake_t := 0.0
var zoom_kick := 0.0
var view_h := 28.0
var cam_pos := Vector3.ZERO
var cam_focus: Car = null
var focus_t := 0.0
var flash := Color(1, 1, 1, 0)
var race_t := 0.0
var countdown := 0.0
var last_beep := 4
var lap_start := 0.0
var best_lap := INF
var crash_t := -1.0
var place := 5
var onc_dist := 0.0
var nm_combo := 0
var last_nm := -10.0
var was_drift := false
var was_nitro := false
var _last_us := 0
var auto_test := false
var test_shots: Array = []
var test_lane := 0.0
var post_blur := 0.0
var post_aberr := 0.0
var post_lines := 0.0
var wrong_t := 0.0
var steer_testing := false
var test_zoom := 0.0
var cam_yaw := CAM_YAW
var cam_pitch := CAM_PITCH
var cam_mode := ""
var cam_mode_t := 0.0
var cam_loop := {}
var cam_kick := Vector3.ZERO
var oil_fx := 0.0


func _ready() -> void:
	randomize()
	_setup_input()
	_load_save()
	var args := OS.get_cmdline_user_args()
	auto_test = "--autotest" in args
	for a in args:
		if a.begins_with("--shots="):
			test_shots = Array(a.substr(8).split(","))
		if a.begins_with("--lane="):
			test_lane = float(a.substr(7))
		if a.begins_with("--track="):
			track_idx = int(a.substr(8))
		if a.begins_with("--zoom="):
			test_zoom = float(a.substr(7))

	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(5, 0.6)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.14
	env.adjustment_brightness = 0.97
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 1.1
	sun.shadow_opacity = 0.92
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = view_h
	cam.near = 1.0
	cam.far = 500.0
	add_child(cam)
	cam.make_current()

	lib = (load("res://assets/minicars.glb") as PackedScene).instantiate()
	_prep_materials(lib, {})
	ground_shader = load("res://shaders/ground.gdshader")
	road_shader = load("res://shaders/road.gdshader")
	fx = Fx.new()
	add_child(fx)
	sfx = Sfx.new()
	add_child(sfx)
	for i in 6:
		var sc := fx.make_scrape()
		fx.add_child(sc)
		scrape_pool.append(sc)
	weapons = Weapons.new()
	add_child(weapons)
	weapons.setup(self, fx, sfx, lib)
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	load_track(track_idx)
	_last_us = Time.get_ticks_usec()
	if "--overview" in args:
		_overview_shots()
	elif "--steertest" in args:
		_steer_test()
	elif "--uishot" in args:
		_ui_shots()
	elif auto_test:
		start_race()


func _steer_test() -> void:
	steer_testing = true
	save.steer = "tela"
	start_race()
	while mode != "race":
		await get_tree().physics_frame
	var rr := Vector3(cos(CAM_YAW), 0, -sin(CAM_YAW))
	var ff := Vector3(-sin(CAM_YAW), 0, -cos(CAM_YAW))
	for test in [["tela", "left", -rr], ["tela", "right", rr], ["tela", "down", -ff], ["tela", "up", ff], ["carro", "left", rr]]:
		save.steer = test[0]
		# carro andando para BAIXO da tela, a 20 m/s, numa reta
		var a := track.at(60.0)
		var down := -ff
		var bs := Basis.looking_at(-down, Vector3.UP)
		player.place(Transform3D(bs, Vector3(400, float(theme.gy) + 0.3, 400)), 20.0)
		wrong_t = -1000.0
		for k in 20:
			await get_tree().physics_frame
		Input.action_press(test[1])
		for k in (150 if test[1] == "up" else 70):
			await get_tree().physics_frame
		Input.action_release(test[1])
		var fwd := player.global_transform.basis.z
		fwd = Vector3(fwd.x, 0, fwd.z).normalized()
		var exp_dir: Vector3 = test[2]
		print("STEER %s tecla=%s  frente·esperado=%.2f  (1 = virou para o lado certo)" % [test[0], test[1], fwd.dot(exp_dir)])
	get_tree().quit()


## fotos de inspeção: pista inteira vista de cima + closes nos elementos especiais e na decoração
func _overview_shots() -> void:
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = int(a.substr(7))
	for ti in TrackData.TRACKS.size():
		if only >= 0 and ti != only:
			continue
		load_track(ti)
		hud.show_screen("none")
		var spots: Array = []
		var i := 0
		while i < track.n and spots.size() < 4:
			if track.feat[i] == 1 and track.feat[track.idx(i - 1)] == 0:
				spots.append(track.P[track.idx(i + 20)])
				i += 40
			i += 1
		# trecho elevado normal (decoração ao lado da pista)
		for k in range(0, track.n, 7):
			if track.feat[k] == 0 and track.P[k].y - float(theme.gy) > 4.0:
				spots.append(track.P[k])
				break
		spots.append(track.P[0])
		for si in spots.size():
			mode = "shots"
			cam_pos = spots[si]
			view_h = 46.0
			for f in 6:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("user://ov_t%d_%d.png" % [ti, si])
	get_tree().quit()


func _ui_shots() -> void:
	for scr in ["menu", "tracks", "garage"]:
		hud.show_screen(scr)
		for k in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://ui_%s.png" % scr)
	get_tree().quit()


func _exit_tree() -> void:
	if is_instance_valid(lib):
		lib.free()


func _setup_input() -> void:
	var keys := {
		"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D], "up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S],
		"drift": [KEY_SPACE], "nitro": [KEY_SHIFT, KEY_N], "fire": [KEY_Z, KEY_J, KEY_CTRL], "drop": [KEY_X, KEY_K],
		"brake": [KEY_B, KEY_C],
		"reset": [KEY_R], "pause": [KEY_P, KEY_ESCAPE], "mute": [KEY_M],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)


# ------------------------------------------------------------------ save
func _load_save() -> void:
	save = {"cash": 800, "car": "faisca", "front": "mg", "rear": "mine", "nitro": "short", "steer": "tela",
		"up": {"engine": 0, "armor": 0, "ammo": 0, "nitro": 0}, "best": {}}
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				save[k] = d[k]
	for k in ["engine", "armor", "ammo", "nitro"]:
		save.up[k] = int(save.up.get(k, 0))


func _write_save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))


func upgrade_price(k: String) -> int:
	return UP_PRICE[mini(int(save.up[k]), 2)]


func buy_upgrade(k: String) -> void:
	var lvl: int = save.up[k]
	if lvl >= 3:
		return
	var price := upgrade_price(k)
	if int(save.cash) < price:
		return
	save.cash = int(save.cash) - price
	save.up[k] = lvl + 1
	_write_save()
	sfx.play("pickup")
	hud.refresh_garage()


func equip(slot: String, key: String) -> void:
	save[slot] = key
	_write_save()
	sfx.play("drop", -6.0)
	hud.refresh_garage()


# ------------------------------------------------------------------ materiais e cenário
func _prep_materials(n: Node, done: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m == null or done.has(m):
				continue
			done[m] = true
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = false
			match m.resource_name:
				"Paint", "Paint2":
					m.roughness = 0.24
					m.metallic = 0.18
					m.metallic_specular = 0.7
					m.rim_enabled = true
					m.rim = 0.25
					m.rim_tint = 0.6
				"Glass":
					m.roughness = 0.03
					m.metallic = 0.7
					m.metallic_specular = 1.0
				"Chrome", "Rim":
					m.roughness = 0.12
					m.metallic = 1.0
				"Tire":
					m.roughness = 0.95
				"SignYellow", "SignBlack", "Metal":
					m.cull_mode = BaseMaterial3D.CULL_DISABLED
				"Headlight", "Taillight", "LampGlow", "Window", "Billboard", "Billboard2", "CrystalC", "CrystalM", "RedLight", "NitroBlue":
					m.vertex_color_use_as_albedo = false
	for c in n.get_children():
		_prep_materials(c, done)


func _inst(name_: String) -> Node3D:
	var n := lib.get_node(name_).duplicate() as Node3D
	n.transform = Transform3D.IDENTITY
	_shadows(n)
	return n


func _shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children():
		_shadows(c)


func load_track(i: int) -> void:
	Engine.time_scale = 1.0
	track_idx = i
	if world:
		remove_child(world)
		world.queue_free()
	weapons.clear()
	for d in fx.debris:
		(d.rb as Node).queue_free()
	fx.debris.clear()
	for tr in fx.trails:
		(tr.mi as Node).queue_free()
	fx.trails.clear()
	fx.skid_mm.visible_instance_count = 0
	fx.skid_head = 0
	em.clear()
	cars.clear()
	rivals.clear()
	traffic.clear()
	props.clear()
	pickups.clear()
	var data: Dictionary = TrackData.TRACKS[i]
	theme = TrackData.THEMES[data.theme]
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	track = Track.new()
	track.setup(data, theme)
	world.add_child(track)
	track.build(ground_shader, road_shader)
	_apply_theme()
	_build_scenery()
	_spawn_cars()
	hud.set_track(track)
	hud.cars = cars
	hud.player = player
	cam_pos = player.global_position
	mode = "menu"


func _apply_theme() -> void:
	sky_mat.sky_top_color = Color(theme.sky_top)
	sky_mat.sky_horizon_color = Color(theme.sky_hor)
	sky_mat.ground_horizon_color = Color(theme.sky_hor)
	sky_mat.ground_bottom_color = Color(theme.ga).darkened(0.3)
	env.background_color = Color(theme.bg)
	# color grade: ambiente mais baixo (sombras mais densas) e noites bem mais escuras
	var night := bool(theme.night)
	var dusk := bool(theme.get("dusk", false))
	env.ambient_light_energy = float(theme.amb) * (0.5 if night else (0.6 if dusk else 0.72))
	env.tonemap_exposure = 0.92 if night else (0.95 if dusk else 1.0)
	env.adjustment_saturation = 1.18 if night else 1.1
	env.adjustment_contrast = 1.2 if night else 1.14
	env.fog_enabled = String(theme.fog) != ""
	if env.fog_enabled:
		env.fog_light_color = Color(theme.fog)
		env.fog_density = float(theme.get("fog_d", 0.0011))
	sun.light_color = Color(theme.sun)
	sun.light_energy = float(theme.sun_e) * (0.55 if night else (0.75 if dusk else 1.05))
	sun.rotation = Vector3(deg_to_rad(theme.sun_rot[0]), deg_to_rad(theme.sun_rot[1]), 0)
	env.glow_intensity = 0.8 if night else 0.55


func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337 + track_idx * 101
	var a0 := track.at(0.0)
	var gate := _inst("prop_gate")
	var gs: float = (track.WALL - 0.35) / 13.0
	gate.transform = Transform3D((a0.basis as Basis).scaled_local(Vector3(gs, 1, 1)), a0.pos)
	world.add_child(gate)
	for e in [[24.0, -1.0], [50.0, -1.0], [-30.0, 1.0]]:
		var p := track.at(e[0], e[1] * (track.WALL + 4.0))
		if track.U[p.i].y < 0.9 or track.P[p.i].y - float(theme.gy) > 1.5 or float(theme.gy) < -0.5:
			continue
		var st := _inst("prop_stand")
		var n: Vector3 = (p.left as Vector3) * -float(e[1])
		st.position = Vector3(p.pos.x, float(theme.gy), p.pos.z)
		st.rotation.y = atan2(n.x, n.z)
		world.add_child(st)
	for spot in track.decor_spots():
		var nd := _inst(spot.kind)
		nd.transform = spot.xf
		if spot.get("flip", false):
			nd.scale = Vector3(-1, 1, 1)
		world.add_child(nd)
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for i in range(0, track.n, 5):
		mn = mn.min(Vector2(track.P[i].x, track.P[i].z))
		mx = mx.max(Vector2(track.P[i].x, track.P[i].z))
	mn -= Vector2(70, 70)
	mx += Vector2(70, 70)
	var list: Array = theme.props
	var total := 0
	for it in list:
		total += int(it[1])
	var gy: float = theme.gy
	var placed := 0
	var dens: int = theme.density
	var pscale: float = theme.get("prop_scale", 1.0)
	for k in dens * 4:
		if placed >= dens or total == 0:
			break
		var x := rng.randf_range(mn.x, mx.x)
		var z := rng.randf_range(mn.y, mx.y)
		if track.clearance_xz(Vector3(x, 0, z)) < track.WALL + 5.0 * pscale:
			continue
		var r := rng.randi() % total
		var kind := ""
		for it in list:
			r -= int(it[1])
			if r < 0:
				kind = it[0]
				break
		if kind == "container":
			_container_pad(Vector3(x, gy, z), rng)
		else:
			var m := _inst(kind)
			var base_y := gy
			if gy < -0.5:
				base_y = gy + 0.6
				_mound(Vector3(x, gy, z), rng.randf_range(2.4, 3.6))
			m.position = Vector3(x, base_y, z)
			m.rotation.y = rng.randf() * TAU
			m.scale = Vector3.ONE * (0.8 + rng.randf() * 0.7) * pscale
			world.add_child(m)
		placed += 1
	placed = 0
	var bn: int = theme.bldg
	for k in bn * 6:
		if placed >= bn:
			break
		var x := rng.randf_range(mn.x - 40, mx.x + 40)
		var z := rng.randf_range(mn.y - 40, mx.y + 40)
		if track.clearance_xz(Vector3(x, 0, z)) < track.WALL + 12.0:
			continue
		var b := _inst(["prop_bldgA", "prop_bldgB", "prop_bldgC"][rng.randi() % 3])
		b.position = Vector3(x, gy, z)
		b.rotation.y = round(rng.randf() * 4.0) * PI / 2.0
		if theme.night:
			b.scale = Vector3(1.0, 1.0 + rng.randf() * 1.5, 1.0)
		world.add_child(b)
		placed += 1
	if theme.ground == 8:
		_clouds(rng, mn, mx)
	for ps in track.pickup_spots:
		var a := track.at(ps.s, ps.lat)
		var nd := _inst("pickup_" + String(ps.kind))
		nd.position = a.pos + a.up * 1.0
		world.add_child(nd)
		var glow := MeshInstance3D.new()
		var gp := PlaneMesh.new()
		gp.size = Vector2(3.2, 3.2)
		glow.mesh = gp
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.albedo_texture = fx.dot_tex
		gm.albedo_color = {"ammo": Color(0.6, 1.4, 0.4), "repair": Color(1.5, 0.5, 0.45), "nitro": Color(0.4, 0.9, 1.6)}[ps.kind]
		glow.material_override = gm
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.transform = Transform3D(a.basis, (a.pos as Vector3) + (a.up as Vector3) * 0.1)
		world.add_child(glow)
		pickups.append({"node": nd, "kind": ps.kind, "t": 0.0, "base": a.pos + a.up * 1.0, "up": a.up})
	var made := 0
	for i in track.n:
		if made >= 6:
			break
		if track.feat[i] == 0 and absf(track.curv[i]) > 1.0 / 32.0 and track.U[i].y > 0.95 and i % 4 == 0:
			var outside := signf(track.curv[i])
			for j in 3:
				var a := track.at(i * track.ds + j * 2.5, outside * (track.HALF + 0.6))
				_add_prop("prop_crate" if theme.road == 1 else ["prop_barrel", "prop_tires"][j % 2], a, 30.0, Vector2(0.5, 1.0))
			made += 1


func _mound(p: Vector3, r: float) -> void:
	# ilhota de terra/pedra embaixo dos objetos na água ou na lava
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.75
	cm.bottom_radius = r
	cm.height = 1.4
	cm.radial_segments = 9
	cm.rings = 1
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(theme.shoulder).darkened(0.1) if theme.ground != 3 else Color("#5a6b3a")
	m.roughness = 1.0
	mi.material_override = m
	mi.position = p + Vector3(0, -0.1, 0)
	mi.rotation.y = randf() * TAU
	world.add_child(mi)


func _container_pad(p: Vector3, rng: RandomNumberGenerator) -> void:
	var pad := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(9, 4, 15)
	pad.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#8a8d94")
	m.roughness = 0.9
	pad.material_override = m
	pad.position = p + Vector3(0, 1.6, 0)
	pad.rotation.y = rng.randf() * TAU
	world.add_child(pad)
	var cnt := rng.randi_range(1, 3)
	for k in cnt:
		var c := _inst(["prop_containerR", "prop_containerB", "prop_containerY"][rng.randi() % 3])
		c.position = Vector3([-2.5, 2.5, 0.0][k], 2.0 + (2.6 if k == 2 else 0.0), 0)
		pad.add_child(c)


func _clouds(rng: RandomNumberGenerator, mn: Vector2, mx: Vector2) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.85, 0.88, 1.0)
	m.emission_energy_multiplier = 0.35
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 7
	for k in 34:
		var c := Vector3(rng.randf_range(mn.x, mx.x), float(theme.gy) + rng.randf_range(-3, 3), rng.randf_range(mn.y, mx.y))
		var s := rng.randf_range(6, 14)
		for b in rng.randi_range(4, 7):
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			mi.material_override = m
			var bs := s * rng.randf_range(0.5, 1.0)
			mi.scale = Vector3(bs, bs * 0.75, bs)
			mi.position = c + Vector3(rng.randf_range(-1.4, 1.4) * s, rng.randf_range(0.0, 0.5) * s, rng.randf_range(-1.0, 1.0) * s)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(mi)


func _add_prop(name_: String, a: Dictionary, m: float, dims: Vector2) -> void:
	var rb := RigidBody3D.new()
	rb.mass = m
	rb.collision_layer = 4
	rb.collision_mask = 1 | 2 | 4
	rb.contact_monitor = true
	rb.max_contacts_reported = 2
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.6
	rb.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = dims.x
	c.height = dims.y
	cs.shape = c
	cs.position.y = dims.y * 0.5
	rb.add_child(cs)
	rb.add_child(_inst(name_))
	world.add_child(rb)
	rb.global_transform = Transform3D(a.basis, (a.pos as Vector3) + (a.up as Vector3) * 0.05)
	var pr := {"rb": rb, "hit": false, "name": name_}
	props.append(pr)
	rb.body_entered.connect(func(b): _prop_hit(pr, b))


func _prop_hit(pr: Dictionary, b: Node) -> void:
	if pr.hit or not (b is Car):
		return
	pr.hit = true
	var c: Car = b
	var rb: RigidBody3D = pr.rb
	var v := c.linear_velocity
	rb.apply_central_impulse((v * 0.5 + Vector3.UP * (4.0 + v.length() * 0.25)) * rb.mass)
	rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * rb.mass * 3.0)
	fx.sparks(rb.global_position + Vector3.UP * 0.5, v, 0.3)
	fx.burst("smoke", rb.global_position + Vector3.UP * 0.4)
	if c == player and mode == "race":
		sfx.play("smash", -4.0)
		_shake(0.2)
		stats.score += 25


# ------------------------------------------------------------------ carros
func _make_car(kind: String, role: String, col: Color) -> Car:
	var c := Car.new()
	c.setup(lib, kind, role, col)
	c.grav_factor = float(theme.grav)
	c.grip_factor = float(theme.grip)
	world.add_child(c)
	c.hit.connect(_on_hit)
	c.part_off.connect(_on_part_off)
	c.landed.connect(_on_landed)
	c.died.connect(_on_died)
	cars.append(c)
	var e := {"skid": [null, null, null, null]}
	if role != "traffic":
		e.smoke = [fx.make_tire_smoke(), fx.make_tire_smoke()]
		e.dust = [fx.make_dust(), fx.make_dust()]
		for s in e.smoke + e.dust:
			world.add_child(s)
		_add_xray(c)
		if bool(theme.night) or bool(theme.get("dusk", false)):
			e.lights = _add_headlights(c)
		e.flame = fx.make_nitro_flame()
		c.add_child(e.flame)
		e.flame.position = c.exhaust_local
		# segundo cano: mesma chama, sem luz própria (uma luz por carro basta)
		e.flame2 = fx.make_nitro_flame(false)
		c.add_child(e.flame2)
		e.flame2.position = c.exhaust2_local
		e.trails = [fx.make_trail(Color(1.5, 0.25, 0.4)), fx.make_trail(Color(1.5, 0.25, 0.4))]
	e.dark = fx.make_damage_smoke(true)
	e.fire = fx.make_damage_smoke(false)
	c.add_child(e.dark)
	c.add_child(e.fire)
	e.dark.position = Vector3(0, 1.0, c.sp.len * 0.3)
	e.fire.position = Vector3(0, 0.9, c.sp.len * 0.3)
	e.shadow = fx.contact_shadow(c.sp.len, c.sp.wid)
	world.add_child(e.shadow)
	if role == "player":
		e.wind = fx.make_wind()
		world.add_child(e.wind)
	em[c] = e
	return c


func _place(c: Car, s: float, lat: float, speed: float) -> void:
	var a := track.at(s, lat)
	var b: Basis = a.basis
	if c.oncoming:
		b = b.rotated(a.up, PI)
	c.place(Transform3D(b, (a.pos as Vector3) + (a.up as Vector3) * 0.25), speed)
	var pr := track.project(a.pos)
	c.ti = pr.i
	c.s_track = pr.s
	c.lat = pr.lat
	c.lane = lat
	c.lane_t = lat
	c.lane_cur = lat


func _spawn_cars() -> void:
	var L := track.length
	var lw := track.W * 0.22
	var grid := [[-9.0, -lw], [-9.0, lw], [-18.0, -lw], [-18.0, lw], [-27.0, 0.0]]
	var fronts := ["mg", "rocket"]
	var rears := ["mine", "oil"]
	var nitros := ["short", "long"]
	for i in RIVALS.size():
		var r: Dictionary = RIVALS[i]
		var c := _make_car(r.kind, "rival", Color(r.color))
		c.display_name = r.name
		c.seed_f = i * 2.1 + 0.5
		c.cruise = 36.0 + i * 0.5 + track_idx * 0.25
		c.ai_skill = randf_range(0.95, 1.03)
		c.next_bash = 6.0 + i * 3.0
		c.configure(lib, fronts[(i + track_idx) % 2], rears[(i / 2 + track_idx) % 2], nitros[i % 2], {})
		_place(c, L + grid[i][0], grid[i][1], 0)
		rivals.append(c)
	player = _make_car(save.car, "player", Color("#e8352b"))
	player.display_name = "VOCÊ"
	player.configure(lib, save.front, save.rear, save.nitro, save.up)
	player.turn_mult = 1.15
	_place(player, L + grid[4][0], grid[4][1], 0)
	var tc: int = track.data.traffic
	for i in tc:
		var t: Array = TRAFFIC[i % TRAFFIC.size()]
		var cols: Array = t[1]
		var c := _make_car(t[0], "traffic", Color(cols[randi() % cols.size()]))
		c.oncoming = i % 5 == 1 or i % 5 == 3
		c.cruise = randf_range(15, 20) if c.oncoming else randf_range(13, 19)
		var s := 60.0 + (float(i) / tc) * (L - 100.0) + randf_range(-8, 8)
		var lanes: Array = track.lanes_onc if c.oncoming else track.lanes_fwd
		_place(c, s, lanes[randi() % 2], c.cruise)
		traffic.append(c)
	for c in cars:
		var pr := track.project(c.global_position)
		c.dist = pr.s - L if pr.s > L * 0.5 else pr.s
		c.prev_s = pr.s
		c.lap = 0
	for c in [player] + rivals:
		c.freeze = true


# ------------------------------------------------------------------ fluxo
func choose_track(i: int) -> void:
	load_track(i)
	hud.show_screen("garage")


func next_track() -> void:
	load_track((track_idx + 1) % TrackData.TRACKS.size())
	hud.show_screen("garage")


func start_race() -> void:
	load_track(track_idx)
	stats = {"kills": 0, "takedowns": 0, "near": 0, "best_drift": 0.0, "air": 0.0, "falls": 0, "deaths": 0, "score": 0, "oncoming": 0.0, "prize": 0}
	race_t = 0.0
	lap_start = 0.0
	best_lap = INF
	ts = 1.0
	ts_target = 1.0
	slow_t = 0.0
	hitstop = 0.0
	crash_t = -1.0
	cam_focus = null
	place = 5
	hud.show_screen("race")
	hud.touch.release_all()
	hud.touch.labels["drop"] = "MINA" if player.rear_type == "mine" else "ÓLEO"
	hud.touch.labels["fire"] = "TIRO" if player.front_type == "mg" else "FOGUETE"
	mode = "countdown"
	countdown = 3.0
	last_beep = 4
	hud.big(String(track.data.name).to_upper(), Color("#ffcf33"), Color("#c74200"))


func to_menu() -> void:
	load_track(track_idx)
	hud.show_screen("menu")


func pause(on: bool) -> void:
	if on and mode in ["race", "countdown"]:
		prev_mode = mode
		mode = "paused"
		hud.show_screen("pause")
		Engine.time_scale = 0.0
	elif not on and mode == "paused":
		mode = prev_mode
		hud.show_screen("race")


func toggle_steer() -> void:
	save.steer = "carro" if String(save.get("steer", "tela")) == "tela" else "tela"
	_write_save()
	hud.refresh_steer()
	hud.popup("DIREÇÃO: " + ("APONTA NA TELA" if save.steer == "tela" else "GIRA O CARRO"), Color("#2ee6ff"))


func toggle_mute() -> void:
	sfx.set_muted(not sfx.muted)


# ------------------------------------------------------------------ eventos
func _on_hit(c: Car, other: Object, point: Vector3, dv: float) -> void:
	var oc: Car = other as Car
	if oc:
		c.last_hit_by = oc
		c.last_hit_t = time_g
	if mode != "race":
		return
	c.take_impact(point, dv)
	var vis := _on_screen(point)
	var out := (point - c.global_position).normalized()
	if vis and dv > 4.0:
		var back := -c.linear_velocity.normalized() * 0.6
		fx.sparks(point + Vector3.UP * 0.3, out + back, clampf(dv / 14.0, 0.3, 2.0))
		if dv > 10.0:
			fx.hit_light(point + Vector3.UP, Color(1.0, 0.7, 0.3), clampf(dv * 0.35, 3.0, 9.0), 9.0, 0.25)
	if c == player and dv > 5.0:
		_shake(minf(0.5, dv * 0.022))
		sfx.play("bump", linear_to_db(clampf(dv / 20.0, 0.2, 1.0)))
		if dv > 10.0:
			sfx.play("metal", -6.0)
			hitstop = maxf(hitstop, 0.04)
			_flash(Color(1, 1, 1), 0.1)
		if dv > 16.0:
			c.stun = 0.2
	# trânsito atropelado com força pelo jogador vira sucata
	if c.role == "traffic" and oc == player and dv > 14.0 and not c.wrecked:
		c.apply_damage(500.0, point, player, false)


func _on_died(c: Car, killer: Car) -> void:
	var big := c.role != "traffic"
	var from: Vector3 = killer.global_position if killer else c.global_position - c.global_transform.basis.z
	var fell: bool = c.get_meta("fell", false)
	c.set_meta("fell", false)
	c.wreck(28.0, (c.global_position - from).normalized(), not fell)
	if _on_screen(c.global_position):
		fx.explosion(c.global_position, big)
		sfx.play("crash", 0.0 if big else -5.0)
		_shake(0.6 if big else 0.25)
	if c == player:
		stats.deaths += 1
		hud.big("CAIU!" if fell else "DESTRUÍDO!", Color("#ffe14d"), Color("#ff5a1a"))
		hud.killfeed("%s destruiu VOCÊ" % (killer.display_name if killer else "A PISTA"), Color("#ff7a7a"))
		_flash(Color(1, 1, 1), 0.6)
		hitstop = 0.1
		_slowmo(0.3, 1.4)
		crash_t = 0.0
		zoom_kick -= 8.0
		Input.vibrate_handheld(150)
		return
	if killer == player and mode == "race":
		var ram := player.linear_velocity.length() > 15.0 and c.global_position.distance_to(player.global_position) < 6.0
		stats.kills += 1
		if c.role == "traffic":
			stats.score += 150
			hud.popup("TRÂNSITO!", Color("#ff7a1a"), "+150")
			_add_meter(0.2)
		else:
			if ram:
				stats.takedowns += 1
			hud.big("TAKEDOWN!" if ram else "DESTRUIU!", Color.WHITE, Color("#ff2d55"))
			hud.popup(c.display_name, Color("#ff2d55"), "+$%d" % KILL_BONUS)
			hud.killfeed("VOCÊ destruiu %s" % c.display_name, Color("#7dff6a"))
			stats.score += 1000
			sfx.play("fanfare", -6.0)
			_flash(Color(1, 0.9, 0.6), 0.3)
			hitstop = 0.07
			if randf() < 0.6:
				_slowmo(0.35, 0.7)
				cam_focus = c
				focus_t = 0.8
			_add_meter(0.5)
			Input.vibrate_handheld(80)
	elif c.role != "traffic" and mode == "race":
		hud.killfeed("%s destruiu %s" % [killer.display_name if killer else "A PISTA", c.display_name], Color(1, 1, 1, 0.85))


func on_player_hit_enemy(_c: Car, _killed: bool) -> void:
	pass


func on_player_got_hit(amount: float) -> void:
	_shake(minf(0.3, amount * 0.02))
	_flash(Color(1, 0.2, 0.15), minf(0.25, amount * 0.012))


func _on_part_off(c: Car, mesh: MeshInstance3D, xform: Transform3D, vel: Vector3, is_wheel: bool) -> void:
	mesh.material_overlay = null
	var rb := fx.spawn_debris(mesh, xform, vel, is_wheel)
	if not _on_screen(xform.origin):
		return
	fx.sparks(xform.origin, vel, 0.6)
	if String(mesh.name).ends_with("cabin"):
		fx.burst("glass", xform.origin + Vector3.UP)
		sfx.play("glass", -3.0)
	else:
		sfx.play("metal", -8.0, randf_range(0.8, 1.3))
	if c == player and rb:
		pass


func _on_landed(c: Car, air: float, impact: float) -> void:
	c.juice_squash(clampf(impact * 0.12, 0.4, 2.2))
	c.juice_pitch(-clampf(impact * 0.03, 0.1, 0.5))
	if not _on_screen(c.global_position):
		return
	fx.burst("dust", c.global_position + c.global_transform.basis.y * 0.2)
	if c != player:
		return
	_shake(minf(0.45, impact * 0.03))
	sfx.play("land", linear_to_db(clampf(impact / 15.0, 0.3, 1.0)))
	hitstop = maxf(hitstop, 0.035)
	if air > 0.6 and mode == "race":
		var pts := int(air * 150)
		hud.popup("PULÃO %.1fs" % air, Color("#7dff6a"), "+%d" % pts)
		stats.score += pts
		stats.air = maxf(stats.air, air)
		_add_meter(0.25)


## manobras enchem o medidor; cheio = uma carga extra de nitro
func _add_meter(a: float) -> void:
	player.nitro_meter += a
	if player.nitro_meter >= 1.0:
		player.nitro_meter -= 1.0
		if player.nitro_ch < player.nitro_cap + 1:
			player.nitro_ch += 1
			hud.popup("+1 NITRO", Color("#2ee6ff"))
			sfx.play("coin", -6.0)


func _shake(a: float) -> void:
	trauma = minf(1.0, trauma + a)


func _flash(c: Color, a: float) -> void:
	flash = Color(c.r, c.g, c.b, maxf(flash.a, a))


func _slowmo(target: float, dur: float) -> void:
	ts_target = target
	slow_t = dur
	ts = minf(ts, target + 0.15)


func _on_screen(p: Vector3) -> bool:
	return Vector2(p.x - cam_pos.x, p.z - cam_pos.z).length() < view_h * 1.4


# ------------------------------------------------------------------ física e regras
func _physics_process(dt: float) -> void:
	if mode == "paused":
		return
	time_g += dt
	for c in cars:
		c.game_time = time_g
		if c.role != "player" and not c.wrecked:
			c.ai(track, self, dt)
	if mode == "race" and not player.wrecked:
		_player_input()
	elif not player.wrecked:
		player.ctrl.fire = false
		player.ctrl.drop = false
		player.ctrl.nitro = false
		player.ctrl.drift = false
		player.ctrl.brake = 0.0
		player.ctrl.dir = null
		player.ctrl.steer = 0.0
		player.ctrl.throttle = 0.0
		if mode == "finish":
			player.ai(track, self, dt)
			player.ctrl.nitro = false
	if mode in ["race", "finish"]:
		weapons.update(dt)
	for c in cars:
		if c.wrecked or not c.on_ground or time_g < c.pad_t:
			continue
		var pad = track.pad_at(c.s_track, c.lat)
		if pad != null and absf(c.h_track) < 2.0:
			c.pad_t = time_g + 0.8
			var f: Vector3 = c.global_transform.basis.z
			var want: float = float(pad.spd) if float(pad.spd) > 0.0 else c.sp.nitro * 0.95
			var v: float = maxf(c.linear_velocity.length(), want)
			c.linear_velocity = f.slide(c.ground_n).normalized() * v
			pad.hit = 1.0
			c.juice_squash(-1.2)
			c.juice_pitch(0.6)
			if _on_screen(c.global_position):
				var acc: Color = pad.accent
				fx.hit_light(c.global_position + c.ground_n * 0.8, acc, 3.5, 8.0, 0.25)
				for sgn: float in [-1.0, 1.0]:
					fx.sparks(c.global_transform * Vector3(sgn * c.sp.wid * 0.45, 0.15, -c.sp.len * 0.45), -f + c.ground_n * 0.35, 0.9)
				fx.nitro_burst(c.global_transform * c.exhaust_local, f)
			if c == player:
				sfx.play("nitro", -2.0)
				hud.popup("TURBO!", Color("#ff9a1a"))
				zoom_kick += 5.0
				cam_kick -= f * 2.2
				_shake(0.22)
				_flash((pad.accent as Color).lerp(Color.WHITE, 0.4), 0.16)
				_add_meter(0.15)
	_pickups(dt)
	_feature_stats(dt)
	_rules(dt)
	_respawns(dt)
	_recycle()


## Direção "tela": o jogador aponta para onde quer ir na tela (não inverte quando o carro desce a tela).
## Direção "carro": esquerda/direita giram o carro (estilo clássico).
## medição de fluidez: quantas vezes um carro "engasga" (cai abaixo de 8 m/s) dentro de loop/torção/espiral
func _feature_stats(_dt: float) -> void:
	if mode != "race":
		return
	for c in cars:
		if c.role == "traffic" or c.wrecked or c.freeze:
			continue
		var on_f: bool = track.feat[c.ti] == 1
		var slow: bool = c.linear_velocity.length() < 8.0
		var was: bool = c.get_meta("stall", false)
		if on_f and slow and not was:
			var key := "stalls" if c == player else "ai_stalls"
			stats[key] = int(stats.get(key, 0)) + 1
			var k2 := "st_" + track.ftype[c.ti] + ("_l" if track.loopf[c.ti] == 1 else "")
			stats[k2] = int(stats.get(k2, 0)) + 1
			if (c == player or OS.get_cmdline_user_args().has("--debugstall_ai")) and OS.get_cmdline_user_args().has("--debugstall"):
				print("STALL %s s=%d lat=%.1f h=%.1f v=%.1f onf=%s inloop=%s ft=%s gnd=%s wheels=%d up·U=%.2f inv=%.1f" % [k2, int(c.s_track), c.lat, c.h_surf, c.linear_velocity.length(), c.on_feature, c.in_loop, c.feat_type, c.on_ground, c.wheels.filter(func(w): return w.contact).size(), c.global_transform.basis.y.dot(track.U[c.ti]), c.invuln])
				for ct in c._contacts:
					var ob: Object = ct[0]
					var nm := "?"
					if ob is Node:
						nm = (ob as Node).name + ":" + (ob as Node).get_class()
					print("   contact ", nm, " lp=", ct[1], " n=", ct[2])
				for o in cars:
					if o != c and o.global_position.distance_to(c.global_position) < 6.0:
						print("   near car ", o.role, " d=%.1f" % o.global_position.distance_to(c.global_position))
		c.set_meta("stall", on_f and slow)


func _player_input() -> void:
	var c := player.ctrl
	var screen_mode := String(save.get("steer", "tela")) == "tela"
	# controles presos ao ângulo base da câmera: a câmera dinâmica (loops/torções) não inverte a direção
	var rr := Vector3(cos(CAM_YAW), 0, -sin(CAM_YAW))
	var ff := Vector3(-sin(CAM_YAW), 0, -cos(CAM_YAW))
	c.dir = null
	c.steer = 0.0
	c.throttle = 0.0
	c.brake = Input.get_action_strength("brake")
	if screen_mode:
		var kx := Input.get_action_strength("right") - Input.get_action_strength("left")
		var ky := Input.get_action_strength("up") - Input.get_action_strength("down")
		if absf(kx) + absf(ky) > 0.1:
			c.dir = (rr * kx + ff * ky).normalized()
			c.dir_mag = 1.0
			c.throttle = 1.0
	else:
		c.steer = Input.get_action_strength("left") - Input.get_action_strength("right")
		c.throttle = Input.get_action_strength("up")
		c.brake = maxf(c.brake, Input.get_action_strength("down"))
	if c.brake > 0.0:
		c.throttle = 0.0
	c.drift = Input.is_action_pressed("drift")
	c.nitro = Input.is_action_pressed("nitro")
	c.fire = Input.is_action_pressed("fire")
	c.drop = Input.is_action_pressed("drop")
	var tp := hud.touch
	if tp.used:
		if not tp.btn.brake and c.brake <= 0.0:
			c.throttle = 1.0
		if tp.btn.brake:
			c.brake = 1.0
			c.throttle = 0.0
		c.drift = c.drift or tp.btn.drift
		c.nitro = c.nitro or tp.btn.nitro
		c.fire = c.fire or tp.btn.fire
		c.drop = c.drop or tp.btn.drop
		if screen_mode and tp.stick_vec.length() > 0.22:
			c.dir = (rr * tp.stick_vec.x - ff * tp.stick_vec.y).normalized()
			c.dir_mag = minf(1.0, (tp.stick_vec.length() - 0.22) / 0.5)
		elif not screen_mode and absf(tp.stick_vec.x) > 0.15:
			c.steer = clampf(-tp.stick_vec.x * 1.4, -1.0, 1.0)
	if auto_test and not OS.get_cmdline_user_args().has("--steertest"):
		player.cruise = 38.0
		player.role = "rival"
		player.ai(track, self, 1.0 / 60.0)
		player.role = "player"
		if test_lane != 0.0:
			var a := track.at(player.s_track + 12.0, test_lane)
			c.dir = ((a.pos as Vector3) - player.global_position).normalized()
		c.nitro = player.nitro_ch > 0 and absf(track.curv[track.idx(player.ti + 10)]) < 0.008 and randf() < 0.02
		if OS.get_cmdline_user_args().has("--nitrotest"):
			player.nitro_ch = 3
			c.nitro = int(real * 2.0) % 2 == 0
		c.fire = weapons._target(player, 50.0, 0.97) != null
		c.drop = randf() < 0.01


func _pickups(dt: float) -> void:
	for pk in pickups:
		var nd: Node3D = pk.node
		if pk.t > 0.0:
			pk.t -= dt
			nd.visible = pk.t <= 0.0
			continue
		nd.rotate(pk.up, dt * 2.0)
		nd.position = (pk.base as Vector3) + (pk.up as Vector3) * sin(time_g * 3.0) * 0.25
		for c in cars:
			if c.role == "traffic" or c.wrecked:
				continue
			if c.global_position.distance_to(nd.global_position) < 2.8:
				pk.t = 10.0
				nd.visible = false
				match String(pk.kind):
					"ammo":
						c.ammo_f = mini(c.front_cap, c.ammo_f + maxi(1, c.front_cap / 2))
						c.ammo_r = mini(c.rear_cap, c.ammo_r + 1)
					"repair":
						c.health = minf(c.max_health, c.health + c.max_health * 0.4)
					"nitro":
						c.nitro_ch = mini(c.nitro_cap + 1, c.nitro_ch + 1)
				if c == player:
					sfx.play("pickup")
					var names := {"ammo": "MUNIÇÃO!", "repair": "REPARO!", "nitro": "NITRO!"}
					hud.popup(names[pk.kind], Color("#7dff6a"))
					fx.sparkle(nd.global_position, {"ammo": Color(0.7, 1.4, 0.5), "repair": Color(1.4, 0.6, 0.5), "nitro": Color(0.5, 1.0, 1.6)}[pk.kind])
				break


func _rules(dt: float) -> void:
	var L := track.length
	for c in cars:
		var pr := track.project(c.global_position, c.ti)
		c.ti = pr.i
		c.lat = pr.lat
		c.s_track = pr.s
		c.h_track = pr.h
		c.in_loop = track.loopf[pr.i] == 1
		c.feat_type = track.ftype[pr.i]
		c.on_feature = track.feat[pr.i] == 1 and track.gap[pr.i] == 0 and track.ftype[pr.i] != "jump"
		if c.on_feature:
			var fr := track.frame(c.global_position, pr.i)
			c.track_up = fr.u
			c.track_left = fr.l
			c.track_tan = fr.t
			c.h_surf = fr.h
			c.lat = fr.lat
		else:
			c.track_up = track.U[pr.i]
			c.track_left = track.L[pr.i]
			c.track_tan = track.T[pr.i]
			c.h_surf = pr.h
		c.road_half = track.HALF
		c.track_ref = track
		if c.role == "traffic":
			continue
		var d: float = pr.s - c.prev_s
		if d > L * 0.5:
			d -= L
		elif d < -L * 0.5:
			d += L
		c.dist += d
		c.prev_s = pr.s
		var lap := int(floor(c.dist / L))
		if lap > c.lap:
			c.lap = lap
			c.refill()
			if c == player and mode == "race":
				var lt := race_t - lap_start
				lap_start = race_t
				best_lap = minf(best_lap, lt)
				if lap >= LAPS:
					_finish()
				else:
					hud.big("ÚLTIMA VOLTA!" if lap == LAPS - 1 else "VOLTA %d" % (lap + 1), Color("#ffcf33"), Color("#c74200"))
					hud.popup("MUNIÇÃO E NITRO RECARREGADOS", Color("#2ee6ff"))
					sfx.play("fanfare", -6.0)
					fx.burst("confetti", player.global_position + Vector3.UP)
	if mode != "race":
		return
	race_t += dt
	var order := [player] + rivals
	order.sort_custom(func(a, b): return a.dist > b.dist)
	place = order.find(player) + 1
	for r in rivals:
		r.rubber = clampf(1.0 + (player.dist - r.dist) * 0.0028, 0.86, 1.1)
	if player.wrecked:
		return
	var p := player
	var v := p.linear_velocity
	# sentido errado: avisa e, se continuar, coloca o carro de volta na direção certa
	var along_t: float = p.global_transform.basis.z.dot(track.T[p.ti])
	if along_t < -0.35 and v.length() > 2.0 and not p.in_loop:
		wrong_t += dt
	else:
		wrong_t = maxf(0.0, wrong_t - dt * 2.0)
	hud.wrong_l.visible = wrong_t > 0.8
	if hud.wrong_l.visible:
		hud.wrong_l.modulate.a = 1.0 if int(real * 5.0) % 2 == 0 else 0.4
	if wrong_t > 3.5:
		wrong_t = 0.0
		hud.wrong_l.visible = false
		_respawn(p, false)
		hud.popup("DE VOLTA AO SENTIDO CERTO", Color("#2ee6ff"))
	if p.drifting and p.v_f > 12.0:
		p.nitro_meter += dt * 0.08 * minf(1.0, p.drift_slip * 2.0)
	if was_drift and not p.drifting and p.drift_t > 0.8:
		var pts := int(p.drift_t * 120)
		hud.popup("DRIFT %.1fs" % p.drift_t, Color("#c77dff"), "+%d" % pts)
		stats.score += pts
		stats.best_drift = maxf(stats.best_drift, p.drift_t)
		_add_meter(minf(0.3, p.drift_t * 0.08))
	was_drift = p.drifting
	if p.nitro_meter >= 1.0:
		_add_meter(0.0)
	if track.data.traffic > 0:
		var tg := track.T[p.ti]
		var along := v.dot(tg)
		if p.lat > 0.8 and along > 14.0 and p.on_ground:
			p.nitro_meter += dt * 0.08
			onc_dist += along * dt
			stats.oncoming += along * dt
			hud.onc_l.modulate.a = 1.0 if int(real * 6.0) % 2 == 0 else 0.6
		else:
			if onc_dist > 40.0:
				hud.popup("CONTRAMÃO %dm" % int(onc_dist), Color("#ff2d55"), "+%d" % int(onc_dist))
				stats.score += int(onc_dist)
			onc_dist = 0.0
			hud.onc_l.modulate.a = 0.0
		for c in traffic:
			if c.wrecked:
				c.nm_state = null
				continue
			var dd: float = c.global_position.distance_to(p.global_position)
			var rel: float = (c.linear_velocity - v).length()
			if dd < 4.6 and rel > 12.0 and c.nm_state == null:
				c.nm_state = {"touched": false}
			if c.nm_state != null:
				if c.last_hit_by == p and time_g - c.last_hit_t < 0.5:
					c.nm_state.touched = true
				if dd > 7.5:
					if not c.nm_state.touched:
						_near_miss(c)
					c.nm_state = null


func _near_miss(c: Car) -> void:
	stats.near += 1
	nm_combo = nm_combo + 1 if real - last_nm < 2.5 else 1
	last_nm = real
	var pts := 50 * nm_combo
	stats.score += pts
	_add_meter(0.18)
	hud.popup("POR UM TRIZ!" if c.oncoming else "QUASE!", Color("#2ee6ff"), ("x%d +%d" % [nm_combo, pts]) if nm_combo > 1 else "+%d" % pts)
	sfx.play("whoosh", -3.0)
	zoom_kick += 1.5


## caiu da pista, ficou de cabeça para baixo ou foi destruído: volta para a pista
func _respawns(dt: float) -> void:
	if steer_testing:
		return
	for c in cars:
		if c.role == "traffic":
			continue
		if c.wrecked:
			if c != player and c.wreck_t > 3.0:
				_respawn(c, false)
			continue
		if c.freeze:
			continue
		var below: bool = c.h_track < -4.0
		var away: bool = absf(c.lat) > track.WALL + 3.0
		# caiu para fora da pista: explode ao bater no chão/água (ou depois de cair um tempo, no céu)
		var falling: bool = below or (away and c.h_track < -1.5 and c.linear_velocity.y < -2.0)
		var water_now: bool = c.global_position.y < float(theme.gy) + 0.6 and track.P[c.ti].y > float(theme.gy) + 2.5
		if falling or water_now:
			c.fall_t = float(c.get("fall_t")) + dt
			var hit_ground: bool = c.global_position.y < float(theme.gy) + 1.4
			if water_now or hit_ground or c.fall_t > 1.3:
				c.fall_t = 0.0
				_fall_wreck(c, water_now)
				continue
		else:
			c.fall_t = 0.0
		var upside: bool = c.global_transform.basis.y.dot(track.U[c.ti]) < -0.2 and c.linear_velocity.length() < 5.0
		var in_water: bool = c.global_position.y < float(theme.gy) + 0.6 and track.P[c.ti].y > float(theme.gy) + 2.5
		if below or away or upside or in_water:
			c.off_t += dt
		else:
			c.off_t = 0.0
		# preso (encostado na mureta, de lado, travado): volta para a pista
		if mode == "race" and c.linear_velocity.length() < 2.5:
			c.stuck_t += dt
		else:
			c.stuck_t = 0.0
		if c.stuck_t > 3.0:
			c.stuck_t = 0.0
			if c == player:
				hud.popup("VOLTANDO À PISTA", Color("#2ee6ff"))
			_respawn(c, false)
			continue
		if c.off_t > (0.15 if in_water else (0.6 if (below or away) else 1.5)):
			if auto_test and OS.get_cmdline_user_args().has("--debugfall"):
				print("FALL %s s=%d lat=%.1f h=%.1f v=%.1f below=%s away=%s up=%s water=%s feat=%d gap=%d loop=%d" % [c.display_name, int(c.s_track), c.lat, c.h_track, c.linear_velocity.length(), below, away, upside, in_water, track.feat[c.ti], track.gap[c.ti], track.loopf[c.ti]])
			if in_water and _on_screen(c.global_position):
				if theme.ground == 4:
					fx.explosion(c.global_position, false, "smoke")
				else:
					fx.burst("smoke", c.global_position)
					sfx.play("splash", -3.0)
			_respawn(c, true)
	if crash_t >= 0.0:
		crash_t += dt / maxf(Engine.time_scale, 0.05)
		if crash_t > 2.2:
			crash_t = -1.0
			_respawn(player, false)


## faróis acesos à noite: uma luz spot (ilumina a pista) + dois fachos aditivos
func _add_headlights(c: Car) -> Array:
	var out := []
	var y: float = c.sp.clr + c.sp.h * 0.6
	var z: float = c.sp.len * 0.5 + 0.15
	var sp := SpotLight3D.new()
	sp.light_color = Color(1.0, 0.92, 0.78)
	sp.light_energy = 5.0 if c.role == "player" else 3.2
	sp.spot_range = 26.0
	sp.spot_angle = 36.0
	sp.spot_attenuation = 0.7
	sp.shadow_enabled = false
	sp.light_specular = 0.5
	sp.transform = Transform3D(Basis.looking_at(Vector3(0, -0.2, 1.0), Vector3.UP), Vector3(0, y + 0.2, z))
	c.add_child(sp)
	out.append(sp)
	var bsh := load("res://shaders/beam.gdshader") as Shader
	for sx: float in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.18
		cm.bottom_radius = 2.4
		cm.height = 11.0
		cm.radial_segments = 14
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		mi.mesh = cm
		var m := ShaderMaterial.new()
		m.shader = bsh
		m.set_shader_parameter("strength", 0.16 if c.role == "player" else 0.1)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# cilindro "deitado": eixo apontando para a frente e um pouco para baixo
		var dirv := Vector3(0, -0.12, 1.0).normalized()
		# eixo Y do cilindro aponta para trás (topo estreito no farol, base larga lá na frente)
		var yb := -dirv
		var zb := Vector3.RIGHT.cross(yb).normalized()
		var xb := yb.cross(zb).normalized()
		mi.transform = Transform3D(Basis(xb, yb, zb), Vector3(sx * c.sp.wid * 0.32, y, z) + dirv * 5.5)
		c.add_child(mi)
		out.append(mi)
	return out


## lens flare: fontes de luz rápidas (explosões, turbo, nitro) registradas pelos efeitos
var flares_t: Array = []


func add_flare(pos: Vector3, col: Color, k: float, dur: float) -> void:
	flares_t.append({"pos": pos, "col": col, "k": k, "t": 0.0, "dur": dur})
	if flares_t.size() > 16:
		flares_t.pop_front()


func _update_flares(rdt: float) -> void:
	var m := hud.post_mat
	var vs := get_viewport().get_visible_rect().size
	var cand: Array = []
	var cam_f := -cam.global_basis.z
	var night := bool(theme.night) or bool(theme.get("dusk", false))
	for c in cars:
		if c.wrecked or not _on_screen(c.global_position):
			continue
		var f: Vector3 = c.global_transform.basis.z
		if night:
			# faróis virados para a câmera brilham na lente
			var facing := clampf(-f.dot(cam_f) * 1.6 + 0.25, 0.0, 1.0)
			if facing > 0.05:
				for sx: float in [-1.0, 1.0]:
					var hp: Vector3 = c.global_transform * Vector3(sx * c.sp.wid * 0.32, c.sp.clr + c.sp.h * 0.6, c.sp.len * 0.5 + 0.1)
					cand.append([hp, Color(1.0, 0.9, 0.75), facing * (0.9 if c == player else 0.6), 1.0])
		if c.nitroing:
			cand.append([c.global_transform * c.exhaust_local, Color(0.45, 0.75, 1.0), 0.7, 1.2])
	for i in range(flares_t.size() - 1, -1, -1):
		var ft: Dictionary = flares_t[i]
		ft.t += rdt
		if ft.t > ft.dur:
			flares_t.remove_at(i)
			continue
		cand.append([ft.pos, ft.col, float(ft.k) * (1.0 - float(ft.t) / float(ft.dur)), 1.6])
	cand.sort_custom(func(a, b): return a[2] > b[2])
	var pos_a: Array = []
	var col_a: Array = []
	for cd in cand:
		if pos_a.size() >= 12:
			break
		var wp: Vector3 = cd[0]
		if cam.is_position_behind(wp):
			continue
		var sp: Vector2 = cam.unproject_position(wp) / vs
		if sp.x < -0.1 or sp.x > 1.1 or sp.y < -0.1 or sp.y > 1.1:
			continue
		pos_a.append(Vector4(sp.x, sp.y, float(cd[2]), float(cd[3])))
		col_a.append(Vector4((cd[1] as Color).r, (cd[1] as Color).g, (cd[1] as Color).b, 1.0))
	while pos_a.size() < 12:
		pos_a.append(Vector4.ZERO)
		col_a.append(Vector4.ZERO)
	var nfl := 0
	for p4 in pos_a:
		if (p4 as Vector4).z > 0.0:
			nfl += 1
	m.set_shader_parameter("fl_pos", pos_a)
	m.set_shader_parameter("fl_col", col_a)
	m.set_shader_parameter("fl_n", nfl)
	# sol (dia): brilho entrando pela borda do lado do sol
	if not night and mode != "menu":
		var sd: Vector3 = sun.global_basis.z
		var cf := Vector2(cam_f.x, cam_f.z).normalized()
		var sh := Vector2(sd.x, sd.z).normalized()
		var toward := cf.dot(sh)   # sol na frente da câmera = mais brilho
		var r := cam.global_basis.x
		var sx: float = Vector2(r.x, r.z).normalized().dot(sh)
		var su := Vector2(0.5 + sx * 0.62, -0.08 - maxf(0.0, toward) * 0.05)
		m.set_shader_parameter("sun_uv", su)
		m.set_shader_parameter("sun_k", clampf(0.35 + toward * 0.65, 0.0, 1.0) * 0.9)
		m.set_shader_parameter("sun_col", Color(theme.sun))
	else:
		m.set_shader_parameter("sun_k", 0.0)


## silhueta "raio-X": o carro aparece mesmo embaixo de outro trecho de pista
func _add_xray(c: Car) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/xray.gdshader")
	var me: bool = c.role == "player"
	var col: Color = c.color if not me else Color("#ffd23a")
	m.set_shader_parameter("col", col.lightened(0.25))
	m.set_shader_parameter("strength", 1.0 if me else 0.6)
	var stack: Array = [c.model]
	while stack.size() > 0:
		var nd: Node = stack.pop_back()
		if nd is MeshInstance3D:
			(nd as MeshInstance3D).material_overlay = m
		for ch in nd.get_children():
			stack.append(ch)


func _fall_wreck(c: Car, water: bool) -> void:
	if auto_test and OS.get_cmdline_user_args().has("--debugfall"):
		print("FALL %s s=%d lat=%.1f h=%.1f v=%.1f water=%s feat=%d gap=%d loop=%d" % [c.display_name, int(c.s_track), c.lat, c.h_track, c.linear_velocity.length(), water, track.feat[c.ti], track.gap[c.ti], track.loopf[c.ti]])
	if c == player:
		stats.falls += 1
	elif mode == "race":
		stats["ai_falls"] = int(stats.get("ai_falls", 0)) + 1
	var pos := c.global_position
	if _on_screen(pos):
		if water and int(theme.ground) == 4:
			fx.explosion(pos, true, "fireball")
		elif water:
			fx.burst("smoke", pos)
			fx.burst("smoke", pos + Vector3.UP)
			sfx.play("splash", 0.0)
		else:
			fx.scorch(pos, 3.0)
	# quem derrubou leva o crédito (batida/tiro recente)
	var killer: Car = c.last_hit_by if c.last_hit_by and c.game_time - c.last_hit_t < 4.0 else null
	c.set_meta("fell", true)
	c.invuln = 0.0
	c.apply_damage(c.health + 9999.0, pos, killer, false)


func _respawn(c: Car, fell: bool) -> void:
	var s := track.safe_s(c.s_track - 6.0)
	var old_dist := c.dist
	if c.wrecked:
		c.repair()
	var lat: float = [0.0, -track.W * 0.25, track.W * 0.25][randi() % 3] if track.data.traffic == 0 else track.lanes_fwd[0]
	_place(c, s, lat, 18.0)
	c.dist = old_dist
	c.prev_s = track.project(c.global_position).s
	c.invuln = 2.0
	if c == player:
		zoom_kick += 4.0
		fx.sparkle(c.global_position + Vector3.UP, Color(1.2, 1.2, 1.3))
		if fell:
			stats.falls += 1
			hud.popup("CAIU! VOLTANDO", Color("#ffcf33"))
	elif fell:
		stats.ai_falls = int(stats.get("ai_falls", 0)) + 1


func _recycle() -> void:
	var p := player
	var L := track.length
	for c in traffic:
		var rel: float = wrapf(c.s_track - p.s_track, -L * 0.5, L * 0.5)
		var far := rel < -70.0 or rel > 260.0
		var vis := _on_screen(c.global_position)
		if ((c.wrecked and c.wreck_t > 4.0) or far or c.h_track < -4.0) and not vis:
			for tries in 6:
				var s: float = track.safe_s(p.s_track + randf_range(110, 250))
				var lanes: Array = track.lanes_onc if c.oncoming else track.lanes_fwd
				var lat: float = lanes[randi() % 2]
				var pos: Vector3 = track.at(s, lat).pos
				var ok := true
				for o in cars:
					if o != c and o.global_position.distance_to(pos) < 8.0:
						ok = false
						break
				if ok:
					c.repair()
					_place(c, s, lat, c.cruise)
					break
			c.nm_state = null


func _finish() -> void:
	mode = "finish"
	var prize: int = PRIZE[place - 1] + int(stats.kills) * KILL_BONUS
	stats.prize = prize
	save.cash = int(save.cash) + prize
	var key := str(track_idx)
	var best: Dictionary = save.best.get(key, {})
	if not best.has("place") or place < int(best.place) or (place == int(best.place) and race_t < float(best.time)):
		save.best[key] = {"place": place, "time": race_t}
	_write_save()
	hud.big("VITÓRIA!" if place == 1 else "%dº LUGAR" % place, Color("#ffcf33"), Color("#c74200"))
	sfx.play("fanfare")
	fx.burst("confetti", player.global_position + Vector3.UP)
	_slowmo(0.35, 1.2)
	get_tree().create_timer(2.0, true, false, true).timeout.connect(_show_results)
	if auto_test:
		print("RESULT ", JSON.stringify({"track": track_idx, "place": place, "time": snappedf(race_t, 0.1), "stats": stats}))


func _show_results() -> void:
	if mode != "finish":
		return
	hud.res_title.text = "VITÓRIA!" if place == 1 else "%dº LUGAR" % place
	var lines := [
		"Tempo total   %s" % _fmt(race_t), "Melhor volta   %s" % _fmt(best_lap),
		"Destruídos   %d  (takedowns %d)" % [stats.kills, stats.takedowns], "Quedas   %d   ·   Destruições sofridas   %d" % [stats.falls, stats.deaths],
		"Maior drift   %.1fs   ·   Maior pulo   %.1fs" % [stats.best_drift, stats.air], "Pontos   %d" % stats.score]
	hud.res_list.text = "\n".join(lines)
	hud.res_cash.text = "+$%d   (total $%d)" % [int(stats.prize), int(save.cash)]
	hud.show_screen("results")
	if auto_test:
		get_tree().quit()


func _fmt(t: float) -> String:
	if t == INF:
		return "--:--.--"
	var m := int(t / 60.0)
	return "%d:%05.2f" % [m, t - m * 60.0]


# ------------------------------------------------------------------ quadro
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var rdt := minf(0.05, (now - _last_us) / 1e6)
	_last_us = now
	if auto_test:
		rdt = 1.0 / 60.0
	real += rdt
	if Input.is_action_just_pressed("pause"):
		pause(mode != "paused")
	if Input.is_action_just_pressed("mute"):
		toggle_mute()
	if Input.is_action_just_pressed("reset") and mode == "race" and not player.wrecked:
		_respawn(player, false)
	if mode == "paused":
		Engine.time_scale = 0.0
		return
	if slow_t > 0.0:
		slow_t -= rdt
		if slow_t <= 0.0:
			ts_target = 1.0
	ts = lerpf(ts, ts_target, minf(1.0, rdt * (12.0 if ts_target < ts else 3.0)))
	var eff := ts
	if hitstop > 0.0:
		hitstop -= rdt
		eff = 0.03
	Engine.time_scale = eff
	if focus_t > 0.0:
		focus_t -= rdt
		if focus_t <= 0.0:
			cam_focus = null
	if mode == "countdown":
		countdown -= rdt
		var n := int(ceil(countdown))
		if n < last_beep and n > 0:
			last_beep = n
			hud.big(str(n), Color.WHITE, Color("#2e7dff"))
			sfx.play("beep")
			_shake(0.1)
		if countdown <= 0.0:
			mode = "race"
			hud.big("VAI!", Color("#7dff6a"), Color("#1f8a2a"))
			sfx.play("go")
			_shake(0.3)
			zoom_kick += 4.0
			for c in [player] + rivals:
				c.freeze = false
				c.launch_t = 0.85   # pneus cantando na largada
			if Input.is_action_pressed("up") or hud.touch.used or auto_test:
				player.linear_velocity = player.global_transform.basis.z * 14.0
				hud.popup("LARGADA PERFEITA!", Color("#ff9a1a"))
	_car_fx(rdt * eff)
	if player.nitroing and not was_nitro:
		sfx.play("nitro")
		zoom_kick += 4.5
		cam_kick -= player.global_transform.basis.z * 2.6   # a câmera "fica para trás" e alcança o carro
		_shake(0.18)
		var ex: Vector3 = player.global_transform * player.exhaust_local
		fx.nitro_burst(ex, player.global_transform.basis.z)
		fx.hit_light(ex - player.global_transform.basis.z * 0.8, Color(1.0, 0.55, 0.2), 7.0, 8.0, 0.18)
		fx.burst("backfire", ex - player.global_transform.basis.z * 0.3, -player.global_transform.basis.z)
		_flash(Color(0.6, 0.9, 1.0), 0.12)
	if player.nitroing and not player.wrecked:
		trauma = maxf(trauma, 0.16)   # ronco: leve tremor contínuo durante o nitro
	was_nitro = player.nitroing
	var sp01: float = player.linear_velocity.length() / player.sp.vmax
	var slip: float = 1.0 if (player.drifting or player.launch_t > 0.15) else clampf((absf(player.v_s) - 3.0) / 8.0, 0.0, 1.0)
	if player.ctrl.brake > 0.0 and player.v_f > 10.0:
		slip += 0.5
	sfx.drive(clampf(sp01, 0.0, 1.3), player.ctrl.throttle, slip, player.nitroing, ts < 0.6, mode in ["race", "countdown", "finish"] and not player.wrecked)
	_camera(rdt)
	_post(rdt)
	_update_flares(rdt)
	_hud()
	# onda de luz das placas de turbo depois que alguém passa
	for pd in track.pads:
		if float(pd.get("hit", 0.0)) > 0.0 and pd.has("mat"):
			pd.hit = maxf(0.0, float(pd.hit) - rdt * 2.2)
			(pd.mat as ShaderMaterial).set_shader_parameter("hit", pd.hit)
	if auto_test and OS.get_cmdline_user_args().has("--camshots") and cam_mode != "":
		var key := "cam_" + cam_mode
		var fr := int(stats.get(key, 0)) + 1
		stats[key] = fr
		if fr % 40 == 0 and fr <= 160:
			get_viewport().get_texture().get_image().save_png("user://cam_t%d_%s_%d.png" % [track_idx, cam_mode, fr / 40])
			print("CAMSHOT ", cam_mode, " ", fr / 40)
	elif auto_test:
		stats.erase("cam_loop"); stats.erase("cam_twist"); stats.erase("cam_helix"); stats.erase("cam_air")
	if auto_test and test_shots.size() > 0 and real > float(test_shots[0]):
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://shot_t%d_%s.png" % [track_idx, test_shots[0]])
		print("SHOT ", track_idx)
		test_shots.pop_front()
	if auto_test and OS.get_cmdline_user_args().has("--debugair") and player.air_t > 2.0 and int(real * 60.0) % 30 == 0:
		var p2 := player
		print("AIR t=%.1f air=%.1f s=%d lat=%.1f h=%.1f v=%.1f gnd=%s feat=%d ft=%s gap=%d y=%.1f grounded_wheels=%d" % [real, p2.air_t, int(p2.s_track), p2.lat, p2.h_track, p2.linear_velocity.length(), p2.on_ground, track.feat[p2.ti], track.ftype[p2.ti], track.gap[p2.ti], p2.global_position.y, p2.wheels.filter(func(w): return w.contact).size()])
	if auto_test and OS.get_cmdline_user_args().has("--debugfall") and int(real * 60.0) % (20 if (player.s_track > 400 and player.s_track < 560) else 600) == 0:
		var p := player
		print("P t=%d s=%d lat=%.1f h=%.1f v=%.1f vf=%.1f gnd=%s road=%s up=%s n=%s feat=%d loop=%d thr=%.1f br=%.1f" % [int(real), int(p.s_track), p.lat, p.h_track, p.linear_velocity.length(), p.v_f, p.on_ground, p.on_road, str(p.global_transform.basis.y.snapped(Vector3.ONE * 0.01)), str(p.ground_n.snapped(Vector3.ONE * 0.01)), track.feat[p.ti], track.loopf[p.ti], p.ctrl.throttle, p.ctrl.brake])
	if auto_test and real > 240.0:
		print("TIMEOUT ", JSON.stringify({"track": track_idx, "lap": player.lap, "dist": player.dist, "stats": stats}))
		get_tree().quit()


func _scrapes() -> void:
	var list: Array = []
	for c in cars:
		if c.scraping and _on_screen(c.scrape_pt):
			list.append(c)
	list.sort_custom(func(a, b): return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	var player_scr := 0.0
	for i in scrape_pool.size():
		var n: Node3D = scrape_pool[i]
		if i < list.size():
			var c: Car = list[i]
			var v: Vector3 = c.scrape_v
			var spd := v.length()
			var dir := (-v.normalized() * 0.85 + c.scrape_n * 0.35 + Vector3.UP * 0.3).normalized()
			fx.set_scrape(n, true, c.scrape_pt + Vector3.UP * 0.25, dir, clampf(spd / 30.0, 0.2, 1.3))
			if c == player:
				player_scr = clampf(spd / 25.0, 0.3, 1.0)
		else:
			fx.set_scrape(n, false, Vector3.ZERO, Vector3.UP, 0.0)
	sfx.set_scrape(player_scr if mode in ["race", "finish"] else 0.0)
	if player_scr > 0.0:
		_shake(0.012 * player_scr)


func _car_fx(dt: float) -> void:
	_scrapes()
	for c in cars:
		var e: Dictionary = em[c]
		var vis: bool = _on_screen(c.global_position)
		var slip: float = absf(c.v_s)
		var braking: bool = c.ctrl.brake > 0.0 and c.v_f > 10.0
		var launching: bool = c.launch_t > 0.0 and c.on_ground
		var skidding: bool = vis and not c.wrecked and c.on_ground and (c.drifting or slip > 3.5 or braking or launching)
		var wi := 0
		for w in c.wheels:
			if w.lost:
				wi += 1
				continue
			var wp: Vector3 = c.global_transform * Vector3(w.base.x, 0.0, w.base.z)
			var oily: bool = c.oily_t > 0.0 and vis and c.on_ground and w.contact and not c.wrecked
			if (skidding and w.contact and (not w.front or braking)) or oily:
				var last = e.skid[wi]
				if last != null:
					var al: float = 0.5 if (c.drifting or launching) else 0.28
					if oily:
						al = maxf(al, 0.75 * clampf(c.oily_t / 1.2, 0.0, 1.0))
					fx.skid(last, wp, 0.44 if oily else 0.38, al, c.ground_n)
				e.skid[wi] = wp
			else:
				e.skid[wi] = null
			wi += 1
		if e.has("smoke"):
			var rear: Array = c.wheels.filter(func(w): return not w.front)
			for i in 2:
				var s: CPUParticles3D = e.smoke[i]
				var du: CPUParticles3D = e.dust[i]
				if i < rear.size() and not rear[i].lost:
					var wpos: Vector3 = c.global_transform * Vector3(rear[i].base.x, 0.2, rear[i].base.z)
					s.global_position = wpos
					du.global_position = wpos
				s.emitting = skidding and (c.drifting or slip > 5.0 or braking or launching)
				du.emitting = vis and not c.wrecked and c.on_ground and absf(c.lat) > track.HALF + 0.4 and c.linear_velocity.length() > 8.0
			var flame: Node3D = e.flame
			if c.nitroing and not e.get("was_n", false) and c != player and vis:
				fx.nitro_burst(c.global_transform * c.exhaust_local, c.global_transform.basis.z)
			e.was_n = c.nitroing
			e.heat_t = 0.5 if c.nitroing else maxf(0.0, float(e.get("heat_t", 0.0)) - dt)
			for fl: Node3D in [flame, e.flame2]:
				(fl.get_node("P") as CPUParticles3D).emitting = c.nitroing
				(fl.get_node("Haze") as CPUParticles3D).emitting = vis and (c.nitroing or float(e.heat_t) > 0.0)
				var core := fl.get_node("Core") as Node3D
				core.visible = c.nitroing
				if c.nitroing:
					var w := randf_range(0.9, 1.15)
					core.scale = Vector3(w, w, randf_range(0.8, 1.25))
			for i in 2:
				var tp: Vector3 = c.global_transform * c.tail_local[i]
				fx.trail_push(e.trails[i], tp, real, c.nitroing and vis)
		(e.dark as CPUParticles3D).emitting = vis and (c.health < c.max_health * 0.45 or c.wrecked)
		(e.fire as CPUParticles3D).emitting = vis and (c.health < c.max_health * 0.2 or (c.wrecked and c.wreck_t < 3.0))
		var sh: MeshInstance3D = e.shadow
		sh.visible = vis
		if vis:
			var a := track.at(c.s_track, c.lat)
			var gp: Vector3 = c.ground_pt if c.on_ground and not c.wrecked else a.pos
			var gn: Vector3 = c.ground_n if c.on_ground and not c.wrecked else a.up
			var hgt: float = maxf(0.0, (c.global_position - gp).dot(gn))
			var f: Vector3 = c.global_transform.basis.z.slide(gn).normalized()
			if f.length() < 0.5:
				f = a.tan
			sh.global_transform = Transform3D(Basis(gn.cross(f).normalized(), gn, f).scaled_local(Vector3(c.sp.wid * 1.45, 1, c.sp.len * 1.25)), gp + gn * 0.08)
			(sh.material_override as ShaderMaterial).set_shader_parameter("strength", clampf(1.0 - hgt * 0.25, 0.15, 1.0))
		if e.has("wind"):
			var w: CPUParticles3D = e.wind
			var sp: float = c.linear_velocity.length()
			w.emitting = (sp > 36.0 or c.nitroing) and not c.wrecked
			if w.emitting:
				var dir: Vector3 = c.linear_velocity.normalized()
				w.global_position = c.global_position + dir * 10.0 + Vector3.UP * 1.5
				w.direction = -dir
				w.initial_velocity_min = sp * 0.05
				w.initial_velocity_max = sp * 0.1
		if vis and not c.wrecked and c.linear_velocity.length() > 6.0:
			for w in c.wheels:
				if w.lost and randf() < dt * 30.0:
					fx.sparks(c.global_transform * Vector3(w.base.x, 0.1, w.base.z), -c.linear_velocity, 0.25)


func _cam_mode(rdt: float) -> String:
	if mode != "race" and mode != "finish" and mode != "countdown":
		return ""
	var p := player
	if p.wrecked:
		return ""
	var want := ""
	var steps := int(26.0 / track.ds)
	for k in range(-2, steps):
		var j := track.idx(p.ti + k)
		if track.loopf[j] == 1:
			want = "loop"
			cam_loop = track.loop_info(j)
			break
		if track.feat[j] == 1 and track.ftype[j] == "cork":
			want = "twist"
			break
		if track.feat[j] == 1 and track.ftype[j] == "helix" and k < 6:
			want = "helix"
			break
	if want == "" and not p.on_ground and p.air_t > 0.3:
		want = "air"
	if want != "":
		cam_mode = want
		cam_mode_t = 0.45
	else:
		cam_mode_t -= rdt
		if cam_mode_t <= 0.0:
			cam_mode = ""
	return cam_mode


func _camera(rdt: float) -> void:
	var p := player
	var v := p.linear_velocity
	var target := p.global_position + Vector3(v.x, 0, v.z) * 0.36
	var focus_h := 0.0
	if cam_focus and focus_t > 0.0:
		target = (cam_focus.global_position + p.global_position) * 0.5
		focus_h = -5.0
	if p.wrecked:
		target = p.global_position
	if mode == "menu":
		target = track.at(fmod(real * 18.0, track.length)).pos
	var cm := _cam_mode(rdt) if mode != "shots" else ""
	var want_yaw := CAM_YAW
	var want_pitch := CAM_PITCH
	var follow := 3.0 if p.wrecked else 4.5
	var extra := 0.0
	var size_fix := -1.0
	match cm:
		"loop":
			# vista lateral: olhando ao longo do eixo do loop, o círculo inteiro aparece na tela
			var lc: Vector3 = cam_loop.center
			var ax: Vector3 = cam_loop.axis
			var axh := Vector3(ax.x, 0, ax.z).normalized()
			var y1 := atan2(axh.x, axh.z)
			var y2 := atan2(-axh.x, -axh.z)
			want_yaw = y1 if absf(angle_difference(CAM_YAW, y1)) <= absf(angle_difference(CAM_YAW, y2)) else y2
			want_pitch = 0.2
			var along := (p.global_position - lc).dot(ax)
			var mid := lc + ax * along
			target = mid.lerp(p.global_position, 0.25)
			size_fix = float(cam_loop.r) * 2.0 + 18.0
			follow = 3.5
		"twist":
			# atrás do carro, um pouco alto: dá para ver a pista girando
			var t3: Vector3 = track.T[p.ti]
			var th := Vector3(t3.x, 0, t3.z).normalized()
			var yb := atan2(-th.x, -th.z)
			want_yaw = lerp_angle(CAM_YAW, yb, 0.75)
			want_pitch = 0.45
			target = p.global_position + th * 7.0 + Vector3.UP * 1.5
			size_fix = 26.0
			follow = 5.0
		"helix":
			want_pitch = 1.05
			extra = 14.0
		"air":
			want_pitch = 0.5
			extra = 6.0
	var bk := 1.0 - exp(-rdt * 3.2)
	cam_yaw = lerp_angle(cam_yaw, want_yaw, bk)
	cam_pitch = lerpf(cam_pitch, want_pitch, bk)
	if mode == "menu" or mode == "shots":
		cam_yaw = CAM_YAW
		cam_pitch = CAM_PITCH
	var k := 1.0 - exp(-rdt * follow)
	cam_kick *= exp(-rdt * 5.0)
	if mode != "shots":
		cam_pos = cam_pos.lerp(target + cam_kick, k)
	var vs := get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(1.0, vs.y)
	var base := maxf(28.0, 26.0 / aspect) if aspect < 1.0 else 28.0
	var sp := v.length()
	var want := base + clampf(sp / 55.0, 0.0, 1.0) * 8.0 + (4.0 if p.nitroing else 0.0) + focus_h + (-8.0 if p.wrecked else 0.0) + extra
	if size_fix > 0.0:
		want = maxf(size_fix, base) / clampf(aspect, 0.6, 1.0)
	if mode == "menu":
		want = 40.0
	if test_zoom > 0.0 and mode != "menu":
		want = test_zoom
	if mode == "shots":
		want = view_h
		zoom_kick = 0.0
	zoom_kick *= exp(-rdt * 4.0)
	view_h = lerpf(view_h, want + zoom_kick, 1.0 - exp(-rdt * 3.0))
	cam.size = maxf(8.0, view_h)
	var off := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * CAM_DIST
	cam.global_position = cam_pos + off
	cam.look_at(cam_pos, Vector3.UP)
	shake_t += rdt
	trauma = maxf(0.0, trauma - rdt * 1.6)
	var s := trauma * trauma
	cam.h_offset = (sin(shake_t * 37.0) * 0.6 + sin(shake_t * 85.0 + 1.0) * 0.4) * s * 1.5
	cam.v_offset = (sin(shake_t * 41.0 + 4.0) * 0.6 + sin(shake_t * 94.0 + 2.0) * 0.4) * s * 1.1
	cam.rotate_object_local(Vector3.FORWARD, sin(shake_t * 29.0 + 9.0) * s * 0.04)


func _post(rdt: float) -> void:
	var p := player
	var sp := p.linear_velocity.length()
	var slow := ts < 0.6
	var bt := (0.6 if p.nitroing else 0.0) + clampf((sp - 38.0) / 30.0, 0.0, 0.2) + (0.4 if slow else 0.0)
	post_blur = lerpf(post_blur, bt, minf(1.0, rdt * 6.0))
	oil_fx = maxf(0.0, oil_fx - rdt * 1.2)
	post_aberr = lerpf(post_aberr, (0.8 if p.nitroing else 0.0) + trauma * 1.5 + (0.8 if slow else 0.0) + oil_fx * 2.2, minf(1.0, rdt * 8.0))
	post_lines = lerpf(post_lines, (1.0 if p.nitroing else 0.0) + clampf((sp - 42.0) / 15.0, 0.0, 0.6), minf(1.0, rdt * 6.0))
	flash.a *= exp(-rdt * 7.0)
	var m := hud.post_mat
	m.set_shader_parameter("blur", post_blur)
	m.set_shader_parameter("aberr", post_aberr)
	m.set_shader_parameter("lines", post_lines)
	m.set_shader_parameter("flash", Vector4(flash.r, flash.g, flash.b, flash.a))
	m.set_shader_parameter("sat", 0.7 if slow else 1.0)
	m.set_shader_parameter("vig", 0.3 + (0.25 if p.nitroing else 0.0) + (0.3 if slow else 0.0))
	var vs := get_viewport().get_visible_rect().size
	m.set_shader_parameter("aspect", vs.x / maxf(1.0, vs.y))
	m.set_shader_parameter("center", cam.unproject_position(p.global_position + Vector3.UP * 0.6) / vs)


func _hud() -> void:
	var p := player
	hud.pos_l.text = "%dº" % place
	hud.lap_l.text = "VOLTA %d/%d" % [clampi(p.lap + 1, 1, LAPS), LAPS]
	hud.time_l.text = _fmt(race_t)
	hud.score_l.text = "$%d  ·  %d DESTRUÍDOS" % [int(save.cash), int(stats.get("kills", 0))]
	hud.speed_l.text = "%d km/h" % int(p.linear_velocity.length() * 3.6 * 1.25)
	var tc := hud.touch
	tc.counts["fire"] = str(p.ammo_f)
	tc.counts["drop"] = str(p.ammo_r)
	tc.counts["nitro"] = str(p.nitro_ch)
	tc.nitro_on = p.nitroing
