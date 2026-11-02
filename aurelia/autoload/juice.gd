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
	speed_amt = maxf(0.0, speed_amt - delta * 3.0)
	hurt_amt = maxf(0.0, hurt_amt - delta * 2.4)
	if postfx != null:
		postfx.set_pulse(chroma, screen_flash, speed_amt, hurt_amt)


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
	size *= 0.75
	color.a = 0.6
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

## A confirmed melee/spell hit. power: 0.2 light .. 1.0 finisher. Kept deliberately small: a few
## sparks and a little shake; only heavy hits get a ring / camera punch.
func hit(pos: Vector3, dir: Vector3, color: Color, power: float, shake_amt: float) -> void:
	Game.log_event("hit_fx", {"p": power})
	shake(shake_amt * 0.45)
	kick(dir, 0.03 + 0.08 * power)
	sparks(pos, dir + Vector3.UP * 0.4, color, int(3 + 5 * power), 3.0 + 2.5 * power)
	rumble(0.2 * power, 0.45 * power + 0.1, 70)
	if power >= 0.7:
		ring(pos, color.lerp(Color.WHITE, 0.5), 0.9 + power * 0.7, 0.22)
		fov_punch = -1.5


func death_burst(pos: Vector3, color: Color) -> void:
	shake(0.15)
	sparks(pos + Vector3(0, 0.5, 0), Vector3.UP, color, 9, 4.5)
	ring(pos + Vector3(0, 0.05, 0), color, 1.8, 0.4, true)


# ============================================================ round-2 juice

const SLASH := preload("res://vfx/shaders/slash_arc.gdshader")
const SHELL := preload("res://vfx/shaders/shell_fx.gdshader")
const TELE := preload("res://vfx/shaders/telegraph.gdshader")
const BLOB := preload("res://vfx/shaders/blob_shadow.gdshader")

var speed_amt := 0.0
var hurt_amt := 0.0
var battle_zoom := 0.0       # camera reads this (BattleManager sets the target, Juice smooths)


func speed_lines(a: float) -> void:
	speed_amt = maxf(speed_amt, a)


func hurt_flash() -> void:
	hurt_amt = 1.0


func popup(pos: Vector3, text: String, color: Color = Color.WHITE) -> void:
	pos.y -= 0.35
	if not (text.begins_with("LEVEL")):
		return          # weapon / technique names live in the HUD now
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.011
	l.font_size = 40
	l.outline_size = 12
	l.outline_modulate = Color(0.08, 0.05, 0.14, 1)
	l.modulate = color
	l.render_priority = 12
	_add(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 0.3
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", pos.y + 0.7, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.85)
	tw.chain().tween_callback(l.queue_free)


## Crescent smear on the contact frame. idx = combo index (0,1,2).
func slash_arc(pos: Vector3, facing: float, idx: int, color: Color, weapon_key: String = "sword") -> void:
	if true:
		return          # replaced by a thin weapon trail (too much effect otherwise)
	var a0 := 2.3
	var a1 := -0.5
	var radius := 0.8
	var thick := 0.17
	var size := 3.2
	match weapon_key:
		"sword":
			match idx:
				0: a0 = 2.4; a1 = -0.6
				1: a0 = -0.9; a1 = 1.9
				_: a0 = 2.9; a1 = -1.1; radius = 0.95; thick = 0.24
		"axe":
			radius = 0.95; thick = 0.24
			match idx:
				0: a0 = 2.6; a1 = -0.8
				1: a0 = -1.0; a1 = 2.2
				_: a0 = 3.1; a1 = -1.4; radius = 1.05; thick = 0.3
		"spear":
			if idx < 2:
				thrust_streak(pos + Vector3(0, 0.85, 0.2), facing, color, 2.2)
				return
			a0 = 1.5; a1 = -0.9; radius = 1.0; thick = 0.3
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = SLASH
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("a0", a0)
	mat.set_shader_parameter("a1", a1)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("thickness", thick)
	mat.set_shader_parameter("flip", facing)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(m)
	m.global_position = pos + Vector3(facing * 0.7, 0.85, 0.35)
	var tw := m.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.25, 0.13)
	tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.14)
	tw.tween_callback(m.queue_free)


## Tiny random claw-mark flash where a hit lands.
func hit_slash(pos: Vector3, dir: Vector3, color: Color, power: float) -> void:
	if true:
		return
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5) * (0.7 + power * 0.7)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = SLASH
	var a := randf_range(-0.6, 0.6) + (0.0 if dir.x >= 0.0 else PI)
	mat.set_shader_parameter("color", color.lerp(Color.WHITE, 0.55))
	mat.set_shader_parameter("a0", a + 1.0)
	mat.set_shader_parameter("a1", a - 1.0)
	mat.set_shader_parameter("radius", 0.75)
	mat.set_shader_parameter("thickness", 0.22)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(m)
	m.global_position = pos
	var tw := m.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.25, 0.07)
	tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.1)
	tw.tween_callback(m.queue_free)


