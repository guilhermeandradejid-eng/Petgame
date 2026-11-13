extends Kit
## Lumia: zoneadora. Vagalumes, lanterna flutuante, cometa, mariposas e três cartas de feitiço.

const GOLD := Color(1.0, 0.82, 0.35)
const FIRE := Color(1.0, 0.9, 0.45)
const TEAL := Color(0.45, 0.95, 0.8)
const MOTH := Color(0.85, 0.55, 1.0)


func _init() -> void:
	id = "lumia"
	walk_f = 2.1
	walk_b = 1.8
	jump_v = -9.6
	jump_x = 3.0
	dash_speed = 6.2
	dash_min = 14
	dash_max = 30
	fly_speed = 5.8
	ghost_color = Color(0.4, 0.9, 0.8, 0.5)
	deck = ["lumia_s1", "lumia_s1", "lumia_s1", "lumia_s2", "lumia_s2", "lumia_s3", "lumia_s3",
			"elixir", "elixir", "vento", "vento", "lumia_s2"]
	moves = {
		"a5_1": melee("a5_1", 300, 0, {"swing_at": 3, "cancel": ["a5_2", "a2", "a6", "b5", "b2", "b2c", "c5", "c6", "c2", "spell"], "spark": "magic"}),
		"a5_2": melee("a5_2", 340, 1, {"swing_at": 4, "kb": Vector2(2.4, 0), "cancel": ["a5_3", "a6", "b5", "b2", "c5", "c6", "c2", "spell"], "spark": "magic"}),
		"a5_3": melee("a5_3", 400, 1, {"swing_at": 4, "kb": Vector2(3.0, 0), "cancel": ["a5_4", "b5", "c5", "c6", "c2", "spell"], "spark": "magic"}),
		"a5_4": melee("a5_4", 720, 2, {"swing_at": 11, "kb": Vector2(7.5, -5.5), "launch": true, "knockdown": true,
			"wallbounce": true, "cancel": ["c5", "c6", "c2", "spell"], "limit": 30}),
		"a2": melee("a2", 360, 1, {"swing_at": 4, "guard": "low", "crouch": true, "kb": Vector2(2.8, 0),
			"cancel": ["a6", "b5", "b2c", "c5", "c6", "c2", "spell"], "spark": "magic"}),
		"a6": melee("a6", 780, 2, {"swing_at": 12, "kb": Vector2(5.5, -6.5), "launch": true,
			"cancel": ["c5", "c6", "c2", "spell"]}),
		"aj": melee("aj", 420, 1, {"swing_at": 4, "guard": "high", "air": true, "kb": Vector2(3.0, -2.0),
			"cancel": ["aj2", "bj", "cj", "spell"], "spark": "magic"}),
		"aj2": melee("aj2", 520, 2, {"swing_at": 5, "guard": "high", "air": true, "kb": Vector2(2.0, 6.5),
			"spike": true, "cancel": ["bj", "cj", "spell"]}),
		"ad": melee("ad", 520, 1, {"swing_at": 4, "kb": Vector2(4.5, -3.0), "keep_vel": true, "vel": Vector2(4.0, 0),
			"cancel": ["c5", "c6", "c2", "spell"], "spark": "magic"}),
		"b5": shot("b5", 0.25),
		"b2": shot("b2", 0.25),
		"b2c": shot("b2c", 0.3, {"crouch": true}),
		"bj": shot("bj", 0.25, {"air": true, "grav": 0.35}),
		"c5": skill("c5", 1.0),
		"c6": skill("c6", 1.0),
		"c2": skill("c2", 1.0),
		"cj": skill("cj", 1.0, {"air": true, "grav": 0.3}),
	}


func next_chain(cur: String) -> String:
	return super.next_chain(cur)


func on_event(f: Fighter, ev: String) -> void:
	var tip := f.point("staff_tip") + Vector2(0, 8)
	match ev:
		"fire":
			_fireflies(f)
		"burst":
			f.battle.fx.burst(tip, FIRE, 22, 4.0)
			f.battle.fx.ring(tip, GOLD, 34.0, 14, 0.6)
			Audio.play("explosion", -8.0, 1.3)
		"skill":
			match f.mv_id:
				"c5":
					_lantern(f)
				"c6", "cj":
					_comet(f, f.mv_id == "cj")
				"c2":
					_moths(f)


