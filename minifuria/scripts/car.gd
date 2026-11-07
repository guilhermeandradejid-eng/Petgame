class_name Car
extends RigidBody3D
## Carro arcade com física de verdade em pista 3D: suspensão por raycast, "gruda" na pista (gravidade ao longo da
## normal do asfalto, para loopings e saca-rolhas), aderência lateral, drift, nitro por cargas, vida, armas e destruição.

signal hit(car: Car, other: Object, point: Vector3, dv: float)
signal part_off(car: Car, mesh: MeshInstance3D, xform: Transform3D, vel: Vector3, is_wheel: bool)
signal landed(car: Car, air_time: float, impact: float)
signal died(car: Car, killer: Car)

const SUSP := 0.38
const GRAV := 9.8 * 2.2

const SPECS := {
	"faisca": {"len": 3.7, "wid": 2.0, "h": 0.62, "clr": 0.34, "mass": 1.0, "vmax": 40.0, "nitro": 58.0, "accel": 26.0, "grip": 9.5, "drift_grip": 1.6, "turn": 2.7, "hp": 100.0},
	"trovao": {"len": 4.1, "wid": 2.1, "h": 0.6, "clr": 0.3, "mass": 1.25, "vmax": 38.0, "nitro": 54.0, "accel": 23.0, "grip": 8.5, "drift_grip": 1.8, "turn": 2.45, "hp": 140.0},
	"vespa": {"len": 3.4, "wid": 2.0, "h": 0.55, "clr": 0.45, "mass": 0.95, "vmax": 42.0, "nitro": 58.0, "accel": 28.0, "grip": 10.0, "drift_grip": 1.7, "turn": 2.95, "hp": 80.0},
	"sedan": {"len": 3.9, "wid": 1.95, "h": 0.66, "clr": 0.3, "mass": 1.0, "vmax": 26.0, "nitro": 26.0, "accel": 12.0, "grip": 8.0, "drift_grip": 2.0, "turn": 2.2, "hp": 60.0},
	"taxi": {"len": 3.9, "wid": 1.95, "h": 0.66, "clr": 0.3, "mass": 1.0, "vmax": 26.0, "nitro": 26.0, "accel": 12.0, "grip": 8.0, "drift_grip": 2.0, "turn": 2.2, "hp": 60.0},
	"policia": {"len": 3.9, "wid": 1.95, "h": 0.66, "clr": 0.3, "mass": 1.1, "vmax": 30.0, "nitro": 30.0, "accel": 14.0, "grip": 8.0, "drift_grip": 2.0, "turn": 2.2, "hp": 70.0},
	"picape": {"len": 4.3, "wid": 2.1, "h": 0.8, "clr": 0.45, "mass": 1.5, "vmax": 24.0, "nitro": 24.0, "accel": 10.0, "grip": 8.0, "drift_grip": 2.0, "turn": 2.0, "hp": 80.0},
	"van": {"len": 4.4, "wid": 2.1, "h": 0.85, "clr": 0.35, "mass": 1.8, "vmax": 22.0, "nitro": 22.0, "accel": 9.0, "grip": 8.0, "drift_grip": 2.0, "turn": 1.9, "hp": 90.0},
}

## equipamentos: valores base por volta (Rock n' Roll Racing: recarregam a cada volta)
const FRONT := {"mg": {"name": "Metralhadora", "cap": 60, "up": 15}, "rocket": {"name": "Lança-foguetes", "cap": 4, "up": 1}}
const REAR := {"mine": {"name": "Minas", "cap": 3, "up": 1}, "oil": {"name": "Óleo", "cap": 3, "up": 1}}
const NITRO := {"short": {"name": "Nitro curto", "cap": 4, "dur": 1.0, "acc": 2.3}, "long": {"name": "Nitro longo", "cap": 2, "dur": 2.6, "acc": 1.7}}

var kind := ""
var role := "traffic"       # player | rival | traffic
var display_name := ""
var sp: Dictionary
var color := Color.RED
var ctrl := {"steer": 0.0, "throttle": 0.0, "brake": 0.0, "drift": false, "nitro": false, "fire": false, "drop": false, "dir": null, "dir_mag": 0.0}

