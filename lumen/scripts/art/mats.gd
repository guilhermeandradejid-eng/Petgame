class_name Mats
## Biblioteca de materiais: tudo usa o mesmo shader toon, mudando so os parametros.

const TOON: Shader = preload("res://shaders/toon.gdshader")

static var _env: Dictionary = {}

static func toon(tint: Color, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("tint", tint)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

## Materiais compartilhados do cenario e dos inimigos, pelo nome vindo do Blender.
static func env(mname: String) -> ShaderMaterial:
	if _env.has(mname):
		return _env[mname]
	var m: ShaderMaterial
	match mname:
		"vcol_wind":
			m = toon(Color.WHITE, {"wind": 1.0, "rim": 0.5})
		"glow":
			m = toon(Color.WHITE, {"shade_boost": 2.4, "rim": 0.0})
		"water":
			m = toon(Color.WHITE, {"shade_boost": 0.4, "gloss": 1.2})
		"metal":
			m = toon(Color("c3cede"), {"gloss": 0.9})
		_:
			m = toon(Color.WHITE, {"rim": 0.6})
	_env[mname] = m
	return m

## Troca os materiais importados de uma arvore de nos pelos do jogo.
static func apply_env(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.mesh:
			for si in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(si)
				mi.set_surface_override_material(si, env(src.resource_name if src else "vcol"))
	for c in n.get_children():
		apply_env(c)

static func find_of(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := find_of(c, cls)
		if r:
			return r
	return null

static func set_instance_param(n: Node, param: StringName, value: Variant) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).set_instance_shader_parameter(param, value)
	for c in n.get_children():
		set_instance_param(c, param, value)
