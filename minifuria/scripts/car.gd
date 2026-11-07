class_name Car
extends RigidBody3D
## Carro arcade com física de verdade: suspensão por raycast em cada roda, aderência lateral, drift que conserva
## embalo, nitro, guinada controlada por torque e destruição (amassados na malha, peças que soltam, capotagem).

signal hit(car: Car, other: Object, point: Vector3, dv: float)
signal part_off(car: Car, mesh: MeshInstance3D, xform: Transform3D, vel: Vector3, is_wheel: bool)
signal landed(car: Car, air_time: float, impact: float)

const SUSP := 0.38          # curso da suspensão (m)
const GRAV_SCALE := 2.2     # gravidade arcade

const SPECS := {
	"faisca": {"len": 3.7, "wid": 2.0, "h": 0.62, "clr": 0.34, "mass": 1.0, "vmax": 40.0, "nitro": 58.0, "accel": 26.0, "grip": 9.5, "drift_grip": 1.6, "turn": 2.7},
	"trovao": {"len": 4.1, "wid": 2.1, "h": 0.6, "clr": 0.3, "mass": 1.25, "vmax": 39.0, "nitro": 53.0, "accel": 24.0, "grip": 8.5, "drift_grip": 1.8, "turn": 2.5},
	"vespa": {"len": 3.4, "wid": 2.0, "h": 0.55, "clr": 0.45, "mass": 0.95, "vmax": 38.0, "nitro": 53.0, "accel": 26.0, "grip": 9.0, "drift_grip": 1.8, "turn": 2.8},
	"sedan": {"len": 3.9, "wid": 1.95, "h": 0.66, "clr": 0.3, "mass": 1.0, "vmax": 26.0, "nitro": 26.0, "accel": 12.0, "grip": 8.0, "drift_grip": 2.0, "turn": 2.2},
	"taxi": {"len": 3.9, "wid": 1.95, "h": 0.66, "clr": 0.3, "mass": 1.0, "vmax": 26.0, "nitro": 26.0, "accel": 12.0, "grip": 8.0, "drift_grip": 2.0, "turn": 2.2},
	"policia": {"len": 3.9, "wid": 1.95, "h": 0.66, "clr": 0.3, "mass": 1.1, "vmax": 30.0, "nitro": 30.0, "accel": 14.0, "grip": 8.0, "drift_grip": 2.0, "turn": 2.2},
	"picape": {"len": 4.3, "wid": 2.1, "h": 0.8, "clr": 0.45, "mass": 1.5, "vmax": 24.0, "nitro": 24.0, "accel": 10.0, "grip": 8.0, "drift_grip": 2.0, "turn": 2.0},
	"van": {"len": 4.4, "wid": 2.1, "h": 0.85, "clr": 0.35, "mass": 1.8, "vmax": 22.0, "nitro": 22.0, "accel": 9.0, "grip": 8.0, "drift_grip": 2.0, "turn": 1.9},
}

var kind := ""
var role := "traffic"       # player | rival | traffic
var display_name := ""
var sp: Dictionary
var color := Color.RED
var ctrl := {"steer": 0.0, "throttle": 0.0, "brake": 0.0, "drift": false, "nitro": false, "dir": null, "dir_mag": 0.0}

var nitro_amt := 1.0
var nitroing := false
var v_f := 0.0
var v_s := 0.0
var steer_s := 0.0
var drifting := false
var drift_dir := 0.0
var drift_t := 0.0
var drift_slip := 0.0
var on_ground := true
var air_t := 0.0
var stun := 0.0
var invuln := 0.0
var wrecked := false
var wreck_t := 0.0
var health := 100.0
var last_hit_by: Car = null
var last_hit_t := -10.0
var game_time := 0.0

# IA / pista
var oncoming := false
var lane := -2.75
var lane_t := -2.75
var lane_cur := -2.75
var cruise := 18.0
var rubber := 1.0
var seed_f := 0.0
var next_bash := 5.0
var lane_switch_t := 0.0
var ti := -1
var s_track := 0.0
var lat := 0.0
var dist := 0.0
var prev_s := 0.0
var lap := 0
var nm_state = null
var pad_t := 0.0

