class_name Car
extends RigidBody3D
## Carro arcade com física de verdade em pista 3D: suspensão por raycast, "gruda" na pista (gravidade ao longo da
## normal do asfalto, para loopings e saca-rolhas), aderência lateral, drift, nitro por cargas, vida, armas e destruição.

signal hit(car: Car, other: Object, point: Vector3, dv: float)
signal part_off(car: Car, mesh: MeshInstance3D, xform: Transform3D, vel: Vector3, is_wheel: bool)
signal landed(car: Car, air_time: float, impact: float)
signal died(car: Car, killer: Car)

const SUSP := 0.38
# mola mais longa que o curso: em repouso o carro fica na altura do modelo (roda dentro da caixa de roda,
# sem a carroceria "sentar" em cima do pneu); o batente segura as compressões fortes
const PRELOAD := 0.11
const BUMP := 0.12
const WHEEL_UP := 0.05   # quanto a roda pode subir visualmente antes de encostar no para-lama
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
var road_half := 9.0
var track_ref: Track = null
var guided_spd := 0.0
var _susp_forces := true
var jump_cd := 0.0
var _jump_armed := true
var launch_t := 0.0     # largada: pneus cantando e fumaça
var fall_t := 0.0
var oily_t := 0.0      # pneus sujos de graxa: deixam rastro escuro por um tempo
var _hard_t := 0.0      # tempo de curva forte (auto-drift)
var _dh := 0.0
# "game juice" visual: amassa ao pousar, estica e empina no nitro (mola amortecida, só no modelo)
var squash := 0.0
var squash_v := 0.0
var pitch_kick := 0.0
var pitch_v := 0.0
var _nitro_vis := false
var ghost_t := 0.0   # nos trechos guiados os carros se atravessam (sem engavetar nem "estourar" na saída)

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
var stuck_t := 0.0
var finished := false
var kills := 0

var model: Node3D
var wheels: Array = []
var parts: Dictionary = {}
var paint: StandardMaterial3D
var tail_mat: StandardMaterial3D
var sirens: Array = []
var exhaust_local := Vector3.ZERO
var exhaust2_local := Vector3.ZERO
var mount_local := Vector3.ZERO
var tail_local := [Vector3.ZERO, Vector3.ZERO]
var muzzle_local := Vector3.ZERO
var weapon_node: Node3D
var weapon_base := Vector3.ZERO
var recoil := 0.0
var firing_t := 0.0
var casings: CPUParticles3D
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
	center_of_mass = Vector3(0, 0.3, 0)   # centro de massa baixo: mais "peso", difícil de capotar
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
	pm.bounce = 0.02
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
	exhaust_local = Vector3(Wc * 0.26, sp.clr - 0.03, -(Lc * 0.5 + 0.38))
	exhaust2_local = Vector3(-Wc * 0.26, sp.clr - 0.03, -(Lc * 0.5 + 0.38))
	mount_local = Vector3(0, sp.clr + sp.h + 0.6, -0.2)
	# pontos marcados no modelo (Blender): ponteiras do escapamento e base da arma no teto
	var exr := model.get_node_or_null(kind + "_exR") as Node3D
	var exl := model.get_node_or_null(kind + "_exL") as Node3D
	var mnt := model.get_node_or_null(kind + "_mount") as Node3D
	if exr:
		exhaust_local = exr.position
	if exl:
		exhaust2_local = exl.position
	if mnt:
		mount_local = mnt.position
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
	# arma parafusada no teto (ponto "_mount" do modelo), sem atravessar cabine nem para-brisa
	weapon_base = mount_local
	weapon_node.transform = Transform3D(Basis.IDENTITY, weapon_base)
	for c in weapon_node.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(weapon_node)
	muzzle_local = weapon_base + (Vector3(0, 0.32, 1.1) if front == "mg" else Vector3(0, 0.3, 0.55))


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
		call_deferred("reset_physics_interpolation")
		_prev_v = state.linear_velocity
	_contacts.clear()
	for i in state.get_contact_count():
		_contacts.append([state.get_contact_collider_object(i), state.get_contact_local_position(i), state.get_contact_local_normal(i)])


