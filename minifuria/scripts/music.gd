class_name Music
extends Node
## Trilha sonora.
## 1) Se existir um arquivo de música do usuário, toca ele em loop:
##    res://music/pista<N>.(ogg|mp3|wav)  ->  só na pista N (1..9)
##    res://music/<tema>.(ogg|mp3|wav)    ->  park, city, desert, snow, port, volcano, toy, sky, swamp
##    res://music/menu.(ogg|mp3|wav)      ->  menu
##    res://music/corrida1..8.(ogg|mp3|wav) -> sorteada nas pistas sem música própria
## 2) Senão, compõe e sintetiza um rock instrumental ORIGINAL (bateria, baixo, guitarra distorcida e solo),
##    diferente para cada pista. Uma delas usa "Na Gruta do Rei da Montanha" (Edvard Grieg, 1875 —
##    melodia em domínio público) arranjada como rock.
## A síntese é feita aos poucos (fatias por quadro) para não travar o jogo.

const SR := 22050
const BUDGET := 60000   # amostras-voz por quadro

var player: AudioStreamPlayer
var _events: Array = []
var _ev_i := 0
var _buf := PackedFloat32Array()
var _bytes := PackedByteArray()
var _conv_i := -1
var _peak := 0.0
var _rng := RandomNumberGenerator.new()
var _want_key := ""
var _cache := {}
var _cur_key := ""
var volume_db := -9.0
var now_text := ""   # "♪ faixa — artista" da música de arquivo que está tocando (crédito na tela)

## Créditos das faixas incluídas (todas CC0 / domínio público — uso comercial livre; crédito por cortesia)
const CREDITS := {
	"pista1": "Hit n Smash — FreePD.com",
	"pista2": "SUPER METAL — Loyalty Freak Music",
	"pista3": "50 Over The Speed Limit — HoliznaCC0",
	"pista4": "Snowboard Rock — Loyalty Freak Music",
	"pista5": "Punk — HoliznaCC0",
	"pista6": "GIGA METAL — Loyalty Freak Music",
	"pista7": "Nitro — Monplaisir",
	"pista8": "MAXI METAL — Loyalty Freak Music",
	"pista9": "Ghost Surf Rock — Loyalty Freak Music",
	"menu": "Rock n' Roll — HoliznaCC0",
}


func _ready() -> void:
	_ensure()


func _ensure() -> void:
	if player:
		return
	player = AudioStreamPlayer.new()
	player.volume_db = -60.0
	add_child(player)


func set_paused(p: bool) -> void:
	_ensure()
	player.stream_paused = p


func play_menu() -> void:
	_ensure()
	if _try_file(["menu"], "menu"):
		return
	_start_song("menu", 99)


func play_track(idx: int, theme_key: String) -> void:
	_ensure()
	now_text = ""
	var names := ["pista%d" % (idx + 1), theme_key]
	if _try_file(names, "t%d" % idx):
		return
	# músicas genéricas do usuário (corrida1..8), sorteadas por pista
	var generic: Array = []
	for k in range(1, 9):
		for ext in ["ogg", "mp3", "wav"]:
			var p := "res://music/corrida%d.%s" % [k, ext]
			if ResourceLoader.exists(p):
				generic.append(p)
	if generic.size() > 0:
		_play_stream(load(generic[idx % generic.size()]), "g%d" % idx)
		return
	_start_song("t%d" % idx, idx)


func _try_file(names: Array, key: String) -> bool:
	for nm in names:
		for ext in ["ogg", "mp3", "wav"]:
			var p := "res://music/%s.%s" % [nm, ext]
			if ResourceLoader.exists(p):
				now_text = String(CREDITS.get(nm, ""))
				_play_stream(load(p), key)
				return true
	return false


