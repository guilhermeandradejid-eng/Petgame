class_name Sfx
extends Node
## Áudio com sons REAIS (pasta sfx/, autores e licenças em sfx/CREDITOS.txt; montada por tools/build_sfx.py):
## - motor do seu carro feito de gravações em rotação fixa (6 a 10 por motor, do engine-sim): tocam as duas
##   mais próximas da rotação atual, com o tom ajustado e mistura entre elas; marchas com troca audível e
##   filtro que abafa o motor quando você tira o pé;
## - pneu cantando (derrapagem/freada), metal raspando na mureta, vento e turbo do nitro em loop;
## - efeitos curtos com variações sorteadas (batidas, armas, explosões, interface, narrador);
## - motor 3D dos rivais (cada um com a gravação do próprio carro, mais alto quando passa perto).

const SHOTS := {"crash": 7, "bump": 7, "metal": 5, "tink": 5, "glass": 5, "smash": 5, "land": 4, "splash": 3, "splat": 1,
	"whoosh": 4, "nitro": 5, "backfire": 1, "shift": 3, "gun": 2, "rocket": 1, "boom": 3, "boom_small": 2, "zap": 2,
	"laser": 5, "plasma": 1, "rail": 1, "mortar": 1, "harpoon": 1, "freeze": 3, "flame": 1, "emp": 1, "deploy": 5,
	"click": 3, "ui_drop": 4, "buy": 4, "pickup": 4, "error": 2, "warn": 1, "count3": 1, "count2": 1, "count1": 1,
	"go": 1, "v_ready": 1, "v_final": 1, "v_win": 1, "v_over": 1, "v_record": 1, "fanfare": 3}
## nomes antigos (som sintetizado) -> sons novos
const ALIAS := {"coin": "click", "drop": "ui_drop", "beep": "warn"}
## séries de motor (rotação de cada gravação)
const ENGINES := {"b-i6r": [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000], "su-mid": [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000],
	"su-sz": [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000], "exh": [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000],
	"tsu": [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000], "gv8": [1000, 2000, 3000, 4000, 5000, 6000],
	"ct-v8": [1000, 2000, 3000, 4000, 5000, 6000, 7000], "v12d": [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000],
	"v8f": [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000], "dsl": [300, 630, 1000, 1500, 2000, 2350], "elec": [4000]}
## motor de cada carro (o tipo de motor combina com o carro: rally boxer, muscle V8, V12 do hipercarro...)
const ENGINE_OF := {"faisca": "b-i6r", "vespa": "su-mid", "zefiro": "elec", "trovao": "exh", "jacare": "tsu", "escorpiao": "gv8",
	"monstro": "ct-v8", "nevasca": "su-sz", "nemesis": "v12d", "falcao": "v8f", "hyper": "v12d", "sedan": "tsu", "taxi": "tsu",
	"policia": "exh", "picape": "gv8", "van": "dsl"}
## faixa de rotação usada (marcha lenta .. corte) por série
const RANGE := {"dsl": [500.0, 2350.0], "elec": [2200.0, 7600.0], "gv8": [1000.0, 6000.0], "ct-v8": [1000.0, 7000.0]}

## mixagem: motor do jogador e dos rivais um pouco abaixo, para a música aparecer por cima no celular
const ENG_GAIN := 0.62
const SHOT_DB := -4.0   # efeitos curtos (tiros, batidas): abaixo da música
const LOOP_DB := -3.0   # pneu, vento, turbo, raspada
var muted := false
var pool: Array = []
var pool_i := 0
var _cache := {}
# motor do jogador (2D)
var eng_set := ""
var eng_rpms: Array = []
var eng_players: Array = []
var rpm := 1000.0
var t_rpm := 1000.0
var eng_vol := 0.0
var t_eng_vol := 0.0
var throttle_s := 0.0
var gear := 0
var _shift_dip := 0.0
var slow_k := 1.0
var _lp: AudioEffectLowPassFilter
var _motor_bus := -1
# loops
var loops := {}
var t_loop := {}
var v_loop := {}
var t_scrape := 0.0
# menu/vitrine controla o motor (ronco no desfile)
var menu_on := false
# motores 3D dos rivais (só tocam com a corrida na tela)
var engines3d: Array = []
var world_on := false


func _ready() -> void:
	# limitador no Master: muitos sons juntos (batida + explosão + motor) não estouram
	var has_lim := false
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			has_lim = true
	if not has_lim:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.8
		lim.pre_gain_db = 0.0
		AudioServer.add_bus_effect(0, lim)
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "Efeitos"
		add_child(p)
		pool.append(p)
	for nm in ["loop_skid", "loop_scrape", "loop_wind", "loop_turbo"]:
		var p := AudioStreamPlayer.new()
		p.bus = "Efeitos"
		p.stream = _load("res://sfx/%s.ogg" % nm, true)
		p.volume_db = -80.0
		add_child(p)
		loops[nm] = p
		t_loop[nm] = 0.0
		v_loop[nm] = 0.0


