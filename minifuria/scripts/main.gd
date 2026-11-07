extends Node3D
## Mini Fúria: corrida isométrica de mini carros com destruição, takedowns e nitro.

const LAPS := 3
const CAM_YAW := PI / 4.0
const CAM_PITCH := 0.62
const CAM_DIST := 120.0

const RIVALS := [
	{"kind": "trovao", "color": "#2f6fd6", "name": "TROVÃO"},
	{"kind": "vespa", "color": "#ffb31a", "name": "VESPA"},
	{"kind": "trovao", "color": "#8a5cd6", "name": "CORISCO"},
]
const TRAFFIC := [
	["sedan", ["#5cc26b", "#f08a7a", "#7fc8d9", "#e6e1d6", "#9a7cf0"]],
	["taxi", ["#ffcf33"]],
	["policia", ["#f4f4f4"]],
	["picape", ["#8a5cd6", "#e2553b", "#3d8bd6"]],
	["van", ["#f08a7a", "#ffd23a", "#7fc8d9"]],
]

var lib: Node3D
var track: Track
var fx: Fx
var hud: Hud
var sfx: Sfx
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment

var cars: Array = []
var rivals: Array = []
var traffic: Array = []
var props: Array = []
var player: Car
var em := {}   # efeitos contínuos por carro
var scrape_pool: Array = []
var cam_mode := "iso"          # iso | chase (terceira pessoa)
var chase_pos := Vector3.ZERO
var chase_dir := Vector3.FORWARD
var chase_fov := 65.0
var orbit_a := 0.0

var mode := "loading"
var time_g := 0.0
var real := 0.0
var ts := 1.0
var ts_target := 1.0
var slow_t := 0.0
var hitstop := 0.0
var trauma := 0.0
var shake_t := 0.0
var zoom_kick := 0.0
var view_h := 32.0
var cam_pos := Vector3.ZERO
var cam_focus: Car = null
var focus_t := 0.0
var flash := Color(1, 1, 1, 0)
var race_t := 0.0
var countdown := 0.0
var last_beep := 4
var lap_start := 0.0
var best_lap := INF
var stats := {}
var crash_t := -1.0
var place := 4
var onc_dist := 0.0
var nm_combo := 0
var last_nm := -10.0
var was_drift := false
var was_nitro := false
var nitro_was_full := false
var _last_us := 0
var auto_test := false
var test_shots: Array = []
var test_lane := -2.75

var post_blur := 0.0
var post_aberr := 0.0
var post_lines := 0.0


func _ready() -> void:
	randomize()
	_setup_input()
	auto_test = "--autotest" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lane="):
			test_lane = float(a.substr(7))
		if a.begins_with("--shots="):
			test_shots = Array(a.substr(8).split(","))

	env = Environment.new()
	# céu procedural: luz ambiente e reflexos vindos do céu (acabamento parecido com o render do Blender)
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color("#6fa6f2")
	psm.sky_horizon_color = Color("#dde8f7")
	psm.ground_horizon_color = Color("#d9dde3")
	psm.ground_bottom_color = Color("#6b7f5a")
	psm.sun_angle_max = 20.0
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#bcd6f2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(5, 0.6)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.28
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color("#fff0d4")
	sun.light_energy = 1.7
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 75.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.6
	sun.shadow_opacity = 0.85
	add_child(sun)

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = view_h
	cam.near = 1.0
	cam.far = 400.0
	add_child(cam)
	cam.make_current()

	lib = (load("res://assets/minicars.glb") as PackedScene).instantiate()
	_prep_materials(lib, {})
	track = Track.new()
	track.add_ramp(96, -5.5)
	track.add_ramp(476, 5.5)
	track.add_pad(30, -2.75)
	track.add_pad(200, -5.5)
	track.add_pad(330, 5.5)
	track.add_pad(540, -5.5)
	add_child(track)
	track.build(_prop_scene("prop_ramp"))
	fx = Fx.new()
	add_child(fx)
	for i in 6:
		var sc := fx.make_scrape()
		fx.add_child(sc)
		scrape_pool.append(sc)
	sfx = Sfx.new()
	add_child(sfx)
	hud = Hud.new()
	add_child(hud)
	hud.track = track
	hud.play_pressed.connect(_start)
	hud.restart_pressed.connect(_start)
	hud.resume_pressed.connect(func(): _pause(false))
	hud.pause_pressed.connect(func(): _pause(mode != "paused"))
	hud.menu_pressed.connect(_to_menu)
	hud.mute_pressed.connect(func(): sfx.set_muted(not sfx.muted))
	hud.cam_pressed.connect(_toggle_cam)

	_build_scenery()
	_new_race()
	mode = "menu"
	_last_us = Time.get_ticks_usec()
	if auto_test:
		_start()
		if "--chase" in OS.get_cmdline_user_args():
			_toggle_cam()


func _setup_input() -> void:
	var keys := {
		"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D], "up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S],
		"drift": [KEY_SPACE], "nitro": [KEY_SHIFT, KEY_N, KEY_J], "reset": [KEY_R], "pause": [KEY_P, KEY_ESCAPE],
		"mute": [KEY_M], "start": [KEY_ENTER], "camera": [KEY_C],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)


## acabamento dos materiais vindos do Blender: AO assada nos vértices + ajustes de brilho por tipo
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
				"Headlight", "Taillight", "LampGlow", "Window":
					m.vertex_color_use_as_albedo = false
	for c in n.get_children():
		_prep_materials(c, done)


func _prop_scene(name_: String) -> PackedScene:
	var n := lib.get_node(name_).duplicate() as Node3D
	n.transform = Transform3D.IDENTITY
	_shadows(n)
	var ps := PackedScene.new()
	_own(n, n)
	ps.pack(n)
	return ps


func _own(n: Node, owner_: Node) -> void:
	for c in n.get_children():
		c.owner = owner_
		_own(c, owner_)


func _shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children():
		_shadows(c)


func _inst(name_: String) -> Node3D:
	var n := lib.get_node(name_).duplicate() as Node3D
	n.transform = Transform3D.IDENTITY
	_shadows(n)
	return n


