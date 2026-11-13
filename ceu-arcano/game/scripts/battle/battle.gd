extends Node2D
## Cena de batalha: loop fixo de 60 ticks, colisões, hitstop, câmera, rounds, cartas e feitiços.

const ROUND_TIME := 99
const CAM_REF := Vector2(0, -110)

var frame := 0
var fighters: Array[Fighter] = []
var projectiles: Array = []
var hitstop := 0
var superfreeze := 0
var freeze_owner: Fighter = null
var phase := "intro"
var phase_t := 0
var round_num := 1
var timer := ROUND_TIME * 60
var winner: Fighter = null
var spells := [null, null]        # carta ativa por jogador
var paused := false
var slowmo := 0.0
var training := false
var stats := {}   # dano por golpe (diagnóstico, impresso no fim da partida)

var world: Node2D
var stage: Node2D
var fx: Fx
var cam: Camera2D
var hud: Node
var cutin: Node
var screen: ColorRect
var proj_root: Node2D
var shadows: Node2D
var pause_menu: Control
var spell_bg: Node2D

# câmera
var cam_pos := CAM_REF
var cam_zoom := 1.0
var trauma := 0.0
var zoom_punch := 0.0
var cam_focus_t := 0.0
var cam_focus := Vector2.ZERO
var shock_t := 1.0
var shock_pos := Vector2.ZERO
var aberr := 0.0
var darken := 0.0
var darken_target := 0.0


func _ready() -> void:
	training = Game.mode == Game.Mode.TRAINING
	world = Node2D.new()
	add_child(world)
	stage = load("res://scripts/battle/stage.gd").new()
	stage.battle = self
	world.add_child(stage)
	spell_bg = load("res://scripts/battle/spell_bg.gd").new()
	spell_bg.battle = self
	spell_bg.z_index = 1
	world.add_child(spell_bg)
	shadows = _Shadows.new()
	shadows.battle = self
	shadows.z_index = 2
	world.add_child(shadows)
	proj_root = Node2D.new()
	proj_root.z_index = 20
	world.add_child(proj_root)
	for p in 2:
		var f := Fighter.new()
		var alt: bool = p == 1 and Game.p_chars[0] == Game.p_chars[1]
		f.setup(self, Game.p_chars[p], p, alt)
		f.z_index = 5
		world.add_child(f)
		fighters.append(f)
	fighters[0].opp = fighters[1]
	fighters[1].opp = fighters[0]
	for p in 2:
		if Game.p_cpu[p]:
			var ai = load("res://scripts/battle/ai.gd").new()
			ai.setup(fighters[p], self, Game.cpu_level if not training else -1)
			fighters[p].cpu = ai
	fx = Fx.new()
	fx.z_index = 25
	world.add_child(fx)
	stage.build_front()
	cam = Camera2D.new()
	cam.position = CAM_REF
	world.add_child(cam)
	cam.make_current()
	hud = load("res://scripts/battle/hud.gd").new()
	hud.battle = self
	add_child(hud)
	cutin = load("res://scripts/battle/cutin.gd").new()
	cutin.battle = self
	add_child(cutin)
	_build_screen_fx()
	_build_pause()
	start_round(true)
	Audio.music("battle")