func _physics_process(dt: float) -> void:
	game_time += dt
	_visuals(dt)
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
		collision_layer = 2
		collision_mask = 1 | 2 | 4
		ghost_t = 0.0
		wreck_t += dt
		var f := Vector3.DOWN * GRAV * grav_factor * mass
		apply_central_force(f)
		_applied += f
		_suspension(true)
		return
	invuln = maxf(0.0, invuln - dt)
	stun = maxf(0.0, stun - dt)
	oil_t = maxf(0.0, oil_t - dt)
	_wall_hold()
	var guided := on_feature and (in_loop or feat_type == "cork") and h_surf < 3.0 and h_surf > -1.5 and track_ref != null
	_susp_forces = not guided
	var grounded := _suspension(false)
	_susp_forces = true
	var was_ground := on_ground
	on_ground = grounded >= 2
	jump_cd = maxf(0.0, jump_cd - dt)
	if on_ground:
		_jump_armed = true
	elif _jump_armed and feat_type == "jump" and track_ref != null and jump_cd <= 0.0:
		_jump_assist()
	# "ímã" de pista nos loopings, espirais e saca-rolhas (arcade, estilo pista de brinquedo)
	var magnet := on_feature and h_surf < 2.6 and h_surf > -1.2 and linear_velocity.length() > 6.0
	if magnet and h_surf < 1.5:
		on_ground = true
		on_road = true
		ground_n = ground_n.lerp(track_up, 0.6).normalized()
	# no trecho guiado a carroceria não colide com o asfalto (as rodas continuam lendo a pista):
	# assim nenhuma emenda ou quina do colisor segura o carro. Os carros também viram "fantasmas"
	# entre si (camada 16) ali e por meio segundo depois, para não se empurrarem para fora da pista.
	ghost_t = 0.5 if guided else maxf(0.0, ghost_t - dt)
	var want_layer := 16 if ghost_t > 0.0 else 2
	var want_mask := 4 if guided else ((1 | 4) if ghost_t > 0.0 else (1 | 2 | 4))
	if collision_layer != want_layer:
		collision_layer = want_layer
	if collision_mask != want_mask:
		collision_mask = want_mask
	if guided:
		# looping e torção guiados: o carro segue a pista com velocidade mínima, sem engasgar nas emendas
		# a rapidez é guardada à parte (entra com a do carro e não perde nada nas emendas)
		var spd := maxf(guided_spd, 30.0 if in_loop else 28.0)
		if nitro_t > 0.0:
			spd = move_toward(spd, maxf(spd, sp.nitro * engine_mult * 0.9), 40.0 * dt)
		spd = minf(spd, 58.0)
		guided_spd = spd
		# lateral só por posição (sem reaproveitar v·L medido: num looping com deslocamento lateral
		# essa leitura carrega o giro do referencial e empurraria o carro para fora da pista)
		var lim := road_half - 1.6
		var lat_target := -lat * 0.25
		if role == "player":
			if ctrl.dir == null:
				lat_target += ctrl.steer * 5.0   # direção clássica: dá para desviar para os lados
		else:
			lat_target = (clampf(lane_cur, -lim, lim) - lat) * 1.2
		if absf(lat) > lim:
			lat_target = minf(lat_target, -(absf(lat) - lim) * 3.0 - 1.0) if lat > 0.0 else maxf(lat_target, (absf(lat) - lim) * 3.0 + 1.0)
		# segue a pista exatamente: mira o ponto onde o carro deve estar no próximo quadro
		# (s + v·dt, faixa e altura suavizadas), então não sobra erro para acumular entre quadros
		var lat_next := clampf(lat + clampf(lat_target, -8.0, 8.0) * dt, -road_half + 1.2, road_half - 1.2)
		var h_next := lerpf(h_surf, 0.0, 0.3)
		var nx := track_ref.at(s_track + spd * dt, lat_next)
		var target: Vector3 = nx.pos + (nx.up as Vector3) * h_next
		var lv := (target - global_position) / dt
		if lv.length() > spd * 1.6 + 6.0:
			lv = lv.normalized() * (spd * 1.6 + 6.0)
		linear_velocity = lv
		var want: Basis = (nx.basis as Basis).orthonormalized()
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
	guided_spd = maxf(0.0, linear_velocity.dot(track_tan))
	if magnet and feat_type == "cork":
		# no saca-rolhas a pista gira em volta do eixo: puxa o carro para o centro
		var cf := -track_left * lat * mass * 9.0 - track_left * linear_velocity.dot(track_left) * mass * 2.0
		apply_central_force(cf)
		_applied += cf
	if not on_ground:
		if h_surf > 0.7 or not on_feature:
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
		_dh = dh
		# só inverte quando o jogador está dando ré de propósito (segurando o freio)
		if v_f < -2.0 and ctrl.brake > 0.0:
			steer = -steer
	else:
		_uturn = 0.0
	steer_s = lerpf(steer_s, steer, minf(1.0, dt * 14.0))
	var vmax: float = sp.vmax * engine_mult
	var spd01 := minf(1.0, absf(v_f) / vmax)

	# auto-drift: curva forte em velocidade entra sozinha num drift suave (sem botão)
	var demand: float = (absf(_dh) / 0.8) if ctrl.dir != null else (absf(ctrl.steer) / 0.9)
	if on_ground and v_f > 19.0 and demand >= 1.0 and not on_feature:
		_hard_t += dt
	else:
		_hard_t = maxf(0.0, _hard_t - dt * 2.0)
	var want_drift: bool = ctrl.drift or _hard_t > 0.14
	if not drifting and on_ground and want_drift and v_f > 15.0 and absf(steer_s) > 0.3:
		drifting = true
		drift_dir = signf(steer_s)
		drift_t = 0.0
		angular_velocity += up * drift_dir * 0.55
	if drifting:
		drift_t += dt
		drift_slip = absf(atan2(v_s, maxf(1.0, v_f)))
		var holding: bool = ctrl.drift or (steer_s * drift_dir > 0.35 and demand > 0.55)
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
	# descidas embalam (e subidas freiam menos): a gravidade "de verdade" ao longo da rampa
	var slope_a := 0.0
	if on_ground and not magnet and not on_feature:
		var gw := Vector3.DOWN * GRAV * grav_factor
		var gt := gw - n * gw.dot(n)
		var along := gt.dot(fwd_g)
		slope_a = along * (1.7 if along > 0.0 else 0.55)
		vmax_now += maxf(0.0, slope_a) * 0.9
	launch_t = maxf(0.0, launch_t - dt)
	oily_t = maxf(0.0, oily_t - dt)

	var wy := angular_velocity.dot(up)
	var inertia: float = mass * (sp.len * sp.len + sp.wid * sp.wid) / 12.0
	if on_ground:
		var target := 0.0
		if drifting:
			target = (steer_s * 1.15 + drift_dir * 0.4) * sp.turn * 0.95
		else:
			var rate: float = sp.turn * turn_mult * minf(1.0, absf(v_f) / 5.0) * (1.0 - 0.28 * spd01)
			target = steer_s * rate * (1.0 if v_f >= 0.0 else -1.0)
		var auth := 0.25 if stun > 0.0 else 1.0
		if oil_t > 0.0:
			# perda de controle: rabeia de um lado para o outro, mais forte logo ao entrar
			auth = 0.15
			target += sin(game_time * 7.5) * 2.8 * clampf(oil_t / 1.1, 0.3, 1.0)
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
		a += slope_a
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
		var dfc := -up * mass * clampf(absf(v_f) * 0.2, 0, 10)   # pressão aerodinâmica: cola no chão
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
		var stab := 30.0 if on_ground else 10.0   # no ar o carro se nivela (pousa de rodas)
		# peso: amortece capotar/empinar (não a virada), então o carro não "bóia" nas batidas
		apply_torque((tilt * stab - ang_nyaw * (4.5 if on_ground else 1.8)) * inertia)


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
			if comp > -0.03 - PRELOAD:
				w.contact = true
				grounded += 1
				nsum += res.normal
				psum += res.position
				if res.collider and (res.collider as Node).has_meta("road"):
					road_hits += 1
				if (not wreck_mode or up.y > 0.5) and _susp_forces:
					var rel: Vector3 = mount - global_position
					var pv := linear_velocity + angular_velocity.cross(rel)
					var f := maxf(0.0, _k * maxf(comp + PRELOAD, 0.0) - _c * pv.dot(up))
					if comp > BUMP:
						f += _k * 6.0 * (comp - BUMP) - _c * 1.5 * minf(0.0, pv.dot(up))
					f = minf(f, mass * 130.0)
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
func take_impact(point: Vector3, dv: float, wall := false) -> void:
	var tough := 0.55 if role == "player" else 1.0
	if wall:
		tough *= 0.45   # raspar/bater na mureta amassa, mas raramente destrói
	_deform(point, dv * (0.7 if wall else 1.0))
	var dmg := maxf(0.0, dv - (10.0 if wall else 7.5)) * 1.5 * tough
	if dmg > 0.0:
		apply_damage(dmg, point, last_hit_by if game_time - last_hit_t < 1.5 else null, false)


