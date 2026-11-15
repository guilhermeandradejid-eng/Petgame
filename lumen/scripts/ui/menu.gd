class_name Menu
extends CanvasLayer
## Menu principal: nome, criar sala (hospedar) ou entrar na sala de um amigo pelo IP.

var root: Control
var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var status: Label

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = Ui.theme()
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 p = UV;\n\tvec3 top = vec3(0.16, 0.13, 0.36);\n\tvec3 mid = vec3(0.55, 0.32, 0.62);\n\tvec3 bot = vec3(1.0, 0.72, 0.52);\n\tvec3 c = mix(top, mid, smoothstep(0.0, 0.6, p.y));\n\tc = mix(c, bot, smoothstep(0.55, 1.05, p.y));\n\tfloat s = 0.0;\n\tfor (int i = 0; i < 5; i++) {\n\t\tfloat fi = float(i);\n\t\tfloat y = 0.62 + fi * 0.085 + sin(p.x * (3.0 + fi) + TIME * 0.12 * (fi + 1.0) + fi * 1.7) * 0.03;\n\t\ts = max(s, step(y, p.y) * (0.14 + fi * 0.09));\n\t}\n\tc = mix(c, vec3(0.10, 0.08, 0.22), s);\n\tvec2 g = fract(p * vec2(26.0, 14.0)) - 0.5;\n\tvec2 id = floor(p * vec2(26.0, 14.0));\n\tfloat r = fract(sin(dot(id, vec2(12.9898, 78.233))) * 43758.5453);\n\tfloat tw = smoothstep(0.06, 0.0, length(g + (r - 0.5) * 0.6)) * step(0.82, r) * (0.5 + 0.5 * sin(TIME * (1.0 + r * 3.0) + r * 20.0)) * (1.0 - smoothstep(0.2, 0.6, p.y));\n\tc += vec3(tw);\n\tCOLOR = vec4(c, 1.0);\n}"
	sm.shader = sh
	bg.material = sm
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)
	var t := Ui.title("LÚMEN", 110, Color("fff2c8"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 18)
	v.add_child(t)
	var sub := Ui.label("Ruínas do Entardecer  ·  roguelite cooperativo online", 22, Color("f4efe6"), true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var pc := Ui.panel()
	pc.custom_minimum_size = Vector2(560, 0)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pc)
	var pv := VBoxContainer.new()
	pc.add_child(pv)
	pv.add_child(Ui.label("Seu nome", 17, Ui.MUTED))
	name_edit = LineEdit.new()
	name_edit.text = str(Save.data["name"])
	name_edit.max_length = 16
	pv.add_child(name_edit)
	var host := Ui.button("Criar sala (hospedar)", 26)
	host.custom_minimum_size = Vector2(0, 62)
	host.pressed.connect(_host)
	pv.add_child(host)
	pv.add_child(Ui.label("Entrar na sala de um amigo", 17, Ui.MUTED))
	var row := HBoxContainer.new()
	pv.add_child(row)
	ip_edit = LineEdit.new()
	ip_edit.text = str(Save.data.get("last_ip", "127.0.0.1"))
	ip_edit.placeholder_text = "IP do host"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ip_edit)
	port_edit = LineEdit.new()
	port_edit.text = str(Net.DEFAULT_PORT)
	port_edit.custom_minimum_size = Vector2(110, 0)
	row.add_child(port_edit)
	var join := Ui.button("Entrar", 24)
	join.pressed.connect(_join)
	row.add_child(join)
	status = Ui.label("Até 4 jogadores. O host abre a porta %d (UDP); o jogo tenta fazer isso sozinho via UPnP." % Net.DEFAULT_PORT, 15, Ui.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(520, 0)
	pv.add_child(status)
	var quit := Ui.button("Sair", 20)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(quit)
	Game.phase_changed.connect(_refresh)
	Game.toast.connect(func(text: String, _c: Color) -> void:
		if Game.phase == Game.Phase.MENU:
			status.text = text)
	_refresh()

func _refresh() -> void:
	root.visible = Game.phase == Game.Phase.MENU
	if root.visible:
		Sfx.set_music("hub")

func _store_name() -> void:
	var nm := name_edit.text.strip_edges()
	if nm == "":
		nm = "Viajante"
	Save.data["name"] = nm
	Save.save()

func _host() -> void:
	_store_name()
	Game.host_game(int(port_edit.text) if port_edit.text.is_valid_int() else Net.DEFAULT_PORT)

func _join() -> void:
	_store_name()
	Save.data["last_ip"] = ip_edit.text.strip_edges()
	Save.save()
	status.text = "Conectando a %s..." % ip_edit.text
	var err := Game.join_game(ip_edit.text.strip_edges(), int(port_edit.text) if port_edit.text.is_valid_int() else Net.DEFAULT_PORT)
	if err != OK:
		status.text = "Endereço inválido."
