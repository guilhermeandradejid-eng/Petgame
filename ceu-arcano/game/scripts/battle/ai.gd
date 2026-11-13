extends RefCounted
## CPU: lê o estado da luta e gera entradas como um jogador (com tempo de reação e erros).

var f: Fighter
var battle
var level := 1                 # -1 boneco de treino, 0 fácil, 1 normal, 2 difícil
var wants_block := false
var wants_low := false
var plan: Array = []
var step_left := 0
var cur_dir := Vector2i.ZERO
var cur_btn := {}
var idle_t := 0
var block_t := 0
var think_cd := 0
var rng := RandomNumberGenerator.new()
var zoner := false

const BLOCK_CHANCE := [0.25, 0.6, 0.88]
const REACT := [24, 14, 8]
const AGGRO := [0.35, 0.6, 0.85]


func setup(fighter: Fighter, b, lvl: int) -> void:
	f = fighter
	battle = b
	level = lvl
	zoner = f.kit.id == "lumia"
	rng.randomize()


func reset() -> void:
	plan.clear()
	step_left = 0
	wants_block = false
	wants_low = false
	think_cd = 30


func think(frozen: bool) -> void:
	if level < 0:
		f.inp.feed(Vector2i.ZERO, {}, frozen)
		return
	if frozen or battle.phase != "fight":
		f.inp.feed(cur_dir if battle.phase == "fight" else Vector2i.ZERO, {}, frozen)
		return
	_defense()
	if wants_block:
		var d := Vector2i(-f.facing, 1 if wants_low else 0)
		f.inp.feed(d, {})
		plan.clear()
		step_left = 0
		return
	if step_left <= 0:
		if plan.is_empty():
			think_cd -= 1
			if think_cd <= 0 or _can_combo():
				_decide()
		if not plan.is_empty():
			var s: Dictionary = plan.pop_front()
			cur_dir = s.get("d", Vector2i.ZERO)
			cur_btn = s.get("b", {})
			step_left = int(s.get("n", 1))
		else:
			cur_btn = {}
	step_left -= 1
	# botões só no primeiro frame do passo
	var btn := cur_btn.duplicate()
	f.inp.feed(_rel(cur_dir), btn)
	cur_btn = {}


func _rel(d: Vector2i) -> Vector2i:
	## d.x relativo: +1 = para frente
	return Vector2i(d.x * f.facing, d.y)


func _can_combo() -> bool:
	return f.state == "move" and f.mv_hit and plan.is_empty()


func _push(d: Vector2i, n := 1, b := {}) -> void:
	plan.append({"d": d, "n": n, "b": b})


func _press(b: String, d := Vector2i.ZERO) -> void:
	_push(d, 1, {b: true})
	_push(d, 1)


func _defense() -> void:
	var o: Fighter = f.opp
	if block_t > 0:
		block_t -= 1
		if block_t == 0:
			wants_block = false
		return
	if not (f.state in ["idle", "walk_f", "walk_b", "crouch", "block", "air", "land"]):
		wants_block = false
		return
	var threat := false
	var low := false
	var dx := absf(o.pos.x - f.pos.x)
	if o.state == "move" and o.mv.get("type", "") != "bullet" and dx < 95.0:
		threat = true
		low = o.mv.get("guard", "mid") == "low"
	if o.state == "spell" and dx < 160.0:
		threat = true
	for p in battle.projectiles:
		if not is_instance_valid(p) or p.owner_f != o or p.dead:
			continue
		var rel: Vector2 = f.center() - p.pos
		if rel.length() < 90.0 and (p.vel.dot(rel) > 0.0 or p.vel.length() < 0.5):
			threat = true
			low = low or p.guard == "low"
			break
	if threat:
		if rng.randf() < BLOCK_CHANCE[level]:
			wants_block = true
			wants_low = low and rng.randf() < BLOCK_CHANCE[level]
			block_t = 18
		else:
			block_t = REACT[level]
			wants_block = false


func _decide() -> void:
	think_cd = REACT[level] + rng.randi_range(0, 10)
	var o: Fighter = f.opp
	var dx: float = (o.pos.x - f.pos.x) * f.facing
	var adx := absf(dx)
	var opp_air := o.pos.y < -30.0
	var r := rng.randf()
	# combos depois de acertar
	if f.state == "move" and f.mv_hit:
		_combo()
		return
	if not f.is_neutral():
		return
	# cartas
	if not f.hand.is_empty():
		var c: Dictionary = Cards.get_card(f.hand[0])
		if f.hand.size() >= int(c["cost"]):
			if c["kind"] == "system":
				if (f.hand[0] == "elixir" and f.hp < 6500.0) or (f.hand[0] == "vento" and f.spirit < 2.0):
					_press("spell")
					return
			elif r < 0.04 + 0.03 * level and _spell_ok(f.hand[0], adx):
				_press("spell")
				return
		if f.hand.size() >= 2 and Cards.get_card(f.hand[0])["cost"] > f.hand.size() and rng.randf() < 0.05:
			_press("switch")
	# anti-aérea
	if opp_air and adx < 110.0 and o.vel.y > -2.0 and r < AGGRO[level]:
		if f.spirit >= 1.0 and f.grounded:
			_press("c", Vector2i(0, 1))
		elif f.grounded:
			_press("b", Vector2i(0, -1))
		return
	if zoner:
		_zoner(adx, r)
	else:
		_rusher(adx, r)