## dano de qualquer fonte (armas, batidas). Retorna true se destruiu o carro.
func apply_damage(amount: float, point: Vector3, attacker: Car, deform := true) -> bool:
	if wrecked or invuln > 0.0 or amount <= 0.0:
		return false
	health -= amount
	flash_t = 0.06
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


func wreck(power: float, from_dir: Vector3, pop := true) -> void:
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
	if pop:
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


## encostado na mureta: o carro não "sobe" nela nem é lançado para fora (tira a velocidade para cima
## e o giro de capotagem), e devolve parte da velocidade ao longo da pista
func _wall_hold() -> void:
	if wrecked:
		return
	var touching := false
	for c in _contacts:
		var ob: Object = c[0]
		if ob is Node and (ob as Node).has_meta("rail"):
			touching = true
			break
	if not touching:
		return
	var up := track_up
	var vu := linear_velocity.dot(up)
	if vu > 1.0:
		linear_velocity -= up * (vu - 1.0) * 0.85
	var b := global_transform.basis
	var yaw := angular_velocity.dot(b.y)
	angular_velocity = angular_velocity.lerp(b.y * yaw, 0.5)


## salto assistido (arcade): na decolagem o carro sai alinhado com a pista e com a rapidez mínima
## para cair na rampa de pouso (sem pousar torto na mureta nem cair no vão por falta de embalo)
func _jump_assist() -> void:
	var tr := track_ref
	var j := ti
	var k := 0
	# só na ponta da rampa (o vão começa logo à frente): um pulinho no começo da rampa não conta
	while k < 5 and tr.gap[tr.idx(j)] == 0:
		j += 1
		k += 1
	if tr.gap[tr.idx(j)] == 0:
		return
	if h_surf < -0.5:
		return   # já caiu abaixo da rampa: não dá mais para salvar
	_jump_armed = false
	while k < 60 and tr.gap[tr.idx(j)] == 1:
		j += 1
		k += 1
	jump_cd = 1.2
	var li := tr.idx(j + 6)
	var land: Vector3 = tr.P[li] + tr.L[li] * clampf(lat, -road_half * 0.4, road_half * 0.4)
	var to := land - global_position
	var D := Vector2(to.x, to.z).length()
	var G := GRAV * grav_factor
	var v := linear_velocity
	var vy := maxf(v.y, 5.5)   # arco mínimo: salto "de verdade", não um pulinho
	# tempo de voo até a altura do pouso: vy·t − ½·G·t² = Δy (se o pouso estiver acima do ápice, usa o ápice)
	var disc := vy * vy - 2.0 * G * to.y
	var tf := (vy + sqrt(maxf(disc, 0.0))) / G
	var need := D / maxf(tf, 0.2)
	var vh := Vector2(v.x, v.z).length()
	var hd := Vector3(to.x, 0, to.z).normalized()
	var newh := clampf(maxf(vh, need), 0.0, maxf(vh, 8.0) * 1.5 + 6.0)
	if OS.get_cmdline_user_args().has("--debugjump"):
		print("JUMP %s s=%d k=%d D=%.1f dy=%.1f vy=%.1f tf=%.2f vh=%.1f need=%.1f new=%.1f ang=%.0f" % [display_name, int(s_track), k, D, to.y, v.y, tf, vh, need, newh, rad_to_deg(Vector2(v.x, v.z).angle_to(Vector2(to.x, to.z)))])
	linear_velocity = hd * newh + Vector3.UP * vy
	angular_velocity = Vector3.ZERO   # sai reto da rampa (sem cambalhota)


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
		lt = clampf(lane_t, -3.5, 3.5)   # nos loopings e torções cada um mantém sua faixa (sem engavetar no meio)
	elif track.ftype[ahead] == "jump" or track.ftype[pr.i] == "jump":
		lt = clampf(lane_t, -2.5, 2.5)   # salto pelo meio da rampa
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
			if track.feat[j] == 1 and (track.ftype[j] == "loop" or track.ftype[j] == "jump" or track.ftype[j] == "cork"):
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
func juice_squash(amount: float) -> void:
	squash_v += amount