# equipamento e munição
var front_type := "mg"
var rear_type := "mine"
var nitro_type := "short"
var front_cap := 60
var rear_cap := 3
var nitro_cap := 4
var ammo_f := 60
var ammo_r := 3
var nitro_ch := 4
var nitro_t := 0.0
var nitro_meter := 0.0        # manobras enchem: cheio = +1 carga
var fire_cd := 0.0
var drop_cd := 0.0
var engine_mult := 1.0
var max_health := 100.0
var health := 100.0
var grav_factor := 1.0
var grip_factor := 1.0
var _nitro_was := false
var _drop_was := false

var nitroing := false
var v_f := 0.0
var v_s := 0.0
var steer_s := 0.0
var drifting := false
var drift_dir := 0.0
var drift_t := 0.0
var drift_slip := 0.0
var on_ground := true
var on_road := false
var ground_n := Vector3.UP
var ground_pt := Vector3.ZERO
var air_t := 0.0
var stun := 0.0
var oil_t := 0.0
var invuln := 0.0
var wrecked := false
var wreck_t := 0.0
var last_hit_by: Car = null
var last_hit_t := -10.0
var game_time := 0.0
var flash_t := 0.0
var turn_mult := 1.0
var _uturn := 0.0
# informação da pista (preenchida pelo jogo a cada passo)
var track_up := Vector3.UP
var on_feature := false
var feat_type := ""
var track_left := Vector3.RIGHT
var track_tan := Vector3.FORWARD
var in_loop := false
var h_surf := 0.0

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
var ai_skill := 1.0
var ti := -1
var s_track := 0.0
var lat := 0.0
var h_track := 0.0
var dist := 0.0
var prev_s := 0.0
var lap := 0
var nm_state = null
var pad_t := 0.0
var off_t := 0.0
var finished := false
var kills := 0

var model: Node3D
var wheels: Array = []
var parts: Dictionary = {}
var paint: StandardMaterial3D
var tail_mat: StandardMaterial3D
var sirens: Array = []
var exhaust_local := Vector3.ZERO
var tail_local := [Vector3.ZERO, Vector3.ZERO]
var muzzle_local := Vector3.ZERO
var weapon_node: Node3D
var hbar: MeshInstance3D

var _prev_v := Vector3.ZERO
var _applied := Vector3.ZERO
var _contacts: Array = []
var _teleport = null
var _dent_cd := 0.0
var _k := 0.0
var _c := 0.0
var scraping := false
var scrape_pt := Vector3.ZERO
var scrape_n := Vector3.UP
var scrape_v := Vector3.ZERO


func setup(lib: Node3D, kind_: String, role_: String, col: Color) -> void:
	kind = kind_
	role = role_
	color = col
	sp = SPECS[kind]
	mass = 1000.0 * sp.mass
	gravity_scale = 0.0
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
	max_health = sp.hp
	health = max_health

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(sp.wid * 0.94, sp.h + 0.45, sp.len * 0.96)
	cs.shape = box
	cs.position = Vector3(0, sp.clr + (sp.h + 0.45) * 0.5 + 0.02, 0)
	add_child(cs)

	model = lib.get_node("car_" + kind).duplicate()
	model.transform = Transform3D.IDENTITY
	add_child(model)
	var mat_cache := {}
	for ch in model.get_children():
		if not (ch is MeshInstance3D):
			continue
		var mi: MeshInstance3D = ch
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mats: Array = []
		for s in mi.mesh.get_surface_count():
			mats.append(_car_mat(mi.mesh.surface_get_material(s), mat_cache))
			mi.set_surface_override_material(s, mats[s])
		var part_name := String(mi.name).substr(kind.length() + 1)
		if part_name.begins_with("w") and part_name.length() == 3:
			wheels.append({"mesh": mi, "base": mi.position, "front": mi.position.z > 0, "r": mi.position.y,
				"spin": 0.0, "dist": SUSP + mi.position.y, "contact": false, "lost": false, "name": part_name})
		else:
			var arrays: Array = []
			for s in mi.mesh.get_surface_count():
				arrays.append(mi.mesh.surface_get_arrays(s))
			parts[part_name] = {"mesh": mi, "orig": mi.mesh, "arrays": arrays, "mats": mats, "hp": 100.0, "off": false,
				"center": mi.transform * mi.mesh.get_aabb().get_center()}
	var Lc: float = sp.len
	var Wc: float = sp.wid
	exhaust_local = Vector3(Wc * 0.28, sp.clr + 0.12, -(Lc * 0.5 + 0.3))
	var tz: float = sp.clr + sp.h * 0.65
	tail_local = [Vector3(-Wc * 0.32, tz, -Lc * 0.5), Vector3(Wc * 0.32, tz, -Lc * 0.5)]
	muzzle_local = Vector3(0, sp.clr + sp.h + 0.55, Lc * 0.5 + 0.4)
	_k = mass * GRAV / 4.0 / 0.13
	_c = 2.0 * sqrt(_k * mass / 4.0) * 0.55
	if role != "traffic":
		hbar = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2.4, 0.26)
		hbar.mesh = q
		var hm := ShaderMaterial.new()
		hm.shader = load("res://shaders/hbar.gdshader")
		hm.set_shader_parameter("col", color)
		hbar.material_override = hm
		hbar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hbar.position = Vector3(0, 2.6, 0)
		hbar.visible = false
		add_child(hbar)


