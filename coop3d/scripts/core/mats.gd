class_name Mats
## Material factory + cache. Converts imported glTF materials into the
## project's stylized shaders based on the Blender material name prefix.

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const TERRAIN := preload("res://shaders/terrain.gdshader")
const GLOW := preload("res://shaders/glow.gdshader")
const GHOST := preload("res://shaders/ghost.gdshader")

const N_ROCK := preload("res://assets/textures/normals/rock.webp")
const N_PEBBLES := preload("res://assets/textures/normals/pebbles.webp")
const N_STONE := preload("res://assets/textures/normals/cracked_stone.webp")
const N_TILES := preload("res://assets/textures/normals/tiles.webp")
const N_WOOD := preload("res://assets/textures/normals/wood.webp")
const N_SAND := preload("res://assets/textures/normals/sand.webp")
const N_SCALES := preload("res://assets/textures/normals/scales.webp")

static var _cache := {}
static var _outline_cache := {}


static func toon(color: Color, opts := {}) -> ShaderMaterial:
	var key := "toon_%s_%s" % [color.to_html(), str(opts)]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	for k in opts:
		if k == "outline":
			continue
		m.set_shader_parameter(k, opts[k])
	if opts.get("outline", 0.0) > 0.0:
		m.next_pass = outline(opts["outline"])
	_cache[key] = m
	return m


static func outline(width := 0.012, color := Color(0.16, 0.09, 0.2)) -> ShaderMaterial:
	var key := "%f_%s" % [width, color.to_html()]
	if _outline_cache.has(key):
		return _outline_cache[key]
	var m := ShaderMaterial.new()
	m.shader = OUTLINE
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("outline_color", color)
	_outline_cache[key] = m
	return m


static func glow(color: Color, energy := 1.6) -> ShaderMaterial:
	var key := "glow_%s_%f" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("energy", energy)
	_cache[key] = m
	return m


static func ghost(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GHOST
	m.set_shader_parameter("color", color)
	return m


## Terrain for islands/planets. `style`: "meadow", "ruins", "planet".
static func terrain(style := "meadow", planet_center := Vector3.ZERO, radial := false) -> ShaderMaterial:
	var key := "terrain_%s_%s_%s" % [style, str(planet_center), radial]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = TERRAIN
	m.set_shader_parameter("rock_normal", N_ROCK)
	m.set_shader_parameter("grass_normal", N_PEBBLES)
	m.set_shader_parameter("radial", radial)
	m.set_shader_parameter("planet_center", planet_center)
	match style:
		"ruins":
			m.set_shader_parameter("rock_a", Color(0.78, 0.74, 0.86))
			m.set_shader_parameter("rock_b", Color(0.6, 0.57, 0.74))
			m.set_shader_parameter("grass_a", Color(0.4, 0.72, 0.5))
			m.set_shader_parameter("grass_b", Color(0.56, 0.84, 0.55))
			m.set_shader_parameter("rock_normal", N_STONE)
		"planet":
			m.set_shader_parameter("grass_a", Color(0.42, 0.8, 0.58))
			m.set_shader_parameter("grass_b", Color(0.68, 0.9, 0.5))
			m.set_shader_parameter("grass_only", 1.0)
		"planet_pink":
			m.set_shader_parameter("grass_a", Color(1.0, 0.62, 0.75))
			m.set_shader_parameter("grass_b", Color(1.0, 0.78, 0.84))
			m.set_shader_parameter("grass_only", 1.0)
		"planet_sand":
			m.set_shader_parameter("grass_a", Color(1.0, 0.82, 0.55))
			m.set_shader_parameter("grass_b", Color(0.98, 0.9, 0.66))
			m.set_shader_parameter("grass_normal", N_SAND)
			m.set_shader_parameter("grass_only", 1.0)
	_cache[key] = m
	return m


## Walks an imported glTF scene and swaps every surface material.
## `outline_width` > 0 adds the inverted-hull outline as next_pass.
static func stylize(root: Node, outline_width := 0.0, terrain_style := "meadow") -> void:
	for n in _all_meshes(root):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var name := src.resource_name if src else ""
			var color := Color.WHITE
			var emit := Color.BLACK
			if src is BaseMaterial3D:
				color = src.albedo_color
				if src.emission_enabled:
					emit = src.emission
			mi.set_surface_override_material(s, convert_material(name, color, emit, outline_width, terrain_style))


static func convert_material(name: String, color: Color, emit: Color, outline_width: float, terrain_style: String) -> Material:
	if name.begins_with("M_Glow"):
		return glow(color.lerp(emit, 0.35), 1.8)
	if name.begins_with("M_EyeShine"):
		return glow(Color.WHITE, 0.6)
	if name.begins_with("M_Eye") and not name.begins_with("M_EyeWhite"):
		return toon(color, {"spec_amount": 1.4, "spec_size": 0.6, "rim_amount": 0.2, "outline": outline_width})
	if name.begins_with("M_Grass") or name.begins_with("M_Rock_Island"):
		return terrain(terrain_style)
	if name.begins_with("M_Rock"):
		return toon(color, {"detail_normal": N_ROCK, "detail_strength": 0.6, "detail_scale": 0.8, "noise_tint": 0.12, "outline": outline_width})
	if name.begins_with("M_Bark") or name.begins_with("M_Wood"):
		return toon(color, {"detail_normal": N_WOOD, "detail_strength": 0.45, "detail_scale": 1.2, "noise_tint": 0.08, "outline": outline_width})
	if name.begins_with("M_Cap") and not name.begins_with("M_Cap_Mushroom"):
		return toon(color, {"detail_normal": N_SCALES, "detail_strength": 0.5, "detail_scale": 3.0, "outline": outline_width})
	if name.begins_with("M_Leaf"):
		return toon(color, {"noise_tint": 0.12, "noise_scale": 1.5, "rim_amount": 0.7, "outline": outline_width})
	if name.begins_with("M_Metal"):
		return toon(color, {"spec_amount": 1.2, "spec_size": 0.5, "rim_amount": 0.8, "outline": outline_width})
	return toon(color, {"outline": outline_width})


static func _all_meshes(n: Node, out: Array = []) -> Array:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_all_meshes(c, out)
	return out
