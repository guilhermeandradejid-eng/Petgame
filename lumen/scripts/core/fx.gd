extends Node
## Efeitos visuais. Tudo e gerado por codigo: malhas simples + shaders de fita/anel/brilho,
## particulas de CPU e textos flutuantes. Os efeitos se destroem sozinhos.

const SH_GROUND: Shader = preload("res://shaders/fx_ground.gdshader")
const SH_ARC: Shader = preload("res://shaders/fx_arc.gdshader")
const SH_GLOW: Shader = preload("res://shaders/fx_glow.gdshader")
const SH_BAR: Shader = preload("res://shaders/fx_bar.gdshader")

var _dot: Texture2D
var _plane: PlaneMesh
var _sphere: SphereMesh
var _arc_cache: Dictionary = {}
var _quad: QuadMesh

func _ready() -> void:
	_plane = PlaneMesh.new()
	_plane.size = Vector2(2, 2)
	_sphere = SphereMesh.new()
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 16
	_sphere.rings = 8
	_quad = QuadMesh.new()

func root() -> Node:
	return Game.world.things if Game.world else get_tree().root

func soft_dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_dot = t
	return _dot

func _mat(sh: Shader, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

func _mi(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	root().add_child(mi)
	return mi

func _tw(n: Node) -> Tween:
	return n.create_tween()

func _param(tw: Tween, m: ShaderMaterial, p: String, a: float, b: float, t: float) -> MethodTweener:
	return tw.tween_method(func(v: float) -> void: m.set_shader_parameter(p, v), a, b, t)

func _ground(pos: Vector3, r: float, params: Dictionary) -> MeshInstance3D:
	var mi := _mi(_plane, _mat(SH_GROUND, params), Vector3(pos.x, maxf(pos.y, 0.0) + 0.05, pos.z))
	mi.scale = Vector3(r, 1, r)
	return mi

# ------------------------------------------------------------------ particulas
func _particles(pos: Vector3, col: Color, count: int, speed: float, life: float, size: float, grav: float = -6.0, spread: float = 180.0, dir: Vector3 = Vector3.UP) -> CPUParticles3D:
	var cp := CPUParticles3D.new()
	cp.one_shot = true
	cp.explosiveness = 0.95
	cp.amount = count
	cp.lifetime = life
	cp.direction = dir
	cp.spread = spread
	cp.initial_velocity_min = speed * 0.4
	cp.initial_velocity_max = speed
	cp.gravity = Vector3(0, grav, 0)
	cp.damping_min = 1.5
	cp.damping_max = 3.0
	cp.scale_amount_min = 0.5
	cp.scale_amount_max = 1.0
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	cp.scale_amount_curve = c
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = soft_dot()
	qm.material = m
	cp.mesh = qm
	cp.position = pos
	root().add_child(cp)
	cp.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(cp.queue_free)
	return cp

func spark(pos: Vector3, col: Color) -> void:
	_particles(pos, col, 10, 6.0, 0.3, 0.22)
	var mi := _mi(_sphere, _mat(SH_GLOW, {"color": col, "core": 1.5, "rim_power": 1.2}), pos)
	mi.scale = Vector3.ONE * 0.2
	var tw := _tw(mi)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.75, 0.1).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float) -> void: (mi.material_override as ShaderMaterial).set_shader_parameter("fade", v), 1.0, 0.0, 0.12)
	tw.tween_callback(mi.queue_free)

func burst(pos: Vector3, col: Color, size: float) -> void:
	_particles(pos, col, int(clampf(10.0 + size * 6.0, 10.0, 40.0)), 3.0 + size * 2.2, 0.55, 0.16 + size * 0.05, -7.0)

func dust(pos: Vector3, size: float) -> void:
	_particles(pos + Vector3(0, 0.15, 0), Color(0.9, 0.86, 0.78, 0.5), int(6 + size * 5.0), 1.2 + size, 0.5, 0.35 + size * 0.15, 0.6, 80.0)

func spawn_puff(pos: Vector3, r: float, col: Color) -> void:
	dust(pos, r * 2.0)
	ring(pos, r * 2.4, col.lightened(0.3), 0.35)