## arma visível no teto + capacidades por equipamento e upgrades
func configure(lib: Node3D, front: String, rear: String, nitro: String, up: Dictionary) -> void:
	front_type = front
	rear_type = rear
	nitro_type = nitro
	front_cap = int(FRONT[front].cap) + int(FRONT[front].up) * int(up.get("ammo", 0))
	rear_cap = int(REAR[rear].cap) + int(REAR[rear].up) * int(up.get("ammo", 0))
	nitro_cap = int(NITRO[nitro].cap) + int(up.get("nitro", 0))
	engine_mult = 1.0 + 0.04 * int(up.get("engine", 0))
	max_health = sp.hp * (1.0 + 0.2 * int(up.get("armor", 0)))
	health = max_health
	refill()
	if weapon_node:
		weapon_node.queue_free()
	weapon_node = lib.get_node("wpn_gun" if front == "mg" else "wpn_pod").duplicate()
	weapon_node.transform = Transform3D(Basis.IDENTITY, Vector3(0, sp.clr + sp.h + 0.28, sp.len * 0.05))
	for c in weapon_node.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(weapon_node)
	muzzle_local = Vector3(0, sp.clr + sp.h + 0.6, sp.len * 0.05 + 1.1)


func refill() -> void:
	ammo_f = front_cap
	ammo_r = rear_cap
	nitro_ch = nitro_cap


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
			(out as StandardMaterial3D).emission_enabled = true
			(out as StandardMaterial3D).emission = Color.WHITE
			(out as StandardMaterial3D).emission_energy_multiplier = 0.0
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
	flash_t = maxf(0.0, flash_t - dt)
	fire_cd = maxf(0.0, fire_cd - dt)
	drop_cd = maxf(0.0, drop_cd - dt)
	_detect_impacts(dt)
	_applied = Vector3.ZERO
	if freeze:
		air_t = 0.0
		on_ground = true
		_prev_v = Vector3.ZERO
		return
	if wrecked:
		wreck_t += dt
		var f := Vector3.DOWN * GRAV * grav_factor * mass
		apply_central_force(f)
		_applied += f
		_suspension(true)
		return
	invuln = maxf(0.0, invuln - dt)
	stun = maxf(0.0, stun - dt)
	oil_t = maxf(0.0, oil_t - dt)
	var grounded := _suspension(false)
	var was_ground := on_ground
	on_ground = grounded >= 2
	# "ímã" de pista nos loopings, espirais e saca-rolhas (arcade, estilo pista de brinquedo)
	var magnet := on_feature and h_surf < 2.6 and h_surf > -1.2 and linear_velocity.length() > 6.0
	if magnet and h_surf < 1.5:
		on_ground = true
		on_road = true
		ground_n = ground_n.lerp(track_up, 0.6).normalized()
	if magnet and in_loop and h_surf < 3.0:
		# assistência de looping: o carro é guiado pela pista com velocidade mínima
		var spd := maxf(linear_velocity.dot(track_tan), 30.0)
		var lv := track_tan * spd + track_left * linear_velocity.dot(track_left) * 0.8 - track_up * (h_surf - 0.05) * 6.0
		linear_velocity = lv
		var want := Basis(track_left, track_up, track_tan).orthonormalized()
		var dq := (want * global_transform.basis.orthonormalized().inverse()).get_rotation_quaternion()
		var ax := dq.get_axis()
		var ang := dq.get_angle()
		if ang > PI:
			ang -= TAU
		angular_velocity = ax.normalized() * ang * 12.0 if ax.length() > 0.001 else Vector3.ZERO
		v_f = spd
		nitroing = nitro_t > 0.0
		_applied = Vector3.ZERO
		_prev_v = linear_velocity
		on_ground = true
		air_t = 0.0
		return
	if magnet and feat_type == "cork":
		# no saca-rolhas a pista gira em volta do eixo: puxa o carro para o centro
		var cf := -track_left * lat * mass * 9.0 - track_left * linear_velocity.dot(track_left) * mass * 2.0
		apply_central_force(cf)
		_applied += cf
	if not on_ground:
		air_t += dt
	elif not was_ground:
		if air_t > 0.15:
			landed.emit(self, air_t, maxf(0.0, -_prev_v.dot(ground_n)))
		air_t = 0.0

	var b := global_transform.basis
	var up := b.y
	var fwd := b.z
	var v := linear_velocity
	var n := ground_n if on_ground else up
	# gravidade: no asfalto ela puxa contra a pista (gruda nos loopings), no ar é a normal
	var gdir := Vector3.DOWN
	var gmag := GRAV * grav_factor
	if magnet:
		gdir = -track_up
		gmag = GRAV * 1.3
	elif on_ground and on_road and (n.y > 0.35 or v.length() > 11.0):
		gdir = -n
	var gf := gdir * gmag * mass
	apply_central_force(gf)
	_applied += gf

	var fwd_g := (fwd - n * fwd.dot(n)).normalized()
	var left_g := n.cross(fwd_g)
	v_f = v.dot(fwd_g)
	v_s = v.dot(left_g)

	var steer: float = ctrl.steer
	if ctrl.dir != null:
		var d: Vector3 = b.inverse() * (ctrl.dir as Vector3)
		var dh := atan2(d.x, d.z)
		# meia-volta: com o alvo quase atrás, continua girando para o mesmo lado (sem ficar indeciso)
		if absf(dh) > 2.4:
			if _uturn == 0.0:
				_uturn = signf(dh) if absf(steer_s) < 0.1 else signf(steer_s)
			dh = _uturn * absf(dh)
		else:
			_uturn = 0.0
		steer = clampf(dh * 2.4, -1.0, 1.0) * float(ctrl.dir_mag)
		# só inverte quando o jogador está dando ré de propósito (segurando o freio)
		if v_f < -2.0 and ctrl.brake > 0.0:
			steer = -steer
	else:
		_uturn = 0.0
	steer_s = lerpf(steer_s, steer, minf(1.0, dt * 14.0))
	var vmax: float = sp.vmax * engine_mult
	var spd01 := minf(1.0, absf(v_f) / vmax)

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

	# nitro por cargas: um toque = uma arrancada
	nitro_t = maxf(0.0, nitro_t - dt)
	var np: bool = ctrl.nitro
	if np and not _nitro_was and nitro_ch > 0 and nitro_t <= 0.0:
		nitro_ch -= 1
		nitro_t = float(NITRO[nitro_type].dur)
	_nitro_was = np
	nitroing = nitro_t > 0.0
	var nacc: float = NITRO[nitro_type].acc
	var vmax_now: float = (sp.nitro * engine_mult) if nitroing else vmax

	var wy := angular_velocity.dot(up)
	var inertia: float = mass * (sp.len * sp.len + sp.wid * sp.wid) / 12.0
	if on_ground:
		var target := 0.0
		if drifting:
			target = (steer_s * 1.25 + drift_dir * 0.55) * sp.turn * 0.95
		else:
			var rate: float = sp.turn * turn_mult * minf(1.0, absf(v_f) / 5.0) * (1.0 - 0.28 * spd01)
			target = steer_s * rate * (1.0 if v_f >= 0.0 else -1.0)
		var auth := 0.25 if stun > 0.0 else 1.0
		if oil_t > 0.0:
			auth = 0.15
			target += sin(game_time * 9.0) * 2.5
		var k := (5.0 if drifting else 9.0) * auth
		apply_torque(up * (target - wy) * inertia * k)
		var a := 0.0
		if ctrl.throttle > 0.0 and not (ctrl.brake > 0.0 and v_f > 1.0):
			if v_f < vmax_now:
				var f := maxf(0.12, 1.0 - pow(v_f / vmax_now, 2.0))
				a += sp.accel * engine_mult * (nacc if nitroing else 1.0) * ctrl.throttle * f
			else:
				a -= (v_f - vmax_now) * 1.2
		elif ctrl.brake <= 0.0:
			a -= signf(v_f) * minf(absf(v_f) / dt, 4.0) + v_f * 0.08
		if nitroing and v_f < vmax_now:
			a += 6.0
		if ctrl.brake > 0.0:
			if v_f > 0.5:
				a -= 8.0 if drifting else 32.0
			elif v_f > -12.0:
				a -= 16.0
		if drifting:
			a -= v_f * 0.1
		var grip: float = (sp.drift_grip if drifting else sp.grip) * grip_factor
		if stun > 0.0:
			grip *= 0.25
		if oil_t > 0.0:
			grip *= 0.18
		var lost := v_s * (1.0 - exp(-grip * dt))
		if drifting:
			a += absf(lost) / dt * 0.35
		var force := fwd_g * a * mass + left_g * (-lost / dt) * mass
		apply_force(force, -up * 0.15 + b * center_of_mass)
		_applied += force
		var dfc := -up * mass * clampf(absf(v_f) * 0.12, 0, 6)
		apply_central_force(dfc)
		_applied += dfc
	elif nitroing:
		var f := fwd_g * mass * 10.0
		apply_central_force(f)
		_applied += f
	# estabilizador: alinha o carro com a pista (ou com o céu, no ar)
	var target_up := ground_n if on_ground else Vector3.UP
	if magnet:
		target_up = track_up
	var tilt := up.cross(target_up)
	var ang_nyaw := angular_velocity - up * wy
	if magnet:
		# acompanha a rotação da pista na hora (sem isso o carro "descola" no saca-rolhas)
		angular_velocity = up * wy + tilt * 18.0
	else:
		var stab := 22.0 if on_ground else 6.0
		apply_torque((tilt * stab - ang_nyaw * (3.0 if on_ground else 1.0)) * inertia)


