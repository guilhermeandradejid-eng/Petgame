class_name Rift
extends Area3D
## One end of a dimensional rift. Two rifts are linked; stepping into an
## open rift pops you out of the other one with a flash and a swirl.

const SHADER := preload("res://shaders/portal.gdshader")

var level: Node
var other: Rift
var channel := ""
var _disc: MeshInstance3D
var _mat: ShaderMaterial
var _open := 1.0
var _cool := {}
var _light: OmniLight3D


func setup(lvl: Node, ch := "") -> void:
	level = lvl
	channel = ch
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	cs.shape = sh
	cs.position.y = 1.3
	add_child(cs)
	_disc = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 3.0)
	_disc.mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_disc.material_override = _mat
	_disc.position.y = 1.4
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.4, 1.0)
	_light.omni_range = 5.0
	_light.position.y = 1.4
	add_child(_light)
	# floating rock shards orbiting the rift
	for i in 5:
		var r := MeshInstance3D.new()
		var bm := PrismMesh.new()
		bm.size = Vector3(0.25, 0.4, 0.25)
		r.mesh = bm
		r.material_override = Mats.glow(Color(0.7, 0.5, 1.0), 1.2)
		r.set_meta("a", i * TAU / 5.0)
		r.name = "Shard%d" % i
		add_child(r)
	body_entered.connect(_on_body)


func is_open() -> bool:
	return channel == "" or level.channel(channel)


func _process(delta: float) -> void:
	_open = move_toward(_open, 1.0 if is_open() else 0.12, delta * 2.0)
	_mat.set_shader_parameter("open", _open)
	_light.light_energy = 1.8 * _open
	var t := Time.get_ticks_msec() / 1000.0
	for c in get_children():
		if c.has_meta("a"):
			var a: float = c.get_meta("a") + t * 1.3
			c.position = Vector3(cos(a) * 1.7, 1.4 + sin(a * 2.0) * 0.4, sin(a) * 1.7) * Vector3(_open * 0.6 + 0.4, 1, _open * 0.6 + 0.4)
			c.rotation = Vector3(t * 2.0, a, 0)
	for k in _cool.keys():
		_cool[k] -= delta
		if _cool[k] <= 0.0:
			_cool.erase(k)


func _on_body(b: Node) -> void:
	if not (b is Player) or b.is_busy() or _cool.has(b) or other == null or not is_open():
		return
	other._cool[b] = 1.2
	_cool[b] = 1.2
	b.drop_carry()
	var exit_pos := other.global_position + other.global_basis.z * 1.8 + other.global_basis.y * 0.2
	Vfx.burst(b.global_position + b.up * 0.6, Color(0.7, 0.4, 1.0), 20, 6.0)
	b.global_position = exit_pos
	b.velocity = other.global_basis.z * 6.0 + other.global_basis.y * 6.0
	b.facing = other.global_basis.z
	b.rig.pop(0.4)
	Vfx.burst(exit_pos + b.up * 0.6, Color(0.3, 0.95, 1.0), 20, 6.0)
	Vfx.ring(other.global_position + other.global_basis.y * 0.1, other.global_basis.y, Color(0.6, 0.4, 1.0), 2.5)
	Vfx.flash(Color(0.75, 0.55, 1.0, 0.35))
	Sfx.play("portal", 1.0)
	Juice.shake(0.15)
