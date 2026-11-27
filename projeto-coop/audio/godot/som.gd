extends Node
## Som — autoload de efeitos sonoros do Plumbdeep.
##
## Registre como autoload com o nome "Som" (Projeto > Configurações > Autoload) e aponte
## audio/buses/default_bus_layout para res://audio/godot/audio_bus_layout.tres.
##
## Uso básico (no quadro de contato da animação):
##     Som.tocar("escorador_impacto_final", global_position, 1.0, {"alvo": "gosma"})
## Sopro que precisa ter o pico ANTES do contato (chame no início do golpe):
##     Som.tocar_antes_do_contato("escorador_swing_pesado", global_position, 0.22)
##
## Tudo o que define o som (camadas, arquivos, volumes, atrasos, prioridade, limite de vozes,
## ducking, hit-stop) está em eventos.json, gerado por som/scripts/compor.py.

signal evento_tocado(evento: String, posicao: Variant, peso: float, quadro: int)

const CAMADA_REVERB := 1 << 19  ## camada de física (20) usada pelas áreas de reverb (Area3D)

@export var raiz := "res://audio/"
@export var arquivo_eventos := "res://audio/godot/eventos.json"
## Compostos = golpes com as camadas já mixadas (atrasos de poucos ms exatos, menos vozes).
## Desligue para montar as camadas em tempo de jogo a partir de "receita_composto" (útil para ajustar a mixagem).
@export var usar_compostos := true
@export var vozes_3d := 40
@export var vozes_2d := 16
@export var vozes_planas := 16
## Multiplica o pitch pelo Engine.time_scale (câmera lenta), sem descer abaixo de 0,55.
@export var seguir_time_scale := true
## Grava cada evento tocado (com o número do quadro) em user://som_log.jsonl,
## para montar a trilha dos clipes do Movie Maker com ffmpeg.
@export var registrar_log := false:
	set(v):
		registrar_log = v
		if v and _log == null and is_inside_tree():
			_abrir_log()
@export var arquivo_log := "user://som_log.jsonl"

var grupos: Dictionary = {}
var eventos: Dictionary = {}
var musicas: Dictionary = {}

var _streams: Dictionary = {}          # caminho -> AudioStream
var _ultimo: Dictionary = {}           # grupo -> último índice (escolha sem repetir)
var _ultimo_disparo: Dictionary = {}   # evento -> ms (cooldown)
var _pool3d: Array = []
var _pool2d: Array = []
var _pool_plano: Array = []
var _vozes: Dictionary = {}            # player -> {evento, prioridade, inicio, pitch_base, id, grupo_voz}
var _agendados: Array = []             # camadas com atraso
var _prox_id := 1
var _duck_db := 0.0                    # atenuação atual do ambiente (negativa)
var _duck_alvo := 0.0
var _duck_ate := 0
var _hit_stop_ate := 0
var _hit_stop_fator := 1.0
var _camera_lenta := 1.0
var _bus_amb := -1
var _bus_mus := -1
var _bus_mundo := -1
var _bus_caverna := -1
var _vol_amb_base := 0.0
var _vol_mus_base := 0.0
var _area_reverb: Area3D
var _abafado_alvo := 20000.0
var _abafado_atual := 20000.0
var _musica_a: AudioStreamPlayer
var _musica_b: AudioStreamPlayer
var _musica_atual := ""
var _desbloqueado := true
var _pendentes: Array = []             # pedidos feitos antes do primeiro toque (web)
var _log: FileAccess
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	if OS.has_feature("web"):
		# iPhone/Safari: poucas vozes simultâneas e o áudio só destrava no primeiro toque.
		vozes_3d = mini(vozes_3d, 20)
		vozes_2d = mini(vozes_2d, 8)
		vozes_planas = mini(vozes_planas, 8)
		usar_compostos = true
		_desbloqueado = false
	_carregar_eventos()
	_bus_amb = AudioServer.get_bus_index("Ambiente")
	_bus_mus = AudioServer.get_bus_index("Musica")
	_bus_mundo = AudioServer.get_bus_index("Mundo")
	_bus_caverna = AudioServer.get_bus_index("Caverna")
	if _bus_amb >= 0: _vol_amb_base = AudioServer.get_bus_volume_db(_bus_amb)
	if _bus_mus >= 0: _vol_mus_base = AudioServer.get_bus_volume_db(_bus_mus)
	for i in vozes_3d:
		var p := AudioStreamPlayer3D.new()
		p.area_mask = CAMADA_REVERB
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 4.0
		p.max_distance = 60.0
		p.panning_strength = 0.8
		_pool3d.append(_prepara(p))
	for i in vozes_2d:
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = 1400.0
		_pool2d.append(_prepara(p2))
	for i in vozes_planas:
		_pool_plano.append(_prepara(AudioStreamPlayer.new()))
	_musica_a = AudioStreamPlayer.new(); _musica_a.bus = &"Musica"; add_child(_musica_a)
	_musica_b = AudioStreamPlayer.new(); _musica_b.bus = &"Musica"; add_child(_musica_b)
	if registrar_log:
		_abrir_log()


