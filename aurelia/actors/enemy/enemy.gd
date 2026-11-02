class_name Enemy
extends CharacterBody3D
## Field monsters (Capmook, Hopkin...). Simulated on the host only; clients render replicated state.
## They stay DORMANT on the field until the BattleManager starts an encounter, then they
## notice the party and fight inside the arena ring.

enum S { DORMANT, NOTICE, CHASE, WINDUP, ATTACK, RECOVER, HURT, DEAD }

var data: EnemyData
var sprite: SpriteActor
var hp := 60
var state := S.DORMANT
var st := 0
var hitstop := 0
var target: Player
var facing := 1.0
var hit_set: Array = []
var engaged := false
var encounter_id := -1
var _contact := Vector2i(-1, -1)
var _wander_t := 0
var _wander_dir := Vector3.ZERO
var _launched := false
var _hurt_len := 14
var _bar_t := 0.0
var _bar_bg: MeshInstance3D
var _bar_fg: MeshInstance3D
var _dissolve := 0.0
var _hop_t := 0
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
	sync.public_visibility = false          # let the spawn RPC arrive first, then start replicating
	add_child(sync)
	get_tree().create_timer(0.6).timeout.connect(func(): if is_instance_valid(sync): sync.public_visibility = true)
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
	else:
		# spawn-in pop so encounters appear with some life
		sprite.squash(Vector2(1.5, 0.4))
		Juice.dust(global_position, 5)


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


# ----------------------------------------------------------------- battle hooks

## Host: the encounter started; wake up, notice the party and fight.
func engage(delay: int) -> void:
	if data.dummy or state == S.DEAD:
		return
	engaged = true
	_set_state(S.NOTICE)
	st = -delay


func standby() -> void:
	## Battle was lost/aborted: go back to field idling.
	engaged = false
	target = null
	if state != S.DEAD:
		_set_state(S.DORMANT)


# ----------------------------------------------------------------- ticking

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		_remote_tick()
		return
	if hitstop > 0 or Game.freeze_ticks > 0:
		hitstop = maxi(hitstop - 1, 0)
		sprite.shake_px = 0.07
		_publish()
		return
	sprite.shake_px = 0.0
	match state:
		S.DORMANT: _tick_dormant()
		S.NOTICE: _tick_notice()
		S.CHASE: _tick_chase()
		S.WINDUP: _tick_windup()
		S.ATTACK: _tick_attack()
		S.RECOVER: _tick_recover()
		S.HURT: _tick_hurt()
		S.DEAD: _tick_dead()
	if engaged:
		global_position = Game.clamp_to_arena(global_position, 0.5)
	st += 1
	_advance_sprite()
	_publish()


func _advance_sprite() -> void:
	if data.style == "walker" and sprite.anim == "walk" and (state == S.CHASE or state == S.DORMANT):
		var v := Vector2(velocity.x, velocity.z).length()
		sprite.advance_rate(clampf(v / 1.7, 0.4, 1.8))      # feet follow the ground
	else:
		sprite.advance()
	sprite.skew_target = clampf(velocity.x * 0.012, -0.08, 0.08)


func _publish() -> void:
	net_pos = global_position
	sync_anim = sprite.anim
	sync_tick = sprite.tick
	sync_face = facing
	sync_hp = hp
	sync_dissolve = _dissolve
	sync_glow = 1.0 if state == S.WINDUP or (state == S.ATTACK and st < 10) else 0.0


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


# ------------------------------------------------------------------ states

func _tick_dormant() -> void:
	# field idling: munch around a little, unaware of the party until a battle starts
	if data.dummy:
		sprite.play("idle")
		_move(Vector3.ZERO, 0.6)
		return
	_wander_t -= 1
	if _wander_t <= 0:
		_wander_t = _rng.randi_range(70, 150)
		_wander_dir = Vector3.ZERO if _rng.randf() < 0.55 else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	if _wander_dir != Vector3.ZERO:
		sprite.play("walk")
		facing = signf(_wander_dir.x) if absf(_wander_dir.x) > 0.1 else facing
		sprite.set_facing(facing)
		_move(_wander_dir * data.speed * 0.28, 0.2)
	else:
		sprite.play("idle")
		_move(Vector3.ZERO, 0.4)


func _tick_notice() -> void:
	_move(Vector3.ZERO, 0.6)
	if st == 0:
		target = _nearest_player(99.0)
		_face_target()
		sprite.play("idle", true)
		sprite.squash(Vector2(0.8, 1.35))
		Juice.alert(global_position + Vector3(0, 1.8, 0))
		rpc("rpc_alert")
		Game.log_event("enemy_notice", {"enemy": name})
	if st >= 26:
		_set_state(S.CHASE)


func _tick_chase() -> void:
	if target == null or not is_instance_valid(target) or target.is_dead():
		target = _nearest_player(99.0)
		if target == null:
			_move(Vector3.ZERO, 0.6)
			sprite.play("idle")
			return
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	_face_target()
	# separation from other enemies
	var sep := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and not e.is_dead():
			var d: Vector3 = global_position - e.global_position
			d.y = 0.0
			if d.length() < 1.1 and d.length() > 0.01:
				sep += d.normalized() * (1.1 - d.length())
	if dist <= data.attack_range_m and _attack_slot_free() and (data.style != "hopper" or is_on_floor()):
		_set_state(S.WINDUP)
		sprite.play("windup", true)
		Sfx.play("windup", -6.0)
		sprite.squash(Vector2(1.2, 0.8))
		Juice.telegraph(global_position, data.attack_range_m, Color(1, 0.35, 0.3), float(data.windup_ticks) / 60.0)
		return
	var dir := to.normalized() * (1.0 if dist > data.attack_range_m * 0.8 else 0.0) + sep * 0.8
	if data.style == "hopper":
		_tick_hop(dir)
		return
	sprite.play("walk")
	_move(dir.normalized() * data.speed if dir.length() > 0.05 else Vector3.ZERO, 0.4)


