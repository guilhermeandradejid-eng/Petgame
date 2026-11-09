extends Node
## Cena de abertura: mostra o carregamento (carrinho andando) enquanto a cena do jogo, os modelos e a
## trilha são carregados em segundo plano; depois entrega para o jogo e some suavemente.

const MAIN := "res://scenes/main.tscn"
const WARM := ["res://assets/minicars.glb", "res://music/menu.ogg"]

var layer: CanvasLayer
var loader: Loader
var t := 0.0
var done := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	# servidor, testes e modo sem tela: entra direto
	if DisplayServer.get_name() == "headless" or "--server" in args or "--autotest" in args:
		get_tree().change_scene_to_file.call_deferred(MAIN)
		return
	layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	loader = Loader.new()
	layer.add_child(loader)
	Lang.setup(Lang.saved_code())
	loader.show_for("WRECK 'N' ROLL", "LIGANDO OS MOTORES")
	ResourceLoader.load_threaded_request(MAIN)
	for p in WARM:
		if ResourceLoader.exists(p):
			ResourceLoader.load_threaded_request(p)


func _process(dt: float) -> void:
	if done or loader == null:
		return
	t += dt
	var tot := 0.0
	var all_ok := true
	for p in [MAIN] + WARM:
		if not ResourceLoader.exists(p):
			continue
		var pr := []
		var st := ResourceLoader.load_threaded_get_status(p, pr)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			tot += 1.0
		elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			tot += float(pr[0]) if pr.size() > 0 else 0.0
			all_ok = false
		else:
			all_ok = all_ok and st != ResourceLoader.THREAD_LOAD_IN_PROGRESS
	loader.progress = 0.9 * tot / float(1 + WARM.size())
	# mostra o carrinho por pelo menos 1,2 s (dá tempo de ver a animação)
	if all_ok and t > 1.2:
		done = true
		_go()


func _go() -> void:
	var ps: PackedScene = ResourceLoader.load_threaded_get(MAIN)
	for p in WARM:
		if ResourceLoader.exists(p):
			ResourceLoader.load_threaded_get(p)
	loader.progress = 0.95
	await get_tree().process_frame
	var main := ps.instantiate()
	get_tree().root.add_child(main)   # o _ready do jogo roda aqui (monta a pista) com o carregamento por cima
	get_tree().current_scene = main
	loader.progress = 1.0
	await get_tree().process_frame
	await get_tree().process_frame
	loader.finish()
	await get_tree().create_timer(0.6).timeout
	queue_free()
