extends Node
## Loads every data/**/*.tres by id. Adding a weapon/spell/enemy = adding a .tres file.

var weapons: Dictionary = {}
var spells: Dictionary = {}
var enemies: Dictionary = {}


func _ready() -> void:
	_scan("res://data/weapons", weapons)
	_scan("res://data/spells", spells)
	_scan("res://data/enemies", enemies)


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


func weapon(id: String) -> WeaponData:
	return weapons.get(id)


func spell(id: String) -> SpellData:
	return spells.get(id)


func enemy(id: String) -> EnemyData:
	return enemies.get(id)
