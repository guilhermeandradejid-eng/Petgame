extends Node
## Audio todo sintetizado em tempo de carga (sem arquivos): efeitos por receita de
## osciladores + ruido com envelope, e trilhas geradas por um sequenciador minimo.

const RATE := 22050

# receita: lista de camadas. w = onda, f = [hz inicial, hz final], t = duracao,
# a = ataque (s), p = potencia da queda, v = volume, lp = passa-baixa (0..1, menor = mais abafado), d = atraso
const SOUNDS := {
	"swing": [{"w": "noise", "f": [1, 1], "t": 0.16, "a": 0.03, "p": 1.6, "v": 0.5, "lp": 0.35, "lp2": 0.08}],
	"swing_heavy": [{"w": "noise", "f": [1, 1], "t": 0.26, "a": 0.05, "p": 1.4, "v": 0.6, "lp": 0.22, "lp2": 0.05},
		{"w": "sine", "f": [160, 70], "t": 0.2, "a": 0.02, "p": 2.0, "v": 0.25}],
	"hit": [{"w": "sine", "f": [210, 60], "t": 0.11, "a": 0.002, "p": 2.2, "v": 0.8}, {"w": "noise", "f": [1, 1], "t": 0.05, "a": 0.001, "p": 3.0, "v": 0.4, "lp": 0.6}],
	"hit_crit": [{"w": "sine", "f": [240, 70], "t": 0.13, "a": 0.002, "p": 2.0, "v": 0.85}, {"w": "noise", "f": [1, 1], "t": 0.06, "a": 0.001, "p": 3.0, "v": 0.45, "lp": 0.7},
		{"w": "tri", "f": [1318, 1976], "t": 0.16, "a": 0.004, "p": 2.5, "v": 0.3}],
	"slam": [{"w": "sine", "f": [120, 38], "t": 0.4, "a": 0.004, "p": 2.0, "v": 1.0}, {"w": "noise", "f": [1, 1], "t": 0.3, "a": 0.004, "p": 2.6, "v": 0.5, "lp": 0.14}],
	"explode": [{"w": "noise", "f": [1, 1], "t": 0.55, "a": 0.004, "p": 2.4, "v": 0.8, "lp": 0.3, "lp2": 0.04}, {"w": "sine", "f": [90, 32], "t": 0.5, "a": 0.004, "p": 1.8, "v": 0.8}],
	"explode_big": [{"w": "noise", "f": [1, 1], "t": 1.1, "a": 0.006, "p": 2.2, "v": 0.9, "lp": 0.35, "lp2": 0.03}, {"w": "sine", "f": [75, 26], "t": 1.0, "a": 0.004, "p": 1.6, "v": 1.0}],
	"arrow": [{"w": "noise", "f": [1, 1], "t": 0.09, "a": 0.003, "p": 2.0, "v": 0.4, "lp": 0.8, "hp": 0.6}, {"w": "sine", "f": [900, 260], "t": 0.1, "a": 0.002, "p": 2.0, "v": 0.25}],
	"bow_draw": [{"w": "saw", "f": [80, 130], "t": 0.16, "a": 0.03, "p": 1.0, "v": 0.12, "lp": 0.2}],
	"cast": [{"w": "sine", "f": [520, 1150], "t": 0.2, "a": 0.01, "p": 1.8, "v": 0.4}, {"w": "tri", "f": [1040, 2300], "t": 0.16, "a": 0.01, "p": 2.2, "v": 0.15}],
	"cast_big": [{"w": "sine", "f": [220, 660], "t": 0.6, "a": 0.2, "p": 1.2, "v": 0.4}, {"w": "tri", "f": [330, 990], "t": 0.6, "a": 0.25, "p": 1.2, "v": 0.25},
		{"w": "noise", "f": [1, 1], "t": 0.6, "a": 0.4, "p": 1.0, "v": 0.15, "lp": 0.5, "hp": 0.5}],
	"zap": [{"w": "square", "f": [1900, 180], "t": 0.16, "a": 0.002, "p": 1.6, "v": 0.3, "lp": 0.6}, {"w": "noise", "f": [1, 1], "t": 0.12, "a": 0.002, "p": 2.0, "v": 0.3, "hp": 0.7, "lp": 0.9}],
	"frost": [{"w": "noise", "f": [1, 1], "t": 0.45, "a": 0.01, "p": 1.6, "v": 0.35, "hp": 0.8, "lp": 0.95}, {"w": "sine", "f": [2100, 700], "t": 0.4, "a": 0.005, "p": 1.8, "v": 0.3},
		{"w": "sine", "f": [100, 50], "t": 0.3, "a": 0.004, "p": 2.0, "v": 0.5}],
	"heal": [{"w": "sine", "f": [660, 660], "t": 0.3, "a": 0.02, "p": 1.6, "v": 0.3}, {"w": "sine", "f": [880, 880], "t": 0.3, "a": 0.02, "p": 1.6, "v": 0.3, "d": 0.09},
		{"w": "sine", "f": [1320, 1320], "t": 0.4, "a": 0.02, "p": 1.4, "v": 0.3, "d": 0.18}],
	"shield": [{"w": "sine", "f": [300, 620], "t": 0.4, "a": 0.05, "p": 1.4, "v": 0.35}, {"w": "tri", "f": [900, 930], "t": 0.4, "a": 0.1, "p": 1.4, "v": 0.2}],
	"holy": [{"w": "sine", "f": [523, 523], "t": 1.1, "a": 0.2, "p": 1.2, "v": 0.25}, {"w": "sine", "f": [659, 659], "t": 1.1, "a": 0.25, "p": 1.2, "v": 0.25},
		{"w": "sine", "f": [784, 784], "t": 1.1, "a": 0.3, "p": 1.2, "v": 0.25}, {"w": "sine", "f": [1046, 1046], "t": 1.1, "a": 0.4, "p": 1.2, "v": 0.2}],
	"blink": [{"w": "sine", "f": [1600, 280], "t": 0.16, "a": 0.003, "p": 1.6, "v": 0.4}, {"w": "noise", "f": [1, 1], "t": 0.14, "a": 0.02, "p": 1.6, "v": 0.2, "hp": 0.6, "lp": 0.9}],
	"dash": [{"w": "noise", "f": [1, 1], "t": 0.22, "a": 0.05, "p": 1.5, "v": 0.5, "lp": 0.4, "lp2": 0.1}],
	"dodge": [{"w": "noise", "f": [1, 1], "t": 0.2, "a": 0.06, "p": 1.5, "v": 0.4, "lp": 0.3, "lp2": 0.08}],
	"jump": [{"w": "sine", "f": [280, 520], "t": 0.1, "a": 0.005, "p": 1.8, "v": 0.3}],
	"land": [{"w": "sine", "f": [140, 60], "t": 0.1, "a": 0.002, "p": 2.4, "v": 0.5}, {"w": "noise", "f": [1, 1], "t": 0.07, "a": 0.002, "p": 2.5, "v": 0.2, "lp": 0.15}],
	"hurt": [{"w": "saw", "f": [320, 140], "t": 0.2, "a": 0.004, "p": 1.8, "v": 0.35, "lp": 0.3}, {"w": "noise", "f": [1, 1], "t": 0.1, "a": 0.002, "p": 2.4, "v": 0.3, "lp": 0.5}],
	"down": [{"w": "tri", "f": [420, 90], "t": 0.7, "a": 0.01, "p": 1.3, "v": 0.45}, {"w": "sine", "f": [210, 45], "t": 0.7, "a": 0.01, "p": 1.3, "v": 0.4}],
	"revive": [{"w": "sine", "f": [523, 523], "t": 0.25, "a": 0.01, "p": 1.6, "v": 0.3}, {"w": "sine", "f": [659, 659], "t": 0.25, "a": 0.01, "p": 1.6, "v": 0.3, "d": 0.1},
		{"w": "sine", "f": [784, 784], "t": 0.25, "a": 0.01, "p": 1.6, "v": 0.3, "d": 0.2}, {"w": "sine", "f": [1046, 1046], "t": 0.5, "a": 0.01, "p": 1.4, "v": 0.35, "d": 0.3}],
	"coin": [{"w": "sine", "f": [1568, 1568], "t": 0.07, "a": 0.002, "p": 2.0, "v": 0.3}, {"w": "sine", "f": [2093, 2093], "t": 0.16, "a": 0.002, "p": 2.2, "v": 0.3, "d": 0.06}],
	"shard": [{"w": "sine", "f": [2093, 2093], "t": 0.3, "a": 0.003, "p": 2.0, "v": 0.25}, {"w": "sine", "f": [2637, 2637], "t": 0.3, "a": 0.003, "p": 2.0, "v": 0.2, "d": 0.05},
		{"w": "sine", "f": [3136, 3136], "t": 0.35, "a": 0.003, "p": 2.0, "v": 0.18, "d": 0.1}],
	"chest": [{"w": "sine", "f": [150, 80], "t": 0.15, "a": 0.003, "p": 2.0, "v": 0.6}, {"w": "sine", "f": [1318, 1318], "t": 0.3, "a": 0.01, "p": 1.8, "v": 0.25, "d": 0.12},
		{"w": "sine", "f": [1760, 1760], "t": 0.4, "a": 0.01, "p": 1.8, "v": 0.25, "d": 0.22}],
	"clear": [{"w": "tri", "f": [523, 523], "t": 0.2, "a": 0.01, "p": 1.5, "v": 0.3}, {"w": "tri", "f": [659, 659], "t": 0.2, "a": 0.01, "p": 1.5, "v": 0.3, "d": 0.12},
		{"w": "tri", "f": [784, 784], "t": 0.2, "a": 0.01, "p": 1.5, "v": 0.3, "d": 0.24}, {"w": "tri", "f": [1046, 1046], "t": 0.6, "a": 0.01, "p": 1.3, "v": 0.35, "d": 0.36},
		{"w": "sine", "f": [523, 523], "t": 0.7, "a": 0.01, "p": 1.3, "v": 0.2, "d": 0.36}],
	"portal": [{"w": "noise", "f": [1, 1], "t": 0.7, "a": 0.5, "p": 1.0, "v": 0.3, "lp": 0.1, "lp2": 0.6}, {"w": "sine", "f": [180, 540], "t": 0.7, "a": 0.4, "p": 1.2, "v": 0.3}],
	"enemy_windup": [{"w": "tri", "f": [140, 230], "t": 0.24, "a": 0.08, "p": 1.2, "v": 0.3, "lp": 0.3}],
	"enemy_die": [{"w": "noise", "f": [1, 1], "t": 0.2, "a": 0.003, "p": 2.2, "v": 0.4, "lp": 0.4}, {"w": "sine", "f": [520, 90], "t": 0.26, "a": 0.004, "p": 1.6, "v": 0.4}],
	"roar": [{"w": "saw", "f": [95, 60], "t": 1.2, "a": 0.15, "p": 1.2, "v": 0.5, "lp": 0.12, "trem": 22.0}, {"w": "noise", "f": [1, 1], "t": 1.2, "a": 0.2, "p": 1.3, "v": 0.4, "lp": 0.1}],
	"wind": [{"w": "noise", "f": [1, 1], "t": 0.6, "a": 0.15, "p": 1.3, "v": 0.6, "lp": 0.08, "lp2": 0.5}],
	"vortex": [{"w": "sine", "f": [60, 110], "t": 0.9, "a": 0.3, "p": 1.2, "v": 0.6, "trem": 9.0}, {"w": "noise", "f": [1, 1], "t": 0.9, "a": 0.4, "p": 1.2, "v": 0.3, "lp": 0.12}],
	"beam": [{"w": "saw", "f": [220, 240], "t": 0.9, "a": 0.08, "p": 1.0, "v": 0.2, "lp": 0.25, "trem": 30.0}, {"w": "sine", "f": [880, 900], "t": 0.9, "a": 0.08, "p": 1.0, "v": 0.2}],
	"plant": [{"w": "sine", "f": [200, 90], "t": 0.14, "a": 0.003, "p": 2.0, "v": 0.6}, {"w": "tri", "f": [600, 900], "t": 0.2, "a": 0.02, "p": 1.8, "v": 0.2, "d": 0.08}],
	"arrow_rain": [{"w": "noise", "f": [1, 1], "t": 0.9, "a": 0.2, "p": 1.0, "v": 0.4, "hp": 0.5, "lp": 0.8, "trem": 26.0}],
	"ui_click": [{"w": "sine", "f": [880, 1100], "t": 0.06, "a": 0.002, "p": 2.0, "v": 0.3}],
	"ui_hover": [{"w": "sine", "f": [1320, 1320], "t": 0.03, "a": 0.002, "p": 2.0, "v": 0.12}],
	"ui_buy": [{"w": "sine", "f": [1046, 1046], "t": 0.1, "a": 0.002, "p": 2.0, "v": 0.3}, {"w": "sine", "f": [1568, 1568], "t": 0.2, "a": 0.002, "p": 2.0, "v": 0.3, "d": 0.08}],
	"ui_error": [{"w": "square", "f": [220, 180], "t": 0.16, "a": 0.004, "p": 1.4, "v": 0.2, "lp": 0.2}],
	"pick": [{"w": "sine", "f": [784, 784], "t": 0.15, "a": 0.004, "p": 1.8, "v": 0.3}, {"w": "sine", "f": [1175, 1175], "t": 0.15, "a": 0.004, "p": 1.8, "v": 0.3, "d": 0.08},
		{"w": "sine", "f": [1568, 1568], "t": 0.4, "a": 0.004, "p": 1.5, "v": 0.3, "d": 0.16}],
}

