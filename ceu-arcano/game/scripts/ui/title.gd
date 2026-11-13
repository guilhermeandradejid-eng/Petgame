extends Node2D
## Tela de título: o jardim ao fundo com a câmera passeando, logo animado e menu.

var world: Node2D
var stage: Node2D
var cam: Camera2D
var darken := 0.0
var fx = null
var hud = null
var t := 0.0
var menu: MenuList
var opts: MenuList
var ui: Control
var logo_t := 0.0
var previews: Array = []
var in_options := false
var started := false


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	stage = load("res://scripts/battle/stage.gd").new()
	stage.battle = self
	world.add_child(stage)
	stage.build_front()
	cam = Camera2D.new()
	world.add_child(cam)
	cam.make_current()
	# as duas personagens no jardim
	for i in 2:
		var p := CharPreview.new()
		p.setup(Game.CHARACTERS[i])
		p.position = Vector2(-70 if i == 0 else 70, 0)
		p.facing = 1 if i == 0 else -1
		p.z_index = 5
		world.add_child(p)
		previews.append(p)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = _UI.new()
	ui.title = self
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	menu = MenuList.new()
	menu.position = Vector2(220, 196)
	menu.size = Vector2(200, 150)
	menu.spacing = 18.0
	menu.font_size = 13
	menu.set_items([
		{"text": "Versus CPU", "hint": "Você contra a máquina, melhor de 3."},
		{"text": "2 Jogadores", "hint": "P1 no teclado (WASD+JKL) ou controle 1, P2 nas setas+numpad ou controle 2."},
		{"text": "Treino", "hint": "Boneco parado, cartas e espírito sem fim. F1 mostra as caixas."},
		{"text": "Assistir CPU x CPU", "hint": "Senta e assiste."},
		{"text": "Opções"},
		{"text": "Sair"},
	])
	menu.chosen.connect(_on_choose)
	menu.cancelled.connect(func(): pass)
	menu.visible = false
	menu.active = false
	layer.add_child(menu)
	opts = MenuList.new()
	opts.position = Vector2(170, 196)
	opts.size = Vector2(300, 150)
	opts.spacing = 18.0
	opts.font_size = 13
	opts.visible = false
	opts.active = false
	opts.chosen.connect(_on_opt)
	opts.cancelled.connect(_close_opts)
	layer.add_child(opts)
	Audio.music("title")


class _UI extends Control:
	var title
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		title._draw_ui(self)


func _process(delta: float) -> void:
	t += delta
	logo_t += delta
	var cp := Vector2(sin(t * 0.07) * 120.0, -150.0 + sin(t * 0.11) * 30.0)
	var z := 0.9 + sin(t * 0.05) * 0.05
	cam.position = cp
	cam.zoom = Vector2(z, z)
	stage.update_view(cp, z)
	if not started and logo_t > 1.2:
		started = true
		menu.visible = true
		menu.active = true
	if not started and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("p1_a")):
		logo_t = 1.2
	if previews.size() == 2 and int(t * 60.0) % 400 == 0:
		previews[randi() % 2].play("intro")


