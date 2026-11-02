extends Node
## Loads every data/**/*.tres by id. Adding a weapon/spell/enemy = adding a .tres file.

var weapons: Dictionary = {}
var spells: Dictionary = {}
var enemies: Dictionary = {}
var weapon_order: Array = ["bronze_sword", "iron_spear", "stone_axe"]
var spell_order: Array = ["ice_lance", "ring_of_fire", "comet"]


func _ready() -> void:
	_scan("res://data/weapons", weapons)
	_scan("res://data/spells", spells)
	_scan("res://data/enemies", enemies)
	_index_anims()


func _scan(dir_path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		var fname := f.trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var res := load(dir_path + "/" + fname)
		if res != null and "id" in res:
			into[res.id] = res
		else:
			push_error("Registry: could not load %s/%s" % [dir_path, fname])


var _anim_special: Dictionary = {}
var _anim_attack: Dictionary = {}


func _index_anims() -> void:
	for w in weapons.values():
		for a in w.combo:
			_anim_attack[a.anim] = a
		for sp in w.specials:
			_anim_special[sp.anim] = sp


func special_for_anim(anim: String) -> SpecialData:
	return _anim_special.get(anim)


func attack_for_anim(anim: String) -> AttackData:
	return _anim_attack.get(anim)


func weapon(id: String) -> WeaponData:
	return weapons.get(id)


func spell(id: String) -> SpellData:
	return spells.get(id)


func enemy(id: String) -> EnemyData:
	return enemies.get(id)
