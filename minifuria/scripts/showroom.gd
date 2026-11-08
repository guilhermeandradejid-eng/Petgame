class_name Showroom
extends Control
## Vitrine 3D (garagem e menu principal): estúdio próprio num SubViewport, com ciclorama escuro (shader de céu com
## "softboxes" que só aparecem nos reflexos), piso envernizado semitransparente com o carro espelhado por baixo,
## plataforma giratória com anel de LEDs, luz principal com sombra, recortes coloridos e câmera em órbita que
## aproxima da peça em foco. O carro é o Car de verdade (mesmo kit, armas e pneus da corrida).
## Também tem uma "cabine de fotos" que tira as miniaturas (carros, peças do kit, armas): uma por quadro, em cache.

const FOV := 30.0
const TABLE_R := 3.3
## câmera por peça em foco: giro da plataforma (yaw), inclinação, distância relativa e alvo (fração do carro)
const FOCUS := {
	"": {"yaw": -0.65, "pitch": 0.3, "dist": 1.0, "tgt": Vector3(0.0, 0.55, 0.0)},
	"engine": {"yaw": -0.55, "pitch": 0.45, "dist": 0.9, "tgt": Vector3(0.0, 0.75, 0.25)},
	"armor": {"yaw": -1.2, "pitch": 0.24, "dist": 0.92, "tgt": Vector3(0.3, 0.55, 0.1)},
	"tires": {"yaw": -1.1, "pitch": 0.18, "dist": 0.86, "tgt": Vector3(0.45, 0.45, 0.35)},
	"rear": {"yaw": -2.9, "pitch": 0.24, "dist": 0.9, "tgt": Vector3(0.0, 0.55, -0.45)},
	"wpn": {"yaw": -0.5, "pitch": 0.32, "dist": 0.9, "tgt": Vector3(0.0, 0.95, 0.0)},
	"tier": {"yaw": -2.35, "pitch": 0.32, "dist": 0.95, "tgt": Vector3(0.0, 0.7, -0.2)},
}
const THUMB_COLORS := {"faisca": "#e8352b", "vespa": "#2f6fd6", "zefiro": "#e8f0ff", "trovao": "#ffd23a", "jacare": "#5a7a32",
	"escorpiao": "#d9822b", "monstro": "#33c46b", "nevasca": "#f2f5fa", "nemesis": "#7b2cff", "falcao": "#2ec4ff"}

static var _thumbs := {}

var game: Node
var lib: Node3D
var vp: SubViewport
var svc: SubViewportContainer
var cam: Camera3D
var key_light: DirectionalLight3D
var spin: Node3D
var mirror_root: Node3D
var car: Car
var floor_mat: ShaderMaterial
var sky_mat: ShaderMaterial
var name3d: Label3D
var sub3d: Label3D
var env: Environment
var accent := Color("#ffb21a")
var frame_off := Vector2.ZERO   # centro do carro na tela (fração da tela, + = direita/baixo)
var size_k := 1.0               # > 1 = carro menor na tela (mais longe)
var focus_key := ""
var auto_spin := true
var yaw := -0.65
var yaw_vel := 0.0
var _pitch := 0.3
var _dist := 1.0
var _tgt := Vector3(0, 0.55, 0)
var _idle := 0.0
var _drag := false
var _pulse := 0.0
var _mirror_dirty := false
var _cur := {}
var _on := false
# cabine de fotos (miniaturas)
var booth: SubViewport
var booth_cam: Camera3D
var stage: Node3D
var _queue: Array = []
var _job := {}
var _job_wait := 0


func setup(g: Node) -> void:
	game = g
	lib = g.lib
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.physics_object_picking = false
	svc.add_child(vp)
	_build_studio()
	_build_booth()
	set_process(false)


