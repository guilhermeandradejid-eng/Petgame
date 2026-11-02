class_name LevelBase
extends Node3D
## Base class for every level: environment, players, shared camera, HUD,
## puzzle logic channels, respawning, and a small builder API so levels are
## written as readable code (see level_1.gd .. level_3.gd).

signal channel_changed(name: String, value: bool)

const ISLAND := preload("res://assets/models/island.glb")
const TREE := preload("res://assets/models/tree.glb")
const TREE_PINK := preload("res://assets/models/tree_pink.glb")
const BUSH := preload("res://assets/models/bush.glb")
const FLOWER := preload("res://assets/models/flower.glb")
const ROCK := preload("res://assets/models/rock.glb")
const CRYSTAL := preload("res://assets/models/crystal.glb")
const CHANNEL_PALETTE := [Color(0.25, 0.9, 0.85), Color(1.0, 0.45, 0.75), Color(1.0, 0.75, 0.25), Color(0.55, 0.95, 0.4), Color(0.5, 0.65, 1.0), Color(1.0, 0.5, 0.35)]
const FLOWER_COLORS := [Color(1.0, 0.55, 0.7), Color(1.0, 0.85, 0.4), Color(0.7, 0.6, 1.0), Color(1, 1, 1), Color(0.5, 0.85, 1.0)]

var players: Array = []
var camera: CoopCamera
var hud: Hud
var active := 0
var sparks := 0
var spark_total := 0
var seeds := [false, false, false]
var elapsed := 0.0
var kill_y := -30.0
var spawn := Vector3.ZERO
var spawn_fwd := Vector3.FORWARD
var checkpoint := Vector3.ZERO
var checkpoint_up := Vector3.UP
var done := false
var sky_colors := {}
var music_seed := 0
## Phones/tablets get lighter scenery (fewer grass blades, cheaper effects).
var low_spec := OS.has_feature("mobile") or OS.has_feature("web")
## false for grounded worlds (no sea of clouds / floating islets).
var floating_world := true

var _channels := {}  # name -> {source_id: bool}
var _channel_colors := {}
var _paused := false
var _sea: MeshInstance3D
var _sun: DirectionalLight3D
var _blade: ArrayMesh
var _focus_t := 0.0
var _rng := RandomNumberGenerator.new()


# ------------------------------------------------------------- lifecycle
func _ready() -> void:
	_rng.seed = 1234
	configure()
	_build_environment()
	build()  # implemented by each level
	checkpoint = spawn
	_spawn_players()
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	hud.resume_requested.connect(func(): _set_paused(false))
	hud.restart_requested.connect(func(): Game.play_level(Game.current_level))
	hud.menu_requested.connect(func(): Game.to_title())
	hud.next_requested.connect(_on_next)
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args():
		hud.add_child(TouchControls.new())
	var info: Dictionary = Game.LEVELS[Game.current_level]
	hud.title_card(info["title"], info["sub"])
	for s in get_tree().get_nodes_in_group("spark"):
		spark_total += 1
	spark_total += get_tree().get_nodes_in_group("pound_target").filter(func(n): return n is Crate).size() * 4
	spark_total += get_tree().get_nodes_in_group("pound_target").filter(func(n): return n is Urchin).size() * 3
	Sfx.play_music(music_seed)
	Vfx.set_vignette(0.22)


## Override to set kill_y, sky_colors and music_seed before the world is built.
func configure() -> void:
	pass


## Override to build the level with the helper functions below.
func build() -> void:
	pass


## Logic AND: `out` is on while every channel in `inputs` is on.
func and_gate(out: String, inputs: Array) -> void:
	var src := Node.new()
	add_child(src)
	channel_changed.connect(func(_n, _v):
		var all := true
		for c in inputs:
			all = all and channel(c)
		if all != channel(out):
			set_channel(out, src, all))