func _suspension(wreck_mode: bool) -> int:
	var space := get_world_3d().direct_space_state
	var b := global_transform.basis
	var up := b.y
	var grounded := 0
	var excl := [get_rid()]
	var nsum := Vector3.ZERO
	var psum := Vector3.ZERO
	var road_hits := 0
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
				nsum += res.normal
				psum += res.position
				if res.collider and (res.collider as Node).has_meta("road"):
					road_hits += 1
				if not wreck_mode or up.y > 0.5:
					var rel: Vector3 = mount - global_position
					var pv := linear_velocity + angular_velocity.cross(rel)
					var f := maxf(0.0, _k * maxf(comp, 0.0) - _c * pv.dot(up))
					f = minf(f, mass * 80.0)
					apply_force(up * f, rel)
					_applied += up * f
	if grounded > 0:
		ground_n = ground_n.lerp(nsum.normalized(), 0.5).normalized()
		ground_pt = psum / grounded
	on_road = road_hits >= 2
	return grounded


func _detect_impacts(dt: float) -> void:
	_detect_scrape()
	var v := linear_velocity
	var jump := v - _prev_v - _applied / mass * dt
	var dv := jump.length()
	_prev_v = v
	if dv < 3.0 or _contacts.is_empty():
		return
	var up := global_transform.basis.y
	var best = null
	for c in _contacts:
		var nrm: Vector3 = c[2]
		if not wrecked and nrm.dot(up) > 0.75:
			continue
		best = c
		break
	if best == null:
		return
	hit.emit(self, best[0], best[1], dv)