func _build_studio() -> void:
	var root3 := Node3D.new()
	vp.add_child(root3)
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/showroom_sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	root3.add_child(we)
	key_light = DirectionalLight3D.new()
	key_light.rotation = Vector3(deg_to_rad(-52), deg_to_rad(28), 0)
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key_light.directional_shadow_max_distance = 22.0
	key_light.shadow_blur = 1.6
	key_light.shadow_opacity = 0.85
	root3.add_child(key_light)
	# recortes coloridos atrás do carro (frio à esquerda, quente à direita) e luz de cima
	for it in [[Vector3(-5.5, 5.5, -6.5), Color("#2ee6ff"), 10.0], [Vector3(5.5, 5.0, -6.0), Color("#ffb21a"), 8.0]]:
		var sl := SpotLight3D.new()
		sl.light_color = it[1]
		sl.light_energy = it[2]
		sl.spot_range = 13.0
		sl.spot_angle = 24.0
		sl.spot_attenuation = 0.8
		sl.light_cull_mask = 1
		root3.add_child(sl)
		sl.look_at_from_position(it[0], Vector3(0, 0.6, 0))
	var top := SpotLight3D.new()
	top.light_energy = 5.0
	top.spot_range = 14.0
	top.spot_angle = 34.0
	top.position = Vector3(0, 9.0, 0.5)
	top.rotation = Vector3(-PI / 2, 0, 0)
	root3.add_child(top)
	# piso + plataforma (um plano grande com shader) e o carro espelhado por baixo
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	fl.mesh = pm
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = preload("res://shaders/showroom_floor.gdshader")
	floor_mat.set_shader_parameter("table_r", TABLE_R)
	fl.material_override = floor_mat
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fl.layers = 2
	root3.add_child(fl)
	spin = Node3D.new()
	root3.add_child(spin)
	mirror_root = Node3D.new()
	mirror_root.scale = Vector3(1, -1, 1)
	mirror_root.process_mode = Node.PROCESS_MODE_DISABLED
	spin.add_child(mirror_root)
	# nome gigante do carro atrás dele (no próprio 3D: acompanha a perspectiva)
	name3d = Label3D.new()
	name3d.font = UI.display_it
	name3d.font_size = 220
	name3d.pixel_size = 0.018
	name3d.outline_size = 0
	name3d.modulate = Color(1, 1, 1, 0.06)
	name3d.position = Vector3(0, 1.25, -9.0)
	name3d.double_sided = false
	root3.add_child(name3d)
	sub3d = Label3D.new()
	sub3d.font = UI.body_bold
	sub3d.font_size = 64
	sub3d.pixel_size = 0.012
	sub3d.outline_size = 0
	sub3d.modulate = Color(1, 0.75, 0.2, 0.22)
	sub3d.position = Vector3(0, -0.6, -8.9)
	sub3d.visible = false
	root3.add_child(sub3d)
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.1
	cam.far = 200.0
	root3.add_child(cam)
	cam.current = true
	set_accent(accent)


func _build_booth() -> void:
	booth = SubViewport.new()
	booth.own_world_3d = true
	booth.transparent_bg = true
	booth.size = Vector2i(320, 200)
	booth.msaa_3d = Viewport.MSAA_4X
	booth.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(booth)
	var r3 := Node3D.new()
	booth.add_child(r3)
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 1.25
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.1
	var we := WorldEnvironment.new()
	we.environment = e
	r3.add_child(we)
	var kl := DirectionalLight3D.new()
	kl.rotation = Vector3(deg_to_rad(-48), deg_to_rad(35), 0)
	kl.light_energy = 1.5
	r3.add_child(kl)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-15), deg_to_rad(-140), 0)
	fill.light_energy = 0.6
	fill.light_color = Color("#9fdcff")
	r3.add_child(fill)
	stage = Node3D.new()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	r3.add_child(stage)
	booth_cam = Camera3D.new()
	booth_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	r3.add_child(booth_cam)
	booth_cam.current = true


# ------------------------------------------------------------------ ligar / desligar
## liga a vitrine (o 3D da pista para de desenhar enquanto ela está na tela) e ajusta os reflexos para o estúdio
func activate(on: bool) -> void:
	if on == _on:
		return
	_on = on
	visible = on
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	set_process(on or not _queue.is_empty())
	if game:
		game.get_viewport().disable_3d = on
		if on:
			_studio_reflections()
		elif game.theme:
			game._refl_theme()