## Latch: `out` turns on (for good) the first time every input is on.
func latch_gate(out: String, inputs: Array) -> void:
	var src := Node.new()
	add_child(src)
	channel_changed.connect(func(_n, _v):
		if channel(out):
			return
		for c in inputs:
			if not channel(c):
				return
		set_channel(out, src, true)
		Sfx.play("fanfare", 1.3, -6.0))


## Shared toggle (every toggle switch on a channel flips the same state).
func toggle_channel(ch: String) -> void:
	set_channel(ch, self, not channel(ch))


func _spawn_players() -> void:
	for i in 2:
		var p := Player.new()
		add_child(p)
		var side := spawn_fwd.cross(Vector3.UP).normalized()
		p.global_position = spawn + side * (-1.2 if i == 0 else 1.2) + Vector3.UP * 0.5
		p.setup(i, self)
		p.facing = spawn_fwd
		players.append(p)
	players[0].partner = players[1]
	players[1].partner = players[0]
	camera = CoopCamera.new()
	add_child(camera)
	camera.snap(spawn, spawn_fwd)
	_update_control()


func _update_control() -> void:
	for i in players.size():
		players[i].controlled = Game.coop or i == active
	if Game.coop:
		camera.targets = players.duplicate()
	else:
		camera.targets = [players[active]]


func _physics_process(delta: float) -> void:
	if not done:
		elapsed += delta
	RenderingServer.global_shader_parameter_set("player_pos_a", players[0].global_position)
	RenderingServer.global_shader_parameter_set("player_pos_b", players[1].global_position)
	for p in players:
		if p.state != "bubble" and is_out_of_bounds(p.global_position):
			on_player_fell(p)


func _process(delta: float) -> void:
	var yaw := 0.0
	var pcount := 2 if Game.coop else 1
	for i in pcount:
		yaw += Input.get_action_strength(Game.act(i, "cam_right")) - Input.get_action_strength(Game.act(i, "cam_left"))
	camera.yaw_input = clampf(yaw, -1.0, 1.0)
	if not Game.coop and Input.is_action_just_pressed(Game.act(0, "swap")) and not _paused:
		active = 1 - active
		_update_control()
		Sfx.play("pop", 1.3)
		players[active].rig.pop(0.3)
		Vfx.burst(players[active].global_position + Vector3.UP, players[active].data["light"], 10, 3.0)
		toast("Agora: %s" % players[active].name, players[active].data["color"])
	if _focus_t > 0.0:
		_focus_t -= delta
		camera.focus_weight = lerpf(camera.focus_weight, 0.55, 1.0 - exp(-4.0 * delta))
	else:
		camera.focus_weight = lerpf(camera.focus_weight, 0.0, 1.0 - exp(-3.0 * delta))
	_update_signs(delta)
	if _sea and camera:
		_sea.global_position.x = snappedf(camera.global_position.x, 20.0)
		_sea.global_position.z = snappedf(camera.global_position.z, 20.0)


