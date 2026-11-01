extends Node
## Scripted bot used by the automated tests: `--autotest` (solo / host / client by Net.mode).
## Prints TEST_OK / TEST_FAIL lines and exits with a matching status code.

var role := "solo"
var ticks := 0
var _cast_cd := 0
var _dash_cd := 0
var _me: Player
var _done_at := -1


func _ready() -> void:
	role = {"offline": "solo", "host": "host", "client": "client"}.get(Net.mode, "solo")
	if role == "solo" and not Game.args.has("shot"):
		Engine.time_scale = 3.0
	print("[autotest] role=", role)


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var bd := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.data.dummy or e.is_dead():
			continue
		var d: float = (e.global_position - _me.global_position).length()
		if d < bd:
			bd = d
			best = e
	return best


func _showcase(tick: int) -> Dictionary:
	## Fixed choreography for screenshots: walk up beside the dummy, cast, then a 3-hit combo.
	var out := {"move": Vector2.ZERO, "press": 0}
	if tick < 50:
		out["move"] = Vector2(0, -1)
	elif tick < 53:
		out["move"] = Vector2(1, 0)
	elif tick == 56:
		out["press"] = InputFrame.CAST
	elif tick >= 100 and tick < 104:
		out["move"] = Vector2(1, 0)
	elif tick >= 104 and tick < 125:
		out["move"] = Vector2(0.2, 0)
		if tick in [110, 122, 134]:
			out["press"] = InputFrame.ATTACK
	elif tick >= 126:
		out["move"] = Vector2(0.2, 0)
		if tick in [134, 148]:
			out["press"] = InputFrame.ATTACK
	return out


func _drive(tick: int) -> Dictionary:
	if Game.args.has("showcase"):
		return _showcase(tick)
	var out := {"move": Vector2.ZERO, "press": 0}
	var t := _nearest_enemy()
	_cast_cd -= 1
	_dash_cd -= 1
	if t == null or _me.is_dead():
		return out
	var to := t.global_position - _me.global_position
	to.y = 0.0
	var dist := to.length()
	var dir := Vector2(to.x, to.z).normalized()
	if tick == 40:
		out["press"] |= InputFrame.JUMP
	elif dist > 3.6 and dist < 9.0 and _cast_cd <= 0 and _me.mp >= 20.0 and absf(to.x) > absf(to.z) * 2.0:
		out["press"] |= InputFrame.CAST
		_cast_cd = 150
		out["move"] = dir * 0.2
	elif dist <= 1.7:
		out["move"] = dir * 0.2
		if tick % 9 == 0:
			out["press"] |= InputFrame.ATTACK
		if _dash_cd <= 0 and tick % 400 < 3:
			out["press"] |= InputFrame.DASH
			_dash_cd = 200
	else:
		out["move"] = dir
	return out


func _shots() -> void:
	## --shot=<dir>: save viewport screenshots at fixed ticks (needs a real renderer, e.g. xvfb).
	var dir: String = Game.args["shot"]
	var list: Array = [60, 200, 330, 420, 520, 640]
	if Game.args.has("shot_ticks"):
		list = Array(String(Game.args["shot_ticks"]).split(",")).map(func(x): return int(x))
	for t in list:
		if ticks == t:
			DirAccess.make_dir_recursive_absolute(dir)
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/shot_%04d.png" % [dir, t])
			print("[autotest] saved shot ", t, " player=", _me.global_position if _me else null, " focus=", Game.world.cam.focus, " cam=", Game.world.cam.cam.global_position, " dist=", Game.world.cam.dist)
	if ticks > int(list.max()) + 10:
		get_tree().quit(0)


func _physics_process(_d: float) -> void:
	ticks += 1
	if Game.args.has("shot"):
		_shots()
	if _me == null or not is_instance_valid(_me):
		for p in get_tree().get_nodes_in_group("players"):
			if p.is_multiplayer_authority():
				_me = p
				_me.source = InputSource.Scripted.new(_drive)
		return
	if _done_at < 0 and _condition():
		_done_at = ticks + 90
	if _done_at > 0 and ticks >= _done_at:
		_finish(true)
	if ticks > 3600 * 3:
		_finish(false)


func _condition() -> bool:
	var players := get_tree().get_nodes_in_group("players").size()
	match role:
		"solo":
			return Game.kills >= 1 and Game.count_events("dash") >= 1 and Game.count_events("player_hit") >= 3 \
				and Game.count_events("spell_hit") >= 1
		"host":
			return players >= 2 and Game.kills >= 1
		_:
			return players >= 2 and Game.kills >= 1
	return false


func _finish(ok: bool) -> void:
	var players := get_tree().get_nodes_in_group("players").size()
	var summary := "role=%s ticks=%d players=%d kills=%d dashes=%d hits=%d spell_hits=%d hurt=%d" % [
		role, ticks, players, Game.kills, Game.count_events("dash"), Game.count_events("player_hit"),
		Game.count_events("spell_hit"), Game.count_events("player_hurt")]
	print(("TEST_OK " if ok else "TEST_FAIL ") + summary)
	get_tree().quit(0 if ok else 1)