func _detect_scrape() -> void:
	scraping = false
	if linear_velocity.length() < 5.0:
		return
	var up := global_transform.basis.y
	var best := 0.0
	for c in _contacts:
		var nrm: Vector3 = c[2]
		if not wrecked and nrm.dot(up) > 0.7:
			continue
		var rel := linear_velocity
		if c[0] is RigidBody3D:
			rel -= (c[0] as RigidBody3D).linear_velocity
		var tang := rel - nrm * rel.dot(nrm)
		var spd := tang.length()
		if spd > 4.0 and spd > best:
			best = spd
			scraping = true
			scrape_pt = c[1]
			scrape_n = nrm
			scrape_v = tang


# ------------------------------------------------------------------ dano e vida
## dano de batida física (dv = variação de velocidade no impacto)
func take_impact(point: Vector3, dv: float) -> void:
	var tough := 0.55 if role == "player" else 1.0
	_deform(point, dv)
	var dmg := maxf(0.0, dv - 7.0) * 1.7 * tough
	if dmg > 0.0:
		apply_damage(dmg, point, last_hit_by if game_time - last_hit_t < 1.5 else null, false)


## dano de qualquer fonte (armas, batidas). Retorna true se destruiu o carro.
func apply_damage(amount: float, point: Vector3, attacker: Car, deform := true) -> bool:
	if wrecked or invuln > 0.0 or amount <= 0.0:
		return false
	health -= amount
	flash_t = 0.12
	if attacker:
		last_hit_by = attacker
		last_hit_t = game_time
	if deform:
		_deform(point, amount * 0.6 + 4.0)
	if paint:
		var dmg := clampf(1.0 - health / max_health, 0.0, 1.0)
		paint.albedo_color = color.lerp(Color(0.18, 0.16, 0.15), dmg * 0.55)
		paint.roughness = 0.24 + dmg * 0.5
	if health <= 0.0:
		health = 0.0
		died.emit(self, attacker)
		return true
	return false


