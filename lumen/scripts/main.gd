extends Node
## Cena principal: junta o mundo 3D e as camadas de interface e cuida do cursor do mouse.

var world: World
var hud: Hud
var windows: Windows
var menu: Menu

func _ready() -> void:
	world = World.new()
	world.name = "World"
	add_child(world)
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.bind_world(world)
	windows = Windows.new()
	windows.name = "Windows"
	add_child(windows)
	menu = Menu.new()
	menu.name = "Menu"
	add_child(menu)
	if bool(Save.setting("fullscreen")) and DisplayServer.get_name() != "headless" and not Dev.args.has("windowed"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _process(_delta: float) -> void:
	var want := Input.MOUSE_MODE_VISIBLE
	if Game.phase != Game.Phase.MENU and not Game.paused_ui and DisplayServer.window_is_focused():
		want = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != want and not Dev.bot:
		Input.mouse_mode = want
