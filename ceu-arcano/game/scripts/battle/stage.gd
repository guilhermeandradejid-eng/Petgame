extends Node2D
## Cenário "Jardim das Lanternas Suspensas": céu em shader + camadas renderizadas no Blender
## (stage.json) com parallax e zoom por profundidade, lanternas tremulando, cachoeiras, vagalumes,
## pétalas e clima que muda a cada round.

const DIR := "res://assets/stage/"

var battle
var cfg := {}
var layers: Array = []          # {node, parallax, origin, front}
var ref := Vector2(0, -110)
var sky_layer: CanvasLayer
var sky: ColorRect
var sky_mat: ShaderMaterial
var moon: Sprite2D
var moon_cfg := {}
var glow_tex: Texture2D
var lights: Array = []
var ambient: Node2D
var front_root: Node2D
var t := 0.0
var flash := 0.0
var weather := 0
var weather_k := 0.0
var cam_pos := Vector2(0, -110)
var cam_zoom := 1.0
var debris_tex: Texture2D
var debris_nodes: Array = []


func _ready() -> void:
	glow_tex = _make_glow()
	_build_sky()
	var txt := FileAccess.get_file_as_string(DIR + "stage.json")
	var j = JSON.parse_string(txt) if txt != "" else null
	if typeof(j) == TYPE_DICTIONARY:
		cfg = j
		if cfg.has("ref_camera"):
			ref = Vector2(cfg["ref_camera"][0], cfg["ref_camera"][1])
		for L in cfg.get("layers", []):
			if L.get("front", false):
				continue
			_add_layer(L, self)
		if cfg.has("moon"):
			moon_cfg = cfg["moon"]
	else:
		_fallback_floor()
	ambient = _Ambient.new()
	ambient.stage = self
	ambient.z_index = 0
	add_child(ambient)
	if ResourceLoader.exists("res://assets/vfx/rock_chunks.png"):
		debris_tex = load("res://assets/vfx/rock_chunks.png")


func build_front() -> void:
	## camadas na frente dos lutadores (chamado depois de criar os lutadores)
	front_root = Node2D.new()
	front_root.z_index = 40
	battle.world.add_child(front_root)
	for L in cfg.get("layers", []):
		if L.get("front", false):
			_add_layer(L, front_root)


func _add_layer(L: Dictionary, parent: Node) -> void:
	var path: String = DIR + str(L["file"])
	if not ResourceLoader.exists(path):
		return
	var holder := Node2D.new()
	holder.z_index = int(L.get("z", 0))
	holder.z_as_relative = false
	parent.add_child(holder)
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/pixel_layer.gdshader")
	s.material = m
	holder.add_child(s)
	var rec := {"node": holder, "sprite": s, "mat": m, "parallax": float(L.get("parallax", 1.0)),
		"origin": Vector2(L["origin"][0], L["origin"][1]), "name": str(L["name"]), "front": L.get("front", false)}
	layers.append(rec)
	# lanternas e cachoeiras desta camada
	for li in cfg.get("lights", []):
		if str(li.get("layer", "")) != rec["name"]:
			continue
		var g := Sprite2D.new()
		g.texture = glow_tex
		var r: float = float(li.get("r", 14))
		g.scale = Vector2.ONE * (r * 2.6 / 64.0)
		g.position = Vector2(li["x"], li["y"])
		g.modulate = Color(str(li.get("color", "#ffc46a")))
		var gm := CanvasItemMaterial.new()
		gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = gm
		holder.add_child(g)
		lights.append({"node": g, "base": g.modulate, "seed": randf() * 10.0, "scale": g.scale})
	for wf in cfg.get("waterfalls", []):
		if str(wf.get("layer", "")) != rec["name"]:
			continue
		var w := ColorRect.new()
		w.position = Vector2(wf["x"], wf["y"])
		w.size = Vector2(maxf(2.0, float(wf["w"])), float(wf["h"]))
		var wm := ShaderMaterial.new()
		wm.shader = load("res://shaders/waterfall.gdshader")
		wm.set_shader_parameter("seed", randf() * 10.0)
		w.material = wm
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(w)