# ------------------------------------------------------------------ chao
func ring(pos: Vector3, r: float, col: Color, t: float) -> void:
	var mi := _ground(pos, r, {"mode": 1, "color": col, "progress": 0.0})
	var tw := _tw(mi)
	_param(tw, mi.material_override, "progress", 0.05, 1.0, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(mi.queue_free)

func shockwave(pos: Vector3, r: float, col: Color, t: float) -> void:
	ring(pos, r * 1.08, col, t)
	var g := _ground(pos, r * 0.9, {"mode": 3, "color": Color(col, 0.55)})
	var tw := _tw(g)
	_param(tw, g.material_override, "fade", 1.0, 0.0, t * 0.8)
	tw.tween_callback(g.queue_free)

## Aviso de area. friendly: cor do aliado (nao e perigo). owner: quem cancela se for interrompido.
func telegraph(pos: Vector3, r: float, t: float, col: Color, friendly: bool, follow: Node3D = null, owner: Node = null) -> MeshInstance3D:
	var c := Color(col, 0.5 if friendly else 0.85)
	var mi := _ground(pos, r, {"mode": 0, "color": c, "progress": 0.0})
	_run_telegraph(mi, t, follow, owner)
	return mi

func telegraph_cone(pos: Vector3, dir: Vector3, r: float, angle: float, t: float, col: Color, owner: Node = null) -> void:
	var mi := _ground(pos, r, {"mode": 0, "color": Color(col, 0.85), "progress": 0.0, "angle": deg_to_rad(angle)})
	mi.rotation.y = atan2(-dir.x, -dir.z)
	_run_telegraph(mi, t, null, owner)

func telegraph_line(pos: Vector3, dir: Vector3, length: float, width: float, t: float, col: Color, owner: Node = null) -> void:
	var mi := _mi(_plane, _mat(SH_GROUND, {"mode": 2, "color": Color(col, 0.85), "progress": 0.0}), pos + dir * length * 0.5 + Vector3(0, 0.05, 0))
	mi.scale = Vector3(width * 0.5, 1, length * 0.5)
	mi.rotation.y = atan2(-dir.x, -dir.z)
	_run_telegraph(mi, t, null, owner)

func _run_telegraph(mi: MeshInstance3D, t: float, follow: Node3D, owner: Node) -> void:
	mi.add_to_group("telegraph")
	if owner:
		mi.set_meta("owner", owner.get_instance_id())
	var tw := _tw(mi)
	_param(tw, mi.material_override, "progress", 0.0, 1.0, maxf(t, 0.05))
	_param(tw, mi.material_override, "fade", 1.0, 0.0, 0.12)
	tw.tween_callback(mi.queue_free)
	if follow:
		var cb := func() -> void:
			if is_instance_valid(follow) and is_instance_valid(mi):
				mi.global_position = Vector3(follow.global_position.x, 0.05, follow.global_position.z)
		tw.parallel().tween_method(func(_v: float) -> void: cb.call(), 0.0, 1.0, t)

func cancel_telegraphs(owner: Node) -> void:
	var id := owner.get_instance_id()
	for n in get_tree().get_nodes_in_group("telegraph"):
		if n.has_meta("owner") and int(n.get_meta("owner")) == id:
			n.queue_free()

func ground_glow(pos: Vector3, r: float, col: Color, t: float) -> MeshInstance3D:
	var g := _ground(pos, r, {"mode": 3, "color": col})
	if t > 0.0:
		var tw := _tw(g)
		tw.tween_interval(t)
		_param(tw, g.material_override, "fade", 1.0, 0.0, 0.3)
		tw.tween_callback(g.queue_free)
	return g

func rune_circle(parent: Node3D, r: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _plane
	mi.material_override = _mat(SH_GROUND, {"mode": 4, "color": col})
	mi.scale = Vector3(r, 1, r)
	mi.position.y = 0.06
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## Onda de choque que corre pelo chao: fere quem estiver no anel e no chao (pule ou esquive).
func ground_wave(center: Vector3, max_r: float, speed: float, dmg: float, eid: int) -> void:
	var mi := _ground(center, max_r, {"mode": 1, "color": Color("ff7a5a"), "progress": 0.0})
	var t := max_r / speed
	var hit := [false]
	var tw := _tw(mi)
	tw.tween_method(func(v: float) -> void:
		(mi.material_override as ShaderMaterial).set_shader_parameter("progress", v * 0.999)
		var me: Player = Game.me()
		if me == null or hit[0] or not me.alive():
			return
		var d := me.global_position - center
		var up := d.y
		d.y = 0.0
		var rr := v * max_r * 0.92
		if v > 0.2 and absf(d.length() - rr) < 0.6 and up < 0.55:
			hit[0] = me.take_damage(dmg, center, 5.0, eid), 0.0, 1.0, t)
	tw.tween_callback(mi.queue_free)

# ------------------------------------------------------------------ fitas (cortes)
func _arc_mesh(r_in: float, r_out: float, span_deg: float, segs: int = 18) -> ArrayMesh:
	var key := "%.2f_%.2f_%.0f" % [r_in, r_out, span_deg]
	if _arc_cache.has(key):
		return _arc_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span := deg_to_rad(span_deg)
	for i in segs:
		var u0 := float(i) / segs
		var u1 := float(i + 1) / segs
		var a0 := -span * 0.5 + span * u0
		var a1 := -span * 0.5 + span * u1
		# angulo 0 = frente (-Z); a fita vai da direita para a esquerda
		var d0 := Vector3(-sin(a0), 0, -cos(a0))
		var d1 := Vector3(-sin(a1), 0, -cos(a1))
		var v := [[d0 * r_in, Vector2(u0, 0)], [d0 * r_out, Vector2(u0, 1)], [d1 * r_out, Vector2(u1, 1)], [d1 * r_in, Vector2(u1, 0)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(v[idx][1])
			st.add_vertex(v[idx][0])
	var m := st.commit()
	_arc_cache[key] = m
	return m

## Corte de arma. kind: 1 direita->esquerda, -1 esquerda->direita, 2 de cima para baixo.
func slash(p: Node3D, kind: int, r: float, col: Color) -> void:
	var mat := _mat(SH_ARC, {"color": Color(col, 1.0), "progress": 0.0, "sweep": 1.0, "scroll": 3.0})
	var mi := _mi(_arc_mesh(r * 0.45, r, 165.0), mat, p.global_position + Vector3(0, 0.85, 0))
	var yaw := p.rotation.y
	match kind:
		1:
			mi.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, -0.18) * Basis.from_scale(Vector3(-1, 1, 1))
		-1:
			mi.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, 0.18)
		_:
			mi.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.5) * Basis(Vector3.FORWARD, PI * 0.5) * Basis.from_scale(Vector3(-1, 1, 1))
			mi.position += Vector3(0, 0.5, 0)
	var tw := _tw(mi)
	_param(tw, mat, "progress", 0.0, 1.0, 0.24)
	tw.tween_callback(mi.queue_free)

func cut(pos: Vector3, col: Color, size: float) -> void:
	var mat := _mat(SH_ARC, {"color": col, "progress": 0.0, "sweep": 1.0, "scroll": 4.0})
	var mi := _mi(_arc_mesh(size * 0.55, size, 150.0), mat, pos)
	mi.basis = Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.FORWARD, randf_range(-1.2, 1.2))
	var tw := _tw(mi)
	_param(tw, mat, "progress", 0.0, 1.0, 0.2)
	tw.tween_callback(mi.queue_free)

