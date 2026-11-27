extends RefCounted
# Efeitos com forma: fitas de raio/rastro voltadas para a câmera, estrelas de impacto pintadas,
# marcas no chão (anel do jogador, telegrafia, sombra). Tudo determinístico por semente.

var main: Node3D
var sm: Callable

func _init(m: Node3D, smf: Callable) -> void:
	main = m
	sm = smf

func bolt_points(a: Vector3, b: Vector3, depth: int, amp: float, rng: RandomNumberGenerator) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	var off := amp
	for d in depth:
		var np := PackedVector3Array()
		for i in pts.size() - 1:
			var p: Vector3 = pts[i]
			var q: Vector3 = pts[i + 1]
			np.append(p)
			var m := (p + q) * 0.5
			var dir := (q - p).normalized()
			var side := dir.cross(Vector3.UP)
			if side.length() < 0.1:
				side = dir.cross(Vector3.RIGHT)
			side = side.normalized()
			var up := side.cross(dir).normalized()
			m += side * rng.randf_range(-off, off) + up * rng.randf_range(-off, off) * 0.6
			np.append(m)
		np.append(pts[pts.size() - 1])
		pts = np
		off *= 0.55
	return pts

func ribbon_mesh(pts: PackedVector3Array, w0: float, w1: float, cam_pos: Vector3, inten := 1.0, taper := true) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var n := pts.size()
	var L := 0.0
	var acc := PackedFloat32Array([0.0])
	for i in range(1, n):
		L += pts[i].distance_to(pts[i - 1])
		acc.append(L)
	for i in n:
		var p: Vector3 = pts[i]
		var t := float(i) / float(max(1, n - 1))
		var dir: Vector3 = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
		var vdir := (cam_pos - p).normalized()
		var side := dir.cross(vdir).normalized()
		var w := lerpf(w0, w1, t)
		if taper:
			w *= clamp(t * 6.0, 0.25, 1.0) * clamp((1.0 - t) * 5.0, 0.2, 1.0)
		verts.append(p + side * w * 0.5)
		verts.append(p - side * w * 0.5)
		var u: float = acc[i] / max(L, 1e-4)
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
		cols.append(Color(1, 1, 1, inten))
		cols.append(Color(1, 1, 1, inten))
	var idx := PackedInt32Array()
	for i in n - 1:
		var a := i * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	if verts.size() >= 4:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func ribbon(pts: PackedVector3Array, w0: float, w1: float, cam_pos: Vector3, params := {}, inten := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ribbon_mesh(pts, w0, w1, cam_pos, inten)
	mi.material_override = sm.call("raio", params)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)
	return mi

func decal(kind: int, pos: Vector3, size: Vector2, params := {}, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	var p := {"kind": kind, "qsize": size.y}
	p.merge(params, true)
	mi.material_override = sm.call("marca", p)
	mi.position = pos + Vector3(0, 0.012, 0)
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)
	return mi

func star(pos: Vector3, size: float, params := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = sm.call("estrela", params)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)
	return mi

func parabola(a: Vector3, b: Vector3, h: float, n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t)
		p.y += 4.0 * h * t * (1.0 - t)
		pts.append(p)
	return pts

# ------------------------------------------------------------------ impacto de caco
const ELEM := {  # cor acesa na fenda por matéria
	"faisca": Color("#F3C631"), "brasa": Color("#DA6A2C"), "cal": Color("#F6F3EC"), "neutro": Color("#F6F3EC"),
}

func crack(pos: Vector3, size: float, params := {}, on_ground := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if on_ground:
		var pm := PlaneMesh.new()
		pm.size = Vector2(size, size)
		mi.mesh = pm
		params["ground"] = 1.0
	else:
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		mi.mesh = q
	mi.material_override = sm.call("racha", params)
	mi.position = pos + (Vector3(0, 0.014, 0) if on_ground else Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)
	return mi

# estilhaços vidrados: devolve a lista para shards_at(lista, t). Posição analítica: saída com
# ease-out no plano, gravidade no vertical, quique seco no chão e giro que para ao assentar.
func shards(pos: Vector3, dir: Vector3, n: int, seed: int, params := {}, speed := 2.2, sz := 0.06) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array = []
	var mat: ShaderMaterial = sm.call("caco_fx", params)
	var hs := Vector3(sz * 0.5, sz * 0.5, sz * 0.1)
	mat.set_shader_parameter("half_size", hs)
	for i in n:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := rng.randf_range(0.6, 1.25)
		bm.size = hs * 2.0 * s
		mi.mesh = bm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main.add_child(mi)
		var a := rng.randf() * TAU
		var hd := Vector3(cos(a), 0, sin(a))
		if dir.length() > 0.01:
			hd = (hd * 0.6 + Vector3(dir.x, 0, dir.z).normalized() * 0.8).normalized()
		var v := hd * speed * rng.randf_range(0.5, 1.2) + Vector3(0, rng.randf_range(1.4, 3.0), 0)
		var ax := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		out.append({"node": mi, "p0": pos, "v": v, "ax": ax, "w": rng.randf_range(10.0, 22.0), "mat": mat, "rest": rng.randf() * TAU})
	return out

func shards_at(list: Array, t: float, life := 1.1) -> void:
	for d in list:
		var mi: MeshInstance3D = d["node"]
		var v: Vector3 = d["v"]
		var p0: Vector3 = d["p0"]
		var k := 3.5
		var hx := (1.0 - exp(-k * t)) / k                 # ease-out no plano
		var y := p0.y + v.y * t - 4.9 * t * t
		var t_land := (v.y + sqrt(v.y * v.y + 19.6 * max(p0.y, 0.0))) / 9.8
		var landed := t > t_land
		var p := p0 + Vector3(v.x, 0, v.z) * hx
		if landed:
			p = p0 + Vector3(v.x, 0, v.z) * ((1.0 - exp(-k * t_land)) / k)
			y = 0.012
		p.y = max(y, 0.012)
		mi.position = p
		if landed:
			mi.basis = Basis(Vector3.UP, float(d["rest"])) * Basis(Vector3.RIGHT, PI / 2)
		else:
			mi.basis = Basis(d["ax"], t * float(d["w"]))
		var dis: float = clamp((t - life * 0.6) / (life * 0.4), 0.0, 1.0)
		(d["mat"] as ShaderMaterial).set_shader_parameter("dissolve", dis)
		mi.visible = t >= 0.0 and dis < 1.0

func puff(pos: Vector3, size: float, params := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = sm.call("po", params)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)
	return mi

func spark(pos: Vector3, size: float, params := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = sm.call("faisca", params)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)
	return mi