var model: Node3D
var wheels: Array = []
var parts: Dictionary = {}
var paint: StandardMaterial3D
var tail_mat: StandardMaterial3D
var sirens: Array = []
var exhaust_local := Vector3.ZERO
var tail_local := [Vector3.ZERO, Vector3.ZERO]

var _prev_v := Vector3.ZERO
var _applied := Vector3.ZERO
var _contacts: Array = []
var _teleport = null
var _dent_cd := 0.0
var _k := 0.0
var _c := 0.0


func setup(lib: Node3D, kind_: String, role_: String, col: Color) -> void:
	kind = kind_
	role = role_
	color = col
	sp = SPECS[kind]
	mass = 1000.0 * sp.mass
	gravity_scale = GRAV_SCALE
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.45, 0)
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 6
	angular_damp = 1.2
	linear_damp = 0.02
	can_sleep = false
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	var pm := PhysicsMaterial.new()
	pm.friction = 0.25
	pm.bounce = 0.15
	physics_material_override = pm

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(sp.wid * 0.94, sp.h + 0.45, sp.len * 0.96)
	cs.shape = box
	cs.position = Vector3(0, sp.clr + (sp.h + 0.45) * 0.5 + 0.02, 0)
	add_child(cs)

	model = lib.get_node("car_" + kind).duplicate()
	model.transform = Transform3D.IDENTITY
	add_child(model)
	paint = null
	var mat_cache := {}
	for ch in model.get_children():
		if not (ch is MeshInstance3D):
			continue
		var mi: MeshInstance3D = ch
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mats: Array = []
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			mats.append(_car_mat(m, mat_cache))
			mi.set_surface_override_material(s, mats[s])
		var nm := String(mi.name)
		var part_name := nm.substr(kind.length() + 1)
		if part_name.begins_with("w") and part_name.length() == 3:
			wheels.append({"mesh": mi, "base": mi.position, "front": mi.position.z > 0, "r": mi.position.y,
				"spin": 0.0, "dist": SUSP + mi.position.y, "contact": false, "lost": false, "skid": null, "name": part_name})
		else:
			var arrays: Array = []
			for s in mi.mesh.get_surface_count():
				arrays.append(mi.mesh.surface_get_arrays(s))
			parts[part_name] = {"mesh": mi, "orig": mi.mesh, "arrays": arrays, "mats": mats, "hp": 100.0, "off": false,
				"center": mi.transform * mi.mesh.get_aabb().get_center()}
	var L: float = sp.len
	var W: float = sp.wid
	exhaust_local = Vector3(W * 0.28, sp.clr + 0.12, -(L * 0.5 + 0.3))
	var tz: float = sp.clr + sp.h * 0.65
	tail_local = [Vector3(-W * 0.32, tz, -L * 0.5), Vector3(W * 0.32, tz, -L * 0.5)]
	var g_eff := 9.8 * GRAV_SCALE
	_k = mass * g_eff / 4.0 / 0.13
	_c = 2.0 * sqrt(_k * mass / 4.0) * 0.55


func _car_mat(m: Material, cache: Dictionary) -> Material:
	if m == null:
		return m
	if cache.has(m):
		return cache[m]
	var out := m
	var nm := m.resource_name
	if nm == "Paint" or nm == "Taillight" or nm.begins_with("Siren"):
		out = m.duplicate()
		if nm == "Paint":
			(out as StandardMaterial3D).albedo_color = color
			paint = out
		elif nm == "Taillight":
			tail_mat = out
		else:
			sirens.append(out)
	cache[m] = out
	return out


# ------------------------------------------------------------------ física
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _teleport != null:
		state.transform = _teleport.xform
		state.linear_velocity = _teleport.vel
		state.angular_velocity = Vector3.ZERO
		_teleport = null
		_prev_v = state.linear_velocity
	_contacts.clear()
	for i in state.get_contact_count():
		_contacts.append([state.get_contact_collider_object(i), state.get_contact_local_position(i), state.get_contact_local_normal(i)])


