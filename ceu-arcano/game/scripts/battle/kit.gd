class_name Kit
extends RefCounted
## Base dos personagens: atributos, tabela de golpes e ganchos de eventos/feitiços.

var id := ""
var walk_f := 2.2
var walk_b := 1.8
var jump_v := -9.4
var jump_x := 3.2
var dash_speed := 6.0
var dash_min := 12
var dash_max := 34
var fly_speed := 5.6
var ghost_color := Color(0.6, 0.9, 1.0, 0.55)
var deck: Array = []
var moves := {}

const MELEE_CANCEL := ["b5", "b2", "b2c", "c5", "c6", "c2", "spell"]
const AIR_CANCEL := ["bj", "cj", "spell"]


static func create(cid: String) -> Kit:
	match cid:
		"lumia":
			return load("res://scripts/battle/kit_lumia.gd").new()
		"rubi":
			return load("res://scripts/battle/kit_rubi.gd").new()
	return Kit.new()


func next_chain(cur: String) -> String:
	match cur:
		"a5_1":
			return "a5_2"
		"a5_2":
			return "a5_3"
		"a5_3":
			return "a5_4"
	return "a5_1"


func melee(anim: String, dmg: float, level: int, extra := {}) -> Dictionary:
	var m := {
		"anim": anim, "type": "melee", "dmg": dmg, "level": level,
		"stun": [15, 19, 24][level], "bstun": [11, 14, 18][level],
		"kb": Vector2([2.2, 3.0, 5.0][level], 0.0), "guard": "mid",
		"spirit_dmg": [0.25, 0.4, 0.6][level], "prorate": [0.92, 0.88, 0.82][level],
		"limit": [8, 12, 20][level], "push": [2.6, 3.2, 4.2][level],
		"swing": "swing_light" if level == 0 else "swing_heavy",
		"cancel": MELEE_CANCEL.duplicate(),
	}
	m.merge(extra, true)
	return m


func shot(anim: String, cost: float, extra := {}) -> Dictionary:
	var m := {"anim": anim, "type": "bullet", "cost": cost, "cancel": ["c5", "c6", "c2", "cj", "spell"],
			  "cancel_on": "always", "cancel_from": 14}
	m.merge(extra, true)
	return m


func skill(anim: String, cost: float, extra := {}) -> Dictionary:
	var m := {"anim": anim, "type": "skill", "cost": cost, "cancel": ["spell"], "cancel_on": "contact",
			  "dmg": 0.0, "level": 1}
	m.merge(extra, true)
	return m


# ------------------------------------------------------------------ ganchos

func on_event(_f: Fighter, _ev: String) -> void:
	pass


func move_start(_f: Fighter, _id: String) -> void:
	pass


func move_tick(_f: Fighter, _id: String) -> void:
	pass


func on_land(_f: Fighter, _id: String) -> void:
	pass


func on_move_hit(_f: Fighter, _id: String, _victim: Fighter, _blocked: bool) -> void:
	pass


func can_spell(_f: Fighter, _cid: String) -> bool:
	return true


func spell_start(_f: Fighter, _cid: String) -> void:
	pass


func spell_tick(_f: Fighter) -> bool:
	return true


# ------------------------------------------------------------------ util para projéteis

func bullet(f: Fighter, kind: String, at: Vector2, v: Vector2, extra := {}) -> Projectile:
	return f.battle.spawn_projectile(f, kind, at, v, extra)


func aim(f: Fighter, from: Vector2) -> Vector2:
	if f.opp == null:
		return Vector2(f.facing, 0)
	return (f.opp.center() - from).normalized()