# ------------------------------------------------------------------ cenário
func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var a0 := track.at(0)
	var gate := _inst("prop_gate")
	gate.position = a0.pos
	gate.rotation.y = a0.heading
	add_child(gate)
	for e in [[18.0, -(Track.WALL + 4)], [44.0, -(Track.WALL + 4)], [-20.0, Track.WALL + 4]]:
		var p := track.at(e[0], e[1])
		var st := _inst("prop_stand")
		st.position = p.pos
		var to_track: float = 1.0 if e[1] < 0 else -1.0
		var n := Vector3(p.tan.z, 0, -p.tan.x) * to_track
		st.rotation.y = atan2(n.x, n.z)
		add_child(st)
	var s := 0.0
	var k := 0
	while s < track.length:
		var side := 1.0 if k % 2 == 0 else -1.0
		var p := track.at(s, side * (Track.WALL + 1.3))
		var l := _inst("prop_lamp")
		l.position = p.pos
		var n := Vector3(p.tan.z, 0, -p.tan.x) * -side
		l.rotation.y = atan2(n.x, n.z)
		add_child(l)
		s += 34.0
		k += 1
	var deco := ["prop_tree", "prop_tree", "prop_pine", "prop_pine", "prop_rock"]
	var placed := 0
	for i in 900:
		if placed >= 220:
			break
		var x := (rng.randf() - 0.5) * 330.0
		var z := (rng.randf() - 0.5) * 260.0
		if absf(track.project(Vector3(x, 0, z)).lat) < Track.WALL + 3.5:
			continue
		var m := _inst(deco[rng.randi() % deco.size()])
		m.position = Vector3(x, 0, z)
		m.rotation.y = rng.randf() * TAU
		m.scale = Vector3.ONE * (0.8 + rng.randf() * 0.7)
		add_child(m)
		placed += 1
	placed = 0
	for i in 400:
		if placed >= 24:
			break
		var x := (rng.randf() - 0.5) * 360.0
		var z := (rng.randf() - 0.5) * 300.0
		if absf(track.project(Vector3(x, 0, z)).lat) < Track.WALL + 12 or (absf(x) < 70 and absf(z) < 30):
			continue
		var b := _inst(["prop_bldgA", "prop_bldgB", "prop_bldgC"][rng.randi() % 3])
		b.position = Vector3(x, 0, z)
		b.rotation.y = round(rng.randf() * 4.0) * PI / 2.0
		add_child(b)
		placed += 1

	# props destrutíveis (física de verdade)
	for i in 7:
		_add_prop("prop_cone", 60 + i * 5, -2.75 + (3.0 if i % 2 else -3.0), 6.0, "cyl", Vector2(0.3, 0.9))
	for i in 10:
		_add_prop("prop_cone", 300 + i * 4, -9 + i * 2, 6.0, "cyl", Vector2(0.3, 0.9))
	for e in [[287, 10], [290, 9], [293, 10.5], [347, -10], [350, -9.5], [408, 10], [411, 9.5], [414, 10.3]]:
		_add_prop("prop_barrel", e[0], e[1], 40.0, "cyl", Vector2(0.45, 1.1))
	for i in 6:
		_add_prop("prop_crate", 130 + (i % 3) * 1.3, -5.5 + (i / 3) * 1.3 - 0.6, 35.0, "box", Vector2(1.1, 1.1))
		_add_prop("prop_crate", 508 - (i % 3) * 1.3, 5.5 + (i / 3) * 1.3 - 0.6, 35.0, "box", Vector2(1.1, 1.1))
	for e in [[150, 10.6], [152, 10.6], [250, -10.6], [252, -10.6], [440, 10.6], [560, -10.6]]:
		_add_prop("prop_tires", e[0], e[1], 50.0, "cyl", Vector2(0.5, 0.95))


func _add_prop(name_: String, s: float, lat: float, m: float, shape: String, dims: Vector2) -> void:
	var p := track.at(s, lat)
	var rb := RigidBody3D.new()
	rb.mass = m
	rb.collision_layer = 4
	rb.collision_mask = 1 | 2 | 4
	rb.contact_monitor = true
	rb.max_contacts_reported = 2
	rb.can_sleep = true
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.6
	rb.physics_material_override = pm
	var cs := CollisionShape3D.new()
	if shape == "cyl":
		var c := CylinderShape3D.new()
		c.radius = dims.x
		c.height = dims.y
		cs.shape = c
	else:
		var b := BoxShape3D.new()
		b.size = Vector3(dims.x, dims.y, dims.x)
		cs.shape = b
	cs.position.y = dims.y * 0.5
	rb.add_child(cs)
	var vis := _inst(name_)
	rb.add_child(vis)
	add_child(rb)
	var xf := Transform3D(Basis(Vector3.UP, p.heading), p.pos + Vector3(0, 0.02, 0))
	rb.global_transform = xf
	var pr := {"rb": rb, "home": xf, "hit": false, "t": 0.0, "name": name_}
	props.append(pr)
	rb.body_entered.connect(func(b): _prop_hit(pr, b))


func _prop_hit(pr: Dictionary, b: Node) -> void:
	if pr.hit or not (b is Car):
		return
	var c: Car = b
	pr.hit = true
	pr.t = 0.0
	var rb: RigidBody3D = pr.rb
	var v := c.linear_velocity
	rb.apply_central_impulse((v * 0.5 + Vector3.UP * (4.0 + v.length() * 0.25)) * rb.mass)
	rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * rb.mass * 3.0)
	fx.sparks(rb.global_position + Vector3.UP * 0.5, v, 0.3)
	fx.burst("dust" if pr.name == "prop_crate" else "smoke", rb.global_position + Vector3.UP * 0.4)
	if c == player and mode == "race":
		sfx.play("smash", -4.0)
		_shake(0.12 if pr.name == "prop_cone" else 0.3)
		stats.smash += 1
		stats.score += 25
		_add_nitro(0.02)
		if pr.name != "prop_cone":
			hitstop = maxf(hitstop, 0.035)
		if stats.smash % 5 == 0:
			hud.popup("DESTRUIÇÃO!", Color("#ffcf33"), "x%d" % stats.smash)