func _abrir_log() -> void:
	_log = FileAccess.open(arquivo_log, FileAccess.WRITE)
	if _log:
		# primeira linha: referência de quadro (o quadro 0 do Movie Maker é o primeiro quadro desenhado)
		_log.store_line(JSON.stringify({"inicio_quadro": Engine.get_frames_drawn(), "fps_movie_writer": ProjectSettings.get_setting("editor/movie_writer/fps", 60),
			"movie_maker": Engine.get_write_movie_path() != ""}))


func _exit_tree() -> void:
	_streams.clear()
	if _log:
		_log.close()


func _prepara(p: Node) -> Node:
	add_child(p)
	p.finished.connect(_ao_terminar.bind(p))
	return p


# ------------------------------------------------------------------ dados
func _carregar_eventos() -> void:
	var f := FileAccess.open(arquivo_eventos, FileAccess.READ)
	if f == null:
		push_error("Som: não achei %s" % arquivo_eventos)
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		push_error("Som: eventos.json inválido")
		return
	grupos = d.get("grupos", {})
	eventos = d.get("eventos", {})
	musicas = d.get("musica", {})


## Carrega (e guarda) o stream de um arquivo da biblioteca.
func stream(caminho: String, laco := false) -> AudioStream:
	var p := caminho if caminho.begins_with("res://") or caminho.begins_with("user://") else raiz.path_join(caminho)
	var chave := p + ("#laco" if laco else "")
	if _streams.has(chave):
		return _streams[chave]
	var s: AudioStream = null
	if ResourceLoader.exists(p):
		s = load(p)
	elif FileAccess.file_exists(p):
		s = AudioStreamOggVorbis.load_from_file(p)  # arquivo solto, sem importação
	if s == null:
		push_warning("Som: arquivo ausente %s" % p)
		return null
	if laco and s is AudioStreamOggVorbis:
		s = s.duplicate()
		(s as AudioStreamOggVorbis).loop = true
	_streams[chave] = s
	return s


## Pré-carrega todos os grupos usados pelos eventos (chame numa tela de carregamento).
func precarregar(filtro_bus := "") -> int:
	var n := 0
	for nome in eventos:
		var ev: Dictionary = eventos[nome]
		if filtro_bus != "" and ev.get("bus", "") != filtro_bus:
			continue
		for c in _camadas(ev, null, true):
			var g: Dictionary = grupos.get(c["grupo"], {})
			for a in g.get("arquivos", []):
				if stream(a, g.get("laco", false)) != null:
					n += 1
	return n


## Escolhe um arquivo do grupo sem repetir o último. Devolve o índice.
func escolher(grupo: String, indices: Array = []) -> int:
	var g: Dictionary = grupos.get(grupo, {})
	var n: int = g.get("arquivos", []).size()
	if n == 0:
		return -1
	var cand: Array = indices.duplicate() if indices.size() > 0 else range(n)
	var ult: int = _ultimo.get(grupo, -1)
	if cand.size() > 1 and cand.has(ult):
		cand.erase(ult)
	var i: int = cand[_rng.randi() % cand.size()]
	_ultimo[grupo] = i
	return i


func _camadas(ev: Dictionary, alvo: Variant, todas := false) -> Array:
	var cs: Array = []
	if not usar_compostos and ev.has("receita_composto"):
		cs.append_array(ev["receita_composto"])
	else:
		cs.append_array(ev.get("camadas", []))
	var alvos: Dictionary = ev.get("alvos", {})
	if todas:
		if ev.has("receita_composto"):
			cs.append_array(ev["receita_composto"])
		for k in alvos:
			cs.append_array(alvos[k])
		return cs
	var a: Variant = alvo if alvo != null else ev.get("alvo_padrao", null)
	if a != null and alvos.has(a):
		cs.append_array(alvos[a])
	return cs


