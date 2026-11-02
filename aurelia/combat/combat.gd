class_name Combat
extends RefCounted
## Stateless helpers shared by players, enemies and spells.

## Hitbox test in the ground plane (+ generous vertical tolerance for juggles).
static func hit_test(centre: Vector3, radius_m: float, target: Node3D, target_radius: float) -> bool:
	var d := target.global_position - centre
	if absf(d.y) > 1.8:
		return false
	d.y = 0.0
	return d.length() <= radius_m + target_radius


static func attack_centre(origin: Vector3, facing: float, a) -> Vector3:
	return origin + Vector3(facing * a.reach_px * Game.PX, 0.0, 0.0)


static func launch_speed(height_px: float) -> float:
	## v0 so the apex is exactly height_px (explicit height => same launch every hit).
	return sqrt(2.0 * Game.GRAVITY * height_px * Game.PX)


static func payload(a: AttackData, attacker_peer: int, pos: Vector3, dir: Vector3, power: float, seed_val: int) -> Dictionary:
	return {
		"dmg": a.damage, "kb": a.knockback, "launch": a.launch_height_px, "hs": a.hitstop,
		"dir": dir, "col": a.trail_color, "sh": a.shake, "sfx": a.hit_sfx, "peer": attacker_peer,
		"apos": pos, "power": power, "seed": seed_val,
	}


## Deliver one confirmed hit from a spell/special projectile owned by `owner_peer`:
## local predicted feedback now, host-validated damage via claim_hit.
static func deal(e: Enemy, owner_peer: int, from: Vector3, dir: Vector3, d: Dictionary) -> void:
	var owner_pl: Player = Game.world.player_of(owner_peer) if Game.world != null else null
	var mult := owner_pl.power_mult() if owner_pl != null else 1.0
	var dmg := int(round(float(d["dmg"]) * mult))
	var power := clampf(float(dmg) / 28.0, 0.2, 1.0)
	var col: Color = d["col"]
	Juice.hit(e.global_position + Vector3(0, 0.8, 0.2), dir, col, power, d["sh"])
	Juice.hit_slash(e.global_position + Vector3(0, 0.9, 0.3), dir, col, power)
	Sfx.play(d.get("sfx", "hit"), -2.0)
	e.predict_hit(int(d["hs"]))
	var a := AttackData.new()
	a.damage = dmg
	a.knockback = d["kb"]
	a.launch_height_px = d.get("launch", 0.0)
	a.hitstop = d["hs"]
	a.shake = d["sh"]
	a.trail_color = col
	a.hit_sfx = d.get("sfx", "hit")
	e.claim_hit(payload(a, owner_peer, from, dir, power, int(d.get("seed", Game.tick)) + e.get_instance_id() % 997))
	Game.register_hit(dmg)
	if owner_pl != null:
		owner_pl.gain_sp(float(d.get("sp", 0.0)))
	Game.log_event("spell_hit", {"peer": owner_peer, "spell": d.get("id", "")})