func _draw_ui(c: Control) -> void:
	var k := clampf(logo_t / 1.0, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	# faixa escura de leitura
	c.draw_rect(Rect2(0, 0, 640, 360), Color(0.03, 0.02, 0.09, 0.25))
	var y := 70.0 + (1.0 - e) * -40.0
	var title := "CÉU ARCANO"
	var font: Font = Game.font_title
	var size := 44
	var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := 320.0 - w * 0.5
	# brilho/eco
	for i in 3:
		var off := Vector2(sin(t * 1.3 + i) * 2.0, (i + 1) * 2.0)
		c.draw_string(font, Vector2(x, y) + off, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.6, 0.3, 0.9, 0.25 * e))
	c.draw_string_outline(font, Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(0.04, 0.02, 0.1, e))
	# letra por letra com degradê
	var cx := x
	for i in title.length():
		var ch := title[i]
		var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var wave := sin(t * 2.0 - i * 0.5) * 2.0
		var col := Color("ffe9a8").lerp(Color("7affd8"), 0.5 + 0.5 * sin(t * 0.8 + i * 0.4))
		c.draw_string(font, Vector2(cx, y + wave), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, e))
		cx += cw
	# estrelinha girando
	_star(c, Vector2(x - 18, y - 16), 7.0 + sin(t * 3.0), Color("ffd66b", e), t)
	_star(c, Vector2(x + w + 18, y - 16), 7.0 + cos(t * 3.0), Color("ffd66b", e), -t)
	var sub := "Duelo de Cartas no Crepúsculo"
	var sw := Game.font_main.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	c.draw_string_outline(Game.font_main, Vector2(320 - sw * 0.5, y + 24), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0.04, 0.02, 0.1, e))
	c.draw_string(Game.font_main, Vector2(320 - sw * 0.5, y + 24), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.85, 1.0, e))
	if not started:
		var a := 0.5 + 0.5 * sin(t * 4.0)
		var s2 := "aperte J ou Enter"
		var w2 := Game.font_main.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		c.draw_string(Game.font_main, Vector2(320 - w2 * 0.5, 260), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, a))
	else:
		c.draw_rect(Rect2(170, 184, 300, menu.items.size() * 18.0 + 34.0 if not in_options else 150.0), Color(0.04, 0.02, 0.1, 0.55))
	c.draw_string(Game.font_small, Vector2(8, 354), "F11 tela cheia", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.7, 0.85, 0.7))
	var v := "pixel rig em Python · cenário no Blender · Godot 4"
	var vw := Game.font_small.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(Game.font_small, Vector2(632 - vw, 354), v, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.7, 0.85, 0.7))


func _star(c: Control, ctr: Vector2, r: float, col: Color, rot: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(ctr + Vector2.from_angle(rot - PI / 2 + i * PI / 5) * rr)
	c.draw_colored_polygon(pts, col)


func _on_choose(i: int) -> void:
	match i:
		0:
			Game.mode = Game.Mode.VS_CPU
			Game.p_cpu = [false, true]
			Game.goto("res://scenes/select.tscn")
		1:
			Game.mode = Game.Mode.VS_PLAYER
			Game.p_cpu = [false, false]
			Game.goto("res://scenes/select.tscn")
		2:
			Game.mode = Game.Mode.TRAINING
			Game.p_cpu = [false, true]
			Game.goto("res://scenes/select.tscn")
		3:
			Game.mode = Game.Mode.WATCH
			Game.p_cpu = [true, true]
			Game.p_chars = [Game.CHARACTERS[randi() % 2], Game.CHARACTERS[randi() % 2]]
			Game.goto("res://scenes/battle.tscn")
		4:
			_open_opts()
		5:
			get_tree().quit()


func _opt_items() -> Array:
	var lv = ["Fácil", "Normal", "Difícil"][Game.cpu_level]
	return [
		{"text": "Dificuldade da CPU: %s" % lv},
		{"text": "Rounds para vencer: %d" % Game.rounds_to_win},
		{"text": "Volume geral: %d%%" % int(Game.master_volume * 100)},
		{"text": "Música: %d%%" % int(Game.music_volume * 100)},
		{"text": "Tela cheia"},
		{"text": "Voltar"},
	]


func _open_opts() -> void:
	in_options = true
	menu.active = false
	menu.visible = false
	opts.set_items(_opt_items())
	opts.sel = 0
	opts.visible = true
	await get_tree().process_frame
	opts.active = true


func _close_opts() -> void:
	in_options = false
	opts.active = false
	opts.visible = false
	menu.visible = true
	await get_tree().process_frame
	menu.active = true


func _on_opt(i: int) -> void:
	match i:
		0:
			Game.cpu_level = (Game.cpu_level + 1) % 3
		1:
			Game.rounds_to_win = 1 + Game.rounds_to_win % 3
		2:
			Game.set_master_volume(fposmod(Game.master_volume + 0.1, 1.05))
		3:
			Game.music_volume = fposmod(Game.music_volume + 0.1, 1.05)
			Audio.duck(1.0)
		4:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		5:
			_close_opts()
			return
	opts.set_items(_opt_items())
