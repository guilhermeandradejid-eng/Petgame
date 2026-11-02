class_name GameAudio
extends Node
## Áudio do jogo: buses de mixagem, efeitos 3D posicionais com variações,
## música adaptativa em camadas e torcida que reage ao jogo.

const SFX_DIR := "res://assets/audio/sfx/"
const AMB_DIR := "res://assets/audio/amb/"
const MUSIC_DIR := "res://assets/audio/music/"

var banks := {}             # nome base -> Array[AudioStream] (variações _0, _1, ...)
var pool3d: Array[AudioStreamPlayer3D] = []
var pool2d: Array[AudioStreamPlayer] = []
var next3d := 0
var next2d := 0
var listener: AudioListener3D
var stems: Array[AudioStreamPlayer] = []
var stem_target := [1.0, 0.0, 0.0]
var stem_level := [0.0, 0.0, 0.0]
var music_on := true
var muffle := 0.0           # 0 = normal, 1 = abafado (replay/pausa)
var crowd_bed: AudioStreamPlayer
var sea: AudioStreamPlayer
var crowd_level := 0.2
var bus_music := -1
var bus_sfx := -1
var bus_crowd := -1
var bus_ui := -1
var lp_music: AudioEffectLowPassFilter
var lp_crowd: AudioEffectLowPassFilter
var last_play := {}
var duck_t := 0.0


## Abaixa a música um instante (para o estouro do especial aparecer)
func duck(t := 0.4) -> void:
	duck_t = t


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_load_banks()
	listener = AudioListener3D.new()
	add_child(listener)
	listener.make_current()
	for i in 28:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 22.0
		p.max_distance = 80.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.7
		add_child(p)
		pool3d.append(p)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		pool2d.append(p)
	for n in ["music_base", "music_perc", "music_lead"]:
		var s := AudioStreamPlayer.new()
		s.stream = _loop(load(MUSIC_DIR + n + ".ogg"))
		s.bus = "Music"
		s.volume_db = -80.0
		add_child(s)
		stems.append(s)
	crowd_bed = AudioStreamPlayer.new()
	crowd_bed.stream = _loop(load(AMB_DIR + "crowd_bed.ogg"))
	crowd_bed.bus = "Crowd"
	add_child(crowd_bed)
	sea = AudioStreamPlayer.new()
	sea.stream = _loop(load(AMB_DIR + "sea.ogg"))
	sea.bus = "Crowd"
	sea.volume_db = -12.0
	add_child(sea)
	crowd_bed.play()
	sea.play()
	start_music()


func _setup_buses() -> void:
	# Master: compressão leve + limitador (som cheio e sem estourar)
	var comp := AudioEffectCompressor.new()
	comp.threshold = -14.0
	comp.ratio = 3.0
	comp.attack_us = 2000.0
	comp.release_ms = 180.0
	comp.gain = 3.0
	AudioServer.add_bus_effect(0, comp)
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.8
	AudioServer.add_bus_effect(0, lim)
	bus_music = _add_bus("Music", -9.0)
	lp_music = AudioEffectLowPassFilter.new()
	lp_music.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(bus_music, lp_music)
	bus_sfx = _add_bus("SFX", 3.0)
	# praia aberta: quase sem reverb (só um ar), o eco curto já vem no próprio som
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.2
	rv.damping = 0.7
	rv.wet = 0.03
	rv.dry = 1.0
	AudioServer.add_bus_effect(bus_sfx, rv)
	bus_crowd = _add_bus("Crowd", -5.0)
	lp_crowd = AudioEffectLowPassFilter.new()
	lp_crowd.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(bus_crowd, lp_crowd)
	bus_ui = _add_bus("UI", 0.0)


func _add_bus(n: String, db: float) -> int:
	var idx := AudioServer.get_bus_index(n)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, n)
		AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, db)
	return idx