## Tutorial signs pop in (elastic) when someone walks close, and shrink away
## otherwise, so the screen never fills with overlapping text.
func _update_signs(delta: float) -> void:
	for l in get_tree().get_nodes_in_group("sign_label"):
		var near := false
		for p in players:
			if p.global_position.distance_to(l.global_position) < 7.5:
				near = true
		var shown: bool = l.get_meta("shown", false)
		if near != shown:
			l.set_meta("shown", near)
			var tw: Tween = l.create_tween()
			if near:
				tw.tween_property(l, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				Sfx.play("tick", 1.6, -10.0)
			else:
				tw.tween_property(l, "scale", Vector3.ONE * 0.01, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		l.position.y += sin(Time.get_ticks_msec() * 0.003 + l.position.x) * 0.002


func toggle_pause() -> void:
	if not done:
		_set_paused(not _paused)


func _set_paused(on: bool) -> void:
	_paused = on
	get_tree().paused = on
	hud.show_pause(on)
	Sfx.play("click", 1.2 if on else 0.9)


# ----------------------------------------------------------- game logic
func channel_color(ch: String) -> Color:
	if not _channel_colors.has(ch):
		_channel_colors[ch] = CHANNEL_PALETTE[_channel_colors.size() % CHANNEL_PALETTE.size()]
	return _channel_colors[ch]


func channel(ch: String) -> bool:
	if not _channels.has(ch):
		return false
	for k in _channels[ch]:
		if _channels[ch][k]:
			return true
	return false


func set_channel(ch: String, source: Object, value: bool) -> void:
	var before := channel(ch)
	if not _channels.has(ch):
		_channels[ch] = {}
	_channels[ch][source.get_instance_id()] = value
	if channel(ch) != before:
		channel_changed.emit(ch, channel(ch))


func focus_on(pos: Vector3, dur := 1.0) -> void:
	camera.focus_override = pos
	_focus_t = dur


func toast(text: String, color := Color(1, 0.97, 0.9)) -> void:
	if hud:
		hud.toast(text, color)


func add_spark(_p: Player) -> void:
	sparks += 1
	hud.bump_sparks()
	if sparks % 50 == 0:
		Vfx.text_pop(_p.global_position + _p.up * 2.0, "%d Faíscas!" % sparks, Color(1, 0.9, 0.4), 80)
		Sfx.play("sparkle")


func add_seed(i: int, _p: Player) -> void:
	if i >= 0 and i < 3:
		seeds[i] = true
		hud.set_seed(i, true)


func spawn_spark(pos: Vector3, from = null) -> Collectible:
	var c := Collectible.new()
	add_child(c)
	c.add_to_group("spark")
	c.setup(self, "spark")
	c.global_position = pos
	if from != null:
		c.global_position = from
		c.monitoring = false
		var tw := c.create_tween()
		var mid: Vector3 = (from + pos) * 0.5 + Vector3.UP * 2.0
		tw.tween_method(func(t):
			var a: Vector3 = (from as Vector3).lerp(mid, t)
			var b: Vector3 = mid.lerp(pos, t)
			c.global_position = a.lerp(b, t), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_QUAD)
		tw.tween_interval(0.4)
		tw.tween_callback(func(): c.monitoring = true)
	return c


func on_player_hurt(p: Player) -> void:
	var lose := mini(3, sparks)
	sparks -= lose
	for i in lose:
		var a := TAU * i / maxf(lose, 1) + randf()
		var off := Vector3(cos(a), 0, sin(a)) * randf_range(1.8, 2.8)
		off = off - p.up * off.dot(p.up)
		spawn_spark(p.global_position + off + p.up * 0.8, p.global_position + p.up * 0.8)


func on_pound(p: Player, pos: Vector3, radius: float, already: Array = []) -> void:
	for n in get_tree().get_nodes_in_group("pound_target"):
		if n in already or not is_instance_valid(n):
			continue
		if (n as Node3D).global_position.distance_to(pos) < radius + 0.8:
			n.on_pound(p)


func set_checkpoint(pos: Vector3, up: Vector3) -> void:
	checkpoint = pos
	checkpoint_up = up


func respawn_point_for(p: Player) -> Vector3:
	var o: Player = p.partner
	if Game.coop and o and not o.is_busy() and o.state != "bubble":
		return o.safe_pos
	return checkpoint


func respawn_up_for(p: Player) -> Vector3:
	var o: Player = p.partner
	if Game.coop and o and not o.is_busy() and o.state != "bubble":
		return o.safe_up
	return checkpoint_up


func is_out_of_bounds(pos: Vector3) -> bool:
	return pos.y < kill_y or pos.length() > 600.0


func on_player_fell(p: Player) -> void:
	Sfx.play("fall", 1.0, -4.0)
	Juice.shake(0.15)
	p.enter_bubble()
	if not Game.coop and players.find(p) != active:
		p.pop_bubble()


func complete() -> void:
	if done:
		return
	done = true
	for p in players:
		p.celebrate()
	Sfx.stop_music()
	var seeds_n := seeds.count(true)
	Game.finish_level(Game.current_level, sparks, seeds)
	await get_tree().create_timer(2.6).timeout
	hud.show_complete({"sparks": sparks, "total": spark_total, "seeds": seeds_n, "time": elapsed,
			"has_next": Game.current_level + 1 < Game.LEVELS.size()})


func _on_next() -> void:
	if Game.current_level + 1 < Game.LEVELS.size():
		Game.play_level(Game.current_level + 1)
	else:
		Game.to_title()


# ------------------------------------------------------------ environment
func _build_environment() -> void:
	var c := {
		"zenith": Color(0.32, 0.55, 0.95), "horizon": Color(0.98, 0.82, 0.72), "ground": Color(0.62, 0.62, 0.86),
		"sun": Color(1.0, 0.94, 0.84), "ambient": Color(0.72, 0.7, 0.92), "fog": Color(0.95, 0.82, 0.8),
		"sea_top": Color(1.0, 0.97, 0.97), "sea_low": Color(0.82, 0.74, 0.95), "stars": 0.25, "clouds": 0.45,
	}
	c.merge(sky_colors, true)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = ShaderLib.get_shader("sky")
	sm.set_shader_parameter("zenith", c["zenith"])
	sm.set_shader_parameter("horizon", c["horizon"])
	sm.set_shader_parameter("ground", c["ground"])
	sm.set_shader_parameter("star_amount", c["stars"])
	sm.set_shader_parameter("cloud_cover", c["clouds"])
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = c["ambient"]
	env.ambient_light_energy = 0.62
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = c["fog"]
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.25
	env.ssao_enabled = not low_spec
	env.ssao_intensity = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, -38, 0)
	_sun.light_color = c["sun"]
	_sun.light_energy = 1.25
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_max_distance = 50.0 if low_spec else 80.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if low_spec else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(_sun)

	if not floating_world:
		_distant_mountains(c)
		return
	_sea = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	pm.subdivide_width = 70 if low_spec else 150
	pm.subdivide_depth = 70 if low_spec else 150
	_sea.mesh = pm
	var smat := ShaderMaterial.new()
	smat.shader = ShaderLib.get_shader("cloud_sea")
	smat.set_shader_parameter("top_color", c["sea_top"])
	smat.set_shader_parameter("low_color", c["sea_low"])
	smat.set_shader_parameter("far_color", c["horizon"])
	_sea.material_override = smat
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sea.position.y = kill_y - 14.0
	add_child(_sea)

	# far-away floating islets for depth and parallax
	var far_n := 7 if low_spec else 14
	for i in far_n:
		var a := TAU * i / float(far_n) + _rng.randf() * 0.3
		var d := _rng.randf_range(130.0, 230.0)
		var m := ISLAND.instantiate()
		var r := _rng.randf_range(5.0, 14.0)
		m.scale = Vector3(r, r * 0.6, r)
		m.position = Vector3(cos(a) * d, _rng.randf_range(-15.0, 25.0), sin(a) * d)
		add_child(m)
		Mats.stylize(m, 0.0)


## Ring of big soft mountains on the horizon for grounded worlds.
func _distant_mountains(c: Dictionary) -> void:
	var n := 10 if low_spec else 18
	for i in n:
		var a := TAU * i / float(n) + _rng.randf() * 0.2
		var d := _rng.randf_range(170.0, 240.0)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := _rng.randf_range(45.0, 80.0)
		cm.top_radius = r * _rng.randf_range(0.05, 0.25)
		cm.bottom_radius = r
		cm.height = _rng.randf_range(40.0, 75.0)
		cm.radial_segments = 9
		cm.rings = 2
		mi.mesh = cm
		var col: Color = (c["ground"] as Color).lerp(c["horizon"], _rng.randf_range(0.2, 0.5))
		mi.material_override = Mats.toon(col, {"rim_amount": 0.2, "spec_amount": 0.0})
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(a) * d, cm.height * 0.5 - 12.0, -70.0 + sin(a) * d)
		add_child(mi)