func _build_sky() -> void:
	sky_layer = CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	sky = ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.material = sky_mat
	sky_layer.add_child(sky)
	moon = Sprite2D.new()
	moon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mm := ShaderMaterial.new()
	mm.shader = load("res://shaders/pixel_layer.gdshader")
	moon.material = mm
	sky_layer.add_child(moon)
	var halo := Sprite2D.new()
	halo.texture = glow_tex
	halo.name = "Halo"
	var hm := CanvasItemMaterial.new()
	hm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = hm
	halo.modulate = Color(0.75, 0.7, 1.0, 0.45)
	halo.scale = Vector2.ONE * 6.0
	moon.add_child(halo)
	moon.show_behind_parent = false
	halo.show_behind_parent = true


func _make_glow() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


func _fallback_floor() -> void:
	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([Vector2(-900, -20), Vector2(900, -20), Vector2(900, 300), Vector2(-900, 300)])
	floor.color = Color(0.2, 0.14, 0.3)
	floor.z_index = -5
	add_child(floor)


func update_view(cpos: Vector2, z: float) -> void:
	cam_pos = cpos
	cam_zoom = z
	for L in layers:
		var f: float = L["parallax"]
		var ze := 1.0 + (z - 1.0) * f
		var s := ze / z
		var node: Node2D = L["node"]
		node.scale = Vector2(s, s)
		node.position = cpos + s * (L["origin"] - ref - f * (cpos - ref))
	# lua (fica na camada do céu, em coordenadas de tela)
	if moon_cfg.size() > 0 and moon.texture == null and ResourceLoader.exists(DIR + str(moon_cfg["file"])):
		moon.texture = load(DIR + str(moon_cfg["file"]))
		moon.centered = false
	if moon.texture:
		var f2: float = float(moon_cfg.get("parallax", 0.03))
		var o := Vector2(moon_cfg["origin"][0], moon_cfg["origin"][1])
		var vs := get_viewport().get_visible_rect().size
		var scr := (o - ref - f2 * (cpos - ref)) + Vector2(320, 180)
		moon.position = scr * (vs / Vector2(640, 360))
		moon.scale = vs / Vector2(640, 360)
		var h: Sprite2D = moon.get_node("Halo")
		h.position = moon.texture.get_size() * 0.5
		h.scale = Vector2.ONE * moon.texture.get_width() * 3.2 / 64.0
	sky_mat.set_shader_parameter("cam", cpos)


func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 3.5)
	weather_k = move_toward(weather_k, 1.0, delta * 0.5)
	sky_mat.set_shader_parameter("time", t)
	sky_mat.set_shader_parameter("flash", flash)
	sky_mat.set_shader_parameter("weather", float(weather))
	sky_mat.set_shader_parameter("weather_k", weather_k)
	var dim = 1.0 - (battle.darken if battle else 0.0) * 0.6
	sky.modulate = Color(dim, dim, dim * 1.05)
	moon.modulate = Color(dim, dim, dim)
	for L in lights:
		var n: Sprite2D = L["node"]
		var sd: float = L["seed"]
		var fl := 0.82 + 0.12 * sin(t * 3.1 + sd) + 0.06 * sin(t * 11.7 + sd * 3.0)
		n.modulate = Color(L["base"], (0.55 + flash * 0.4) * fl)
		n.scale = L["scale"] * (0.95 + 0.08 * fl)
	for L in layers:
		var m: ShaderMaterial = L["mat"]
		m.set_shader_parameter("flash", flash * (0.6 if L["parallax"] < 0.5 else 0.35))
	_update_debris(delta)


func on_round(n: int) -> void:
	weather = (n - 1) % 3
	weather_k = 0.0
	if n > 1:
		Audio.play("weather_change", -4.0)


func lightning_flash() -> void:
	flash = 1.0


func debris(p: Vector2, n: int) -> void:
	for i in n:
		var v := Vector2(randf_range(-3.5, 3.5), randf_range(-6.5, -2.5))
		if debris_tex:
			var s := Sprite2D.new()
			s.texture = debris_tex
			s.region_enabled = true
			var cols := 8
			var fw := debris_tex.get_width() / cols
			var row := randi() % 8
			s.region_rect = Rect2(0, row * fw, fw, fw)
			s.position = p + Vector2(randf_range(-6, 6), -2)
			s.z_index = 26
			battle.world.add_child(s)
			debris_nodes.append({"n": s, "v": v, "life": 1.4, "row": row, "fw": fw, "t": randf() * 8.0})
		else:
			battle.fx.particle(p, v, 50, Color(0.5, 0.45, 0.6), 3.0, "sq", false, 0.25, 0.98, {"floor": true})


