class_name RingOfFire
extends Node3D
## "Ring of Fire": a hollow torus of flame that sweeps outward from the caster, with a ring of
## rising embers. Enemies caught on the sweeping band are launched.

const SHELL := preload("res://vfx/shaders/shell_fx.gdshader")

var spell: SpellData
var owner_peer := 1
var age := 0
var hit_set: Array = []
var _mat: ShaderMaterial
var _torus: MeshInstance3D
var _embers: CPUParticles3D
var _light: OmniLight3D


func _ready() -> void:
	_torus = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0          # unit ring, scaled by the expanding radius
	tm.rings = 28
	tm.ring_segments = 10
	_torus.mesh = tm
	_mat = ShaderMaterial.new()
	_mat.shader = SHELL
	_mat.set_shader_parameter("color", spell.color)
	_mat.set_shader_parameter("stripes", 14.0)
	_mat.set_shader_parameter("twist", 8.0)
	_mat.set_shader_parameter("speed", -9.0)
	_mat.set_shader_parameter("stripe_amt", 0.9)
	_mat.set_shader_parameter("rim_amt", 0.7)
	_torus.material_override = _mat
	_torus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_torus)
	_embers = CPUParticles3D.new()
	_embers.amount = 40
	_embers.lifetime = 0.6
	_embers.local_coords = false
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_embers.emission_ring_axis = Vector3(0, 1, 0)
	_embers.emission_ring_height = 0.1
	_embers.emission_ring_radius = 1.0
	_embers.emission_ring_inner_radius = 0.85
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://vfx/shaders/spark.gdshader")
	q.material = sm
	_embers.mesh = q
	_embers.direction = Vector3(0, 1, 0)
	_embers.spread = 20.0
	_embers.initial_velocity_min = 1.5
	_embers.initial_velocity_max = 3.2
	_embers.gravity = Vector3(0, 1.5, 0)
	_embers.color = spell.color
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_embers.scale_amount_curve = curve
	add_child(_embers)
	_light = OmniLight3D.new()
	_light.light_color = spell.color
	_light.omni_range = 7.0
	_light.light_energy = 1.2
	_light.position.y = 0.5
	add_child(_light)
	position.y = 0.35
	Sfx.play("fire_ring", -1.0)
	Juice.shake(0.15)


func _radius(t: float) -> float:
	return lerpf(0.6, spell.radius_m, 1.0 - pow(1.0 - t, 2.5))


func _physics_process(_delta: float) -> void:
	age += 1
	var t := clampf(float(age) / float(spell.life_ticks), 0.0, 1.0)
	var r := _radius(t)
	_torus.scale = Vector3(r, r * 0.55, r)
	_embers.emission_ring_radius = r
	_light.light_energy = 1.2 * (1.0 - t)
	_mat.set_shader_parameter("t", age / 60.0)
	_mat.set_shader_parameter("fade", 1.0 - smoothstep(0.7, 1.0, t))
	if owner_peer == multiplayer.get_unique_id():
		for e in get_tree().get_nodes_in_group("enemies"):
			if e in hit_set or e.is_dead():
				continue
			var d: Vector3 = e.global_position - global_position
			d.y = 0.0
			if absf(d.length() - r) < 0.9 + e.data.radius_m:
				hit_set.append(e)
				var dir := d.normalized() if d.length() > 0.05 else Vector3.RIGHT
				Combat.deal(e, owner_peer, global_position, dir, {
					"dmg": spell.damage, "kb": spell.knockback, "launch": spell.launch_height_px, "hs": spell.hitstop,
					"sh": spell.shake, "col": spell.color, "sfx": "fire_hit", "sp": 3.0, "id": spell.id, "seed": age * 17})
	if age >= spell.life_ticks:
		_embers.emitting = false
		queue_free()