var streams: Dictionary = {}
var music: Dictionary = {}
var enabled := true
var _pool: Array = []
var _pool_i := 0
var _ui: AudioStreamPlayer
var _music_a: AudioStreamPlayer
var _thread: Thread
var _want_music := ""
var _cur_music := ""
var _last: Dictionary = {}

func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--nosound")
	if not enabled:
		return
	for i in 20:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 9.0
		p.max_distance = 60.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool.append(p)
	_ui = AudioStreamPlayer.new()
	add_child(_ui)
	_music_a = AudioStreamPlayer.new()
	add_child(_music_a)
	_thread = Thread.new()
	_thread.start(_generate)
	apply_volume()

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(Save.setting("volume")), 0.0001, 1.0)))
	if _music_a:
		_music_a.volume_db = linear_to_db(clampf(float(Save.setting("music")) * 0.5, 0.0001, 1.0))

func _generate() -> void:
	for nm in SOUNDS:
		var st := _render(SOUNDS[nm])
		call_deferred("_store", nm, st)
	for nm in ["hub", "combat", "boss"]:
		var ms := _render_music(nm)
		call_deferred("_store_music", nm, ms)

func _store(nm: String, st: AudioStreamWAV) -> void:
	streams[nm] = st

func _store_music(nm: String, st: AudioStreamWAV) -> void:
	music[nm] = st
	if _want_music == nm:
		set_music(nm)