func _load(path: String, loop := false) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var st: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = loop
	_cache[path] = st
	return st


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)


## barramento "Motor" (manda para "Efeitos"), com filtro que abafa o motor sem acelerador
func _ensure_motor_bus() -> void:
	_motor_bus = AudioServer.get_bus_index("Motor")
	if _motor_bus < 0:
		AudioServer.add_bus()
		_motor_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_motor_bus, "Motor")
		AudioServer.set_bus_send(_motor_bus, "Efeitos")
		_lp = AudioEffectLowPassFilter.new()
		_lp.cutoff_hz = 9000.0
		_lp.resonance = 0.6
		AudioServer.add_bus_effect(_motor_bus, _lp)
	elif _lp == null:
		_lp = AudioServer.get_bus_effect(_motor_bus, 0) as AudioEffectLowPassFilter


## motor do carro do jogador (troca a série de gravações)
func set_engine(kind: String) -> void:
	var s: String = ENGINE_OF.get(kind, "b-i6r")
	if not ENGINES.has(s):
		s = "b-i6r"
	if s == eng_set:
		return
	_ensure_motor_bus()
	for p in eng_players:
		(p as Node).queue_free()
	eng_players.clear()
	eng_set = s
	eng_rpms = ENGINES[s]
	for r in eng_rpms:
		var p := AudioStreamPlayer.new()
		p.bus = "Motor"
		p.stream = _load("res://sfx/engine/%s_%d.ogg" % [s, int(r)], true)
		p.volume_db = -80.0
		add_child(p)
		p.play()
		p.stream_paused = true
		eng_players.append(p)
	var rg: Array = RANGE.get(s, [float(eng_rpms[0]), float(eng_rpms[-1])])
	rpm = rg[0]
	t_rpm = rpm


func _range() -> Array:
	return RANGE.get(eng_set, [float(eng_rpms[0]), float(eng_rpms[-1])]) if eng_rpms.size() > 0 else [1000.0, 7000.0]


func set_scrape(level: float) -> void:
	t_scrape = clampf(level, 0.0, 1.0)


## jogo (a cada quadro): velocidade 0..1+, acelerador, derrapagem 0..1, nitro, câmera lenta, carro ativo
func drive(speed01: float, throttle: float, slip: float, nitro: bool, slowmo: bool, active: bool) -> void:
	slow_k = 0.62 if slowmo else 1.0
	if menu_on:
		return
	var rg := _range()
	var s := clampf(speed01, 0.0, 1.25)
	var gears := 5
	var g := mini(gears - 1, int(s * gears * 0.999))
	var frac := s * gears - g
	# cada marcha sobe do meio da faixa até perto do corte; a 1ª sai da marcha lenta
	var lo: float = rg[0] + (rg[1] - rg[0]) * (0.0 if g == 0 else 0.42)
	var r := lerpf(lo, rg[1] * 0.93, frac)
	if s < 0.08:
		r = maxf(r, lerpf(rg[0], rg[1] * 0.7, throttle))   # parado: acelerador sobe o giro
	if nitro:
		r = minf(rg[1], r + (rg[1] - rg[0]) * 0.06)
	if active and g > gear and s > 0.05:
		play("shift", -10.0, randf_range(0.95, 1.05))
		_shift_dip = 0.18
	gear = g
	t_rpm = r
	throttle_s = throttle
	t_eng_vol = (0.62 + 0.38 * throttle) if active else 0.0
	t_loop["loop_skid"] = clampf(slip, 0.0, 1.0) * (1.0 if active else 0.0)
	t_loop["loop_wind"] = clampf((s - 0.35) * 1.1, 0.0, 0.7) if active else 0.0
	t_loop["loop_turbo"] = 0.75 if (active and nitro) else 0.0
	if not active:
		t_scrape = 0.0


## vitrine/menu: ronco do carro em exibição (rev 0 = marcha lenta .. 1 = corte); vol 0 desliga
func menu_engine(kind: String, rev: float, vol: float) -> void:
	menu_on = vol > 0.0
	if kind != "":
		set_engine(kind)
	var rg := _range()
	t_rpm = lerpf(rg[0], rg[1] * 0.95, clampf(rev, 0.0, 1.0))
	throttle_s = clampf(rev * 1.4, 0.0, 1.0)
	t_eng_vol = vol
	for k in t_loop:
		t_loop[k] = 0.0


