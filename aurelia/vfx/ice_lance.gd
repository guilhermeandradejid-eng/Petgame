class_name IceLance
extends Node3D
## "Ice Lance": a hexagonal crystal spear with a hollow, fresnel-lit shell (no solid core, so
## additive blending can never blow it out), frost motes behind it, and a shatter on impact.

const SHELL := preload("res://vfx/shaders/ice_shell.gdshader")

var spell: SpellData
var dir := Vector3.RIGHT
var owner_peer := 1
var age := 0
var hit_set: Array = []
var _mat: ShaderMaterial
var _mesh: MeshInstance3D
var _motes: CPUParticles3D


static func build_mesh(len_front := 0.85, len_back := 0.4, r := 0.17) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0
		ring.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	var tip := Vector3(0, 0, len_front)
	var tail := Vector3(0, 0, -len_back)
	for i in 6:
		var a := ring[i]
		var b := ring[(i + 1) % 6]
		st.set_uv(Vector2(float(i) / 6.0, 0.0)); st.add_vertex(a)
		st.set_uv(Vector2(float(i + 1) / 6.0, 0.0)); st.add_vertex(b)
		st.set_uv(Vector2(float(i) / 6.0 + 0.08, 1.0)); st.add_vertex(tip)
		st.set_uv(Vector2(float(i + 1) / 6.0, 0.0)); st.add_vertex(b)
		st.set_uv(Vector2(float(i) / 6.0, 0.0)); st.add_vertex(a)
		st.set_uv(Vector2(float(i) / 6.0 + 0.08, 1.0)); st.add_vertex(tail)
	st.generate_normals()
	return st.commit()


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = build_mesh()
	_mat = ShaderMaterial.new()
	_mat.shader = SHELL
	_mat.set_shader_parameter("color", spell.color)
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	scale = Vector3.ONE * 0.2
	create_tween().tween_property(self, "scale", Vector3.ONE, 4.0 / 60.0).set_trans(Tween.TRANS_BACK)
	_motes = CPUParticles3D.new()
	_motes.amount = 24
	_motes.lifetime = 0.5
	_motes.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://vfx/shaders/spark.gdshader")
	q.material = sm
	_motes.mesh = q
	_motes.direction = Vector3(0, 1, 0)
	_motes.spread = 180.0
	_motes.initial_velocity_min = 0.2
	_motes.initial_velocity_max = 0.9
	_motes.gravity = Vector3(0, -1.2, 0)
	_motes.color = spell.color
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_motes.scale_amount_curve = curve
	add_child(_motes)
	if dir.length() > 0.01:
		look_at(global_position + dir, Vector3.UP)
	Sfx.play("lance", -3.0)


func _physics_process(_delta: float) -> void:
	age += 1
	global_position += dir * spell.speed / Game.TICK_RATE
	_mat.set_shader_parameter("t", age / 60.0)
	if owner_peer == multiplayer.get_unique_id():
		_check_hits()
	if age >= spell.life_ticks or absf(global_position.x) > Game.ARENA_HALF + 2 or absf(global_position.z) > Game.ARENA_HALF + 2:
		shatter()


func _check_hits() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in hit_set or e.is_dead():
			continue
		if Combat.hit_test(global_position, spell.radius_px * Game.PX, e, e.data.radius_m):
			hit_set.append(e)
			Combat.deal(e, owner_peer, global_position, dir, {
				"dmg": spell.damage, "kb": spell.knockback, "launch": spell.launch_height_px, "hs": spell.hitstop,
				"sh": spell.shake, "col": spell.color, "sfx": "ice_shatter", "sp": 3.0, "id": spell.id, "seed": age * 31})
			_shard_burst()


func _shard_burst() -> void:
	for i in 8:
		var s := MeshInstance3D.new()
		s.mesh = build_mesh(0.28, 0.1, 0.07)
		var m := ShaderMaterial.new()
		m.shader = SHELL
		m.set_shader_parameter("color", spell.color)
		s.material_override = m
		Juice._add(s)
		s.global_position = global_position
		var v := Vector3(randf_range(-1, 1), randf_range(0.2, 1.4), randf_range(-1, 1)).normalized() * randf_range(3.0, 6.0)
		s.look_at(s.global_position + v, Vector3.UP)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "global_position", s.global_position + v * 0.45 + Vector3(0, -0.4, 0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(f: float): m.set_shader_parameter("fade", f), 1.0, 0.0, 0.5)
		tw.chain().tween_callback(s.queue_free)
	Juice.ring(global_position, spell.color, 2.0, 0.4)
	Juice.ring(Vector3(global_position.x, 0.03, global_position.z), spell.color, 2.4, 0.5, true)


func shatter() -> void:
	if age < spell.life_ticks:
		_shard_burst()
	else:
		Juice.sparks(global_position, Vector3.UP, spell.color, 6, 3.0)
	queue_free()