class _Shadows extends Node2D:
	var battle
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		for f in battle.fighters:
			var h := clampf(-f.pos.y / 220.0, 0.0, 1.0)
			var w := 22.0 * (1.0 - h * 0.5)
			var c := Color(0.06, 0.03, 0.14, 0.45 * (1.0 - h * 0.7))
			draw_set_transform(Vector2(f.pos.x, 1.0), 0.0, Vector2(1.0, 0.28))
			draw_circle(Vector2.ZERO, w, c)
			draw_circle(Vector2.ZERO, w * 0.6, Color(c, c.a * 0.8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_screen_fx() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	screen = ColorRect.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/screen_fx.gdshader")
	screen.material = m
	layer.add_child(screen)


func _build_pause() -> void:
	pause_menu = load("res://scripts/ui/pause_menu.gd").new()
	pause_menu.battle = self
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	layer.add_child(pause_menu)
	pause_menu.visible = false


# ------------------------------------------------------------------ rounds

func start_round(first := false) -> void:
	for p in projectiles:
		if is_instance_valid(p):
			p.queue_free()
	projectiles.clear()
	spells = [null, null]
	spell_bg.clear()
	for i in 2:
		hud.spell_banner(i, "")
		fighters[i].spell_card = ""
	winner = null
	timer = ROUND_TIME * 60
	hitstop = 0
	superfreeze = 0
	Engine.time_scale = 1.0
	darken_target = 0.0
	fighters[0].reset_round(-110)
	fighters[1].reset_round(110)
	for f in fighters:
		f.enter("intro", "intro")
		if f.cpu:
			f.cpu.reset()
	if training:
		for f in fighters:
			f.card_gauge = 100.0
	phase = "intro"
	phase_t = 0 if first else 40
	cam_pos = Vector2(0, -90)
	cam_zoom = 1.25
	hud.round_start(round_num)
	stage.on_round(round_num)


func _physics_process(_delta: float) -> void:
	if paused:
		return
	frame += 1
	phase_t += 1
	var frozen := hitstop > 0 or superfreeze > 0
	for f in fighters:
		if f.cpu:
			f.cpu.think(frozen)
		elif training and f.pid == 1:
			f.inp.feed(Vector2i.ZERO, {}, frozen)
		else:
			f.inp.read_device(f.pid, frozen)
	_check_pause()
	_phase_logic()
	if superfreeze > 0:
		superfreeze -= 1
		if freeze_owner:
			freeze_owner._advance_anim()
			freeze_owner.sf += 1
		if superfreeze == 0 and freeze_owner:
			var f := freeze_owner
			freeze_owner = null
			f.start_spell()
		_decay_shake()
		return
	if hitstop > 0:
		hitstop -= 1
		_decay_shake()
		return
	for f in fighters:
		f.tick()
		if f.shake > 0:
			f.shake -= 1
	for i in range(projectiles.size() - 1, -1, -1):
		var p = projectiles[i]
		if not is_instance_valid(p) or p.dead:
			projectiles.remove_at(i)
			continue
		p.tick()
	if phase in ["fight", "ko"]:
		_melee_hits()
		_projectile_hits()
		_clashes()
	_push_apart()
	if training:
		_training_tick()


func _decay_shake() -> void:
	for f in fighters:
		if f.shake > 0:
			f.shake -= 1


func _check_pause() -> void:
	for p in 2:
		if Input.is_action_just_pressed("p%d_start" % (p + 1)) and phase != "end":
			set_paused(true)
			return


func set_paused(v: bool) -> void:
	paused = v
	get_tree().paused = v
	pause_menu.visible = v
	if v:
		pause_menu.open()
		Audio.duck(0.4)
		Audio.play("ui_back", -4.0)
	else:
		Audio.duck(1.0)


func _phase_logic() -> void:
	match phase:
		"intro":
			if phase_t == 80:
				hud.announce("ROUND %d" % round_num if round_num < 3 else "ROUND FINAL", Color("ffd66b"), 1.0, false,
					"Clima: %s" % ["Crepúsculo", "Chuva de Estrelas", "Aurora"][stage.weather])
				Audio.play("round_announce")
			if phase_t == 135:
				hud.announce("DUELO!", Color("ffffff"), 0.7, true)
				Audio.play("fight_start")
				add_trauma(0.35)
				for f in fighters:
					f.enter("idle")
			if phase_t >= 140:
				phase = "fight"
				phase_t = 0
		"fight":
			if superfreeze == 0 and hitstop == 0 and not training:
				timer -= 1
				if timer % 60 == 0 and timer <= 600 and timer > 0:
					Audio.play("timer_tick", -6.0)
			if timer <= 0:
				_time_up()
		"ko":
			if phase_t == 1:
				Engine.time_scale = 0.28
			if phase_t == 30:
				_tween_time_scale(1.0, 0.6)
			var loser: Fighter = winner.opp if winner else null
			if phase_t > 70 and loser and (loser.grounded or phase_t > 260) and phase_t > 120:
				if winner.state != "win" and winner.grounded and winner.state in ["idle", "walk_f", "walk_b", "crouch", "land"]:
					winner.enter("win", "win")
					winner.face_opponent()
			if phase_t == 220:
				winner.wins += 1
				hud.update_wins()
				if winner.wins >= Game.rounds_to_win:
					_match_over()
				else:
					hud.announce("%s vence o round" % Game.CHAR_INFO[winner.kit.id]["name"], Color("ffd66b"), 1.0)
			if phase_t == 330 and winner.wins < Game.rounds_to_win:
				round_num += 1
				start_round()
		"timeup":
			if phase_t == 200:
				if winner:
					winner.wins += 1
					hud.update_wins()
				if winner and winner.wins >= Game.rounds_to_win:
					_match_over()
				else:
					round_num += 1
					start_round()


func _tween_time_scale(to: float, dur: float) -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_method(func(v): Engine.time_scale = v, Engine.time_scale, to, dur)


func _time_up() -> void:
	phase = "timeup"
	phase_t = 0
	var a := fighters[0].hp / Fighter.HP_MAX
	var b := fighters[1].hp / Fighter.HP_MAX
	winner = fighters[0] if a > b else (fighters[1] if b > a else null)
	hud.announce("TEMPO!", Color("ff9a6a"), 1.4, true)
	Audio.play("ko", -4.0)
	for f in fighters:
		if f == winner:
			f.enter("win", "win")
		elif f.grounded:
			f.enter("idle")


func _match_over() -> void:
	phase = "end"
	print("FIM_DA_PARTIDA vencedora=%s placar=%d-%d rounds=%d" % [winner.kit.id, fighters[0].wins, fighters[1].wins, round_num])
	if OS.get_cmdline_user_args().size() > 0:
		var keys := stats.keys()
		keys.sort_custom(func(a, b): return stats[a] > stats[b])
		for k in keys:
			print("  DANO %s %d" % [k, int(stats[k])])
	hud.announce("VITÓRIA DE %s" % Game.CHAR_INFO[winner.kit.id]["name"].to_upper(), Game.CHAR_INFO[winner.kit.id]["color"], 2.0)
	Audio.music("victory", 0.3)
	await get_tree().create_timer(2.2).timeout
	var res = load("res://scripts/ui/results.gd").new()
	res.battle = self
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	layer.add_child(res)


func rematch() -> void:
	Game.goto("res://scenes/battle.tscn")


# ------------------------------------------------------------------ colisões

func _melee_hits() -> void:
	for f in fighters:
		if f.state != "move" and f.state != "spell":
			continue
		if f.mv.is_empty() and f.state == "move":
			continue
		var boxes := f.hitboxes()
		if boxes.is_empty():
			continue
		var m: Dictionary = f.mv if f.state == "move" else f.spell_data.get("move", {})
		if m.is_empty():
			continue
		var max_hits: int = int(m.get("hits", 1))
		if f.mv_hits >= max_hits or f.mv_lock > 0:
			continue
		var o := f.opp
		if o.strike_inv > 0 or o.state in ["knockdown", "wakeup"] or (o.ko and o.grounded):
			continue
		var contact = null
		for hb in boxes:
			for hr in o.hurtboxes():
				if hb.intersects(hr):
					var inter: Rect2 = hb.intersection(hr)
					contact = inter.get_center()
					break
			if contact != null:
				break
		if contact == null:
			continue
		f.mv_hits += 1
		f.mv_lock = int(m.get("every", 99))
		f.mv_contact = true
		var blocked := resolve_hit(f, o, m, contact, null)
		if not blocked:
			f.mv_hit = true
		f.kit.on_move_hit(f, f.mv_id if f.state == "move" else "spell", o, blocked)


func _projectile_hits() -> void:
	for p in projectiles:
		if not is_instance_valid(p) or not p.active() or p.hit_cd > 0 or p.hits <= 0:
			continue
		var o: Fighter = p.owner_f.opp
		if o.ko and o.grounded:
			continue
		if o.state in ["knockdown", "wakeup"]:
			continue
		for hr in o.hurtboxes():
			if not p.overlaps_rect(hr):
				continue
			if o.proj_inv > 0 or (p.grazeable and o.grazing()):
				if not p.grazed:
					p.grazed = true
					_graze(o, p)
				break
			var blocked := resolve_hit(p.owner_f, o, p.as_move(), p.pos, p)
			p.hits -= 1
			p.hit_cd = p.hit_every
			if p.hit_cb.is_valid():
				p.hit_cb.call(p, o, blocked)
			if p.hits <= 0:
				p.kill(true)
			break


func _clashes() -> void:
	var n := projectiles.size()
	for i in n:
		var a = projectiles[i]
		if not is_instance_valid(a) or not a.active() or not a.clashable:
			continue
		for j in range(i + 1, n):
			var b = projectiles[j]
			if not is_instance_valid(b) or not b.active() or not b.clashable or b.owner_f == a.owner_f:
				continue
			if not a.overlaps_proj(b):
				continue
			var sa: int = a.strength
			var sb: int = b.strength
			a.strength -= sb
			b.strength -= sa
			if a.strength <= 0:
				a.kill(true)
			if b.strength <= 0:
				b.kill(true)
			Audio.play("bullet_cancel", -10.0)
			if not a.active():
				break


func _graze(f: Fighter, p) -> void:
	f.gain_card(2.2)
	f.grazed_this += 1
	fx.spark(p.pos, "graze", 0, 0)
	Audio.play("graze", -12.0, 1.0, 0.15)
	hud.on_graze(f.pid)


func resolve_hit(att: Fighter, def: Fighter, m: Dictionary, point: Vector2, proj) -> bool:
	var from_dir := 1 if def.pos.x >= att.pos.x else -1
	if proj != null and absf(proj.vel.x) > 0.5:
		from_dir = 1 if proj.vel.x > 0 else -1
	var level: int = int(m.get("level", 0))
	var is_bullet := proj != null
	var guard: String = m.get("guard", "mid")
	var blocked := false
	if def.can_block() and not m.get("unblockable", false):
		var crouching = def.inp.down() or (def.cpu != null and def.cpu.wants_low)
		if not def.grounded:
			blocked = true
		elif guard == "low":
			blocked = crouching
		elif guard == "high":
			blocked = not crouching
		else:
			blocked = true
		if def.cpu != null and def.cpu.wants_block:
			def.inp.dir.y = 1 if (guard == "low") else (0 if guard == "high" else def.inp.dir.y)
	if blocked:
		var chip: float = float(m.get("spirit_dmg", 0.3)) * (1.6 if not def.grounded else 1.0)
		def.take_block(att, m, from_dir, chip)
		if not is_bullet:
			def.face_opponent()
		if is_bullet:
			def.freeze = 3
		else:
			hitstop = 6 + level * 2
		fx.spark(point, "guard", level, -from_dir)
		Audio.play("block", -3.0)
		att.gain_card(1.5 + level)
		def.gain_card(1.0)
		if not is_bullet and absf(def.pos.x) >= Fighter.WALL - 1.0:
			att.vel.x = -from_dir * float(m.get("push", 3.0)) * 1.2
		return true
	var counter = def.state == "move" and def.mv.get("type", "") != "bullet" and not is_bullet
	var dmg: float = maxf(1.0, float(m.get("dmg", 100.0)) * def.prorate * (1.15 if counter else 1.0))
	if training and def.pid == 1:
		pass
	def.take_hit(att, m, dmg, counter, from_dir)
	var sk: String = att.kit.id + ":" + (str(proj.kind) if proj != null else (att.mv_id if att.state == "move" else "spell"))
	stats[sk] = stats.get(sk, 0.0) + dmg
	var hs: int = int(m.get("hitstop", 0))
	if hs <= 0:
		hs = [7, 10, 14][clampi(level, 0, 2)] if not is_bullet else [3, 5, 8][clampi(level, 0, 2)]
	if counter:
		hs += 5
	if is_bullet and level < 2:
		def.freeze = hs
		def.shake = hs
	else:
		hitstop = maxi(hitstop, hs)
		def.shake = hs
	def.flash = 1.0
	def.flash_color = Color(1.0, 0.55, 0.35) if counter else Color.WHITE
	var sp: String = m.get("spark", "hit")
	fx.spark(point, "counter" if counter and sp == "hit" else sp, level, from_dir,
		att.kit.ghost_color.lerp(Color.WHITE, 0.4) if sp == "magic" else Color(1, 0.92, 0.6))
	add_trauma([0.12, 0.25, 0.45][clampi(level, 0, 2)] * (0.5 if is_bullet else 1.0) + (0.15 if counter else 0.0))
	if level >= 2 and not is_bullet:
		zoom_punch = 0.06
		_shockwave(point)
	var snd: String = m.get("hit_sfx", "")
	if snd == "":
		snd = ["hit_light", "hit_medium", "hit_heavy"][clampi(level, 0, 2)]
	Audio.play(snd, -2.0 if not is_bullet else -6.0)
	if counter:
		Audio.play("hit_counter", -4.0)
		fx.text(def.center() + Vector2(0, -58), "CONTRA!", Color("ff8a5a"), 1.0, 12)
	att.gain_card(dmg / 32.0 + 1.0)
	def.gain_card(dmg / 48.0)
	hud.on_hit(att.pid, def)
	if def.ko and phase == "fight":
		_ko(att, def)
	return false


func _push_apart() -> void:
	var a := fighters[0]
	var b := fighters[1]
	if a.state in ["knockdown"] or b.state in ["knockdown"]:
		return
	var ra := a.body_rect()
	var rb := b.body_rect()
	if not ra.intersects(rb):
		return
	var overlap := (Fighter.PUSH_W * 2.0) - absf(a.pos.x - b.pos.x)
	if overlap <= 0.0:
		return
	var dir := 1.0 if a.pos.x < b.pos.x else -1.0
	if absf(a.pos.x - b.pos.x) < 0.01:
		dir = float(a.facing)
	var pa := overlap * 0.5
	var pb := overlap * 0.5
	if absf(a.pos.x) >= Fighter.WALL - 0.5:
		pa = 0.0
		pb = overlap
	elif absf(b.pos.x) >= Fighter.WALL - 0.5:
		pb = 0.0
		pa = overlap
	a.pos.x = clampf(a.pos.x - dir * pa, -Fighter.WALL, Fighter.WALL)
	b.pos.x = clampf(b.pos.x + dir * pb, -Fighter.WALL, Fighter.WALL)


func _training_tick() -> void:
	var d := fighters[1]
	if d.state in ["idle", "crouch", "walk_f", "walk_b"] and frame - d.last_hit_frame > 90:
		d.hp = minf(Fighter.HP_MAX, d.hp + 80.0)
		d.hp_shown = d.hp
	for f in fighters:
		if frame - f.last_hit_frame > 60:
			f.spirit = minf(Fighter.SPIRIT_MAX, f.spirit + 0.05)
		if f.hand.size() < 4:
			f.card_gauge = minf(199.0, f.card_gauge + 0.8)


# ------------------------------------------------------------------ eventos

func _ko(att: Fighter, def: Fighter) -> void:
	phase = "ko"
	phase_t = 0
	winner = att
	hitstop = 24
	Audio.play("ko", 0.0)
	Audio.play("slowmo", -4.0)
	Game.flash_screen(Color(1, 1, 1, 0.85), 0.5)
	add_trauma(0.9)
	zoom_punch = 0.18
	cam_focus = def.center()
	cam_focus_t = 1.6
	_shockwave(def.center())
	fx.ring(def.center(), Color(1, 1, 1), 120.0, 30, 1.0)
	fx.burst(def.center(), Color("ffd66b"), 40, 6.0)
	hud.announce("K.O.", Color("ff5a4a"), 1.6, true)
	for p in projectiles:
		if is_instance_valid(p) and p.owner_f == att:
			pass
		elif is_instance_valid(p):
			p.kill(true)


func on_card_drawn(f: Fighter, cid) -> void:
	hud.card_drawn(f.pid, cid)
	Audio.play("card_gain", -6.0)


func on_card_used(f: Fighter, cid: String, used: Array) -> void:
	hud.card_used(f.pid, cid, used)


func declare_spell(f: Fighter, cid: String) -> void:
	superfreeze = 54
	freeze_owner = f
	spells[f.pid] = cid
	cutin.play(f, cid)
	darken_target = 0.65
	zoom_punch = 0.1
	cam_focus = f.center()
	cam_focus_t = 0.75
	aberr = 1.0
	Audio.play("spell_declare", 0.0)
	Audio.play("super_flash", -3.0)
	fx.ring(f.center(), Cards.get_card(cid)["color"], 90.0, 26, 0.8)
	fx.flash(f.center(), Cards.get_card(cid)["color"], 40.0, 16)
	spell_bg.start(f, cid)
	hud.spell_banner(f.pid, cid)


func spell_ended(f: Fighter) -> void:
	spells[f.pid] = null
	spell_bg.stop(f)
	hud.spell_banner(f.pid, "")
	if spells[0] == null and spells[1] == null:
		darken_target = 0.0


func on_crush(f: Fighter) -> void:
	hitstop = maxi(hitstop, 16)
	fx.text(f.center() + Vector2(0, -60), "QUEBROU!", Color("ff6a8a"), 1.2, 14)
	fx.burst(f.center(), Color(0.6, 0.85, 1.0), 30, 5.0)
	fx.ring(f.center(), Color(0.7, 0.9, 1.0), 60.0, 20)
	Audio.play("guard_crush", 0.0)
	add_trauma(0.5)
	_shockwave(f.center())


func on_wallbounce(f: Fighter) -> void:
	hitstop = maxi(hitstop, 8)
	add_trauma(0.4)
	var wp := Vector2(signf(f.pos.x) * (Fighter.WALL + 8.0), f.pos.y - 40.0)
	fx.spark(wp, "hit", 2, -int(signf(f.pos.x)))
	for i in 10:
		fx.particle(wp, Vector2(-signf(f.pos.x) * randf_range(1, 4), randf_range(-4, 1)), 30,
			Color(0.6, 0.55, 0.7), 2.5, "sq", false, 0.2, 0.96, {"floor": true})
	Audio.play("hit_heavy", -4.0, 0.8)


func on_groundbounce(f: Fighter) -> void:
	add_trauma(0.3)
	fx.dust(f.pos, 2.0, f.facing)
	fx.ring(f.pos + Vector2(0, -2), Color(0.8, 0.75, 0.95, 0.8), 36.0, 14, 0.4)
	Audio.play("land", 0.0, 0.7)
	stage.debris(f.pos, 6)


func spawn_projectile(owner: Fighter, kind: String, at: Vector2, v: Vector2, extra := {}) -> Projectile:
	var p := Projectile.new()
	p.battle = self
	p.owner_f = owner
	p.kind = kind
	p.pos = at
	p.vel = v
	p.face = owner.facing
	for k in extra:
		p.set(k, extra[k])
	proj_root.add_child(p)
	projectiles.append(p)
	return p


func add_trauma(t: float) -> void:
	trauma = clampf(trauma + t, 0.0, 1.0)


func _shockwave(p: Vector2) -> void:
	shock_t = 0.0
	shock_pos = p


# ------------------------------------------------------------------ câmera e tela

func _process(delta: float) -> void:
	var a := fighters[0]
	var b := fighters[1]
	var mid := (a.center() + b.center()) * 0.5
	var dx := absf(a.pos.x - b.pos.x)
	var dy := absf(a.pos.y - b.pos.y)
	var z := clampf(minf(640.0 * 0.86 / (dx + 150.0), 360.0 * 0.66 / (dy + 110.0)), 0.74, 1.32)
	if phase == "intro" and phase_t < 135:
		z = 1.3
	var vw := 640.0 / z
	var vh := 360.0 / z
	var top := minf(a.pos.y, b.pos.y) - 100.0
	var cy := minf(-0.34 * vh, top + vh * 0.5)
	cy = maxf(cy, -640.0 + vh * 0.5)
	var target := Vector2(mid.x, cy)
	if cam_focus_t > 0.0:
		cam_focus_t -= delta / maxf(Engine.time_scale, 0.05) * Engine.time_scale
		target = target.lerp(cam_focus + Vector2(0, -10), 0.55)
		z = maxf(z, 1.15)
	var lim := 560.0 - vw * 0.5
	target.x = clampf(target.x, -lim, lim)
	var k := 1.0 - pow(0.0008, delta)
	cam_pos = cam_pos.lerp(target, k)
	cam_zoom = lerpf(cam_zoom, z, 1.0 - pow(0.003, delta))
	zoom_punch = lerpf(zoom_punch, 0.0, 1.0 - pow(0.002, delta))
	trauma = maxf(0.0, trauma - delta * 1.6)
	var sh := trauma * trauma
	var t := Time.get_ticks_msec() / 1000.0
	var off := Vector2(sin(t * 61.0) + sin(t * 23.0) * 0.6, cos(t * 57.0) + sin(t * 31.0) * 0.6) * sh * 9.0
	cam.position = cam_pos + off
	cam.rotation = sin(t * 41.0) * sh * 0.025
	cam.zoom = Vector2.ONE * (cam_zoom + zoom_punch)
	stage.update_view(cam.position, cam.zoom.x)
	# efeitos de tela
	darken = lerpf(darken, darken_target, 1.0 - pow(0.02, delta))
	stage.modulate = Color(1, 1, 1).lerp(Color(0.32, 0.3, 0.45), darken)
	aberr = maxf(0.0, aberr - delta * 1.8)
	shock_t = minf(1.0, shock_t + delta * 1.6)
	var m := screen.material as ShaderMaterial
	var sp := get_viewport().get_canvas_transform() * shock_pos
	var vs := get_viewport().get_visible_rect().size
	m.set_shader_parameter("shock_center", sp / vs)
	m.set_shader_parameter("shock_t", shock_t)
	m.set_shader_parameter("aberration", aberr * 0.006 + sh * 0.004)
	m.set_shader_parameter("ko_desat", 1.0 - Engine.time_scale if phase == "ko" else 0.0)