# ------------------------------------------------------------------ API
## Toca um evento. posicao: Vector3 (3D), Vector2 (2D) ou null (sem posição).
## peso 0..1: escala o sub-grave, o pitch (mais pesado = mais grave), o volume e o ducking.
## opcoes: alvo ("carne", "gosma", "pedra", "nada"), volume_db, pitch, atraso_s, seguir (Node3D/Node2D).
## Devolve o id da voz principal (para parar() ou mover()), ou 0 se não tocou.
func tocar(evento: String, posicao: Variant = null, peso: float = 1.0, opcoes: Dictionary = {}) -> int:
	if not eventos.has(evento):
		push_warning("Som: evento desconhecido '%s'" % evento)
		return 0
	if not _desbloqueado:
		_pendentes.append([evento, posicao, peso, opcoes])
		return 0
	var ev: Dictionary = eventos[evento]
	var agora := Time.get_ticks_msec()
	var cd: int = int(ev.get("cooldown_ms", 0))
	if cd > 0 and agora - int(_ultimo_disparo.get(evento, -100000)) < cd:
		return 0
	_ultimo_disparo[evento] = agora
	peso = clampf(peso, 0.0, 1.5)
	# variação compartilhada pelo evento (todas as camadas sobem/descem juntas)
	var pv: float = ev.get("pitch_var", 0.04)
	var p_ev: float = float(ev.get("pitch", 1.0)) * (1.0 + _rng.randf_range(-pv, pv)) * float(opcoes.get("pitch", 1.0))
	p_ev *= 1.0 - (peso - 0.5) * float(ev.get("peso_pitch", 0.0))
	var v_ev: float = float(ev.get("volume_db", 0.0)) + _rng.randf_range(-1.0, 1.0) * float(ev.get("volume_var_db", 1.5))
	v_ev += (peso - 1.0) * float(ev.get("peso_volume_db", 0.0)) + float(opcoes.get("volume_db", 0.0))
	var atraso_base: float = opcoes.get("atraso_s", 0.0)
	var id := _prox_id
	_prox_id += 1
	var n_camada := 0
	for c in _camadas(ev, opcoes.get("alvo", null)):
		n_camada += 1
		if c.has("probabilidade") and _rng.randf() > float(c["probabilidade"]):
			continue
		var vol: float = v_ev + float(c.get("volume_db", 0.0)) + _rng.randf_range(-1.0, 1.0) * float(c.get("volume_var_db", 0.75))
		if c.get("escala_peso", false):
			if peso < float(c.get("peso_min", 0.2)):
				continue
			vol += (peso - 1.0) * 12.0
		var cpv: float = c.get("pitch_var", 0.02)
		var p: float = p_ev * float(c.get("pitch", 1.0)) * (1.0 + _rng.randf_range(-cpv, cpv))
		var at: float = atraso_base + (float(c.get("atraso_ms", 0.0)) + _rng.randf_range(0.0, float(c.get("atraso_var_ms", 0.0)))) / 1000.0
		var i: int = int(opcoes["indice0"]) if n_camada == 1 and opcoes.has("indice0") else escolher(c["grupo"], c.get("indices", []))
		if i < 0:
			continue
		var g: Dictionary = grupos[c["grupo"]]
		var gd: Array = g.get("ganho_db", [])
		if i < gd.size():
			vol += float(gd[i])
		var camada := {"evento": evento, "ev": ev, "grupo": c["grupo"], "indice": i, "vol": vol, "pitch": p,
			"posicao": posicao, "seguir": opcoes.get("seguir", null), "id": id, "max_s": c.get("max_s", 0.0),
			"desde_s": float(opcoes.get("desde_s", 0.0)), "laco": ev.get("laco", false) or g.get("laco", false)}
		if at > 0.004:
			camada["quando"] = Time.get_ticks_usec() + int(at * 1000000.0)
			_agendados.append(camada)
		else:
			_iniciar(camada)
	_duck(float(ev.get("duck_db", 0.0)) * clampf(peso, 0.0, 1.0), int(ev.get("duck_ms", 0)))
	var hs: int = ev.get("hit_stop_ms", 0)
	if hs > 0 and peso >= 0.5:
		iniciar_hit_stop(hs / 1000.0 * peso, 0.82, id)
	var quadro := Engine.get_frames_drawn()
	evento_tocado.emit(evento, posicao, peso, quadro)
	if _log:
		_log.store_line(JSON.stringify({"quadro": quadro, "quadro_fisica": Engine.get_physics_frames(), "ms": agora,
			"evento": evento, "peso": peso, "alvo": opcoes.get("alvo", ev.get("alvo_padrao", null)),
			"pos": var_to_str(posicao), "atraso_s": atraso_base, "desde_s": float(opcoes.get("desde_s", 0.0)),
			"pitch": float(opcoes.get("pitch", 1.0)), "volume_db": float(opcoes.get("volume_db", 0.0))}))
		_log.flush()
	return id