func _shell_mat(color: Color, stripes: float, twist: float, speed: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHELL
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("stripes", stripes)
	m.set_shader_parameter("twist", twist)
	m.set_shader_parameter("speed", speed)
	return m


## Whirlwind / Hurricane Axe: two nested open cones of wind that spin around the hero.
func cyclone(parent: Node3D, color: Color, duration: float, radius: float) -> Node3D:
	var root := Node3D.new()
	root.position.y = 0.05
	parent.add_child(root)
	var mats: Array = []
	for i in 1:
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius * (1.0 - 0.18 * i)
		cm.bottom_radius = radius * (0.45 - 0.1 * i)
		cm.height = 1.5 - 0.3 * i
		cm.radial_segments = 28
		cm.rings = 2
		cm.cap_top = false
		cm.cap_bottom = false
		m.mesh = cm
		var mat := _shell_mat(color, 9.0 - 2.0 * i, 5.0, 16.0 + 6.0 * i)
		mat.set_shader_parameter("v_fade", 0.5)
		mat.set_shader_parameter("rim_amt", 0.7)
		mat.set_shader_parameter("stripe_amt", 0.8)
		mat.set_shader_parameter("base_alpha", 0.02)
		m.material_override = mat
		m.position.y = cm.height * 0.5
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)
		mats.append(mat)
		var spin := m.create_tween()
		spin.tween_property(m, "rotation_degrees:y", (720.0 if i == 0 else -900.0), duration + 0.15)
	# three spinning blade crescents lying flat at hip height: reads as a real whirl of steel
	var blades := Node3D.new()
	blades.position.y = 0.75
	root.add_child(blades)
	for i in 0:
		var bm := MeshInstance3D.new()
		var bq := QuadMesh.new()
		bq.size = Vector2(radius * 2.5, radius * 2.5)
		bm.mesh = bq
		var sm := ShaderMaterial.new()
		sm.shader = SLASH
		sm.set_shader_parameter("billboard", false)
		sm.set_shader_parameter("color", color.lerp(Color.WHITE, 0.4))
		sm.set_shader_parameter("a0", 0.0)
		sm.set_shader_parameter("a1", 2.0)
		sm.set_shader_parameter("radius", 0.92)
		sm.set_shader_parameter("thickness", 0.26)
		sm.set_shader_parameter("progress", 1.3)
		bm.material_override = sm
		bm.rotation_degrees = Vector3(-90, i * 120.0, 0)
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blades.add_child(bm)
		mats.append(sm)
	var bspin := blades.create_tween()
	bspin.tween_property(blades, "rotation_degrees:y", -1080.0, duration + 0.15)
	root.scale = Vector3(0.3, 0.3, 0.3)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(duration - 0.2, 0.01))
	tw.tween_method(func(v: float):
		for mt in mats:
			mt.set_shader_parameter("fade", v), 1.0, 0.0, 0.15)
	tw.tween_callback(root.queue_free)
	# leaves/dust flung outward
	return root


## Meteor Dive: a fiery shell wraps the hero through the leap.
func meteor_aura(parent: Node3D, color: Color, duration: float) -> Node3D:
	var root := Node3D.new()
	root.position.y = 0.8
	parent.add_child(root)
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.8
	sm.height = 1.9
	sm.radial_segments = 16
	sm.rings = 8
	m.mesh = sm
	var mat := _shell_mat(color, 6.0, 6.0, 20.0)
	mat.set_shader_parameter("fresnel_pow", 1.5)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	var p := CPUParticles3D.new()
	p.amount = 36
	p.lifetime = 0.4
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	q.material = _spark_mat
	p.mesh = q
	p.color = color
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	root.add_child(p)
	root.scale = Vector3.ONE * 0.4
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(maxf(duration - 0.12, 0.01))
	tw.tween_callback(root.queue_free)
	return root


func thrust_streak(pos: Vector3, facing: float, color: Color, length: float) -> void:
	var m := MeshInstance3D.new()
	m.mesh = IceLance.build_mesh(1.4, 0.15, 0.07)
	var mat := _shell_mat(color, 3.0, 0.0, 0.0)
	mat.set_shader_parameter("rim_amt", 1.0)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(m)
	m.global_position = pos + Vector3(facing * 0.3, 0.05, 0.1)
	m.look_at(m.global_position + Vector3(facing, 0, 0), Vector3.UP)
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "global_position:x", m.global_position.x + facing * length, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.14)
	tw.chain().tween_callback(m.queue_free)
	sparks(pos + Vector3(facing * length * 0.8, 0, 0), Vector3(facing, 0.2, 0), color, 4, 4.0)


