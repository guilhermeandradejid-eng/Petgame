extends Node
# Carrega todos os scripts do projeto (com os autoloads ativos) para pegar erros de compilação.
func _ready() -> void:
	var bad := 0
	for dir in ["res://scripts/core/", "res://scripts/battle/", "res://scripts/ui/"]:
		var d := DirAccess.open(dir)
		for f in d.get_files():
			if f.ends_with(".gd"):
				var s = load(dir + f)
				if s == null or not s.can_instantiate():
					print("FALHOU: ", dir + f)
					bad += 1
	print("scripts com erro: ", bad)
	get_tree().quit(1 if bad > 0 else 0)