# --------------------------------------------------------------- builders
func _body_faces(body: Node3D, root: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	var inv := body.global_transform.affine_inverse()
	for mi in Mats._all_meshes(root):
		var xf: Transform3D = inv * (mi as MeshInstance3D).global_transform
		var faces := (mi as MeshInstance3D).mesh.get_faces()
		for v in faces:
			out.append(xf * v)
	return out


## Floating island. `pos` is the center of the walkable top.
func island(pos: Vector3, r: float, depth := -1.0, style := "meadow", grass := true) -> StaticBody3D:
	var sy := depth if depth > 0.0 else r * 0.45
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	body.global_position = pos - Vector3(0, 0.18 * sy, 0)
	var model := ISLAND.instantiate()
	model.scale = Vector3(r, sy, r)
	body.add_child(model)
	Mats.stylize(model, 0.0, style)
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.set_faces(_body_faces(body, model))
	cs.shape = sh
	body.add_child(cs)
	if grass:
		_grass_disc(pos, r, sy, int(r * r * (3.0 if low_spec else 9.0)))
		_flowers_disc(pos, r, sy, int(r * (0.5 if low_spec else 1.2)))
	return body


func _island_height(center: Vector3, r: float, sy: float, d: float) -> float:
	var k := clampf(d / (r * 1.02), 0.0, 1.0)
	var nz := sqrt(1.0 - k * k)
	return center.y + (0.12 + 0.06 * nz - 0.18) * sy


func _blade_mesh() -> ArrayMesh:
	if _blade:
		return _blade
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.07
	var h := 0.5
	var pts := [Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(-w * 0.6, h * 0.5, 0.02), Vector3(w * 0.6, h * 0.5, 0.02), Vector3(0, h, 0.06)]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0.5, 0)]
	for tri in [[0, 1, 2], [1, 3, 2], [2, 3, 4]]:
		for idx in tri:
			st.set_normal(Vector3(0, 0.3, 1).normalized())
			st.set_uv(uvs[idx])
			st.add_vertex(pts[idx])
	_blade = st.commit()
	return _blade