## Ground crater: scorch mark, expanding hollow rings, flung rocks, embers.
func crater(pos: Vector3, color: Color, radius: float) -> void:
	ring(Vector3(pos.x, 0.05, pos.z), color, radius * 2.0, 0.5, true)
	sparks(pos + Vector3(0, 0.2, 0), Vector3.UP, color, 8, 5.0)
	rock_burst(pos, color, 4)
	dust(pos, 6, Color(0.7, 0.62, 0.5, 0.8))
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.4, radius * 2.0)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = BLOB
	mat.set_shader_parameter("strength", 0.65)
	m.material_override = mat
	m.rotation_degrees = Vector3(-90, 0, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(m)
	m.global_position = Vector3(pos.x, 0.025, pos.z)
	var tw := m.create_tween()
	tw.tween_interval(1.4)
	tw.tween_method(func(v: float): mat.set_shader_parameter("strength", v), 0.65, 0.0, 1.2)
	tw.tween_callback(m.queue_free)


func rock_burst(pos: Vector3, color: Color, n: int) -> void:
	for i in n:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		var s := randf_range(0.1, 0.22)
		b.size = Vector3(s, s * 0.8, s)
		m.mesh = b
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.36, 0.3, 0.28).lerp(color, 0.15)
		mt.roughness = 1.0
		m.material_override = mt
		_add(m)
		var p0 := pos + Vector3(randf_range(-0.4, 0.4), 0.1, randf_range(-0.3, 0.3))
		m.global_position = p0
		var v := Vector3(randf_range(-2.5, 2.5), randf_range(4.0, 7.5), randf_range(-1.5, 1.5))
		var spin := Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var tw := m.create_tween()
		tw.tween_method(func(t: float):
			m.global_position = p0 + v * t + Vector3(0, -9.0 * t * t * 0.5 * 2.0, 0)
			m.rotation = spin * t
			if m.global_position.y < 0.05:
				m.global_position.y = 0.05, 0.0, 0.7, 0.7)
		tw.tween_callback(m.queue_free)


## Red ground warning that fills until the attack lands.
func telegraph(pos: Vector3, radius: float, color: Color, life: float) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = TELE
	mat.set_shader_parameter("color", color)
	m.material_override = mat
	m.rotation_degrees = Vector3(-90, 0, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(m)
	m.global_position = Vector3(pos.x, 0.035, pos.z)
	var tw := m.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, life)
	tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.12)
	tw.tween_callback(m.queue_free)


## Killing blow: a short global freeze, a zoom punch and a white flash.
func last_hit_freeze(pos: Vector3) -> void:
	Game.freeze_ticks = maxi(Game.freeze_ticks, 5)
	fov_punch = -2.0
	shake(0.2)
	Game.log_event("last_hit")


## Orbs burst out, then home in on the player and restore a little HP/MP.
func mana_orbs(pos: Vector3, player: Node3D, n: int, color: Color) -> void:
	for i in mini(n, 2):
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.38, 0.38)
		q.material = _spark_mat
		m.mesh = q
		_add(m)
		m.global_position = pos
		var burst := Vector3(randf_range(-1.6, 1.6), randf_range(1.0, 2.4), randf_range(-1.0, 1.0))
		var tw := m.create_tween()
		tw.tween_method(func(t: float):
			if t < 0.3:
				m.global_position = pos + burst * t - Vector3(0, 2.0 * t * t, 0)
			elif is_instance_valid(player):
				var goal: Vector3 = player.global_position + Vector3(0, 0.9, 0.1)
				var u := (t - 0.3) / 0.45
				m.global_position = m.global_position.lerp(goal, clampf(u * u * 0.6 + 0.05, 0.0, 1.0)), 0.0, 0.75, 0.75)
		tw.tween_callback(func():
			if is_instance_valid(player):
				sparks(player.global_position + Vector3(0, 0.9, 0.2), Vector3.UP, color, 3, 2.5)
			m.queue_free())


func level_up(pos: Vector3) -> void:
	ring(pos + Vector3(0, 0.05, 0.2), Color(1, 0.95, 0.5), 2.0, 0.5, true)
	sparks(pos + Vector3(0, 0.5, 0.2), Vector3.UP, Color(1, 0.95, 0.5), 10, 4.0)


func confetti(center: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 90
	p.lifetime = 2.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -7.0, 0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	q.material = _spark_mat
	p.mesh = q
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.85, 0.3), Color(0.5, 1, 0.8), Color(1, 0.5, 0.6), Color(0.6, 0.7, 1)])
	g.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	p.color_initial_ramp = g
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curve
	p.emitting = true
	_add(p)
	p.global_position = center + Vector3(0, 1.5, 0)
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)
