class_name Player
extends CharacterBody3D
## Heroi. No dono (is_local) le o teclado, simula e manda o estado; nos outros
## jogadores e um fantoche que interpola a posicao e repete as acoes recebidas.

enum St { NORMAL, ACTION, DODGE, HIT, DOWN, EMOTE }

const BASE_ATK := 20.0
const GRAVITY := 26.0
const JUMP_V := 9.2
const DODGE_TIME := 0.46
const DODGE_IFRAMES := 0.36
const DODGE_DIST := 5.6
const SEND_RATE := 1.0 / 20.0
const SLOTS := ["primary", "secondary", "q", "r", "ult"]
const SLOT_ACTIONS := {"primary": "attack", "secondary": "secondary", "q": "skill1", "r": "skill2", "ult": "ultimate"}

var peer_id := 1
var is_local := false
var info: Dictionary = {}
var cls := "espadachim"
var wt := "sword"

var visual: HeroVisual
var rig: CameraRig
var skills: Skills
var procs: Procs
var name_tag: Label3D

# --- estado de jogo (o dono e a autoridade)
var state: int = St.NORMAL
var hp := 100.0
var max_hp := 100.0
var shield := 0.0
var shield_t := 0.0
var gold := 0
var boons: Dictionary = {}
var relics: Array = []
var slots: Dictionary = {}
var cds: Dictionary = {}
var cd_max: Dictionary = {}
var stats: Dictionary = {}
var flasks := 0
var revives_left := 0
var kills := 0
var dmg_done := 0.0
var downs := 0
var buffs: Dictionary = {}       # nome -> {t, v}

# --- movimento / acoes
var wish := Vector3.ZERO
var face_yaw := 0.0
var action_id := 0
var action_end := 0.0
var action_cancel := 0.0
var action_move := 0.0
var action_turn := false
var push_vel := Vector3.ZERO
var carry_vel := Vector3.ZERO
var carry_t := 0.0
var buffer_slot := ""
var buffer_t := 0.0
var combo_i := 0
var combo_t := 0.0
var invuln_t := 0.0
var guard_t := 0.0
var guard_v := 0.0
var dodge_charges := 1
var dodge_cd := 0.0
var dodge_dir := Vector3.ZERO
var state_t := 0.0
var jumps_left := 1
var air_t := 0.0
var shot_count := 0
var now := 0.0
var revive_target: Player = null
var revive_prog := 0.0
var being_revived := 0.0
var in_hub := true
var down_t := 0.0

# --- fantoche
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_loco := 0
var net_flags := 0
var busy_until := 0.0
var _send_t := 0.0
var _last_loco := -1

func setup(id: int, p_info: Dictionary) -> void:
	peer_id = id
	name = str(id)
	is_local = id == Net.my_id()
	apply_info(p_info)

func apply_info(p_info: Dictionary) -> void:
	info = p_info
	cls = str(info.get("cls", "espadachim"))
	wt = DB.CLASSES[cls]["wt"]
	if visual:
		visual.apply_look(info.get("look", {}))
		_last_loco = -1
	if name_tag:
		name_tag.text = str(info.get("name", ""))
	if is_local or stats.is_empty():
		_default_slots()
		recalc()
		if in_hub:
			hp = max_hp

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.25
	cs.shape = cap
	cs.position.y = 0.625
	add_child(cs)
	visual = HeroVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.apply_look(info.get("look", {}))
	skills = Skills.new(self)
	procs = Procs.new(self)
	name_tag = Label3D.new()
	name_tag.text = str(info.get("name", ""))
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.font = Ui.font_bold()
	name_tag.font_size = 44
	name_tag.pixel_size = 0.0045
	name_tag.outline_size = 12
	name_tag.outline_modulate = Color("1b1730")
	name_tag.modulate = Color(DB.CLASSES[cls]["color"]).lightened(0.45)
	name_tag.position.y = 1.72
	name_tag.visible = not is_local
	add_child(name_tag)
	net_pos = global_position
	face_yaw = rotation.y
	net_yaw = rotation.y
	if is_local:
		reset_run()

