class_name Fighter
extends Node2D
## Um lutador: máquina de estados por frame (60 fps), recursos (vida, espírito, cartas) e visual.

const GRAVITY := 0.42
const MAX_FALL := 10.0
const WALL := 470.0
const PUSH_W := 13.0
const HP_MAX := 10000.0
const SPIRIT_MAX := 5.0
const HAND_MAX := 4

var battle: Node
var kit: Kit
var data: CharData
var pid := 0
var opp: Fighter
var inp := InputState.new()
var cpu: RefCounted = null
var alt_palette := false

# física
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var facing := 1
var grounded := true
var grav_scale := 1.0

# estado
var state := "idle"
var sf := 0
var mv: Dictionary = {}
var mv_id := ""
var mv_contact := false
var mv_hit := false
var mv_hits := 0
var mv_lock := 0
var anim := "idle"
var at := 0
var fi := 0
var freeze := 0          # congelamento individual (tomou tiro)
var landing_lag := 6

# recursos
var hp := HP_MAX
var hp_shown := HP_MAX   # barra "fantasma"
var spirit := SPIRIT_MAX
var spirit_delay := 0
var crushed := 0
var card_gauge := 0.0
var hand: Array = []
var deck: Array = []
var air_jumps := 1
var fly_used := false
var buffs := {}
var heal_left := 0.0

# combate
var hitstun := 0
var blockstun := 0
var block_low := false
var untech := false
var combo_hits := 0
var combo_dmg := 0.0
var prorate := 1.0
var limit := 0.0
var strike_inv := 0
var proj_inv := 0
var counter_window := false
var shake := 0
var flash := 0.0
var flash_color := Color.WHITE
var last_hit_frame := -100
var wins := 0
var spell_card := ""
var spell_t := 0
var spell_data := {}
var grazed_this := 0
var ghost_t := 0
var ghost_color := Color(0.6, 0.9, 1.0, 0.5)
var ko := false

var spr: Sprite2D
var mat: ShaderMaterial


func setup(b: Node, cid: String, p: int, alt: bool) -> void:
	battle = b
	pid = p
	alt_palette = alt
	data = CharData.get_data(cid)
	kit = Kit.create(cid)
	ghost_color = kit.ghost_color
	spr = Sprite2D.new()
	spr.texture = data.tex_b if alt else data.tex_a
	spr.region_enabled = true
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/fighter.gdshader")
	spr.material = mat
	add_child(spr)
	set_anim("idle")


func reset_round(x: float) -> void:
	pos = Vector2(x, 0)
	vel = Vector2.ZERO
	grounded = true
	hp = HP_MAX
	hp_shown = HP_MAX
	spirit = SPIRIT_MAX
	spirit_delay = 0
	crushed = 0
	card_gauge = maxf(card_gauge, 0.0)
	hitstun = 0
	blockstun = 0
	untech = false
	ko = false
	freeze = 0
	buffs.clear()
	heal_left = 0.0
	reset_combo()
	if deck.is_empty():
		deck = kit.deck.duplicate()
		deck.shuffle()
	facing = 1 if x < 0 else -1
	enter("idle")


func reset_combo() -> void:
	combo_hits = 0
	combo_dmg = 0.0
	prorate = 1.0
	limit = 0.0


# ------------------------------------------------------------------ animação

func set_anim(name: String, restart := true) -> void:
	if not data.has_anim(name):
		name = "idle"
	if name == anim and not restart:
		return
	anim = name
	at = 0
	fi = 0


func frame() -> Dictionary:
	return data.anims[anim]["frames"][fi]


func anim_done() -> bool:
	var a: Dictionary = data.anims[anim]
	return not a["loop"] and at >= int(a["total"])


func _advance_anim() -> void:
	var a: Dictionary = data.anims[anim]
	var prev_t := at
	at += 1
	fi = data.frame_at(anim, at)
	for ev in a["events"]:
		if int(ev[0]) > prev_t and int(ev[0]) <= at:
			kit.on_event(self, str(ev[1]))
		elif at == 1 and int(ev[0]) == 0:
			kit.on_event(self, str(ev[1]))


