class_name Ball
extends Node3D
## Bola de beach tennis: física própria (sem arrasto) para que a IA e o
## marcador de queda possam prever a trajetória com exatidão.

signal landed(pos: Vector3)
signal touched_net(pos: Vector3)

const RADIUS := 0.11
const TRAIL_LEN := 14

var vel := Vector3.ZERO
var flying := false
var dead := false            # depois de bater na rede ninguém mais pode tocar
var held_by: Node3D = null   # jogador que vai sacar
var last_team := -1
var last_hitter: Node3D = null
var last_shot := -1
var hit_id := 0              # incrementa a cada golpe (a IA usa para replanejar)
var net_touched := false
var is_serve := false
var speed_at_hit := 0.0

var mesh: MeshInstance3D
var shadow: MeshInstance3D
var trail_mesh: MeshInstance3D
var trail_im: ImmediateMesh
var trail_mat: ShaderMaterial
var trail_points: Array[Vector3] = []
var spin_axis := Vector3.RIGHT
var spin := 0.0


func _ready() -> void:
	mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 16
	sm.rings = 10
	mesh.mesh = sm
	mesh.material_override = Toon.make(Color("ffe14d"), {"rim": 0.6, "spec": 0.6, "outline": 0.018})
	add_child(mesh)
	# faixa da bola
	var band := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RADIUS * 0.93
	tm.outer_radius = RADIUS * 1.04
	tm.rings = 16
	tm.ring_segments = 6
	band.mesh = tm
	band.rotation.z = 0.5
	band.material_override = Toon.make(Color("ff7a2e"), {"outline": 0.0})
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


func launch(v: Vector3, team: int, hitter: Node3D, shot: int) -> void:
	vel = v
	flying = true
	dead = false
	held_by = null
	last_team = team
	last_hitter = hitter
	last_shot = shot
	hit_id += 1
	net_touched = false
	speed_at_hit = v.length()
	spin_axis = Vector3(v.z, 0, -v.x).normalized() if Vector2(v.x, v.z).length() > 0.1 else Vector3.RIGHT
	spin = v.length() * 2.0
	trail_points.clear()
	trail_mat.set_shader_parameter("color", Shots.COLORS[shot] if shot >= 0 else Color.WHITE)


func reset_to(p: Vector3) -> void:
	position = p
	vel = Vector3.ZERO
	flying = false
	dead = false
	net_touched = false
	last_team = -1
	last_hitter = null
	last_shot = -1
	is_serve = false
	trail_points.clear()


func step(dt: float) -> void:
	if held_by != null:
		trail_points.clear()
		_update_visuals(dt)
		return
	if not flying:
		_update_visuals(dt)
		return
	var prev := position
	# integração exata da parábola: a simulação bate com a previsão da IA
	position += vel * dt + Vector3(0.0, -0.5 * Shots.G * dt * dt, 0.0)
	vel.y -= Shots.G * dt
	# rede
	if not net_touched and signf(prev.z) != signf(position.z) and prev.z != 0.0:
		var f := prev.z / (prev.z - position.z)
		var c := prev.lerp(position, f)
		if absf(c.x) < GameData.NET_HALF_W and c.y < GameData.NET_H + RADIUS:
			net_touched = true
			dead = true
			var s := signf(prev.z)
			position = Vector3(c.x, minf(c.y, GameData.NET_H - 0.05), s * (RADIUS + 0.03))
			vel = Vector3(vel.x * 0.15, minf(vel.y, 0.5) * 0.3, s * absf(vel.z) * 0.1)
			touched_net.emit(position)
	if position.y <= RADIUS:
		position.y = RADIUS
		flying = false
		vel = Vector3.ZERO
		landed.emit(position)
	_update_visuals(dt)


func _update_visuals(dt: float) -> void:
	if spin > 0.0:
		mesh.rotate(spin_axis, spin * dt)
		spin = maxf(spin - dt * 4.0, 0.0)
	var squash := clampf(vel.length() / 30.0, 0.0, 0.35)
	mesh.scale = Vector3.ONE * (1.0 + squash * 0.2)
	shadow.global_position = Vector3(global_position.x, 0.02, global_position.z)
	var h := clampf(global_position.y / 6.0, 0.0, 1.0)
	shadow.scale = Vector3.ONE * lerpf(1.0, 0.55, h)
	shadow.visible = visible
	# rastro
	if flying and vel.length() > 6.0:
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
		var w := RADIUS * 1.6 * t
		trail_im.surface_set_uv(Vector2(t, 0.0))
		trail_im.surface_add_vertex(p + side * w)
		trail_im.surface_set_uv(Vector2(t, 1.0))
		trail_im.surface_add_vertex(p - side * w)
	trail_im.surface_end()


## Posição prevista daqui a t segundos (ignora a rede).
func predict(t: float) -> Vector3:
	return position + vel * t + Vector3(0.0, -0.5 * Shots.G * t * t, 0.0)


func time_to_ground() -> float:
	if not flying:
		return 0.0
	return Shots.flight_time(position, vel, RADIUS)


func landing_point() -> Vector3:
	var p := predict(time_to_ground())
	p.y = 0.0
	return p


func is_live() -> bool:
	return flying and not dead
