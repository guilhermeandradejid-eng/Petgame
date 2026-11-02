class_name Player
extends CharacterBody3D
## The hero. Tick-based state machine (60 ticks/s). The owning peer is authoritative over its own
## movement and detects its own hits; the host validates and owns enemies.
##
## Legend-of-Mana-style kit: 3 weapons (swap with Q), each with a 3-hit combo and two specials that
## spend the SP gauge (filled by landing normal hits), plus three spirit spells that spend MP.
## Visual-only effects are driven from the animation tick (`_anim_fx`) so remote peers see the
## exact same slash arcs, trails and auras without any extra network traffic.

enum S { IDLE, DASH, JUMP, ATTACK, SPECIAL, CAST, HURT, DEAD, VICTORY }

const WALK := 1.8
const RUN := 3.4
const REF_WALK := 1.7          # ground speed (m/s) at which the walk cycle's feet do not slide
const REF_RUN := 2.8
const DASH_SPEED := 12.0
const DASH_START := 3          # anticipation ticks before the burst
const DASH_MOVE_TICKS := 12    # ...burst lasts until this tick (i-frames cover it)
const BUFFER := 8
const JUMP_V := 7.4
const SP_MAX := 100.0

var peer_id := 1
var local_index := 0
var source: InputSource
var weapon_idx := 0
var spell_idx := 0
var weapon: WeaponData
var spell: SpellData
var sprite: SpriteActor
var state := S.IDLE
var st := 0
var hp := 100
var max_hp := 100
var mp := 60.0
var max_mp := 60.0
var sp := 0.0
var level := 1
var exp_total := 0
var exp_next := 30
var facing := 1.0
var combo := 0
var hitstop := 0
var iframes := 0
var dash_cd := 0
var cur_attack: AttackData
var cur_special: SpecialData
var hit_set: Array = []
var sp_denied := 0          # HUD blink when a special is not affordable
var _buffer := {}
var _dash_dir := Vector3.RIGHT
var _airborne := false
var _land_t := 0
var _windows: Array = []    # contact windows (Vector2i ticks) of the current action
var _trail: WeaponTrail
var _aura: Node3D
var _respawn := 0
var _victory_t := 0
var _spawn_pos := Vector3.ZERO
var _name_label: Label3D
var _swing_id := 0
var _dive_from := Vector3.ZERO
var _dive_to := Vector3.ZERO
var _fx_prev_anim := ""
var _fx_prev_tick := -1
# replicated
var net_pos := Vector3.ZERO
var sync_anim := "idle"
var sync_tick := 0
var sync_face := 1.0
var sync_hp := 100
var sync_iframes := false
var sync_weapon := "bronze_sword"
var sync_spell := "ice_lance"