func _fireflies(f: Fighter) -> void:
	var tip := f.point("staff_tip") + Vector2(0, 8)
	var base := 0.0
	match f.mv_id:
		"b2":
			base = -0.62
		"bj":
			base = 0.6
		"b2c":
			base = 0.0
	Audio.play("shot_firefly", -6.0)
	f.battle.fx.flash(tip, FIRE, 10.0, 6)
	if f.mv_id == "b2c":
		var v := Vector2(f.facing * 4.2, 0)
		bullet(f, "orb", tip + Vector2(0, 8), v, {"radius": 6.0, "color": GOLD, "dmg": 260, "stun": 16,
			"life": 140, "strength": 3, "trail_len": 7, "level": 1, "kb": Vector2(3, 0), "guard": "low", "accel": Vector2(f.facing * 0.04, 0)})
		return
	for i in 3:
		var ang := base + (i - 1) * 0.16
		var v2 := Vector2(cos(ang) * f.facing, sin(ang)) * (5.2 + i * 0.25)
		bullet(f, "firefly", tip, v2, {"radius": 3.6, "color": FIRE, "dmg": 140, "stun": 12, "life": 110,
			"trail_len": 5, "kb": Vector2(1.5, 0), "drag": 0.995, "spark": "magic"})


func _lantern(f: Fighter) -> void:
	for p in f.battle.projectiles:
		if is_instance_valid(p) and p.owner_f == f and p.kind == "lantern" and not p.dead:
			p.kill(true)
	var at := f.point("staff_tip")
	var goal := Vector2(f.pos.x + f.facing * 70.0, minf(f.pos.y - 90.0, -80.0))
	var l := bullet(f, "lantern", at, Vector2.ZERO, {"radius": 7.0, "life": 260, "hits": 1, "dmg": 200,
		"strength": 2, "grazeable": false, "color": GOLD, "data": {"goal": goal}})
	l.tick_cb = func(p):
		var g: Vector2 = p.data["goal"]
		p.pos = p.pos.lerp(g, 0.08)
		if p.age > 30 and p.age % 36 == 0 and p.age < 240:
			var d: Vector2 = aim(f, p.pos)
			bullet(f, "orb", p.pos, d * 3.0, {"radius": 5.0, "color": GOLD, "dmg": 160, "stun": 14, "life": 160,
				"trail_len": 6, "homing": 0.012, "homing_delay": 10, "homing_until": 60, "strength": 1})
			Audio.play("shot_star", -10.0)
			p.battle.fx.ring(p.pos, GOLD, 16.0, 10, 0.2)
	Audio.play("lantern_place", -2.0)


func _comet(f: Fighter, air: bool) -> void:
	var tip := f.point("staff_tip") + Vector2(0, 6)
	var v := Vector2(f.facing * 8.0, 3.2 if air else 0.0)
	var c := bullet(f, "comet", tip, v, {"radius": 7.5, "color": Color(0.6, 0.95, 1.0), "color2": Color(1, 1, 1),
		"dmg": 600, "stun": 24, "life": 120, "trail_len": 14, "strength": 4, "level": 2, "kb": Vector2(5, -4),
		"launch": true, "spark": "magic"})
	c.tick_cb = func(p):
		if p.age % 2 == 0:
			p.battle.fx.particle(p.pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)), -p.vel * 0.15 + Vector2(0, randf_range(-0.5, 0.5)),
				20, Color(0.7, 0.95, 1.0), 2.0, "sq", true, 0.0, 0.94)
	Audio.play("comet", -3.0)
	f.battle.fx.flash(tip, Color(0.6, 0.95, 1.0), 20.0, 8)


func _moths(f: Fighter) -> void:
	var at := f.point("staff_tip")
	for i in 4:
		var ang := -1.2 + i * 0.22
		var v := Vector2(cos(ang) * f.facing, sin(ang)) * (3.4 + i * 0.4)
		bullet(f, "moth", at, v, {"radius": 6.0, "color": MOTH, "color2": Color(1, 0.85, 1), "dmg": 190, "stun": 16,
			"life": 120, "homing": 0.03, "homing_delay": 18, "homing_until": 70, "strength": 1, "kb": Vector2(2, -4),
			"launch": true, "accel": Vector2(0, -0.02), "spark": "magic"})
	Audio.play("moth", -3.0)


# ------------------------------------------------------------------ feitiços

func spell_start(f: Fighter, cid: String) -> void:
	f.spell_data = {"cid": cid}
	f.mv_hits = 0
	f.mv_lock = 0
	match cid:
		"lumia_s1":
			f.set_anim("cast")
		"lumia_s2":
			f.set_anim("cast_up")
			f.spell_data["center"] = f.opp.center()
			f.spell_data["stars"] = []
		"lumia_s3":
			f.set_anim("cast_up")
	if not f.grounded:
		f.vel = Vector2.ZERO
		f.grav_scale = 0.0


func spell_tick(f: Fighter) -> bool:
	var t := f.spell_t
	var cid: String = f.spell_data.get("cid", "")
	f.vel.x *= 0.8
	if not f.grounded:
		f.vel.y = 0.0
		f.grav_scale = 0.0
	match cid:
		"lumia_s1":
			return _s1(f, t)
		"lumia_s2":
			return _s2(f, t)
		"lumia_s3":
			return _s3(f, t)
	return true


