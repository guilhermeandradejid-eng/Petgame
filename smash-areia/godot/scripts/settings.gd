class_name Settings
## Opções do jogador, salvas em user://settings.cfg:
##  - gráficos: qualidade, pós-processamento (bloom, raios de sol, cor, vinheta...),
##    antisserrilhado, escala de resolução, limite de FPS, tela cheia e contador de FPS;
##  - controles: teclas do J1 e do J2 e botões do controle, remapeáveis;
##  - toque: lado dos botões (canhoto), tamanho e transparência.

const PATH := "user://settings.cfg"

const QUALITY_NAMES := ["BAIXA", "MÉDIA", "ALTA"]
const FPS_CAPS := [30, 60, 0]          # 0 = sem limite
const SCALES := [0.6, 0.75, 0.85, 1.0]

## Ações remapeáveis (na ordem da tela de controles).
## "key" = ação do J1 no teclado, "p2" = ação do J2 no teclado.
const ACTIONS := [
	{"id": "drive", "name": "FORTE", "key": "shot_drive", "p2": "p2_drive"},
	{"id": "lob", "name": "LOB", "key": "shot_lob", "p2": "p2_lob"},
	{"id": "drop", "name": "CURTA", "key": "shot_drop", "p2": "p2_drop"},
	{"id": "smash", "name": "SMASH", "key": "shot_smash", "p2": "p2_smash"},
	{"id": "defense", "name": "DEFESA", "key": "shot_defense", "p2": "p2_defense"},
	{"id": "super", "name": "ESPECIAL", "key": "super", "p2": "p2_super"},
	{"id": "dive", "name": "PEIXINHO", "key": "dive", "p2": "p2_dive"},
	{"id": "jump", "name": "PULO", "key": "jump", "p2": ""},
]
const MOVE_ACTIONS := {
	"move_up": "p2_up", "move_down": "p2_down", "move_left": "p2_left", "move_right": "p2_right",
}

const DEFAULT_KEYS := {
	"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S,
	"shot_drive": KEY_J, "shot_lob": KEY_K, "shot_drop": KEY_L, "shot_smash": KEY_I,
	"shot_defense": KEY_O, "super": KEY_U, "jump": KEY_SPACE, "dive": KEY_SHIFT,
	"p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_up": KEY_UP, "p2_down": KEY_DOWN,
	"p2_drive": KEY_N, "p2_lob": KEY_M, "p2_drop": KEY_COMMA, "p2_smash": KEY_PERIOD,
	"p2_defense": KEY_SLASH, "p2_super": KEY_B, "p2_dive": KEY_V,
}

## Gatilhos analógicos viram "botões" virtuais no mapa do controle
const PAD_LT := 100
const PAD_RT := 101
const PAD_NONE := -1
const DEFAULT_PAD := {
	"drive": JOY_BUTTON_A, "lob": JOY_BUTTON_X, "drop": JOY_BUTTON_B, "smash": JOY_BUTTON_Y,
	"defense": JOY_BUTTON_LEFT_SHOULDER, "super": JOY_BUTTON_RIGHT_SHOULDER, "dive": PAD_LT,
	"jump": PAD_NONE,
}
## Atalhos extras que continuam valendo enquanto o botão não for usado por outra ação
## (gatilhos que no Android chegam como botão 15/16, paddles e L3).
const PAD_ALT := {
	"defense": [PAD_RT, JOY_BUTTON_PADDLE1, JOY_BUTTON_RIGHT_STICK],
	"dive": [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_MISC1],
}

# ---------------------------------------------------------------- valores

static var quality := 2
static var postfx := true
static var bloom := false        # desligado por padrão (pode ligar em OPÇÕES)
static var sun_rays := true
static var color_grade := true
static var vignette := true
static var grain := false
static var impact_fx := true       # aberração cromática, zoom e flash nas pancadas
static var msaa := 2               # 0, 2, 4
static var scale_index := 3
static var fps_cap := 1
static var show_fps := false
static var fullscreen := false
static var vsync := true
static var shake := true
static var split_swap := false     # tela dividida invertida: J1 à direita, J2 à esquerda

static var keys := {}              # ação -> physical keycode
static var pad := {}               # id da ação -> botão (ou PAD_LT/PAD_RT/PAD_NONE)

