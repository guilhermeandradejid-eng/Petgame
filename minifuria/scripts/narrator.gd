class_name Narrator
extends Node
## Narrador da corrida: ZECA TURBO (empolgado, voz de estádio) e TIA GRAXA (mecânica sarcástica, pelo rádio).
## Falas em voice/<chave>_<n>.ogg, geradas por tools/build_voice.py; o texto vai para a legenda animada do HUD
## (Hud.caption), com os rostos dos dois mexendo a boca no ritmo da voz.
## Regras:
##   - uma fala por vez; prioridade maior fura a fila (contagem e fim de corrida falam na hora);
##   - cada tipo de fala tem intervalo mínimo (não repete "ultrapassou" a cada carro);
##   - a variação é sorteada sem repetir a última;
##   - algumas falas do Zeca ganham resposta da Tia Graxa pelo rádio;
##   - corrida quieta por muito tempo: o Zeca solta um comentário;
##   - enquanto alguém fala, a música e os efeitos abaixam um pouco.

const COOLDOWN := {"overtake": 8.0, "overtaken": 8.0, "lead": 12.0, "kill": 5.0, "killed": 5.0, "fall": 5.0,
	"air": 10.0, "drift": 12.0, "nitro": 22.0, "lowhp": 30.0, "boss_attack": 12.0, "perfect_start": 5.0}
const IDLE_AFTER := 20.0

var game: Node
var player: AudioStreamPlayer
var enabled := true
var cur_prio := -1
var last_t := {}
var last_n := {}
var pending: Dictionary = {}
var side_key := ""
var quiet_t := 0.0
var _amp: Array = []   # AudioEffectAmplify em Musica e Efeitos (abaixa durante a fala)
var _duck := 0.0
var _gap_t := 0.0


func setup(g: Node) -> void:
	game = g
	if AudioServer.get_bus_index("Narrador") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Narrador")
		AudioServer.set_bus_send(i, "Master")
	player = AudioStreamPlayer.new()
	player.bus = "Narrador"
	add_child(player)
	player.finished.connect(_on_done)
	for nm in ["Musica", "Efeitos"]:
		var bi := AudioServer.get_bus_index(nm)
		if bi < 0:
			continue
		var a := AudioEffectAmplify.new()
		a.volume_db = 0.0
		AudioServer.add_bus_effect(bi, a)
		_amp.append(a)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func talking() -> bool:
	return player.playing


## pede uma fala. prio: 0 enchimento, 1 comum, 2 importante, 3 largada, 5 contagem/fim (fala na hora).
## side: chance de a Tia Graxa responder pelo rádio (se existir "g_" + chave).
## devolve a duração da fala que começou agora (0 se não falou ou ficou na fila)
func say(key: String, prio := 1, chance := 1.0, side := 0.0) -> float:
	if not enabled or not VoiceLines.LINES.has(key) or randf() > chance:
		return 0.0
	if _now() - float(last_t.get(key, -99.0)) < float(COOLDOWN.get(key, 2.0)):
		return 0.0
	if player.playing or _gap_t > 0.0:
		if prio >= 5 or prio > cur_prio + 1:
			side_key = ""
			return _play(key, prio, side)
		elif prio >= 1 and (pending.is_empty() or prio >= int(pending.prio)):
			pending = {"key": key, "prio": prio, "side": side, "t": _now()}
		return 0.0
	return _play(key, prio, side)


func stop() -> void:
	player.stop()
	pending = {}
	side_key = ""
	cur_prio = -1
	if game and game.hud:
		game.hud.caption_hide()


func _play(key: String, prio: int, side: float) -> float:
	var lines: Array = VoiceLines.LINES[key]
	var n := randi() % lines.size()
	if lines.size() > 1 and n == int(last_n.get(key, -1)):
		n = (n + 1 + randi() % (lines.size() - 1)) % lines.size()
	var st := load("res://voice/%s_%d.ogg" % [key, n]) as AudioStream
	if st == null:
		return 0.0
	last_n[key] = n
	last_t[key] = _now()
	cur_prio = prio
	quiet_t = 0.0
	side_key = ("g_" + key) if (side > 0.0 and randf() < side and VoiceLines.LINES.has("g_" + key)) else ""
	player.stream = st
	player.play()
	var ln: Array = lines[n]
	if game and game.auto_test:
		print("NARR t=%.1f %s: %s" % [float(game.race_t), key, String(ln[1])])
	if game and game.hud:
		game.hud.caption(String(ln[0]), String(ln[1]), float(ln[2]))
	return float(ln[2])


func _on_done() -> void:
	cur_prio = -1
	_gap_t = 0.35
	if side_key != "":
		var k := side_key
		side_key = ""
		await get_tree().create_timer(0.3).timeout
		if not player.playing:
			_play(k, 1, 0.0)
			return
	if not pending.is_empty() and _now() - float(pending.t) < 3.0:
		var p := pending
		pending = {}
		_play(String(p.key), int(p.prio), float(p.side))
		return
	pending = {}


func _process(dt: float) -> void:
	_gap_t = maxf(0.0, _gap_t - dt)
	# abaixa música (-6 dB) e efeitos (-3 dB) enquanto alguém fala, com volta suave
	_duck = move_toward(_duck, 1.0 if player.playing else 0.0, dt * (6.0 if player.playing else 2.0))
	for i in _amp.size():
		(_amp[i] as AudioEffectAmplify).volume_db = -_duck * (6.0 if i == 0 else 3.0)
	if not enabled or game == null:
		return
	if game.mode == "race" and not player.playing:
		quiet_t += dt
		if quiet_t > IDLE_AFTER:
			quiet_t = 0.0
			say("idle", 0, 1.0, 0.35)