# ------------------------------------------------------------------ atributos
func _default_slots() -> void:
	var c: Dictionary = DB.CLASSES[cls]
	slots = {"primary": c["primary"], "secondary": c["secondary"], "q": c["skills"][0], "r": c["skills"][1], "ult": c["ult"]}
	for s in SLOTS:
		cds[s] = 0.0
		cd_max[s] = 1.0

func reset_run() -> void:
	boons = {}
	relics = []
	gold = 0
	kills = 0
	dmg_done = 0.0
	downs = 0
	buffs = {}
	shield = 0.0
	_default_slots()
	recalc()
	hp = max_hp
	revives_left = int(stats.get("revives", 0))
	flasks = Save.upgrade_level("frasco") * int(DB.UPGRADES["frasco"]["flasks"])
	gold = Save.upgrade_level("ouro") * int(DB.UPGRADES["ouro"]["start_gold"])
	state = St.NORMAL
	dodge_charges = int(stats.get("dodges", 1))
	procs.reset()

func recalc() -> void:
	var m: Dictionary = {}
	var add := func(mods: Dictionary, k: float) -> void:
		for key in mods:
			m[key] = float(m.get(key, 0.0)) + float(mods[key]) * k
	if is_local:
		for id in DB.UPGRADES:
			var lvl := Save.upgrade_level(id)
			if lvl > 0 and DB.UPGRADES[id].has("mods"):
				add.call(DB.UPGRADES[id]["mods"], float(lvl))
	for id in boons:
		if DB.BOONS.has(id):
			add.call(DB.BOONS[id]["mods"], float(boons[id]))
	for id in relics:
		if DB.RELICS.has(id) and DB.RELICS[id].has("mods"):
			add.call(DB.RELICS[id]["mods"], 1.0)
	var c: Dictionary = DB.CLASSES[cls]
	var old_max := max_hp
	max_hp = maxf(10.0, (float(c["hp"]) + float(m.get("max_hp", 0.0))) * (1.0 + float(m.get("hp_pct", 0.0))))
	stats = {
		"atk": BASE_ATK * (1.0 + float(m.get("atk", 0.0))),
		"crit": 0.05 + float(m.get("crit", 0.0)),
		"crit_dmg": 1.6 + float(m.get("crit_dmg", 0.0)),
		"aspd": 1.0 + float(m.get("aspd", 0.0)),
		"speed": float(c["speed"]) * (1.0 + float(m.get("mspd", 0.0))),
		"cdr": clampf(float(m.get("cdr", 0.0)), 0.0, 0.6),
		"ult_cdr": clampf(float(m.get("ult_cdr", 0.0)), 0.0, 0.6),
		"def": clampf(float(m.get("def", 0.0)), 0.0, 0.7),
		"lifesteal": float(m.get("lifesteal", 0.0)),
		"gold": 1.0 + float(m.get("gold", 0.0)),
		"luck": float(m.get("luck", 0.0)),
		"dodges": 1 + int(m.get("dodges", 0.0)),
		"regen": float(m.get("regen", 0.0)),
		"thorns": float(m.get("thorns", 0.0)),
		"skill": 1.0 + float(m.get("skill", 0.0)),
		"primary": 1.0 + float(m.get("primary", 0.0)),
		"p_burn": float(m.get("p_burn", 0.0)), "p_chill": float(m.get("p_chill", 0.0)),
		"p_poison": float(m.get("p_poison", 0.0)), "p_chain": float(m.get("p_chain", 0.0)),
		"jumps": 1 + int(m.get("jumps", 0.0)),
		"size": 1.0 + float(m.get("size", 0.0)),
		"magnet": 2.2 + float(m.get("magnet", 0.0)),
		"heal_bonus": 1.0 + float(m.get("heal_bonus", 0.0)),
		"revives": int(m.get("revives", 0.0)),
		"revive_speed": 1.0 + float(m.get("revive_speed", 0.0)),
	}
	if old_max > 0.0 and max_hp != old_max and not in_hub:
		hp = clampf(hp + maxf(0.0, max_hp - old_max), 1.0, max_hp)
	hp = minf(hp, max_hp)
	if visual:
		visual.scale = Vector3.ONE * float(stats["size"])

