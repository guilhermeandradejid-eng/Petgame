class_name Javelin
extends Node3D
## Thrown spear: slim hexagonal shaft with a leaf head (hollow shell), pierces everything it meets.

const SHELL := preload("res://vfx/shaders/shell_fx.gdshader")

var special: SpecialData
var dir := Vector3.RIGHT
var owner_peer := 1
var age := 0
var hit_set: Array = []
var _trail: WeaponTrail


func _ready() -> void:
	var m := MeshInstance3D.new()
	m.mesh = IceLance.build_mesh(1.1, 0.9, 0.09)
	var mat := ShaderMaterial.new()
	mat.shader = SHELL
	mat.set_shader_parameter("color", special.color)
	mat.set_shader_parameter("stripes", 3.0)
	mat.set_shader_parameter("rim_amt", 1.0)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	if dir.length() > 0.01:
		look_at(global_position + dir, Vector3.UP)
	_trail = WeaponTrail.new()
	_trail.color = special.color
	Juice.fx_root.add_child(_trail)
	Sfx.play("lance", -2.0, 0.8)


func _physics_process(_delta: float) -> void:
	age += 1
	global_position += dir * 22.0 / Game.TICK_RATE
	_trail.add_sample(global_position + Vector3(0, 0.05, 0), global_position + Vector3(0, -0.05, 0) - dir * 1.4)
	if owner_peer == multiplayer.get_unique_id():
		for e in get_tree().get_nodes_in_group("enemies"):
			if e in hit_set or e.is_dead():
				continue
			if Combat.hit_test(global_position, special.radius_px * Game.PX, e, e.data.radius_m):
				hit_set.append(e)
				Combat.deal(e, owner_peer, global_position, dir, {
					"dmg": special.damage, "kb": special.knockback, "launch": special.launch_height_px, "hs": special.hitstop,
					"sh": special.shake, "col": special.color, "sfx": "hit_heavy", "sp": 2.0, "id": special.id, "seed": age})
	if age > 46 or absf(global_position.x) > Game.ARENA_HALF + 2 or absf(global_position.z) > Game.ARENA_HALF + 2:
		Juice.sparks(global_position, -dir + Vector3.UP, special.color, 10, 5.0)
		Juice.ring(global_position, special.color, 1.4, 0.3)
		_trail.done = true
		queue_free()
