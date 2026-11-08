class_name Voice
extends Node
## Chat de voz por proximidade.
## Microfone (AudioStreamMicrophone num barramento mudo com AudioEffectCapture) -> mono 12 kHz ->
## IMA ADPCM 4 bits (pacotes de 40 ms, ~6 KB/s, cada pacote decodifica sozinho) -> servidor de salas ->
## cada pessoa da sala toca num AudioStreamGenerator, com volume e lado (esquerda/direita) pela distância
## entre o carro de quem fala e o seu. No lobby (sem carros) todo mundo se ouve normalmente.
## Modos: "off" | "open" (fala quando a voz passa do limiar) | "ptt" (aperte V ou o L3 do controle para falar)

const RATE := 12000
const FRAME := 480                 # 40 ms
const KIND := 2                    # tipo do pacote binário no servidor de salas
const NEAR := 12.0                 # até aqui volume cheio
const FAR := 70.0                  # daqui para longe não se ouve
const VAD := 0.010                 # limiar de voz (RMS) no modo aberto

const STEP := [7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97,
	107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963,
	1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484,
	7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767]
const IDX := [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]

var game: Node
var net: Net
var mode := "off"
var mic: AudioStreamPlayer
var capture: AudioEffectCapture
var _acc := 0.0
var _sum := 0.0
var _cnt := 0
var _pcm := PackedFloat32Array()
var _seq := 0
var _hold := 0.0
var _pred := 0
var _index := 0
var talking := false
var level := 0.0
var peers := {}     # id -> {"pl", "pb", "q": PackedVector2Array, "started", "last", "g", "pan"}
var volume_db := 0.0


func setup(g: Node, n: Net) -> void:
	game = g
	net = n
	if not InputMap.has_action("talk"):
		InputMap.add_action("talk")
		var k := InputEventKey.new()
		k.physical_keycode = KEY_V
		InputMap.action_add_event("talk", k)
		var j := InputEventJoypadButton.new()
		j.device = -1
		j.button_index = JOY_BUTTON_LEFT_STICK
		InputMap.action_add_event("talk", j)
	net.bin.connect(_on_bin)


func set_mode(m: String) -> void:
	mode = m
	if mode == "off":
		if mic:
			mic.stop()
		talking = false
		return
	if OS.get_name() == "Android":
		OS.request_permissions()
	if mic == null:
		var bi := AudioServer.get_bus_index("VozMic")
		if bi < 0:
			AudioServer.add_bus()
			bi = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bi, "VozMic")
			capture = AudioEffectCapture.new()
			capture.buffer_length = 0.5
			AudioServer.add_bus_effect(bi, capture)
			AudioServer.set_bus_mute(bi, true)   # o próprio microfone não sai na caixa de som
		mic = AudioStreamPlayer.new()
		mic.stream = AudioStreamMicrophone.new()
		mic.bus = "VozMic"
		add_child(mic)
	if not mic.playing:
		mic.play()


func label() -> String:
	return {"off": "VOZ: DESLIGADA", "open": "VOZ: MICROFONE ABERTO", "ptt": "VOZ: APERTE V / L3 PARA FALAR"}[mode]


func cycle() -> void:
	set_mode({"off": "open", "open": "ptt", "ptt": "off"}[mode])


# ------------------------------------------------------------------ captura e envio
var _vt := 0.0
var _vt_n := 0


func _process(dt: float) -> void:
	_play_out()
	if "--voicetest" in OS.get_cmdline_user_args() and net.in_room():
		# teste sem microfone: "fala" um tom de 300 Hz, pacotes de 40 ms
		_vt += dt
		while _vt >= FRAME / float(RATE):
			_vt -= FRAME / float(RATE)
			var fr := PackedFloat32Array()
			fr.resize(FRAME)
			for i in FRAME:
				fr[i] = 0.3 * sin(TAU * 300.0 * float(_vt_n * FRAME + i) / RATE)
			_vt_n += 1
			talking = true
			net.send_bin(KIND, _encode(fr))
	if "--voicelog" in OS.get_cmdline_user_args() and Engine.get_process_frames() % 120 == 0:
		for id in peers:
			var p: Dictionary = peers[id]
			print("VOICERX de=%d recebido_ha=%.2fs fila=%d ganho=%.2f lado=%.2f tocando=%s" % [id, Time.get_ticks_msec() / 1000.0 - float(p.last), (p.q as PackedVector2Array).size(), float(p.g), float(p.pan), (p.pl as AudioStreamPlayer).playing])
	if mode == "off" or capture == null or not net.in_room():
		talking = false
		if capture:
			capture.clear_buffer()
		return
	var n := capture.get_frames_available()
	if n <= 0:
		return
	var frames := capture.get_buffer(n)
	var ratio := AudioServer.get_mix_rate() / float(RATE)
	# mono + reamostragem por média (filtro de caixa: tira o chiado acima de 6 kHz)
	for f in frames:
		_sum += (f.x + f.y) * 0.5
		_cnt += 1
		_acc += 1.0
		if _acc >= ratio:
			_acc -= ratio
			_pcm.append(_sum / _cnt)
			_sum = 0.0
			_cnt = 0
	while _pcm.size() >= FRAME:
		var fr := _pcm.slice(0, FRAME)
		_pcm = _pcm.slice(FRAME)
		var rms := 0.0
		for v in fr:
			rms += v * v
		rms = sqrt(rms / FRAME)
		level = lerpf(level, rms, 0.3)
		var want := false
		if mode == "open":
			if rms > VAD:
				_hold = 0.35
			want = _hold > 0.0
			_hold -= FRAME / float(RATE)
		else:
			want = Input.is_action_pressed("talk")
		talking = want
		if want:
			net.send_bin(KIND, _encode(fr))


