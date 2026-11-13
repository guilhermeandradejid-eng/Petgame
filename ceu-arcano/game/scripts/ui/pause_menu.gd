extends Control
## Pausa: continuar, lista de comandos, reiniciar, trocar personagens e menu principal.

var battle
var menu: MenuList
var cmd_panel: Control
var showing_cmds := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.09, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Game.make_label("PAUSA", 24, Color("ffd66b"), Game.font_title)
	title.position = Vector2(0, 70)
	title.size = Vector2(640, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	menu = MenuList.new()
	menu.position = Vector2(170, 120)
	menu.size = Vector2(300, 160)
	menu.set_items([{"text": "Continuar"}, {"text": "Lista de comandos"}, {"text": "Reiniciar luta"},
		{"text": "Escolher personagens"}, {"text": "Menu principal"}])
	menu.chosen.connect(_on_choose)
	menu.cancelled.connect(_resume)
	add_child(menu)
	cmd_panel = load("res://scripts/ui/command_list.gd").new()
	cmd_panel.visible = false
	add_child(cmd_panel)


func open() -> void:
	menu.sel = 0
	showing_cmds = false
	cmd_panel.visible = false
	menu.visible = true
	menu.active = false
	await get_tree().process_frame
	menu.active = true


func _process(_d: float) -> void:
	if showing_cmds and (Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("p1_b") \
			or Input.is_action_just_pressed("p1_start") or Input.is_action_just_pressed("ui_accept")):
		showing_cmds = false
		cmd_panel.visible = false
		menu.visible = true
		menu.active = true
		Audio.play("ui_back", -4.0)
	elif visible and not showing_cmds and (Input.is_action_just_pressed("p1_start") or Input.is_action_just_pressed("p2_start")) and menu.active:
		_resume()


func _resume() -> void:
	battle.set_paused(false)


func _on_choose(i: int) -> void:
	match i:
		0:
			_resume()
		1:
			showing_cmds = true
			menu.active = false
			menu.visible = false
			cmd_panel.visible = true
		2:
			battle.get_tree().paused = false
			Game.goto("res://scenes/battle.tscn")
		3:
			battle.get_tree().paused = false
			Game.goto("res://scenes/select.tscn")
		4:
			battle.get_tree().paused = false
			Game.goto("res://scenes/title.tscn")
