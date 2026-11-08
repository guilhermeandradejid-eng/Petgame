class_name Sfx
extends Node
## Áudio 100% sintetizado: motor contínuo (AudioStreamGenerator) com trocas de marcha, pneu, nitro, vento
## e efeitos curtos gerados em buffers PCM na inicialização.

const RATE := 22050.0
var gen: AudioStreamGeneratorPlayback
var player: AudioStreamPlayer
var muted := false
var ph1 := 0.0
var ph2 := 0.0
var lp := 0.0
var lp_n := 0.0
var lp_b := 0.0
var bp1 := 0.0
var bp2 := 0.0
# alvos (setados pelo jogo)
var t_freq := 60.0
var t_vol := 0.0
var t_cut := 0.2
var t_tire := 0.0
var t_nitro := 0.0
var t_wind := 0.0
var t_scrape := 0.0
var scr := 0.0
var lp_s := 0.0
var ring_ph := 0.0
var freq := 60.0
var vol := 0.0
var cut := 0.2
var tire := 0.0
var nit := 0.0
var wind := 0.0
var shots := {}
var pool: Array = []
var pool_i := 0


func _ready() -> void:
	player = AudioStreamPlayer.new()
	var st := AudioStreamGenerator.new()
	st.mix_rate = RATE
	st.buffer_length = 0.12
	player.stream = st
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.volume_db = -4.0
	player.bus = "Efeitos"
	add_child(player)
	player.play()
	gen = player.get_stream_playback()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Efeitos"
		add_child(p)
		pool.append(p)
	_build_shots()


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)


## speed01 0..1+, throttle 0..1, slip 0..1
func set_scrape(level: float) -> void:
	t_scrape = clampf(level, 0.0, 1.0)


func drive(speed01: float, throttle: float, slip: float, nitro: bool, slowmo: bool, active: bool) -> void:
	var gears := 5.0
	var g := minf(gears - 1.0, floorf(speed01 * gears * 0.999))
	var frac := speed01 * gears - g
	var rpm := 0.25 + frac * 0.75 * (0.6 + throttle * 0.4) + g * 0.04
	t_freq = (48.0 + rpm * 120.0 + (25.0 if nitro else 0.0)) * (0.55 if slowmo else 1.0)
	t_cut = clampf(0.12 + rpm * 0.35 + throttle * 0.1, 0.05, 0.8)
	t_vol = (0.22 + throttle * 0.2) if active else 0.0
	t_tire = clampf(slip, 0.0, 1.0) * 0.5 if active else 0.0
	t_nitro = 0.45 if (active and nitro) else 0.0
	t_wind = maxf(0.0, speed01 - 0.3) * 0.25 if active else 0.0


func _process(_dt: float) -> void:
	if gen == null:
		return
	var n := gen.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	var k := 0.004
	for i in n:
		freq += (t_freq - freq) * k
		vol += (t_vol - vol) * k
		cut += (t_cut - cut) * k
		tire += (t_tire - tire) * k * 2.0
		nit += (t_nitro - nit) * k
		wind += (t_wind - wind) * k
		scr += (t_scrape - scr) * k * 3.0
		ring_ph = fmod(ring_ph + (1870.0 + randf() * 300.0) / RATE, 1.0)
		ph1 = fmod(ph1 + freq / RATE, 1.0)
		ph2 = fmod(ph2 + freq * 0.5 / RATE, 1.0)
		var saw := ph1 * 2.0 - 1.0
		var sq := 1.0 if ph2 < 0.5 else -1.0
		var e := saw * 0.6 + sq * 0.35
		lp += (e - lp) * cut
		var nz := randf() * 2.0 - 1.0
		# pneu: ruído em "passa-banda" (diferença de dois passa-baixas)
		bp1 += (nz - bp1) * 0.45
		bp2 += (bp1 - bp2) * 0.12
		var tire_s := (bp1 - bp2) * tire * 1.6
		lp_n += (nz - lp_n) * (0.05 + nit * 0.15)
		lp_b += (nz - lp_b) * 0.6
		# raspar metal no muro: ruído agudo + um 'ring' metálico
		lp_s += (nz - lp_s) * 0.35
		var grind := ((nz - lp_s) * 1.4 + sin(ring_ph * TAU) * 0.35 * randf()) * scr
		var s := lp * vol + tire_s + lp_n * nit * 1.4 + (nz - lp_b) * wind * 0.5 + grind
		s = clampf(s, -1.0, 1.0)
		buf[i] = Vector2(s, s)
	gen.push_buffer(buf)


# ------------------------------------------------------------------ efeitos curtos
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = false
	w.data = data
	return w