func _deform(point: Vector3, dv: float) -> void:
	var lp := to_local(point)
	if _dent_cd <= 0.0 and dv > 4.0:
		_dent_cd = 0.08
		var dir := Vector3(-lp.x, 0, -lp.z).normalized()
		var depth := clampf(dv * 0.016, 0.04, 0.38)
		for pn in parts:
			var p: Dictionary = parts[pn]
			if p.off:
				continue
			if (p.center as Vector3).distance_to(lp) < 2.2:
				_dent(p, lp, dir, depth, 1.0 + dv * 0.03)
	var tough := 0.5 if role == "player" else 1.0
	for pn in parts:
		var p: Dictionary = parts[pn]
		if p.off or pn == "body":
			continue
		var d: float = (p.center as Vector3).distance_to(lp)
		if d < 1.8:
			p.hp -= dv * 6.0 * tough * (1.0 - d / 1.8)
			if p.hp <= 0.0 and (pn != "cabin" or wrecked):
				detach(pn, (lp - (p.center as Vector3)).normalized() * -1.0)


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
				var jit := Vector3(sin(i * 12.9898), cos(i * 78.233), sin(i * 4.1414)) * 0.035
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
	vel += (global_transform.basis * push) * randf_range(3, 7) + global_transform.basis.y * randf_range(4, 9)
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
	var vel := linear_velocity + global_transform.basis.x * side * randf_range(4, 8) + global_transform.basis.y * randf_range(4, 8)
	part_off.emit(self, copy, xf, vel, true)


func wreck(power: float, from_dir: Vector3) -> void:
	if wrecked:
		return
	wrecked = true
	wreck_t = 0.0
	drifting = false
	nitroing = false
	nitro_t = 0.0
	angular_damp = 0.15
	var pw := clampf(power / 30.0, 0.5, 1.4)
	var fwd := global_transform.basis.z
	var side := global_transform.basis.x
	var up := global_transform.basis.y
	apply_central_impulse((up * (5.0 + 5.0 * pw) + from_dir * 4.0) * mass)
	var tq := fwd * randf_range(-1, 1) * 8.0 * pw + side * randf_range(-4, 4) * pw + up * randf_range(-5, 5)
	apply_torque_impulse(tq * mass * 2.0)
	var names := parts.keys().filter(func(k): return k != "body" and not parts[k].off)
	names.shuffle()
	for i in mini(randi_range(1, 3), names.size()):
		detach(names[i], Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)))
	if randf() < 0.6:
		var ws := wheels.duplicate()
		ws.shuffle()
		detach_wheel(ws[0])


