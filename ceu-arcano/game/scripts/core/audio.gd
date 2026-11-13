extends Node
## Efeitos sonoros (pool com variação de pitch) e música com crossfade.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"

var _sfx := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""
var _duck := 1.0
var _trim := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for f in _list(SFX_DIR, [".wav", ".ogg"]):
		var s = load(SFX_DIR + f)
		if s:
			_sfx[f.get_basename()] = s
	var meta = JSON.parse_string(FileAccess.get_file_as_string(SFX_DIR + "sfx.json"))
	if typeof(meta) == TYPE_DICTIONARY:
		for k in meta:
			_trim[k] = float(meta[k].get("suggested_volume_db", 0.0))
	for i in 20:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)


func _list(dir: String, exts: Array) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		var name := f.trim_suffix(".import").trim_suffix(".remap")
		for e in exts:
			if name.ends_with(e) and not out.has(name):
				out.append(name)
	return out


func has(name: String) -> bool:
	return _sfx.has(name)


func play(name: String, vol_db := 0.0, pitch := 1.0, pitch_var := 0.06) -> void:
	if not _sfx.has(name):
		return
	# evita empilhar o mesmo som no mesmo frame
	var now := Time.get_ticks_msec()
	if _last_play.has(name) and now - int(_last_play[name]) < 25:
		return
	_last_play[name] = now
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _sfx[name]
	# o volume sugerido pelo pipeline de áudio e o pedido na chamada não se somam: vale o mais baixo
	p.volume_db = minf(vol_db, float(_trim.get(name, vol_db))) + linear_to_db(maxf(Game.sfx_volume, 0.0001))
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-pitch_var, pitch_var)) * Engine.time_scale ** 0.35)
	p.play()


func music(name: String, fade := 0.8) -> void:
	if name == _music_name:
		return
	_music_name = name
	var path := MUSIC_DIR + name + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	if stream:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = name != "victory"
		_music_a.stream = stream
		_music_a.volume_db = -40.0
		_music_a.play()
		var tw := create_tween()
		tw.tween_property(_music_a, "volume_db", _music_db(), fade)
	var tw2 := create_tween()
	tw2.tween_property(_music_b, "volume_db", -60.0, fade)
	tw2.tween_callback(_music_b.stop)


func stop_music(fade := 0.8) -> void:
	_music_name = ""
	var tw := create_tween()
	tw.tween_property(_music_a, "volume_db", -60.0, fade)
	tw.tween_callback(_music_a.stop)


func duck(amount: float) -> void:
	_duck = clampf(amount, 0.05, 1.0)
	if _music_a.playing:
		_music_a.volume_db = _music_db()


func _music_db() -> float:
	return linear_to_db(maxf(Game.music_volume * _duck, 0.0001)) - 4.0
