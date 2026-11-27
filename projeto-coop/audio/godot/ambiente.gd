extends Node3D
class_name AmbienteCaverna
## Camadas de ambiente da caverna do Plumbdeep.
##
## Coloque um nó AmbienteCaverna na cena do nível. Ele cria:
##  - camas estéreo (sem posição): base da caverna, "respiração" do abismo (volume que sobe e desce
##    lentamente, como um fôlego), vento com rajadas e cama de goteiras;
##  - gotas isoladas com eco em pontos aleatórios em volta do ouvinte (3D);
##  - emissores posicionais em laço nos nós dos grupos abaixo (só os mais próximos tocam):
##      "som_cascata", "som_rio", "som_lanterna", "som_fungo", "som_fervura", "som_poca_eletrica".
## Depende do autoload Som (som.gd) para achar os arquivos em eventos.json.

@export var ativo := true
## 0 = perto da superfície/acampamento, 1 = fundo do abismo (mais respiração, menos base, mais reverb).
@export_range(0.0, 1.0) var profundidade := 0.4
## 0 = túnel, 1 = salão amplo. Repassado ao Som.definir_espaco().
@export_range(0.0, 1.0) var amplitude_espaco := 0.6
@export var volume_camas_db := 0.0
@export var gotas_por_minuto := 28.0
@export var raio_gotas := Vector2(4.0, 16.0)
## Máximo de emissores tocando por tipo (os mais próximos do ouvinte).
@export var max_por_tipo := {"som_cascata": 2, "som_rio": 1, "som_lanterna": 4, "som_fungo": 4, "som_fervura": 2, "som_poca_eletrica": 3}

const TIPOS := {
	"som_cascata": {"evento": "amb_cascata", "unit": 7.0, "max": 55.0, "vol": 0.0},
	"som_rio": {"evento": "amb_rio_subterraneo", "unit": 6.0, "max": 45.0, "vol": -2.0},
	"som_lanterna": {"evento": "lanterna_crepitar", "unit": 1.2, "max": 12.0, "vol": -4.0},
	"som_fungo": {"evento": "fungos_zumbido", "unit": 1.0, "max": 9.0, "vol": -8.0},
	"som_fervura": {"evento": "fervura_laco", "unit": 1.5, "max": 14.0, "vol": -3.0},
	"som_poca_eletrica": {"evento": "corrente_zumbido", "unit": 1.5, "max": 14.0, "vol": -4.0},
}

var _camas := {}            # nome -> AudioStreamPlayer
var _emissores := {}        # Node3D -> AudioStreamPlayer3D
var _t := 0.0
var _fase_resp := 0.0
var _periodo_resp := 9.0
var _rajada := 0.0
var _rajada_alvo := 0.0
var _prox_rajada := 4.0
var _prox_gota := 1.0
var _prox_varredura := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if not ativo:
		return
	var som := _som()
	if som == null:
		push_error("AmbienteCaverna: autoload Som não encontrado")
		return
	som.definir_espaco(amplitude_espaco)
	_cria_cama("base", "amb_caverna_base", -3.0)
	_cria_cama("respiracao", "amb_abismo_respiracao", -2.0)
	_cria_cama("vento", "amb_vento_caverna", -9.0)
	_cria_cama("goteiras", "amb_goteiras", -6.0)
	_periodo_resp = _rng.randf_range(7.0, 11.0)


func _som() -> Node:
	return get_node_or_null("/root/Som")


func _arquivo(evento: String, indice := -1) -> AudioStream:
	var som := _som()
	var ev: Dictionary = som.eventos.get(evento, {})
	if ev.is_empty():
		return null
	var grupo: String = ev["camadas"][0]["grupo"]
	var g: Dictionary = som.grupos[grupo]
	var i: int = indice if indice >= 0 else som.escolher(grupo)
	return som.stream(g["arquivos"][i], true)


func _cria_cama(nome: String, evento: String, vol: float) -> void:
	var s := _arquivo(evento)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = &"Ambiente"
	p.volume_db = vol + volume_camas_db
	p.set_meta("vol_base", vol)
	add_child(p)
	# começa num ponto aleatório para duas salas iguais não soarem idênticas
	p.play(_rng.randf() * maxf(s.get_length() - 1.0, 0.0))
	_camas[nome] = p


func _ouvinte() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else global_position


