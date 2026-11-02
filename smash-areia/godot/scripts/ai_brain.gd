class_name AIBrain
extends RefCounted
## Cérebro dos jogadores controlados pelo computador (adversários, parceiro e
## os bonecos do modo demonstração do menu).

var p: Player
var diff: Dictionary
var rng := RandomNumberGenerator.new()
var plan: Dictionary = {}
var plan_hit_id := -999
var react_left := 0.0
var replan_t := 0.0
var leaving := false
var committed := false
var dive_done := false
var move_target := Vector3.ZERO
var sloppy := Vector3.ZERO     # imprecisão de posicionamento (depende da dificuldade)


func _init(player: Player, difficulty: Dictionary) -> void:
	p = player
	diff = difficulty
	rng.randomize()
	move_target = player.position


## Calcula onde e quando o jogador consegue alcançar a bola.
## Retorna {} se for impossível, ou {ok, t, point, stand, high, dive}
static func intercept(pl: Player, ball: Ball, react: float) -> Dictionary:
	if not ball.is_live():
		return {}
	var speed := pl.max_speed()
	if ball.speed_at_hit > 16.0:
		react += 0.1   # pancada é difícil de ler
	var nd := pl.net_dir()
	var here := Vector2(pl.position.x, pl.position.z)
	for i in range(1, 95):
		var t := i * 0.035
		var bp := ball.predict(t)
		if bp.y < 0.2:
			break
		if bp.z * pl.side < 0.45 or bp.y > 3.25:
			continue
		var stand := Vector3(bp.x, 0.0, bp.z) - nd * 0.3
		var dist := maxf(Vector2(stand.x, stand.z).distance_to(here) - 0.5, 0.0)
		var need := react + dist / speed + (0.1 if dist > 0.4 else 0.0)
		var high := bp.y > Player.TOP_REACH - 0.1
		if high:
			need += 0.08
		if need <= t:
			return {"ok": true, "t": t, "point": bp, "stand": stand, "high": high, "dive": false}
	# não alcança correndo: tenta o mergulho
	var tl := ball.time_to_ground()
	for k in 4:
		var t2 := tl - 0.06 - k * 0.07
		if t2 <= 0.1:
			break
		var bp2 := ball.predict(t2)
		if bp2.z * pl.side < 0.45 or bp2.y > 1.0:
			continue
		var d2 := Vector2(bp2.x, bp2.z).distance_to(here)
		var run_time := maxf(t2 - react - 0.4, 0.0)
		if d2 <= run_time * speed + 2.3:
			return {"ok": true, "t": t2, "point": bp2, "stand": Vector3(bp2.x, 0, bp2.z), "high": false, "dive": true}
	return {}


func update(dt: float, game: Node) -> void:
	var ball: Ball = game.ball
	if ball.hit_id != plan_hit_id:
		plan_hit_id = ball.hit_id
		react_left = float(diff["reaction"]) * rng.randf_range(0.75, 1.35)
		plan = {}
		leaving = false
		committed = false
		dive_done = false
		replan_t = 0.0
		var a := rng.randf() * TAU
		sloppy = Vector3(cos(a), 0.0, sin(a)) * float(diff["error"]) * rng.randf_range(0.15, 0.75)
		if ball.last_team != p.team and ball.is_live() and game.interceptor(p.team) == p:
			_judge_out(ball, game)
	if p.state != Player.State.NORMAL:
		p.move_input = Vector3.ZERO
		return
	if react_left > 0.0:
		react_left -= dt
		_steer(move_target, dt, 0.5)
		return
	var incoming: bool = ball.is_live() and ball.last_team != p.team
	if incoming and game.interceptor(p.team) == p and not leaving:
		replan_t -= dt
		if plan.is_empty() or replan_t <= 0.0:
			var np := intercept(p, ball, 0.0)
			if not np.is_empty():
				plan = np
				plan["t_abs"] = game.time + float(np["t"])
			replan_t = 0.12
		if plan.is_empty():
			_steer(game.support_position(p), dt, 1.0)
			return
		var t_left: float = float(plan["t_abs"]) - game.time
		var stand: Vector3 = plan["stand"] + sloppy
		if plan["dive"]:
			_steer(stand, dt, 1.0)
			var d := Vector2(stand.x - p.position.x, stand.z - p.position.z).length()
			if not dive_done and t_left < 0.42 and d > 0.9 and rng.randf() < float(diff["dive"]) + 0.2:
				dive_done = true
				p.request_dive(Vector3(stand.x - p.position.x, 0, stand.z - p.position.z))
		else:
			_steer(stand, dt, 1.0)
			if not committed and t_left < 0.34:
				committed = true
				var bp: Vector3 = plan["point"]
				var shot := choose_shot(bp, ball, game)
				p.request_shot(shot)
	else:
		_steer(game.support_position(p), dt, 0.9)


func _judge_out(ball: Ball, game: Node) -> void:
	var land := ball.landing_point()
	var out_by := maxf(absf(land.x) - GameData.COURT_HALF_W, absf(land.z) - GameData.COURT_HALF_L)
	if out_by > 0.35 and land.z * p.side > 0.0 and rng.randf() < float(diff["judge"]):
		leaving = true
		p.say("FORA!" if rng.randf() < 0.5 else "DEIXA!", Color("ffe14d"))
		var mate: Player = game.teammate(p)
		if mate and mate.brain:
			mate.brain.leaving = true


func _steer(target: Vector3, _dt: float, urgency: float) -> void:
	move_target = target
	var to := Vector3(target.x - p.position.x, 0.0, target.z - p.position.z)
	var d := to.length()
	if d < 0.12:
		p.move_input = Vector3.ZERO
		return
	var k := clampf(d / 0.9, 0.0, 1.0) * urgency
	p.move_input = to / d * k


func choose_shot(contact: Vector3, ball: Ball, game: Node) -> int:
	var opps: Array = game.opponents(p)
	var avg_z := 0.0
	for o in opps:
		avg_z += absf((o as Player).position.z)
	avg_z /= maxf(opps.size(), 1)
	var roll := rng.randf()
	var close_net := absf(contact.z) < 5.5
	if contact.y > Player.TOP_REACH - 0.2 and close_net and roll < float(diff["smash"]):
		return Shots.SMASH
	if ball.speed_at_hit > 17.0:
		return Shots.LOB if roll < 0.55 else Shots.DRIVE
	roll = rng.randf()
	if avg_z < 3.6:
		if roll < 0.5:
			return Shots.LOB
		return Shots.DRIVE if roll < 0.88 else Shots.DROP
	if avg_z > 5.6:
		if roll < 0.38:
			return Shots.DROP
		return Shots.DRIVE if roll < 0.85 else Shots.LOB
	if roll < 0.62:
		return Shots.DRIVE
	return Shots.LOB if roll < 0.82 else Shots.DROP


## Mira no buraco entre os adversários.
func choose_aim(game: Node, shot: int) -> Vector2:
	var opps: Array = game.opponents(p)
	var best_x := 0.0
	var best_score := -INF
	for cx in [-0.95, -0.5, 0.0, 0.5, 0.95]:
		var wx: float = cx * 3.2
		var score := 0.0
		var m := INF
		for o in opps:
			m = minf(m, absf((o as Player).position.x - wx))
		score = m + rng.randf_range(0.0, 1.6)
		if score > best_score:
			best_score = score
			best_x = cx
	var depth := rng.randf_range(-0.5, 0.6)
	if shot == Shots.LOB:
		depth = rng.randf_range(-0.3, 0.4)
	return Vector2(best_x, depth)