func point(name: String) -> Vector2:
	var pts: Dictionary = frame()["pts_v"]
	var p: Vector2 = pts.get(name, Vector2(0, -50))
	return pos + Vector2(p.x * facing, p.y)


func _world_rect(r: Rect2) -> Rect2:
	if facing == 1:
		return Rect2(pos + r.position, r.size)
	return Rect2(Vector2(pos.x - r.position.x - r.size.x, pos.y + r.position.y), r.size)


func hurtboxes() -> Array:
	var out := []
	for r in frame()["hurt_r"]:
		out.append(_world_rect(r))
	return out


func hitboxes() -> Array:
	var out := []
	for r in frame()["hit_r"]:
		out.append(_world_rect(r))
	return out


func body_rect() -> Rect2:
	return Rect2(pos.x - PUSH_W, pos.y - 70, PUSH_W * 2, 70)


func center() -> Vector2:
	return pos + Vector2(0, -44)


# ------------------------------------------------------------------ estados

func enter(s: String, a := "") -> void:
	state = s
	sf = 0
	grav_scale = 1.0
	match s:
		"idle":
			set_anim("idle", false if anim == "idle" else true)
		"crouch":
			if anim != "crouch" and anim != "block_low":
				set_anim("crouch")
		_:
			set_anim(a if a != "" else s)


func neutral() -> void:
	if grounded:
		if inp.down():
			enter("crouch")
			set_anim("crouch")
			at = 6
		else:
			enter("idle")
	else:
		enter("air", "fall")


func is_neutral() -> bool:
	return state in ["idle", "walk_f", "walk_b", "crouch", "air"] or (state == "land" and sf >= 3)


func is_attacking() -> bool:
	return state == "move" or state == "spell" or state == "declare"


func in_air_state() -> bool:
	return not grounded


func grazing() -> bool:
	if proj_inv > 0:
		return true
	match state:
		"dash_f", "fly":
			return true
		"dash_b":
			return sf < 14
	if state == "move" and mv.get("graze", false):
		return true
	return false


func can_block() -> bool:
	if crushed > 0 and state == "crush":
		return false
	if state in ["idle", "walk_f", "walk_b", "crouch", "block", "air", "land", "jump_squat", "stand_up"]:
		return inp.back(facing) or (cpu != null and cpu.wants_block)
	return false


func tick() -> void:
	if freeze > 0:
		freeze -= 1
		return
	sf += 1
	_timers()
	match state:
		"intro", "win", "lose":
			pass
		"idle", "walk_f", "walk_b":
			_ground_neutral()
		"crouch":
			_crouch()
		"stand_up":
			if not _try_actions() and sf >= 6:
				enter("idle")
		"jump_squat":
			if sf >= 4:
				_jump()
		"air":
			_air_neutral()
		"land":
			if not (sf >= 3 and _try_actions()) and sf >= landing_lag:
				neutral()
		"dash_f":
			_dash_f()
		"dash_b":
			_dash_b()
		"fly":
			_fly()
		"move":
			_move()
		"block":
			blockstun -= 1
			if not grounded:
				pass
			elif blockstun <= 0:
				neutral()
		"hit":
			hitstun -= 1
			vel.x *= 0.86
			if hitstun <= 0:
				reset_combo_if_free()
				enter("idle")
		"hit_air":
			hitstun -= 1
			if hitstun <= 0 and not untech and pos.y < -20:
				_air_recover()
		"air_recover":
			if sf >= 14:
				enter("air", "fall")
		"knockdown":
			if grounded:
				vel.x *= 0.8
				if sf >= 54 and not ko:
					enter("wakeup")
					strike_inv = 30
					proj_inv = 30
		"wakeup":
			strike_inv = maxi(strike_inv, 2)
			proj_inv = maxi(proj_inv, 2)
			if anim_done():
				reset_combo()
				neutral()
		"crush":
			vel.x *= 0.85
			if sf >= 54:
				neutral()
		"declare":
			pass
		"spell":
			spell_t += 1
			if kit.spell_tick(self):
				spell_card = ""
				battle.spell_ended(self)
				neutral()
	_physics()
	_advance_anim()
	_auto_face()


func reset_combo_if_free() -> void:
	reset_combo()