func _synth(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var st := {"lp": 0.0, "lp2": 0.0, "ph": 0.0}
	for i in n:
		out[i] = f.call(float(i) / RATE, float(i) / n, st)
	return _wav(out)


func _build_shots() -> void:
	# raio elétrico: estalo + zumbido serrilhado descendo
	shots["zap"] = _synth(0.35, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.ph += lerpf(1400.0, 300.0, u) / RATE
		var saw := 2.0 * fmod(st.ph, 1.0) - 1.0
		var crack := nz * exp(-t * 40.0)
		return (saw * 0.45 * (1.0 if randf() > 0.15 else -0.4) + crack * 0.9) * exp(-t * 7.0))
	# lança-chamas: rajada de ar com ronco grave
	shots["flame"] = _synth(0.3, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * 0.12
		st.ph += 70.0 / RATE
		return (st.lp * 1.6 + sin(st.ph * TAU) * 0.25) * sin(u * PI))
	shots["crash"] = _synth(1.1, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * lerpf(0.6, 0.03, u)
		st.ph += lerpf(90.0, 35.0, u) / RATE
		var thump := sin(st.ph * TAU) * exp(-t * 6.0)
		return (st.lp * 1.3 * exp(-t * 3.0) + thump * 0.9 + nz * 0.25 * exp(-t * 18.0)))
	shots["bump"] = _synth(0.25, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * 0.2
		st.ph += lerpf(120.0, 60.0, u) / RATE
		return (st.lp * 0.9 + sin(st.ph * TAU) * 0.8) * exp(-t * 16.0))
	shots["scrape"] = _synth(0.15, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * 0.7
		return (nz - st.lp) * 0.6 * (1.0 - u))
	shots["glass"] = _synth(0.6, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * 0.5
		var ting := sin(t * TAU * (2400.0 + 900.0 * sin(t * 40.0))) * 0.25
		return ((nz - st.lp) * 0.8 + ting) * exp(-t * 7.0))
	shots["metal"] = _synth(0.5, func(t, u, st):
		return (sin(t * TAU * 310.0) * 0.4 + sin(t * TAU * 467.0) * 0.3 + sin(t * TAU * 893.0) * 0.2) * exp(-t * 9.0))
	shots["whoosh"] = _synth(0.45, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * lerpf(0.05, 0.6, u)
		return st.lp * sin(u * PI) * 1.6)
	shots["nitro"] = _synth(0.7, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * lerpf(0.02, 0.5, minf(1.0, u * 2.0))
		st.ph += lerpf(160.0, 520.0, u) / RATE
		return (st.lp * 1.4 + sin(st.ph * TAU) * 0.25) * (1.0 - u))
	shots["land"] = _synth(0.3, func(t, u, st):
		st.ph += lerpf(80.0, 40.0, u) / RATE
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * 0.08
		return (sin(st.ph * TAU) * 0.9 + st.lp) * exp(-t * 10.0))
	shots["smash"] = _synth(0.2, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * 0.35
		return (st.lp + sin(t * TAU * lerpf(300.0, 150.0, u)) * 0.3) * exp(-t * 18.0))
	shots["gun"] = _synth(0.12, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * 0.55
		st.ph += lerpf(180.0, 60.0, u) / RATE
		var crack := nz * exp(-t * 120.0) * 0.8
		return (st.lp * 1.1 * exp(-t * 38.0) + sin(st.ph * TAU) * 0.9 * exp(-t * 30.0) + crack))
	shots["tink"] = _synth(0.18, func(t, u, st):
		var ring := sin(t * TAU * 2350.0) * 0.5 + sin(t * TAU * 3720.0) * 0.3 + sin(t * TAU * 5130.0) * 0.15
		var nz := randf() * 2.0 - 1.0
		return (ring * exp(-t * 28.0) + nz * exp(-t * 200.0) * 0.6) * 0.7)
	shots["rocket"] = _synth(0.7, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * lerpf(0.4, 0.05, u)
		st.ph += lerpf(300.0, 900.0, u) / RATE
		return (st.lp * 1.3 + sin(st.ph * TAU) * 0.15) * (1.0 - u) * minf(1.0, t * 30.0))
	shots["boom"] = _synth(0.9, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * lerpf(0.5, 0.02, u)
		st.ph += lerpf(70.0, 30.0, u) / RATE
		return (st.lp * 1.4 * exp(-t * 3.5) + sin(st.ph * TAU) * exp(-t * 5.0) * 1.0))
	shots["drop"] = _synth(0.25, func(t, u, st): return sin(t * TAU * lerpf(500.0, 200.0, u)) * 0.4 * (1.0 - u))
	shots["splat"] = _synth(0.35, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * 0.08
		return st.lp * 2.0 * exp(-t * 8.0))
	shots["pickup"] = _synth(0.3, func(t, u, st):
		var f := 660.0 if t < 0.07 else (880.0 if t < 0.14 else 1320.0)
		return (2.0 * absf(2.0 * fmod(t * f, 1.0) - 1.0) - 1.0) * 0.3 * (1.0 - u))
	shots["splash"] = _synth(0.8, func(t, u, st):
		var nz := randf() * 2.0 - 1.0
		st.lp += (nz - st.lp) * lerpf(0.4, 0.05, u)
		return st.lp * 1.5 * exp(-t * 3.0))
	shots["beep"] = _synth(0.2, func(t, u, st): return (1.0 if fmod(t * 440.0, 1.0) < 0.5 else -1.0) * 0.3 * (1.0 - u))
	shots["go"] = _synth(0.5, func(t, u, st): return (1.0 if fmod(t * 880.0, 1.0) < 0.5 else -1.0) * 0.3 * (1.0 - u))
	shots["coin"] = _synth(0.35, func(t, u, st):
		var f := 988.0 if t < 0.08 else 1318.0
		return (1.0 if fmod(t * f, 1.0) < 0.5 else -1.0) * 0.18 * (1.0 - u))
	shots["fanfare"] = _synth(0.7, func(t, u, st):
		var notes := [659.0, 784.0, 988.0, 1318.0]
		var f: float = notes[mini(3, int(t / 0.12))]
		return (2.0 * absf(2.0 * fmod(t * f, 1.0) - 1.0) - 1.0) * 0.25 * (1.0 - u * 0.7))


func play(name_: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not shots.has(name_):
		return
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = shots[name_]
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()
