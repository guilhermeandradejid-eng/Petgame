extends Node
## Scripted bot used by the automated tests: `--autotest` (solo / host / client by Net.mode).
## Prints TEST_OK / TEST_FAIL lines and exits with a matching status code.

var role := "solo"
var ticks := 0
var _cast_cd := 0
var _dash_cd := 0
var _sp_cd := 0
var _me: Player
var _done_at := -1
var _saw_two := false


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


const SHOW := {
	30: InputFrame.SP1,          # sword: Whirlwind
	110: InputFrame.SP2,         # sword: Meteor Dive
	200: InputFrame.WEAPON,      # -> spear
	215: InputFrame.SP1,         # Gale Thrusts
	290: InputFrame.SP2,         # Javelin Toss
	370: InputFrame.WEAPON,      # -> axe
	385: InputFrame.SP1,         # Quake Cleave
	470: InputFrame.SP2,         # Hurricane Axe
	560: InputFrame.CAST,        # Ice Lance
	620: InputFrame.SPELL,
	632: InputFrame.CAST,        # Ring of Fire
	720: InputFrame.SPELL,
	732: InputFrame.CAST,        # Comet
	800: InputFrame.WEAPON,      # -> sword
	812: InputFrame.ATTACK,      # sword combo
	824: InputFrame.ATTACK,
	836: InputFrame.ATTACK,
}


func _showcase(tick: int) -> Dictionary:
	## Fixed choreography for screenshots: every special and spell against the training dummy.
	var out := {"move": Vector2.ZERO, "press": 0}
	_me.sp = 100.0
	_me.mp = _me.max_mp
	if tick < 50:
		out["move"] = Vector2(0, -1)
	elif tick < 54:
		out["move"] = Vector2(1, 0)
	if SHOW.has(tick):
		out["press"] = SHOW[tick]
	return out


func _drive(tick: int) -> Dictionary:
	if Game.args.has("showcase"):
		return _showcase(tick)
	var out := {"move": Vector2.ZERO, "press": 0}
	var t := _nearest_enemy()
	_cast_cd -= 1
	_dash_cd -= 1
	_sp_cd -= 1
	if _me.is_dead():
		return out
	# rotate through the loadout so every weapon / spell gets exercised
	if tick in [420, 1300, 2200] and _me.state == Player.S.IDLE:
		out["press"] |= InputFrame.WEAPON
	if tick in [800, 1700] and _me.state == Player.S.IDLE:
		out["press"] |= InputFrame.SPELL
	if t == null:
		return out
	var to := t.global_position - _me.global_position
	to.y = 0.0
	var dist := to.length()
	var dir := Vector2(to.x, to.z).normalized()
	if tick == 40:
		out["press"] |= InputFrame.JUMP
	elif _sp_cd <= 0 and _me.sp >= 70.0 and dist < 4.0:
		out["press"] |= InputFrame.SP2
		_sp_cd = 150
		out["move"] = dir * 0.2
	elif _sp_cd <= 0 and _me.sp >= 40.0 and dist < 3.0:
		out["press"] |= InputFrame.SP1
		_sp_cd = 120
		out["move"] = dir * 0.2
	elif dist > 3.2 and dist < 9.0 and _cast_cd <= 0 and _me.mp >= float(_me.spell.mp_cost) and Game.arena_active:
		out["press"] |= InputFrame.CAST
		_cast_cd = 140
		out["move"] = dir * 0.2
	elif dist <= 1.8:
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
			print("[autotest] saved shot ", t, " player=", _me.global_position if _me else null)
	if ticks > int(list.max()) + 10:
		get_tree().quit(0)


func _physics_process(_d: float) -> void:
	ticks += 1
	if Game.args.has("shot"):
		_shots()
	if ticks % 600 == 0:
		print("[autotest] t=%d kills=%d battles=%d specials=%d hp=%d sp=%.0f pos=%s state=%s" % [ticks, Game.kills, Game.count_events("battle_start"), Game.count_events("special"), _me.hp if _me else -1, _me.sp if _me else 0.0, _me.global_position if _me else null, _me.state if _me else -1])
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
	if ticks > 3600 * 2:
		_finish(false)


func _condition() -> bool:
	var players := get_tree().get_nodes_in_group("players").size()
	_saw_two = _saw_two or players >= 2
	match role:
		"solo":
			return Game.kills >= 6 and Game.count_events("dash") >= 1 and Game.count_events("player_hit") >= 10 \
				and Game.count_events("spell_hit") >= 1 and Game.count_events("special") >= 1 \
				and Game.count_events("battle_start") >= 1 and Game.count_events_where("battle_end", "win", true) >= 1
		"host":
			# stay up until the client has seen its kill and left, so both sides are verified
			return _saw_two and Game.kills >= 1 and Game.count_events("peer_left") >= 1
		_:
			return players >= 2 and Game.kills >= 1
	return false


func _finish(ok: bool) -> void:
	var players := get_tree().get_nodes_in_group("players").size()
	players = maxi(players, 2 if _saw_two else 0)
	var summary := "role=%s ticks=%d players=%d kills=%d dashes=%d hits=%d spell_hits=%d specials=%d battles=%d won=%d hurt=%d" % [
		role, ticks, players, Game.kills, Game.count_events("dash"), Game.count_events("player_hit"),
		Game.count_events("spell_hit"), Game.count_events("special"), Game.count_events("battle_start"),
		Game.count_events_where("battle_end", "win", true), Game.count_events("player_hurt")]
	print(("TEST_OK " if ok else "TEST_FAIL ") + summary)
	get_tree().quit(0 if ok else 1)