func _physics_process(dt: float) -> void:
	game_time += dt
	_dent_cd = maxf(0.0, _dent_cd - dt)
	_detect_impacts(dt)
	if wrecked:
		wreck_t += dt
		_suspension(dt, true)
		return
	if freeze:
		air_t = 0.0
		on_ground = true
		_prev_v = Vector3.ZERO
		return
	invuln = maxf(0.0, invuln - dt)
	stun = maxf(0.0, stun - dt)
	_applied = Vector3.ZERO
	var grounded := _suspension(dt, false)
	var was_ground := on_ground
	on_ground = grounded >= 2
	if not on_ground:
		air_t += dt
	elif not was_ground:
		landed.emit(self, air_t, maxf(0.0, -_prev_v.y))
		air_t = 0.0

	var b := global_transform.basis
	var up := b.y
	var fwd := b.z
	var v := linear_velocity
	var fwd_g := Vector3(fwd.x, 0, fwd.z).normalized()
	var left_g := Vector3.UP.cross(fwd_g)
	v_f = v.dot(fwd_g)
	v_s = v.dot(left_g)
	var h := atan2(fwd.x, fwd.z)

	# direção: analógico de tela vira um rumo-alvo
	var steer: float = ctrl.steer
	if ctrl.dir != null:
		var d: Vector3 = ctrl.dir
		var dh := wrapf(atan2(d.x, d.z) - h, -PI, PI)
		steer = clampf(dh * 2.4, -1.0, 1.0) * float(ctrl.dir_mag)
		if v_f < -2.0:
			steer = -steer
	steer_s = lerpf(steer_s, steer, minf(1.0, dt * 14.0))
	var spd01: float = minf(1.0, absf(v_f) / sp.vmax)

	# drift
	if not drifting and on_ground and ctrl.drift and v_f > 11.0 and absf(steer_s) > 0.2:
		drifting = true
		drift_dir = signf(steer_s)
		drift_t = 0.0
		angular_velocity += up * drift_dir * 1.1
	if drifting:
		drift_t += dt
		drift_slip = absf(atan2(v_s, maxf(1.0, v_f)))
		var holding: bool = ctrl.drift or steer_s * drift_dir > 0.25
		if v_f < 7.0 or not on_ground or (drift_t > 0.35 and drift_slip < 0.1 and not holding) or (drift_t > 0.2 and drift_slip < 0.05):
			drifting = false
	else:
		drift_slip = 0.0

	nitroing = ctrl.nitro and nitro_amt > 0.01 and v_f > 2.0
	var vmax_now: float = sp.nitro if nitroing else sp.vmax
	if nitroing and role == "player":
		nitro_amt = maxf(0.0, nitro_amt - dt * 0.3)

	var wy := angular_velocity.dot(up)
	var inertia: float = mass * (sp.len * sp.len + sp.wid * sp.wid) / 12.0
	if on_ground:
		# guinada
		var target := 0.0
		if drifting:
			target = (steer_s * 1.25 + drift_dir * 0.55) * sp.turn * 0.95
		else:
			var rate: float = sp.turn * minf(1.0, absf(v_f) / 5.0) * (1.0 - 0.32 * spd01)
			target = steer_s * rate * (1.0 if v_f >= 0.0 else -1.0)
		var auth := 0.25 if stun > 0.0 else 1.0
		var k := (5.0 if drifting else 9.0) * auth
		apply_torque(up * (target - wy) * inertia * k)
		# longitudinal
		var a := 0.0
		if ctrl.throttle > 0.0 and not (ctrl.brake > 0.0 and v_f > 1.0):
			if v_f < vmax_now:
				var f := maxf(0.12, 1.0 - pow(v_f / vmax_now, 2.0))
				a += sp.accel * (1.7 if nitroing else 1.0) * ctrl.throttle * f
			else:
				a -= (v_f - vmax_now) * 1.2
		elif ctrl.brake <= 0.0:
			a -= signf(v_f) * minf(absf(v_f) / dt, 4.0) + v_f * 0.08
		if ctrl.brake > 0.0:
			if v_f > 0.5:
				a -= 8.0 if drifting else 32.0
			elif v_f > -12.0:
				a -= 16.0
		if drifting:
			a -= v_f * 0.1
		# aderência lateral
		var grip: float = sp.drift_grip if drifting else sp.grip
		if stun > 0.0:
			grip *= 0.25
		var lost := v_s * (1.0 - exp(-grip * dt))
		var lat_a := -lost / dt
		if drifting:
			a += absf(lost) / dt * 0.35
		var force := fwd_g * a * mass + left_g * lat_a * mass
		apply_force(force, up * -0.15 + global_transform.basis * center_of_mass - Vector3.ZERO)
		_applied += force
		# pressão aerodinâmica
		apply_central_force(-up * mass * clampf(absf(v_f) * 0.12, 0, 6))
	else:
		if nitroing:
			apply_central_force(fwd_g * mass * 10.0)
			_applied += fwd_g * mass * 10.0
	# estabilizador: mantém o carro de pé (arcade). Destroços não têm isso.
	var tilt := up.cross(Vector3.UP)
	var ang_nyaw := angular_velocity - up * wy
	var stab := 22.0 if on_ground else 8.0
	apply_torque((tilt * stab - ang_nyaw * (3.0 if on_ground else 1.2)) * inertia)


