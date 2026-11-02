extends Node
## Sound effects and music.
## Recorded one-shots come from Kenney's CC0 starter kit; everything else is
## synthesized at startup into AudioStreamWAV buffers (tiny additive/FM synth),
## and each level gets its own procedurally composed music loop.

const RATE := 22050
const FILES := {
	"jump": "res://assets/audio/jump.ogg",
	"land": "res://assets/audio/land.ogg",
	"fall": "res://assets/audio/fall.ogg",
	"break": "res://assets/audio/break.ogg",
	"coin": "res://assets/audio/coin.ogg",
}

var streams := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_cache := {}
var _combo := 0
var _combo_time := 0.0
var _task := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	for k in FILES:
		streams[k] = load(FILES[k])
	_build_synth()


func _process(delta: float) -> void:
	_combo_time -= delta
	if _combo_time <= 0.0:
		_combo = 0


## Play a sound with random pitch variation (avoids the "machine gun" effect).
func play(name: String, pitch := 1.0, vol_db := 0.0, variation := 0.08) -> void:
	var s = streams.get(name)
	if s == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.pitch_scale = maxf(0.05, pitch * randf_range(1.0 - variation, 1.0 + variation))
			p.volume_db = vol_db + linear_to_db(Game.settings["sfx"])
			p.play()
			return


## Collectible chime: consecutive pickups climb a pentatonic scale.
func pickup() -> void:
	const SCALE := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
	var semis: int = SCALE[mini(_combo, SCALE.size() - 1)]
	play("chime", pow(2.0, semis / 12.0), -4.0, 0.0)
	_combo += 1
	_combo_time = 1.2


# ------------------------------------------------------------------- music
func play_music(seed_value: int) -> void:
	if _music_cache.has(seed_value):
		_start_music(_music_cache[seed_value])
		return
	var task := func():
		var st := _compose(seed_value)
		_music_cache[seed_value] = st
		call_deferred("_start_music", st)
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = WorkerThreadPool.add_task(task)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func stop_music() -> void:
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, 0.6)
	tw.tween_callback(_music.stop)


func _start_music(st: AudioStreamWAV) -> void:
	_music.stream = st
	_music.volume_db = -40.0
	_music.play()
	var target := linear_to_db(maxf(Game.settings["music"], 0.001)) - 8.0
	create_tween().tween_property(_music, "volume_db", target, 1.5)


