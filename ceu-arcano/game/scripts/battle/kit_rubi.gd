extends Kit
## Rubi: ofensiva. Manoplas elétricas, investidas, gancho ascendente e três cartas de trovão.

const VOLT := Color(0.45, 0.92, 1.0)
const RED := Color(1.0, 0.45, 0.3)


func _init() -> void:
	id = "rubi"
	walk_f = 2.7
	walk_b = 2.1
	jump_v = -9.2
	jump_x = 3.4
	dash_speed = 6.8
	dash_min = 10
	dash_max = 60
	fly_speed = 6.0
	ghost_color = Color(1.0, 0.4, 0.35, 0.5)
	deck = ["rubi_s1", "rubi_s1", "rubi_s1", "rubi_s2", "rubi_s2", "rubi_s3", "rubi_s3",
			"elixir", "elixir", "vento", "vento", "rubi_s2"]
	moves = {
		"a5_1": melee("a5_1", 260, 0, {"swing_at": 2, "stun": 14, "cancel": ["a5_2", "a2", "a6", "b5", "b2", "c5", "c6", "c2", "spell"], "spark": "elec"}),
		"a5_2": melee("a5_2", 320, 1, {"swing_at": 3, "kb": Vector2(2.4, 0), "cancel": ["a5_3", "a6", "a2", "b5", "c5", "c6", "c2", "spell"]}),
		"a5_3": melee("a5_3", 420, 1, {"swing_at": 4, "kb": Vector2(3.2, 0), "cancel": ["a5_4", "c5", "c6", "c2", "spell"]}),
		"a5_4": melee("a5_4", 760, 2, {"swing_at": 11, "kb": Vector2(2.0, -9.5), "launch": true, "knockdown": true,
			"cancel": ["c2", "spell"], "limit": 30, "spark": "elec"}),
		"a2": melee("a2", 360, 1, {"swing_at": 4, "guard": "low", "crouch": true, "kb": Vector2(1.5, -3.0),
			"knockdown": true, "trip": true, "cancel": ["c5", "c6", "c2", "spell"]}),
		"a6": melee("a6", 820, 2, {"swing_at": 12, "kb": Vector2(8.5, -3.0), "launch": true, "wallbounce": true,
			"cancel": ["c6", "c2", "spell"], "spark": "elec"}),
		"aj": melee("aj", 400, 1, {"swing_at": 3, "guard": "high", "air": true, "kb": Vector2(3.0, -2.0),
			"cancel": ["aj2", "bj", "cj", "spell"]}),
		"aj2": melee("aj2", 540, 2, {"swing_at": 8, "guard": "high", "air": true, "kb": Vector2(1.0, 7.0), "spike": true,
			"cancel": ["bj", "cj", "spell"]}),
		"ad": melee("ad", 560, 2, {"swing_at": 3, "kb": Vector2(6.0, -4.0), "launch": true, "keep_vel": true,
			"vel": Vector2(5.0, 0), "cancel": ["c6", "c2", "spell"]}),
		"b5": shot("b5", 0.25),
		"b2": shot("b2", 0.25),
		"b2c": shot("b2c", 0.25, {"crouch": true}),
		"bj": shot("bj", 0.25, {"air": true, "grav": 0.4}),
		"c5": skill("c5", 1.0),
		"c6": skill("c6", 1.0, {"dmg": 640, "level": 2, "stun": 26, "bstun": 16, "kb": Vector2(6.0, -4.0), "launch": true,
			"keep_vel": true, "graze": true, "hits": 1, "spark": "elec", "spirit_dmg": 0.7, "push": 4.0,
			"prorate": 0.85, "limit": 25, "cancel": ["spell"]}),
		"c2": skill("c2", 1.0, {"dmg": 260, "level": 1, "stun": 22, "bstun": 14, "kb": Vector2(1.0, -7.5), "launch": true,
			"hits": 3, "every": 5, "inv": 9, "spark": "elec", "spirit_dmg": 0.35, "prorate": 0.9, "limit": 12,
			"keep_vel": true, "cancel": ["spell"]}),
		"cj": skill("cj", 1.0, {"dmg": 480, "level": 2, "stun": 20, "bstun": 14, "kb": Vector2(3.5, 4.0), "spike": true,
			"air": true, "guard": "high", "hits": 1, "spark": "elec", "spirit_dmg": 0.5, "keep_vel": true, "grav": 0.0}),
	}