# ------------------------------------------------------------------ corrida
func _make_car(kind: String, role: String, col: Color) -> Car:
	var c := Car.new()
	c.setup(lib, kind, role, col)
	add_child(c)
	c.hit.connect(_on_hit)
	c.part_off.connect(_on_part_off)
	c.landed.connect(_on_landed)
	cars.append(c)
	if role != "traffic":
		var e := {}
		e.smoke = [fx.make_tire_smoke(), fx.make_tire_smoke()]
		for s in e.smoke:
			add_child(s)
		e.flame = fx.make_nitro_flame()
		c.add_child(e.flame)
		e.flame.position = c.exhaust_local
		e.trails = [fx.make_trail(Color(1.5, 0.25, 0.4)), fx.make_trail(Color(1.5, 0.25, 0.4))]
		em[c] = e
	var dm := {"dark": fx.make_damage_smoke(true), "fire": fx.make_damage_smoke(false), "skid": [null, null, null, null]}
	c.add_child(dm.dark)
	c.add_child(dm.fire)
	dm.dark.position = Vector3(0, 1.0, c.sp.len * 0.3)
	dm.fire.position = Vector3(0, 0.9, c.sp.len * 0.3)
	dm.shadow = fx.contact_shadow(c.sp.len, c.sp.wid)
	add_child(dm.shadow)
	if role != "traffic":
		dm.dust = [fx.make_dust(), fx.make_dust()]
		for d in dm.dust:
			add_child(d)
	if role == "player":
		dm.wind = fx.make_wind()
		add_child(dm.wind)
	if em.has(c):
		em[c].merge(dm)
	else:
		em[c] = dm
	return c


func _place(c: Car, s: float, lat: float, speed: float) -> void:
	var a := track.at(s, lat)
	var h: float = a.heading + (PI if c.oncoming else 0.0)
	c.place(Transform3D(Basis(Vector3.UP, h), a.pos + Vector3(0, 0.1, 0)), speed)
	var pr := track.project(a.pos)
	c.ti = pr.i
	c.s_track = pr.s
	c.lat = pr.lat
	c.lane = lat
	c.lane_t = lat
	c.lane_cur = lat


func _new_race() -> void:
	for c in cars:
		c.queue_free()
	for c in em:
		for k in ["smoke"]:
			if em[c].has(k):
				for s in em[c][k]:
					s.queue_free()
	em.clear()
	cars.clear()
	rivals.clear()
	traffic.clear()
	var L := track.length
	var grid := [[-9.0, -2.75], [-9.0, -8.25], [-18.0, -2.75], [-18.0, -8.25]]
	for i in RIVALS.size():
		var r: Dictionary = RIVALS[i]
		var c := _make_car(r.kind, "rival", Color(r.color))
		c.display_name = r.name
		c.seed_f = i * 2.1 + 0.5
		c.cruise = 36.5 + i * 0.6
		c.next_bash = 6.0 + i * 3.0
		_place(c, L + grid[i][0], grid[i][1], 0)
		rivals.append(c)
	player = _make_car("faisca", "player", Color("#e8352b"))
	player.display_name = "VOCÊ"
	player.nitro_amt = 0.35
	_place(player, L + grid[3][0], grid[3][1], 0)
	for i in 16:
		var t: Array = TRAFFIC[i % TRAFFIC.size()]
		var cols: Array = t[1]
		var c := _make_car(t[0], "traffic", Color(cols[randi() % cols.size()]))
		c.oncoming = i % 5 == 1 or i % 5 == 3
		c.cruise = randf_range(15, 20) if c.oncoming else randf_range(13, 19)
		var s := 50.0 + (float(i) / 16.0) * (L - 90.0) + randf_range(-8, 8)
		var lanes: Array = Track.LANES_ONC if c.oncoming else Track.LANES_FWD
		_place(c, s, lanes[randi() % 2], c.cruise)
		traffic.append(c)
	for c in cars:
		var pr := track.project(c.global_position)
		c.dist = pr.s - L if pr.s > L * 0.5 else pr.s
		c.prev_s = pr.s
		c.lap = 0
	for c in [player] + rivals:
		c.freeze = true
	for pr in props:
		_reset_prop(pr)
	stats = {"takedowns": 0, "near": 0, "best_drift": 0.0, "oncoming": 0.0, "air": 0.0, "crashes": 0, "smash": 0, "score": 0, "parts": 0}
	race_t = 0.0
	lap_start = 0.0
	best_lap = INF
	ts_target = 1.0
	slow_t = 0.0
	hitstop = 0.0
	cam_focus = null
	crash_t = -1.0
	place = 4
	cam_pos = player.global_position
	hud.cars = cars
	hud.player = player


func _reset_prop(pr: Dictionary) -> void:
	var rb: RigidBody3D = pr.rb
	rb.global_transform = pr.home
	rb.linear_velocity = Vector3.ZERO
	rb.angular_velocity = Vector3.ZERO
	rb.sleeping = true
	pr.hit = false
	pr.t = 0.0
	for ch in rb.get_children():
		if ch is Node3D:
			ch.scale = Vector3.ONE


func _start() -> void:
	_new_race()
	hud.menu.visible = false
	hud.results.visible = false
	hud.pause_m.visible = false
	hud.set_race_hud(true)
	mode = "countdown"
	countdown = 3.0
	last_beep = 4
	get_tree().paused = false


func _to_menu() -> void:
	_new_race()
	hud.results.visible = false
	hud.set_race_hud(false)
	hud.menu.visible = true
	mode = "menu"


func _pause(on: bool) -> void:
	if on and mode in ["race", "countdown"]:
		hud.set_meta("prev", mode)
		mode = "paused"
		hud.pause_m.visible = true
		Engine.time_scale = 0.0
	elif not on and mode == "paused":
		mode = hud.get_meta("prev")
		hud.pause_m.visible = false