func repair() -> void:
	wrecked = false
	health = max_health
	angular_damp = 1.2
	oil_t = 0.0
	stun = 0.0
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
		paint.roughness = 0.24


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
	off_t = 0.0
	ground_n = xform.basis.y
	v_f = speed


# ------------------------------------------------------------------ IA
func ai(track: Track, game: Node, dt: float) -> void:
	var pr := track.project(global_position, ti)
	ti = pr.i
	lat = pr.lat
	var dir := -1.0 if oncoming else 1.0
	var look := 5.0 + maxf(0.0, v_f) * 0.42
	var lt := lane_t
	var ahead := track.idx(pr.i + int(look / track.ds))
	if track.ftype[ahead] == "cork" or track.ftype[pr.i] == "cork" or track.ftype[ahead] == "loop":
		lt = 0.0
	lane_cur += clampf(lt - lane_cur, -dt * 6.0, dt * 6.0)
	var tp := track.at(pr.s + look * dir, lane_cur)
	var to: Vector3 = tp.pos - global_position
	ctrl.dir = to.normalized()
	ctrl.dir_mag = 1.0
	ctrl.drift = false
	var want := cruise
	if role == "rival":
		var max_c := 0.0
		var special := false
		for k in range(2, 26, 2):
			var j := track.idx(pr.i + k)
			max_c = maxf(max_c, absf(track.curv[j]))
			if track.feat[j] == 1:
				special = true
		var lim := sqrt(30.0 / maxf(max_c, 1e-4))
		want = minf(cruise * rubber * ai_skill, lim)
		if special:
			want = maxf(want, 32.0)   # loopings e saltos pedem velocidade
		ctrl.nitro = max_c < 0.01 and v_f > 25.0 and nitro_ch > 0 and sin(game.time_g * 0.5 + seed_f) > 0.6
		var p: Car = game.player
		if p and not p.wrecked and global_position.distance_to(p.global_position) < 9.0 and game.time_g > next_bash:
			lane_t = clampf(p.lat, -track.HALF + 2.0, track.HALF - 2.0)
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
		if f > 0.0 and f < 10.0 + v_f * 0.5 and absf(sd) < 2.4 and absf(d.dot(global_transform.basis.y)) < 3.0 and f < bf:
			bf = f
			blocked = o
	if blocked:
		if role == "rival":
			if game.time_g > lane_switch_t:
				var opts: Array = [track.lanes_fwd[0], track.lanes_fwd[1], track.lanes_onc[0], track.lanes_onc[1]]
				var best: float = opts[0]
				for l in opts:
					if absf(l - blocked.lat) > absf(best - blocked.lat):
						best = l
				lane_t = best
				lane_switch_t = game.time_g + 1.2
		elif blocked.role != "player":
			want = minf(want, maxf(0.0, blocked.v_f) * 0.9)
	elif role == "rival" and game.time_g > lane_switch_t and track.data.traffic > 0 and lane_t > 0.0:
		lane_t = track.lanes_fwd[int(seed_f) % 2]
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
	if paint:
		paint.emission_energy_multiplier = 3.0 if flash_t > 0.0 else 0.0
	if sirens.size() >= 2:
		var on := sin(game_time * 14.0) > 0.0
		sirens[0].emission_energy_multiplier = 6.0 if on else 0.3
		sirens[1].emission_energy_multiplier = 0.3 if on else 6.0
	if hbar:
		hbar.visible = not wrecked and health < max_health * 0.999
		if hbar.visible:
			(hbar.material_override as ShaderMaterial).set_shader_parameter("ratio", health / max_health)
	visible = invuln <= 0.0 or int(game_time * 16.0) % 2 == 0