func cone(pos: Vector3, dir: Vector3, r: float, angle: float, col: Color) -> void:
	var mat := _mat(SH_ARC, {"color": col, "progress": 0.0, "sweep": 0.0, "scroll": 5.0})
	var mi := _mi(_arc_mesh(r * 0.25, r, minf(angle, 340.0)), mat, pos + Vector3(0, 0.7, 0))
	mi.rotation.y = atan2(-dir.x, -dir.z)
	mi.scale = Vector3.ONE * 0.5
	var tw := _tw(mi)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.14).set_ease(Tween.EASE_OUT)
	tw.parallel()
	_param(tw, mat, "progress", 0.0, 1.0, 0.28)
	tw.tween_callback(mi.queue_free)

func gust(pos: Vector3, dir: Vector3, r: float, angle: float, col: Color) -> void:
	for i in 3:
		var mat := _mat(SH_ARC, {"color": Color(col, 0.7), "progress": 0.0, "sweep": 0.0, "scroll": 7.0})
		var mi := _mi(_arc_mesh(r * 0.5, r, angle), mat, pos + Vector3(0, i * 0.5 - 0.3, 0))
		mi.rotation.y = atan2(-dir.x, -dir.z)
		mi.scale = Vector3.ONE * 0.2
		var tw := _tw(mi)
		tw.tween_interval(i * 0.05)
		tw.tween_property(mi, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT)
		tw.parallel()
		_param(tw, mat, "progress", 0.0, 1.0, 0.4)
		tw.tween_callback(mi.queue_free)
	_particles(pos, col, 24, r * 2.2, 0.5, 0.25, 0.0, angle * 0.5, dir)