func _timers() -> void:
	if strike_inv > 0:
		strike_inv -= 1
	if proj_inv > 0:
		proj_inv -= 1
	if crushed > 0:
		crushed -= 1
	for k in buffs.keys():
		buffs[k] -= 1
		if buffs[k] <= 0:
			buffs.erase(k)
	if heal_left > 0.0:
		var h := minf(heal_left, 12.0)
		heal_left -= h
		hp = minf(HP_MAX, hp + h)
		hp_shown = maxf(hp_shown, hp)
	if spirit_delay > 0:
		spirit_delay -= 1
	elif crushed <= 0 and spirit < SPIRIT_MAX and state not in ["block", "fly", "crush"]:
		var rate := 0.035 * (2.0 if buffs.has("vento") else 1.0) * (1.5 if battle.stage.weather == 2 else 1.0)
		spirit = minf(SPIRIT_MAX, spirit + rate)
	if hp_shown > hp:
		if not (state in ["hit", "hit_air", "knockdown"]) or sf > 30:
			hp_shown = maxf(hp, hp_shown - 40.0)
	# cartas
	if card_gauge >= 100.0 and hand.size() < HAND_MAX:
		card_gauge -= 100.0
		_draw_card()


func _draw_card() -> void:
	if deck.is_empty():
		deck = kit.deck.duplicate()
		deck.shuffle()
	var c = deck.pop_front()
	hand.append(c)
	battle.on_card_drawn(self, c)


func gain_card(amount: float) -> void:
	if battle and battle.stage and battle.stage.weather == 1:
		amount *= 1.5   # Chuva de Estrelas
	if hand.size() >= HAND_MAX:
		card_gauge = minf(100.0, card_gauge + amount)
	else:
		card_gauge = minf(199.0, card_gauge + amount)


func speed_mult() -> float:
	return 1.15 if buffs.has("vento") else 1.0


func _ground_neutral() -> void:
	if _try_actions():
		return
	if inp.down():
		enter("crouch")
		return
	if inp.fwd(facing):
		if state != "walk_f":
			enter("walk_f")
		vel.x = kit.walk_f * facing * speed_mult()
		if sf % 18 == 9:
			Audio.play("step", -14.0, 1.0, 0.15)
	elif inp.back(facing):
		if state != "walk_b":
			enter("walk_b")
		vel.x = -kit.walk_b * facing * speed_mult()
	else:
		if state != "idle":
			enter("idle")
		vel.x = 0.0


func _crouch() -> void:
	vel.x = 0.0
	if _try_actions():
		return
	if not inp.down():
		enter("stand_up")


func _air_neutral() -> void:
	if _try_actions():
		return
	if vel.y > 0.0 and anim == "jump" and at > 10:
		set_anim("fall")


func _jump() -> void:
	var dx := inp.dir.x
	grounded = false
	vel.y = kit.jump_v
	vel.x = float(dx) * kit.jump_x * speed_mult()
	if prev_state_was_dash:
		vel.x = float(facing) * kit.jump_x * 1.7
	prev_state_was_dash = false
	enter("air", "jump")
	Audio.play("jump", -6.0)
	battle.fx.dust(pos, 1.0, facing)


var prev_state_was_dash := false


func _air_recover() -> void:
	enter("air_recover", "spin")
	strike_inv = 14
	proj_inv = 14
	vel = Vector2(-facing * 1.5, -3.0)
	reset_combo()
	battle.fx.ring(center(), Color(0.8, 0.9, 1.0), 26.0, 12)
	Audio.play("dash", -8.0, 1.3)


