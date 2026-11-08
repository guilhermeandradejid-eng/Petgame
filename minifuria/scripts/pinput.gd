class_name PInput
extends RefCounted
## Entrada por dispositivo (multijogador local): cada jogador lê só o seu teclado ou o seu controle.
##   "solo"  -> tudo junto (teclado inteiro + qualquer controle + toque): jogo de 1 pessoa
##   "kbA"   -> WASD dirige · E tiro · Q mina/óleo · Shift esq. nitro · F especial · Espaço freio
##   "kbB"   -> setas dirigem · . (ponto) tiro · , (vírgula) mina/óleo · / nitro · L especial · Enter freio
##   "joyN"  -> controle N (layout Xbox; PlayStation e Switch são mapeados pelo SDL do Godot):
##              analógico esq. dirige · A / RT acelera · B / LT freio-ré · X tiro · Y mina/óleo
##              RB nitro (mobilidade) · LB especial · Start pausa · Back/Select volta à pista

const DEADZONE := 0.22

const KB := {
	"kbA": {"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S, "fire": KEY_E, "drop": KEY_Q, "nitro": KEY_SHIFT, "special": KEY_F, "brake": KEY_SPACE, "join": KEY_SPACE},
	"kbB": {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN, "fire": KEY_PERIOD, "drop": KEY_COMMA, "nitro": KEY_SLASH, "special": KEY_L, "brake": KEY_ENTER, "join": KEY_ENTER},
}


static func label(dev: String) -> String:
	if dev == "solo":
		return "TECLADO/CONTROLE"
	if dev == "kbA":
		return "TECLADO (WASD)"
	if dev == "kbB":
		return "TECLADO (SETAS)"
	if dev.begins_with("joy"):
		var id := int(dev.substr(3))
		var nm := Input.get_joy_name(id)
		return "CONTROLE %d%s" % [id + 1, (" · " + nm.to_upper().left(18)) if nm != "" else ""]
	return dev.to_upper()


static func help(dev: String) -> String:
	if dev == "kbA":
		return "WASD dirige · E tiro · Q mina · Shift nitro · F especial · Espaço freio"
	if dev == "kbB":
		return "Setas dirigem · . tiro · , mina · / nitro · L especial · Enter freio"
	if dev.begins_with("joy"):
		return "Analógico dirige · A/RT acelera · B/LT freio · X tiro · Y mina · RB nitro · LB especial"
	return ""


## devolve o dispositivo que apertou "entrar" neste evento (ou "")
static func join_device(ev: InputEvent) -> String:
	if ev is InputEventJoypadButton and ev.pressed and (ev.button_index == JOY_BUTTON_A or ev.button_index == JOY_BUTTON_START):
		return "joy%d" % ev.device
	if ev is InputEventKey and ev.pressed and not ev.echo:
		for d in KB:
			if ev.physical_keycode == KB[d].join:
				return d
	return ""


static func _key(dev: String, k: String) -> bool:
	return Input.is_physical_key_pressed(KB[dev][k])


static func pause_pressed(dev: String) -> bool:
	if dev.begins_with("joy"):
		return Input.is_joy_button_pressed(int(dev.substr(3)), JOY_BUTTON_START)
	return false


static func reset_pressed(dev: String) -> bool:
	if dev.begins_with("joy"):
		return Input.is_joy_button_pressed(int(dev.substr(3)), JOY_BUTTON_BACK)
	return false


## preenche ctrl (o mesmo dicionário do carro). rr/ff = direita/frente da tela no mundo.
static func read(dev: String, c: Dictionary, screen_mode: bool, rr: Vector3, ff: Vector3) -> void:
	c.dir = null
	c.steer = 0.0
	c.throttle = 0.0
	c.brake = 0.0
	c.drift = false
	var sx := 0.0
	var sy := 0.0
	var accel := false
	if KB.has(dev):
		sx = float(_key(dev, "right")) - float(_key(dev, "left"))
		sy = float(_key(dev, "up")) - float(_key(dev, "down"))
		c.brake = 1.0 if _key(dev, "brake") else 0.0
		c.fire = _key(dev, "fire")
		c.drop = _key(dev, "drop")
		c.nitro = _key(dev, "nitro")
		c.special = _key(dev, "special")
		if screen_mode:
			if absf(sx) + absf(sy) > 0.1:
				c.dir = (rr * sx + ff * sy).normalized()
				c.dir_mag = 1.0
				c.throttle = 1.0
		else:
			c.steer = -sx
			c.throttle = maxf(sy, 0.0)
			c.brake = maxf(c.brake, maxf(-sy, 0.0))
	elif dev.begins_with("joy"):
		var id := int(dev.substr(3))
		sx = Input.get_joy_axis(id, JOY_AXIS_LEFT_X)
		sy = -Input.get_joy_axis(id, JOY_AXIS_LEFT_Y)
		# direcional (d-pad) também dirige
		sx += float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_LEFT))
		sy += float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_UP)) - float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_DOWN))
		var rt := Input.get_joy_axis(id, JOY_AXIS_TRIGGER_RIGHT)
		var lt := Input.get_joy_axis(id, JOY_AXIS_TRIGGER_LEFT)
		accel = Input.is_joy_button_pressed(id, JOY_BUTTON_A) or rt > 0.3
		var brk := Input.is_joy_button_pressed(id, JOY_BUTTON_B) or lt > 0.3
		c.brake = maxf(lt, 1.0 if brk else 0.0)
		c.fire = Input.is_joy_button_pressed(id, JOY_BUTTON_X)
		c.drop = Input.is_joy_button_pressed(id, JOY_BUTTON_Y)
		c.nitro = Input.is_joy_button_pressed(id, JOY_BUTTON_RIGHT_SHOULDER)
		c.special = Input.is_joy_button_pressed(id, JOY_BUTTON_LEFT_SHOULDER)
		var mag := Vector2(sx, sy).length()
		if screen_mode:
			if mag > DEADZONE:
				var v := Vector2(sx, sy) / maxf(mag, 1.0)
				c.dir = (rr * v.x + ff * v.y).normalized()
				c.dir_mag = minf(1.0, (mag - DEADZONE) / 0.5)
				c.throttle = 1.0
			elif accel:
				c.throttle = 1.0
		else:
			if absf(sx) > 0.12:
				c.steer = clampf(-sx * 1.2, -1.0, 1.0)
			c.throttle = maxf(rt, 1.0 if accel else 0.0)
	if c.brake > 0.05:
		c.throttle = 0.0