func on_event(f: Fighter, ev: String) -> void:
	var hand := f.point("hand_f")
	match ev:
		"fire":
			_spark(f)
		"burst":
			var p := f.point("hand_b") if f.mv_id == "a5_4" else hand
			f.battle.fx.spark(p, "elec", 1, f.facing)
			Audio.play("spark_shot", -6.0, 0.8)
		"skill":
			match f.mv_id:
				"c5":
					_orb(f)
				"c6":
					f.vel.x = f.facing * 9.5
					Audio.play("electric_orb", -6.0, 1.4)
				"c2":
					f.grounded = false
					f.vel = Vector2(f.facing * 1.6, -8.4)
					Audio.play("uppercut", -2.0)
				"cj":
					f.vel = Vector2(f.facing * 6.5, 7.5)
					Audio.play("uppercut", -4.0, 1.2)


func move_tick(f: Fighter, id: String) -> void:
	match id:
		"c6":
			if f.sf >= 10 and f.sf < 24:
				if f.sf % 2 == 0:
					f.battle.fx.afterimage(f, Color(0.4, 0.9, 1.0, 0.6))
					f.battle.fx.arc(f.center() + Vector2(randf_range(-10, 10), randf_range(-20, 20)),
						f.center() + Vector2(-f.facing * randf_range(20, 40), randf_range(-20, 20)), VOLT)
			elif f.sf >= 24:
				f.vel.x *= 0.7
		"c2":
			if f.sf < 22 and f.sf % 2 == 0:
				f.battle.fx.afterimage(f, Color(0.4, 0.9, 1.0, 0.6))
				f.battle.fx.particle(f.point("hand_f"), Vector2(randf_range(-1, 1), randf_range(0, 2)), 18, VOLT, 2.0, "sq", true)
		"cj":
			if f.sf >= 11:
				f.grav_scale = 0.0
				if f.sf % 2 == 0:
					f.battle.fx.afterimage(f, Color(0.4, 0.9, 1.0, 0.6))
		"ad":
			if f.sf < 10 and f.sf % 3 == 0:
				f.battle.fx.afterimage(f)


func on_land(f: Fighter, id: String) -> void:
	if id == "cj":
		f.battle.fx.spark(f.pos + Vector2(f.facing * 12, -4), "elec", 2, f.facing)
		f.battle.fx.ring(f.pos, VOLT, 50.0, 16, 0.6)
		f.battle.add_trauma(0.3)
		f.battle.stage.debris(f.pos, 5)
		Audio.play("thunder_crack", -8.0, 1.4)


func on_move_hit(f: Fighter, id: String, victim: Fighter, blocked: bool) -> void:
	if id == "c6" and not blocked:
		f.vel.x *= 0.2


func _spark(f: Fighter) -> void:
	var hand := f.point("hand_f") + Vector2(f.facing * 4, 0)
	var ang := 0.0
	match f.mv_id:
		"b2":
			ang = -0.7
		"bj":
			ang = 0.62
		"b2c":
			ang = 0.0
			hand.y = maxf(hand.y, -14.0)
	var v := Vector2(cos(ang) * f.facing, sin(ang)) * 8.5
	bullet(f, "spark", hand, v, {"radius": 6.0, "color": VOLT, "dmg": 210, "stun": 15, "life": 34, "strength": 2,
		"spark": "elec", "kb": Vector2(2.0, 0), "guard": "low" if f.mv_id == "b2c" else "mid", "drag": 0.985})
	f.battle.fx.spark(hand, "elec", 0, f.facing)
	Audio.play("spark_shot", -5.0)


func _orb(f: Fighter) -> void:
	var at := f.point("hand_f") + Vector2(f.facing * 10, 0)
	var o := bullet(f, "eorb", at, Vector2(f.facing * 1.8, 0), {"radius": 13.0, "color": VOLT, "color2": Color(0.9, 1, 1),
		"dmg": 120, "stun": 16, "life": 90, "hits": 5, "hit_every": 9, "strength": 5, "spark": "elec",
		"prorate": 0.95, "limit": 5, "spirit_dmg": 0.15, "drag": 0.99})
	o.tick_cb = func(p):
		if p.age % 5 == 0:
			p.battle.fx.arc(p.pos, p.pos + Vector2.from_angle(randf() * TAU) * randf_range(16, 26), VOLT, 5)
	Audio.play("electric_orb", -3.0)


# ------------------------------------------------------------------ feitiços