func _try_actions() -> bool:
	## lê a entrada e começa golpes, pulos e dashes. Retorna true se mudou de estado.
	if state == "move" and not mv.is_empty():
		pass
	# carta
	if inp.pressed("switch", 3):
		inp.consume("switch")
		if hand.size() > 1:
			hand.append(hand.pop_front())
			Audio.play("card_select", -6.0)
			battle.hud.card_cycled(pid)
	if inp.pressed("spell", 5) and not hand.is_empty():
		if try_card():
			return true
	if grounded:
		if inp.pressed("a"):
			inp.consume("a")
			var id := "a5_1"
			if state == "dash_f":
				id = "ad"
			elif inp.down():
				id = "a2"
			elif inp.fwd(facing):
				id = "a6"
			return start_move(id)
		if inp.pressed("b"):
			inp.consume("b")
			var idb := "b5"
			if inp.down():
				idb = "b2c"
			elif inp.up():
				idb = "b2"
			return start_move(idb)
		if inp.pressed("c"):
			inp.consume("c")
			var idc := "c5"
			if inp.down():
				idc = "c2"
			elif inp.fwd(facing):
				idc = "c6"
			return start_move(idc)
		if inp.pressed("dash", 4) and state != "dash_f" and state != "dash_b":
			inp.consume("dash")
			if inp.back(facing):
				return start_dash_b()
			return start_dash_f()
		if inp.up() and state != "jump_squat":
			prev_state_was_dash = state == "dash_f"
			enter("jump_squat")
			vel.x = 0.0
			return true
	else:
		if inp.pressed("a"):
			inp.consume("a")
			return start_move("aj2" if inp.down() else "aj")
		if inp.pressed("b"):
			inp.consume("b")
			return start_move("bj")
		if inp.pressed("c"):
			inp.consume("c")
			return start_move("cj")
		if inp.pressed("dash", 4) and not fly_used and state != "fly":
			inp.consume("dash")
			return start_fly()
		if inp.up_age == 0 and air_jumps > 0 and state == "air":
			air_jumps -= 1
			vel.y = kit.jump_v * 0.88
			vel.x = float(inp.dir.x) * kit.jump_x * speed_mult()
			enter("air", "jump")
			Audio.play("jump", -7.0, 1.15)
			battle.fx.ring(pos + Vector2(0, -6), Color(1, 1, 1, 0.8), 18.0, 10, 0.35)
			return true
	return false


func try_card() -> bool:
	var cid: String = hand[0]
	var card: Dictionary = Cards.get_card(cid)
	var cost: int = card["cost"]
	if hand.size() < cost:
		if inp.pressed("spell", 0):
			Audio.play("ui_error", -10.0)
		inp.consume("spell")
		return false
	if card["kind"] == "spell" and not kit.can_spell(self, cid):
		return false
	inp.consume("spell")
	var used := []
	for i in cost:
		used.append(hand.pop_front())
	battle.on_card_used(self, cid, used)
	if card["kind"] == "system":
		Cards.apply_system(self, cid)
		return false
	spell_card = cid
	spell_t = 0
	spell_data = {}
	vel = Vector2(0, 0) if grounded else Vector2(vel.x * 0.2, 0)
	enter("declare", "declare")
	strike_inv = 60
	proj_inv = 60
	battle.declare_spell(self, cid)
	return true


func start_spell() -> void:
	## chamado pela batalha quando a declaração termina
	state = "spell"
	sf = 0
	spell_t = 0
	strike_inv = 0
	proj_inv = 0
	kit.spell_start(self, spell_card)


func start_dash_f() -> bool:
	enter("dash_f")
	vel.x = kit.dash_speed * facing * speed_mult()
	Audio.play("dash", -5.0)
	battle.fx.dust(pos, 1.3, facing)
	return true


func start_dash_b() -> bool:
	enter("dash_b")
	grounded = false
	vel = Vector2(-5.2 * facing, -3.4)
	strike_inv = 7
	Audio.play("dash", -5.0, 0.9)
	battle.fx.dust(pos, 1.0, -facing)
	return true


func start_fly() -> bool:
	if spirit < 0.4 or crushed > 0:
		return false
	use_spirit(0.35)
	fly_used = true
	var d := Vector2(inp.dir)
	if d == Vector2.ZERO:
		d = Vector2(facing, 0)
	fly_dir = d.normalized()
	enter("fly")
	Audio.play("flight", -4.0)
	battle.fx.ring(center(), Color(0.85, 0.95, 1.0, 0.9), 24.0, 12, 0.3)
	return true


var fly_dir := Vector2.RIGHT