func _compose(seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bpm: float = [96.0, 104.0, 88.0, 110.0][seed_value % 4]
	var beat: float = 60.0 / bpm
	var root: int = [60, 62, 57, 65][seed_value % 4]  # MIDI
	# Chord progressions (scale degrees as semitone offsets of triads).
	var progs := [
		[[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]],  # I vi IV V
		[[0, 4, 7], [5, 9, 12], [9, 12, 16], [7, 11, 14]],  # I IV vi V
		[[0, 4, 7], [7, 11, 14], [9, 12, 16], [5, 9, 12]],  # I V vi IV
	]
	var prog: Array = progs[seed_value % progs.size()]
	var bars := 8
	var total := int(bars * 4 * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var penta := [0, 2, 4, 7, 9, 12, 14, 16]
	var melody := []
	for i in bars * 8:
		melody.append(penta[rng.randi() % penta.size()] if rng.randf() < 0.55 else -1)
	for bar in bars:
		var chord: Array = prog[bar % 4]
		var bar_start: float = bar * 4 * beat
		# pad: soft detuned triangles
		for n in chord:
			_add_tone(buf, bar_start, 4 * beat, _midi(root + n - 12), 0.035, "pad")
		# bass on beats 1 and 3
		_add_tone(buf, bar_start, beat * 1.8, _midi(root + chord[0] - 24), 0.16, "bass")
		_add_tone(buf, bar_start + 2 * beat, beat * 1.8, _midi(root + chord[0] - 24 + (7 if bar % 2 else 0)), 0.13, "bass")
		# arpeggio in eighths
		for e in 8:
			var note: int = chord[[0, 1, 2, 1, 0, 2, 1, 2][e]]
			_add_tone(buf, bar_start + e * beat * 0.5, beat * 0.5, _midi(root + note + 12), 0.05, "pluck")
		# melody
		for e in 8:
			var m: int = melody[bar * 8 + e]
			if m >= 0 and (e % 2 == 0 or rng.randf() < 0.3):
				_add_tone(buf, bar_start + e * beat * 0.5, beat * 0.9, _midi(root + m + 12), 0.06, "bell")
		# soft shaker
		for e in 8:
			_add_noise(buf, bar_start + e * beat * 0.5, 0.05, 0.03 if e % 2 else 0.018)
	return _to_wav(buf, true)


func _midi(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)


func _add_tone(buf: PackedFloat32Array, start: float, dur: float, freq: float, amp: float, kind: String) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var total := buf.size()
	for i in n:
		var t := float(i) / RATE
		var env := 1.0
		var s := 0.0
		match kind:
			"pad":
				env = minf(t / 0.4, 1.0) * minf((dur - t) / 0.5, 1.0)
				var ph := fmod(t * freq, 1.0)
				var ph2 := fmod(t * freq * 1.006, 1.0)
				s = (absf(ph * 4.0 - 2.0) - 1.0) + (absf(ph2 * 4.0 - 2.0) - 1.0)
			"bass":
				env = minf(t / 0.01, 1.0) * exp(-t * 3.0)
				s = sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t)
			"pluck":
				env = minf(t / 0.005, 1.0) * exp(-t * 9.0)
				s = sin(TAU * freq * t + 0.8 * sin(TAU * freq * 2.0 * t) * exp(-t * 6.0))
			"bell":
				env = minf(t / 0.005, 1.0) * exp(-t * 4.0)
				s = sin(TAU * freq * t + 1.5 * sin(TAU * freq * 3.5 * t) * exp(-t * 5.0))
		var idx := (i0 + i) % total
		buf[idx] += s * env * amp


func _add_noise(buf: PackedFloat32Array, start: float, dur: float, amp: float) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := randf() * 2.0 - 1.0
		var hp := w - prev  # crude high-pass for a hissy shaker
		prev = w
		var idx := (i0 + i) % buf.size()
		buf[idx] += hp * amp * exp(-t * 60.0)


func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := minf(1.0, 0.9 / peak)
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = bytes
	if loop:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = buf.size()
	return st


# ------------------------------------------------------------- synth sfx
func _synth(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / RATE
		buf[i] = fn.call(t, t / dur)
	return _to_wav(buf, false)


func _build_synth() -> void:
	streams["chime"] = _synth(0.35, func(t, k): return (sin(TAU * 1320.0 * t) + 0.5 * sin(TAU * 1980.0 * t)) * exp(-t * 12.0) * 0.6)
	streams["pop"] = _synth(0.12, func(t, k): return sin(TAU * (900.0 - 600.0 * k) * t) * (1.0 - k) * 0.8)
	streams["boing"] = _synth(0.45, func(t, k): return sin(TAU * (180.0 + 420.0 * k + 40.0 * sin(t * 60.0)) * t) * (1.0 - k) * 0.8)
	streams["whoosh"] = _synth(0.35, func(t, k): return (randf() * 2.0 - 1.0) * sin(PI * k) * 0.35 * (0.5 + 0.5 * sin(TAU * (8.0 + 30.0 * k) * t)))
	streams["thud"] = _synth(0.4, func(t, k): return (sin(TAU * (90.0 - 50.0 * k) * t) * 0.9 + (randf() - 0.5) * 0.6 * exp(-t * 25.0)) * exp(-t * 7.0))
	streams["tick"] = _synth(0.05, func(t, k): return sin(TAU * 2200.0 * t) * (1.0 - k) * 0.5)
	streams["tock"] = _synth(0.06, func(t, k): return sin(TAU * 1500.0 * t) * (1.0 - k) * 0.5)
	streams["click"] = _synth(0.12, func(t, k): return (sin(TAU * 520.0 * t) + sin(TAU * 780.0 * t)) * exp(-t * 30.0) * 0.5)
	streams["unlock"] = _synth(0.5, func(t, k):
		var f := 660.0 if t < 0.12 else 990.0
		return sin(TAU * f * t) * exp(-fmod(t, 0.12 if t < 0.12 else 1.0) * 6.0) * 0.5)
	streams["portal"] = _synth(0.8, func(t, k): return (sin(TAU * (300.0 + 500.0 * k) * t + 2.0 * sin(TAU * 7.0 * t)) * 0.4 + sin(TAU * (450.0 + 750.0 * k) * t) * 0.25) * sin(PI * k))
	streams["fanfare"] = _synth(1.4, func(t, k):
		var notes := [523.25, 659.25, 783.99, 1046.5]
		var idx := mini(int(t / 0.14), 3)
		var lt: float = t - idx * 0.14
		var f: float = notes[idx]
		return (sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.0 * t)) * exp(-lt * (2.0 if idx == 3 else 6.0)) * 0.45)
	streams["hurt"] = _synth(0.3, func(t, k): return signf(sin(TAU * (500.0 - 300.0 * k) * t)) * (1.0 - k) * 0.25)
	streams["bubble"] = _synth(0.25, func(t, k): return sin(TAU * (300.0 + 900.0 * k * k) * t) * sin(PI * k) * 0.6)
	streams["dash"] = _synth(0.22, func(t, k): return ((randf() * 2.0 - 1.0) * 0.4 + sin(TAU * (200.0 + 800.0 * k) * t) * 0.3) * (1.0 - k))
	streams["zap"] = _synth(0.4, func(t, k): return sin(TAU * (1200.0 - 900.0 * k) * t + 3.0 * sin(TAU * 40.0 * t)) * (1.0 - k) * 0.4)
	streams["sparkle"] = _synth(0.6, func(t, k):
		var f := 1568.0 * pow(2.0, floor(t / 0.06) * 2.0 / 12.0)
		return sin(TAU * f * t) * exp(-fmod(t, 0.06) * 30.0) * (1.0 - k) * 0.35)
	streams["step"] = _synth(0.06, func(t, k): return (randf() - 0.5) * exp(-t * 80.0) * 0.5)
	streams["swish"] = _synth(0.2, func(t, k): return (randf() * 2.0 - 1.0) * sin(PI * k) * 0.25)