# ------------------------------------------------------------------ eventos de batida
func _on_hit(c: Car, other: Object, point: Vector3, dv: float) -> void:
	c.take_damage(point, dv)
	var lp := c.to_local(point)
	var front: float = lp.z / (c.sp.len * 0.5)
	var out := (point - c.global_position)
	out.y = 0
	out = out.normalized()
	var oc: Car = other as Car
	var vis := _on_screen(point)
	if vis and dv > 4.0:
		var back := -c.linear_velocity.normalized() * 0.6
		fx.sparks(point + Vector3.UP * 0.3, out + back, clampf(dv / 14.0, 0.3, 2.0))
		if dv > 9.0:
			fx.sparks(point + Vector3.UP * 0.4, -out + back, clampf(dv / 20.0, 0.3, 1.5))
			fx.hit_light(point + Vector3.UP * 1.0, Color(1.0, 0.7, 0.3), clampf(dv * 0.4, 3.0, 10.0), 9.0, 0.25)
	if oc:
		if c.role != "player" and oc == player:
			c.last_hit_by = player
			c.last_hit_t = time_g
	if mode != "race":
		return
	if c == player:
		if oc == null:
			if dv > 30.0 and front > 0.72 and c.invuln <= 0.0:
				_crash_player(dv, -out)
				return
		elif oc.role == "traffic" and front > 0.65 and c.invuln <= 0.0 and (dv > 33.0 or (dv > 25.0 and oc.oncoming)):
			_crash_player(dv, -out)
			_wreck(oc, dv, out, false)
			return
		if dv > 5.0:
			_shake(minf(0.55, dv * 0.025))
			sfx.play("bump", linear_to_db(clampf(dv / 20.0, 0.2, 1.0)))
			if dv > 9.0:
				sfx.play("metal", -6.0)
			if dv > 16.0:
				c.stun = 0.2
				hitstop = maxf(hitstop, 0.05)
				_flash(Color(1, 1, 1), 0.12)
			if oc and oc.role == "rival" and dv > 4.0:
				_add_nitro(0.04)
				hud.popup("ENCOSTOU!", Color("#8a8aff"))
		elif dv > 3.0:
			sfx.play("scrape", -8.0)
		return
	if c.wrecked:
		return
	var by_player := c.last_hit_by == player and time_g - c.last_hit_t < 1.6
	if c.role == "rival":
		if by_player and dv > 11.0 and c.invuln <= 0.0:
			_takedown(c, dv, out)
		elif dv > 26.0 and front > 0.6:
			_wreck(c, dv, -out, false)
	else:
		if by_player and dv > 12.0:
			_wreck(c, dv, -out, false)
			stats.score += 150
			hud.popup("TRÂNSITO!", Color("#ff7a1a"), "+150")
			_add_nitro(0.08)
			hitstop = maxf(hitstop, 0.05)
		elif dv > 19.0:
			_wreck(c, dv, -out, false)


func _wreck(c: Car, power: float, dir: Vector3, big: bool) -> void:
	if c.wrecked:
		return
	c.wreck(power, dir)
	if _on_screen(c.global_position):
		fx.explosion(c.global_position, big)
		_shake(0.9 if big else 0.35)
		sfx.play("crash", 0.0 if big else -5.0)
		sfx.play("glass", -4.0)


func _takedown(c: Car, power: float, dir: Vector3) -> void:
	_wreck(c, maxf(power, 22.0), -dir, true)
	stats.takedowns += 1
	stats.score += 1000
	player.nitro_amt = 1.0
	hud.big("TAKEDOWN!", Color.WHITE, Color("#ff2d55"))
	hud.popup(c.display_name, Color("#ff2d55"), "+1000")
	sfx.play("fanfare", -6.0)
	_flash(Color(1, 0.9, 0.6), 0.45)
	hitstop = 0.09
	_slowmo(0.28, 1.0)
	cam_focus = c
	focus_t = 1.0
	zoom_kick -= 7.0
	fx.ring(c.global_position, Color(2.0, 0.6, 0.9, 1.0), 12.0)
	Input.vibrate_handheld(80)


func _crash_player(power: float, dir: Vector3) -> void:
	if player.wrecked:
		return
	player.nitro_amt = maxf(0.0, player.nitro_amt - 0.25)
	_wreck(player, maxf(power, 26.0), dir, true)
	stats.crashes += 1
	hud.big("BATIDA!", Color("#ffe14d"), Color("#ff5a1a"))
	_flash(Color(1, 1, 1), 0.7)
	hitstop = 0.12
	_slowmo(0.25, 1.7)
	crash_t = 0.0
	zoom_kick -= 10.0
	Input.vibrate_handheld(150)


func _respawn_player() -> void:
	var pr := track.project(player.global_position, player.ti)
	var old_dist := player.dist
	player.repair()
	_place(player, pr.s - 4.0, -2.75, 16.0)
	player.invuln = 2.2
	player.dist = old_dist
	player.prev_s = track.project(player.global_position).s
	crash_t = -1.0
	zoom_kick += 5.0
	fx.burst("smoke", player.global_position + Vector3.UP * 0.5)
	fx.ring(player.global_position, Color(1.5, 1.5, 1.5, 1.0), 6.0)


func _on_part_off(c: Car, mesh: MeshInstance3D, xform: Transform3D, vel: Vector3, is_wheel: bool) -> void:
	fx.spawn_debris(mesh, xform, vel, is_wheel)
	if not _on_screen(xform.origin):
		return
	fx.sparks(xform.origin, vel, 0.6)
	if String(mesh.name).ends_with("cabin"):
		fx.burst("glass", xform.origin + Vector3.UP)
		sfx.play("glass", -3.0)
	else:
		sfx.play("metal", -8.0, randf_range(0.8, 1.3))
	if c == player and mode == "race" and not c.wrecked:
		stats.parts += 1
		var names := {"hood": "CAPÔ", "bumperF": "PARA-CHOQUE", "bumperR": "PARA-CHOQUE", "doorL": "PORTA", "doorR": "PORTA", "spoiler": "AEROFÓLIO", "cargo": "CAÇAMBA"}
		var key := String(mesh.name).substr(c.kind.length() + 1)
		hud.popup("PERDEU O %s!" % names.get(key, "PEDAÇO"), Color("#ff7a1a"))


func _on_landed(c: Car, air: float, impact: float) -> void:
	if not _on_screen(c.global_position):
		return
	fx.burst("dust", c.global_position + Vector3.UP * 0.2)
	if c != player:
		return
	_shake(minf(0.45, impact * 0.03))
	sfx.play("land", linear_to_db(clampf(impact / 15.0, 0.3, 1.0)))
	hitstop = maxf(hitstop, 0.04)
	if air > 0.5 and mode == "race":
		var pts := int(air * 150)
		hud.popup("PULÃO %.1fs" % air, Color("#7dff6a"), "+%d" % pts)
		stats.score += pts
		stats.air = maxf(stats.air, air)
		_add_nitro(0.12)


func _add_nitro(a: float) -> void:
	var was := player.nitro_amt
	player.nitro_amt = minf(1.0, player.nitro_amt + a)
	if was < 1.0 and player.nitro_amt >= 1.0:
		hud.popup("NITRO CHEIO!", Color("#2ee6ff"))
		sfx.play("coin", -6.0)
	hud.bump_bar()


# ------------------------------------------------------------------ juice helpers
func _shake(a: float) -> void:
	trauma = minf(1.0, trauma + a)


