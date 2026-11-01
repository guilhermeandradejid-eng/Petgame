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


static func attack_centre(origin: Vector3, facing: float, a: AttackData) -> Vector3:
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