static var touch_left := false     # canhoto: botões à esquerda, analógico à direita
static var touch_size := 1         # 0 pequeno, 1 médio, 2 grande
static var touch_alpha := 1        # 0 discreto, 1 normal, 2 forte

static var loaded := false


static func load_settings() -> void:
	if loaded:
		return
	loaded = true
	keys = DEFAULT_KEYS.duplicate()
	pad = DEFAULT_PAD.duplicate()
	# padrão por plataforma: celular começa na qualidade média, sem nitidez extra
	if OS.has_feature("mobile"):
		quality = 1
		msaa = 2
		scale_index = 2
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	quality = clampi(int(cf.get_value("gfx", "quality", quality)), 0, 2)
	postfx = bool(cf.get_value("gfx", "postfx", postfx))
	bloom = bool(cf.get_value("gfx", "bloom2", bloom))   # chave nova: bloom volta desligado
	sun_rays = bool(cf.get_value("gfx", "sun_rays", sun_rays))
	color_grade = bool(cf.get_value("gfx", "color_grade", color_grade))
	vignette = bool(cf.get_value("gfx", "vignette", vignette))
	grain = bool(cf.get_value("gfx", "grain", grain))
	impact_fx = bool(cf.get_value("gfx", "impact_fx", impact_fx))
	msaa = int(cf.get_value("gfx", "msaa", msaa))
	scale_index = clampi(int(cf.get_value("gfx", "scale", scale_index)), 0, SCALES.size() - 1)
	fps_cap = clampi(int(cf.get_value("gfx", "fps_cap", fps_cap)), 0, FPS_CAPS.size() - 1)
	show_fps = bool(cf.get_value("gfx", "show_fps", show_fps))
	fullscreen = bool(cf.get_value("gfx", "fullscreen", fullscreen))
	vsync = bool(cf.get_value("gfx", "vsync", vsync))
	shake = bool(cf.get_value("gfx", "shake", shake))
	split_swap = bool(cf.get_value("gfx", "split_swap", split_swap))
	for a in DEFAULT_KEYS:
		keys[a] = int(cf.get_value("keys", a, keys[a]))
	for a in DEFAULT_PAD:
		pad[a] = int(cf.get_value("pad", a, pad[a]))
	touch_left = bool(cf.get_value("touch", "left", touch_left))
	touch_size = clampi(int(cf.get_value("touch", "size", touch_size)), 0, 2)
	touch_alpha = clampi(int(cf.get_value("touch", "alpha", touch_alpha)), 0, 2)


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("gfx", "quality", quality)
	cf.set_value("gfx", "postfx", postfx)
	cf.set_value("gfx", "bloom2", bloom)
	cf.set_value("gfx", "sun_rays", sun_rays)
	cf.set_value("gfx", "color_grade", color_grade)
	cf.set_value("gfx", "vignette", vignette)
	cf.set_value("gfx", "grain", grain)
	cf.set_value("gfx", "impact_fx", impact_fx)
	cf.set_value("gfx", "msaa", msaa)
	cf.set_value("gfx", "scale", scale_index)
	cf.set_value("gfx", "fps_cap", fps_cap)
	cf.set_value("gfx", "show_fps", show_fps)
	cf.set_value("gfx", "fullscreen", fullscreen)
	cf.set_value("gfx", "vsync", vsync)
	cf.set_value("gfx", "shake", shake)
	cf.set_value("gfx", "split_swap", split_swap)
	for a in keys:
		cf.set_value("keys", a, keys[a])
	for a in pad:
		cf.set_value("pad", a, pad[a])
	cf.set_value("touch", "left", touch_left)
	cf.set_value("touch", "size", touch_size)
	cf.set_value("touch", "alpha", touch_alpha)
	cf.save(PATH)


## Predefinições de qualidade (as opções individuais continuam editáveis depois)
static func apply_preset(q: int) -> void:
	quality = q
	match q:
		0:
			msaa = 0
			scale_index = 1
			sun_rays = false
			grain = false
		1:
			msaa = 2
			scale_index = 2
			sun_rays = false
		2:
			msaa = 4
			scale_index = 3
			sun_rays = true