func _flash(c: Color, a: float) -> void:
	flash = Color(c.r, c.g, c.b, maxf(flash.a, a))


func _slowmo(target: float, dur: float) -> void:
	ts_target = target
	slow_t = dur
	ts = minf(ts, target + 0.15)


func _on_screen(p: Vector3) -> bool:
	if cam_mode == "chase":
		return p.distance_to(player.global_position) < 90.0
	return Vector2(p.x - cam_pos.x, p.z - cam_pos.z).length() < view_h * 1.3


func _toggle_cam() -> void:
	cam_mode = "chase" if cam_mode == "iso" else "iso"
	var chase := cam_mode == "chase"
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE if chase else Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1 if chase else 1.0
	cam.far = 500.0 if chase else 400.0
	# na terceira pessoa aparece o horizonte: céu de verdade e neblina de distância
	env.background_mode = Environment.BG_SKY if chase else Environment.BG_COLOR
	env.fog_enabled = chase
	env.fog_light_color = Color("#cfe0f5")
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	var f := player.global_transform.basis.z
	chase_dir = Vector3(f.x, 0, f.z).normalized()
	chase_pos = player.global_position - chase_dir * 8.0 + Vector3.UP * 3.2
	hud.popup("CÂMERA 3ª PESSOA" if chase else "CÂMERA ISOMÉTRICA", Color("#2e7dff"))


func _chase_camera(rdt: float) -> void:
	var p := player
	var v := p.linear_velocity
	var sp := v.length()
	var target := p.global_position
	if p.wrecked:
		# carro destruído: a câmera gira devagar em volta do destroço
		orbit_a += rdt * 0.9
		var o := Vector3(sin(orbit_a), 0, cos(orbit_a)) * 9.0 + Vector3.UP * 4.5
		chase_pos = chase_pos.lerp(target + o, 1.0 - exp(-rdt * 3.0))
		cam.global_position = chase_pos
		cam.look_at(target + Vector3.UP * 0.8, Vector3.UP)
	else:
		var f := p.global_transform.basis.z
		var fwd := Vector3(f.x, 0, f.z).normalized()
		# no drift a câmera segue mais o movimento do que o bico do carro
		var vel_dir := Vector3(v.x, 0, v.z).normalized() if sp > 6.0 else fwd
		var want_dir := fwd.lerp(vel_dir, 0.55 if p.drifting else 0.25).normalized()
		chase_dir = chase_dir.slerp(want_dir, 1.0 - exp(-rdt * (3.0 if p.on_ground else 1.2))).normalized()
		orbit_a = atan2(-chase_dir.x, -chase_dir.z)
		var dist := 7.0 + clampf(sp / 55.0, 0.0, 1.0) * 2.5 - (1.0 if p.nitroing else 0.0)
		var height := 2.8 + clampf(sp / 55.0, 0.0, 1.0) * 0.6
		if cam_focus and focus_t > 0.0:
			# takedown: câmera recua e olha para a vítima
			target = cam_focus.global_position
			dist += 6.0
			height += 3.0
		var desired := p.global_position - chase_dir * dist + Vector3.UP * height
		chase_pos = chase_pos.lerp(desired, 1.0 - exp(-rdt * 9.0))
		cam.global_position = chase_pos
		cam.look_at(target + Vector3.UP * 1.1 + chase_dir * 5.0, Vector3.UP)
	var want_fov := 62.0 + clampf(sp / 55.0, 0.0, 1.0) * 14.0 + (10.0 if p.nitroing else 0.0) + zoom_kick * 0.9
	zoom_kick *= exp(-rdt * 4.0)
	chase_fov = lerpf(chase_fov, clampf(want_fov, 40.0, 100.0), 1.0 - exp(-rdt * 5.0))
	cam.fov = chase_fov
	shake_t += rdt
	trauma = maxf(0.0, trauma - rdt * 1.6)
	var s := trauma * trauma
	cam.h_offset = (sin(shake_t * 37.0) * 0.6 + sin(shake_t * 85.0 + 1.0) * 0.4) * s * 0.5
	cam.v_offset = (sin(shake_t * 41.0 + 4.0) * 0.6 + sin(shake_t * 94.0 + 2.0) * 0.4) * s * 0.4
	cam.rotate_object_local(Vector3.FORWARD, sin(shake_t * 29.0 + 9.0) * s * 0.05)
	# tremidinha de velocidade
	if sp > 35.0:
		cam.v_offset += sin(shake_t * 60.0) * 0.015 * (sp - 35.0) / 20.0
	cam_pos = p.global_position


# ------------------------------------------------------------------ loop
func _physics_process(dt: float) -> void:
	if mode in ["loading", "paused"]:
		return
	time_g += dt
	for c in cars:
		c.game_time = time_g
		if c.role != "player" and not c.wrecked:
			c.ai(track, self, dt)
	if mode == "race" and not player.wrecked:
		_player_input()
	elif not player.wrecked:
		player.ctrl.throttle = 0.6 if mode == "finish" else 0.0
		player.ctrl.steer = 0.0
		player.ctrl.dir = null
		player.ctrl.nitro = false
		player.ctrl.drift = false
		player.ctrl.brake = 0.0
		if mode == "finish":
			player.ai(track, self, dt)
			player.ctrl.nitro = false
	# boost pads
	for c in cars:
		if c.wrecked or not c.on_ground or time_g < c.pad_t:
			continue
		if track.pad_at(c.global_position) != null:
			c.pad_t = time_g + 0.8
			var f: Vector3 = c.global_transform.basis.z
			var v: float = maxf(c.linear_velocity.length(), c.sp.nitro * 0.95)
			c.linear_velocity = Vector3(f.x, 0, f.z).normalized() * v + Vector3.UP * c.linear_velocity.y
			if c == player:
				_add_nitro(0.2)
				sfx.play("nitro", -2.0)
				hud.popup("TURBO!", Color("#ff9a1a"))
				zoom_kick += 5.0
				_shake(0.2)
				_flash(Color(0.5, 0.9, 1.0), 0.18)
				fx.ring(c.global_position, Color(0.4, 1.4, 2.0, 1.0), 7.0)
	_rules(dt)
	_recycle()
	for pr in props:
		if pr.hit:
			pr.t += dt
			if pr.t > 10.0 and player.global_position.distance_to(pr.home.origin) > 70.0:
				_reset_prop(pr)