func _process(delta: float) -> void:
	if not ativo or _som() == null:
		return
	_t += delta
	var p := profundidade
	# respiração do abismo: ciclo lento e assimétrico (inspira mais rápido que expira), mais forte no fundo
	_fase_resp += delta / _periodo_resp
	if _fase_resp >= 1.0:
		_fase_resp -= 1.0
		_periodo_resp = _rng.randf_range(7.0, 11.0)
	var r := pow(sin(PI * _fase_resp), 2.0)  # 0..1
	if _camas.has("respiracao"):
		var prof := lerpf(-12.0, 0.0, p)
		_camas["respiracao"].volume_db = _camas["respiracao"].get_meta("vol_base") + prof + lerpf(-7.0, 1.0, r) + volume_camas_db
		_camas["respiracao"].pitch_scale = lerpf(0.97, 1.02, r)
	if _camas.has("base"):
		_camas["base"].volume_db = _camas["base"].get_meta("vol_base") + lerpf(0.0, -5.0, p) + volume_camas_db
	# rajadas de vento
	_prox_rajada -= delta
	if _prox_rajada <= 0.0:
		_rajada_alvo = _rng.randf_range(0.5, 1.0) if _rajada_alvo < 0.2 else 0.0
		_prox_rajada = _rng.randf_range(2.5, 5.0) if _rajada_alvo > 0.0 else _rng.randf_range(6.0, 16.0)
	_rajada = move_toward(_rajada, _rajada_alvo, delta * (0.45 if _rajada_alvo > _rajada else 0.25))
	if _camas.has("vento"):
		_camas["vento"].volume_db = _camas["vento"].get_meta("vol_base") + _rajada * 8.0 + volume_camas_db
		_camas["vento"].pitch_scale = 1.0 + _rajada * 0.06
	# gotas isoladas em volta do ouvinte
	_prox_gota -= delta
	if _prox_gota <= 0.0 and gotas_por_minuto > 0.0:
		_prox_gota = _rng.randf_range(0.4, 1.6) * 60.0 / gotas_por_minuto
		var ang := _rng.randf() * TAU
		var d := _rng.randf_range(raio_gotas.x, raio_gotas.y)
		var pos := _ouvinte() + Vector3(cos(ang) * d, _rng.randf_range(1.0, 8.0), sin(ang) * d)
		_som().tocar("gota_eco", pos, 1.0, {"volume_db": _rng.randf_range(-6.0, 0.0)})
	# emissores posicionais: varre a cada 0,5 s e liga só os mais próximos de cada tipo
	_prox_varredura -= delta
	if _prox_varredura <= 0.0:
		_prox_varredura = 0.5
		_varre_emissores()


func _varre_emissores() -> void:
	var ouv := _ouvinte()
	for tipo in TIPOS:
		var nos: Array = get_tree().get_nodes_in_group(tipo).filter(func(n): return n is Node3D and n.is_inside_tree())
		nos.sort_custom(func(a, b): return a.global_position.distance_squared_to(ouv) < b.global_position.distance_squared_to(ouv))
		var lim: int = max_por_tipo.get(tipo, 3)
		if OS.has_feature("web"):
			lim = maxi(1, lim / 2)
		var cfg: Dictionary = TIPOS[tipo]
		for i in nos.size():
			var n: Node3D = nos[i]
			var perto := i < lim and n.global_position.distance_to(ouv) < float(cfg["max"])
			if perto and not _emissores.has(n):
				_liga(n, cfg)
			elif not perto and _emissores.has(n):
				_desliga(n)
	for n in _emissores.keys():
		if not is_instance_valid(n):
			var p: Node = _emissores[n]
			_emissores.erase(n)
			if is_instance_valid(p):
				p.queue_free()


func _liga(n: Node3D, cfg: Dictionary) -> void:
	var s := _arquivo(cfg["evento"])
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = &"Ambiente"
	p.unit_size = cfg["unit"]
	p.max_distance = cfg["max"]
	p.volume_db = -40.0
	p.area_mask = 1 << 19
	p.pitch_scale = _rng.randf_range(0.96, 1.04)
	n.add_child(p)
	p.play(_rng.randf() * maxf(s.get_length() - 0.5, 0.0))
	create_tween().tween_property(p, "volume_db", float(cfg["vol"]), 1.2)
	_emissores[n] = p


func _desliga(n: Node3D) -> void:
	var p: AudioStreamPlayer3D = _emissores[n]
	_emissores.erase(n)
	if is_instance_valid(p):
		var t := create_tween()
		t.tween_property(p, "volume_db", -50.0, 1.0)
		t.tween_callback(p.queue_free)


## Muda a profundidade em tempo de jogo (ex.: ao descer de andar).
func definir_profundidade(valor: float) -> void:
	profundidade = clampf(valor, 0.0, 1.0)


func definir_amplitude(valor: float) -> void:
	amplitude_espaco = clampf(valor, 0.0, 1.0)
	if _som():
		_som().definir_espaco(amplitude_espaco)