func spell_start(f: Fighter, cid: String) -> void:
	f.spell_data = {"cid": cid}
	f.mv_hits = 0
	f.mv_lock = 0
	match cid:
		"rubi_s1":
			f.set_anim("c6")
			f.at = 8
			f.spell_data["rush"] = {"dmg": 220, "level": 2, "stun": 30, "bstun": 18, "kb": Vector2(1.0, -0.5),
				"hits": 1, "spark": "elec", "spirit_dmg": 0.8, "prorate": 0.95, "limit": 0, "push": 3.0}
			f.strike_inv = 24
			f.proj_inv = 30
		"rubi_s2":
			f.set_anim("dash_f")
			f.spell_data["rush"] = {"dmg": 200, "level": 1, "stun": 40, "bstun": 18, "kb": Vector2(0.5, 0),
				"hits": 1, "spark": "elec", "spirit_dmg": 0.8, "prorate": 0.97, "limit": 0, "push": 3.0}
			f.proj_inv = 24
		"rubi_s3":
			f.set_anim("cast_up")


func spell_tick(f: Fighter) -> bool:
	var cid: String = f.spell_data.get("cid", "")
	match cid:
		"rubi_s1":
			return _s1(f, f.spell_t)
		"rubi_s2":
			return _s2(f, f.spell_t)
		"rubi_s3":
			return _s3(f, f.spell_t)
	return true


func _lock_victim(f: Fighter, stun := 20) -> void:
	var v := f.opp
	v.hitstun = maxi(v.hitstun, stun)
	if v.state == "hit_air":
		v.vel = v.vel * 0.3
		v.vel.y = minf(v.vel.y, 0.0)
		v.grav_scale = 0.15


func _rush_contact(f: Fighter) -> int:
	## 0 = nada, 1 = acertou, 2 = defendeu
	if f.spell_data.get("whiffed", false) or f.opp.strike_inv > 0 or f.opp.state in ["knockdown", "wakeup"]:
		return 0
	var box := Rect2(f.pos.x + (0.0 if f.facing > 0 else -40.0), f.pos.y - 72.0, 40.0, 72.0)
	for hr in f.opp.hurtboxes():
		if box.intersects(hr):
			var blocked: bool = f.battle.resolve_hit(f, f.opp, f.spell_data["rush"], hr.get_center(), null)
			if blocked:
				f.spell_data["whiffed"] = true
				return 2
			return 1
	return 0


func _rush(f: Fighter, t: int, speed: float, ghost: Color) -> bool:
	## fase de investida; retorna true quando a carta deve terminar
	f.vel.x = f.facing * speed
	if t % 2 == 0:
		f.battle.fx.afterimage(f, ghost)
	if not f.spell_data.get("whiffed", false):
		var r := _rush_contact(f)
		if r == 1:
			f.spell_data["connected"] = true
			f.spell_data["t_hit"] = t
			f.vel.x = 0.0
			return false
		elif r == 2:
			f.vel.x = -f.facing * 3.0
	if t > 28 or f.spell_data.get("whiffed", false):
		f.vel.x *= 0.5
		return t > 42
	return false


func _s1(f: Fighter, t: int) -> bool:
	var con: bool = f.spell_data.get("connected", false)
	if not con:
		return _rush(f, t, 10.0, Color(0.4, 0.9, 1.0, 0.7))
	var th: int = f.spell_data["t_hit"]
	var k := t - th
	f.vel.x = 0.0
	_lock_victim(f, 30)
	if k < 30 and k % 6 == 0:
		f.mv_hits = 0
		f.mv_lock = 0
		var m: Dictionary = f.spell_data["rush"]
		f.battle.resolve_hit(f, f.opp, m, f.opp.center() + Vector2(randf_range(-8, 8), randf_range(-14, 8)), null)
		f.battle.fx.arc(f.point("hand_f"), f.opp.center(), VOLT)
		f.mv_hits = 99
	if k == 34:
		var x := f.opp.pos.x
		var b := bullet(f, "bolt", Vector2(x, 0), Vector2.ZERO, {"shape": "rect", "rect": Rect2(-22, -400, 44, 400),
			"color": VOLT, "color2": Color(1, 1, 1), "size": 1.6, "dmg": 700, "stun": 30, "life": 30, "active_from": 0,
			"level": 2, "kb": Vector2(2.0, -6.0), "launch": true, "grazeable": false, "strength": 99, "spark": "elec",
			"spirit_dmg": 1.5, "unblockable": true})
		b.knockdown = true
		Audio.play("thunder_crack", 0.0)
		f.battle.add_trauma(0.7)
		f.battle.aberr = 1.2
		Game.flash_screen(Color(0.8, 0.95, 1.0, 0.6), 0.3)
		f.battle.stage.lightning_flash()
	return k >= 60