func _grass_mmi(xforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _blade_mesh()
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = ShaderLib.get_shader("grass")
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _grass_disc(center: Vector3, r: float, sy: float, count: int) -> void:
	var xf := []
	for i in count:
		var d := sqrt(_rng.randf()) * r * 0.86
		var a := _rng.randf() * TAU
		var p := Vector3(center.x + cos(a) * d, 0, center.z + sin(a) * d)
		p.y = _island_height(center, r, sy, d) - 0.03
		var s := _rng.randf_range(0.6, 1.4)
		xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.3), s)), p))
	_grass_mmi(xf)


func _flowers_disc(center: Vector3, r: float, sy: float, count: int) -> void:
	for i in count:
		var d := _rng.randf_range(0.45, 0.85) * r
		var a := _rng.randf() * TAU
		var p := Vector3(center.x + cos(a) * d, 0, center.z + sin(a) * d)
		p.y = _island_height(center, r, sy, d)
		flower(p)


func flower(pos: Vector3, up := Vector3.UP) -> Node3D:
	var f := FLOWER.instantiate()
	add_child(f)
	f.global_position = pos
	_orient(f, up)
	f.rotate_object_local(Vector3.UP, _rng.randf() * TAU)
	f.scale = Vector3.ONE * _rng.randf_range(1.2, 1.9)
	Mats.stylize(f, 0.0)
	var col: Color = FLOWER_COLORS[_rng.randi() % FLOWER_COLORS.size()]
	for mi in Mats._all_meshes(f):
		if String(mi.name).begins_with("Petal"):
			(mi as MeshInstance3D).set_surface_override_material(0, Mats.toon(col, {"rim_amount": 0.8}))
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return f


