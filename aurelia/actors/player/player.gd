class_name Player
extends CharacterBody3D
## The hero. Tick-based state machine (60 ticks/s). The owning peer is authoritative over
## its own movement and detects its own hits; the host validates and owns enemies.

enum S { IDLE, DASH, JUMP, ATTACK, CAST, HURT, DEAD }

const WALK := 3.0
const RUN := 5.6
const DASH_SPEED := 17.0
const DASH_MOVE_TICKS := 10
const DASH_TOTAL := 16
const JUMP_V := 8.6
const BUFFER := 8

var peer_id := 1
var local_index := 0
var source: InputSource
var weapon: WeaponData
var spell: SpellData
var sprite: SpriteActor
var state := S.IDLE
var st := 0
var hp := 100
var max_hp := 100
var mp := 60.0
var max_mp := 60.0
var facing := 1.0
var combo := 0
var hitstop := 0
var iframes := 0
var dash_cd := 0
var cur_attack: AttackData
var hit_set: Array = []
var _buffer := {}
var _dash_dir := Vector3.RIGHT
var _airborne := false
var _land_t := 0
var _contact := Vector2i(-1, -1)
var _trail: WeaponTrail
var _respawn := 0
var _spawn_pos := Vector3.ZERO
var _name_label: Label3D
var _swing_id := 0
# replicated
var net_pos := Vector3.ZERO
var sync_anim := "idle"
var sync_tick := 0
var sync_face := 1.0
var sync_hp := 100
var sync_iframes := false


