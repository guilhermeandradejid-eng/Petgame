class_name InputState
extends RefCounted
## Entrada de um jogador por frame, com buffer de botões e direções relativas ao lado da luta.

const BUTTONS := ["a", "b", "c", "dash", "spell", "switch"]
const BUFFER := 7

var held := {}        # botão -> bool
var age := {}         # botão -> frames desde o último aperto (99 = nada)
var dir := Vector2i.ZERO   # -1..1 (x à direita, y para baixo) em coordenadas de tela
var prev_dir := Vector2i.ZERO
var up_age := 99      # frames desde que "cima" foi apertado
var dash_tap := 99


func _init() -> void:
	for b in BUTTONS:
		held[b] = false
		age[b] = 99


func feed(new_dir: Vector2i, buttons: Dictionary, frozen := false) -> void:
	## frozen: durante o hitstop os apertos entram no buffer mas não envelhecem
	prev_dir = dir
	dir = new_dir
	if dir.y < 0 and prev_dir.y >= 0:
		up_age = 0
	elif not frozen:
		up_age = mini(up_age + 1, 99)
	for b in BUTTONS:
		var h: bool = buttons.get(b, false)
		if h and not held[b]:
			age[b] = 0
		elif not frozen:
			age[b] = mini(int(age[b]) + 1, 99)
		held[b] = h


func read_device(p: int, frozen := false) -> void:
	var pre := "p%d_" % (p + 1)
	var d := Vector2i.ZERO
	if Input.is_action_pressed(pre + "left"):
		d.x -= 1
	if Input.is_action_pressed(pre + "right"):
		d.x += 1
	if Input.is_action_pressed(pre + "up"):
		d.y -= 1
	if Input.is_action_pressed(pre + "down"):
		d.y += 1
	var btn := {}
	for b in BUTTONS:
		btn[b] = Input.is_action_pressed(pre + b)
	feed(d, btn, frozen)


func pressed(b: String, window := BUFFER) -> bool:
	return int(age[b]) <= window


func consume(b: String) -> void:
	age[b] = 99


func fwd(facing: int) -> bool:
	return dir.x == facing


func back(facing: int) -> bool:
	return dir.x == -facing


func down() -> bool:
	return dir.y > 0


func up() -> bool:
	return dir.y < 0


func clear() -> void:
	for b in BUTTONS:
		age[b] = 99