func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()

# ------------------------------------------------------------------ sintese
func _osc(w: String, ph: float) -> float:
	var x := fposmod(ph, 1.0)
	match w:
		"sine":
			return sin(x * TAU)
		"tri":
			return 4.0 * absf(x - 0.5) - 1.0
		"saw":
			return 2.0 * x - 1.0
		"square":
			return 1.0 if x < 0.5 else -1.0
	return randf() * 2.0 - 1.0

func _layer(buf: PackedFloat32Array, l: Dictionary) -> void:
	var n := int(float(l["t"]) * RATE)
	var off := int(float(l.get("d", 0.0)) * RATE)
	var w := str(l["w"])
	var f0 := float(l["f"][0])
	var f1 := float(l["f"][1])
	var atk := maxf(float(l.get("a", 0.005)), 0.0005)
	var pw := float(l.get("p", 2.0))
	var vol := float(l.get("v", 0.5))
	var lp0 := float(l.get("lp", 1.0))
	var lp1 := float(l.get("lp2", lp0))
	var hp := float(l.get("hp", 0.0))
	var trem := float(l.get("trem", 0.0))
	var ph := 0.0
	var y := 0.0
	var hy := 0.0
	var hx := 0.0
	for i in n:
		var t := float(i) / n
		var ts := float(i) / RATE
		var s: float
		if w == "noise":
			s = randf() * 2.0 - 1.0
		else:
			ph += lerpf(f0, f1, t) / RATE
			s = _osc(w, ph)
		var lp := lerpf(lp0, lp1, t)
		if lp < 0.999:
			y += (s - y) * lp
			s = y
		if hp > 0.0:
			hy = hp * (hy + s - hx)
			hx = s
			s = hy
		var env := minf(ts / atk, 1.0) * pow(1.0 - t, pw)
		if trem > 0.0:
			env *= 0.65 + 0.35 * sin(ts * trem * TAU)
		var j := off + i
		if j < buf.size():
			buf[j] += s * env * vol