func _dash_f() -> void:
	ghost_t += 1
	if ghost_t % 4 == 0:
		battle.fx.afterimage(self)
	if sf > 3 and _try_actions():
		return
	var hold: bool = inp.held["dash"] or inp.fwd(facing)
	var spd := kit.dash_speed * speed_mult()
	if sf < kit.dash_min or (hold and sf < kit.dash_max):
		vel.x = spd * facing
		if sf % 6 == 0:
			battle.fx.dust(pos, 0.6, facing)
	else:
		vel.x *= 0.7
		if absf(vel.x) < 1.0:
			enter("idle")


func _dash_b() -> void:
	if grounded and sf > 4:
		enter("land")
		landing_lag = 5


func _fly() -> void:
	ghost_t += 1
	if ghost_t % 3 == 0:
		battle.fx.afterimage(self)
	if inp.dir != Vector2i.ZERO:
		fly_dir = fly_dir.lerp(Vector2(inp.dir).normalized(), 0.12).normalized()
	vel = fly_dir * kit.fly_speed * speed_mult()
	grav_scale = 0.0
	use_spirit(0.022, false)
	if fly_dir.x != 0.0 and absf(fly_dir.x) > 0.3:
		pass
	if sf > 8 and _try_actions():
		return
	if (not inp.held["dash"] and sf > 12) or sf > 46 or spirit <= 0.0:
		vel *= 0.55
		enter("air", "fall")


func use_spirit(amount: float, delay := true) -> void:
	spirit = maxf(0.0, spirit - amount)
	spirit_delay = maxi(spirit_delay, 45 if delay else 20)


# ------------------------------------------------------------------ golpes

func start_move(id: String) -> bool:
	if not kit.moves.has(id):
		return false
	var m: Dictionary = kit.moves[id]
	var cost: float = m.get("cost", 0.0)
	if cost > 0.0 and (spirit < cost * 0.6 or crushed > 0):
		if inp.pressed("b", 0) or inp.pressed("c", 0):
			pass
		battle.fx.text(center() + Vector2(0, -50), "sem espírito", Color(0.7, 0.75, 1.0), 0.6)
		return false
	if cost > 0.0:
		use_spirit(cost)
	mv = m
	mv_id = id
	mv_contact = false
	mv_hit = false
	mv_hits = 0
	mv_lock = 0
	state = "move"
	sf = 0
	grav_scale = m.get("grav", 1.0)
	set_anim(m["anim"])
	if m.has("vel"):
		var v: Vector2 = m["vel"]
		vel = Vector2(v.x * facing, v.y if not grounded or v.y != 0.0 else 0.0)
		if v.y < 0.0:
			grounded = false
	elif grounded:
		vel.x = 0.0
	if m.has("inv"):
		strike_inv = int(m["inv"])
	kit.move_start(self, id)
	return true


func _move() -> void:
	if mv_lock > 0:
		mv_lock -= 1
	kit.move_tick(self, mv_id)
	if state != "move":
		return
	# som do golpe no primeiro frame ativo
	if sf == int(mv.get("swing_at", -1)):
		Audio.play(mv.get("swing", "swing_light"), -6.0)
	# cancelamentos
	var can_cancel := false
	var cancel_on: String = mv.get("cancel_on", "contact")
	if cancel_on == "contact" and mv_contact:
		can_cancel = true
	elif cancel_on == "always" and sf >= int(mv.get("cancel_from", 0)):
		can_cancel = true
	if can_cancel and _try_cancel():
		return
	# a sequência de golpes (A A A A) encadeia mesmo sem acertar, depois do fim do quadro ativo
	if not mv_contact and mv_id in ["a5_1", "a5_2", "a5_3"] and grounded and sf >= int(mv.get("swing_at", 3)) + 7:
		if inp.pressed("a", 6) and not inp.down() and not inp.fwd(facing):
			inp.consume("a")
			start_move(kit.next_chain(mv_id))
			return
	if grounded and mv.get("air", false) and sf > 2:
		enter("land")
		landing_lag = 7
		return
	if anim_done():
		if mv.get("air", false) or not grounded:
			enter("air", "fall")
		elif mv.get("crouch", false):
			enter("crouch")
			set_anim("crouch")
			at = 6
		else:
			enter("idle")
	if grounded and not mv.has("keep_vel"):
		vel.x *= 0.8