func _orient(n: Node3D, up: Vector3) -> void:
	if absf(up.dot(Vector3.UP)) > 0.999:
		if up.y < 0.0:
			n.global_basis = Basis(Vector3.RIGHT, PI)
		return
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := up.cross(ref).normalized()
	n.global_basis = Basis(x, up, x.cross(up))


## Solid box (stone, wood, ruins). `pos` = center of the top face.
func block(pos: Vector3, size: Vector3, style := "stone", rot_y := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	add_child(b)
	b.global_position = pos - Vector3(0, size.y * 0.5, 0)
	b.rotation.y = rot_y
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	match style:
		"wood":
			mi.material_override = Mats.toon(Color(0.88, 0.62, 0.4), {"detail_normal": Mats.N_WOOD, "detail_strength": 0.6, "detail_scale": 0.6, "noise_tint": 0.1})
		"ruins":
			mi.material_override = Mats.toon(Color(0.78, 0.74, 0.88), {"detail_normal": Mats.N_TILES, "detail_strength": 0.6, "detail_scale": 0.45, "noise_tint": 0.12})
		_:
			mi.material_override = Mats.toon(Color(0.82, 0.68, 0.6), {"detail_normal": Mats.N_STONE, "detail_strength": 0.6, "detail_scale": 0.5, "noise_tint": 0.12})
	b.add_child(mi)
	if style != "wood":
		var top := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(size.x + 0.08, 0.14, size.z + 0.08)
		top.mesh = tm
		top.position.y = size.y * 0.5
		top.material_override = Mats.toon(Color(0.52, 0.84, 0.42), {"noise_tint": 0.15, "noise_scale": 1.0})
		b.add_child(top)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	return b


func pillar(pos: Vector3, h := 4.0, r := 0.5) -> StaticBody3D:
	var b := StaticBody3D.new()
	add_child(b)
	b.global_position = pos + Vector3(0, h * 0.5, 0)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.85
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = Mats.toon(Color(0.8, 0.76, 0.9), {"detail_normal": Mats.N_STONE, "detail_strength": 0.6, "detail_scale": 0.7})
	b.add_child(mi)
	var cap := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(r * 2.6, 0.35, r * 2.6)
	cap.mesh = bm
	cap.position.y = h * 0.5
	cap.material_override = mi.material_override
	b.add_child(cap)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = h
	cs.shape = cyl
	b.add_child(cs)
	return b


func prop(scene: PackedScene, pos: Vector3, scale_f := 1.0, up := Vector3.UP, collide_r := 0.0, outline := 0.012) -> Node3D:
	var n := scene.instantiate()
	var holder: Node3D = n
	if collide_r > 0.0:
		var b := StaticBody3D.new()
		add_child(b)
		b.add_child(n)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = collide_r * scale_f
		cyl.height = 2.0 * scale_f
		cs.shape = cyl
		cs.position.y = scale_f
		b.add_child(cs)
		holder = b
	else:
		add_child(n)
	holder.global_position = pos
	_orient(holder, up)
	holder.rotate_object_local(Vector3.UP, _rng.randf() * TAU)
	n.scale = Vector3.ONE * scale_f
	Mats.stylize(n, outline)
	return holder


func tree(pos: Vector3, s := 1.4, pink := false, up := Vector3.UP) -> Node3D:
	var t := prop(TREE_PINK if pink else TREE, pos, s, up, 0.3)
	for mi in Mats._all_meshes(t):
		if String(mi.name).begins_with("Leaf"):
			var m: Material = (mi as MeshInstance3D).get_surface_override_material(0)
			if m is ShaderMaterial:
				var d: ShaderMaterial = m.duplicate()
				d.set_shader_parameter("wobble", 0.025)
				(mi as MeshInstance3D).set_surface_override_material(0, d)
	return t


func bush(pos: Vector3, s := 1.0, up := Vector3.UP) -> Node3D:
	return prop(BUSH, pos, s, up)


func rock(pos: Vector3, s := 1.0, up := Vector3.UP) -> Node3D:
	return prop(ROCK, pos, s, up, 0.6, 0.0)


func crystal(pos: Vector3, s := 1.0, up := Vector3.UP) -> Node3D:
	var c := prop(CRYSTAL, pos, s, up, 0.0, 0.0)
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 0.85, 1.0)
	l.light_energy = 0.8
	l.omni_range = 3.5 * s
	l.position.y = 0.8 * s
	c.add_child(l)
	return c


