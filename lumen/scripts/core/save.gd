extends Node
## Perfil do jogador salvo em disco: nome, classe, visual, desbloqueios e progressao permanente.

signal changed

const VERSION := 1

var profile_name := "perfil"
var data: Dictionary = {}

func _enter_tree() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profile="):
			profile_name = a.get_slice("=", 1)
	load_profile()

func _path() -> String:
	return "user://%s.json" % profile_name

func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"name": "Viajante",
		"cls": "espadachim",
		"look": default_look(),
		"weapons": {},          # tipo de arma -> skin equipada
		"unlocked": [],         # ids de cosmeticos comprados
		"shards": 0,            # moeda permanente (fragmentos de lumen)
		"upgrades": {},         # id -> nivel
		"heat": 0,              # dificuldade escolhida
		"max_heat": 0,          # maior dificuldade liberada
		"stats": {"runs": 0, "wins": 0, "kills": 0, "best_room": 0, "deaths": 0},
		"settings": {"sens": 1.0, "volume": 0.8, "music": 0.6, "fullscreen": false, "shake": 1.0},
		"last_ip": "127.0.0.1",
		"seen_help": false,
	}

func default_look() -> Dictionary:
	return {
		"hair": "hair_bagunca", "hat": "", "ears": "", "acc": "", "top": "top_tunica",
		"bottom": "bottom_botas", "back": "", "eyes": "eyes_round",
		"skin": "f6c9a4", "hair_c": "7a4a2e", "primary": "3f86d9", "secondary": "f3ead6",
		"accent": "f2b632", "iris": "5fb0e8",
	}

func load_profile() -> void:
	data = defaults()
	if FileAccess.file_exists(_path()):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path()))
		if parsed is Dictionary:
			_merge(data, parsed)
	# perfis de teste comecam com nome proprio
	if profile_name != "perfil" and data["name"] == "Viajante":
		data["name"] = profile_name.capitalize()

func _merge(base: Dictionary, over: Dictionary) -> void:
	for k in over:
		if base.has(k) and base[k] is Dictionary and over[k] is Dictionary:
			_merge(base[k], over[k])
		else:
			base[k] = over[k]

func save() -> void:
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, " "))
	changed.emit()

func setting(key: String) -> Variant:
	return data["settings"].get(key, defaults()["settings"].get(key))

func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save()

# ------------------------------------------------------------------ moeda e desbloqueios
func add_shards(n: int) -> void:
	data["shards"] = int(data["shards"]) + n
	save()

func spend_shards(n: int) -> bool:
	if int(data["shards"]) < n:
		return false
	data["shards"] = int(data["shards"]) - n
	save()
	return true

func is_unlocked(id: String) -> bool:
	if id == "":
		return true
	return DB.cosmetic_cost(id) <= 0 or data["unlocked"].has(id)

func unlock(id: String) -> bool:
	if is_unlocked(id):
		return true
	if not spend_shards(DB.cosmetic_cost(id)):
		return false
	data["unlocked"].append(id)
	save()
	return true

func upgrade_level(id: String) -> int:
	return int(data["upgrades"].get(id, 0))

func buy_upgrade(id: String) -> bool:
	var def: Dictionary = DB.UPGRADES.get(id, {})
	if def.is_empty():
		return false
	var lvl := upgrade_level(id)
	if lvl >= int(def["max"]):
		return false
	if not spend_shards(DB.upgrade_cost(id, lvl)):
		return false
	data["upgrades"][id] = lvl + 1
	save()
	return true

func weapon_skin(wt: String) -> String:
	var w: String = data["weapons"].get(wt, "")
	if w == "" or not is_unlocked(w):
		w = DB.default_weapon(wt)
	return w

## Visual completo enviado pela rede (inclui a arma da classe atual).
func net_look() -> Dictionary:
	var l: Dictionary = data["look"].duplicate()
	l["weapon"] = weapon_skin(DB.CLASSES[data["cls"]]["wt"])
	return l