func _try_cancel() -> bool:
	var allowed: Array = mv.get("cancel", [])
	if allowed.is_empty():
		return false
	if "spell" in allowed and inp.pressed("spell", 5) and not hand.is_empty():
		if try_card():
			return true
	var want := ""
	if inp.pressed("a"):
		if grounded:
			want = "a2" if inp.down() else ("a6" if inp.fwd(facing) else kit.next_chain(mv_id))
		else:
			want = "aj2" if inp.down() else "aj"
		if want in allowed:
			inp.consume("a")
			return start_move(want)
	if inp.pressed("b"):
		if grounded:
			want = "b2c" if inp.down() else ("b2" if inp.up() else "b5")
		else:
			want = "bj"
		if want in allowed:
			inp.consume("b")
			return start_move(want)
	if inp.pressed("c"):
		if grounded:
			want = "c2" if inp.down() else ("c6" if inp.fwd(facing) else "c5")
		else:
			want = "cj"
		if want in allowed:
			inp.consume("c")
			return start_move(want)
	if "jump" in allowed and inp.up_age <= 2 and grounded:
		enter("jump_squat")
		return true
	return false


# ------------------------------------------------------------------ física

func _physics() -> void:
	if state in ["declare"]:
		return
	if not grounded:
		vel.y = minf(vel.y + GRAVITY * grav_scale, MAX_FALL)
	pos += vel
	if state in ["hit", "crush", "knockdown"] and grounded:
		pass
	if not grounded and pos.y >= 0.0 and vel.y >= 0.0:
		pos.y = 0.0
		_land()
	elif grounded:
		pos.y = 0.0
		vel.y = 0.0
	var w := WALL
	if pos.x < -w or pos.x > w:
		var hit_wall := state == "hit_air" and absf(vel.x) > 4.0 and untech
		pos.x = clampf(pos.x, -w, w)
		if hit_wall and wallbounce:
			wallbounce = false
			vel.x = -vel.x * 0.45
			vel.y = minf(vel.y, -4.0)
			battle.on_wallbounce(self)
		else:
			vel.x = 0.0


var wallbounce := false


func _land() -> void:
	grounded = true
	air_jumps = 1
	fly_used = false
	match state:
		"hit_air":
			if untech or hitstun > 0:
				if vel.y > 6.5 and not bounced:
					bounced = true
					grounded = false
					vel.y = -vel.y * 0.38
					vel.x *= 0.6
					battle.on_groundbounce(self)
					return
				enter("knockdown", "knockdown")
				set_anim("knockdown")
				at = 10
				vel.x *= 0.5
				vel.y = 0.0
				strike_inv = 60
				proj_inv = 60
				battle.fx.dust(pos, 1.6, facing)
				Audio.play("land", -2.0, 0.8)
			else:
				_soft_land()
		"knockdown":
			vel.y = 0.0
		"move":
			if mv.get("air", false):
				kit.on_land(self, mv_id)
				if state == "move":
					_soft_land()
			else:
				vel.y = 0.0
		"spell":
			vel.y = 0.0
			kit.on_land(self, "spell")
		"block":
			vel.y = 0.0
			if blockstun <= 0:
				_soft_land()
		_:
			_soft_land()
	bounced = false


var bounced := false


func _soft_land() -> void:
	vel.y = 0.0
	vel.x *= 0.3
	enter("land", "land")
	landing_lag = 6
	battle.fx.dust(pos, 0.8, facing)
	Audio.play("land", -9.0)


func _auto_face() -> void:
	if opp == null:
		return
	if grounded and state in ["idle", "walk_f", "walk_b", "crouch", "land", "stand_up", "wakeup", "block"]:
		var want := 1 if opp.pos.x >= pos.x else -1
		if absf(opp.pos.x - pos.x) < 2.0:
			return
		if want != facing:
			facing = want
			if state == "walk_f":
				enter("walk_b")
			elif state == "walk_b":
				enter("walk_f")


func face_opponent() -> void:
	if opp and absf(opp.pos.x - pos.x) > 1.0:
		facing = 1 if opp.pos.x >= pos.x else -1