## Para sopros/cargas: agenda o evento para que o PICO do arquivo escolhido caia
## `antecipacao_s` antes do contato (padrão 25 ms ≈ 1,5 quadro a 60 fps).
## Se o contato está mais perto que o pico, começa o arquivo já adiantado.
func tocar_antes_do_contato(evento: String, posicao: Variant, segundos_ate_contato: float, peso := 1.0, opcoes := {}, antecipacao_s := 0.025) -> int:
	var ev: Dictionary = eventos.get(evento, {})
	var cs: Array = ev.get("camadas", [])
	if cs.is_empty():
		return 0
	var g: Dictionary = grupos.get(cs[0]["grupo"], {})
	# escolhe já o arquivo da primeira camada para saber onde está o pico dele
	var i := escolher(cs[0]["grupo"], cs[0].get("indices", []))
	var pico: float = g.get("pico_em_s", [0.0])[maxi(i, 0)] / maxf(float(cs[0].get("pitch", 1.0)), 0.01)
	var atraso := segundos_ate_contato - antecipacao_s - pico
	var o := opcoes.duplicate()
	o["indice0"] = i
	if atraso >= 0.0:
		o["atraso_s"] = atraso
	else:
		o["desde_s"] = minf(-atraso, pico)
	return tocar(evento, posicao, peso, o)


## Para todas as vozes de um id (de tocar()) com fade.
func parar(id: int, fade_s := 0.08) -> void:
	for p in _vozes.keys():
		if _vozes[p]["id"] == id:
			_soltar(p, fade_s)
	_agendados = _agendados.filter(func(c): return c["id"] != id)


## Para tudo (troca de cena, morte da equipe). Música e ambiente do AmbienteCaverna não são afetados.
func parar_tudo(fade_s := 0.1) -> void:
	_agendados.clear()
	for p in _vozes.keys():
		_soltar(p, fade_s)


func mover(id: int, posicao: Variant) -> void:
	for p in _vozes.keys():
		if _vozes[p]["id"] == id:
			p.set("global_position", posicao)


## Hit-stop: as outras vozes de SFX descem de pitch e voltam quando o tempo volta.
func iniciar_hit_stop(duracao_s: float, fator := 0.82, exceto_id := -1) -> void:
	_hit_stop_ate = Time.get_ticks_msec() + int(duracao_s * 1000.0)
	_hit_stop_fator = fator
	for p in _vozes.keys():
		var v: Dictionary = _vozes[p]
		v["hit_stop"] = v["id"] != exceto_id


## Câmera lenta manual (0.3..1). Se seguir_time_scale estiver ligado, usa o menor dos dois.
func definir_camera_lenta(fator: float) -> void:
	_camera_lenta = clampf(fator, 0.3, 1.0)


## Tamanho do espaço: 0 = túnel apertado, 1 = salão/abismo amplo. Ajusta o reverb de caverna.
func definir_espaco(amplitude: float) -> void:
	amplitude = clampf(amplitude, 0.0, 1.0)
	if _bus_caverna >= 0 and AudioServer.get_bus_effect_count(_bus_caverna) > 0:
		var r := AudioServer.get_bus_effect(_bus_caverna, 0) as AudioEffectReverb
		if r:
			r.room_size = lerpf(0.35, 0.95, amplitude)
			r.damping = lerpf(0.7, 0.35, amplitude)
			r.predelay_msec = lerpf(8.0, 70.0, amplitude)
			r.predelay_feedback = lerpf(0.2, 0.5, amplitude)
	_garantir_area_reverb()
	if _area_reverb:
		_area_reverb.reverb_bus_amount = lerpf(0.12, 0.6, amplitude)


## Som abafado (debaixo d'água, atordoado, menu de pausa). Afeta tudo menos música e UI.
func abafar(ativo: bool, corte_hz := 700.0) -> void:
	_abafado_alvo = corte_hz if ativo else 20000.0
	if ativo and _bus_mundo >= 0:
		AudioServer.set_bus_effect_enabled(_bus_mundo, 0, true)