func sign_text(pos: Vector3, text: String, color := Color(1, 0.97, 0.88)) -> Label3D:
	var post := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 1.3, 0.14)
	post.mesh = bm
	post.material_override = Mats.toon(Color(0.6, 0.4, 0.28), {"detail_normal": Mats.N_WOOD, "detail_strength": 0.5, "outline": 0.02})
	add_child(post)
	post.global_position = pos + Vector3(0, 0.65, 0)
	var board := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.9, 0.55, 0.1)
	board.mesh = bb
	board.material_override = Mats.toon(Color(0.95, 0.72, 0.45), {"detail_normal": Mats.N_WOOD, "detail_strength": 0.6, "outline": 0.02})
	post.add_child(board)
	board.position.y = 0.55
	var ex := Label3D.new()
	ex.text = "!"
	ex.font_size = 72
	ex.position = Vector3(0, 0.55, 0.06)
	ex.pixel_size = 0.006
	ex.modulate = Color(0.35, 0.18, 0.12)
	post.add_child(ex)
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = Color(0.2, 0.08, 0.25)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.0085
	l.width = 900
	l.scale = Vector3.ONE * 0.01
	l.add_to_group("sign_label")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	l.global_position = pos + Vector3(0, 2.5, 0)
	return l


func spark(pos: Vector3, up := Vector3.UP) -> Collectible:
	var c := Collectible.new()
	add_child(c)
	c.add_to_group("spark")
	c.setup(self, "spark", -1, up)
	c.global_position = pos
	return c


func spark_line(a: Vector3, b: Vector3, n: int) -> void:
	for i in n:
		spark(a.lerp(b, float(i) / maxf(n - 1, 1)))


func spark_arc(a: Vector3, b: Vector3, h: float, n: int) -> void:
	for i in n:
		var t := float(i) / maxf(n - 1, 1)
		spark(a.lerp(b, t) + Vector3.UP * sin(t * PI) * h)


func spark_ring(center: Vector3, r: float, n: int, up := Vector3.UP) -> void:
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := up.cross(ref).normalized()
	var z := x.cross(up)
	for i in n:
		var a := TAU * i / n
		spark(center + (x * cos(a) + z * sin(a)) * r, up)


func star_seed(pos: Vector3, idx: int) -> Collectible:
	var c := Collectible.new()
	add_child(c)
	c.setup(self, "seed", idx)
	c.global_position = pos
	return c


func checkpoint_at(pos: Vector3, up := Vector3.UP) -> Checkpoint:
	var c := Checkpoint.new()
	add_child(c)
	c.global_position = pos
	_orient(c, up)
	c.setup(self)
	return c


func plate(pos: Vector3, ch: String, heavy := false, up := Vector3.UP) -> PressurePlate:
	var p := PressurePlate.new()
	add_child(p)
	p.global_position = pos
	_orient(p, up)
	p.setup(self, ch, heavy)
	return p


func gate(pos: Vector3, chs: Array, rot_y := 0.0, width := 4.0, height := 3.5, latch := true) -> Gate:
	var g := Gate.new()
	add_child(g)
	g.global_position = pos
	g.rotation.y = rot_y
	g.setup(self, chs, width, height, latch)
	return g


