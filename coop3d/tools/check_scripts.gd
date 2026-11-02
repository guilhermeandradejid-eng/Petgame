extends Node
## Compiles every GDScript in the project and reports failures.
## Usage: godot --headless --path . res://tools/check.tscn


func _ready() -> void:
	var bad := 0
	for f in _scan("res://scripts"):
		var s = load(f)
		if s == null or not (s is GDScript) or not s.can_instantiate():
			print("FAIL ", f)
			bad += 1
	print("checked, failures: ", bad)
	get_tree().quit(1 if bad > 0 else 0)


func _scan(dir: String) -> Array:
	var out := []
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scan(dir + "/" + d))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	return out