func tocar_musica(nome: String, crossfade_s := 2.5, indice := -1) -> void:
	var lista: Array = musicas.get(nome, [])
	if lista.is_empty():
		return
	if not _desbloqueado:
		_pendentes.append(["__musica", nome, crossfade_s, indice])
		return
	var i := indice if indice >= 0 else _rng.randi() % lista.size()
	var s := stream(lista[i], true)
	var novo := _musica_b if _musica_a.playing else _musica_a
	var velho := _musica_a if novo == _musica_b else _musica_b
	novo.stream = s
	novo.volume_db = -40.0
	novo.play()
	var t := create_tween().set_ignore_time_scale(true).set_parallel(true)
	t.tween_property(novo, "volume_db", 0.0, crossfade_s)
	if velho.playing:
		t.tween_property(velho, "volume_db", -60.0, crossfade_s)
		t.chain().tween_callback(velho.stop)
	_musica_atual = nome


func vozes_ativas() -> int:
	return _vozes.size()


# ------------------------------------------------------------------ interno
func _garantir_area_reverb() -> void:
	if _area_reverb or not is_inside_tree():
		return
	# Área enorme que manda todas as vozes 3D para o bus Caverna (envio de reverb).
	# Áreas Area3D colocadas no nível (mesma camada 20, prioridade maior) sobrescrevem esta.
	_area_reverb = Area3D.new()
	_area_reverb.name = "ReverbGlobal"
	_area_reverb.collision_layer = CAMADA_REVERB
	_area_reverb.collision_mask = 0
	_area_reverb.monitoring = false
	_area_reverb.priority = -100
	_area_reverb.reverb_bus_enabled = true
	_area_reverb.reverb_bus_name = &"Caverna"
	_area_reverb.reverb_bus_amount = 0.3
	_area_reverb.reverb_bus_uniformity = 0.4
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(4000, 4000, 4000)
	cs.shape = b
	_area_reverb.add_child(cs)
	add_child(_area_reverb)


func _pool_para(posicao: Variant) -> Array:
	if posicao is Vector3:
		return _pool3d
	if posicao is Vector2:
		return _pool2d
	return _pool_plano


func _iniciar(c: Dictionary) -> void:
	var ev: Dictionary = c["ev"]
	var evento: String = c["evento"]
	var prio: int = ev.get("prioridade", 5)
	# limite de vozes por evento: rouba a mais antiga do mesmo evento
	var max_v: int = ev.get("max_vozes", 4)
	var mesmas: Array = []
	for p in _vozes:
		if _vozes[p]["evento"] == evento and _vozes[p]["grupo_voz"] == c["grupo"]:
			mesmas.append(p)
	if mesmas.size() >= max_v:
		mesmas.sort_custom(func(a, b): return _vozes[a]["inicio"] < _vozes[b]["inicio"])
		_soltar(mesmas[0], 0.03)
	var pool := _pool_para(c["posicao"])
	var player: Node = null
	for p in pool:
		if not _vozes.has(p) and not p.playing:
			player = p
			break
	if player == null:
		# rouba a voz de menor prioridade (empate: a mais antiga), se não for mais importante que esta
		var pior: Node = null
		for p in pool:
			if not _vozes.has(p):
				continue
			if pior == null or _vozes[p]["prioridade"] < _vozes[pior]["prioridade"] \
					or (_vozes[p]["prioridade"] == _vozes[pior]["prioridade"] and _vozes[p]["inicio"] < _vozes[pior]["inicio"]):
				pior = p
		if pior == null or _vozes[pior]["prioridade"] > prio:
			return
		_vozes.erase(pior)
		pior.stop()
		player = pior
	var g: Dictionary = grupos[c["grupo"]]
	var s := stream(g["arquivos"][c["indice"]], c["laco"])
	if s == null:
		return
	player.stream = s
	player.bus = StringName(ev.get("bus", "SFX"))
	player.volume_db = c["vol"]
	player.pitch_scale = maxf(0.05, c["pitch"] * _fator_tempo())
	if c["posicao"] is Vector3 or c["posicao"] is Vector2:
		player.set("global_position", c["posicao"])
	var desde: float = c.get("desde_s", 0.0)
	player.play(desde)
	_vozes[player] = {"evento": evento, "prioridade": prio, "inicio": Time.get_ticks_msec(), "pitch_base": c["pitch"],
		"id": c["id"], "grupo_voz": c["grupo"], "seguir": c["seguir"], "hit_stop": false,
		"fim": Time.get_ticks_msec() + int(float(c["max_s"]) * 1000.0 / maxf(c["pitch"], 0.05)) if float(c["max_s"]) > 0.0 else 0}