func _studio_reflections() -> void:
	var sd := key_light.global_transform.basis.z.normalized() if key_light.is_inside_tree() else Vector3(0.4, 0.75, 0.5)
	for kind in ["paint", "glass", "chrome"]:
		var m: ShaderMaterial = game._refl(kind)
		m.set_shader_parameter("sky_top", Color(0.5, 0.5, 0.56))
		m.set_shader_parameter("sky_hor", Color(0.8, 0.8, 0.88))
		m.set_shader_parameter("ground_col", Color(0.03, 0.03, 0.05))
		m.set_shader_parameter("sun_col", Color(1.0, 0.97, 0.92))
		m.set_shader_parameter("sun_dir", sd)
		m.set_shader_parameter("night", 0.0)
	Car.refl_metal = game._refl("chrome")


func set_accent(c: Color) -> void:
	accent = c
	floor_mat.set_shader_parameter("accent", c)
	sky_mat.set_shader_parameter("accent", c)


# ------------------------------------------------------------------ carro
## mostra um carro (kind, cor, armas, upgrades). Se só os upgrades/cor mudaram, remonta o kit sem trocar o carro.
func show_car(kind: String, col: Color, front: String, rear: String, nitro: String, up: Dictionary, special := "", pop := true) -> void:
	var cfg := {"kind": kind, "col": col, "front": front, "rear": rear, "nitro": nitro, "up": up.duplicate(), "special": special}
	if car and is_instance_valid(car) and String(_cur.get("kind", "")) == kind:
		if cfg.hash() == _cur.hash():
			return
		_cur = cfg
		if car.color != col:
			car.color = col
			if car.paint:
				(car.paint as StandardMaterial3D).albedo_color = col
		car.configure(lib, front, rear, nitro, up, special)
		_mirror_dirty = true
		return
	_cur = cfg
	if car and is_instance_valid(car):
		car.queue_free()
	car = Car.new()
	car.process_mode = Node.PROCESS_MODE_DISABLED
	spin.add_child(car)
	car.setup(lib, kind, "rival", col)
	car.configure(lib, front, rear, nitro, up, special)
	car.freeze = true
	car.position = Vector3.ZERO
	_mirror_dirty = true
	var nm: String = Car.CAR_NAME.get(kind, kind.to_upper())
	name3d.text = nm
	sub3d.text = String(Career.SHOP[kind].get("class", "")) if Career.SHOP.has(kind) else ""
	_make_exhaust_fx()
	if not pop:
		return
	# entrada do carro: cai na plataforma com um "quique" e o anel pisca
	spin.scale = Vector3(0.82, 0.82, 0.82)
	spin.position.y = 0.6
	var tw := create_tween().set_parallel()
	tw.tween_property(spin, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(spin, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pulse = 1.0


## brilho no anel (compra de upgrade, troca de cor)
func flash() -> void:
	_pulse = 1.0
	var tw := create_tween()
	spin.scale = Vector3(1.04, 0.94, 1.04)
	tw.tween_property(spin, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func set_focus(k: String) -> void:
	focus_key = k if FOCUS.has(k) else ""
	_idle = 0.0


## peças do kit ligadas ao upgrade em foco (para piscar na vitrine)
func _rebuild_mirror() -> void:
	for ch in mirror_root.get_children():
		ch.queue_free()
	if car == null or car.model == null:
		return
	var dup := car.model.duplicate() as Node3D
	mirror_root.add_child(dup)


# ------------------------------------------------------------------ quadro a quadro
func _process(dt: float) -> void:
	_booth_step()
	if not _on:
		if _queue.is_empty() and _job.is_empty():
			set_process(false)
		return
	if _mirror_dirty:
		_mirror_dirty = false
		_rebuild_mirror()
	var f: Dictionary = FOCUS[focus_key]
	_idle += dt
	if not parade.is_empty():
		_parade_step(dt)
	if _phase != "" and not _drag:
		pass   # alinhar/sair/entrar: o desfile cuida do giro
	elif not _drag:
		if focus_key == "" and auto_spin and _idle > 1.2:
			yaw_vel = lerpf(yaw_vel, 0.22, dt * 1.5)
		elif focus_key != "":
			# gira a plataforma até mostrar a peça em foco (pelo caminho mais curto)
			var want: float = f.yaw
			var d := wrapf(want - yaw, -PI, PI)
			yaw_vel = lerpf(yaw_vel, d * 3.0, dt * 6.0)
		else:
			yaw_vel = lerpf(yaw_vel, 0.0, dt * 3.0)
	yaw += yaw_vel * dt
	spin.rotation.y = yaw
	floor_mat.set_shader_parameter("table_ang", -yaw)
	_pulse = maxf(0.0, _pulse - dt * 1.6)
	floor_mat.set_shader_parameter("pulse", _pulse)
	# câmera: distância pelo tamanho do carro, alvo na peça em foco (no espaço do carro, girando com ele)
	var L := 4.2
	var W := 2.1
	if car:
		L = float(car.sp.len) / car.vscale
		W = float(car.sp.wid) / car.vscale
	var base_d := (L * 2.55 + 2.0) * size_k
	var k := minf(1.0, dt * 4.0)
	_pitch = lerpf(_pitch, float(f.pitch), k)
	_dist = lerpf(_dist, float(f.dist), k)
	var tl: Vector3 = f.tgt
	var tw := Vector3(tl.x * W * 0.5, tl.y, tl.z * L * 0.5)
	if focus_key != "":
		tw = spin.transform.basis * tw
	_tgt = _tgt.lerp(tw, k)
	var d3 := base_d * _dist
	var cy := 0.0
	var pp := _pitch
	if not parade.is_empty():
		# câmera de vitrine: passeia devagar em volta, sobe/desce e respira a distância
		_cam_t += dt
		cy = 0.32 * sin(_cam_t * 0.16)
		pp += 0.09 * sin(_cam_t * 0.23 + 0.7)
		d3 *= 1.0 + 0.08 * sin(_cam_t * 0.13 + 1.9)
	var dir := Vector3(sin(cy) * cos(pp), sin(pp), cos(cy) * cos(pp))
	cam.position = _tgt + dir * d3
	cam.look_at(_tgt, Vector3.UP)
	# tela mais "quadrada" que 16:9 (tablet): mantém a largura do enquadramento, para o carro não crescer
	var asp := float(vp.size.x) / maxf(1.0, float(vp.size.y))
	var tv := tan(deg_to_rad(FOV) * 0.5)
	if asp < 16.0 / 9.0:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = rad_to_deg(2.0 * atan(tv * 16.0 / 9.0))
		tv = tv * (16.0 / 9.0) / asp
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = FOV
	# desloca o carro na tela para caber entre os painéis
	var half_h := d3 * tv
	cam.h_offset = -frame_off.x * 2.0 * half_h * asp
	cam.v_offset = frame_off.y * 2.0 * half_h


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
		_idle = 0.0
	elif ev is InputEventMouseMotion and _drag:
		yaw_vel = 0.0
		yaw += ev.relative.x * 0.01
		_idle = 0.0
		if focus_key != "":
			focus_key = ""


# ------------------------------------------------------------------ miniaturas
## pede a miniatura 'key' (car:<tipo>, part:<peça>, tire:<tipo>, wpn:<arma>, mesh:<nó>) para um TextureRect
func thumb(key: String, target: TextureRect) -> void:
	if _thumbs.has(key):
		target.texture = _thumbs[key]
		return
	target.texture = null
	if String(_job.get("key", "")) == key:
		_job.targets.append(target)
		return
	for j in _queue:
		if j.key == key:
			j.targets.append(target)
			return
	_queue.append({"key": key, "targets": [target]})
	set_process(true)


func _booth_step() -> void:
	if _job.is_empty():
		if _queue.is_empty():
			return
		_job = _queue.pop_front()
		for ch in stage.get_children():
			ch.queue_free()
		var n := _booth_build(String(_job.key))
		if n == null:
			_job = {}
			return
		stage.add_child(n)
		_booth_frame(n, String(_job.key))
		_job_wait = 3
		return
	_job_wait -= 1
	if _job_wait == 2:
		# a câmera e a peça nova chegam ao servidor de render no quadro seguinte: só então pede a foto
		booth.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _job_wait > 0:
		return
	var img := booth.get_texture().get_image()
	if OS.get_cmdline_user_args().has("--thumbdump"):
		img.save_png("user://thumb_%s.png" % String(_job.key).replace(":", "_"))
	var tex := ImageTexture.create_from_image(img)
	_thumbs[_job.key] = tex
	for t in _job.targets:
		if is_instance_valid(t):
			(t as TextureRect).texture = tex
	_job = {}


func _booth_build(key: String) -> Node3D:
	var parts := key.split(":")
	match parts[0]:
		"car":
			var k := parts[1]
			var c := Car.new()
			c.process_mode = Node.PROCESS_MODE_DISABLED
			c.setup(lib, k, "rival", Color(String(THUMB_COLORS.get(k, "#e8352b"))))
			var lo: Array = Car.LOADOUT.get(k, ["mg", "oil", "short"])
			c.configure(lib, lo[0], lo[1], lo[2], {})
			c.freeze = true
			return c
		"boss":
			var w: Dictionary = Career.WORLDS[int(parts[1])]
			var bc := Car.new()
			bc.process_mode = Node.PROCESS_MODE_DISABLED
			bc.setup(lib, String(w.boss), "rival", Color(String(w.boss_col)))
			bc.configure(lib, "none", "none", "short", {"_tier": 3, "_tire_vis": 3})
			bc.freeze = true
			return bc
		"part", "mesh":
			var src := lib.get_node_or_null(parts[1]) as MeshInstance3D
			if src == null:
				return null
			var mi := MeshInstance3D.new()
			mi.mesh = src.mesh
			var acc := StandardMaterial3D.new()
			acc.albedo_color = Color("#ffcf33")
			acc.roughness = 0.35
			for si in mi.mesh.get_surface_count():
				var sm := mi.mesh.surface_get_material(si)
				if sm and sm.resource_name == "KitAccent":
					mi.set_surface_override_material(si, acc)
				elif sm and sm.resource_name == "Paint":
					var pm := (sm as StandardMaterial3D).duplicate() as StandardMaterial3D
					pm.albedo_color = Color("#e8352b")
					mi.set_surface_override_material(si, pm)
			return mi
		"tire":
			var src := lib.get_node_or_null("tire_" + parts[1]) as MeshInstance3D
			if src == null:
				return null
			var mi := MeshInstance3D.new()
			mi.mesh = src.mesh
			mi.rotation.y = 0.6
			return mi
		"wpn":
			return _turret(parts[1], parts[2] if parts.size() > 2 else "")
	return null


## torre da arma montada como na corrida (base, anel, corpo e peça giratória)
func _turret(front: String, extra: String) -> Node3D:
	var root3 := Node3D.new()
	for pre in ["wb_", "wy_", "wg_", "ws_"]:
		var src := lib.get_node_or_null(pre + front) as MeshInstance3D
		if src == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = src.mesh
		match pre:
			"wy_":
				mi.position = Vector3(0, 0.2, 0)
			"wg_":
				mi.position = Vector3(0, 0.46, 0)
			"ws_":
				var cfg: Dictionary = Car.WPN.get(front, {})
				mi.position = Vector3(0, 0.46, 0) + (cfg.get("spin", Vector3.ZERO) as Vector3)
		root3.add_child(mi)
	if extra != "":
		var src2 := lib.get_node_or_null(extra) as MeshInstance3D
		if src2:
			var e := MeshInstance3D.new()
			e.mesh = src2.mesh
			e.position = Vector3(0.36, 0.5, 0.0)
			if extra == "kit_heatsink":
				e.scale = Vector3(0.42, 0.3, 0.12)
				e.position = Vector3(0, 0.46, 0.05)
			root3.add_child(e)
	root3.rotation.y = 0.0
	return root3


func _booth_frame(n: Node3D, key: String) -> void:
	# câmera ortográfica em 3/4 (frente-direita, de cima), enquadrando a caixa da peça
	var dir := Vector3(1.0, 0.75, 1.25).normalized()
	if key.begins_with("tire:"):
		dir = Vector3(1.0, 0.35, 0.45).normalized()
	var bb := _aabb(n, Transform3D.IDENTITY)
	var c := bb.get_center()
	booth_cam.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), c + dir * 30.0)
	# tamanho: projeta os cantos da caixa no plano da câmera
	var inv := booth_cam.transform.affine_inverse()
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for i in 8:
		var p := inv * bb.get_endpoint(i)
		mn = mn.min(Vector2(p.x, p.y))
		mx = mx.max(Vector2(p.x, p.y))
	var asp := float(booth.size.x) / float(booth.size.y)
	var sz := maxf(mx.y - mn.y, (mx.x - mn.x) / asp) * 1.12
	booth_cam.size = maxf(sz, 0.2)
	var mid := (mn + mx) * 0.5
	booth_cam.position += booth_cam.transform.basis.x * mid.x + booth_cam.transform.basis.y * mid.y


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t := xf * ((n as Node3D).transform if n is Node3D else Transform3D.IDENTITY)
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out = t * (n as MeshInstance3D).get_aabb()
		first = false
	for ch in n.get_children():
		if ch is MeshInstance3D or (ch is Node3D and ch.get_child_count() > 0):
			if ch is GeometryInstance3D and not (ch as GeometryInstance3D).visible:
				continue
			if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is PlaneMesh:
				continue   # brilho do neon no chão
			var b := _aabb(ch, t)
			if b.size != Vector3.ZERO:
				out = b if first else out.merge(b)
				first = false
	return out


## pré-aquece as miniaturas (enquanto o menu está parado): carros, peças, pneus, armas e chefes
func prewarm() -> void:
	var keys: Array = []
	for k in Career.CAR_ORDER:
		keys.append("car:" + k)
	for p in ["kit_scoop", "kit_blower", "kit_blower3", "kit_bullbar", "kit_armor", "kit_dispenser", "kit_drum"]:
		keys.append("part:" + p)
	for t in ["sport", "slick", "knobby"]:
		keys.append("tire:" + t)
	for i in Career.WORLDS.size():
		keys.append("boss:%d" % i)
	for k in keys:
		if not _thumbs.has(k) and _queue.filter(func(j): return j.key == k).is_empty():
			_queue.append({"key": k, "targets": []})
	set_process(true)


# ------------------------------------------------------------------ desfile (menu principal)
## O menu mostra os seus carros (e os da loja liberados) em revezamento: a plataforma alinha o carro, ele
## ronca com estalos no escapamento, acelera e sai pela direita; o próximo entra pela esquerda freando, com as
## lanternas acesas, mergulha o nariz e o anel pisca. A câmera passeia e dois fachos de luz varrem o estúdio.
signal car_changed(entry: Dictionary)

const SHOW_TIME := 6.5
const DRIVE_X := 18.0
var parade: Array = []
var parade_i := 0
var _pt := 0.0
var _phase := ""
var _phase_t := 0.0
var _drive_z := 0.0
var _rev := 0.0
var _revved := false
var _body_pitch := 0.0
var _body_pv := 0.0
var _cam_t := 0.0
var _pops: Array = []
var _pop_light: OmniLight3D
var beams: Array = []


func start_parade(list: Array) -> void:
	parade = list
	parade_i = 0
	_pt = 0.0
	_phase = ""
	_set_drive(0.0)
	if list.is_empty():
		return
	var e: Dictionary = list[0]
	show_car(e.kind, e.col, e.front, e.rear, e.nitro, e.up, e.get("special", ""))
	car_changed.emit(e)
	_beams(true)


func stop_parade() -> void:
	parade = []
	_phase = ""
	_set_drive(0.0)
	_rev = 0.0
	_beams(false)
	if car and is_instance_valid(car) and car.model:
		car.model.position = Vector3.ZERO
		car.model.rotation = Vector3.ZERO
		for s in car.ex_smoke:
			(s as CPUParticles3D).emitting = false


func _set_drive(z: float) -> void:
	_drive_z = z
	if car and is_instance_valid(car):
		car.position = Vector3(0, 0, z)
	for ch in mirror_root.get_children():
		(ch as Node3D).position = Vector3(0, 0, z)


func _parade_step(dt: float) -> void:
	var n := parade.size()
	var speed := 0.0
	match _phase:
		"":
			_pt += dt
			# ronco de vez em quando (mesmo com um carro só)
			if fmod(_pt, 4.0) < dt and _pt > 1.0:
				_rev_blip(0.6)
			if _pt > SHOW_TIME and n > 1:
				_phase = "align"
				_phase_t = 0.0
				_revved = false
		"align":
			_phase_t += dt
			# gira a plataforma até o carro apontar para a direita da tela
			var ty := PI * 0.5
			yaw += wrapf(ty - yaw, -PI, PI) * minf(1.0, dt * 4.5)
			yaw_vel = 0.0
			if _phase_t > 0.6 and not _revved:
				_revved = true
				_rev_blip(1.0)
			if _phase_t > 1.25:
				yaw = ty
				_phase = "out"
				_phase_t = 0.0
				_body_pv -= 0.9   # empina ao arrancar
				if game:
					game.sfx.play("nitro", -14.0, 1.15)
		"out":
			_phase_t += dt
			speed = 30.0 * _phase_t
			_set_drive(0.5 * 30.0 * _phase_t * _phase_t)
			for s in car.ex_smoke:
				(s as CPUParticles3D).emitting = true
			if _drive_z > DRIVE_X:
				parade_i = (parade_i + 1) % n
				var e: Dictionary = parade[parade_i]
				show_car(e.kind, e.col, e.front, e.rear, e.nitro, e.up, e.get("special", ""), false)
				_set_drive(-DRIVE_X)
				_phase = "in"
				_phase_t = 0.0
				car_changed.emit(e)
				if game:
					game.sfx.play("whoosh", -10.0, 0.9)
		"in":
			_phase_t += dt
			var u := clampf(_phase_t / 1.2, 0.0, 1.0)
			_set_drive(-DRIVE_X * pow(1.0 - u, 3.0))
			speed = DRIVE_X * 3.0 * pow(1.0 - u, 2.0) / 1.2
			if car.tail_mat:
				car.tail_mat.emission_energy_multiplier = 6.0 if u > 0.35 else 1.5
			if u >= 1.0:
				_phase = ""
				_pt = 0.0
				_body_pv += 1.1   # mergulha o nariz na freada
				_pulse = 1.0
				if car.tail_mat:
					car.tail_mat.emission_energy_multiplier = 1.5
				if game:
					game.sfx.play("land", -12.0, 1.2)
	# rodas girando, carroceria (mola) e ronco
	if car and is_instance_valid(car) and car.model:
		for w in car.wheels:
			var mi: MeshInstance3D = w.mesh
			mi.rotation.x += speed / maxf(0.2, float(w.r)) * dt
		_body_pv += (-_body_pitch * 60.0 - _body_pv * 7.0) * dt
		_body_pitch += _body_pv * dt
		_rev = maxf(0.0, _rev - dt * 1.4)
		var jit := _rev * 0.014
		car.model.position = Vector3(randf_range(-jit, jit), randf_range(0.0, jit), 0.0)
		car.model.rotation = Vector3(clampf(_body_pitch, -0.12, 0.12) * -0.6 + (-0.04 if _phase == "out" else 0.0), 0.0, sin(_cam_t * 70.0) * _rev * 0.008)
		if _pop_light:
			_pop_light.light_energy = maxf(0.0, _pop_light.light_energy - dt * 30.0)
		if _phase == "":
			for s in car.ex_smoke:
				(s as CPUParticles3D).emitting = _rev > 0.3
	for b in beams:
		var bl: SpotLight3D = b.light
		var ph: float = b.phase
		# inclinado para o fundo do estúdio e varrendo de um lado para o outro
		bl.rotation = Vector3(-PI * 0.5 + 0.5 + 0.2 * sin(_cam_t * 0.5 + ph), 0.75 * sin(_cam_t * 0.33 + ph * 1.7), 0.0)


## ronco: carroceria treme, estalos com chama e clarão nas ponteiras, fumaça
func _rev_blip(k: float) -> void:
	_rev = k
	for p in _pops:
		(p as CPUParticles3D).restart()
		(p as CPUParticles3D).emitting = true
	if _pop_light:
		_pop_light.light_energy = 5.0 * k
	if game:
		game.sfx.play("gun", -16.0 + 4.0 * k, 0.42)
		if k >= 1.0:
			get_tree().create_timer(0.12).timeout.connect(func(): if game: game.sfx.play("gun", -14.0, 0.5))


## chamas dos estalos e o clarão nas ponteiras do escapamento do carro atual
func _make_exhaust_fx() -> void:
	_pops.clear()
	_pop_light = null
	if car == null or car.model == null:
		return
	for s in car.ex_smoke:
		var sm := s as CPUParticles3D
		sm.process_mode = Node.PROCESS_MODE_ALWAYS
		sm.emitting = false
		var p := CPUParticles3D.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.one_shot = true
		p.emitting = false
		p.amount = 10
		p.lifetime = 0.2
		p.explosiveness = 0.9
		p.local_coords = true
		p.position = sm.position
		var m := SphereMesh.new()
		m.radius = 0.09
		m.height = 0.18
		m.radial_segments = 6
		m.rings = 3
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(1.6, 0.8, 0.25)
		m.material = mat
		p.mesh = m
		p.direction = Vector3(0, 0.15, -1)
		p.spread = 18.0
		p.initial_velocity_min = 2.5
		p.initial_velocity_max = 5.0
		p.gravity = Vector3.ZERO
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.5
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
		g.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
		p.color_ramp = g
		car.model.add_child(p)
		_pops.append(p)
	if not car.ex_smoke.is_empty():
		_pop_light = OmniLight3D.new()
		_pop_light.light_color = Color(1.0, 0.55, 0.15)
		_pop_light.omni_range = 3.0
		_pop_light.light_energy = 0.0
		_pop_light.position = (car.ex_smoke[0] as Node3D).position + Vector3(0, 0.2, -0.3)
		car.model.add_child(_pop_light)


## dois fachos de luz (âmbar e ciano) varrendo o estúdio, com o cone visível
func _beams(on: bool) -> void:
	if beams.is_empty() and on:
		var root3: Node3D = spin.get_parent()
		for it in [[Vector3(-5.5, 9.0, -2.5), Color("#ffb21a"), 0.0], [Vector3(5.5, 9.0, -2.0), Color("#2ee6ff"), 2.1]]:
			var sl := SpotLight3D.new()
			sl.position = it[0]
			sl.light_color = it[1]
			sl.light_energy = 4.0
			sl.spot_range = 16.0
			sl.spot_angle = 16.0
			sl.spot_attenuation = 0.6
			root3.add_child(sl)
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.18
			cm.bottom_radius = 2.4
			cm.height = 11.0
			cm.radial_segments = 20
			cm.rings = 1
			cone.mesh = cm
			var bm := ShaderMaterial.new()
			bm.shader = preload("res://shaders/beam.gdshader")
			bm.set_shader_parameter("col", it[1])
			bm.set_shader_parameter("strength", 0.16)
			cone.material_override = bm
			cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cone.rotation = Vector3(PI * 0.5, 0, 0)
			cone.position = Vector3(0, 0, -5.5)
			sl.add_child(cone)
			beams.append({"light": sl, "phase": it[2]})
	for b in beams:
		(b.light as SpotLight3D).visible = on