func _player_input() -> void:
	var c := player.ctrl
	c.steer = Input.get_action_strength("left") - Input.get_action_strength("right")
	c.throttle = Input.get_action_strength("up")
	c.brake = Input.get_action_strength("down")
	c.drift = Input.is_action_pressed("drift")
	c.nitro = Input.is_action_pressed("nitro")
	c.dir = null
	var tp := hud.touch
	if tp.active and tp.visible:
		# quem usa os controles de tela acelera sozinho; freio solta o acelerador
		if tp.used and not tp.btn.brake and c.brake <= 0.0:
			c.throttle = 1.0
		if tp.btn.brake:
			c.brake = 1.0
			c.throttle = 0.0
		c.drift = c.drift or tp.btn.drift
		c.nitro = c.nitro or tp.btn.nitro
		if tp.stick_vec.length() > 0.22:
			var r := cam.global_basis.x
			var f := -cam.global_basis.z
			var rr := Vector3(r.x, 0, r.z).normalized()
			var ff := Vector3(f.x, 0, f.z).normalized()
			c.dir = (rr * tp.stick_vec.x - ff * tp.stick_vec.y).normalized()
			c.dir_mag = minf(1.0, (tp.stick_vec.length() - 0.22) / 0.5)
	if auto_test:
		_autopilot()


func _autopilot() -> void:
	var p := player
	var pr := track.project(p.global_position, p.ti)
	var tp := track.at(pr.s + 6.0 + maxf(0.0, p.v_f) * 0.45, test_lane)
	var to: Vector3 = tp.pos - p.global_position
	p.ctrl.dir = Vector3(to.x, 0, to.z).normalized()
	p.ctrl.dir_mag = 1.0
	p.ctrl.throttle = 1.0
	var max_c := 0.0
	for k in range(2, 20, 2):
		max_c = maxf(max_c, absf(track.curv[track.idx(pr.i + k)]))
	p.ctrl.drift = max_c > 0.03 and p.v_f > 24.0
	p.ctrl.nitro = max_c < 0.01 and p.nitro_amt > 0.3


func _rules(dt: float) -> void:
	var L := track.length
	for c in cars:
		var pr := track.project(c.global_position, c.ti)
		c.ti = pr.i
		c.lat = pr.lat
		c.s_track = pr.s
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
			if c == player and mode == "race":
				var lt := race_t - lap_start
				lap_start = race_t
				best_lap = minf(best_lap, lt)
				if lap >= LAPS:
					_finish()
				else:
					hud.big("ÚLTIMA VOLTA!" if lap == LAPS - 1 else "VOLTA %d" % (lap + 1), Color("#ffcf33"), Color("#c74200"))
					sfx.play("fanfare", -6.0)
					fx.burst("confetti", player.global_position + Vector3.UP)
	if mode != "race":
		return
	race_t += dt
	var order := [player] + rivals
	order.sort_custom(func(a, b): return a.dist > b.dist)
	place = order.find(player) + 1
	for r in rivals:
		r.rubber = clampf(1.0 + (player.dist - r.dist) * 0.003, 0.84, 1.12)
	if player.wrecked:
		return
	var p := player
	var v := p.linear_velocity
	var sp := v.length()
	# drift: nitro contínuo + popup no fim
	if p.drifting and p.v_f > 12.0:
		p.nitro_amt = minf(1.0, p.nitro_amt + dt * 0.1 * minf(1.0, p.drift_slip * 2.0))
	if was_drift and not p.drifting and p.drift_t > 0.8:
		var pts := int(p.drift_t * 120)
		hud.popup("DRIFT %.1fs" % p.drift_t, Color("#c77dff"), "+%d" % pts)
		stats.score += pts
		stats.best_drift = maxf(stats.best_drift, p.drift_t)
		_add_nitro(minf(0.15, p.drift_t * 0.04))
	was_drift = p.drifting
	if not p.on_ground:
		p.nitro_amt = minf(1.0, p.nitro_amt + dt * 0.06)
	# contramão
	var tg := track.tans[p.ti]
	var along := v.x * tg.x + v.z * tg.y
	if p.lat > 0.8 and along > 14.0 and p.on_ground:
		p.nitro_amt = minf(1.0, p.nitro_amt + dt * 0.11 * sp / p.sp.vmax)
		onc_dist += along * dt
		stats.oncoming += along * dt
		hud.onc_l.modulate.a = 1.0 if int(real * 6.0) % 2 == 0 else 0.6
	else:
		if onc_dist > 40.0:
			hud.popup("CONTRAMÃO %dm" % int(onc_dist), Color("#ff2d55"), "+%d" % int(onc_dist))
			stats.score += int(onc_dist)
		onc_dist = 0.0
		hud.onc_l.modulate.a = 0.0
	# quase-batidas
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
	_add_nitro(0.07 + (0.05 if c.oncoming else 0.0))
	hud.popup("POR UM TRIZ!" if c.oncoming else "QUASE!", Color("#2ee6ff"), ("x%d +%d" % [nm_combo, pts]) if nm_combo > 1 else "+%d" % pts)
	sfx.play("whoosh", -3.0)
	zoom_kick += 1.5
	_shake(0.05)


func _finish() -> void:
	mode = "finish"
	hud.big("VITÓRIA!" if place == 1 else "%dº LUGAR" % place, Color("#ffcf33"), Color("#c74200"))
	sfx.play("fanfare")
	fx.burst("confetti", player.global_position + Vector3.UP)
	_slowmo(0.35, 1.2)
	get_tree().create_timer(2.0, true, false, true).timeout.connect(_show_results)
	if auto_test:
		print("RESULT ", JSON.stringify({"place": place, "time": race_t, "stats": stats}))


func _show_results() -> void:
	hud.res_title.text = "VITÓRIA!" if place == 1 else "%dº LUGAR" % place
	var lines := [
		"Tempo total   %s" % _fmt(race_t), "Melhor volta   %s" % _fmt(best_lap), "Takedowns   %d" % stats.takedowns,
		"Quase-batidas   %d" % stats.near, "Maior drift   %.1fs" % stats.best_drift, "Contramão   %dm" % int(stats.oncoming),
		"Batidas   %d" % stats.crashes, "Pontos   %d" % stats.score]
	hud.res_list.text = "\n".join(lines)
	hud.results.visible = true
	hud.set_race_hud(false)
	if auto_test:
		get_tree().quit()


