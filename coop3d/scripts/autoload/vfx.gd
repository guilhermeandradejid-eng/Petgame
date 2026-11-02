extends Node
## One-shot visual effects. Particles use procedurally drawn sprites (star,
## soft circle, puff), rings use the shockwave shader, and a screen overlay
## handles speed lines, vignette and flashes.

const SPEEDLINES := preload("res://shaders/speedlines.gdshader")

var tex_star: ImageTexture
var tex_circle: ImageTexture
var tex_puff: ImageTexture
var _overlay: ColorRect
var _overlay_mat: ShaderMaterial
var _lines := 0.0
var _flash := Color(1, 1, 1, 0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tex_star = _make_star()
	tex_circle = _make_circle(false)
	tex_puff = _make_circle(true)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = SPEEDLINES
	_overlay.material = _overlay_mat
	layer.add_child(_overlay)


func _process(delta: float) -> void:
	_lines = move_toward(_lines, 0.0, delta * 2.0)
	_flash.a = move_toward(_flash.a, 0.0, delta * 3.0)
	var vp := get_viewport().get_visible_rect().size
	_overlay_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	_overlay_mat.set_shader_parameter("intensity", _lines)
	_overlay_mat.set_shader_parameter("flash", _flash)


func speedlines(amount := 0.8) -> void:
	_lines = maxf(_lines, amount)


func flash(color := Color(1, 1, 1, 0.6)) -> void:
	_flash = color


func set_vignette(v: float) -> void:
	_overlay_mat.set_shader_parameter("vignette", v)


# ------------------------------------------------------------ particles
func _scene() -> Node:
	return get_tree().current_scene


func _particles(pos: Vector3, tex: Texture2D, color: Color, amount: int, life: float, additive := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.explosiveness = 1.0
	p.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.disable_receive_shadows = true
	quad.material = m
	p.mesh = quad
	p.color = color
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	_scene().add_child(p)
	p.global_position = pos
	get_tree().create_timer(life + 0.3, false).timeout.connect(p.queue_free)
	return p


## Star burst for pickups / impacts.
func burst(pos: Vector3, color: Color, amount := 14, speed := 5.0, size := 1.0, up := Vector3.UP) -> void:
	var p := _particles(pos, tex_star, color, amount, 0.6)
	p.direction = up
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = -up * 6.0
	p.damping_min = 3.0
	p.damping_max = 6.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.6 * size
	p.scale_amount_max = 1.4 * size
	p.restart()


## Soft dust puffs at the feet (landing, skidding, running).
func dust(pos: Vector3, up := Vector3.UP, amount := 8, strength := 1.0) -> void:
	var p := _particles(pos + up * 0.05, tex_puff, Color(1, 0.97, 0.92, 0.85), amount, 0.5, false)
	p.direction = up
	p.spread = 80.0
	p.flatness = 0.6
	p.initial_velocity_min = 1.5 * strength
	p.initial_velocity_max = 3.5 * strength
	p.gravity = up * 1.0
	p.damping_min = 4.0
	p.damping_max = 7.0
	p.scale_amount_min = 1.2 * strength
	p.scale_amount_max = 2.2 * strength
	p.restart()


## Colorful confetti (goal, rare collectibles).
func confetti(pos: Vector3, amount := 60) -> void:
	for c in [Color(1, 0.4, 0.5), Color(1, 0.85, 0.3), Color(0.4, 0.9, 1), Color(0.6, 1, 0.5), Color(0.8, 0.5, 1)]:
		var p := _particles(pos, tex_circle, c, amount / 5, 2.2, false)
		p.direction = Vector3.UP
		p.spread = 50.0
		p.initial_velocity_min = 7.0
		p.initial_velocity_max = 13.0
		p.gravity = Vector3(0, -7, 0)
		p.damping_min = 1.0
		p.damping_max = 2.0
		p.scale_amount_min = 0.4
		p.scale_amount_max = 0.8
		p.angle_max = 360.0
		p.restart()


## Continuous emitter attached to a node (trails, hover sparkles).
func trail(parent: Node3D, color: Color, rate := 30) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = rate
	p.lifetime = 0.5
	p.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex_star
	quad.material = m
	p.mesh = quad
	p.color = color
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.gravity = Vector3.ZERO
	p.angle_max = 360.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	p.emitting = false
	parent.add_child(p)
	return p


## Expanding ground ring.
func ring(pos: Vector3, normal := Vector3.UP, color := Color(1, 0.9, 0.6), size := 3.0, duration := 0.45) -> void:
	var mi := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(size * 2.0, size * 2.0)
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = ShaderLib.get_shader("shockwave")
	m.set_shader_parameter("color", color)
	mi.material_override = m
	_scene().add_child(mi)
	mi.global_position = pos + normal * 0.06
	if absf(normal.dot(Vector3.UP)) < 0.999:
		mi.global_basis = Basis(Quaternion(Vector3.UP, normal.normalized()))
	var tw := mi.create_tween()
	tw.tween_method(func(v): m.set_shader_parameter("progress", v), 0.0, 1.0, duration)
	tw.tween_callback(mi.queue_free)


## Floating 3D text ("+1", "Ótimo!") that pops, rises and fades.
func text_pop(pos: Vector3, text: String, color := Color(1, 0.95, 0.5), size := 64) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 18
	l.modulate = color
	l.outline_modulate = Color(0.2, 0.08, 0.25)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.008
	_scene().add_child(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 0.2
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.2, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE, 0.1)
	tw.parallel().tween_property(l, "global_position", pos + Vector3.UP * 1.4, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------- sprite textures
func _make_star() -> ImageTexture:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var p := Vector2(x + 0.5, y + 0.5) / s * 2.0 - Vector2.ONE
			var a := atan2(p.y, p.x)
			var r := p.length()
			var star := 0.35 + 0.65 * pow(absf(cos(a * 2.0)), 6.0)
			var v := clampf(1.0 - r / star, 0.0, 1.0)
			var core := clampf(1.0 - r * 2.2, 0.0, 1.0)
			var alpha := clampf(v * 2.5 + core, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


func _make_circle(puffy: bool) -> ImageTexture:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.12
	for y in s:
		for x in s:
			var p := Vector2(x + 0.5, y + 0.5) / s * 2.0 - Vector2.ONE
			var r := p.length()
			if puffy:
				r += noise.get_noise_2d(x, y) * 0.25
			var a := 1.0 - smoothstep(0.55, 0.95, r) if puffy else 1.0 - smoothstep(0.8, 1.0, r)
			var shade := 1.0 if not puffy else clampf(1.0 - (p.y + 0.3) * 0.25, 0.7, 1.0)
			img.set_pixel(x, y, Color(shade, shade, shade, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
