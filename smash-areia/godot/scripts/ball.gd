class_name Ball
extends Node3D
## Bola de beach tennis com efeito (Magnus), arrasto e super golpes.
## A trajetória é simulada inteira no momento da batida com o mesmo integrador
## usado a cada frame, então a previsão (IA, alvo no chão) é exata.

signal landed(pos: Vector3)
signal touched_net(pos: Vector3)

const RADIUS := Shots.RADIUS
const TRAIL_LEN := 16

var vel := Vector3.ZERO
var spin := Vector3.ZERO
var special := ""
var flying := false
var dead := false
var held_by: Node3D = null
var last_team := -1
var last_hitter: Node3D = null
var last_shot := -1
var last_quality := 1.0
var hit_id := 0
var net_touched := false
var is_serve := false
var speed_at_hit := 0.0
var flight_t := 0.0

var traj := PackedVector3Array()
var traj_i := 0

var mesh: MeshInstance3D
var shadow: MeshInstance3D
var trail_mesh: MeshInstance3D
var trail_im: ImmediateMesh
var trail_mat: ShaderMaterial
var trail_points: Array[Vector3] = []
var trail_width := 1.0
var fx: CPUParticles3D
var fx_mat: ShaderMaterial


func _ready() -> void:
	mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 16
	sm.rings = 10
	mesh.mesh = sm
	mesh.material_override = Toon.make(Color("ffe14d"), {"rim": 0.6, "spec": 0.6, "outline": 0.016})
	add_child(mesh)
	# duas faixas cruzadas: deixam a rotação do efeito bem visível
	for i in 2:
		var band := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = RADIUS * 0.94
		tm.outer_radius = RADIUS * 1.05
		tm.rings = 16
		tm.ring_segments = 6
		band.mesh = tm
		band.rotation = Vector3(0.0, 0.0, PI * 0.5) if i == 0 else Vector3(PI * 0.5, 0.0, 0.0)
		band.material_override = Toon.make(Color("ff7a2e") if i == 0 else Color("ffffff"), {"outline": 0.0})
		mesh.add_child(band)

	shadow = Toon.blob(0.42, Color(0.25, 0.1, 0.25, 0.5))
	shadow.top_level = true
	add_child(shadow)

	trail_im = ImmediateMesh.new()
	trail_mesh = MeshInstance3D.new()
	trail_mesh.mesh = trail_im
	trail_mesh.top_level = true
	trail_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_mat = ShaderMaterial.new()
	trail_mat.shader = preload("res://shaders/trail.gdshader")
	trail_mesh.material_override = trail_mat
	add_child(trail_mesh)

	# partículas dos super golpes (fogo, água, faísca, arco-íris)
	fx = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	fx.mesh = q
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = preload("res://shaders/spark.gdshader")
	fx.material_override = fx_mat
	fx.amount = 40
	fx.lifetime = 0.45
	fx.local_coords = false
	fx.emitting = false
	fx.direction = Vector3.UP
	fx.spread = 180.0
	fx.initial_velocity_min = 0.3
	fx.initial_velocity_max = 1.4
	fx.gravity = Vector3(0, 1.0, 0)
	fx.scale_amount_min = 0.6
	fx.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	fx.scale_amount_curve = curve
	fx.color_ramp = Gradient.new()
	add_child(fx)


func _rebuild_traj() -> void:
	var sim := Shots.simulate(position, vel, spin, special)
	traj = sim["points"]
	traj_i = 0


func launch(v: Vector3, w: Vector3, team: int, hitter: Node3D, shot: int, sp := "", quality := 1.0) -> void:
	vel = v
	spin = w
	special = sp
	flying = true
	dead = false
	held_by = null
	last_team = team
	last_hitter = hitter
	last_shot = shot
	last_quality = quality
	hit_id += 1
	net_touched = false
	speed_at_hit = v.length()
	flight_t = 0.0
	trail_points.clear()
	var col: Color = Shots.COLORS[shot] if shot >= 0 else Color.WHITE
	trail_width = 1.0
	if sp != "":
		col = Shots.SPECIALS[sp]["color"]
		trail_width = 2.2
	elif shot == Shots.SMASH:
		trail_width = 1.5
	trail_mat.set_shader_parameter("color", col)
	_set_fx(sp)
	_rebuild_traj()


func toss(p: Vector3, v: Vector3) -> void:
	position = p
	vel = v
	spin = Vector3.ZERO
	special = ""
	flying = true
	dead = true
	held_by = null
	flight_t = 0.0
	_set_fx("")
	_rebuild_traj()


func _set_fx(sp: String) -> void:
	fx.emitting = sp != ""
	if sp == "":
		return
	var g := Gradient.new()
	match sp:
		"tsunami":
			g.set_color(0, Color("ffffff"))
			g.set_color(1, Color(0.2, 0.7, 1.0, 0.0))
			fx.gravity = Vector3(0, -6, 0)
		"raio":
			g.set_color(0, Color("ffffff"))
			g.set_color(1, Color(1.0, 0.95, 0.2, 0.0))
			fx.gravity = Vector3.ZERO
		"meteoro":
			g.set_color(0, Color("fff08a"))
			g.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
			fx.gravity = Vector3(0, 3, 0)
		_:
			g.set_color(0, Color("ffffff"))
			g.set_color(1, Color(1.0, 0.4, 0.9, 0.0))
			fx.gravity = Vector3.ZERO
	fx.color_ramp = g


