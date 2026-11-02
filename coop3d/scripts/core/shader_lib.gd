class_name ShaderLib
## Central access to every custom spatial/sky shader.
## Each one has a minimal "safe" twin in res://shaders/safe/ with the same
## uniform names. If a GPU driver crashes compiling a shader, the boot
## tracer (GpuTrace) records it and that shader is swapped for its twin on
## the next launch; `Game.safe_graphics` swaps all of them.

const REAL := {
	"toon": "res://shaders/toon.gdshader",
	"outline": "res://shaders/outline.gdshader",
	"terrain": "res://shaders/terrain.gdshader",
	"glow": "res://shaders/glow.gdshader",
	"ghost": "res://shaders/ghost.gdshader",
	"portal": "res://shaders/portal.gdshader",
	"shockwave": "res://shaders/shockwave.gdshader",
	"beam": "res://shaders/beam.gdshader",
	"bubble": "res://shaders/bubble.gdshader",
	"grass": "res://shaders/grass.gdshader",
	"cloud_sea": "res://shaders/cloud_sea.gdshader",
	"sky": "res://shaders/sky.gdshader",
	"water": "res://shaders/water.gdshader",
}
const SAFE := {
	"toon": "res://shaders/safe/toon.gdshader",
	"outline": "res://shaders/safe/outline.gdshader",
	"terrain": "res://shaders/safe/terrain.gdshader",
	"glow": "res://shaders/safe/glow.gdshader",
	"ghost": "res://shaders/safe/fx.gdshader",
	"portal": "res://shaders/safe/fx.gdshader",
	"shockwave": "res://shaders/safe/fx.gdshader",
	"beam": "res://shaders/safe/fx.gdshader",
	"bubble": "res://shaders/safe/fx.gdshader",
	"grass": "res://shaders/safe/grass.gdshader",
	"cloud_sea": "res://shaders/safe/cloud_sea.gdshader",
	"sky": "res://shaders/safe/sky.gdshader",
	"water": "res://shaders/safe/water.gdshader",
}

static var _cache := {}


static func is_safe(name: String) -> bool:
	return Game.safe_graphics or name in Game.safe_shaders


static func get_shader(name: String) -> Shader:
	var path: String = SAFE[name] if is_safe(name) else REAL[name]
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func material(name: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = get_shader(name)
	return m


static func clear_cache() -> void:
	_cache.clear()