func _spell_ok(cid: String, adx: float) -> bool:
	match cid:
		"rubi_s1", "rubi_s2":
			return adx < 160.0 and f.grounded
		"lumia_s2":
			return true
		"lumia_s3":
			return adx < 600.0 and f.grounded
	return true


func _zoner(adx: float, r: float) -> void:
	var want := 230.0
	var o: Fighter = f.opp
	# resposta a quem vem correndo ou investindo
	if adx < 130.0 and (o.state == "dash_f" or (o.state == "move" and o.mv_id in ["c6", "ad"])) and r < AGGRO[level] + 0.1:
		if o.state == "move":
			_push(Vector2i(-1, 0), 1, {"dash": true})
			_push(Vector2i.ZERO, 10)
		else:
			_press("a")
			_push(Vector2i.ZERO, 5)
			_press("a")
		return
	if o.state == "dash_f" and adx > 130.0 and adx < 340.0 and f.grounded and f.spirit >= 1.0 and r < AGGRO[level]:
		_press("c", Vector2i(1, 0) if r < 0.6 else Vector2i.ZERO)
		return
	if o.state == "dash_f" and adx > 100.0 and f.grounded and f.spirit >= 0.4 and r < 0.5:
		_press("b", Vector2i(0, 1))
		return
	if adx < 140.0 and f.grounded and r < 0.25:
		# sai do canto pulando por cima e atira de cima
		_push(Vector2i(-1 if absf(f.pos.x) < 380.0 else 1, -1), 3)
		_push(Vector2i.ZERO, 10)
		_press("b")
		return
	if adx < 80.0:
		if r < 0.35:
			_press("dash", Vector2i(-1, 0))
		elif r < 0.6:
			_press("a")
			_push(Vector2i.ZERO, 6)
			_press("a")
		elif r < 0.75:
			_press("a", Vector2i(0, 1))
		else:
			_push(Vector2i(-1, -1), 3)
			_push(Vector2i(-1, 0), 10)
			_press("b")
		return
	if f.grounded and f.spirit >= 1.2 and r < 0.12 and not _has_lantern():
		_press("c")
		return
	if f.grounded and f.spirit >= 1.2 and adx > 180.0 and r < 0.2:
		_press("c", Vector2i(1, 0))
		return
	if f.spirit >= 0.5 and r < 0.55:
		if r < 0.15:
			_push(Vector2i(0, -1), 3)
			_push(Vector2i(0, 0), 10)
			_press("b")
		elif r < 0.3 and f.opp.pos.y < -40.0:
			_press("b", Vector2i(0, -1))
		else:
			_press("b")
		_push(Vector2i.ZERO, 8)
		return
	if adx > want + 80.0:
		_push(Vector2i(1, 0), 20)
	elif adx < want - 60.0:
		_push(Vector2i(-1, 0), 18)
	else:
		_push(Vector2i.ZERO, 10)


func _rusher(adx: float, r: float) -> void:
	if adx > 200.0:
		if r < 0.5:
			_push(Vector2i(1, 0), 1, {"dash": true})
			_push(Vector2i(1, 0), 22, {})
		elif r < 0.7 and f.spirit >= 0.6:
			_press("b")
		elif r < 0.85:
			_push(Vector2i(1, -1), 3)
			_push(Vector2i(1, 0), 14)
			_press("a", Vector2i(0, 1))
		else:
			_push(Vector2i(1, 0), 24)
		return
	if adx > 90.0:
		if r < 0.25 and f.spirit >= 1.2:
			_press("c", Vector2i(1, 0))
		elif r < 0.6:
			_push(Vector2i(1, 0), 1, {"dash": true})
			_push(Vector2i(1, 0), 12)
			_press("a")
		elif r < 0.75 and f.spirit >= 0.5:
			_press("b")
		else:
			_push(Vector2i(1, 0), 14)
		return
	# perto
	if r < 0.45:
		_press("a")
		for i in 3:
			_push(Vector2i.ZERO, 5)
			_press("a")
	elif r < 0.65:
		_press("a", Vector2i(0, 1))
	elif r < 0.8:
		_press("a", Vector2i(1, 0))
	elif r < 0.9:
		_push(Vector2i(-1, 0), 1, {"dash": true})
		_push(Vector2i.ZERO, 12)
	else:
		_push(Vector2i(0, 1), 12)


func _combo() -> void:
	var id := f.mv_id
	var allowed: Array = f.mv.get("cancel", [])
	var r := rng.randf()
	if not f.hand.is_empty() and "spell" in allowed:
		var c: Dictionary = Cards.get_card(f.hand[0])
		if c["kind"] == "spell" and f.hand.size() >= int(c["cost"]) and r < 0.35 + 0.15 * level:
			_push(Vector2i.ZERO, 2)
			_press("spell")
			return
	if "a5_2" in allowed and id == "a5_1" or "a5_3" in allowed and id == "a5_2" or "a5_4" in allowed and id == "a5_3":
		if r < 0.75 or level == 2:
			_push(Vector2i.ZERO, 3)
			_press("a")
			return
	if f.spirit >= 1.0 and ("c6" in allowed or "c2" in allowed):
		_push(Vector2i.ZERO, 3)
		if zoner:
			_press("c", Vector2i(1, 0))
		else:
			_press("c", Vector2i(0, 1) if f.opp.pos.y < -20.0 else Vector2i(1, 0))


func _has_lantern() -> bool:
	for p in battle.projectiles:
		if is_instance_valid(p) and p.owner_f == f and p.kind == "lantern" and not p.dead:
			return true
	return false