func _update_debris(delta: float) -> void:
	var k := delta * 60.0
	for i in range(debris_nodes.size() - 1, -1, -1):
		var d: Dictionary = debris_nodes[i]
		var s: Sprite2D = d["n"]
		d["life"] -= delta
		d["v"].y += 0.3 * k
		s.position += d["v"] * k
		if s.position.y > 0.0:
			s.position.y = 0.0
			d["v"] = Vector2(d["v"].x * 0.6, -d["v"].y * 0.35)
		d["t"] += k * 0.3
		s.region_rect = Rect2(int(d["t"]) % 8 * d["fw"], d["row"] * d["fw"], d["fw"], d["fw"])
		s.modulate.a = clampf(d["life"] / 0.4, 0.0, 1.0)
		if d["life"] <= 0.0:
			s.queue_free()
			debris_nodes.remove_at(i)


class _Ambient extends Node2D:
	## vagalumes, pétalas e estrelas cadentes do cenário
	var stage
	var flies := []
	var petals := []
	var stars := []
	var _add: Node2D

	func _ready() -> void:
		for i in 26:
			flies.append({"p": Vector2(randf_range(-600, 600), randf_range(-320, -10)), "ph": randf() * TAU,
				"sp": randf_range(0.3, 0.8), "c": Color(1.0, 0.9, 0.45) if randf() < 0.7 else Color(0.55, 1.0, 0.8)})
		for i in 18:
			petals.append(_new_petal(true))
		_add = Node2D.new()
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_add.material = m
		_add.draw.connect(_draw_glow)
		add_child(_add)

	func _new_petal(anywhere := false) -> Dictionary:
		var cx: float = stage.cam_pos.x if stage else 0.0
		return {"p": Vector2(cx + randf_range(-500, 500), randf_range(-420, -40) if anywhere else -460.0),
			"v": Vector2(randf_range(-0.6, 0.2), randf_range(0.3, 0.8)), "ph": randf() * TAU,
			"c": Color(1.0, 0.72, 0.85) if randf() < 0.75 else Color(0.75, 1.0, 0.9)}

	func _process(delta: float) -> void:
		var k := delta * 60.0
		var w: int = stage.weather
		for f in flies:
			f["ph"] += 0.02 * k
			f["p"] += Vector2(cos(f["ph"] * 1.3), sin(f["ph"] * 0.9)) * f["sp"] * 0.4 * k
		for i in petals.size():
			var p: Dictionary = petals[i]
			p["ph"] += 0.04 * k
			p["p"] += (p["v"] + Vector2(sin(p["ph"]) * 0.5, 0)) * k
			if p["p"].y > 40.0:
				petals[i] = _new_petal()
		var rate := 0.01 if w != 1 else 0.08
		if randf() < rate * k:
			var cx: float = stage.cam_pos.x
			stars.append({"p": Vector2(cx + randf_range(-400, 400), randf_range(-560, -300)),
				"v": Vector2(randf_range(-7, -4), randf_range(2, 3.5)), "life": 1.0})
		for i in range(stars.size() - 1, -1, -1):
			stars[i]["p"] += stars[i]["v"] * k
			stars[i]["life"] -= delta * 1.4
			if stars[i]["life"] <= 0.0:
				stars.remove_at(i)
		queue_redraw()
		_add.queue_redraw()

	func _draw() -> void:
		for p in petals:
			var d := Vector2.from_angle(p["ph"]) * 2.0
			draw_line(p["p"] - d, p["p"] + d, p["c"], 2.0)

	func _draw_glow() -> void:
		var t: float = stage.t
		for f in flies:
			var a := 0.5 + 0.5 * sin(t * 2.0 + f["ph"] * 3.0)
			_add.draw_circle(f["p"], 5.0, Color(f["c"], 0.12 * a))
			_add.draw_circle(f["p"], 1.4, Color(f["c"], 0.9 * a))
		for s in stars:
			var a2: float = s["life"]
			_add.draw_line(s["p"], s["p"] - s["v"] * 6.0, Color(1, 0.95, 0.8, 0.8 * a2), 1.5)
			_add.draw_circle(s["p"], 1.5, Color(1, 1, 1, a2))