func _fmt(t: float) -> String:
	if t == INF:
		return "--:--.--"
	var m := int(t / 60.0)
	return "%d:%05.2f" % [m, t - m * 60.0]


func _recycle() -> void:
	var p := player
	var L := track.length
	for c in traffic:
		var rel: float = wrapf(c.s_track - p.s_track, -L * 0.5, L * 0.5)
		var far := rel < -70.0 or rel > 260.0
		var vis := _on_screen(c.global_position)
		if ((c.wrecked and c.wreck_t > 4.0) or far) and not vis:
			for tries in 6:
				var s := p.s_track + randf_range(110, 250)
				var lanes: Array = Track.LANES_ONC if c.oncoming else Track.LANES_FWD
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
	for r in rivals:
		if r.wrecked and r.wreck_t > 3.2:
			var old_s: float = r.s_track
			r.repair()
			var lanes: Array = Track.LANES_FWD
			_place(r, p.s_track - randf_range(26, 40), lanes[randi() % 2], 24.0)
			r.dist += wrapf(r.s_track - old_s, -L * 0.5, L * 0.5)
			r.prev_s = r.s_track
			r.invuln = 1.5


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var rdt := minf(0.05, (now - _last_us) / 1e6)
	_last_us = now
	if auto_test:
		rdt = 1.0 / 60.0
	if mode == "loading":
		return
	real += rdt
	if Input.is_action_just_pressed("pause"):
		_pause(mode != "paused")
	if Input.is_action_just_pressed("camera"):
		_toggle_cam()
	if Input.is_action_just_pressed("mute"):
		sfx.set_muted(not sfx.muted)
	if Input.is_action_just_pressed("start") and mode == "menu":
		_start()
	if Input.is_action_just_pressed("reset") and mode == "race" and not player.wrecked:
		_respawn_player()
	if mode == "paused":
		Engine.time_scale = 0.0
		return

	# tempo: hitstop congela, slow-mo desacelera (tudo em tempo real)
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
			if Input.is_action_pressed("up") or hud.touch.used or auto_test:
				player.linear_velocity = player.global_transform.basis.z * 14.0
				_add_nitro(0.15)
				hud.popup("LARGADA PERFEITA!", Color("#ff9a1a"))
	if crash_t >= 0.0:
		crash_t += rdt
		if crash_t > 2.2:
			_respawn_player()

	_car_fx(rdt * eff)
	if player.nitroing and not was_nitro:
		sfx.play("nitro")
		zoom_kick += 4.0
		_shake(0.15)
		fx.ring(player.global_position - player.global_transform.basis.z * 2.0, Color(0.4, 1.2, 2.2, 1.0), 6.0)
		_flash(Color(0.6, 0.9, 1.0), 0.12)
	was_nitro = player.nitroing
	var sp01: float = player.linear_velocity.length() / player.sp.vmax
	var slip := 1.0 if player.drifting else clampf((absf(player.v_s) - 3.0) / 8.0, 0.0, 1.0)
	if player.ctrl.brake > 0.0 and player.v_f > 10.0:
		slip += 0.5
	sfx.drive(clampf(sp01, 0.0, 1.3), player.ctrl.throttle, slip, player.nitroing, ts < 0.6, mode in ["race", "countdown", "finish"] and not player.wrecked)
	_camera(rdt)
	_post(rdt)
	_hud()
	if auto_test and test_shots.size() > 0 and real > float(test_shots[0]):
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://shot_%s.png" % test_shots[0])
		print("SHOT ", ProjectSettings.globalize_path("user://shot_%s.png" % test_shots[0]))
		test_shots.pop_front()
	if auto_test and real > 140.0:
		print("TIMEOUT ", JSON.stringify(stats))
		get_tree().quit()


func _scrapes() -> void:
	# distribui os jatos de faíscas entre os carros raspando mais perto do jogador
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
			var sp := v.length()
			var dir := (-v.normalized() * 0.85 + c.scrape_n * 0.35 + Vector3.UP * 0.3).normalized()
			fx.set_scrape(n, true, c.scrape_pt + Vector3.UP * 0.25, dir, clampf(sp / 30.0, 0.2, 1.3))
			if c == player:
				player_scr = clampf(sp / 25.0, 0.3, 1.0)
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
		var skidding: bool = vis and not c.wrecked and c.on_ground and (c.drifting or slip > 3.5 or braking)
		# marcas e fumaça
		var wi := 0
		for w in c.wheels:
			if w.lost:
				wi += 1
				continue
			var wp: Vector3 = c.global_transform * Vector3(w.base.x, 0.0, w.base.z)
			if skidding and w.contact and (not w.front or braking):
				var last = e.skid[wi]
				if last != null:
					fx.skid(last, wp, 0.38, 0.4 if c.drifting else 0.28)
				e.skid[wi] = wp
			else:
				e.skid[wi] = null
			wi += 1
		if e.has("smoke"):
			var rear := []
			for w in c.wheels:
				if not w.front:
					rear.append(w)
			for i in 2:
				var s: CPUParticles3D = e.smoke[i]
				if i < rear.size() and not rear[i].lost:
					s.global_position = c.global_transform * Vector3(rear[i].base.x, 0.2, rear[i].base.z)
				s.emitting = skidding and (c.drifting or slip > 5.0 or braking)
			var flame: Node3D = e.flame
			(flame.get_node("P") as CPUParticles3D).emitting = c.nitroing
			var core := flame.get_node("Core") as Node3D
			core.visible = c.nitroing
			if c.nitroing:
				var w := randf_range(0.9, 1.15)
				core.scale = Vector3(w, w, randf_range(0.8, 1.25))
			for i in 2:
				var tp: Vector3 = c.global_transform * c.tail_local[i]
				fx.trail_push(e.trails[i], tp, real, c.nitroing and vis)
		# dano: fumaça preta e fogo
		(e.dark as CPUParticles3D).emitting = vis and (c.health < 55.0 or c.wrecked)
		(e.fire as CPUParticles3D).emitting = vis and (c.health < 20.0 or (c.wrecked and c.wreck_t < 3.0))
		# sombra de contato acompanha o chão e some quando o carro sobe
		var sh: MeshInstance3D = e.shadow
		var gp: Vector3 = c.global_position
		var hgt := 0.0 if c.on_ground else clampf(c.air_t * 3.0, 0.0, 3.0)
		if c.wrecked:
			hgt = clampf(gp.y - 0.4, 0.0, 3.0)
		sh.global_position = Vector3(gp.x, 0.055 + (gp.y if c.on_ground and not c.wrecked else 0.0), gp.z)
		sh.rotation = Vector3(0, atan2(c.global_transform.basis.z.x, c.global_transform.basis.z.z), 0)
		(sh.material_override as ShaderMaterial).set_shader_parameter("strength", clampf(1.0 - hgt * 0.3, 0.15, 1.0))
		sh.visible = vis
		# poeira saindo do asfalto
		if e.has("dust"):
			var off: bool = absf(c.lat) > Track.HALF + 0.4 and c.on_ground and c.linear_velocity.length() > 8.0 and vis
			var rear: Array = c.wheels.filter(func(w): return not w.front)
			for i in 2:
				if i < rear.size():
					e.dust[i].global_position = c.global_transform * Vector3(rear[i].base.x, 0.2, rear[i].base.z)
				e.dust[i].emitting = off
		if e.has("wind"):
			var w: CPUParticles3D = e.wind
			var sp: float = c.linear_velocity.length()
			w.emitting = (sp > 36.0 or c.nitroing) and not c.wrecked
			if w.emitting:
				var dir: Vector3 = c.linear_velocity.normalized()
				w.global_position = gp + Vector3(dir.x, 0, dir.z) * 10.0 + Vector3.UP * 1.5
				w.direction = -dir
				w.initial_velocity_min = sp * 0.05
				w.initial_velocity_max = sp * 0.1
		# roda perdida raspando no chão: faíscas
		if vis and not c.wrecked and c.linear_velocity.length() > 6.0:
			for w in c.wheels:
				if w.lost and randf() < dt * 30.0:
					fx.sparks(c.global_transform * Vector3(w.base.x, 0.1, w.base.z), -c.linear_velocity, 0.25)