func add_boon(id: String) -> void:
	boons[id] = int(boons.get(id, 0)) + 1
	var before := max_hp
	recalc()
	if DB.BOONS[id].has("heal"):
		heal(float(DB.BOONS[id]["heal"]), false)
	dodge_charges = maxi(dodge_charges, 1)

func add_relic(id: String) -> void:
	if relics.has(id):
		return
	relics.append(id)
	recalc()
	if DB.RELICS[id].get("mods", {}).has("revives"):
		revives_left += 1
	procs.on_gain(id)

func set_spell(slot: String, id: String) -> void:
	slots[slot] = id
	cds[slot] = 0.0

func skill_cd(slot: String) -> float:
	var def: Dictionary = DB.SKILLS[slots[slot]]
	var cd := float(def["cd"])
	if slot == "ult":
		cd *= (1.0 - float(stats["cdr"]) * 0.5) * (1.0 - float(stats["ult_cdr"]))
	else:
		cd *= 1.0 - float(stats["cdr"])
	return cd

func buff(bname: String, value: float, time: float) -> void:
	buffs[bname] = {"t": time, "v": value}

func buff_v(bname: String) -> float:
	return float(buffs[bname]["v"]) if buffs.has(bname) else 0.0

# ------------------------------------------------------------------ laco principal
func _physics_process(delta: float) -> void:
	now += delta
	if not is_local:
		_puppet(delta)
		return
	_timers(delta)
	var locked := Game.paused_ui or state == St.DOWN
	var iv := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Dev.bot:
		iv = Dev.bot_move
	wish = Vector3(iv.x, 0, iv.y).rotated(Vector3.UP, rig.yaw if rig else 0.0)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var spd: float = float(stats["speed"]) * (1.0 + buff_v("haste"))
	var hv := Vector3(velocity.x, 0, velocity.z)
	match state:
		St.NORMAL, St.EMOTE:
			hv = hv.move_toward(wish * spd, (60.0 if is_on_floor() else 22.0) * delta)
			if wish.length() > 0.1:
				face_yaw = atan2(-wish.x, -wish.z)
				if state == St.EMOTE:
					state = St.NORMAL
			if not locked:
				_inputs()
		St.ACTION:
			var mv := wish * spd * action_move
			hv = hv.move_toward(mv, 70.0 * delta)
			if carry_t > 0.0:
				carry_t -= delta
				hv = carry_vel
				if carry_t <= 0.0:
					hv = carry_vel * 0.15
			if action_turn and wish.length() > 0.1:
				face_yaw = atan2(-wish.x, -wish.z)
			if not locked:
				_buffer_inputs()
			if now >= action_cancel and buffer_slot != "" and now - buffer_t < 0.4:
				var s := buffer_slot
				buffer_slot = ""
				if _can_use(s):
					skills.use(s)
			elif now >= action_end:
				state = St.NORMAL
			elif now >= action_cancel and wish.length() > 0.5 and action_move == 0.0:
				state = St.NORMAL
		St.DODGE:
			var k := 1.0 - (state_t / DODGE_TIME)
			hv = dodge_dir * (DODGE_DIST / DODGE_TIME) * (0.55 + 0.9 * k)
			if state_t >= DODGE_TIME:
				state = St.NORMAL
		St.HIT:
			hv = hv.move_toward(Vector3.ZERO, 30.0 * delta)
			if state_t >= 0.28:
				state = St.NORMAL
		St.DOWN:
			hv = hv.move_toward(Vector3.ZERO, 40.0 * delta)
			down_t += delta
	state_t += delta
	hv += push_vel
	push_vel = push_vel.move_toward(Vector3.ZERO, 60.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		if air_t > 0.25:
			Fx.dust(global_position, 0.7)
			Sfx.play("land", global_position, 0.6)
		air_t = 0.0
		jumps_left = int(stats["jumps"])
		if velocity.y < 0.0:
			velocity.y = -1.0
	else:
		air_t += delta
		velocity.y -= GRAVITY * delta
	move_and_slide()
	velocity.x -= push_vel.x
	velocity.z -= push_vel.z
	_soft_push()
	if global_position.y < -6.0:
		global_position = Game.world.spawn_point(0)
		velocity = Vector3.ZERO
	rotation.y = lerp_angle(rotation.y, face_yaw, 1.0 - exp(-18.0 * delta))
	_animate()
	_interact_scan(delta)
	_send_t -= delta
	if _send_t <= 0.0:
		_send_t = SEND_RATE
		Game.world.cl_pstate.rpc(global_position, rotation.y, _loco(), _flags(), hp, max_hp, shield)

func _timers(delta: float) -> void:
	for s in SLOTS:
		if cds[s] > 0.0:
			cds[s] = maxf(0.0, cds[s] - delta)
	invuln_t = maxf(0.0, invuln_t - delta)
	guard_t = maxf(0.0, guard_t - delta)
	combo_t = maxf(0.0, combo_t - delta)
	if combo_t <= 0.0:
		combo_i = 0
	var max_d := int(stats["dodges"])
	if dodge_charges < max_d:
		dodge_cd -= delta
		if dodge_cd <= 0.0:
			dodge_charges += 1
			dodge_cd = 1.1
	if shield > 0.0:
		shield_t -= delta
		if shield_t <= 0.0:
			shield = 0.0
	for b in buffs.keys():
		buffs[b]["t"] = float(buffs[b]["t"]) - delta
		if float(buffs[b]["t"]) <= 0.0:
			buffs.erase(b)
	if state != St.DOWN and float(stats["regen"]) > 0.0 and hp < max_hp and not in_hub:
		hp = minf(max_hp, hp + float(stats["regen"]) * delta)
	if in_hub and hp < max_hp:
		hp = max_hp
	procs.tick(delta)

func _inputs() -> void:
	if Dev.bot:
		Dev.bot_inputs(self)
		return
	if Input.is_action_just_pressed("jump") and jumps_left > 0:
		do_jump()
	if Input.is_action_just_pressed("dodge"):
		do_dodge()
	for s in SLOTS:
		var act: String = SLOT_ACTIONS[s]
		var pressed := Input.is_action_pressed(act) if s == "primary" else Input.is_action_just_pressed(act)
		if pressed and _can_use(s):
			skills.use(s)
			return
	if Input.is_action_just_pressed("flask"):
		use_flask()
	for i in 4:
		if Input.is_action_just_pressed("emote%d" % (i + 1)):
			do_emote(i)

func _buffer_inputs() -> void:
	if Dev.bot:
		Dev.bot_inputs(self)
		return
	for s in SLOTS:
		var act: String = SLOT_ACTIONS[s]
		var pressed := Input.is_action_pressed(act) if s == "primary" else Input.is_action_just_pressed(act)
		if pressed:
			buffer_slot = s
			buffer_t = now
	if Input.is_action_just_pressed("dodge") and now >= action_cancel - 0.12:
		do_dodge()

func _can_use(slot: String) -> bool:
	if in_hub and not Game.world.hub_combat_ok(self):
		return false
	return cds.get(slot, 0.0) <= 0.0 and (state == St.NORMAL or state == St.EMOTE or (state == St.ACTION and now >= action_cancel))

# ------------------------------------------------------------------ acoes
## Entra em estado de acao por 'dur' segundos. move = fracao da velocidade permitida.
func begin_action(dur: float, cancel: float = -1.0, move: float = 0.0, turn: bool = false) -> int:
	action_id += 1
	state = St.ACTION
	state_t = 0.0
	action_end = now + dur
	action_cancel = now + (cancel if cancel >= 0.0 else dur)
	action_move = move
	action_turn = turn
	buffer_slot = ""
	return action_id

func action_ok(id: int) -> bool:
	return is_inside_tree() and action_id == id and state == St.ACTION

func end_action(id: int) -> void:
	if action_id == id and state == St.ACTION:
		state = St.NORMAL

func start_cd(slot: String) -> void:
	var cd := skill_cd(slot)
	if cd > 0.0 and procs.skill_echo(slot):
		cd = 0.3
	cds[slot] = cd
	cd_max[slot] = maxf(cd, 0.01)

func face_dir(d: Vector3, instant: bool = true) -> void:
	if Vector2(d.x, d.z).length() < 0.01:
		return
	face_yaw = atan2(-d.x, -d.z)
	if instant:
		rotation.y = face_yaw

func forward() -> Vector3:
	return -Basis(Vector3.UP, face_yaw).z

func aim_flat() -> Vector3:
	if Dev.bot:
		return Dev.bot_aim(self)
	return rig.forward() if rig else forward()

## Leva o heroi a uma velocidade fixa por um tempo (investidas, saltos).
func carry(v: Vector3, t: float) -> void:
	carry_vel = v
	carry_t = t

func lunge(dist: float, time: float = 0.14) -> void:
	push_vel = forward() * (dist / maxf(time, 0.01)) * 0.5

func do_jump() -> void:
	velocity.y = JUMP_V
	jumps_left -= 1
	if air_t > 0.05:
		Fx.ring(global_position, 0.9, Color("ffffff"), 0.25)
	Sfx.play("jump", global_position, 0.6)
	Game.world.cl_pevent.rpc("jump", {})

func do_dodge() -> void:
	if dodge_charges <= 0 or state == St.DOWN or state == St.DODGE:
		return
	if dodge_charges == int(stats["dodges"]):
		dodge_cd = 1.1
	dodge_charges -= 1
	action_id += 1
	state = St.DODGE
	state_t = 0.0
	invuln_t = maxf(invuln_t, DODGE_IFRAMES)
	dodge_dir = wish.normalized() if wish.length() > 0.1 else forward()
	face_dir(dodge_dir)
	var origin := global_position
	_on_event_local("dodge", {"d": dodge_dir})
	Game.world.cl_pevent.rpc("dodge", {"d": dodge_dir})
	procs.on_dodge(origin)

func do_emote(i: int) -> void:
	if state != St.NORMAL and state != St.EMOTE:
		return
	state = St.EMOTE
	_on_event_local("emote", {"i": i})
	Game.world.cl_pevent.rpc("emote", {"i": i})

func use_flask() -> void:
	if flasks <= 0 or hp >= max_hp or state == St.DOWN:
		return
	flasks -= 1
	heal(max_hp * 0.4)
	Sfx.play("heal", global_position)

# ------------------------------------------------------------------ dano recebido e cura
func take_damage(amount: float, from: Vector3, kb: float = 0.0, src_eid: int = -1) -> bool:
	if not is_local or state == St.DOWN or in_hub:
		return false
	if invuln_t > 0.0:
		if state == St.DODGE:
			Fx.text(global_position + Vector3(0, 1.9, 0), "Esquivou!", Color("9ffbff"), 0.8)
		return false
	amount *= 1.0 - float(stats["def"])
	if guard_t > 0.0:
		amount *= 1.0 - guard_v
	if buff_v("sanct") > 0.0:
		amount *= 0.5
	amount = maxf(1.0, amount)
	if shield > 0.0:
		var ab := minf(shield, amount)
		shield -= ab
		amount -= ab
		Fx.text(global_position + Vector3(0, 1.9, 0), "Escudo", Color("7df9ff"), 0.7)
	if amount > 0.0:
		hp -= amount
		Fx.number(global_position + Vector3(0, 1.6, 0), amount, Color("ff6b6b"), false, true)
	visual.flash(Color("ff5a5a"), 0.18)
	Sfx.play("hurt", global_position)
	if rig:
		rig.add_trauma(0.35 + minf(0.4, amount / max_hp * 2.0))
	Game.world.hud_hurt(amount / max_hp)
	var dir := global_position - from
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else -forward()
	if float(stats["thorns"]) > 0.0 and src_eid >= 0:
		Game.world.request_hit(src_eid, float(stats["thorns"]), 0, Vector3.ZERO, "", 0.0, self)
	procs.on_hurt(amount, src_eid)
	Game.world.cl_pevent.rpc("hurt", {})
	if hp <= 0.0:
		_go_down()
		return true
	push_vel += dir * kb
	if amount >= max_hp * 0.07 and state != St.DODGE and buff_v("armor") <= 0.0:
		action_id += 1
		state = St.HIT
		state_t = 0.0
		visual.play_once("hit", 0.03, 1.2)
	return true

func heal(amount: float, show: bool = true) -> void:
	if state == St.DOWN:
		return
	amount *= float(stats.get("heal_bonus", 1.0))
	var before := hp
	hp = minf(max_hp, hp + amount)
	if show and hp - before >= 1.0:
		Fx.number(global_position + Vector3(0, 1.7, 0), hp - before, Color("7dff9a"), false, true)
		Fx.heal(self)

func add_shield(amount: float, time: float = 8.0) -> void:
	shield = maxf(shield, amount)
	shield_t = time
	Fx.shield(self, time)

func _go_down() -> void:
	hp = 0.0
	if revives_left > 0:
		revives_left -= 1
		hp = max_hp * 0.5
		invuln_t = 2.5
		Fx.burst(global_position + Vector3(0, 0.8, 0), Color("ffd36b"), 3.0)
		Fx.text(global_position + Vector3(0, 2.0, 0), "Fôlego da Fênix!", Color("ffd36b"), 1.4)
		Sfx.play("revive", global_position)
		Game.world.local_nova(self, 4.0, 2.0, "stun", 1.0)
		return
	action_id += 1
	state = St.DOWN
	state_t = 0.0
	down_t = 0.0
	downs += 1
	velocity = Vector3.ZERO
	_on_event_local("down", {})
	Game.world.cl_pevent.rpc("down", {})
	Sfx.play("down", global_position)
	Game.world.on_local_down()

## Chamado no dono quando um aliado termina de levantar este heroi (ou ao trocar de sala).
func revive(frac: float = 0.4) -> void:
	if state != St.DOWN:
		return
	hp = maxf(1.0, max_hp * frac)
	invuln_t = 2.5
	begin_action(0.7)
	_on_event_local("revive", {})
	Game.world.cl_pevent.rpc("revive", {})
	Sfx.play("revive", global_position)

func is_down() -> bool:
	return state == St.DOWN if is_local else (net_flags & 1) != 0

func alive() -> bool:
	return not is_down()

# ------------------------------------------------------------------ interacao e reviver
func _interact_scan(delta: float) -> void:
	revive_target = null
	if state == St.DOWN or Game.paused_ui:
		Game.world.set_prompt(null)
		revive_prog = 0.0
		return
	for p: Player in Game.world.all_players():
		if p != self and p.is_down() and p.global_position.distance_to(global_position) < 2.3:
			revive_target = p
	if revive_target:
		Game.world.set_prompt_text("Segure [E] para levantar %s" % revive_target.info.get("name", ""))
		if Input.is_action_pressed("interact") or Dev.bot:
			revive_prog += delta * float(stats["revive_speed"]) / 2.4
			Game.world.revive_progress(revive_target, revive_prog)
			if revive_prog >= 1.0:
				revive_prog = 0.0
				Game.world.cl_revived.rpc_id(revive_target.peer_id, 0.4)
				procs.on_revive_ally(revive_target)
		else:
			revive_prog = 0.0
		return
	revive_prog = 0.0
	var it: Node3D = Game.world.nearest_interactable(global_position)
	Game.world.set_prompt(it)
	if it and Input.is_action_just_pressed("interact") and (state == St.NORMAL or state == St.EMOTE):
		it.call("interact", self)

func _soft_push() -> void:
	for e: Enemy in Game.world.enemy_list():
		if e.dead:
			continue
		var d := global_position - e.global_position
		d.y = 0.0
		var min_d: float = e.radius + 0.3
		var l := d.length()
		if l < min_d and l > 0.001 and state != St.DODGE:
			global_position += d / l * (min_d - l) * 0.5

# ------------------------------------------------------------------ animacao e eventos
func _loco() -> int:
	if state == St.DOWN:
		return 3
	if not is_on_floor() and air_t > 0.12:
		return 2
	return 1 if Vector2(velocity.x, velocity.z).length() > 0.8 else 0

func _flags() -> int:
	var f := 0
	if state == St.DOWN:
		f |= 1
	if state == St.ACTION or state == St.DODGE or state == St.HIT or state == St.EMOTE:
		f |= 2
	if shield > 0.0:
		f |= 4
	return f

func _animate() -> void:
	if state != St.NORMAL:
		_last_loco = -1
		return
	_play_loco(_loco(), Vector2(velocity.x, velocity.z).length())

func _play_loco(l: int, speed: float) -> void:
	match l:
		0:
			visual.play(wt + "_idle-loop", 0.18)
		1:
			visual.play(wt + "_run-loop", 0.12, clampf(speed / 5.6, 0.6, 1.6) * 1.12)
		2:
			visual.play(wt + "_air-loop", 0.12)
		3:
			if visual.current != "down" and visual.current != "down-loop":
				visual.play("down-loop", 0.2)

func _on_event_local(kind: String, d: Dictionary) -> void:
	match kind:
		"dodge":
			visual.play_once("dodge", 0.05, 17.0 / 30.0 / DODGE_TIME)
			busy_until = now + DODGE_TIME
			Fx.dust(global_position, 1.0)
			Sfx.play("dodge", global_position)
		"down":
			visual.play_once("down", 0.05)
			busy_until = now + 9999.0
		"revive":
			visual.play_once("getup", 0.1)
			busy_until = now + 0.7
			Fx.burst(global_position + Vector3(0, 0.6, 0), Color("ffe38a"), 1.6)
		"emote":
			var names := ["wave", "cheer", "dance-loop", "sit-loop"]
			var nm: String = names[clampi(int(d.get("i", 0)), 0, 3)]
			visual.play_once(nm, 0.15)
			busy_until = now + (visual.anim_len(nm) if not nm.ends_with("-loop") else 9999.0)
			if is_local and not nm.ends_with("-loop"):
				var t := get_tree().create_timer(visual.anim_len(nm))
				var id := action_id
				t.timeout.connect(func() -> void:
					if action_id == id and state == St.EMOTE:
						state = St.NORMAL)
		"hurt":
			if not is_local:
				visual.flash(Color("ff5a5a"), 0.18)
		"jump":
			pass

## Evento vindo de outro jogador (este no e o fantoche dele).
func on_remote_event(kind: String, d: Dictionary) -> void:
	if kind == "skill":
		skills.play_remote(d)
		return
	_on_event_local(kind, d)

func apply_net_state(pos: Vector3, yaw: float, loco: int, flags: int, p_hp: float, p_max: float, p_shield: float) -> void:
	if global_position.distance_to(pos) > 8.0:
		global_position = pos
	net_pos = pos
	net_yaw = yaw
	net_loco = loco
	var was_down := (net_flags & 1) != 0
	net_flags = flags
	hp = p_hp
	max_hp = p_max
	shield = p_shield
	if was_down and (flags & 1) == 0:
		busy_until = minf(busy_until, now + 0.7)

func _puppet(delta: float) -> void:
	var before := global_position
	global_position = global_position.lerp(net_pos, 1.0 - exp(-14.0 * delta))
	rotation.y = lerp_angle(rotation.y, net_yaw, 1.0 - exp(-16.0 * delta))
	var spd := (global_position - before).length() / maxf(delta, 0.0001)
	if (net_flags & 2) == 0 and (net_flags & 1) == 0 and busy_until > now + 2.0:
		busy_until = now   # saiu de um loop (emote, girar)
	if now >= busy_until:
		_play_loco(net_loco, spd if net_loco == 1 else 0.0)
