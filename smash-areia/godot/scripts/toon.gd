class_name Toon
## Fábrica de materiais toon (estilo aventura fofa): luz macia + contorno fino
## no tom escuro da própria cor.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const BLOB_SHADER := preload("res://shaders/blob.gdshader")

static var _outline_cache := {}
static var _cache := {}


static func outline(width: float, tint := Color(0.07, 0.04, 0.12)) -> ShaderMaterial:
	var key := "%s|%s" % [snappedf(width, 0.001), tint.to_html(false)]
	if _outline_cache.has(key):
		return _outline_cache[key]
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("color", tint)
	# traços finos (jogadores, bola, raquete) mantêm a espessura de longe;
	# os grossos do cenário não crescem, para o fundo não ficar pesado
	m.set_shader_parameter("max_scale", 2.6 if width <= 0.025 else 1.0)
	m.render_priority = -1
	_outline_cache[key] = m
	return m


## opts: rim, spec, outline (largura, 0 = sem), halftone, shadow (Color), unique (bool)
static func make(color: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var unique: bool = opts.get("unique", false)
	var key := "%s|%s" % [color.to_html(), str(opts)]
	if not unique and _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("rim_amount", opts.get("rim", 0.35))
	m.set_shader_parameter("spec_amount", opts.get("spec", 0.0))
	m.set_shader_parameter("halftone", opts.get("halftone", 1.0))
	if opts.has("shadow"):
		m.set_shader_parameter("shadow_tint", opts["shadow"])
	if opts.has("wind"):
		m.set_shader_parameter("wind", opts["wind"])
	if opts.has("bg"):
		m.set_shader_parameter("bg", opts["bg"])
	# traço mais fino que o antigo (de gibi) e na cor da peça, bem escurecida
	var w: float = opts.get("outline", 0.025) * 0.72
	if w > 0.0:
		m.next_pass = outline(w, line_tint(color))
	if not unique:
		_cache[key] = m
	return m


## Troca os materiais importados do .glb pelos materiais toon.
## palette: nome do material do Blender -> Color. Materiais fora da paleta usam
## a cor original do Blender.
## Tom do contorno: a cor da peça escurecida e puxada para um roxo-ameixa.
static func line_tint(c: Color) -> Color:
	var d := Color(c.r * 0.3, c.g * 0.24, c.b * 0.3).lerp(Color(0.16, 0.08, 0.16), 0.45)
	return Color(snappedf(d.r, 0.02), snappedf(d.g, 0.02), snappedf(d.b, 0.02))


static func apply(root: Node, palette: Dictionary = {}, opts: Dictionary = {}, double_sided: Array = [],
		per_mat: Dictionary = {}) -> void:
	for mi in _meshes(root):
		var mesh := mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			var mat_name := src.resource_name if src else ""
			var col := Color.WHITE
			if palette.has(mat_name):
				col = palette[mat_name]
			elif src is BaseMaterial3D:
				col = (src as BaseMaterial3D).albedo_color
			var o := opts.duplicate()
			if per_mat.has(mat_name):
				o.merge(per_mat[mat_name], true)
			if mat_name in double_sided:
				o["outline"] = 0.0
			var m := make(col, o)
			if mat_name in double_sided:
				m = m.duplicate()
				m.shader = _double_sided_shader()
			mi.set_surface_override_material(s, m)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static var _ds_shader: Shader


static func _double_sided_shader() -> Shader:
	if _ds_shader == null:
		_ds_shader = TOON_SHADER.duplicate()
		_ds_shader.code = TOON_SHADER.code.replace("cull_back", "cull_disabled")
	return _ds_shader


static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(_meshes(c))
	return out


static func blob(size: float, color: Color, ring := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = BLOB_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("ring", 1.0 if ring else 0.0)
	m.render_priority = 1
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
