class_name VoiceChat
extends Node
## Chat de voz das salas online, de graça e sem servidor: o microfone é capturado
## no bus "Mic" (AudioEffectCapture), reduzido para 16 kHz mono, comprimido em
## μ-law (8 bits por amostra, ~16 KB/s) e mandado em pacotes de 40 ms pelo canal
## não confiável do WebRTC (o anfitrião repassa para os outros convidados).
## Cada pessoa que fala ganha um AudioStreamGenerator próprio.
##
## Modos: ABERTO (fala quando a voz passa do limiar), APERTAR PARA FALAR
## (segura T ou o SELECT do controle) e MUDO.

enum Mode { OPEN, PUSH, MUTED }
const MODE_NAMES := ["MICROFONE ABERTO", "APERTAR PARA FALAR (T)", "MICROFONE MUDO"]
const RATE := 16000
const FRAME := 640              # 40 ms a 16 kHz
const VAD_LEVEL := 0.018
const HANGOVER := 0.35

var online: Node
var mode := Mode.OPEN
var volume := 1.0               # volume das vozes dos outros
var running := false
var mic: AudioStreamPlayer
var capture: AudioEffectCapture
var bus_idx := -1
var src_rate := 48000.0
var acc := PackedFloat32Array()     # amostras já em 16 kHz esperando virar pacote
var phase := 0.0                    # posição fracionária da reamostragem
var talk_hang := 0.0
var talking := false
var level := 0.0
var players := {}                   # rpc id -> {"player", "playback"}
var speaking := {}                  # rpc id -> último instante em que chegou voz
var t := 0.0


func _init(o: Node) -> void:
	online = o
	name = "Voice"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cf := ConfigFile.new()
	if cf.load("user://online.cfg") == OK:
		mode = clampi(int(cf.get_value("voice", "mode", mode)), 0, 2)
		volume = clampf(float(cf.get_value("voice", "volume", volume)), 0.0, 2.0)


func save() -> void:
	var cf := ConfigFile.new()
	cf.load("user://online.cfg")
	cf.set_value("voice", "mode", mode)
	cf.set_value("voice", "volume", volume)
	cf.save("user://online.cfg")


func cycle_mode() -> void:
	mode = ((mode + 1) % 3) as Mode
	save()


func start() -> void:
	if running:
		return
	running = true
	src_rate = AudioServer.get_mix_rate()
	bus_idx = AudioServer.get_bus_index("Mic")
	if bus_idx < 0:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, "Mic")
		capture = AudioEffectCapture.new()
		capture.buffer_length = 0.5
		AudioServer.add_bus_effect(bus_idx, capture)
		AudioServer.set_bus_mute(bus_idx, true)   # não toca o próprio microfone
	else:
		capture = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectCapture
	if mic == null:
		mic = AudioStreamPlayer.new()
		mic.stream = AudioStreamMicrophone.new()
		mic.bus = "Mic"
		add_child(mic)
	mic.play()
	capture.clear_buffer()
	acc.clear()


func stop() -> void:
	running = false
	if mic:
		mic.stop()
	for id in players.keys():
		remove_peer(id)
	speaking.clear()


func remove_peer(id: int) -> void:
	if players.has(id):
		(players[id]["player"] as Node).queue_free()
		players.erase(id)
	speaking.erase(id)


func is_speaking(id: int) -> bool:
	return t - float(speaking.get(id, -10.0)) < 0.3


func _wants_send() -> bool:
	match mode:
		Mode.MUTED:
			return false
		Mode.PUSH:
			if Input.is_physical_key_pressed(KEY_T):
				return true
			for d in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(d, JOY_BUTTON_BACK):
					return true
			return false
	return talking


func _process(dt: float) -> void:
	t += dt
	if not running or capture == null:
		return
	var n := capture.get_frames_available()
	if n <= 0:
		return
	var buf := capture.get_buffer(n)
	# reamostra para 16 kHz (média simples entre as amostras de origem)
	var step := src_rate / float(RATE)
	var peak := 0.0
	while phase < float(buf.size()):
		var i0 := int(phase)
		var i1 := mini(int(phase + step), buf.size())
		var s := 0.0
		var c := 0
		for k in range(i0, maxi(i1, i0 + 1)):
			var f: Vector2 = buf[mini(k, buf.size() - 1)]
			s += (f.x + f.y) * 0.5
			c += 1
		var v := s / float(c)
		acc.append(v)
		peak = maxf(peak, absf(v))
		phase += step
	phase -= float(buf.size())
	level = lerpf(level, peak, 0.3)
	# detector de voz com "rabicho" para não cortar o fim das palavras
	if peak > VAD_LEVEL:
		talk_hang = HANGOVER
	else:
		talk_hang -= dt
	talking = talk_hang > 0.0
	var send := _wants_send()
	if send:
		speaking[online.my_id()] = t
	while acc.size() >= FRAME:
		var frame := acc.slice(0, FRAME)
		acc = acc.slice(FRAME)
		if send:
			online.send_voice(_encode(frame))


# ---------------------------------------------------------------- μ-law

static func _mulaw_enc(x: float) -> int:
	var s := clampf(x, -1.0, 1.0)
	var sign := 0x80 if s < 0.0 else 0
	var m := log(1.0 + 255.0 * absf(s)) / log(256.0)
	return sign | int(clampf(m * 127.0, 0.0, 127.0))


static func _mulaw_dec(b: int) -> float:
	var m := float(b & 0x7f) / 127.0
	var v := (pow(256.0, m) - 1.0) / 255.0
	return -v if (b & 0x80) != 0 else v


func _encode(frame: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(frame.size())
	for i in frame.size():
		out[i] = _mulaw_enc(frame[i] * 1.4)   # leve ganho no microfone
	return out


func receive(from: int, data: PackedByteArray) -> void:
	if not running or data.size() == 0 or data.size() > 4000:
		return
	speaking[from] = t
	if not players.has(from):
		var p := AudioStreamPlayer.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = 0.4
		p.stream = gen
		p.bus = "Master"
		add_child(p)
		p.play()
		players[from] = {"player": p, "playback": p.get_stream_playback()}
	var pl: AudioStreamPlayer = players[from]["player"]
	pl.volume_db = linear_to_db(maxf(volume, 0.001))
	var pb := players[from]["playback"] as AudioStreamGeneratorPlayback
	if pb == null:
		return
	if pb.get_frames_available() < data.size():
		pb.clear_buffer()   # atrasou demais: descarta e recomeça (menos eco de atraso)
	var frames := PackedVector2Array()
	frames.resize(data.size())
	for i in data.size():
		var v := _mulaw_dec(data[i])
		frames[i] = Vector2(v, v)
	pb.push_buffer(frames)