func _process(dt: float) -> void:
	# rotação e volume do motor (suavizados), mistura das duas gravações mais próximas
	rpm += (t_rpm - rpm) * minf(1.0, dt * 9.0)
	eng_vol += (t_eng_vol - eng_vol) * minf(1.0, dt * 6.0)
	_shift_dip = maxf(0.0, _shift_dip - dt)
	if _lp:
		_lp.cutoff_hz = lerpf(1400.0, 11000.0, clampf(throttle_s, 0.0, 1.0))
	var n := eng_players.size()
	if n > 0:
		var v := eng_vol * ENG_GAIN * (0.45 if _shift_dip > 0.0 else 1.0)
		var w := PackedFloat32Array()
		w.resize(n)
		if n == 1 or rpm <= float(eng_rpms[0]):
			w[0] = 1.0
		elif rpm >= float(eng_rpms[n - 1]):
			w[n - 1] = 1.0
		else:
			for i in n - 1:
				var a := float(eng_rpms[i])
				var b := float(eng_rpms[i + 1])
				if rpm >= a and rpm <= b:
					var t := (rpm - a) / (b - a)
					w[i] = cos(t * PI * 0.5)
					w[i + 1] = sin(t * PI * 0.5)
					break
		for i in n:
			var p: AudioStreamPlayer = eng_players[i]
			var on := w[i] * v > 0.003
			p.stream_paused = not on
			if on:
				p.volume_db = linear_to_db(w[i] * v)
				p.pitch_scale = clampf(rpm / float(eng_rpms[i]) * slow_k, 0.45, 2.2)
	# loops: pneu, vento, turbo e raspada
	t_loop["loop_scrape"] = t_scrape
	for k in loops:
		var p: AudioStreamPlayer = loops[k]
		v_loop[k] = move_toward(float(v_loop[k]), float(t_loop[k]), dt * (6.0 if float(t_loop[k]) > float(v_loop[k]) else 3.0))
		var lv: float = v_loop[k]
		if lv > 0.004:
			if not p.playing:
				p.play()
			p.volume_db = linear_to_db(lv) + LOOP_DB
			match k:
				"loop_skid":
					p.pitch_scale = (0.92 + lv * 0.18) * slow_k
				"loop_scrape":
					p.pitch_scale = (0.85 + lv * 0.3) * slow_k
				"loop_turbo":
					p.pitch_scale = (0.8 + clampf(rpm / maxf(1.0, float(_range()[1])), 0.0, 1.0) * 0.5) * slow_k
				_:
					p.pitch_scale = slow_k
		elif p.playing:
			p.stop()
	_step_engines3d(dt)


## efeito curto (uma das variações, sorteada)
func play(name_: String, vol_db := 0.0, pitch := 1.0) -> void:
	var nm: String = ALIAS.get(name_, name_)
	var cnt: int = SHOTS.get(nm, 0)
	if cnt <= 0:
		return
	var st := _load("res://sfx/%s_%d.ogg" % [nm, randi() % cnt])
	if st == null:
		return
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = st
	p.volume_db = vol_db + SHOT_DB
	p.pitch_scale = pitch * randf_range(0.95, 1.05) * slow_k
	p.play()


# ------------------------------------------------------------------ motores 3D (rivais e outros jogadores)
## motor 3D preso ao carro: a gravação do motor dele numa rotação média, com o tom seguindo a velocidade
func attach_engine(c: Car) -> void:
	var s: String = ENGINE_OF.get(c.kind if not c.is_boss else "van", "b-i6r")
	if c.is_boss:
		s = "dsl"
	if not ENGINES.has(s):
		s = "b-i6r"
	var rp: Array = ENGINES[s]
	var ref: int = rp[clampi(rp.size() / 2 - 1, 0, rp.size() - 1)]
	var p := AudioStreamPlayer3D.new()
	p.stream = _load("res://sfx/engine/%s_%d.ogg" % [s, ref], true)
	p.bus = "Efeitos"
	p.unit_size = 9.0 if not c.is_boss else 16.0
	p.max_distance = 90.0
	p.max_db = -6.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.panning_strength = 0.8
	p.volume_db = -8.0
	c.add_child(p)
	p.play()
	engines3d.append({"car": c, "p": p, "ref": float(ref), "set": s})


func clear_engines3d() -> void:
	for e in engines3d:
		if is_instance_valid(e.p):
			(e.p as Node).queue_free()
	engines3d.clear()


func _step_engines3d(_dt: float) -> void:
	var keep: Array = []
	for e in engines3d:
		var c = e.car
		if not is_instance_valid(c) or not is_instance_valid(e.p):
			continue
		keep.append(e)
		var p: AudioStreamPlayer3D = e.p
		var car: Car = c
		if car.wrecked or not car.visible or not world_on:
			p.stream_paused = true
			continue
		p.stream_paused = false
		var rg: Array = RANGE.get(e.set, [float(ENGINES[e.set][0]), float(ENGINES[e.set][-1])])
		var s := clampf(car.linear_velocity.length() / maxf(1.0, float(car.sp.vmax)), 0.0, 1.2)
		var g := mini(4, int(s * 5.0 * 0.999))
		var frac := s * 5.0 - g
		var r := lerpf(rg[0] + (rg[1] - rg[0]) * (0.0 if g == 0 else 0.42), rg[1] * 0.93, frac)
		p.pitch_scale = clampf(r / float(e.ref), 0.5, 2.0) * slow_k
		p.volume_db = -18.0 + 5.0 * clampf(car.ctrl.throttle, 0.0, 1.0) + (2.0 if car.nitroing else 0.0)
	engines3d = keep