func _s1(f: Fighter, t: int) -> bool:
	# espiral dupla de vagalumes que depois persegue o alvo
	if t < 110 and t % 3 == 0:
		var tip := f.point("staff_tip") + Vector2(0, 8)
		for arm in 2:
			var ang := t * 0.21 + arm * PI
			var v := Vector2.from_angle(ang) * 2.6 + Vector2(f.facing * 1.2, 0)
			bullet(f, "firefly", tip, v, {"radius": 3.4, "color": FIRE if arm == 0 else TEAL, "dmg": 75, "stun": 14,
				"life": 170, "trail_len": 6, "homing": 0.05, "homing_delay": 26, "homing_until": 90, "max_speed": 5.0,
				"accel": v.normalized() * 0.03, "prorate": 0.97, "limit": 2, "spark": "magic", "level": 0})
		if t % 9 == 0:
			Audio.play("shot_firefly", -8.0, 1.0 + (t % 27) * 0.01)
	return t >= 140


func _s2(f: Fighter, t: int) -> bool:
	var c: Vector2 = f.spell_data["center"]
	var stars: Array = f.spell_data["stars"]
	if t < 42 and t % 6 == 0:
		var i := t / 6
		var ang := -PI / 2 + i * TAU / 7.0
		var p := c + Vector2(cos(ang) * 92.0, sin(ang) * 70.0)
		p.y = minf(p.y, -10.0)
		var s := bullet(f, "star", p, Vector2.ZERO, {"radius": 6.0, "color": Color(1, 0.9, 0.5), "dmg": 90,
			"life": 130, "hits": 2, "hit_every": 12, "strength": 3, "grazeable": true, "active_from": 6, "size": 1.0})
		stars.append(s)
		Audio.play("shot_star", -4.0, 1.0 + i * 0.06)
		f.battle.fx.ring(p, Color(1, 0.9, 0.5), 20.0, 12, 0.3)
	# feixes ligando as estrelas, em sequência
	if t >= 48 and t < 48 + 7 * 7 and (t - 48) % 7 == 0:
		var k := (t - 48) / 7
		if k < stars.size():
			var a = stars[k]
			var b = stars[(k + 1) % stars.size()]
			if is_instance_valid(a) and is_instance_valid(b):
				var l := bullet(f, "laser", a.pos, Vector2.ZERO, {"shape": "segment", "seg_b": b.pos, "thick": 4.0,
					"color": Color(0.55, 0.85, 1.0), "dmg": 150, "stun": 18, "life": 40, "hits": 2, "hit_every": 10,
					"grazeable": true, "clashable": false, "active_from": 6, "level": 1, "spark": "magic",
					"spirit_dmg": 0.2})
				l.strength = 99
				Audio.play("beam", -14.0, 1.6)
	if t == 110:
		for s in stars:
			if is_instance_valid(s) and not s.dead:
				for j in 6:
					var v := Vector2.from_angle(j * TAU / 6.0 + t) * 3.2
					bullet(f, "firefly", s.pos, v, {"radius": 3.0, "color": Color(1, 0.95, 0.6), "dmg": 60,
						"life": 80, "trail_len": 4, "spark": "magic"})
				f.battle.fx.flash(s.pos, Color(1, 0.9, 0.5), 18.0, 10)
				s.kill(false)
		Audio.play("explosion", -2.0, 1.2)
		f.battle.add_trauma(0.3)
	return t >= 130


func _s3(f: Fighter, t: int) -> bool:
	if t == 26:
		var start := f.pos + Vector2(f.facing * 20.0, 0)
		var w := 700.0
		var rect := Rect2(0 if f.facing > 0 else -w, -170, w, 172)
		var beam := bullet(f, "beam", start, Vector2.ZERO, {"shape": "rect", "rect": rect, "dmg": 120, "stun": 20,
			"life": 110, "hits": 18, "hit_every": 6, "grazeable": false, "strength": 99, "level": 1, "kb": Vector2(1.2, -1.0),
			"prorate": 0.97, "limit": 3, "spirit_dmg": 0.18, "spark": "magic", "hitstop": 3})
		var vis := ColorRect.new()
		vis.position = rect.position
		vis.size = rect.size
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/aurora.gdshader")
		m.set_shader_parameter("dir", float(f.facing))
		vis.material = m
		vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		beam.add_child(vis)
		beam.tick_cb = func(p):
			var k := 1.0
			if p.age < 12:
				k = p.age / 12.0
			elif p.life - p.age < 20:
				k = (p.life - p.age) / 20.0
			(vis.material as ShaderMaterial).set_shader_parameter("intensity", k)
			if p.age % 3 == 0:
				p.battle.fx.particle(p.pos + Vector2(randf() * 700.0 * f.facing, randf_range(-160, 0)),
					Vector2(0, randf_range(-1.5, -0.4)), 40, Color(0.5, 1.0, 0.8), 2.0, "sq", true, 0.0, 0.98)
		Audio.play("beam", 0.0)
		f.battle.add_trauma(0.5)
		f.battle.aberr = 1.0
	if t > 26 and t < 130 and t % 10 == 0:
		f.battle.add_trauma(0.12)
	return t >= 140