## Hopkin-style locomotion: squat, spring, glide on the arc, land (the "walk" cycle is 6 frames).
func _tick_hop(dir: Vector3) -> void:
	sprite.play("walk")
	var cycle := sprite.sheet.total_ticks("walk")
	var launch := sprite.sheet.frame_start("walk", 1)
	var landing := sprite.sheet.frame_start("walk", 4)
	var t := sprite.tick % cycle
	if t == launch and is_on_floor():
		velocity.y = 4.6
		sprite.squash(Vector2(0.8, 1.3))
	if t >= launch and t < landing and not is_on_floor():
		var h := dir.normalized() * data.hop_speed if dir.length() > 0.05 else Vector3.ZERO
		velocity.x = h.x
		velocity.z = h.z
	else:
		velocity.x = move_toward(velocity.x, 0.0, 0.8)
		velocity.z = move_toward(velocity.z, 0.0, 0.8)
	if t == landing - 2 and is_on_floor():
		sprite.squash(Vector2(1.3, 0.75))
		Juice.dust(global_position, 3)
	_move(Vector3(velocity.x, 0, velocity.z), 5.0)


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
		sprite.play(data.attack_anim, true)
		_contact = sprite.sheet.contact_range(data.attack_anim)


func _tick_attack() -> void:
	var a: AttackData = data.attack
	var lunge_t := data.lunge_tick if data.lunge_tick >= 0 else _contact.x
	if st == lunge_t:
		var to := Vector3(facing, 0, 0)
		if target != null and is_instance_valid(target):
			to = target.global_position - global_position
			to.y = 0.0
			to = to.normalized()
		velocity.x = to.x * a.lunge
		velocity.z = to.z * a.lunge
		if data.lunge_vy > 0.0:
			velocity.y = data.lunge_vy
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
	_move(Vector3.ZERO, 0.35 if st >= lunge_t else 0.8)
	if st >= sprite.sheet.total_ticks(data.attack_anim) - 1:
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
		_set_state(S.DORMANT if (data.dummy or not engaged) else S.CHASE)
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
	if apos.distance_to(global_position) > 11.0:     # plausibility check
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
	# an unaware field monster that gets hit joins the fight
	if not engaged and not data.dummy:
		engaged = true
		target = _nearest_player(99.0)
	if d["launch"] > 0.0:
		velocity.y = Combat.launch_speed(d["launch"])
		_launched = true
	else:
		_launched = false
	Game.log_event("enemy_hit", {"enemy": name, "dmg": dmg, "hp": hp, "crit": crit})
	rpc("rpc_fx_hit", global_position + Vector3(0, 1.3, 0.2), dmg, crit, d["col"], int(d["peer"]), dir, hp <= 0 and not data.dummy)
	if hp <= 0 and not data.dummy:
		_set_state(S.DEAD)
		sprite.play("death", true)
		velocity.x = dir.x * 3.0
		rpc("rpc_fx_die", data.blood_color, data.exp)
		return
	_set_state(S.HURT)
	sprite.play("hurt", true)
	_hurt_len = 14 if not _launched else 99
	if target == null or not is_instance_valid(target):
		target = _nearest_player(99.0)


@rpc("authority", "call_local", "reliable")
func rpc_fx_hit(pos: Vector3, dmg: int, crit: bool, col: Color, attacker: int, dir: Vector3, killing: bool) -> void:
	Juice.damage_number(pos, dmg, crit, Color(1, 1, 1))
	_bar_t = 2.4
	if killing:
		Juice.last_hit_freeze(pos)
	if attacker != multiplayer.get_unique_id():
		# remote observers get the feedback the attacker already saw predicted
		predict_hit(hitstop if hitstop > 0 else 4)
		Juice.hit(pos - Vector3(0, 0.5, 0), dir, col, 0.5, 0.08)
		Sfx.play("hit", -4.0)


@rpc("authority", "call_local", "reliable")
func rpc_fx_die(col: Color, exp_value: int) -> void:
	Game.kills += 1
	Juice.death_burst(global_position, col)
	Sfx.play("enemy_die")
	Game.log_event("enemy_died", {"enemy": name})
	# mana orbs fly to every local player
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_multiplayer_authority():
			Juice.mana_orbs(global_position + Vector3(0, 0.5, 0), p, 2, col)
			p.hp = mini(p.max_hp, p.hp + 2)
			p.mp = minf(p.max_mp, p.mp + 4.0)
			p.gain_sp(6.0)


@rpc("authority", "call_local", "reliable")
func rpc_alert() -> void:
	if not multiplayer.is_server():
		Juice.alert(global_position + Vector3(0, 1.8, 0))
	Sfx.play("alert", -8.0)


@rpc("authority", "call_local", "reliable")
func rpc_remove() -> void:
	remove_from_group("enemies")
	queue_free()