func _render(layers: Array) -> AudioStreamWAV:
	var dur := 0.0
	for l in layers:
		dur = maxf(dur, float(l["t"]) + float(l.get("d", 0.0)))
	var buf := PackedFloat32Array()
	buf.resize(int(dur * RATE) + 64)
	for l in layers:
		_layer(buf, l)
	return _to_wav(buf, false)

func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v := clampf(buf[i], -1.0, 1.0)
		# saturacao suave para nao estalar
		v = v * (1.5 - 0.5 * v * v)
		bytes.encode_s16(i * 2, int(v * 30000.0))
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

# ------------------------------------------------------------------ musica
func _note(buf: PackedFloat32Array, start: float, freq: float, dur: float, vol: float, kind: String) -> void:
	var n := int(dur * RATE)
	var off := int(start * RATE)
	var total := buf.size()
	var ph := 0.0
	var ph2 := 0.0
	for i in n:
		var t := float(i) / n
		var ts := float(i) / RATE
		ph += freq / RATE
		ph2 += freq * 2.003 / RATE
		var s := 0.0
		var env := 0.0
		match kind:
			"pluck":
				s = sin(ph * TAU) + 0.35 * sin(ph2 * TAU) * (1.0 - t)
				env = minf(ts / 0.006, 1.0) * pow(1.0 - t, 2.6)
			"pad":
				s = sin(ph * TAU) + 0.5 * sin(ph * TAU * 1.5) * 0.0 + 0.25 * (4.0 * absf(fposmod(ph2 * 0.5, 1.0) - 0.5) - 1.0)
				env = sin(t * PI)
				env *= env
			"bass":
				s = sin(ph * TAU) + 0.3 * (4.0 * absf(fposmod(ph, 1.0) - 0.5) - 1.0)
				env = minf(ts / 0.01, 1.0) * pow(1.0 - t, 1.5)
			"bell":
				s = sin(ph * TAU) + 0.4 * sin(ph * TAU * 2.76) * pow(1.0 - t, 3.0)
				env = minf(ts / 0.003, 1.0) * pow(1.0 - t, 3.2)
			"kick":
				var kf := lerpf(150.0, 42.0, minf(t * 3.0, 1.0))
				ph2 += kf / RATE
				s = sin(ph2 * TAU)
				env = pow(1.0 - t, 2.4)
			"hat":
				s = randf() * 2.0 - 1.0
				env = pow(1.0 - t, 5.0)
		buf[(off + i) % total] += s * env * vol