func _ready() -> void:
	add_to_group("players")
	name = "P_%d_%d" % [peer_id, local_index]
	set_multiplayer_authority(peer_id)
	collision_layer = 2
	collision_mask = 1 | 4
	weapon = Registry.weapon("bronze_sword")
	spell = Registry.spell("ice_lance")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.1
	cs.shape = cap
	cs.position.y = 0.55
	add_child(cs)
	sprite = SpriteActor.new()
	sprite.name = "Sprite"
	add_child(sprite)
	sprite.setup("ren", 1.1)
	sprite.play("idle")
	_name_label = Label3D.new()
	_name_label.text = "P%d" % (peer_id if peer_id < 10 else 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.pixel_size = 0.008
	_name_label.font_size = 36
	_name_label.outline_size = 10
	_name_label.no_depth_test = true
	_name_label.modulate = Color(0.7, 1, 0.9)
	_name_label.position = Vector3(0, 1.95, 0)
	add_child(_name_label)
	_spawn_pos = global_position
	net_pos = global_position
	_setup_sync()


func _setup_sync() -> void:
	var cfg := SceneReplicationConfig.new()
	for p in [":net_pos", ":sync_anim", ":sync_tick", ":sync_face", ":sync_hp", ":sync_iframes"]:
		var np := NodePath(p)
		cfg.add_property(np)
		cfg.property_set_replication_mode(np, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 30.0
	add_child(sync)


func is_local() -> bool:
	return is_multiplayer_authority()


func is_dead() -> bool:
	return state == S.DEAD


# ------------------------------------------------------------------- ticking

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		_remote_tick(delta)
		return
	if source == null:
		source = InputSource.new()
	if hitstop > 0:
		hitstop -= 1
		sprite.shake_px = 0.06
		_publish()
		return
	sprite.shake_px = 0.0
	var f := source.poll(Game.tick)
	for bit in [InputFrame.ATTACK, InputFrame.JUMP, InputFrame.DASH, InputFrame.CAST]:
		if f.is_pressed(bit):
			_buffer[bit] = BUFFER
		elif _buffer.has(bit):
			_buffer[bit] -= 1
			if _buffer[bit] <= 0:
				_buffer.erase(bit)
	if iframes > 0:
		iframes -= 1
	if dash_cd > 0:
		dash_cd -= 1
	if state != S.CAST:
		mp = minf(max_mp, mp + 0.1)
	match state:
		S.IDLE: _tick_free(f, delta)
		S.DASH: _tick_dash(f, delta)
		S.JUMP: _tick_jump(f, delta)
		S.ATTACK: _tick_attack(f, delta)
		S.CAST: _tick_cast(f, delta)
		S.HURT: _tick_hurt(f, delta)
		S.DEAD: _tick_dead(f, delta)
	st += 1
	sprite.advance()
	sprite.visible = iframes <= 0 or state == S.DEAD or (Game.tick / 3) % 2 == 0 or state == S.DASH
	_publish()


func _publish() -> void:
	net_pos = global_position
	sync_anim = sprite.anim
	sync_tick = sprite.tick
	sync_face = facing
	sync_hp = hp
	sync_iframes = iframes > 0


func _remote_tick(_delta: float) -> void:
	global_position = global_position.lerp(net_pos, 0.35)
	sprite.set_facing(sync_face)
	facing = sync_face
	hp = sync_hp
	if sprite.anim != sync_anim or absi(sprite.tick - sync_tick) > 3:
		sprite.set_pose(sync_anim, sync_tick)
	else:
		sprite.advance()
	sprite.visible = not sync_iframes or (Game.tick / 3) % 2 == 0


func _consume(bit: int) -> bool:
	if _buffer.get(bit, 0) > 0:
		_buffer.erase(bit)
		return true
	return false


func _set_state(s: S) -> void:
	state = s
	st = -1   # incremented right after the tick body, so the first tick of a state is 0


func _face_to(dir_x: float) -> void:
	if absf(dir_x) > 0.15:
		facing = signf(dir_x)
		sprite.set_facing(facing)


func _move_dir(f: InputFrame) -> Vector3:
	return Vector3(f.move.x, 0.0, f.move.y)


func _accel_to(target: Vector3, rate: float) -> void:
	velocity.x = move_toward(velocity.x, target.x, rate)
	velocity.z = move_toward(velocity.z, target.z, rate)


func _apply_physics(gravity := true) -> void:
	if gravity and not is_on_floor():
		velocity.y -= Game.GRAVITY / Game.TICK_RATE
	elif is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	var lim := Game.ARENA_HALF
	global_position.x = clampf(global_position.x, -lim, lim)
	global_position.z = clampf(global_position.z, -lim, lim)


# ------------------------------------------------------------------- states

func _tick_free(f: InputFrame, _delta: float) -> void:
	var dir := _move_dir(f)
	if _consume(InputFrame.DASH) and dash_cd == 0:
		_start_dash(f)
		return
	if _consume(InputFrame.ATTACK):
		_start_attack(0, f)
		return
	if _consume(InputFrame.CAST) and mp >= spell.mp_cost:
		_start_cast(f)
		return
	if _consume(InputFrame.JUMP):
		_set_state(S.JUMP)
		_airborne = false
		_land_t = 0
		sprite.play("jump", true)
		velocity = Vector3(velocity.x * 0.5, 0, velocity.z * 0.5)
		return
	var mag := dir.length()
	if mag > 0.1:
		var spd := RUN if mag > 0.6 else WALK
		_accel_to(dir.normalized() * spd, 0.7)
		_face_to(dir.x)
		sprite.play("run" if spd == RUN else "walk")
		if (Game.tick % 18) == 0 and spd == RUN:
			Sfx.play("step", -14.0)
			Juice.dust(global_position, 2)
	else:
		_accel_to(Vector3.ZERO, 0.9)
		sprite.play("idle")
	_apply_physics()


func _start_dash(f: InputFrame) -> void:
	var d := _move_dir(f)
	_dash_dir = d.normalized() if d.length() > 0.2 else Vector3(facing, 0, 0)
	_face_to(_dash_dir.x)
	_set_state(S.DASH)
	dash_cd = 24
	iframes = DASH_MOVE_TICKS
	sprite.play("dash", true)
	sprite.squash(Vector2(0.78, 1.18))
	Sfx.play("dash", -4.0)
	Juice.ring(global_position + Vector3(0, 0.05, 0), Color(0.5, 1, 0.9), 1.8, 0.3, true)
	Juice.dust(global_position, 8)
	Juice.shake(0.08)
	_net_event("dash")
	Game.log_event("dash", {"peer": peer_id})


func _tick_dash(f: InputFrame, _delta: float) -> void:
	if st < DASH_MOVE_TICKS:
		var k := 1.0 - float(st) / DASH_MOVE_TICKS * 0.4
		velocity.x = _dash_dir.x * DASH_SPEED * k
		velocity.z = _dash_dir.z * DASH_SPEED * k
		if st % 2 == 0:
			sprite.afterimage(Color(0.3, 1.0, 0.85))
		if st % 3 == 0:
			Juice.dust(global_position, 2)
	else:
		_accel_to(Vector3.ZERO, 1.6)
		if _consume(InputFrame.ATTACK):   # dash cancels into attack from the recovery
			_start_attack(0, f)
			velocity.x = facing * 4.0
			return
	_apply_physics()
	if st >= DASH_TOTAL - 1:
		_set_state(S.IDLE)


func _tick_jump(f: InputFrame, _delta: float) -> void:
	if st < 3:
		_accel_to(Vector3.ZERO, 0.8)
	elif st == 3:
		velocity.y = JUMP_V
		_airborne = true
		sprite.squash(Vector2(0.85, 1.25))
		Sfx.play("step", -6.0, 1.4)
		Juice.dust(global_position, 6)
	if _airborne:
		sprite.tick = 4          # hold the air frame
		var dir := _move_dir(f)
		_accel_to(dir.normalized() * RUN * 0.9 if dir.length() > 0.1 else Vector3.ZERO, 0.45)
		_face_to(dir.x)
		if _consume(InputFrame.DASH) and dash_cd == 0:
			_start_dash(f)
			return
		if st > 6 and is_on_floor():
			_airborne = false
			_land_t = 0
			sprite.tick = 9      # start of the landing frame (jump ticks 9..13)
			sprite.squash(Vector2(1.3, 0.72))
			Juice.dust(global_position, 8)
			Juice.ring(global_position + Vector3(0, 0.05, 0), Color(0.9, 0.85, 0.7), 1.4, 0.25, true)
			Sfx.play("step", -4.0, 0.8)
	elif st > 6:
		_land_t += 1
		_accel_to(Vector3.ZERO, 0.9)
		if _land_t >= 5:
			_set_state(S.IDLE)
	_apply_physics()


func _start_attack(idx: int, f: InputFrame) -> void:
	combo = idx
	cur_attack = weapon.combo[idx]
	hit_set.clear()
	_swing_id += 1
	var d := _move_dir(f)
	if d.length() > 0.2:
		_face_to(d.x)
	_set_state(S.ATTACK)
	sprite.play(cur_attack.anim, true)
	_contact = sprite.sheet.contact_range(cur_attack.anim)
	velocity.x *= 0.3
	velocity.z *= 0.3
	if _trail == null or not is_instance_valid(_trail):
		_trail = null


func _tick_attack(f: InputFrame, _delta: float) -> void:
	var a := cur_attack
	var total := sprite.sheet.total_ticks(a.anim)
	# trail: from just before contact until just after
	if st >= _contact.x - 3 and st <= _contact.y + 1:
		if _trail == null:
			_trail = WeaponTrail.new()
			_trail.color = a.trail_color
			Juice.fx_root.add_child(_trail)
		_trail.add_sample(sprite.anchor_world("hand"), sprite.anchor_world("weapon_tip"))
	elif _trail != null and st > _contact.y + 1:
		_trail.done = true
		_trail = null
	if st == _contact.x:
		velocity.x = facing * a.lunge
		velocity.z = f.move.y * a.lunge * 0.35
		Sfx.play(a.sfx, -3.0)
		sprite.squash(Vector2(1.18, 0.9))
		Juice.dust(global_position, 3)
		Juice.shake(0.06)
	if st >= _contact.x and st < _contact.y:
		_do_hits(a)
	_accel_to(Vector3.ZERO, 0.28 if st >= _contact.x else 0.5)
	# combo / cancels after the contact frame
	if st >= _contact.y:
		if _consume(InputFrame.DASH) and dash_cd == 0:
			combo = 0
			_start_dash(f)
			return
		if _consume(InputFrame.ATTACK) and combo < weapon.combo.size() - 1:
			_start_attack(combo + 1, f)
			return
	_apply_physics()
	if st >= total - 1:
		combo = 0
		_set_state(S.IDLE)


func _do_hits(a: AttackData) -> void:
	var centre := Combat.attack_centre(global_position, facing, a)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in hit_set or e.is_dead():
			continue
		if Combat.hit_test(centre, a.radius_px * Game.PX, e, e.data.radius_m):
			hit_set.append(e)
			_on_hit_enemy(e, a)


func _on_hit_enemy(e: Enemy, a: AttackData) -> void:
	var dir := e.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.05 else Vector3(facing, 0, 0)
	var power := clampf(float(a.damage) / 26.0, 0.25, 1.0)
	# predicted, local feedback (the host confirms damage + numbers)
	hitstop = a.hitstop
	sprite.flash(0.0)
	Juice.hit(e.global_position + Vector3(0, 0.8, 0.2), dir, a.trail_color, power, a.shake)
	Sfx.play(a.hit_sfx, -2.0)
	e.predict_hit(a.hitstop)
	e.claim_hit(Combat.payload(a, peer_id, global_position, dir, power, _swing_id * 7919 + e.get_instance_id() % 1000))
	Game.log_event("player_hit", {"peer": peer_id, "dmg": a.damage, "anim": a.anim})


func _start_cast(_f: InputFrame) -> void:
	_set_state(S.CAST)
	mp -= spell.mp_cost
	sprite.play(spell.cast_anim, true)
	_contact = sprite.sheet.contact_range(spell.cast_anim)
	velocity = Vector3.ZERO
	var col := spell.color
	Juice.magic_circle(global_position, col)
	Sfx.play("cast", -2.0)
	_net_event("cast")


func _tick_cast(_f: InputFrame, _delta: float) -> void:
	_accel_to(Vector3.ZERO, 0.8)
	if st == _contact.x:
		Game.world.spawn_spell(spell.id, sprite.anchor_world("off_hand") + Vector3(0, 0, 0), Vector3(facing, 0, 0), peer_id)
		sprite.squash(Vector2(1.12, 0.92))
		Juice.shake(0.18)
		Juice.kick(Vector3(-facing, 0, 0), 0.15)
	_apply_physics()
	if st >= sprite.sheet.total_ticks(spell.cast_anim) - 1:
		_set_state(S.IDLE)


func _tick_hurt(_f: InputFrame, _delta: float) -> void:
	_accel_to(Vector3.ZERO, 0.35)
	_apply_physics()
	if st >= 13:
		_set_state(S.IDLE)


func _tick_dead(_f: InputFrame, _delta: float) -> void:
	_accel_to(Vector3.ZERO, 0.8)
	_apply_physics()
	_respawn -= 1
	if _respawn <= 0:
		hp = max_hp
		mp = max_mp
		global_position = _spawn_pos
		iframes = 100
		_set_state(S.IDLE)
		sprite.play("idle", true)
		Juice.ring(global_position, Color(0.6, 1, 0.9), 2.2, 0.5, true)
		Game.log_event("respawn", {"peer": peer_id})


# -------------------------------------------------------------- damage in

func receive_hit(dmg: int, dir: Vector3, kb: float, from_pos: Vector3) -> void:
	## Called on the authoritative peer (directly, or via the host's RPC).
	if state == S.DEAD or iframes > 0:
		return
	if state == S.DASH and st < DASH_MOVE_TICKS:
		return
	hp = maxi(0, hp - dmg)
	iframes = 55
	hitstop = 5
	velocity = Vector3(dir.x * kb, 0, dir.z * kb)
	_trail = null
	sprite.flash(1.0, Color(1, 0.4, 0.4))
	sprite.squash(Vector2(1.2, 0.82))
	Sfx.play("hurt", -1.0)
	Juice.hit(global_position + Vector3(0, 0.8, 0.2), dir, Color(1, 0.45, 0.4), 0.55, 0.4)
	Juice.damage_number(global_position + Vector3(0, 1.7, 0), dmg, false, Color(1, 0.5, 0.5))
	Game.log_event("player_hurt", {"peer": peer_id, "dmg": dmg})
	if dir.x != 0.0:
		_face_to(-signf(dir.x))
	if hp <= 0:
		_set_state(S.DEAD)
		_respawn = 260
		sprite.play("death", true)
		Juice.shake(0.5)
		Game.log_event("player_dead", {"peer": peer_id})
	else:
		_set_state(S.HURT)
		sprite.play("hurt", true)


@rpc("any_peer", "call_remote", "reliable")
func rpc_take_hit(dmg: int, dir: Vector3, kb: float, from_pos: Vector3) -> void:
	if is_multiplayer_authority():
		receive_hit(dmg, dir, kb, from_pos)


func take_hit_from_host(dmg: int, dir: Vector3, kb: float, from_pos: Vector3) -> void:
	if is_multiplayer_authority():
		receive_hit(dmg, dir, kb, from_pos)
	else:
		rpc_id(peer_id, "rpc_take_hit", dmg, dir, kb, from_pos)


# ---------------------------------------------------------------- net fx

func _net_event(kind: String) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		rpc("rpc_net_event", kind)


@rpc("authority", "call_remote", "unreliable")
func rpc_net_event(kind: String) -> void:
	match kind:
		"dash":
			sprite.afterimage(Color(0.3, 1.0, 0.85))
			Juice.dust(global_position, 6)
			Juice.ring(global_position + Vector3(0, 0.05, 0), Color(0.5, 1, 0.9), 1.8, 0.3, true)
		"cast":
			Juice.magic_circle(global_position, spell.color)