func _camera(rdt: float) -> void:
	if cam_mode == "chase":
		_chase_camera(rdt)
		return
	var p := player
	var v := p.linear_velocity
	var target := p.global_position + Vector3(v.x, 0, v.z) * 0.38
	var focus_h := 0.0
	if cam_focus and focus_t > 0.0:
		target = (cam_focus.global_position + p.global_position) * 0.5
		focus_h = -6.0
	if p.wrecked:
		target = p.global_position
	target.y = 0.0
	cam_pos = cam_pos.lerp(target, 1.0 - exp(-rdt * (3.0 if p.wrecked else 4.5)))
	var vs := get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(1.0, vs.y)
	var base := maxf(26.0, 24.0 / aspect) if aspect < 1.0 else 26.0
	var sp := v.length()
	var want := base + clampf(sp / 55.0, 0.0, 1.0) * 8.0 + (4.0 if p.nitroing else 0.0) + focus_h + (-10.0 if p.wrecked else 0.0)
	zoom_kick *= exp(-rdt * 4.0)
	view_h = lerpf(view_h, want + zoom_kick, 1.0 - exp(-rdt * 3.0))
	cam.size = maxf(8.0, view_h)
	var off := Vector3(sin(CAM_YAW) * cos(CAM_PITCH), sin(CAM_PITCH), cos(CAM_YAW) * cos(CAM_PITCH)) * CAM_DIST
	cam.global_position = cam_pos + off
	cam.look_at(cam_pos, Vector3.UP)
	# tremor por trauma²
	shake_t += rdt
	trauma = maxf(0.0, trauma - rdt * 1.6)
	var s := trauma * trauma
	var nx := sin(shake_t * 37.0) * 0.6 + sin(shake_t * 85.0 + 1.0) * 0.4
	var ny := sin(shake_t * 41.0 + 4.0) * 0.6 + sin(shake_t * 94.0 + 2.0) * 0.4
	var nr := sin(shake_t * 29.0 + 9.0)
	cam.h_offset = nx * s * 1.6
	cam.v_offset = ny * s * 1.2
	cam.rotate_object_local(Vector3.FORWARD, nr * s * 0.04)


func _post(rdt: float) -> void:
	var p := player
	var sp := p.linear_velocity.length()
	var slow := ts < 0.6
	var bt := (0.6 if p.nitroing else 0.0) + clampf((sp - 38.0) / 30.0, 0.0, 0.2) + (0.4 if slow else 0.0)
	post_blur = lerpf(post_blur, bt, minf(1.0, rdt * 6.0))
	post_aberr = lerpf(post_aberr, (0.8 if p.nitroing else 0.0) + trauma * 1.5 + (0.8 if slow else 0.0), minf(1.0, rdt * 8.0))
	post_lines = lerpf(post_lines, (1.0 if p.nitroing else 0.0) + clampf((sp - 42.0) / 15.0, 0.0, 0.6), minf(1.0, rdt * 6.0))
	flash.a *= exp(-rdt * 7.0)
	var m := hud.post_mat
	m.set_shader_parameter("blur", post_blur)
	m.set_shader_parameter("aberr", post_aberr)
	m.set_shader_parameter("lines", post_lines)
	m.set_shader_parameter("flash", Vector4(flash.r, flash.g, flash.b, flash.a))
	m.set_shader_parameter("sat", 0.7 if slow else 1.08)
	m.set_shader_parameter("vig", 0.3 + (0.25 if p.nitroing else 0.0) + (0.3 if slow else 0.0))
	var vs := get_viewport().get_visible_rect().size
	m.set_shader_parameter("aspect", vs.x / maxf(1.0, vs.y))
	var sc := cam.unproject_position(p.global_position + Vector3.UP * 0.6) / vs
	m.set_shader_parameter("center", sc)


func _hud() -> void:
	var p := player
	hud.nitro = p.nitro_amt
	hud.nitro_on = p.nitroing
	hud.touch.nitro_fill = p.nitro_amt
	hud.pos_l.text = "%dº" % place
	hud.lap_l.text = "VOLTA %d/%d" % [clampi(p.lap + 1, 1, LAPS), LAPS]
	hud.time_l.text = _fmt(race_t)
	hud.score_l.text = "%d PTS" % stats.score
	hud.td_l.text = "   TAKEDOWNS %d" % stats.takedowns
	hud.speed_l.text = "%d km/h" % int(p.linear_velocity.length() * 3.6 * 1.25)


func _exit_tree() -> void:
	if is_instance_valid(lib):
		lib.free()