func _hz(semi: int) -> float:
	return 220.0 * pow(2.0, semi / 12.0)

func _render_music(nm: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	var buf := PackedFloat32Array()
	match nm:
		"hub":
			# calmo, pentatonica maior em Do: harpa + almofada
			rng.seed = 11
			var beat := 0.5
			var bars := 8
			buf.resize(int(bars * 4 * beat * RATE))
			var chords := [[3, 7, 10], [0, 3, 7], [-4, 0, 3], [-2, 2, 5], [3, 7, 10], [0, 3, 7], [5, 8, 12], [-2, 2, 5]]
			var scale := [3, 5, 7, 10, 12, 15, 17, 19]
			for b in bars:
				var ch: Array = chords[b]
				for nt in ch:
					_note(buf, b * 4 * beat, _hz(nt - 12), 4 * beat + 0.5, 0.07, "pad")
				_note(buf, b * 4 * beat, _hz(ch[0] - 24), 3.5 * beat, 0.1, "bass")
				for s in 8:
					if rng.randf() < 0.72:
						var n2: int = scale[rng.randi() % scale.size()] if rng.randf() < 0.5 else int(ch[rng.randi() % 3]) + 12
						_note(buf, (b * 4 + s * 0.5) * beat, _hz(n2), 1.4, 0.09 * rng.randf_range(0.6, 1.0), "pluck")
				if b % 2 == 1:
					_note(buf, (b * 4 + 3) * beat, _hz(int(ch[2]) + 12), 2.0, 0.05, "bell")
		"combat":
			# movido: baixo em colcheias, arpejo menor, percussao leve
			rng.seed = 23
			var beat2 := 0.36
			var bars2 := 8
			buf.resize(int(bars2 * 4 * beat2 * RATE))
			var roots := [0, 0, -4, -2, 0, 0, 3, -2]
			var minor := [0, 3, 7, 10, 12, 15]
			for b in bars2:
				var r: int = roots[b]
				_note(buf, b * 4 * beat2, _hz(r - 12), 4 * beat2 + 0.3, 0.05, "pad")
				_note(buf, b * 4 * beat2, _hz(r - 5), 4 * beat2 + 0.3, 0.04, "pad")
				for s in 8:
					_note(buf, (b * 4 + s * 0.5) * beat2, _hz(r - 24 + (12 if s % 4 == 3 else 0)), beat2 * 0.48, 0.13, "bass")
					if s % 2 == 0:
						_note(buf, (b * 4 + s * 0.5) * beat2, 0.0, 0.16, 0.2 if s % 4 == 0 else 0.12, "kick")
					_note(buf, (b * 4 + s * 0.5 + 0.25) * beat2, 0.0, 0.05, 0.035, "hat")
				for s in 16:
					if rng.randf() < 0.6:
						var n3: int = r + int(minor[(s * 2 + b) % minor.size()])
						_note(buf, (b * 4 + s * 0.25) * beat2, _hz(n3), 0.5, 0.06, "pluck")
		_:
			# chefe: mais lento e pesado, intervalo tenso, sino
			rng.seed = 37
			var beat3 := 0.42
			var bars3 := 8
			buf.resize(int(bars3 * 4 * beat3 * RATE))
			var roots3 := [-2, -2, -1, -2, -5, -5, -4, -2]
			for b in bars3:
				var r3: int = roots3[b]
				_note(buf, b * 4 * beat3, _hz(r3 - 12), 4 * beat3 + 0.4, 0.07, "pad")
				_note(buf, b * 4 * beat3, _hz(r3 - 6), 4 * beat3 + 0.4, 0.045, "pad")
				for s in 8:
					_note(buf, (b * 4 + s * 0.5) * beat3, _hz(r3 - 24), beat3 * 0.5, 0.15, "bass")
					if s % 4 == 0 or s % 8 == 5:
						_note(buf, (b * 4 + s * 0.5) * beat3, 0.0, 0.2, 0.24, "kick")
				for s in 8:
					if rng.randf() < 0.55:
						var n4: int = r3 + [0, 3, 6, 7, 12, 15][rng.randi() % 6]
						_note(buf, (b * 4 + s * 0.5) * beat3, _hz(n4), 0.9, 0.06, "bell")
	return _to_wav(buf, true)

# ------------------------------------------------------------------ tocar
func play(nm: String, pos: Vector3 = Vector3.ZERO, vol: float = 1.0, ui: bool = false) -> void:
	if not enabled or not streams.has(nm):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(nm, 0)) < 40:
		return
	_last[nm] = now
	if ui:
		_ui.stream = streams[nm]
		_ui.volume_db = linear_to_db(maxf(vol, 0.001))
		_ui.pitch_scale = 1.0
		_ui.play()
		return
	var p: AudioStreamPlayer3D = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = streams[nm]
	p.global_position = pos
	p.volume_db = linear_to_db(maxf(vol, 0.001))
	p.pitch_scale = randf_range(0.93, 1.07)
	p.play()

func ui(nm: String) -> void:
	play(nm, Vector3.ZERO, 0.8, true)

func set_music(nm: String) -> void:
	_want_music = nm
	if not enabled or _cur_music == nm:
		return
	if nm == "":
		_cur_music = ""
		_music_a.stop()
		return
	if not music.has(nm):
		return
	_cur_music = nm
	_music_a.stream = music[nm]
	apply_volume()
	_music_a.play()