func _ribbon(a: Vector3, b: Vector3, width: float, col: Color, life: float, sweep: float = 0.0, jag: float = 0.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 8 if jag > 0.0 else 1
	var cam := get_viewport().get_camera_3d()
	var view := (cam.global_position - (a + b) * 0.5).normalized() if cam else Vector3.UP
	var side := (b - a).normalized().cross(view).normalized() * width * 0.5
	var pts: Array = []
	for i in segs + 1:
		var t := float(i) / segs
		var p := a.lerp(b, t)
		if jag > 0.0 and i > 0 and i < segs:
			p += Vector3(randf_range(-jag, jag), randf_range(-jag, jag), randf_range(-jag, jag))
		pts.append(p)
	for i in segs:
		var u0 := float(i) / segs
		var u1 := float(i + 1) / segs
		var v := [[pts[i] - side, Vector2(u0, 0)], [pts[i] + side, Vector2(u0, 1)], [pts[i + 1] + side, Vector2(u1, 1)], [pts[i + 1] - side, Vector2(u1, 0)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(v[idx][1])
			st.add_vertex(v[idx][0])
	var mat := _mat(SH_ARC, {"color": col, "progress": 0.0, "sweep": sweep, "scroll": 6.0})
	var mi := _mi(st.commit(), mat, Vector3.ZERO)
	var tw := _tw(mi)
	_param(tw, mat, "progress", 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)

func lightning(a: Vector3, b: Vector3, col: Color) -> void:
	_ribbon(a, b, 0.5, col, 0.22, 0.0, minf(0.6, a.distance_to(b) * 0.08))
	_ribbon(a, b, 0.22, Color.WHITE, 0.16, 0.0, minf(0.4, a.distance_to(b) * 0.06))

func thrust(a: Vector3, b: Vector3, col: Color) -> void:
	_ribbon(a + Vector3(0, 0.8, 0), b + Vector3(0, 0.8, 0), 1.3, col, 0.28, 1.0)

func trail(p: Node3D, t: float, col: Color) -> void:
	var cp := _particles(p.global_position + Vector3(0, 0.7, 0), col, 26, 0.6, 0.35, 0.5, 0.0)
	cp.one_shot = false
	cp.explosiveness = 0.0
	cp.reparent(p)
	cp.position = Vector3(0, 0.7, 0)
	get_tree().create_timer(t).timeout.connect(func() -> void:
		if is_instance_valid(cp):
			cp.emitting = false)

func whirl(p: Node3D, r: float, t: float, col: Color) -> Node3D:
	var holder := Node3D.new()
	p.add_child(holder)
	holder.position.y = 0.8
	for i in 2:
		var mat := _mat(SH_ARC, {"color": col, "progress": 0.25, "sweep": 0.0, "scroll": 6.0})
		var mi := MeshInstance3D.new()
		mi.mesh = _arc_mesh(r * 0.5, r, 170.0)
		mi.material_override = mat
		mi.rotation.y = i * PI
		mi.position.y = i * 0.25 - 0.1
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	var tw := holder.create_tween().set_loops()
	tw.tween_property(holder, "rotation:y", TAU, 0.3).from(0.0)
	return holder

func beam(p: Player, length: float, width: float, t: float, col: Color) -> Node3D:
	var holder := Node3D.new()
	p.add_child(holder)
	holder.position = Vector3(0, 0.95, -0.6)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var side := (Vector3.RIGHT if k == 0 else Vector3.UP) * width * 0.5
		var v := [[-side, Vector2(0, 0)], [side, Vector2(0, 1)], [side + Vector3(0, 0, -length), Vector2(1, 1)], [-side + Vector3(0, 0, -length), Vector2(1, 0)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(v[idx][1])
			st.add_vertex(v[idx][0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(SH_ARC, {"color": col, "progress": 0.2, "sweep": 0.0, "scroll": 9.0})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 2.5
	l.omni_range = 6.0
	holder.add_child(l)
	return holder

# ------------------------------------------------------------------ volumes
func explosion(pos: Vector3, r: float, col: Color) -> void:
	var c := pos + Vector3(0, 0.3, 0)
	var mi := _mi(_sphere, _mat(SH_GLOW, {"color": col, "core": 1.3, "rim_power": 1.5}), c)
	mi.scale = Vector3.ONE * r * 0.25
	var tw := _tw(mi)
	tw.tween_property(mi, "scale", Vector3.ONE * r * 0.95, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel()
	_param(tw, mi.material_override, "fade", 1.2, 0.0, 0.3)
	tw.tween_callback(mi.queue_free)
	shockwave(pos, r, col, 0.35)
	burst(c, col.lightened(0.3), r)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 4.0
	l.omni_range = r * 2.5
	l.position = c + Vector3(0, 0.8, 0)
	root().add_child(l)
	var tl := _tw(l)
	tl.tween_property(l, "light_energy", 0.0, 0.3)
	tl.tween_callback(l.queue_free)

func meteor(pos: Vector3, delay: float, size: float, col: Color) -> void:
	var start := pos + Vector3(4.0, 16.0, 3.0)
	var mi := _mi(_sphere, _mat(SH_GLOW, {"color": col, "core": 2.0, "rim_power": 1.0}), start)
	mi.scale = Vector3.ONE * maxf(0.35, size * 0.3)
	var tw := _tw(mi)
	tw.tween_interval(maxf(0.0, delay - 0.45))
	tw.tween_property(mi, "position", pos + Vector3(0, 0.3, 0), minf(0.45, delay)).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	var cp := _particles(start, col, 30, 0.5, 0.4, 0.5, 0.0)
	cp.one_shot = false
	cp.explosiveness = 0.0
	cp.reparent(mi)
	cp.position = Vector3.ZERO

func blink(from: Vector3, to: Vector3, col: Color) -> void:
	burst(from + Vector3(0, 0.7, 0), col, 1.6)
	burst(to + Vector3(0, 0.7, 0), col, 1.6)
	_ribbon(from + Vector3(0, 0.8, 0), to + Vector3(0, 0.8, 0), 0.9, col, 0.3, 1.0)

func heal(p: Node3D) -> void:
	var cp := _particles(p.global_position + Vector3(0, 0.3, 0), Color("7dff9a"), 14, 2.2, 0.8, 0.22, 2.5, 30.0)
	cp.reparent(p)

func heal_ring(pos: Vector3, r: float, col: Color) -> void:
	_particles(pos + Vector3(0, 0.2, 0), col, 40, r * 1.6, 0.9, 0.24, 2.0, 88.0)

func shield(p: Node3D, t: float) -> void:
	for c in p.get_children():
		if c.name == "ShieldFx":
			c.queue_free()
	var mi := MeshInstance3D.new()
	mi.name = "ShieldFx"
	mi.mesh = _sphere
	mi.material_override = _mat(SH_GLOW, {"color": Color("7df9ff", 0.8), "rim_power": 2.4})
	mi.scale = Vector3.ONE * 0.95
	mi.position.y = 0.7
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	var tw := mi.create_tween().set_loops(int(minf(t, 60.0) / 0.25))
	tw.tween_callback(func() -> void:
		if p is Player and (p as Player).shield <= 0.0:
			mi.queue_free())
	tw.tween_interval(0.25)
	tw.finished.connect(mi.queue_free)

func charge_glow(e: Node3D, t: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = _mat(SH_GLOW, {"color": col, "core": 1.0, "rim_power": 2.0})
	mi.position.y = float(e.get("height")) * 0.6 if e.get("height") != null else 1.0
	mi.scale = Vector3.ONE * 0.1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group("telegraph")
	mi.set_meta("owner", e.get_instance_id())
	e.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 0.55, t).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)

func champion_aura(e: Node3D, r: float) -> void:
	var g := MeshInstance3D.new()
	g.mesh = _plane
	g.material_override = _mat(SH_GROUND, {"mode": 4, "color": Color("ffb23e")})
	g.scale = Vector3(r * 2.2, 1, r * 2.2)
	g.position.y = 0.06
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.add_child(g)

func status_marks(e: Enemy, f: int) -> void:
	var col := Color.WHITE
	var lvl := 0.0
	if (f & 8) != 0:
		col = Color("ff8a3d")
		lvl = 0.3
	if (f & 16) != 0:
		col = Color("8fd16a")
		lvl = 0.3
	if (f & 2) != 0:
		col = Color("8fe3ff")
		lvl = 0.35
	if (f & 4) != 0:
		col = Color("fff2a0")
		lvl = 0.3
	var key := int(lvl * 100.0) + col.to_rgba32()
	if e.has_meta("st_key") and int(e.get_meta("st_key")) == key:
		return
	e.set_meta("st_key", key)
	e.set_meta("st_lvl", lvl)
	Mats.set_instance_param(e.model, &"flash_color", col)
	Mats.set_instance_param(e.model, &"flash", lvl)

# ------------------------------------------------------------------ zonas persistentes
func zone_visual(z: Zone, r: float, col: Color, kind: String) -> void:
	rune_circle(z, r, col)
	var g := MeshInstance3D.new()
	g.mesh = _plane
	g.material_override = _mat(SH_GROUND, {"mode": 3, "color": Color(col, 0.25)})
	g.scale = Vector3(r, 1, r)
	g.position.y = 0.04
	z.add_child(g)
	var cp := CPUParticles3D.new()
	cp.amount = 40
	cp.lifetime = 0.7
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cp.emission_sphere_radius = r * 0.85
	var qm := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = soft_dot()
	match kind:
		"arrow_rain":
			qm.size = Vector2(0.06, 1.3)
			m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			cp.position.y = 9.0
			cp.gravity = Vector3(0, -60, 0)
			cp.direction = Vector3.DOWN
			cp.spread = 2.0
			cp.initial_velocity_min = 18.0
			cp.initial_velocity_max = 22.0
			cp.flatness = 1.0
			cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			cp.emission_box_extents = Vector3(r * 0.7, 0.2, r * 0.7)
			cp.lifetime = 0.45
		"vortex":
			qm.size = Vector2(0.3, 0.3)
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			cp.gravity = Vector3.ZERO
			cp.radial_accel_min = -30.0
			cp.radial_accel_max = -22.0
			cp.tangential_accel_min = 14.0
			cp.tangential_accel_max = 18.0
			cp.position.y = 0.8
			cp.emission_sphere_radius = r
			var core := MeshInstance3D.new()
			core.mesh = _sphere
			core.material_override = _mat(SH_GLOW, {"color": col, "core": 0.4, "rim_power": 1.6})
			core.position.y = 0.9
			core.scale = Vector3.ONE * 0.7
			z.add_child(core)
		_:
			qm.size = Vector2(0.2, 0.2)
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			cp.gravity = Vector3(0, 3.0, 0)
			cp.amount = 24
			cp.lifetime = 1.2
			cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			cp.emission_box_extents = Vector3(r * 0.7, 0.1, r * 0.7)
			var l := OmniLight3D.new()
			l.light_color = col
			l.light_energy = 1.6
			l.omni_range = r * 1.4
			l.position.y = 1.5
			z.add_child(l)
	qm.material = m
	cp.mesh = qm
	z.add_child(cp)

func totem_visual(z: Zone, col: Color) -> void:
	var m := KitLib.make("env_forest", "totem")
	if m == null:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.16
		cm.bottom_radius = 0.26
		cm.height = 1.4
		cm.radial_segments = 6
		mi.mesh = cm
		mi.position.y = 0.7
		mi.material_override = Mats.toon(Color("8a5a3c"))
		z.add_child(mi)
		var orb := MeshInstance3D.new()
		orb.mesh = _sphere
		orb.scale = Vector3.ONE * 0.24
		orb.position.y = 1.55
		orb.material_override = _mat(SH_GLOW, {"color": col, "core": 2.0, "rim_power": 1.0})
		z.add_child(orb)
	else:
		z.add_child(m)
	rune_circle(z, 1.2, col)
	z.scale = Vector3.ONE * 0.1
	z.create_tween().tween_property(z, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func orbit_visual(z: Zone, r: float, count: int, col: Color) -> void:
	var holder := Node3D.new()
	holder.position.y = 0.85
	z.add_child(holder)
	for i in count:
		var a := TAU * i / count
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.22, 0.75, 0.08)
		mi.mesh = pm
		mi.material_override = _mat(SH_GLOW, {"color": col, "core": 2.2, "rim_power": 0.8})
		mi.position = Vector3(cos(a), 0, sin(a)) * r
		mi.rotation = Vector3(PI * 0.5, -a, 0)
		holder.add_child(mi)
	var tw := holder.create_tween().set_loops()
	tw.tween_property(holder, "rotation:y", -TAU, 0.9).from(0.0)

# ------------------------------------------------------------------ texto e barras
func text(pos: Vector3, s: String, col: Color, life: float) -> void:
	var l := Label3D.new()
	l.text = s
	l.font = Ui.font_bold()
	l.font_size = 56
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color("1b1730")
	l.position = pos
	root().add_child(l)
	var tw := _tw(l)
	tw.tween_property(l, "position:y", pos.y + 0.9, life).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, life * 0.4).set_delay(life * 0.6)
	tw.tween_callback(l.queue_free)

func number(pos: Vector3, amount: float, col: Color, crit: bool, small: bool) -> void:
	var l := Label3D.new()
	l.text = str(int(round(amount))) + ("!" if crit else "")
	l.font = Ui.font_bold()
	l.font_size = 72 if crit else 54
	l.pixel_size = 0.0075 if not small else 0.005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = col
	l.outline_size = 16
	l.outline_modulate = Color("1b1730")
	l.position = pos
	root().add_child(l)
	var drift := Vector3(randf_range(-0.5, 0.5), randf_range(0.9, 1.3), 0)
	var tw := _tw(l)
	l.scale = Vector3.ONE * 0.4
	tw.tween_property(l, "scale", Vector3.ONE * (1.25 if crit else 1.0), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position", pos + drift, 0.7).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.45)
	tw.tween_callback(l.queue_free)

func make_hp_bar(parent: Node3D, y: float, w: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, 0.13)
	mi.mesh = qm
	mi.material_override = _mat(SH_BAR, {"frac": 1.0})
	mi.position.y = y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func set_hp_bar(bar: Node3D, frac: float) -> void:
	((bar as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("frac", clampf(frac, 0.0, 1.0))

func glow_mat(col: Color, core: float = 1.6, rim: float = 1.2) -> ShaderMaterial:
	return _mat(SH_GLOW, {"color": col, "core": core, "rim_power": rim})

func arc_mat(col: Color) -> ShaderMaterial:
	return _mat(SH_ARC, {"color": col, "progress": 0.2, "sweep": 0.0, "scroll": 5.0})