func _suspension(dt: float, wreck_mode: bool) -> int:
	var space := get_world_3d().direct_space_state
	var b := global_transform.basis
	var up := b.y
	var grounded := 0
	var excl := [get_rid()]
	for w in wheels:
		if w.lost:
			continue
		var mount: Vector3 = global_transform * (w.base + Vector3(0, SUSP, 0))
		var maxd: float = SUSP + w.r + 0.3
		var q := PhysicsRayQueryParameters3D.create(mount, mount - up * maxd, 1, excl)
		var res := space.intersect_ray(q)
		w.contact = false
		w.dist = maxd
		if res:
			var dist: float = mount.distance_to(res.position)
			var comp: float = SUSP + w.r - dist
			w.dist = dist
			if comp > -0.03:
				w.contact = true
				grounded += 1
				if not wreck_mode or up.y > 0.5:
					var rel: Vector3 = mount - global_position
					var pv := linear_velocity + angular_velocity.cross(rel)
					var f := maxf(0.0, _k * maxf(comp, 0.0) - _c * pv.dot(up))
					f = minf(f, mass * 80.0)
					apply_force(up * f, rel)
	return grounded


func _detect_impacts(dt: float) -> void:
	var v := linear_velocity
	var expected := _applied / mass * dt
	var jump := v - _prev_v - expected
	jump.y = 0.0
	var dv := jump.length()
	_prev_v = v
	if dv < 3.0 or _contacts.is_empty():
		return
	# contato mais relevante: o que não é chão
	var best = null
	for c in _contacts:
		var nrm: Vector3 = c[2]
		if absf(nrm.y) > 0.8:
			continue
		best = c
		break
	if best == null:
		return
	hit.emit(self, best[0], best[1], dv)


# ------------------------------------------------------------------ dano
func take_damage(point: Vector3, dv: float) -> void:
	var lp := to_local(point)
	health -= dv * 2.0
	# amassa as peças perto do ponto
	if _dent_cd <= 0.0 and dv > 4.0:
		_dent_cd = 0.08
		var dir := Vector3(-lp.x, 0, -lp.z).normalized()
		var depth := clampf(dv * 0.018, 0.05, 0.42)
		for pn in parts:
			var p: Dictionary = parts[pn]
			if p.off:
				continue
			if (p.center as Vector3).distance_to(lp) < 2.2:
				_dent(p, lp, dir, depth, 1.0 + dv * 0.03)
	# peças perdem vida e soltam
	for pn in parts:
		var p: Dictionary = parts[pn]
		if p.off or pn == "body":
			continue
		var d: float = (p.center as Vector3).distance_to(lp)
		if d < 1.8:
			p.hp -= dv * 7.0 * (1.0 - d / 1.8)
			if p.hp <= 0.0 and (pn != "cabin" or wrecked):
				detach(pn, (lp - (p.center as Vector3)).normalized() * -1.0)
	if paint:
		var dmg := clampf(1.0 - health / 100.0, 0.0, 1.0)
		paint.albedo_color = color.lerp(Color(0.18, 0.16, 0.15), dmg * 0.55)
		paint.roughness = 0.35 + dmg * 0.5