func reset_to(p: Vector3) -> void:
	position = p
	vel = Vector3.ZERO
	spin = Vector3.ZERO
	special = ""
	flying = false
	dead = false
	net_touched = false
	last_team = -1
	last_hitter = null
	last_shot = -1
	is_serve = false
	trail_points.clear()
	traj = PackedVector3Array()
	traj_i = 0
	_set_fx("")


func step(dt: float) -> void:
	if held_by != null or not flying:
		trail_points.clear()
		_update_visuals(dt)
		return
	var prev := position
	var r := Shots.integrate(position, vel, spin, flight_t, special)
	position = r[0]
	vel = r[1]
	spin = r[2]
	flight_t += Shots.DT
	traj_i += 1
	if not net_touched and signf(prev.z) != signf(position.z) and prev.z != 0.0:
		var f := prev.z / (prev.z - position.z)
		var c := prev.lerp(position, f)
		if absf(c.x) < GameData.NET_HALF_W and c.y < GameData.NET_H + RADIUS:
			net_touched = true
			dead = true
			var s := signf(prev.z)
			position = Vector3(c.x, minf(c.y, GameData.NET_H - 0.05), s * (RADIUS + 0.03))
			vel = Vector3(vel.x * 0.15, minf(vel.y, 0.5) * 0.3, s * absf(vel.z) * 0.1)
			spin *= 0.2
			special = ""
			_set_fx("")
			_rebuild_traj()
			touched_net.emit(position)
	if position.y <= RADIUS:
		position.y = RADIUS
		flying = false
		vel = Vector3.ZERO
		_set_fx("")
		landed.emit(position)
	_update_visuals(dt)


func _update_visuals(dt: float) -> void:
	# rotação visível do efeito (em câmera lenta para não "piscar")
	if spin.length() > 0.5:
		mesh.rotate(spin.normalized(), spin.length() * dt * 0.3)
	var squash := clampf(vel.length() / 30.0, 0.0, 0.35)
	mesh.scale = Vector3.ONE * (1.0 + squash * 0.25)
	shadow.global_position = Vector3(global_position.x, 0.02, global_position.z)
	var h := clampf(global_position.y / 6.0, 0.0, 1.0)
	shadow.scale = Vector3.ONE * lerpf(1.0, 0.55, h)
	shadow.visible = visible
	if flying and (vel.length() > 6.0 or special != ""):
		trail_points.push_front(global_position)
	elif trail_points.size() > 0:
		trail_points.pop_back()
	while trail_points.size() > TRAIL_LEN:
		trail_points.pop_back()
	_draw_trail()


func _draw_trail() -> void:
	trail_im.clear_surfaces()
	if trail_points.size() < 3:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cam_pos := cam.global_position
	trail_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := trail_points.size()
	for i in n:
		var p: Vector3 = trail_points[i]
		var nxt: Vector3 = trail_points[mini(i + 1, n - 1)]
		var prv: Vector3 = trail_points[maxi(i - 1, 0)]
		var dir := (prv - nxt).normalized()
		var side := dir.cross(cam_pos - p).normalized()
		var t := 1.0 - float(i) / float(n - 1)
		var w := RADIUS * 1.6 * trail_width * t
		trail_im.surface_set_uv(Vector2(t, 0.0))
		trail_im.surface_add_vertex(p + side * w)
		trail_im.surface_set_uv(Vector2(t, 1.0))
		trail_im.surface_add_vertex(p - side * w)
	trail_im.surface_end()


## Mostra a bola numa posição gravada (replay em câmera lenta).
func show_replay(p: Vector3, prev: Vector3, fly: bool) -> void:
	position = p
	vel = (p - prev) * 60.0
	flying = fly
	_update_visuals(1.0 / 60.0)


## Posição prevista daqui a t segundos (usa a trajetória simulada; ignora a rede).
func predict(t: float) -> Vector3:
	if not flying or traj.size() == 0:
		return position
	var f := float(traj_i) + t / Shots.DT - 1.0
	if f < 0.0:
		return position.lerp(traj[0], clampf(f + 1.0, 0.0, 1.0))
	var i := int(f)
	if i >= traj.size() - 1:
		return traj[traj.size() - 1]
	return traj[i].lerp(traj[i + 1], f - float(i))


func time_to_ground() -> float:
	if not flying:
		return 0.0
	return maxf(float(traj.size() - traj_i) * Shots.DT, 0.0)


func landing_point() -> Vector3:
	if traj.size() == 0:
		return Vector3(position.x, 0.0, position.z)
	var p := traj[traj.size() - 1]
	p.y = 0.0
	return p


func is_live() -> bool:
	return flying and not dead
