extends Node
## Game feel. Everything here is local & visual: it never touches the simulation
## (hitstop lives on the entities, driven by tick counters).

const SPARK := preload("res://vfx/shaders/spark.gdshader")
const RING := preload("res://vfx/shaders/ring_fx.gdshader")
const CIRCLE := preload("res://vfx/shaders/magic_circle.gdshader")

var fx_root: Node3D
var postfx: Node                 # ui/postfx.gd
var trauma := 0.0                # 0..1, shake = trauma^2
var kick_vec := Vector3.ZERO     # camera nudge (world metres)
var fov_punch := 0.0
var chroma := 0.0
var screen_flash := 0.0
var _spark_mat: ShaderMaterial
var _star_mesh: QuadMesh


func _ready() -> void:
	_spark_mat = ShaderMaterial.new()
	_spark_mat.shader = SPARK
	_star_mesh = QuadMesh.new()
	_star_mesh.size = Vector2(0.5, 0.5)
	_star_mesh.material = _spark_mat


func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 1.6)
	kick_vec = kick_vec.lerp(Vector3.ZERO, clampf(delta * 11.0, 0.0, 1.0))
	fov_punch = lerpf(fov_punch, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	chroma = maxf(0.0, chroma - delta * 4.0)
	screen_flash = maxf(0.0, screen_flash - delta * 6.0)
	if postfx != null:
		postfx.set_pulse(chroma, screen_flash)


# ---------------------------------------------------------------- primitives

func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)
	Game.log_event("shake", {"a": amount})


func kick(dir: Vector3, strength: float) -> void:
	kick_vec += dir.normalized() * strength


func rumble(weak: float, strong: float, ms: int) -> void:
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, weak, strong, ms / 1000.0)


func _add(n: Node) -> void:
	if fx_root != null and is_instance_valid(fx_root):
		fx_root.add_child(n)
	else:
		n.queue_free()


# -------------------------------------------------------------------- bursts

func sparks(pos: Vector3, dir: Vector3, color: Color, count: int = 10, speed: float = 6.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = 0.38
	p.mesh = _star_mesh
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	p.damping_min = 4.0
	p.damping_max = 8.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.color = color
	p.emitting = true
	_add(p)
	p.global_position = pos
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func ring(pos: Vector3, color: Color, size: float = 1.6, life: float = 0.35, ground: bool = false) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = RING
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("facing_camera", not ground)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if ground:
		m.rotation_degrees = Vector3(-90, 0, 0)
	_add(m)
	m.global_position = pos
	var tw := m.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, life)
	tw.tween_callback(m.queue_free)


func flash_light(pos: Vector3, color: Color, energy: float = 3.0, life: float = 0.12) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 4.5
	l.shadow_enabled = false
	_add(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life)
	tw.tween_callback(l.queue_free)


func dust(pos: Vector3, count: int = 6, color: Color = Color(0.85, 0.8, 0.65, 0.8)) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = count
	p.lifetime = 0.45
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.28)
	var m := ShaderMaterial.new()
	m.shader = RING
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("progress", 0.35)
	m.set_shader_parameter("width", 0.9)
	q.material = m
	p.mesh = q
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.emitting = true
	_add(p)
	p.global_position = pos + Vector3(0, 0.05, 0)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func damage_number(pos: Vector3, amount: int, crit: bool = false, color: Color = Color(1, 1, 1, 1)) -> void:
	var l := Label3D.new()
	l.text = str(amount) + ("!" if crit else "")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.012 if not crit else 0.017
	l.font_size = 48
	l.outline_size = 12
	l.outline_modulate = Color(0.1, 0.05, 0.15, 1)
	l.modulate = Color(1.0, 0.86, 0.3) if crit else color
	l.render_priority = 10
	_add(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 1.7
	var end := pos + Vector3(randf_range(-0.5, 0.5), 1.1, 0.1)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", end, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


func alert(pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = "!"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.02
	l.font_size = 48
	l.outline_size = 12
	l.modulate = Color(1, 0.9, 0.3)
	_add(l)
	l.global_position = pos
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", pos.y + 0.4, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.2).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


func magic_circle(pos: Vector3, color: Color, life: float = 0.7, size: float = 2.6) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = CIRCLE
	mat.set_shader_parameter("color", color)
	m.material_override = mat
	m.rotation_degrees = Vector3(-90, 0, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(m)
	m.global_position = pos + Vector3(0, 0.03, 0)
	m.scale = Vector3.ONE * 0.2
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): mat.set_shader_parameter("t", v), 0.0, life * 3.0, life)
	tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.2).set_delay(life - 0.2)
	tw.chain().tween_callback(m.queue_free)


# ---------------------------------------------------------------- composites

## A confirmed melee/spell hit. power: 0.2 light .. 1.0 finisher.
func hit(pos: Vector3, dir: Vector3, color: Color, power: float, shake_amt: float) -> void:
	Game.log_event("hit_fx", {"p": power})
	shake(shake_amt)
	kick(dir, 0.10 + 0.22 * power)
	sparks(pos, dir + Vector3.UP * 0.4, color, int(8 + 10 * power), 5.0 + 5.0 * power)
	ring(pos, color.lerp(Color.WHITE, 0.5), 1.1 + power * 1.6, 0.28)
	flash_light(pos + Vector3(0, 0.4, 0.4), color, 2.5 + power * 3.0)
	rumble(0.3 * power, 0.6 * power + 0.15, 90)
	if power >= 0.7:
		fov_punch = -2.5
		chroma = 1.0
		screen_flash = 0.5


func death_burst(pos: Vector3, color: Color) -> void:
	shake(0.35)
	sparks(pos + Vector3(0, 0.5, 0), Vector3.UP, color, 22, 7.5)
	ring(pos + Vector3(0, 0.4, 0), color, 2.6, 0.5)
	ring(pos + Vector3(0, 0.05, 0), color, 3.2, 0.6, true)
	flash_light(pos + Vector3(0, 0.6, 0.4), color, 5.0, 0.25)
	chroma = 0.7