func _dent(p: Dictionary, lp: Vector3, dir: Vector3, depth: float, radius: float) -> void:
	var mi: MeshInstance3D = p.mesh
	var inv := mi.transform.affine_inverse()
	var c := inv * lp
	var dm := (inv.basis * dir).normalized()
	var am := ArrayMesh.new()
	for s in p.arrays.size():
		var arr: Array = p.arrays[s]
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var changed := false
		for i in verts.size():
			var dd := verts[i].distance_to(c)
			if dd < radius:
				var f := 1.0 - dd / radius
				f = f * f * (3.0 - 2.0 * f)
				var jit := Vector3(sin(i * 12.9898) , cos(i * 78.233), sin(i * 4.1414)) * 0.035
				verts[i] += (dm * depth + jit) * f
				changed = true
		if changed:
			arr[Mesh.ARRAY_VERTEX] = verts
			_flat_normals(arr)
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(s, p.mats[s])
	mi.mesh = am
	for s in am.get_surface_count():
		mi.set_surface_override_material(s, p.mats[s])


func _flat_normals(arr: Array) -> void:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ind = arr[Mesh.ARRAY_INDEX]
	if ind == null or nrm.size() != verts.size():
		return
	var idx: PackedInt32Array = ind
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var n := (verts[idx[t + 2]] - a).cross(verts[idx[t + 1]] - a).normalized()
		nrm[idx[t]] = n
		nrm[idx[t + 1]] = n
		nrm[idx[t + 2]] = n
	arr[Mesh.ARRAY_NORMAL] = nrm


func detach(pn: String, push := Vector3.ZERO) -> void:
	var p: Dictionary = parts[pn]
	if p.off:
		return
	p.off = true
	var mi: MeshInstance3D = p.mesh
	var copy := mi.duplicate() as MeshInstance3D
	var xf := mi.global_transform
	mi.visible = false
	var c: Vector3 = global_transform * (p.center as Vector3)
	var vel := linear_velocity + angular_velocity.cross(c - global_position)
	vel += (global_transform.basis * push) * randf_range(3, 7) + Vector3.UP * randf_range(4, 9)
	part_off.emit(self, copy, xf, vel, false)


func detach_wheel(w: Dictionary) -> void:
	if w.lost:
		return
	w.lost = true
	var mi: MeshInstance3D = w.mesh
	var copy := mi.duplicate() as MeshInstance3D
	var xf := mi.global_transform
	mi.visible = false
	var side := signf(w.base.x)
	var vel := linear_velocity + global_transform.basis.x * side * randf_range(4, 8) + Vector3.UP * randf_range(4, 8)
	part_off.emit(self, copy, xf, vel, true)


func wreck(power: float, from_dir: Vector3) -> void:
	if wrecked:
		return
	wrecked = true
	wreck_t = 0.0
	drifting = false
	nitroing = false
	angular_damp = 0.15
	var pw := clampf(power / 30.0, 0.5, 1.6)
	var fwd := global_transform.basis.z
	var side := global_transform.basis.x
	apply_central_impulse((Vector3.UP * (6.0 + 6.0 * pw) + from_dir * 5.0) * mass)
	# capota em torno do eixo longitudinal, com um pouco de guinada e cambalhota
	var tq := fwd * randf_range(-1, 1) * 9.0 * pw + side * randf_range(-4, 4) * pw + Vector3.UP * randf_range(-5, 5)
	apply_torque_impulse(tq * mass * 2.2)
	var names := parts.keys().filter(func(k): return k != "body" and not parts[k].off)
	names.shuffle()
	for i in mini(3, names.size()):
		detach(names[i], Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)))
	var ws := wheels.duplicate()
	ws.shuffle()
	for i in randi_range(1, 2):
		detach_wheel(ws[i])


func repair() -> void:
	wrecked = false
	health = 100.0
	angular_damp = 1.2
	for pn in parts:
		var p: Dictionary = parts[pn]
		p.off = false
		p.hp = 100.0
		var mi: MeshInstance3D = p.mesh
		mi.mesh = p.orig
		mi.visible = true
		p.arrays.clear()
		for s in mi.mesh.get_surface_count():
			p.arrays.append(mi.mesh.surface_get_arrays(s))
			mi.set_surface_override_material(s, p.mats[s])
	for w in wheels:
		w.lost = false
		(w.mesh as MeshInstance3D).visible = true
	if paint:
		paint.albedo_color = color
		paint.roughness = 0.35