# ------------------------------------------------------------------ dano

func take_hit(att: Fighter, m: Dictionary, dmg: float, counter: bool, from_dir: int) -> void:
	hp = maxf(0.0, hp - dmg)
	combo_hits += 1
	combo_dmg += dmg
	prorate = maxf(0.18, prorate * float(m.get("prorate", 0.9)))
	limit += float(m.get("limit", 10))
	last_hit_frame = battle.frame
	var stun: int = int(m.get("stun", 16))
	if counter:
		stun = int(stun * 1.4)
	var kb: Vector2 = m.get("kb", Vector2(2.5, 0))
	var launch: bool = m.get("launch", false)
	var airborne := not grounded or launch or kb.y < -0.5
	if not grounded and m.has("air_kb"):
		kb = m["air_kb"]
	elif not grounded and kb.y >= 0.0 and not m.get("spike", false):
		kb = Vector2(kb.x, -3.5)
	vel = Vector2(kb.x * from_dir, kb.y)
	if m.get("knockdown", false) or limit >= 100.0 or hp <= 0.0:
		untech = true
	wallbounce = m.get("wallbounce", false)
	hitstun = stun
	if airborne:
		grounded = false
		if vel.y >= 0.0 and pos.y >= -2.0:
			vel.y = -3.0
		enter("hit_air", "spin" if (launch and kb.y < -6.0) else "hit_air")
	elif untech and m.get("trip", false):
		grounded = false
		vel.y = -3.5
		enter("hit_air", "hit_air")
	else:
		enter("hit", "hit_lo" if m.get("guard", "mid") == "low" or block_low else "hit_hi")
	if hp <= 0.0:
		ko = true
		untech = true
		grounded = false
		vel = Vector2(from_dir * maxf(4.0, absf(kb.x)), minf(-6.0, kb.y))
		enter("hit_air", "spin")


func take_block(att: Fighter, m: Dictionary, from_dir: int, chip_spirit: float) -> void:
	blockstun = int(m.get("bstun", 12))
	var crouching := inp.down() and grounded
	block_low = crouching
	if state != "block":
		enter("block", "block_air" if not grounded else ("block_low" if crouching else "block"))
	else:
		sf = 0
	vel.x = float(m.get("push", 3.0)) * from_dir
	spirit = maxf(0.0, spirit - chip_spirit)
	spirit_delay = maxi(spirit_delay, 50)
	hp = maxf(1.0, hp - float(m.get("chip", 0.0)))
	if spirit <= 0.0:
		crush()


func crush() -> void:
	crushed = 160
	spirit = 0.0
	grounded = pos.y >= -1.0
	enter("crush", "crush")
	vel.x = -facing * 2.0
	battle.on_crush(self)


# ------------------------------------------------------------------ visual

func _process(_delta: float) -> void:
	var fr := frame()
	var r: Rect2 = fr["rect"]
	spr.region_rect = r
	spr.offset = -fr["origin"]
	spr.scale = Vector2(facing, 1)
	var off := Vector2.ZERO
	if shake > 0:
		off.x = (2.0 if (shake % 2 == 0) else -2.0) * minf(1.0, shake / 4.0)
	position = (pos + off).round() if false else pos + off
	if flash > 0.0:
		flash = maxf(0.0, flash - _delta * 6.0)
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("flash_color", flash_color)
	var tint := Color.WHITE
	if crushed > 0 and state == "crush":
		tint = Color(1.0, 0.7, 0.75) if (Engine.get_frames_drawn() / 6) % 2 == 0 else Color.WHITE
	if buffs.has("vento"):
		tint = tint * Color(0.95, 1.05, 1.1)
	var lf: float = battle.stage.flash if battle and battle.stage else 0.0
	if lf > 0.0:
		tint = tint.lerp(Color(1.3, 1.45, 1.7), lf * 0.6)
	mat.set_shader_parameter("tint", tint)
	var inv := strike_inv > 0 and state in ["wakeup", "air_recover"]
	modulate.a = 0.55 if (inv and (Engine.get_frames_drawn() / 3) % 2 == 0) else 1.0
	z_index = 10 if is_attacking() else 5
