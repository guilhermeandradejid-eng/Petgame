class_name WeaponTrail
extends MeshInstance3D
## Ribbon trail between two moving points (weapon base + tip). Thin, translucent, tapered.

const LIFE := 0.22

var color := Color(1, 1, 1, 1)
var _samples: Array = []     # [{ "a": Vector3, "b": Vector3, "t": float }]
var _im := ImmediateMesh.new()
var _mat: StandardMaterial3D
var done := false


func _init() -> void:
	mesh = _im
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.vertex_color_use_as_albedo = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true


func add_sample(base: Vector3, tip: Vector3) -> void:
	_samples.append({"a": base, "b": tip, "t": 0.0})


func _process(delta: float) -> void:
	for s in _samples:
		s["t"] += delta
	while not _samples.is_empty() and _samples[0]["t"] > LIFE:
		_samples.pop_front()
	_im.clear_surfaces()
	if _samples.size() >= 2:
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var pts := _smooth()
		var n := pts.size()
		for i in n:
			var s: Dictionary = pts[i]
			var age := clampf(s["t"] / LIFE, 0.0, 1.0)
			var head := float(i) / maxf(n - 1, 1)             # 1 = newest
			var alpha := (1.0 - age) * (0.25 + 0.75 * head) * color.a
			var c := Color(color.r, color.g, color.b, alpha * 0.9)
			var mid: Vector3 = s["a"].lerp(s["b"], 0.18)       # taper: skip the hilt end
			_im.surface_set_color(Color(c.r, c.g, c.b, 0.0))
			_im.surface_add_vertex(to_local(mid))
			_im.surface_set_color(c)
			_im.surface_add_vertex(to_local(s["b"]))
		_im.surface_end()
	elif done:
		queue_free()
	if done and _samples.is_empty():
		queue_free()


func _smooth() -> Array:
	if _samples.size() < 3:
		return _samples
	var out: Array = []
	for i in range(_samples.size() - 1):
		var p0: Dictionary = _samples[maxi(i - 1, 0)]
		var p1: Dictionary = _samples[i]
		var p2: Dictionary = _samples[i + 1]
		var p3: Dictionary = _samples[mini(i + 2, _samples.size() - 1)]
		for k in 3:
			var t := float(k) / 3.0
			out.append({
				"a": p1["a"].cubic_interpolate(p2["a"], p0["a"], p3["a"], t),
				"b": p1["b"].cubic_interpolate(p2["b"], p0["b"], p3["b"], t),
				"t": lerpf(p1["t"], p2["t"], t),
			})
	out.append(_samples[-1])
	return out
