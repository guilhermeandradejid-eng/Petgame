class_name Comet
extends Node3D
## "Comet": a ground marker warns where it will land, then a flaming star falls out of the sky,
## craters the floor and bursts into embers.

const SHELL := preload("res://vfx/shaders/shell_fx.gdshader")
const FALL_DELAY := 24
const FALL_TICKS := 11

var spell: SpellData
var owner_peer := 1
var target := Vector3.ZERO
var age := 0
var _star: MeshInstance3D
var _mat: ShaderMaterial
var _tail: CPUParticles3D
var _from := Vector3.ZERO
var _impacted := false


func _ready() -> void:
	target.y = 0.0
	global_position = target
	_from = target + Vector3(-5.0, 15.0, -3.5)
	Juice.telegraph(target, spell.radius_m, spell.color, float(FALL_DELAY) / 60.0)
	_star = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.62
	sm.height = 1.24
	sm.radial_segments = 14
	sm.rings = 8
	_star.mesh = sm
	_mat = ShaderMaterial.new()
	_mat.shader = SHELL
	_mat.set_shader_parameter("color", spell.color)
	_mat.set_shader_parameter("stripes", 5.0)
	_mat.set_shader_parameter("speed", 10.0)
	_mat.set_shader_parameter("rim_amt", 1.0)
	_mat.set_shader_parameter("fresnel_pow", 1.4)
	_star.material_override = _mat
	_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_star.visible = false
	add_child(_star)
	_tail = CPUParticles3D.new()
	_tail.amount = 40
	_tail.lifetime = 0.35
	_tail.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var qm := ShaderMaterial.new()
	qm.shader = preload("res://vfx/shaders/spark.gdshader")
	q.material = qm
	_tail.mesh = q
	_tail.direction = Vector3(0, 1, 0)
	_tail.spread = 60.0
	_tail.initial_velocity_min = 0.5
	_tail.initial_velocity_max = 2.0
	_tail.color = spell.color
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_tail.scale_amount_curve = curve
	_tail.emitting = false
	_star.add_child(_tail)
	Sfx.play("comet_call", -2.0)


func _physics_process(_delta: float) -> void:
	age += 1
	if age < FALL_DELAY:
		return
	var t := float(age - FALL_DELAY) / float(FALL_TICKS)
	if not _impacted:
		_star.visible = true
		_tail.emitting = true
		_star.global_position = _from.lerp(target + Vector3(0, 0.4, 0), t * t)
		_mat.set_shader_parameter("t", age / 60.0)
		if t >= 1.0:
			_impact()
	elif age > FALL_DELAY + FALL_TICKS + 20:
		queue_free()


func _impact() -> void:
	_impacted = true
	_star.visible = false
	_tail.emitting = false
	Sfx.play("quake", 0.0, 0.7)
	Sfx.play("fire_hit", -2.0, 0.7)
	Juice.crater(target, spell.color, spell.radius_m)
	Juice.shake(0.5)
	Juice.fov_punch = -2.0
	Juice.sparks(target + Vector3(0, 0.3, 0), Vector3.UP, spell.color, 14, 6.0)
	if owner_peer == multiplayer.get_unique_id():
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_dead():
				continue
			var d: Vector3 = e.global_position - target
			d.y = 0.0
			if d.length() <= spell.radius_m + e.data.radius_m:
				var dir := d.normalized() if d.length() > 0.05 else Vector3.RIGHT
				Combat.deal(e, owner_peer, target, dir, {
					"dmg": spell.damage, "kb": spell.knockback, "launch": spell.launch_height_px, "hs": spell.hitstop,
					"sh": spell.shake, "col": spell.color, "sfx": "hit_heavy", "sp": 4.0, "id": spell.id, "seed": 5})