## Opções liga/desliga pelo nome (usado pela tela de OPÇÕES)
static func get_flag(id: String) -> bool:
	match id:
		"postfx": return postfx
		"bloom": return bloom
		"sun_rays": return sun_rays
		"color_grade": return color_grade
		"vignette": return vignette
		"grain": return grain
		"impact_fx": return impact_fx
		"show_fps": return show_fps
		"fullscreen": return fullscreen
		"vsync": return vsync
		"shake": return shake
		"split_swap": return split_swap
	return false


static func set_flag(id: String, v: bool) -> void:
	match id:
		"postfx": postfx = v
		"bloom": bloom = v
		"sun_rays": sun_rays = v
		"color_grade": color_grade = v
		"vignette": vignette = v
		"grain": grain = v
		"impact_fx": impact_fx = v
		"show_fps": show_fps = v
		"fullscreen": fullscreen = v
		"vsync": vsync = v
		"shake": shake = v
		"split_swap": split_swap = v


static func render_scale() -> float:
	return SCALES[scale_index]


# ---------------------------------------------------------------- teclado

## Reescreve as teclas das ações no InputMap (a pausa e os menus ficam fixos)
static func apply_keys() -> void:
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				InputMap.action_erase_event(a, e)
		var k := int(keys[a])
		if k == 0:
			continue
		var ev := InputEventKey.new()
		ev.physical_keycode = k as Key
		InputMap.action_add_event(a, ev)


## Liga uma tecla a uma ação; se outra ação usava a tecla, as duas trocam.
static func bind_key(action: String, keycode: int) -> void:
	var old := int(keys.get(action, 0))
	for a in keys:
		if a != action and int(keys[a]) == keycode:
			keys[a] = old
	keys[action] = keycode
	apply_keys()


static func key_name(action: String) -> String:
	var k := int(keys.get(action, 0))
	if k == 0:
		return "—"
	var s := OS.get_keycode_string(k as Key).to_upper()
	match s:
		"SPACE": return "ESPAÇO"
		"ESCAPE": return "ESC"
		"COMMA": return ","
		"PERIOD": return "."
		"SLASH": return "/"
		"LEFT": return "←"
		"RIGHT": return "→"
		"UP": return "↑"
		"DOWN": return "↓"
	return s


# ---------------------------------------------------------------- controle

static func bind_pad(action: String, button: int) -> void:
	var old := int(pad.get(action, PAD_NONE))
	for a in pad:
		if a != action and int(pad[a]) == button:
			pad[a] = old
	pad[action] = button


## O botão está apertado no controle? Considera o mapa e os atalhos extras.
static func pad_down(device: int, action: String) -> bool:
	if _pad_raw(device, int(pad.get(action, PAD_NONE))):
		return true
	for b in PAD_ALT.get(action, []):
		if not pad.values().has(b) and _pad_raw(device, b):
			return true
	return false


static func _pad_raw(device: int, b: int) -> bool:
	match b:
		PAD_NONE:
			return false
		PAD_LT:
			return Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > 0.5 \
				or Input.is_joy_button_pressed(device, 15 as JoyButton)
		PAD_RT:
			return Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.5 \
				or Input.is_joy_button_pressed(device, 16 as JoyButton)
	return Input.is_joy_button_pressed(device, b as JoyButton)


static func pad_button_name(b: int) -> String:
	match b:
		PAD_NONE: return "—"
		PAD_LT: return "LT"
		PAD_RT: return "RT"
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_BACK: return "SELECT"
		JOY_BUTTON_GUIDE: return "GUIA"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_MISC1: return "L2"
		JOY_BUTTON_PADDLE1: return "R2"
		JOY_BUTTON_PADDLE2: return "P2"
		JOY_BUTTON_PADDLE3: return "P3"
		JOY_BUTTON_PADDLE4: return "P4"
		JOY_BUTTON_TOUCHPAD: return "TOUCHPAD"
	return "BOTÃO %d" % b


static func pad_name(action: String) -> String:
	return pad_button_name(int(pad.get(action, PAD_NONE)))


static func reset_controls() -> void:
	keys = DEFAULT_KEYS.duplicate()
	pad = DEFAULT_PAD.duplicate()
	apply_keys()
