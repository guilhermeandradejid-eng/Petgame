class_name BattleArena
extends Node3D
## Visual barrier of an encounter: glowing floor ring + a hollow wall of light + drifting motes.
## Purely cosmetic; the real confinement is Game.clamp_to_arena().

const GROUND := preload("res://vfx/shaders/arena_ring.gdshader")
const SHELL := preload("res://vfx/shaders/shell_fx.gdshader")

var radius := 5.4
var color := Color(1.0, 0.82, 0.4)
var _ground_mat: ShaderMaterial
var _wall_mat: ShaderMaterial
var _t := 0.0
var _closing := false


func _ready() -> void:
	var g := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.08, radius * 2.08)
	g.mesh = q
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = GROUND
	_ground_mat.set_shader_parameter("color", color)
	g.material_override = _ground_mat
	g.rotation_degrees = Vector3(-90, 0, 0)
	g.position.y = 0.04
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	var w := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 2.6
	cm.radial_segments = 64
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	w.mesh = cm
	_wall_mat = ShaderMaterial.new()
	_wall_mat.shader = SHELL
	_wall_mat.set_shader_parameter("color", color)
	_wall_mat.set_shader_parameter("stripes", 48.0)
	_wall_mat.set_shader_parameter("twist", 0.0)
	_wall_mat.set_shader_parameter("speed", 1.2)
	_wall_mat.set_shader_parameter("stripe_amt", 0.28)
	_wall_mat.set_shader_parameter("rim_amt", 0.35)
	_wall_mat.set_shader_parameter("base_alpha", 0.0)
	_wall_mat.set_shader_parameter("v_fade_bottom", 0.0)
	_wall_mat.set_shader_parameter("v_fade", 1.0)
	w.material_override = _wall_mat
	w.position.y = 1.3
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 2.2
	p.preprocess = 2.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3(0, 1, 0)
	p.emission_ring_radius = radius
	p.emission_ring_inner_radius = radius - 0.2
	p.emission_ring_height = 0.1
	p.direction = Vector3(0, 1, 0)
	p.spread = 10.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.1
	p.gravity = Vector3.ZERO
	var sq := QuadMesh.new()
	sq.size = Vector2(0.16, 0.16)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://vfx/shaders/spark.gdshader")
	sq.material = sm
	p.mesh = sq
	p.color = color
	add_child(p)
	scale = Vector3(0.2, 1.0, 0.2)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	_ground_mat.set_shader_parameter("t", _t)
	_wall_mat.set_shader_parameter("t", _t)


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float):
		_ground_mat.set_shader_parameter("fade", v)
		_wall_mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.6)
	tw.tween_property(self, "scale", Vector3(1.08, 1.0, 1.08), 0.6)
	tw.chain().tween_callback(queue_free)
