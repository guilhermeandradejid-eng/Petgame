class_name Enemy
extends CharacterBody3D
## Capmook & friends. Simulated on the host only; clients render replicated state.

enum S { IDLE, CHASE, WINDUP, ATTACK, RECOVER, HURT, DEAD }

var data: EnemyData
var sprite: SpriteActor
var hp := 60
var state := S.IDLE
var st := 0
var hitstop := 0
var target: Player
var facing := 1.0
var hit_set: Array = []
var _contact := Vector2i(-1, -1)
var _wander_t := 0
var _wander_dir := Vector3.ZERO
var _launched := false
var _hurt_len := 14
var _bar_t := 0.0
var _bar_bg: MeshInstance3D
var _bar_fg: MeshInstance3D
var _dissolve := 0.0
var _last_hitter := 0
var _rng := RandomNumberGenerator.new()
# replicated
var net_pos := Vector3.ZERO
var sync_anim := "idle"
var sync_tick := 0
var sync_face := 1.0
var sync_hp := 60
var sync_dissolve := 0.0
var sync_glow := 0.0


func _ready() -> void:
	add_to_group("enemies")
	set_multiplayer_authority(1)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	hp = data.max_hp
	_rng.seed = hash(name)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = data.radius_m * 0.8
	cap.height = 1.0
	cs.shape = cap
	cs.position.y = 0.5
	add_child(cs)
	sprite = SpriteActor.new()
	sprite.name = "Sprite"
	add_child(sprite)
	sprite.setup(data.sprite_id, 0.95)
	sprite.play("idle")
	_make_bar()
	net_pos = global_position
	var cfg := SceneReplicationConfig.new()
	for p in [":net_pos", ":sync_anim", ":sync_tick", ":sync_face", ":sync_hp", ":sync_dissolve", ":sync_glow"]:
		var np := NodePath(p)
		cfg.add_property(np)
		cfg.property_set_replication_mode(np, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 30.0
	add_child(sync)
	if data.dummy:
		var l := Label3D.new()
		l.text = "TRAINING DUMMY"
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = 0.007
		l.font_size = 32
		l.outline_size = 8
		l.position = Vector3(0, 1.75, 0)
		l.modulate = Color(1, 0.95, 0.7)
		add_child(l)


func is_dead() -> bool:
	return state == S.DEAD


func _make_bar() -> void:
	var mk := func(col: Color, w: float) -> MeshInstance3D:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(w, 0.09)
		m.mesh = q
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mt.albedo_color = col
		mt.no_depth_test = true
		mt.render_priority = 5
		m.material_override = mt
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		return m
	_bar_bg = mk.call(Color(0.1, 0.05, 0.12), 0.84)
	_bar_fg = mk.call(Color(1.0, 0.45, 0.25), 0.8)
	_bar_bg.position = Vector3(0, 1.45, 0)
	_bar_fg.position = Vector3(0, 1.45, 0.001)


# ----------------------------------------------------------------- ticking

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		_remote_tick()
		return
	if hitstop > 0:
		hitstop -= 1
		sprite.shake_px = 0.07
		_publish()
		return
	sprite.shake_px = 0.0
	match state:
		S.IDLE: _tick_idle()
		S.CHASE: _tick_chase()
		S.WINDUP: _tick_windup()
		S.ATTACK: _tick_attack()
		S.RECOVER: _tick_recover()
		S.HURT: _tick_hurt()
		S.DEAD: _tick_dead()
	st += 1
	sprite.advance()
	_publish()


func _publish() -> void:
	net_pos = global_position
	sync_anim = sprite.anim
	sync_tick = sprite.tick
	sync_face = facing
	sync_hp = hp
	sync_dissolve = _dissolve
	sync_glow = 1.0 if state == S.WINDUP or (state == S.ATTACK and st < 14) else 0.0


func _remote_tick() -> void:
	global_position = global_position.lerp(net_pos, 0.35)
	facing = sync_face
	sprite.set_facing(sync_face)
	hp = sync_hp
	if sprite.anim != sync_anim or absi(sprite.tick - sync_tick) > 3:
		sprite.set_pose(sync_anim, sync_tick)
	else:
		sprite.advance()
	sprite.set_param("dissolve", sync_dissolve)
	sprite.set_param("glow", sync_glow)


func _process(delta: float) -> void:
	if _bar_t > 0.0:
		_bar_t -= delta
		var ratio := clampf(float(hp) / float(data.max_hp), 0.0, 1.0)
		var show := _bar_t > 0.0 and not data.dummy and hp > 0
		_bar_bg.visible = show
		_bar_fg.visible = show
		_bar_fg.scale.x = maxf(ratio, 0.001)
		_bar_fg.position.x = -0.4 * (1.0 - ratio)
	elif _bar_bg.visible:
		_bar_bg.visible = false
		_bar_fg.visible = false
	if multiplayer.is_server():
		sprite.set_param("glow", (0.55 + 0.45 * sin(Game.tick * 0.7)) if (state == S.WINDUP) else 0.0)
	# telegraph blink while winding up


func _players() -> Array:
	var out: Array = []
	for p in get_tree().get_nodes_in_group("players"):
		if not p.is_dead():
			out.append(p)
	return out


func _nearest_player(max_d: float) -> Player:
	var best: Player = null
	var bd := max_d
	for p in _players():
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		var dist: float = d.length()
		if p.get("last_hit_enemy") == self:
			dist *= 0.7
		if dist < bd:
			bd = dist
			best = p
	return best


func _face_target() -> void:
	if target != null and is_instance_valid(target):
		var dx := target.global_position.x - global_position.x
		if absf(dx) > 0.05:
			facing = signf(dx)
			sprite.set_facing(facing)


func _move(vel: Vector3, rate: float = 0.5) -> void:
	velocity.x = move_toward(velocity.x, vel.x, rate)
	velocity.z = move_toward(velocity.z, vel.z, rate)
	if not is_on_floor():
		velocity.y -= Game.GRAVITY / Game.TICK_RATE
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	var lim := Game.ARENA_HALF
	global_position.x = clampf(global_position.x, -lim, lim)
	global_position.z = clampf(global_position.z, -lim, lim)


func _set_state(s: S) -> void:
	state = s
	st = -1


func _tick_idle() -> void:
	sprite.play("idle")
	if data.dummy:
		_move(Vector3.ZERO, 0.6)
		return
	target = _nearest_player(data.aggro_m)
	if target != null:
		Juice.alert(global_position + Vector3(0, 1.8, 0))
		rpc("rpc_alert")
		_set_state(S.CHASE)
		return
	_wander_t -= 1
	if _wander_t <= 0:
		_wander_t = _rng.randi_range(50, 120)
		_wander_dir = Vector3.ZERO if _rng.randf() < 0.4 else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	if _wander_dir != Vector3.ZERO:
		sprite.play("walk")
		facing = signf(_wander_dir.x) if absf(_wander_dir.x) > 0.1 else facing
		sprite.set_facing(facing)
	_move(_wander_dir * data.speed * 0.4, 0.2)


func _tick_chase() -> void:
	if target == null or not is_instance_valid(target) or target.is_dead():
		target = _nearest_player(data.aggro_m * 1.5)
		if target == null:
			_set_state(S.IDLE)
			return
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > data.aggro_m * 2.2:
		target = null
		_set_state(S.IDLE)
		return
	sprite.play("walk")
	_face_target()
	# separation from other enemies
	var sep := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and not e.is_dead():
			var d: Vector3 = global_position - e.global_position
			d.y = 0.0
			if d.length() < 1.2 and d.length() > 0.01:
				sep += d.normalized() * (1.2 - d.length())
	if dist <= data.attack_range_m and _attack_slot_free():
		_set_state(S.WINDUP)
		sprite.play("windup", true)
		Sfx.play("windup", -6.0)
		sprite.squash(Vector2(1.2, 0.8))
		return
	var dir := to.normalized() * (1.0 if dist > data.attack_range_m * 0.8 else 0.0) + sep * 0.8
	_move(dir.normalized() * data.speed if dir.length() > 0.05 else Vector3.ZERO, 0.4)


func _attack_slot_free() -> bool:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.target == target and (e.state == S.WINDUP or e.state == S.ATTACK):
			n += 1
	return n < 2


func _tick_windup() -> void:
	_face_target()
	_move(Vector3.ZERO, 0.6)
	if st >= data.windup_ticks - 1:
		_set_state(S.ATTACK)
		hit_set.clear()
		sprite.play("headbutt", true)
		_contact = sprite.sheet.contact_range("headbutt")


func _tick_attack() -> void:
	var a: AttackData = data.attack
	if st == _contact.x:
		var to := Vector3(facing, 0, 0)
		if target != null and is_instance_valid(target):
			to = target.global_position - global_position
			to.y = 0.0
			to = to.normalized()
		velocity.x = to.x * a.lunge
		velocity.z = to.z * a.lunge
		Sfx.play(a.sfx, -4.0, 0.8)
		sprite.squash(Vector2(1.25, 0.85))
		Juice.dust(global_position, 4)
	if st >= _contact.x and st < _contact.y:
		var centre := Combat.attack_centre(global_position, facing, a)
		for p in _players():
			if p in hit_set:
				continue
			if Combat.hit_test(centre, a.radius_px * Game.PX, p, 0.3):
				hit_set.append(p)
				var dir: Vector3 = p.global_position - global_position
				dir.y = 0.0
				dir = dir.normalized() if dir.length() > 0.05 else Vector3(facing, 0, 0)
				p.take_hit_from_host(a.damage, dir, a.knockback, global_position)
				Game.log_event("enemy_hit_player", {"enemy": name, "peer": p.peer_id})
	_move(Vector3.ZERO, 0.35 if st >= _contact.x else 0.8)
	if st >= sprite.sheet.total_ticks("headbutt") - 1:
		_set_state(S.RECOVER)
		sprite.play("idle", true)


func _tick_recover() -> void:
	_move(Vector3.ZERO, 0.6)
	if st >= data.recover_ticks:
		_set_state(S.CHASE)


func _tick_hurt() -> void:
	_move(Vector3.ZERO, 0.22)
	if _launched:
		sprite.tick = mini(sprite.tick, 3) if not is_on_floor() else sprite.tick
		if is_on_floor() and st > 4:
			_launched = false
			sprite.squash(Vector2(1.35, 0.7))
			Juice.dust(global_position, 6)
			Sfx.play("step", -6.0, 0.7)
			_set_state(S.HURT)
			sprite.play("hurt", true)
			_hurt_len = 10
			return
	elif st >= _hurt_len:
		_set_state(S.IDLE if data.dummy else S.CHASE)
		if target == null and not data.dummy:
			target = _nearest_player(99.0)


func _tick_dead() -> void:
	_move(Vector3.ZERO, 0.5)
	var total := sprite.sheet.total_ticks("death")
	if st > total - 26:
		_dissolve = clampf(float(st - (total - 26)) / 26.0, 0.0, 1.0)
		sprite.set_param("dissolve", _dissolve)
	if st >= total + 4:
		rpc("rpc_remove")


# ----------------------------------------------------------------- damage

func predict_hit(ticks: int) -> void:
	## Instant local feedback on the attacker's screen (host or client).
	hitstop = maxi(hitstop, ticks)
	sprite.flash(1.0)
	sprite.squash(Vector2(1.2, 0.82))
	_bar_t = 2.2


func claim_hit(d: Dictionary) -> void:
	if multiplayer.is_server():
		_apply_hit(d)
	else:
		rpc_id(1, "rpc_claim_hit", d)


@rpc("any_peer", "call_remote", "reliable")
func rpc_claim_hit(d: Dictionary) -> void:
	if multiplayer.is_server():
		_apply_hit(d)


func _apply_hit(d: Dictionary) -> void:
	if state == S.DEAD:
		return
	var apos: Vector3 = d["apos"]
	if apos.distance_to(global_position) > 9.0:     # plausibility check
		return
	_rng.seed = int(d.get("seed", 1))
	var crit := _rng.randf() < 0.12
	var dmg := int(d["dmg"] * (1.5 if crit else 1.0))
	hp = maxi(hp - dmg, 0) if not data.dummy else hp
	_bar_t = 2.4
	var dir: Vector3 = d["dir"]
	var kb: float = d["kb"] * (1.3 if crit else 1.0)
	velocity.x = dir.x * kb
	velocity.z = dir.z * kb
	hitstop = int(d["hs"])
	hit_set.clear()
	_last_hitter = int(d["peer"])
	if d["launch"] > 0.0:
		velocity.y = Combat.launch_speed(d["launch"])
		_launched = true
	else:
		_launched = false
	Game.log_event("enemy_hit", {"enemy": name, "dmg": dmg, "hp": hp, "crit": crit})
	rpc("rpc_fx_hit", global_position + Vector3(0, 1.3, 0.2), dmg, crit, d["col"], int(d["peer"]), dir)
	if hp <= 0 and not data.dummy:
		_set_state(S.DEAD)
		sprite.play("death", true)
		velocity.x = dir.x * 3.0
		rpc("rpc_fx_die", data.blood_color)
		return
	if state != S.ATTACK or st < _contact.x or st >= _contact.y or true:
		_set_state(S.HURT)
		sprite.play("hurt", true)
		_hurt_len = 14 if not _launched else 99
		if target == null or not is_instance_valid(target):
			target = _nearest_player(99.0)


@rpc("authority", "call_local", "reliable")
func rpc_fx_hit(pos: Vector3, dmg: int, crit: bool, col: Color, attacker: int, dir: Vector3) -> void:
	Juice.damage_number(pos, dmg, crit, Color(1, 1, 1))
	_bar_t = 2.4
	if attacker != multiplayer.get_unique_id():
		# remote observers get the feedback the attacker already saw predicted
		predict_hit(hitstop if hitstop > 0 else 4)
		Juice.hit(pos - Vector3(0, 0.5, 0), dir, col, 0.5, 0.08)
		Sfx.play("hit", -4.0)


@rpc("authority", "call_local", "reliable")
func rpc_fx_die(col: Color) -> void:
	Game.kills += 1
	Juice.death_burst(global_position, col)
	Sfx.play("enemy_die")
	Game.log_event("enemy_died", {"enemy": name})


@rpc("authority", "call_local", "reliable")
func rpc_alert() -> void:
	if not multiplayer.is_server():
		Juice.alert(global_position + Vector3(0, 1.8, 0))
	Sfx.play("alert", -8.0)


@rpc("authority", "call_local", "reliable")
func rpc_remove() -> void:
	remove_from_group("enemies")
	queue_free()