func _loop(s: AudioStream) -> AudioStream:
	if s is AudioStreamOggVorbis:
		var o := (s as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		o.loop = true
		return o
	return s


func _load_banks() -> void:
	for dir in [SFX_DIR, AMB_DIR]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			var fname := f.trim_suffix(".import").trim_suffix(".remap")
			if not (fname.ends_with(".wav") or fname.ends_with(".ogg")):
				continue
			var base := fname.get_basename()
			var key := base
			var parts := base.rsplit("_", true, 1)
			if parts.size() == 2 and parts[1].is_valid_int():
				key = parts[0]
			var st: AudioStream = load(dir + fname)
			if st == null:
				continue
			if not banks.has(key):
				banks[key] = []
			if not (st in banks[key]):
				banks[key].append(st)


func has(name: String) -> bool:
	return banks.has(name)


func _pick(name: String) -> AudioStream:
	var list: Array = banks.get(name, [])
	if list.is_empty():
		return null
	return list[randi() % list.size()]


## Efeito posicionado no mundo (golpes, areia, rede)
func play3d(name: String, pos: Vector3, db := 0.0, pitch_var := 0.06, pitch := 1.0) -> void:
	var st := _pick(name)
	if st == null:
		return
	var p := pool3d[next3d]
	next3d = (next3d + 1) % pool3d.size()
	p.stream = st
	p.global_position = pos
	p.volume_db = db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.play()


## Efeito sem posição (interface, vinhetas, reações da torcida)
func play(name: String, db := 0.0, pitch_var := 0.03, pitch := 1.0, bus := "UI") -> void:
	var now := Time.get_ticks_msec()
	if now - int(last_play.get(name, -1000)) < 40:
		return   # evita empilhar o mesmo som no mesmo instante
	last_play[name] = now
	var st := _pick(name)
	if st == null:
		return
	var p := pool2d[next2d]
	next2d = (next2d + 1) % pool2d.size()
	p.stream = st
	p.bus = bus
	p.volume_db = db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.play()


func crowd(event: String, db := 0.0) -> void:
	play(event, db, 0.04, 1.0, "Crowd")


func start_music() -> void:
	for s in stems:
		s.play()
	music_on = true


func set_music_enabled(on: bool) -> void:
	music_on = on
	if on and not stems[0].playing:
		start_music()


## Intensidade da música: 0 = só a base, 1 = percussão + um pouco do refrão, 2 = tudo
func set_intensity(level: float) -> void:
	stem_target = [1.0, clampf(level, 0.0, 1.0), clampf((level - 0.5) / 1.5, 0.0, 1.0)]


func set_crowd(level: float) -> void:
	crowd_level = clampf(level, 0.0, 1.0)


func set_muffle(m: float) -> void:
	muffle = m


func follow(cam: Camera3D) -> void:
	if cam:
		listener.global_transform = cam.global_transform


func _process(dt: float) -> void:
	duck_t = maxf(0.0, duck_t - dt)
	for i in stems.size():
		var tgt: float = stem_target[i] if music_on else 0.0
		stem_level[i] = move_toward(stem_level[i], tgt, dt * (1.6 if tgt > stem_level[i] else 0.8))
		stems[i].volume_db = linear_to_db(maxf(stem_level[i], 0.0001)) - (2.0 if i > 0 else 0.0) - (5.0 if duck_t > 0.0 else 0.0)
	var cut := lerpf(20000.0, 700.0, muffle)
	lp_music.cutoff_hz = lerpf(lp_music.cutoff_hz, cut, 1.0 - exp(-6.0 * dt))
	lp_crowd.cutoff_hz = lerpf(lp_crowd.cutoff_hz, lerpf(20000.0, 1800.0, muffle), 1.0 - exp(-6.0 * dt))
	crowd_bed.volume_db = lerpf(crowd_bed.volume_db, lerpf(-20.0, -6.0, crowd_level), 1.0 - exp(-3.0 * dt))