func _s2(f: Fighter, t: int) -> bool:
	var con: bool = f.spell_data.get("connected", false)
	if not con:
		return _rush(f, t, 8.5, f.ghost_color)
	var k := t - int(f.spell_data["t_hit"])
	f.vel.x = 0.0
	_lock_victim(f, 26)
	if k == 1:
		f.set_anim("cast")
		Audio.play("super_flash", -4.0)
	if k > 0 and k < 56:
		# rajada: um golpe a cada 3 frames
		if k % 3 == 0:
			var m := {"dmg": 55, "level": 0, "stun": 26, "bstun": 10, "kb": Vector2(0.3, 0), "spark": "elec",
				"prorate": 0.985, "limit": 0, "hitstop": 2, "hit_sfx": "hit_light"}
			f.battle.resolve_hit(f, f.opp, m, f.opp.center() + Vector2(randf_range(-10, 6) * f.facing, randf_range(-20, 10)), null)
		f.opp.pos.x = lerpf(f.opp.pos.x, f.pos.x + f.facing * 30.0, 0.3)
	if k == 58:
		f.set_anim("a5_4")
		f.at = 10
		Audio.play("uppercut", 0.0)
	if k == 61:
		var m2 := {"dmg": 520, "level": 2, "stun": 40, "kb": Vector2(1.5, -10.0), "launch": true, "knockdown": true,
			"spark": "elec", "hitstop": 18}
		f.battle.resolve_hit(f, f.opp, m2, f.point("hand_b"), null)
		var b := bullet(f, "bolt", Vector2(f.opp.pos.x, 0), Vector2.ZERO, {"shape": "rect", "rect": Rect2(-20, -400, 40, 400),
			"color": VOLT, "color2": Color(1, 1, 1), "size": 1.4, "dmg": 300, "stun": 30, "life": 26, "level": 2,
			"kb": Vector2(1.0, -4.0), "grazeable": false, "strength": 99, "spark": "elec", "unblockable": true})
		b.knockdown = true
		Audio.play("thunder_crack", -2.0)
		f.battle.add_trauma(0.6)
		f.battle.stage.lightning_flash()
	return k >= 84


func _s3(f: Fighter, t: int) -> bool:
	if not f.grounded:
		f.vel = Vector2.ZERO
	var start_x := f.pos.x + f.facing * 60.0
	if t >= 20 and t < 20 + 6 * 12 and (t - 20) % 12 == 0:
		var i := (t - 20) / 12
		var x := start_x + f.facing * i * 72.0
		x = clampf(x, -Fighter.WALL - 20.0, Fighter.WALL + 20.0)
		_bolt(f, x, 1.1, 360)
	if t == 104:
		_bolt(f, f.opp.pos.x, 2.0, 900)
	return t >= 150


func _bolt(f: Fighter, x: float, size: float, dmg: float) -> void:
	var w := 24.0 * size
	var b := bullet(f, "bolt", Vector2(x, 0), Vector2.ZERO, {"shape": "rect", "rect": Rect2(-w * 0.5, -500, w, 500),
		"color": VOLT, "color2": Color(1, 1, 1), "size": size, "dmg": dmg, "stun": 28, "life": 46, "active_from": 22,
		"level": 2, "kb": Vector2(1.5, -6.0), "launch": true, "grazeable": false, "strength": 99, "spark": "elec",
		"spirit_dmg": 1.2, "hits": 1, "clashable": false})
	b.tick_cb = func(p):
		if p.age == p.active_from:
			Audio.play("thunder_crack", -3.0 if size < 1.5 else 2.0, 1.0 + randf_range(-0.1, 0.1))
			p.battle.add_trauma(0.35 * size)
			p.battle.fx.ring(Vector2(p.pos.x, -2), VOLT, 40.0 * size, 16, 0.6)
			p.battle.fx.spark(Vector2(p.pos.x, -10), "elec", 2, 0)
			p.battle.stage.debris(Vector2(p.pos.x, 0), int(4 * size))
			p.battle.stage.lightning_flash()
			if size >= 1.5:
				p.battle.aberr = 1.2
				Game.flash_screen(Color(0.8, 0.95, 1.0, 0.7), 0.35)
		elif p.age == 1:
			Audio.play("electric_orb", -14.0, 0.7)