func _play_stream(st: AudioStream, key: String) -> void:
	if key == _cur_key and player.playing:
		return
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	elif st is AudioStreamWAV and (st as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(st as AudioStreamWAV).loop_end = int((st as AudioStreamWAV).get_length() * (st as AudioStreamWAV).mix_rate)
	_cur_key = key
	_want_key = ""
	player.stop()
	player.stream = st
	player.volume_db = -40.0
	player.play()
	var tw := create_tween()
	tw.tween_property(player, "volume_db", volume_db, 1.2)


# ------------------------------------------------------------------ composição
func _start_song(key: String, seed_: int) -> void:
	if key == _cur_key and player.playing:
		return
	if _cache.has(key):
		_play_stream(_cache[key], key)
		return
	if _want_key == key:
		return
	_want_key = key
	# baixa a música atual enquanto a nova é "gravada"
	if player.playing:
		var tw := create_tween()
		tw.tween_property(player, "volume_db", -30.0, 0.8)
	_rng.seed = 7919 + seed_ * 104729
	_compose(seed_)
	_ev_i = 0
	_conv_i = -1
	_peak = 0.0


func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


func _compose(seed_: int) -> void:
	_events.clear()
	var menu := seed_ == 99
	var bpm := 108.0 if menu else 138.0 + float(seed_ % 4) * 6.0
	var beat := 60.0 / bpm
	var step := beat / 4.0                      # semicolcheia
	var bars := 16   # parte A (8 compassos, só a levada) + parte B (8 compassos, com solo)
	var total := bars * 16 * step
	_buf = PackedFloat32Array()
	_buf.resize(int(total * SR))
	var mountain := seed_ == 5                  # Boca do Vulcão: Grieg em rock
	# tônica (E, A, D, B...) e progressão de power chords (em semitons acima da tônica)
	var roots := [40, 45, 38, 43, 40, 45, 38, 47]   # E2, A2, D2, G2, E2, A2, D2, B2
	var key_root: int = 47 if mountain else roots[seed_ % roots.size()]
	var progs := [[0, 0, 3, 3, 5, 5, 3, 7], [0, 5, 0, 5, 3, 5, 7, 5], [0, 0, 10, 10, 8, 8, 10, 7],
		[0, 3, 5, 3, 0, 3, 7, 5], [0, 0, 5, 5, 7, 7, 5, 3], [0, 8, 10, 0, 0, 8, 10, 7]]
	var prog: Array = progs[seed_ % progs.size()]
	if mountain:
		prog = [0, 2, 0, 3, 0, 2, 0, 3]
	# levada da guitarra (16 semicolcheias): 1 = palhetada abafada, 2 = acorde aberto (acento)
	var grooves := ["2010101020101010", "2011011020110110", "2000101020001010", "2010201020102010"]
	var groove: String = grooves[(seed_ * 7 + 1) % grooves.size()]
	if menu:
		groove = "2000000020000000"
	for bar in bars:
		var t0 := bar * 16 * step
		var pb: int = int(prog[bar % 8]) if (bar < 8 or mountain) else int(prog[(bar + 2) % 8])
		var r: int = key_root + pb
		# bateria
		for s in 16:
			var t := t0 + s * step
			var fill := (bar == 7 or bar == bars - 1) and s >= 12
			if s == 0 or s == 8 or (s == 10 and seed_ % 2 == 0) or (s == 6 and seed_ % 3 == 1):
				_events.append([t, "kick"])
			if (s == 4 or s == 12) and not fill:
				_events.append([t, "snare", 1.0])
			if fill:
				_events.append([t, "snare", 0.6 + 0.1 * (s - 12)])
			if s % 2 == 0 and not menu:
				_events.append([t, "hat", s % 4 == 2])
			elif menu and s % 4 == 0:
				_events.append([t, "hat", false])
		if bar == 0 or bar == 8:
			_events.append([t0, "crash"])
		# baixo em colcheias seguindo a tônica (oitava no contratempo)
		for s in range(0, 16, 2):
			var oct := 12 if (s % 8 == 6) else 0
			_events.append([t0 + s * step, "bass", _midi(r + oct), step * 1.8])
		# guitarra: power chord (tônica + quinta + oitava) com distorção
		for s in 16:
			var g := groove[s]
			if g == "0":
				continue
			var dur := step * (3.5 if g == "2" else 0.9)
			if menu:
				dur = step * 7.5
			_events.append([t0 + s * step, "gtr", _midi(r + 12), dur, g == "1"])
	# solo / melodia
	if mountain:
		# "Na Gruta do Rei da Montanha" (Grieg, domínio público), em Si menor, colcheias
		var B := 59
		var phrase := [[0, 1], [2, 1], [3, 1], [5, 1], [7, 1], [3, 1], [7, 2],
			[6, 1], [2, 1], [6, 2], [5, 1], [1, 1], [5, 2],
			[0, 1], [2, 1], [3, 1], [5, 1], [7, 1], [3, 1], [7, 1], [12, 1],
			[10, 1], [7, 1], [3, 1], [7, 1], [10, 4]]
		var t := 0.0
		for rep_ in 4:
			for nt in phrase:
				var d: float = float(nt[1]) * step * 2.0
				_events.append([t, "lead", _midi(B + (12 if rep_ >= 2 else 0) + int(nt[0])), d * 0.92])
				t += d
	elif not menu:
		# motivo original na escala pentatônica menor, nos compassos 5–8
		var penta := [0, 3, 5, 7, 10, 12, 15]
		var deg := 2
		var t := 8 * 16 * step
		var end := total - step * 2.0
		while t < end:
			deg = clampi(deg + _rng.randi_range(-2, 2), 0, penta.size() - 1)
			var d := step * float([2, 2, 4, 1, 2, 6][_rng.randi() % 6])
			if _rng.randf() < 0.85:
				_events.append([t, "lead", _midi(key_root + 24 + int(penta[deg])), d * 0.9])
			t += d
	_events.sort_custom(func(a, b): return a[0] < b[0])


func _add(i0: int, v: float) -> void:
	var n := _buf.size()
	var k := i0 % n
	_buf[k] += v
	var a := absf(_buf[k])
	if a > _peak:
		_peak = a


func _render(ev: Array) -> int:
	var i0 := int(float(ev[0]) * SR)
	var kind: String = ev[1]
	match kind:
		"kick":
			var n := int(0.24 * SR)
			var ph := 0.0
			for i in n:
				var t := float(i) / SR
				ph += (48.0 + 120.0 * exp(-t * 30.0)) / SR
				var v := sin(TAU * ph) * exp(-t * 11.0) * 0.95
				if i < 60:
					v += (_rng.randf() * 2.0 - 1.0) * 0.25 * (1.0 - i / 60.0)
				_add(i0 + i, v)
			return n
		"snare":
			var n := int(0.2 * SR)
			var amp: float = ev[2]
			var lp := 0.0
			for i in n:
				var t := float(i) / SR
				var nz := _rng.randf() * 2.0 - 1.0
				lp += (nz - lp) * 0.55
				var v := lp * exp(-t * 20.0) * 0.55 + sin(TAU * 190.0 * t) * exp(-t * 32.0) * 0.4
				_add(i0 + i, v * amp)
			return n
		"hat", "crash":
			var crash: bool = kind == "crash"
			var open: bool = crash or bool(ev[2])
			var n := int((1.2 if crash else (0.12 if open else 0.04)) * SR)
			var prev := 0.0
			for i in n:
				var t := float(i) / SR
				var nz := _rng.randf() * 2.0 - 1.0
				var hp := nz - prev
				prev = nz
				_add(i0 + i, hp * exp(-t * (3.0 if crash else (25.0 if open else 90.0))) * (0.22 if crash else 0.13))
			return n
		"bass":
			var f: float = ev[2]
			var n := int(float(ev[3]) * SR)
			var ph := 0.0
			var lp := 0.0
			for i in n:
				ph = fmod(ph + f / SR, 1.0)
				var saw := ph * 2.0 - 1.0
				lp += (saw - lp) * 0.12
				var env := minf(1.0, i / 80.0) * (1.0 - float(i) / n) * 0.9 + 0.1 * (1.0 - float(i) / n)
				_add(i0 + i, lp * env * 0.55)
			return n
		"gtr":
			var f: float = ev[2]
			var n := int(float(ev[3]) * SR)
			var palm: bool = ev[4]
			var p1 := 0.0
			var p2 := 0.0
			var p3 := 0.0
			var lp := 0.0
			for i in n:
				var t := float(i) / SR
				p1 = fmod(p1 + f * 1.003 / SR, 1.0)
				p2 = fmod(p2 + f * 1.4983 / SR, 1.0)
				p3 = fmod(p3 + f * 0.5 / SR, 1.0)
				var x := (p1 + p2 + p3) * (2.0 / 3.0) - 1.0
				var dr := tanh(x * 5.0)
				lp += (dr - lp) * (0.25 if palm else 0.55)
				var env := minf(1.0, i / 40.0) * (exp(-t * 16.0) if palm else (0.65 + 0.35 * exp(-t * 3.0)))
				env *= minf(1.0, float(n - i) / 200.0)
				_add(i0 + i, lp * env * 0.26)
			return n * 3
		"lead":
			var f: float = ev[2]
			var n := int(float(ev[3]) * SR)
			var ph := 0.0
			var lp := 0.0
			for i in n:
				var t := float(i) / SR
				var vib := 1.0 + 0.006 * sin(TAU * 5.5 * t) * minf(1.0, t * 4.0)
				ph = fmod(ph + f * vib / SR, 1.0)
				var sq := 1.0 if ph < 0.5 else -1.0
				lp += (tanh(sq * 1.6) - lp) * 0.3
				var env := minf(1.0, i / 120.0) * minf(1.0, float(n - i) / 300.0)
				_add(i0 + i, lp * env * 0.2)
			return n
	return 1


func _process(_dt: float) -> void:
	if _want_key == "":
		return
	var budget := BUDGET
	if _ev_i < _events.size():
		while budget > 0 and _ev_i < _events.size():
			budget -= _render(_events[_ev_i])
			_ev_i += 1
		return
	# normaliza e converte para 16 bits (também em fatias)
	var n := _buf.size()
	if _conv_i < 0:
		_bytes = PackedByteArray()
		_bytes.resize(n * 2)
		_conv_i = 0
	var g := 0.82 / maxf(_peak, 0.001)
	var end := mini(n, _conv_i + 120000)
	for i in range(_conv_i, end):
		_bytes.encode_s16(i * 2, int(clampf(_buf[i] * g, -1.0, 1.0) * 32767.0))
	_conv_i = end
	if _conv_i < n:
		return
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = SR
	st.stereo = false
	st.data = _bytes
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	var key := _want_key
	_cache[key] = st
	_want_key = ""
	_buf = PackedFloat32Array()
	_play_stream(st, key)