func _soltar(p: Node, fade_s: float) -> void:
	_vozes.erase(p)
	if fade_s <= 0.0:
		p.stop()
		return
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(p, "volume_db", -60.0, fade_s)
	t.tween_callback(p.stop)


func _ao_terminar(p: Node) -> void:
	_vozes.erase(p)


func _duck(db: float, ms: int) -> void:
	if db >= 0.0 or ms <= 0:
		return
	_duck_alvo = minf(_duck_alvo, db)
	_duck_ate = maxi(_duck_ate, Time.get_ticks_msec() + ms)


func _fator_tempo() -> float:
	var f := _camera_lenta
	if seguir_time_scale:
		f = minf(f, clampf(lerpf(1.0, Engine.time_scale, 0.6), 0.55, 1.0))
	return f


var _ultimo_us := 0


func _process(_delta: float) -> void:
	var agora_us := Time.get_ticks_usec()
	# tempo real (o hit-stop costuma zerar o Engine.time_scale, e o ducking não pode congelar)
	var delta := clampf((agora_us - _ultimo_us) / 1000000.0, 0.0, 0.1) if _ultimo_us > 0 else 0.016
	_ultimo_us = agora_us
	var agora := Time.get_ticks_msec()
	# camadas atrasadas
	if not _agendados.is_empty():
		var resto: Array = []
		for c in _agendados:
			if agora_us >= int(c["quando"]):
				_iniciar(c)
			else:
				resto.append(c)
		_agendados = resto
	# ducking do ambiente/música: ataque rápido, volta suave
	if agora > _duck_ate:
		_duck_alvo = 0.0
	var vel := 60.0 if _duck_alvo < _duck_db else 9.0
	_duck_db = move_toward(_duck_db, _duck_alvo, vel * delta)
	if _bus_amb >= 0:
		AudioServer.set_bus_volume_db(_bus_amb, _vol_amb_base + _duck_db)
	if _bus_mus >= 0:
		AudioServer.set_bus_volume_db(_bus_mus, _vol_mus_base + _duck_db * 0.5)
	# filtro abafado
	if _bus_mundo >= 0 and absf(_abafado_atual - _abafado_alvo) > 1.0:
		_abafado_atual = lerpf(_abafado_atual, _abafado_alvo, clampf(delta * 8.0, 0.0, 1.0))
		var lp := AudioServer.get_bus_effect(_bus_mundo, 0) as AudioEffectLowPassFilter
		if lp:
			lp.cutoff_hz = _abafado_atual
		if _abafado_alvo >= 20000.0 and _abafado_atual > 18000.0:
			AudioServer.set_bus_effect_enabled(_bus_mundo, 0, false)
	# pitch: hit-stop e câmera lenta; seguir nós; cortar camadas com max_s
	var hs := agora < _hit_stop_ate
	var ft := _fator_tempo()
	for p in _vozes.keys():
		var v: Dictionary = _vozes[p]
		var f := ft
		if hs and v["hit_stop"]:
			f *= _hit_stop_fator
		elif not hs:
			v["hit_stop"] = false
		p.pitch_scale = maxf(0.05, float(v["pitch_base"]) * f)
		var s: Variant = v["seguir"]
		if s != null and is_instance_valid(s):
			p.set("global_position", s.get("global_position"))
		if int(v["fim"]) > 0 and agora >= int(v["fim"]):
			_soltar(p, 0.04)


func _input(e: InputEvent) -> void:
	if _desbloqueado:
		return
	if e is InputEventScreenTouch or e is InputEventMouseButton or e is InputEventKey:
		if not e.is_pressed():
			return
		# Primeiro gesto do usuário: o navegador libera o AudioContext. Só então tocamos o que ficou pendente.
		_desbloqueado = true
		var pend := _pendentes
		_pendentes = []
		for q in pend:
			if q[0] == "__musica":
				tocar_musica(q[1], q[2], q[3])
			else:
				tocar(q[0], q[1], q[2], q[3])


## Para testes e para o desktop: força o estado de desbloqueio.
func desbloquear() -> void:
	if not _desbloqueado:
		var e := InputEventMouseButton.new()
		e.pressed = true
		_input(e)