func _encode(fr: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(5 + FRAME / 2)
	out.encode_u16(0, _seq)
	_seq = (_seq + 1) & 0xffff
	out.encode_s16(2, _pred)
	out[4] = _index
	var pred := _pred
	var index := _index
	for i in FRAME:
		var s := clampi(int(fr[i] * 1.6 * 32767.0), -32768, 32767)
		var step: int = STEP[index]
		var diff := s - pred
		var code := 0
		if diff < 0:
			code = 8
			diff = -diff
		var dq := step >> 3
		if diff >= step:
			code |= 4
			diff -= step
			dq += step
		if diff >= (step >> 1):
			code |= 2
			diff -= step >> 1
			dq += step >> 1
		if diff >= (step >> 2):
			code |= 1
			dq += step >> 2
		pred = clampi(pred - dq if code & 8 else pred + dq, -32768, 32767)
		index = clampi(index + IDX[code], 0, 88)
		var bi := 5 + (i >> 1)
		if i & 1:
			out[bi] |= code << 4
		else:
			out[bi] = code
	_pred = pred
	_index = index
	return out


static func decode(data: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if data.size() < 6:
		return out
	var pred := data.decode_s16(2)
	var index := clampi(data[4], 0, 88)
	var n := (data.size() - 5) * 2
	out.resize(n)
	for i in n:
		var b := data[5 + (i >> 1)]
		var code := (b >> 4) & 15 if i & 1 else b & 15
		var step: int = STEP[index]
		var dq := step >> 3
		if code & 4:
			dq += step
		if code & 2:
			dq += step >> 1
		if code & 1:
			dq += step >> 2
		pred = clampi(pred - dq if code & 8 else pred + dq, -32768, 32767)
		index = clampi(index + IDX[code], 0, 88)
		out[i] = pred / 32768.0
	return out


# ------------------------------------------------------------------ recepção e reprodução
func _on_bin(kind: int, from: int, data: PackedByteArray) -> void:
	if kind != KIND:
		return
	var p: Dictionary = peers.get(from, {})
	if p.is_empty():
		var pl := AudioStreamPlayer.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = 0.2
		pl.stream = gen
		pl.bus = "Voz"
		pl.volume_db = volume_db
		add_child(pl)
		pl.play()
		p = {"pl": pl, "pb": pl.get_stream_playback(), "q": PackedVector2Array(), "started": false, "last": 0.0, "g": 1.0, "pan": 0.0}
		peers[from] = p
	p.last = Time.get_ticks_msec() / 1000.0
	var pcm := decode(data)
	var g: float = p.g
	var pan: float = p.pan
	var gl := g * sqrt(clampf(1.0 - pan, 0.0, 2.0) * 0.5) * 1.41
	var gr := g * sqrt(clampf(1.0 + pan, 0.0, 2.0) * 0.5) * 1.41
	var q: PackedVector2Array = p.q
	for v in pcm:
		q.append(Vector2(v * gl, v * gr))
	# fila longa demais (atraso acumulado): descarta o começo
	if q.size() > RATE * 0.3:
		q = q.slice(q.size() - int(RATE * 0.1))
	p.q = q


func _play_out() -> void:
	for id in peers:
		var p: Dictionary = peers[id]
		var q: PackedVector2Array = p.q
		# espera ~80 ms de áudio antes de começar (absorve a variação da rede)
		if not p.started:
			if q.size() < FRAME * 2:
				continue
			p.started = true
		var pb: AudioStreamGeneratorPlayback = p.pb
		var room := pb.get_frames_available()
		var n := mini(room, q.size())
		if n > 0:
			pb.push_buffer(q.slice(0, n))
			p.q = q.slice(n)
		if (p.q as PackedVector2Array).is_empty():
			p.started = false


func is_talking(id: int) -> bool:
	if id == net.my_id:
		return talking
	return peers.has(id) and Time.get_ticks_msec() / 1000.0 - float(peers[id].last) < 0.3


## ganho e lado de cada pessoa pela distância entre os carros (chamado a cada quadro durante a corrida)
func set_spatial(id: int, gain: float, pan: float) -> void:
	if peers.has(id):
		peers[id].g = gain
		peers[id].pan = pan


func drop_peer(id: int) -> void:
	if peers.has(id):
		(peers[id].pl as Node).queue_free()
		peers.erase(id)