func place(xform: Transform3D, speed: float) -> void:
	_teleport = {"xform": xform, "vel": xform.basis.z * speed}
	global_transform = xform
	linear_velocity = xform.basis.z * speed
	angular_velocity = Vector3.ZERO
	_prev_v = linear_velocity
	drifting = false
	on_ground = true
	air_t = 0.0
	stun = 0.0
	v_f = speed


# ------------------------------------------------------------------ IA
func ai(track: Track, game: Node, dt: float) -> void:
	var pr := track.project(global_position, ti)
	ti = pr.i
	lat = pr.lat
	var dir := -1.0 if oncoming else 1.0
	var look := 5.0 + maxf(0.0, v_f) * 0.42
	lane_cur += clampf(lane_t - lane_cur, -dt * 4.0, dt * 4.0)
	var tp := track.at(pr.s + look * dir, lane_cur)
	var to: Vector3 = tp.pos - global_position
	ctrl.dir = Vector3(to.x, 0, to.z).normalized()
	ctrl.dir_mag = 1.0
	ctrl.drift = false
	var want := cruise
	if role == "rival":
		var max_c := 0.0
		for k in range(2, 22, 2):
			max_c = maxf(max_c, absf(track.curv[track.idx(pr.i + k)]))
		var lim := sqrt(30.0 / maxf(max_c, 1e-4))
		want = minf(cruise * rubber, lim)
		ctrl.nitro = max_c < 0.012 and v_f > 25.0 and sin(game.time_g * 0.7 + seed_f) > 0.1
		if ctrl.nitro:
			want = sp.nitro
		var p: Car = game.player
		if p and not p.wrecked and global_position.distance_to(p.global_position) < 9.0 and game.time_g > next_bash:
			lane_t = clampf(p.lat, -9.0, 9.0)
			next_bash = game.time_g + randf_range(3, 6)
	var blocked = null
	var bf := 1e9
	var fwd := global_transform.basis.z
	var left := global_transform.basis.x
	for o in game.cars:
		if o == self or o.wrecked:
			continue
		var d: Vector3 = o.global_position - global_position
		var f := d.dot(fwd)
		var sd := d.dot(left)
		if f > 0.0 and f < 10.0 + v_f * 0.5 and absf(sd) < 2.4 and f < bf:
			bf = f
			blocked = o
	if blocked:
		if role == "rival":
			if game.time_g > lane_switch_t:
				var opts := [-2.75, -8.25, 2.75] if lat < 0 else [-2.75, -8.25]
				var best: float = opts[0]
				for l in opts:
					if absf(l - blocked.lat) > absf(best - blocked.lat):
						best = l
				lane_t = best
				lane_switch_t = game.time_g + 1.2
		elif blocked.role != "player":
			want = minf(want, maxf(0.0, blocked.v_f) * 0.9)
	elif role == "rival" and game.time_g > lane_switch_t and lane_t > 0.0:
		lane_t = Track.LANES_FWD[int(seed_f) % 2]
	ctrl.throttle = 1.0 if v_f < want else 0.0
	ctrl.brake = 1.0 if v_f > want + 3.0 else 0.0


# ------------------------------------------------------------------ visual
func _process(dt: float) -> void:
	for w in wheels:
		if w.lost:
			continue
		var mi: MeshInstance3D = w.mesh
		var y: float = w.base.y + SUSP - w.dist + w.r
		mi.position.y = lerpf(mi.position.y, clampf(y, w.base.y - 0.25, w.base.y + SUSP * 0.9), minf(1.0, dt * 25.0))
		w.spin += v_f / maxf(0.2, w.r) * dt
		var st := 0.0
		if w.front:
			st = (-drift_dir * 0.35 + steer_s * 0.2) if drifting else steer_s * 0.42
		mi.rotation = Vector3(w.spin, st, 0)
	if tail_mat:
		tail_mat.emission_energy_multiplier = 6.0 if ctrl.brake > 0.0 else (3.0 if nitroing else 1.5)
	if sirens.size() >= 2:
		var on := sin(game_time * 14.0) > 0.0
		sirens[0].emission_energy_multiplier = 6.0 if on else 0.3
		sirens[1].emission_energy_multiplier = 0.3 if on else 6.0
	visible = invuln <= 0.0 or int(game_time * 16.0) % 2 == 0