func bridge(pos: Vector3, size: Vector3, ch: String, inverted := false, rot_y := 0.0) -> Bridge:
	var b := Bridge.new()
	add_child(b)
	b.global_position = pos - Vector3(0, size.y * 0.5, 0)
	b.rotation.y = rot_y
	b.setup(self, ch, size, inverted)
	return b


func mover(pos: Vector3, size: Vector3, pts: Array, period := 4.0, ch := "", spin := 0.0, style := "wood") -> MovingPlatform:
	var m := MovingPlatform.new()
	m.position = pos - Vector3(0, size.y * 0.5, 0)
	m.setup(self, size, pts, period, ch, spin, style)
	add_child(m)
	return m


func mushroom(pos: Vector3, strength := 19.0, size := 1.4, up := Vector3.UP) -> BounceMushroom:
	var m := BounceMushroom.new()
	add_child(m)
	m.global_position = pos
	_orient(m, up)
	m.setup(self, strength, size)
	return m


func launch_ring(pos: Vector3, to: Vector3, h := 12.0, dur := 1.4, ch := "", up := Vector3.UP) -> LaunchRing:
	var r := LaunchRing.new()
	add_child(r)
	r.global_position = pos
	_orient(r, up)
	r.setup(self, to, h, dur, ch)
	return r


func rift_pair(a: Vector3, a_fwd: Vector3, b: Vector3, b_fwd: Vector3, ch_a := "", ch_b := "") -> Array:
	var ra := Rift.new()
	var rb := Rift.new()
	add_child(ra)
	add_child(rb)
	ra.global_position = a
	rb.global_position = b
	ra.look_at(a - a_fwd, Vector3.UP)
	rb.look_at(b - b_fwd, Vector3.UP)
	ra.setup(self, ch_a)
	rb.setup(self, ch_b)
	ra.other = rb
	rb.other = ra
	return [ra, rb]


func pound_switch(pos: Vector3, ch: String, mode := "toggle", dur := 6.0, up := Vector3.UP) -> PoundSwitch:
	var s := PoundSwitch.new()
	add_child(s)
	s.global_position = pos
	_orient(s, up)
	s.setup(self, ch, mode, dur)
	return s


func crate(pos: Vector3, breakable := false) -> Crate:
	var c := Crate.new()
	c.position = pos + Vector3(0, 0.5, 0)
	c.setup(self, breakable)
	add_child(c)
	return c


func urchin(pts: Array, spd := 1.6, center = null) -> Urchin:
	var u := Urchin.new()
	add_child(u)
	u.global_position = pts[0]
	u.setup(self, pts, spd, center)
	return u


func wind_fan(pos: Vector3, h := 9.0, s := 34.0) -> WindFan:
	var w := WindFan.new()
	add_child(w)
	w.global_position = pos
	w.setup(self, h, s)
	return w


func goal(pos: Vector3) -> StarBloom:
	var g := StarBloom.new()
	add_child(g)
	g.global_position = pos
	g.setup(self)
	return g


func planet(center: Vector3, r: float, style := "planet", grass := true) -> Planetoid:
	var p := Planetoid.new()
	add_child(p)
	p.global_position = center
	p.setup(self, r, style)
	if grass:
		var xf := []
		var n := int(r * r * (5.0 if low_spec else 14.0))
		for i in n:
			var d := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
			if d.length() < 0.05:
				continue
			d = d.normalized()
			var t := p.surface_xform(d, -0.02)
			var s := _rng.randf_range(0.6, 1.3)
			xf.append(Transform3D(t.basis * Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), t.origin))
		_grass_mmi(xf)
	return p


## Place a node on a planet's surface along direction `dir`.
func on_planet(p: Planetoid, dir: Vector3, extra := 0.0) -> Dictionary:
	var t := p.surface_xform(dir, extra)
	return {"pos": t.origin, "up": t.basis.y}
