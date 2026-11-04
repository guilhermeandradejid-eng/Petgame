class_name PostFX
extends Node
## Controla o shader de pós-processamento de cada câmera (shaders/post.gdshader):
## liga/desliga efeitos conforme as opções, anima os pulsos das pancadas e
## acompanha o sol na tela para os raios de luz. Roda mesmo com o jogo pausado
## (o desfoque da pausa entra e sai suave).

const SHADER := preload("res://shaders/post.gdshader")
const SUN_DIR := Vector3(-0.75, 0.32, -0.58)   # o mesmo do shaders/sky.gdshader
const MOON_DIR := Vector3(0.42, 0.32, -0.85)

var main: Node
var mats: Array[ShaderMaterial] = []
var impact := 0.0
var impact_pos := Vector3.ZERO
var flash := 0.0
var replay := 0.0
var blur := 0.0
var t := 0.0
# iluminação dinâmica (parâmetros globais dos shaders, ver shaders/lighting.gdshaderinc)
var hl := 0.0
var hl_pos := Vector3.ZERO
var warmth := 0.0


func _init(m: Node) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS


## Cria o material de uma SubViewportContainer
func attach(svc: SubViewportContainer) -> void:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	svc.material = m
	mats.append(m)
	apply()


## Pancada (smash, especial, bloqueio): zoom radial + aberração cromática no ponto
func kick(pos: Vector3, strength: float, flash_amount := 0.0) -> void:
	if not Settings.impact_fx:
		return
	impact = maxf(impact, clampf(strength, 0.0, 1.0) * 0.6)  # suave
	impact_pos = pos
	flash = maxf(flash, flash_amount * 0.5)


## Luz rápida de uma batida (cor do golpe, mais forte nas pancadas)
func light(pos: Vector3, color: Color, size: float) -> void:
	var k := clampf(0.35 + size * 0.3, 0.0, 1.0)
	if k < hl * 0.7:
		return
	hl = k
	hl_pos = pos
	var c := Color(1.0, 0.9, 0.7).lerp(color, 0.55)
	RenderingServer.global_shader_parameter_set("hit_light_color", c)


func _update_lighting(dt: float) -> void:
	if hl > 0.0:
		hl = move_toward(hl, 0.0, dt * 3.5)
		RenderingServer.global_shader_parameter_set("hit_light", Vector4(hl_pos.x, hl_pos.y, hl_pos.z, hl * hl))
	# o sol vai baixando durante a partida: começa à tarde e termina no pôr do sol
	var target := 0.25
	if not main.demo:
		var g: Array = main.games
		var total := float(g[0] + g[1]) + float(main.points[0] + main.points[1]) * 0.2
		target = clampf(total / maxf(float(main.games_to_win) * 2.0 - 1.0, 1.0), 0.0, 1.0)
	var w := move_toward(warmth, target, dt * 0.05)
	if absf(w - warmth) > 0.0005 or t < 0.1:
		warmth = w
		RenderingServer.global_shader_parameter_set("sun_warmth", warmth)


## Reaplica as opções nos materiais e nas viewports
func apply() -> void:
	var on := Settings.postfx
	var q := Settings.quality
	# bloom: glow nativo (gaussiano) só nas partes bem claras: sol, espuma, faíscas, especiais
	var we := main.world.get_child(0) as WorldEnvironment if main.world else null
	if we and we.environment:
		var env := we.environment
		env.glow_enabled = on and Settings.bloom
		env.glow_intensity = 0.32
		env.glow_strength = 1.0
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = 0.94
		env.glow_hdr_scale = 2.0
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		for lv in 7:
			env.set_glow_level(lv, 0.0)
		env.set_glow_level(1, 0.6)
		env.set_glow_level(2, 0.8)
		env.set_glow_level(3, 1.0 if q >= 1 else 0.0)
		env.set_glow_level(4, 0.7 if q >= 2 else 0.0)
	for m in mats:
		m.set_shader_parameter("quality", q)
		m.set_shader_parameter("rays_amount", 0.22 if on and Settings.sun_rays else 0.0)
		m.set_shader_parameter("sharpen", 0.1 if on and q > 0 else 0.0)
		m.set_shader_parameter("vignette", 0.15 if on and Settings.vignette else 0.0)
		m.set_shader_parameter("grain", 0.02 if on and Settings.grain else 0.0)
		if on and Settings.color_grade:
			m.set_shader_parameter("exposure", 1.0)
			# cores vivas e limpas de aventura (sombras levemente azuis, luz neutra)
			m.set_shader_parameter("contrast", 1.0)
			m.set_shader_parameter("saturation", 1.04)
			m.set_shader_parameter("shadow_tint", Vector3(0.99, 0.99, 1.02))
			m.set_shader_parameter("highlight_tint", Vector3(1.01, 1.0, 0.98))
		else:
			m.set_shader_parameter("exposure", 1.0)
			m.set_shader_parameter("contrast", 1.0)
			m.set_shader_parameter("saturation", 1.0)
			m.set_shader_parameter("shadow_tint", Vector3.ONE)
			m.set_shader_parameter("highlight_tint", Vector3.ONE)


func _process(dt: float) -> void:
	t += dt
	if not main.get_tree().paused:
		_update_lighting(dt)
	impact = move_toward(impact, 0.0, dt * 3.2)
	flash = move_toward(flash, 0.0, dt * 2.6)
	var want_replay := 1.0 if (main.is_replay() and Settings.postfx) else 0.0
	replay = move_toward(replay, want_replay, dt * 3.0)
	var paused: bool = main.get_tree().paused
	blur = move_toward(blur, 1.0 if paused and Settings.postfx else 0.0, dt * 5.0)
	var views: Array = main.views
	for i in mini(views.size(), mats.size()):
		var v: Dictionary = views[i]
		var svc: SubViewportContainer = v["svc"]
		if not svc.visible:
			continue
		var m := mats[i]
		var cam: Camera3D = v["cam"]
		m.set_shader_parameter("time_s", t)
		m.set_shader_parameter("impact", impact)
		m.set_shader_parameter("flash", flash)
		m.set_shader_parameter("replay", replay)
		m.set_shader_parameter("blur", blur)
		var vp_size := (v["sv"] as SubViewport).size
		if vp_size.x <= 0 or vp_size.y <= 0:
			continue
		var vs := Vector2(vp_size)
		if impact > 0.0 and not cam.is_position_behind(impact_pos):
			m.set_shader_parameter("impact_uv", cam.unproject_position(impact_pos) / vs)
		# sol na tela (some quando sai do quadro ou fica atrás da câmera)
		# à noite os raios saem da lua (mais fracos)
		var night: bool = main.world != null and main.world.night
		var sdir := MOON_DIR if night else SUN_DIR
		var sun_world := cam.global_position + sdir.normalized() * 400.0
		var vis := 0.0
		if not cam.is_position_behind(sun_world):
			var suv := cam.unproject_position(sun_world) / vs
			var edge := minf(minf(suv.x + 0.25, 1.25 - suv.x), minf(suv.y + 0.25, 1.25 - suv.y))
			vis = clampf(edge / 0.3, 0.0, 1.0)
			var fwd := -cam.global_transform.basis.z
			vis *= clampf(fwd.dot(sdir.normalized()) * 2.0, 0.0, 1.0) * (0.6 if night else 1.0)
			m.set_shader_parameter("sun_uv", suv)
		m.set_shader_parameter("sun_vis", vis)