func juice_pitch(amount: float) -> void:
	pitch_v += amount


## visual do carro (rodas, suspensão, "squash", recuo da arma): roda no passo de física para a
## interpolação de física desenhar tudo junto, sem "soquinhos"
func _visuals(dt: float) -> void:
	if model and not wrecked:
		if nitroing and not _nitro_vis:
			juice_squash(-1.6)   # estica para a frente
			juice_pitch(0.9)     # empina o nariz
		_nitro_vis = nitroing
		squash_v += (-squash * 160.0 - squash_v * 11.0) * dt
		squash = clampf(squash + squash_v * dt, -0.16, 0.2)
		pitch_v += (-pitch_kick * 120.0 - pitch_v * 10.0) * dt
		pitch_kick = clampf(pitch_kick + pitch_v * dt, -0.12, 0.12)
		model.scale = Vector3(1.0 + squash * 0.45, 1.0 - squash, 1.0 - squash * 0.35)
		model.rotation.x = -pitch_kick
	for w in wheels:
		if w.lost:
			continue
		var mi: MeshInstance3D = w.mesh
		var y: float = w.base.y + SUSP - w.dist + w.r
		mi.position.y = lerpf(mi.position.y, clampf(y, w.base.y - 0.25, w.base.y + WHEEL_UP), minf(1.0, dt * 25.0))
		# giro visível: acima de ~3 voltas/s o olho vê o raio "parado" (efeito estroboscópico);
		# o giro desenhado é limitado para os raios sempre parecerem girar para a frente
		var wspin: float = (v_f + (35.0 if launch_t > 0.0 and not w.front else 0.0)) / maxf(0.2, w.r)
		w.spin += clampf(wspin, -19.0, 19.0) * dt
		var st := 0.0
		if w.front:
			st = (-drift_dir * 0.28 + steer_s * 0.14) if drifting else steer_s * 0.32
		mi.rotation = Vector3(w.spin, st, 0)
	if tail_mat:
		tail_mat.emission_energy_multiplier = 6.0 if ctrl.brake > 0.0 else (3.0 if nitroing else 1.5)
	if paint:
		paint.emission_energy_multiplier = 0.9 if flash_t > 0.0 else 0.0
	if sirens.size() >= 2:
		var on := sin(game_time * 14.0) > 0.0
		sirens[0].emission_energy_multiplier = 6.0 if on else 0.3
		sirens[1].emission_energy_multiplier = 0.3 if on else 6.0
	# recuo da arma a cada tiro
	recoil = maxf(0.0, recoil - dt * 9.0)
	firing_t = maxf(0.0, firing_t - dt)
	if weapon_node:
		weapon_node.position = weapon_base - Vector3(0, 0, recoil * 0.18) + Vector3(0, recoil * 0.03, 0)
		weapon_node.rotation.x = -recoil * 0.12
	if casings:
		casings.emitting = firing_t > 0.0 and not wrecked
	if hbar:
		hbar.visible = not wrecked and health < max_health * 0.999
		if hbar.visible:
			(hbar.material_override as ShaderMaterial).set_shader_parameter("ratio", health / max_health)
	visible = invuln <= 0.0 or int(game_time * 16.0) % 2 == 0
