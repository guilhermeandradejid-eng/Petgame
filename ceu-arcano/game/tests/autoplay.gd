extends Node
# Roda uma luta CPU x CPU (ou outra cena) e salva capturas de tela periódicas.
# godot --path . res://tests/autoplay.tscn -- --out=/caminho --every=90 --total=1800 --scene=battle --chars=lumia,rubi
var out := "user://shots"
var every := 120
var total := 1800
var scene := "battle"
var n := 0
var frame := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--every="): every = int(a.substr(8))
		elif a.begins_with("--total="): total = int(a.substr(8))
		elif a.begins_with("--scene="): scene = a.substr(8)
		elif a.begins_with("--chars="): Game.p_chars = Array(a.substr(8).split(","))
		elif a.begins_with("--level="): Game.cpu_level = int(a.substr(8))
	DirAccess.make_dir_recursive_absolute(out)
	Game.mode = Game.Mode.WATCH
	Game.p_cpu = [true, true]
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start.call_deferred()


func _start() -> void:
	var s: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	get_tree().root.add_child(s)
	get_tree().current_scene = s

func _process(_d: float) -> void:
	frame += 1
	if frame % every == 0:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%04d.png" % [out, n])
		n += 1
	if frame >= total:
		get_tree().quit()