func _ready() -> void:
	add_to_group("players")
	name = "P_%d_%d" % [peer_id, local_index]
	set_multiplayer_authority(peer_id)
	collision_layer = 2
	collision_mask = 1 | 4
	_set_weapon(0)
	_set_spell(0)
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
	sprite.play("sword.idle" if sprite.sheet.has_anim("sword.idle") else "idle")
	_name_label = Label3D.new()
	_name_label.text = "P%d" % (peer_id if peer_id < 10 else 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.pixel_size = 0.008
	_name_label.font_size = 36
	_name_label.outline_size = 10
	_name_label.no_depth_test = true
	_name_label.modulate = Color(0.7, 1, 0.9)
	_name_label.position = Vector3(0, 1.75, 0)
	add_child(_name_label)
	_spawn_pos = global_position
	net_pos = global_position
	_setup_sync()


func _setup_sync() -> void:
	var cfg := SceneReplicationConfig.new()
	for p in [":net_pos", ":sync_anim", ":sync_tick", ":sync_face", ":sync_hp", ":sync_iframes", ":sync_weapon", ":sync_spell"]:
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


func is_local() -> bool:
	return is_multiplayer_authority()


func is_dead() -> bool:
	return state == S.DEAD


func power_mult() -> float:
	return 1.0 + 0.08 * (level - 1)


# ------------------------------------------------------------- loadout

func _set_weapon(i: int) -> void:
	weapon_idx = posmod(i, Registry.weapon_order.size())
	weapon = Registry.weapon(Registry.weapon_order[weapon_idx])
	sync_weapon = weapon.id


func _set_spell(i: int) -> void:
	spell_idx = posmod(i, Registry.spell_order.size())
	spell = Registry.spell(Registry.spell_order[spell_idx])
	sync_spell = spell.id


func _swap_weapon() -> void:
	_set_weapon(weapon_idx + 1)
	combo = 0
	Sfx.play("swap", -4.0)
	sprite.squash(Vector2(1.08, 0.94))


func _swap_spell() -> void:
	_set_spell(spell_idx + 1)
	Sfx.play("swap", -4.0, 1.3)



## Basic animations exist per weapon ("spear.run"); death/cast are weapon-independent.
func _b(base: String) -> String:
	return _a("%s.%s" % [weapon.weapon_key, base])


static func base_of(an: String) -> String:
	for w in ["sword.", "spear.", "axe."]:
		if an.begins_with(w):
			var rest := an.trim_prefix(w)
			if rest in ["idle", "ready", "walk", "run", "dash", "jump", "hurt", "victory"]:
				return rest
	return an


## Fall back to a close animation while art is being replaced.
func _a(n: String) -> String:
	var sh := sprite.sheet
	if sh.has_anim(n):
		return n
	for w in ["sword.", "spear.", "axe."]:       # weapon-specific basic animation missing: use the neutral one
		if n.begins_with(w) and sh.has_anim(n.trim_prefix(w)):
			return n.trim_prefix(w)
	var alt := {"ready": "idle", "victory": "idle", "cast.ring": "cast", "cast.sky": "cast"}
	if alt.has(n) and sh.has_anim(alt[n]):
		return alt[n]
	if "." in n:
		var tail := n.split(".")[1]
		var sw := "sword." + (tail if tail in ["1", "2", "3"] else "3")
		if sh.has_anim(sw):
			return sw
	return "idle"


# ------------------------------------------------------------------ ticking

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		_remote_tick(delta)
		return
	if source == null:
		source = InputSource.new()
	if hitstop > 0 or Game.freeze_ticks > 0:
		hitstop = maxi(hitstop - 1, 0)
		sprite.shake_px = 0.06
		_publish()
		return
	sprite.shake_px = 0.0
	var f := source.poll(Game.tick)
	for bit in [InputFrame.ATTACK, InputFrame.JUMP, InputFrame.DASH, InputFrame.CAST, InputFrame.SP1, InputFrame.SP2, InputFrame.WEAPON, InputFrame.SPELL]:
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
	if sp_denied > 0:
		sp_denied -= 1
	if state != S.CAST:
		mp = minf(max_mp, mp + 0.1)
	match state:
		S.IDLE: _tick_free(f, delta)
		S.DASH: _tick_dash(f, delta)
		S.JUMP: _tick_jump(f, delta)
		S.ATTACK: _tick_attack(f, delta)
		S.SPECIAL: _tick_special(f, delta)
		S.CAST: _tick_cast(f, delta)
		S.HURT: _tick_hurt(f, delta)
		S.DEAD: _tick_dead(f, delta)
		S.VICTORY: _tick_victory(f, delta)
	st += 1
	_advance_sprite()
	_anim_fx()
	sprite.visible = iframes <= 0 or state == S.DEAD or (Game.tick / 3) % 2 == 0 or state == S.DASH or state == S.SPECIAL
	_publish()


## Locomotion cycles play at ground speed / reference speed (no foot sliding); everything else is
## plain tick playback. Also leans the sprite into its horizontal velocity and fires footsteps on the
## logical contact frames of the run/walk cycles.
func _advance_sprite() -> void:
	var an := sprite.anim
	var base := base_of(an)
	var prev_logical := sprite.logical
	if state == S.IDLE and (base == "run" or base == "walk"):
		var v := Vector2(velocity.x, velocity.z).length()
		var ref := sprite.sheet.ref_speed(an, REF_RUN if base == "run" else REF_WALK)
		sprite.advance_rate(clampf(v / ref, 0.35, 1.9))
		if sprite.logical != prev_logical and (sprite.logical == 0 or sprite.logical == 4) and v > 1.0:
			Sfx.play("step", -13.0, 0.9 + 0.2 * randf())
			Juice.dust(global_position + Vector3(-facing * 0.15, 0, 0), 2)
	else:
		sprite.advance()
	var lean := clampf(velocity.x * 0.016, -0.1, 0.1) if (state == S.IDLE or state == S.DASH) else 0.0
	sprite.skew_target = lean


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
	if weapon == null or weapon.id != sync_weapon:
		weapon = Registry.weapon(sync_weapon)
	if spell == null or spell.id != sync_spell:
		spell = Registry.spell(sync_spell)
	if sprite.anim != sync_anim or absi(sprite.tick - sync_tick) > 3:
		sprite.set_pose(sync_anim, sync_tick)
	else:
		sprite.advance()
	_anim_fx()
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
	global_position = Game.clamp_to_arena(global_position)


func _win_at(t: int) -> int:
	for i in _windows.size():
		var w: Vector2i = _windows[i]
		if t >= w.x and t < w.y:
			return i
	return -1


func _windows_end() -> int:
	return (_windows[-1] as Vector2i).y if not _windows.is_empty() else 0


## Nearest living enemy inside a cone, for attack magnetism (the "approach" feel of the genre).
func _assist_target(max_dist: float, dir_x: float) -> Enemy:
	var best: Enemy = null
	var bd := max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_dead():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0.0
		var dist := d.length()
		if dist < bd and (dir_x == 0.0 or signf(d.x) == signf(dir_x) or absf(d.x) < 0.4):
			bd = dist
			best = e
	return best


# ------------------------------------------------------------------- free

func _tick_free(f: InputFrame, _delta: float) -> void:
	var dir := _move_dir(f)
	if _consume(InputFrame.WEAPON):
		_swap_weapon()
	if _consume(InputFrame.SPELL):
		_swap_spell()
	if _consume(InputFrame.DASH) and dash_cd == 0:
		_start_dash(f)
		return
	if _consume(InputFrame.ATTACK):
		_start_attack(0, f)
		return
	if _consume(InputFrame.SP1):
		if _start_special(0, f):
			return
	if _consume(InputFrame.SP2):
		if _start_special(1, f):
			return
	if _consume(InputFrame.CAST):
		if mp >= spell.mp_cost:
			_start_cast(f)
			return
		_deny()
	if _consume(InputFrame.JUMP):
		_set_state(S.JUMP)
		_airborne = false
		_land_t = 0
		sprite.play(_b("jump"), true)
		velocity = Vector3(velocity.x * 0.5, 0, velocity.z * 0.5)
		return
	var mag := dir.length()
	var battle := Game.arena_active
	if mag > 0.1:
		var spd := (RUN if mag > 0.6 else WALK) * weapon.move_speed_mult
		var want := dir.normalized() * spd
		if velocity.x * want.x < -4.0 and absf(velocity.x) > 3.0:     # hard reversal: skid
			sprite.squash(Vector2(1.18, 0.88))
			Juice.dust(global_position, 4)
			Sfx.play("step", -8.0, 0.7)
		_accel_to(want, 0.55)
		_face_to(dir.x)
		sprite.play(_b("run") if spd >= RUN * 0.9 else _b("walk"))
	else:
		_accel_to(Vector3.ZERO, 0.75)
		sprite.play(_b("ready") if battle else _b("idle"))
	_apply_physics()


func _deny() -> void:
	sp_denied = 24
	Sfx.play("deny", -6.0)
	Juice.shake(0.04)


# ------------------------------------------------------------------- dash

func _start_dash(f: InputFrame) -> void:
	var d := _move_dir(f)
	_dash_dir = d.normalized() if d.length() > 0.2 else Vector3(facing, 0, 0)
	_face_to(_dash_dir.x)
	_set_state(S.DASH)
	dash_cd = 24
	iframes = DASH_MOVE_TICKS + 1
	sprite.play(_b("dash"), true)
	sprite.squash(Vector2(0.78, 1.18))
	Sfx.play("dash", -4.0)
	Juice.dust(global_position, 3)
	_trail = null
	Game.log_event("dash", {"peer": peer_id})


func _tick_dash(f: InputFrame, _delta: float) -> void:
	if st < DASH_START:
		_accel_to(Vector3.ZERO, 1.0)
	elif st < DASH_MOVE_TICKS:
		var k := 1.0 - float(st - DASH_START) / float(DASH_MOVE_TICKS - DASH_START) * 0.45
		velocity.x = _dash_dir.x * DASH_SPEED * k
		velocity.z = _dash_dir.z * DASH_SPEED * k
		if st == DASH_START:
			Juice.dust(global_position, 3)
	else:
		_accel_to(Vector3.ZERO, 1.6)
		if _consume(InputFrame.ATTACK):   # dash cancels into attack from the recovery (Mana: abilities extend combos)
			_start_attack(0, f)
			velocity.x = facing * 4.5
			return
		if _consume(InputFrame.SP1) and _start_special(0, f):
			return
		if _consume(InputFrame.SP2) and _start_special(1, f):
			return
	_apply_physics()
	if st >= sprite.sheet.total_ticks(sprite.anim) - 1:
		_set_state(S.IDLE)


# ------------------------------------------------------------------- jump

func _tick_jump(f: InputFrame, _delta: float) -> void:
	var sh := sprite.sheet
	var an := sprite.anim
	var rise := sh.frame_start(an, 1) if sh.has_anim(an) else 3
	var fall := sh.frame_start(an, 2) if sh.has_anim(an) else 8
	var land := sh.frame_start(an, 3) if sh.has_anim(an) else 9
	if st < rise:
		_accel_to(Vector3.ZERO, 0.8)
	elif st == rise:
		velocity.y = JUMP_V
		_airborne = true
		sprite.squash(Vector2(0.85, 1.25))
		Sfx.play("step", -6.0, 1.4)
		Juice.dust(global_position, 6)
	if _airborne:
		sprite.tick = rise + 2 if velocity.y > 0.5 else fall + 1     # hold rise / fall poses
		var dir := _move_dir(f)
		_accel_to(dir.normalized() * RUN * 0.9 if dir.length() > 0.1 else Vector3.ZERO, 0.45)
		_face_to(dir.x)
		if _consume(InputFrame.DASH) and dash_cd == 0:
			_start_dash(f)
			return
		if _consume(InputFrame.ATTACK):
			_start_attack(0, f)
			return
		if st > rise + 4 and is_on_floor():
			_airborne = false
			_land_t = 0
			sprite.tick = land
			sprite.squash(Vector2(1.3, 0.72))
			Juice.dust(global_position, 4)
			Sfx.play("step", -4.0, 0.8)
	elif st > rise + 4:
		_land_t += 1
		_accel_to(Vector3.ZERO, 0.9)
		if _land_t >= 5:
			_set_state(S.IDLE)
	_apply_physics()


# ----------------------------------------------------------------- attacks

func _start_attack(idx: int, f: InputFrame) -> void:
	combo = idx
	cur_attack = weapon.combo[idx]
	hit_set.clear()
	_swing_id += 1
	var d := _move_dir(f)
	if d.length() > 0.2:
		_face_to(d.x)
	# approach assist: face and drift toward a nearby enemy (Mana-style melee approach)
	var tgt := _assist_target(3.6, facing if d.length() < 0.2 else d.x)
	var assist := Vector3(facing, 0, 0)
	if tgt != null:
		var to := tgt.global_position - global_position
		to.y = 0.0
		assist = to.normalized()
		_face_to(to.x)
	_set_state(S.ATTACK)
	sprite.play(_a(cur_attack.anim), true)
	_windows = sprite.sheet.contact_ranges(sprite.anim)
	velocity.x *= 0.3
	velocity.z *= 0.3
	set_meta("assist", assist)
	_trail = null


func _tick_attack(f: InputFrame, _delta: float) -> void:
	var a := cur_attack
	if _windows.is_empty():
		_set_state(S.IDLE)
		return
	var w0: Vector2i = _windows[0]
	if st == maxi(w0.x - 2, 0):
		# the step into the strike starts just before the contact frame, so body and blade arrive together
		var assist: Vector3 = get_meta("assist", Vector3(facing, 0, 0))
		velocity.x = assist.x * a.lunge * 0.8
		velocity.z = assist.z * a.lunge * 0.8
	if st == w0.x:
		Sfx.play(a.sfx, -3.0, 1.0 + 0.06 * combo)
		sprite.squash(Vector2(1.18, 0.9))
		Juice.dust(global_position, 3)
		Juice.shake(0.02 + 0.02 * combo)
	if _win_at(st) >= 0:
		var centre := Combat.attack_centre(global_position, facing, a)
		_strike(centre, a.radius_px * Game.PX, {
			"dmg": a.damage, "kb": a.knockback, "launch": a.launch_height_px, "hs": a.hitstop, "sh": a.shake,
			"col": a.trail_color, "sfx": a.hit_sfx, "sp": 5.0 + 3.0 * combo, "anim": a.anim})
	_accel_to(Vector3.ZERO, 0.28 if st >= w0.x else 0.5)
	var after := _windows_end()
	if st >= after:
		if _consume(InputFrame.DASH) and dash_cd == 0:
			combo = 0
			_start_dash(f)
			return
		if _consume(InputFrame.SP1) and _start_special(0, f):
			return
		if _consume(InputFrame.SP2) and _start_special(1, f):
			return
		if _consume(InputFrame.ATTACK) and combo < weapon.combo.size() - 1:
			_start_attack(combo + 1, f)
			return
		if _consume(InputFrame.CAST) and mp >= spell.mp_cost:
			combo = 0
			_start_cast(f)
			return
	_apply_physics()
	if st >= sprite.sheet.total_ticks(sprite.anim) - 1:
		combo = 0
		_set_state(S.IDLE)


# ------------------------------------------------------------- hit delivery

func _strike(centre: Vector3, radius_m: float, d: Dictionary) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in hit_set or e.is_dead():
			continue
		if Combat.hit_test(centre, radius_m, e, e.data.radius_m):
			hit_set.append(e)
			_hit_enemy(e, d)
			n += 1
	return n


func _hit_enemy(e: Enemy, d: Dictionary) -> void:
	var dir := e.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.05 else Vector3(facing, 0, 0)
	var dmg := int(round(float(d["dmg"]) * power_mult()))
	var power := clampf(float(dmg) / 28.0, 0.2, 1.0)
	hitstop = int(d["hs"])
	Juice.hit(e.global_position + Vector3(0, 0.8, 0.2), dir, d["col"], power, d["sh"])
	Juice.hit_slash(e.global_position + Vector3(0, 0.9, 0.3), dir, d["col"], power)
	Sfx.play(d["sfx"], -2.0)
	e.predict_hit(int(d["hs"]))
	var a := AttackData.new()
	a.damage = dmg
	a.knockback = d["kb"]
	a.launch_height_px = d["launch"]
	a.hitstop = d["hs"]
	a.shake = d["sh"]
	a.trail_color = d["col"]
	a.hit_sfx = d["sfx"]
	e.claim_hit(Combat.payload(a, peer_id, global_position, dir, power, _swing_id * 7919 + e.get_instance_id() % 1000 + Game.tick))
	gain_sp(float(d.get("sp", 0.0)))
	Game.register_hit(dmg)
	Game.log_event("player_hit", {"peer": peer_id, "dmg": dmg, "anim": d.get("anim", "")})


func gain_sp(v: float) -> void:
	if v <= 0.0:
		return
	var before := sp
	sp = minf(SP_MAX, sp + v)
	for th in [40.0, 70.0, 100.0]:
		if before < th and sp >= th:
			Sfx.play("sp_ready", -6.0, 0.9 + th / 200.0)
			Juice.sparks(global_position + Vector3(0, 1.0, 0.2), Vector3.UP, Color(1, 0.9, 0.4), 5, 3.0)


# ---------------------------------------------------------------- specials

func _start_special(i: int, f: InputFrame) -> bool:
	if i >= weapon.specials.size():
		return false
	var sd: SpecialData = weapon.specials[i]
	if sp < sd.sp_cost:
		_deny()
		return false
	sp -= sd.sp_cost
	cur_special = sd
	hit_set.clear()
	_swing_id += 1
	combo = 0
	var d := _move_dir(f)
	if d.length() > 0.2:
		_face_to(d.x)
	var tgt := _assist_target(7.0 if sd.kind == "dive" else 4.0, facing)
	if tgt != null:
		_face_to(tgt.global_position.x - global_position.x)
	_set_state(S.SPECIAL)
	sprite.play(_a(sd.anim), true)
	_windows = sprite.sheet.contact_ranges(sprite.anim)
	_trail = null
	velocity = Vector3.ZERO
	_dive_from = global_position
	_dive_to = global_position + Vector3(facing * 3.2, 0, 0)
	if tgt != null:
		var t := tgt.global_position
		_dive_to = Vector3(t.x - facing * 0.4, 0, t.z)
	Sfx.play("special_call", -3.0)
	Juice.shake(0.05)
	Game.log_event("special", {"peer": peer_id, "id": sd.id})
	return true


func _tick_special(f: InputFrame, _delta: float) -> void:
	var sd := cur_special
	var w := _win_at(st)
	var first: Vector2i = _windows[0] if not _windows.is_empty() else Vector2i(9999, 9999)
	var base := {"dmg": sd.damage, "kb": sd.knockback, "launch": sd.launch_height_px, "hs": sd.hitstop,
		"sh": sd.shake, "col": sd.color, "sfx": "hit", "sp": 1.5, "anim": sd.anim}
	# new contact window => every enemy may be hit again (multi-hit techniques)
	for i in _windows.size():
		if st == (_windows[i] as Vector2i).x:
			hit_set.clear()
			_on_special_window(i)
	match sd.kind:
		"spin":
			var dir := _move_dir(f)
			var drift := dir.normalized() * 2.2 if (w >= 0 and dir.length() > 0.1) else Vector3.ZERO
			_accel_to(drift, 0.5)
			if w >= 0:
				base["sfx"] = "hit"
				_strike(global_position, sd.radius_px * Game.PX, base)
		"thrusts":
			_accel_to(Vector3.ZERO, 0.4)
			if w >= 0:
				var centre := Combat.attack_centre(global_position, facing, sd)
				_strike(centre, sd.radius_px * Game.PX, base)
		"dive":
			_tick_dive(base)
		"javelin", "fissure":
			_accel_to(Vector3.ZERO, 0.6)
	if sd.kind != "dive":
		_apply_physics()
	if st >= sprite.sheet.total_ticks(sprite.anim) - 1:
		global_position.y = 0.0 if sd.kind == "dive" else global_position.y
		_set_state(S.IDLE)
		_clear_aura()


func _on_special_window(i: int) -> void:
	var sd := cur_special
	match sd.kind:
		"thrusts":
			velocity.x = facing * sd.lunge * 3.0
			Sfx.play("swing", -2.0, 1.1 + 0.04 * i)
			sprite.squash(Vector2(1.2, 0.9))
		"spin":
			Sfx.play("swing_heavy", -4.0, 0.95 + 0.07 * i)
		"javelin":
			if i == 0:
				Game.world.spawn_fx("javelin", sd.id, sprite.anchor_world("hand"), Vector3(facing, 0, 0), peer_id, Vector3.ZERO)
				Sfx.play("swing_heavy", -1.0, 1.2)
		"fissure":
			if i == 0:
				Game.world.spawn_fx("fissure", sd.id, global_position + Vector3(facing * 0.8, 0, 0), Vector3(facing, 0, 0), peer_id, Vector3.ZERO)
				Sfx.play("quake", -1.0)
		"dive":
			pass


func _tick_dive(base: Dictionary) -> void:
	var sd := cur_special
	var an := sprite.anim
	var leap := sprite.sheet.frame_start(an, 1)
	var land: int = (_windows[0] as Vector2i).x if not _windows.is_empty() else 20
	iframes = maxi(iframes, 2)
	if st < leap:
		velocity = Vector3.ZERO
		_apply_physics()
		return
	if st < land:
		var u := float(st - leap) / float(land - leap)
		var p := _dive_from.lerp(_dive_to, smoothstep(0.0, 1.0, u))
		var y := 2.6 * sin(PI * u)
		velocity = Vector3.ZERO
		global_position = Vector3(p.x, y, p.z)
		return
	if st == land:
		global_position.y = 0.0
		velocity = Vector3.ZERO
		_slam_fx()
	if _win_at(st) >= 0:
		var centre := global_position + Vector3(facing * sd.reach_px * Game.PX, 0, 0)
		base["sfx"] = "hit_heavy"
		_strike(centre, sd.radius_px * Game.PX, base)
	_apply_physics()


func _slam_fx() -> void:
	var p := global_position
	Sfx.play("quake", 0.0, 0.8)
	Juice.shake(0.45)
	Juice.fov_punch = -1.5
	Juice.crater(p, cur_special.color, 2.2)
	sprite.squash(Vector2(1.5, 0.6))


# -------------------------------------------------------------------- cast

func _start_cast(_f: InputFrame) -> void:
	_set_state(S.CAST)
	mp -= spell.mp_cost
	combo = 0
	sprite.play(_a(spell.cast_anim), true)
	_windows = sprite.sheet.contact_ranges(sprite.anim)
	velocity = Vector3.ZERO
	_trail = null
	Sfx.play("cast", -2.0)
	Game.log_event("cast", {"peer": peer_id, "spell": spell.id})


func _tick_cast(_f: InputFrame, _delta: float) -> void:
	_accel_to(Vector3.ZERO, 0.8)
	if not _windows.is_empty() and st == (_windows[0] as Vector2i).x:
		var origin := sprite.anchor_world("off_hand")
		var target := global_position + Vector3(facing * 5.0, 0, 0)
		var e := _assist_target(11.0, facing)
		if e != null:
			target = e.global_position
		match spell.kind:
			"lance": Game.world.spawn_fx("lance", spell.id, origin, Vector3(facing, 0, 0), peer_id, target)
			"ring": Game.world.spawn_fx("ring", spell.id, global_position, Vector3(facing, 0, 0), peer_id, target)
			"comet": Game.world.spawn_fx("comet", spell.id, origin, Vector3(facing, 0, 0), peer_id, target)
		sprite.squash(Vector2(1.12, 0.92))
		Juice.shake(0.18)
		Juice.kick(Vector3(-facing, 0, 0), 0.15)
	_apply_physics()
	if st >= sprite.sheet.total_ticks(sprite.anim) - 1:
		_set_state(S.IDLE)


# ------------------------------------------------------------- hurt / dead

func _tick_hurt(_f: InputFrame, _delta: float) -> void:
	_accel_to(Vector3.ZERO, 0.35)
	_apply_physics()
	if st >= sprite.sheet.total_ticks(sprite.anim) - 2:
		_set_state(S.IDLE)


func _tick_dead(_f: InputFrame, _delta: float) -> void:
	_accel_to(Vector3.ZERO, 0.8)
	_apply_physics()
	_respawn -= 1
	if _respawn <= 0:
		hp = max_hp
		mp = max_mp
		global_position = _spawn_pos
		reset_physics_interpolation()
		iframes = 100
		_set_state(S.IDLE)
		sprite.play(_b("idle"), true)
		Juice.ring(global_position, Color(0.6, 1, 0.9), 2.2, 0.5, true)
		Game.log_event("respawn", {"peer": peer_id})


func _tick_victory(f: InputFrame, _delta: float) -> void:
	_accel_to(Vector3.ZERO, 0.8)
	_apply_physics()
	_victory_t += 1
	if _victory_t > 70 and (f.move.length() > 0.3 or f.pressed != 0):
		_set_state(S.IDLE)
	elif _victory_t > 240:
		_set_state(S.IDLE)


func start_victory() -> void:
	if state == S.DEAD or not is_multiplayer_authority():
		return
	_set_state(S.VICTORY)
	_victory_t = 0
	velocity = Vector3.ZERO
	hitstop = 0
	sprite.play(_b("victory"), true)
	sprite.squash(Vector2(0.85, 1.25))
	Sfx.play("victory", -2.0)


func add_exp(n: int) -> void:
	exp_total += n
	while exp_total >= exp_next:
		exp_total -= exp_next
		level += 1
		exp_next = int(exp_next * 1.5)
		max_hp += 12
		hp = max_hp
		max_mp += 6
		mp = max_mp
		Sfx.play("level_up")
		Juice.level_up(global_position)
		Juice.popup(global_position + Vector3(0, 2.1, 0), "LEVEL UP!  Lv %d" % level, Color(1, 0.95, 0.5))


# -------------------------------------------------------------- damage in

func receive_hit(dmg: int, dir: Vector3, kb: float, _from_pos: Vector3) -> void:
	## Called on the authoritative peer (directly, or via the host's RPC).
	if state == S.DEAD or iframes > 0:
		return
	if state == S.DASH and st < DASH_MOVE_TICKS + 1:
		return
	hp = maxi(0, hp - dmg)
	iframes = 55
	hitstop = 5
	velocity = Vector3(dir.x * kb, 0, dir.z * kb)
	_trail = null
	_clear_aura()
	sprite.flash(1.0, Color(1, 0.4, 0.4))
	sprite.squash(Vector2(1.2, 0.82))
	Sfx.play("hurt", -1.0)
	Juice.hit(global_position + Vector3(0, 0.8, 0.2), dir, Color(1, 0.45, 0.4), 0.55, 0.4)
	Juice.damage_number(global_position + Vector3(0, 1.7, 0), dmg, false, Color(1, 0.5, 0.5))
	Juice.hurt_flash()
	Game.log_event("player_hurt", {"peer": peer_id, "dmg": dmg})
	Game.combo_timer = 1       # taking a hit breaks the combo counter
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
		sprite.play(_b("hurt"), true)


@rpc("any_peer", "call_remote", "reliable")
func rpc_take_hit(dmg: int, dir: Vector3, kb: float, from_pos: Vector3) -> void:
	if is_multiplayer_authority():
		receive_hit(dmg, dir, kb, from_pos)


func take_hit_from_host(dmg: int, dir: Vector3, kb: float, from_pos: Vector3) -> void:
	if is_multiplayer_authority():
		receive_hit(dmg, dir, kb, from_pos)
	else:
		rpc_id(peer_id, "rpc_take_hit", dmg, dir, kb, from_pos)


@rpc("authority", "call_remote", "reliable")
func rpc_victory() -> void:
	start_victory()


# ---------------------------------------------------- visual effects by tick
# Runs on every peer, local and remote, from the animation tick: slash arcs, trails, auras.

func _clear_aura() -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null


func _anim_fx() -> void:
	var an := sprite.anim
	var cur := sprite.tick
	var prev := _fx_prev_tick if an == _fx_prev_anim else -1
	_fx_prev_anim = an
	_fx_prev_tick = cur
	if weapon == null or not sprite.sheet.has_anim(an):
		return
	var crossed := func(x: int) -> bool: return prev < x and cur >= x
	var atk := Registry.attack_for_anim(an)
	var spc := Registry.special_for_anim(an)
	var wins := sprite.sheet.contact_ranges(an)
	if base_of(an) == "dash":
		if cur >= DASH_START and cur < DASH_MOVE_TICKS and cur % 4 == 0 and prev != cur:
			sprite.afterimage(Color(0.5, 0.9, 0.9), 0.18)
		return
	if atk != null and not wins.is_empty():
		var w0: Vector2i = wins[0]
		if cur >= w0.x - 3 and cur <= w0.y + 1:
			if _trail == null or not is_instance_valid(_trail):
				_trail = WeaponTrail.new()
				_trail.color = atk.trail_color
				Juice.fx_root.add_child(_trail)
			_trail.add_sample(sprite.anchor_world("hand"), sprite.anchor_world("weapon_tip"))
		elif _trail != null and cur > w0.y + 1:
			_trail.done = true
			_trail = null
		return
	if spc != null and not wins.is_empty():
		var first: Vector2i = wins[0]
		var last: Vector2i = wins[-1]
		match spc.kind:
			"spin":
				if crossed.call(first.x):
					_clear_aura()
					_aura = Juice.cyclone(self, spc.color, float(last.y - first.x) / 60.0, spc.radius_px * Game.PX)
			"thrusts":
				for w in wins:
					if crossed.call((w as Vector2i).x):
						Juice.thrust_streak(sprite.anchor_world("hand"), facing, spc.color, spc.reach_px * Game.PX)
			"dive":
				var leap := sprite.sheet.frame_start(an, 1)
				if crossed.call(leap):
					_clear_aura()
					_aura = Juice.meteor_aura(self, spc.color, float(first.x - leap) / 60.0)
				if cur >= leap and cur < first.x:
					if _trail == null or not is_instance_valid(_trail):
						_trail = WeaponTrail.new()
						_trail.color = spc.color
						Juice.fx_root.add_child(_trail)
					_trail.add_sample(sprite.anchor_world("hand") + Vector3(0, 0.3, 0), sprite.anchor_world("weapon_tip") + Vector3(0, -0.1, 0))
				elif _trail != null and cur >= first.x:
					_trail.done = true
					_trail = null
			"javelin", "fissure":
				pass
		return
	if an.begins_with("cast"):
		if prev < 0 or crossed.call(0):
			var col := spell.color if spell != null else Color(0.6, 0.9, 1)
			Juice.magic_circle(global_position, col, 0.9, 3.0 if an != "cast" else 2.6)
	elif _trail != null:
		_trail.done = true
		_trail = null
