class_name Track
extends Node3D
## Pista 3D: spline fechada com altura, inclinação nas curvas, loopings, espirais, saca-rolhas e vãos de salto.
## Gera malhas (asfalto, zebras, guard-rails, parte de baixo, pilares), colisores e posições de decoração.

var data: Dictionary
var theme: Dictionary
var W := 22.0
var HALF := 11.0
var WALL := 12.6
var lanes_fwd: Array = []
var lanes_onc: Array = []

var n := 0
var length := 0.0
var ds := 2.0
var P := PackedVector3Array()
var T := PackedVector3Array()
var U := PackedVector3Array()
var L := PackedVector3Array()
var gap := PackedByteArray()
var loopf := PackedByteArray()
var ftype := PackedStringArray()
var feat := PackedByteArray()   # trecho especial (loop/espiral/saca-rolhas/salto): sem pads, pickups ou respawn
var curv := PackedFloat32Array()
var pads: Array = []
var pickup_spots: Array = []
var main_s: Array = []


func setup(data_: Dictionary, theme_: Dictionary) -> void:
	data = data_
	theme = theme_
	W = float(data.w)
	HALF = W * 0.5
	WALL = HALF + 1.6
	lanes_fwd = [-W * 0.125, -W * 0.375]
	lanes_onc = [W * 0.125, W * 0.375]
	var cps := _expand()
	_sample(cps)
	_frames()
	_auto_spots()


# ------------------------------------------------------------------ pontos de controle com elementos especiais
static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[2]), float(a[1]))


func _expand() -> Array:
	var raw: Array = data.pts
	var fd: Dictionary = data.feat
	var m := raw.size()
	# os loopings deslocam a pista para o lado; os pontos seguintes acompanham o deslocamento
	var pts: Array = []
	var acc := Vector3.ZERO
	for i in m:
		var q := _v(raw[i]) + acc
		pts.append([q.x, q.z, q.y])
		if fd.has(i) and String(fd[i][0]) == "loop":
			var a0 := _v(raw[i])
			var b0 := _v(raw[(i + 1) % m])
			var c0 := _v(raw[(i + 2) % m])
			var dd := Vector3(b0.x - a0.x, 0, b0.z - a0.z).normalized()
			var d2 := Vector3(c0.x - b0.x, 0, c0.z - b0.z).normalized()
			var lf := Vector3(dd.z, 0, -dd.x)
			var tl := (dd.x * d2.z - dd.z * d2.x) < 0.0
			acc += (lf if tl else -lf) * (W + 4.0) * (1.0 if i + 1 < m else 0.0)
	var cps: Array = []
	for i in m:
		var p := _v(pts[i])
		var prev := _v(pts[(i - 1 + m) % m])
		var nxt := _v(pts[(i + 1) % m])
		cps.append({"p": p, "main": i})
		if not fd.has(i):
			continue
		var f: Array = fd[i]
		var d := Vector3(nxt.x - p.x, 0, nxt.z - p.z).normalized()
		var left := Vector3(d.z, 0, -d.x)
		match String(f[0]):
			"helix":
				var dh_dir := Vector3(nxt.x - prev.x, 0, nxt.z - prev.z).normalized()
				var lft := Vector3(dh_dir.z, 0, -dh_dir.x)
				var turns: float = f[1]
				var R: float = f[2]
				var dh: float = f[3]
				var sg := signf(turns)
				var c := p + lft * R * sg
				var steps := int(absf(turns) * 14.0)
				for k in range(1, steps + 1):
					var a := sg * float(k) / steps * absf(turns) * TAU
					var off := Vector3(p.x - c.x, 0, p.z - c.z).rotated(Vector3.UP, a)
					cps.append({"p": Vector3(c.x + off.x, p.y + dh * k / steps, c.z + off.z), "feat": true, "kind": "helix"})
			"loop":
				var R: float = f[1]
				var mid := p.lerp(nxt, 0.4)
				# o looping sai deslocado para o lado da próxima curva (assim a reta de saída casa com ela)
				var nn := _v(pts[(i + 2) % m])
				var d2 := Vector3(nn.x - nxt.x, 0, nn.z - nxt.z).normalized()
				var turn_left := (d.x * d2.z - d.z * d2.x) < 0.0
				var right := left if turn_left else -left
				var shift := W + 4.0
				cps.append({"p": mid - d * 16.0, "feat": true, "kind": "loop"})
				for k in range(0, 15):
					var th := float(k) / 14.0 * TAU
					var q := mid + d * R * sin(th) + Vector3.UP * R * (1.0 - cos(th)) + right * shift * (th / TAU)
					cps.append({"p": q, "loop": true, "feat": true, "lc": mid + Vector3.UP * R, "la": right, "kind": "loop"})
				cps.append({"p": mid + right * shift + d * 16.0, "feat": true, "kind": "loop"})
			"jump":
				var g: float = f[1]
				var kick: float = f[2]
				var a0 := p.lerp(nxt, 0.25)
				var b0 := a0 + d * 10.0 + Vector3.UP * kick
				var c0 := b0 + d * g - Vector3.UP * (kick + 0.4)
				cps.append({"p": a0, "feat": true, "kind": "jump"})
				cps.append({"p": a0 + d * 5.0 + Vector3.UP * kick * 0.3, "feat": true, "kind": "jump"})
				cps.append({"p": b0, "gap": true, "feat": true, "kind": "jump"})
				cps.append({"p": b0 + d * 3.0 + Vector3.UP * kick * 0.6, "gap": true, "feat": true, "kind": "jump"})
				cps.append({"p": c0 - d * 4.0 + Vector3.UP * 0.7, "gap": true, "feat": true, "kind": "jump"})
				cps.append({"p": c0, "feat": true, "kind": "jump"})
				cps.append({"p": c0 + d * 8.0, "feat": true, "kind": "jump"})
			"cork":
				# torção: a pista deita 75° para um lado e depois para o outro (parede para os dois lados)
				var sg := signf(f[1])
				var banks := [0.0, 40.0, 75.0, 40.0, 0.0, -40.0, -75.0, -40.0, 0.0]
				for k in 9:
					cps.append({"p": p.lerp(nxt, 0.12 + k * 0.088), "bank": sg * banks[k], "feat": true, "kind": "cork"})
	return cps


static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t0 := 0.0
	var t1 := t0 + pow(maxf(p0.distance_to(p1), 1e-3), 0.5)
	var t2 := t1 + pow(maxf(p1.distance_to(p2), 1e-3), 0.5)
	var t3 := t2 + pow(maxf(p2.distance_to(p3), 1e-3), 0.5)
	var tt := lerpf(t1, t2, t)
	var a1 := p0 * (t1 - tt) / (t1 - t0) + p1 * (tt - t0) / (t1 - t0)
	var a2 := p1 * (t2 - tt) / (t2 - t1) + p2 * (tt - t1) / (t2 - t1)
	var a3 := p2 * (t3 - tt) / (t3 - t2) + p3 * (tt - t2) / (t3 - t2)
	var b1 := a1 * (t2 - tt) / (t2 - t0) + a2 * (tt - t0) / (t2 - t0)
	var b2 := a2 * (t3 - tt) / (t3 - t1) + a3 * (tt - t1) / (t3 - t1)
	return b1 * (t2 - tt) / (t2 - t1) + b2 * (tt - t1) / (t2 - t1)


var _bank := PackedFloat32Array()
var _lc := PackedVector3Array()
var _la := PackedVector3Array()


func _sample(cps: Array) -> void:
	var m := cps.size()
	var dense := PackedVector3Array()
	var dseg := PackedInt32Array()
	var dt := PackedFloat32Array()
	var SUB := 20
	for j in m:
		var p0: Vector3 = cps[(j - 1 + m) % m].p
		var p1: Vector3 = cps[j].p
		var p2: Vector3 = cps[(j + 1) % m].p
		var p3: Vector3 = cps[(j + 2) % m].p
		for k in SUB:
			dense.append(_cr(p0, p1, p2, p3, float(k) / SUB))
			dseg.append(j)
			dt.append(float(k) / SUB)
	var cum := PackedFloat32Array([0.0])
	for i in range(1, dense.size() + 1):
		cum.append(cum[i - 1] + dense[i - 1].distance_to(dense[i % dense.size()]))
	length = cum[cum.size() - 1]
	n = int(round(length / 2.0))
	ds = length / n
	main_s.resize(int(data.pts.size()))
	for j in m:
		if cps[j].has("main"):
			main_s[cps[j].main] = cum[j * SUB]
	var k2 := 0
	for i in n:
		var s := i * ds
		while cum[k2 + 1] < s:
			k2 += 1
		var f := (s - cum[k2]) / maxf(cum[k2 + 1] - cum[k2], 1e-6)
		P.append(dense[k2].lerp(dense[(k2 + 1) % dense.size()], f))
		var j: int = dseg[k2]
		var a: Dictionary = cps[j]
		var b: Dictionary = cps[(j + 1) % m]
		gap.append(1 if a.get("gap", false) else 0)
		var in_loop: bool = a.get("loop", false) and b.get("loop", false)
		loopf.append(1 if in_loop else 0)
		_lc.append(a.get("lc", Vector3.ZERO))
		_la.append(a.get("la", Vector3.RIGHT))
		feat.append(1 if (a.get("feat", false) or b.get("feat", false)) else 0)
		ftype.append(String(a.get("kind", b.get("kind", ""))))
		var ba: float = a.get("bank", 0.0)
		var bb: float = b.get("bank", 0.0)
		var t: float = dt[k2] + f / SUB
		_bank.append(ba + wrapf(bb - ba, -180.0, 180.0) * clampf(t, 0.0, 1.0))


func _frames() -> void:
	T.resize(n)
	U.resize(n)
	L.resize(n)
	curv.resize(n)
	for i in n:
		T[i] = (P[(i + 1) % n] - P[(i - 1 + n) % n]).normalized()
	# curvatura horizontal (para inclinação automática e para a IA frear)
	var kl := PackedFloat32Array()
	kl.resize(n)
	for i in n:
		var a := Vector2(T[i].x, T[i].z).normalized()
		var b := Vector2(T[(i + 1) % n].x, T[(i + 1) % n].z).normalized()
		var c := (a.x * b.y - a.y * b.x) / ds
		curv[i] = c if loopf[i] == 0 else 0.0
		kl[i] = -curv[i]
	var base := PackedVector3Array()
	base.resize(n)
	for i in n:
		var t := T[i]
		if loopf[i] == 1:
			# no looping o "para cima" aponta para o eixo do looping (o asfalto fica por dentro do círculo)
			var c := _lc[i] + _la[i] * (P[i] - _lc[i]).dot(_la[i])
			var up := c - P[i]
			up = up - t * t.dot(up)
			base[i] = up.normalized() if up.length() > 0.1 else base[maxi(0, i - 1)]
		else:
			var up := Vector3.UP - t * t.y
			base[i] = up.normalized() if up.length() > 0.05 else base[maxi(0, i - 1)]
	for i in n:
		# inclinação automática nas curvas (suavizada) + inclinação dos elementos (saca-rolhas)
		var acc := 0.0
		var cnt := 0
		for k in range(-8, 9):
			var j := (i + k + n) % n
			if loopf[j] == 0:
				acc += kl[j]
				cnt += 1
		var auto := clampf((acc / maxi(cnt, 1)) * 420.0, -16.0, 16.0) if loopf[i] == 0 else 0.0
		var b := deg_to_rad(auto + _bank[i])
		var up := base[i].rotated(T[i], -b)
		var lf := up.cross(T[i]).normalized()
		L[i] = lf
		U[i] = T[i].cross(lf).normalized()


func idx(i: int) -> int:
	return posmod(i, n)


## ponto na distância s, deslocado lateralmente (lat > 0 = esquerda)
func at(s: float, lat := 0.0) -> Dictionary:
	var f := fposmod(s / ds, n)
	var i := int(f)
	var j := (i + 1) % n
	var t := f - i
	var tg := T[i].lerp(T[j], t).normalized()
	var up := U[i].lerp(U[j], t).normalized()
	var lf := up.cross(tg).normalized()
	up = tg.cross(lf).normalized()
	var pos := P[i].lerp(P[j], t) + lf * lat
	return {"pos": pos, "tan": tg, "up": up, "left": lf, "basis": Basis(lf, up, tg), "heading": atan2(tg.x, tg.z), "i": i}


## projeta um ponto na pista; hint = índice anterior (-1 = busca completa)
func project(p: Vector3, hint := -1) -> Dictionary:
	var best := 1e18
	var bi := 0
	if hint < 0:
		for i in n:
			var d := p.distance_squared_to(P[i])
			if d < best:
				best = d
				bi = i
	else:
		for k in range(-30, 31):
			var i := idx(hint + k)
			var d := p.distance_squared_to(P[i])
			if d < best:
				best = d
				bi = i
	var dd := p - P[bi]
	return {"i": bi, "s": fposmod(bi * ds + dd.dot(T[bi]), length), "lat": dd.dot(L[bi]), "h": dd.dot(U[bi])}


func safe_s(s: float) -> float:
	# recua até um trecho normal (sem vão, looping ou elemento especial) para reaparecer
	var i := idx(int(s / ds))
	for k in n:
		if feat[i] == 0 and gap[i] == 0 and U[i].y > 0.85:
			return i * ds
		i = idx(i - 1)
	return 0.0


func pad_at(s: float, lat: float) -> Variant:
	for p in pads:
		var d: float = wrapf(s - p.s, -length * 0.5, length * 0.5)
		if absf(d) < 3.0 and absf(lat - p.lat) < float(p.wid) * 0.5:
			return p
	return null


# ------------------------------------------------------------------ posições automáticas de pads e itens
func _calm(i: int, span: int) -> bool:
	for k in span:
		var j := idx(i + k)
		if feat[j] == 1 or gap[j] == 1 or absf(curv[j]) > 0.012 or U[j].y < 0.9:
			return false
	return true


func _auto_spots() -> void:
	var i0 := 0
	while i0 < n:
		if feat[i0] == 1 and feat[idx(i0 - 1)] == 0 and (ftype[i0] == "loop" or ftype[i0] == "jump"):
			var k := idx(i0 - int(22.0 / ds))
			pads.append({"s": k * ds, "lat": 0.0, "spd": 40.0 if ftype[i0] == "loop" else 38.0, "wid": W - 4.0})
		i0 += 1
	var last := -1e9
	for i in range(30, n):
		if pads.size() >= 6:
			break
		if i * ds - last > 170.0 and _calm(i, 25):
			pads.append({"s": i * ds, "lat": lanes_fwd[pads.size() % 2] if data.traffic > 0 else [0.0, -W * 0.2, W * 0.2][pads.size() % 3], "spd": 0.0, "wid": 4.6})
			last = i * ds
	var kinds := ["ammo", "repair", "ammo", "nitro"]
	var step := length / 7.0
	for k in 7:
		var i := idx(int((60.0 + k * step) / ds))
		for tries in 40:
			if _calm(i, 6):
				break
			i = idx(i + 3)
		for lat in [-W * 0.22, W * 0.22] if k % 2 == 0 else [0.0]:
			pickup_spots.append({"s": i * ds, "lat": lat, "kind": kinds[k % kinds.size()]})


# ------------------------------------------------------------------ malhas e colisores
func _q(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3, col: Color, uv := Rect2(0, 0, 0, 0)) -> void:
	var uvs := [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	var vs := [a, b, c, d]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(col)
		st.set_normal(nrm)
		st.set_uv(uvs[k])
		st.add_vertex(vs[k])


func _off(i: int, lat: float, h: float) -> Vector3:
	var k := idx(i)
	return P[k] + L[k] * lat + U[k] * h


func build(ground_shader: Shader, road_shader: Shader) -> void:
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := SurfaceTool.new()
	side.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curb_a := Color(theme.curb[0])
	var curb_b := Color(theme.curb[1])
	var rail_a := Color(theme.rail[0])
	var rail_b := Color(theme.rail[1])
	var shoulder := Color(theme.shoulder)
	var under := Color(0.24, 0.24, 0.27) if theme.road != 1 else Color("#d95f00")
	var road_col := PackedVector3Array()
	var rail_col := PackedVector3Array()
	var RH := 1.15
	for i in n:
		if gap[i] == 1:
			continue
		var j := i + 1
		var ui := U[i]
		var v0 := float(i) * ds
		var v1 := float(i + 1) * ds
		var a := _off(i, HALF, 0.02)
		var b := _off(i, -HALF, 0.02)
		var c := _off(j, -HALF, 0.02)
		var d := _off(j, HALF, 0.02)
		_q(road, a, b, c, d, ui, Color.WHITE, Rect2(0, v0, 1, v1 - v0))
		road_col.append_array([a, b, c, a, c, d])
		RH = 2.2 if feat[i] == 1 else 1.15
		var cc := curb_a if i % 2 == 1 else curb_b
		var rc := rail_a if (i / 2) % 2 == 0 else rail_b
		for sgn: float in [1.0, -1.0]:
			# zebra levemente elevada
			var z0 := _off(i, sgn * HALF, 0.07)
			var z1 := _off(i, sgn * (HALF + 1.0), 0.07)
			var z2 := _off(j, sgn * (HALF + 1.0), 0.07)
			var z3 := _off(j, sgn * HALF, 0.07)
			_q(side, z0, z1, z2, z3, ui, cc)
			# acostamento
			var s0 := _off(i, sgn * (HALF + 1.0), 0.04)
			var s1 := _off(i, sgn * WALL, 0.04)
			var s2 := _off(j, sgn * WALL, 0.04)
			var s3 := _off(j, sgn * (HALF + 1.0), 0.04)
			_q(side, s0, s1, s2, s3, ui, shoulder)
			road_col.append_array([z0, z1, z2, z0, z2, z3, s0, s1, s2, s0, s2, s3])
			# guard-rail: face interna, topo e face externa
			var w0 := _off(i, sgn * WALL, 0.0)
			var w1 := _off(i, sgn * WALL, RH)
			var w2 := _off(j, sgn * WALL, RH)
			var w3 := _off(j, sgn * WALL, 0.0)
			_q(side, w0, w1, w2, w3, -L[i] * sgn, rc)
			var t0 := _off(i, sgn * (WALL + 0.5), RH)
			var t1 := _off(j, sgn * (WALL + 0.5), RH)
			_q(side, w1, t0, t1, w2, ui, rc.lightened(0.15))
			var o0 := _off(i, sgn * (WALL + 0.5), -0.8)
			var o1 := _off(j, sgn * (WALL + 0.5), -0.8)
			_q(side, t0, o0, o1, t1, L[i] * sgn, rc.darkened(0.25))
			rail_col.append_array([w0, w1, w2, w0, w2, w3, w1, t0, t1, w1, t1, w2])
		# parte de baixo da pista
		var u0 := _off(i, -(WALL + 0.5), -0.8)
		var u1 := _off(i, WALL + 0.5, -0.8)
		var u2 := _off(j, WALL + 0.5, -0.8)
		var u3 := _off(j, -(WALL + 0.5), -0.8)
		_q(side, u0, u1, u2, u3, -ui, under)

	var rm := MeshInstance3D.new()
	rm.mesh = road.commit()
	var mat := ShaderMaterial.new()
	mat.shader = road_shader
	mat.set_shader_parameter("W", W)
	mat.set_shader_parameter("mode", int(theme.road))
	mat.set_shader_parameter("tint", Color(theme.tint))
	mat.set_shader_parameter("two_way", data.traffic > 0)
	rm.material_override = mat
	rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rm)
	var sm := MeshInstance3D.new()
	sm.mesh = side.commit()
	var smat := StandardMaterial3D.new()
	smat.vertex_color_use_as_albedo = true
	smat.roughness = 0.7
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if theme.road == 1:
		smat.roughness = 0.35
	sm.material_override = smat
	add_child(sm)

	# colisores
	var rb := StaticBody3D.new()
	rb.name = "Road"
	rb.set_meta("road", true)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	rb.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(road_col)
	cs.shape = sh
	rb.add_child(cs)
	add_child(rb)
	var wb := StaticBody3D.new()
	wb.name = "Rails"
	var wpm := PhysicsMaterial.new()
	wpm.friction = 0.15
	wpm.bounce = 0.2
	wb.physics_material_override = wpm
	var wcs := CollisionShape3D.new()
	var wsh := ConcavePolygonShape3D.new()
	wsh.backface_collision = true
	wsh.set_faces(rail_col)
	wcs.shape = wsh
	wb.add_child(wcs)
	add_child(wb)

	_build_pillars()
	_build_ground(ground_shader)
	_build_start()
	_build_pads()


func _build_pillars() -> void:
	if not theme.pillars:
		return
	var gy: float = theme.gy
	var xs: Array = []
	for i in range(0, n, 7):
		if gap[i] == 1 or loopf[i] == 1 or U[i].y < 0.8:
			continue
		var bottom := P[i].y - 0.9
		if bottom - gy < 1.2:
			continue
		for sgn: float in [-1.0, 1.0]:
			var base: Vector3 = P[i] + L[i] * sgn * HALF * 0.55
			# não fincar pilar em cima de outro trecho da pista (viaduto)
			var blocked := false
			for k in range(0, n, 2):
				if absi(k - i) < 12 or absi(k - i) > n - 12:
					continue
				if P[k].y < bottom - 1.0 and Vector2(P[k].x - base.x, P[k].z - base.z).length() < HALF + 3.0:
					blocked = true
					break
			if not blocked:
				xs.append(Transform3D(Basis().scaled(Vector3(1, bottom - gy, 1)), Vector3(base.x, (bottom + gy) * 0.5, base.z)))
	if xs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = 0.9
	cyl.height = 1.0
	cyl.radial_segments = 10
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(theme.shoulder).lightened(0.25) if theme.road != 1 else Color("#ff8c1a")
	m.roughness = 0.8
	cyl.material = m
	mm.mesh = cyl
	mm.instance_count = xs.size()
	for k in xs.size():
		mm.set_instance_transform(k, xs[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _build_ground(shader: Shader) -> void:
	var gy: float = theme.gy
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var gcs := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(1600, 2, 1600)
	gcs.shape = gbox
	gcs.position = Vector3(0, gy - 1, 0)
	ground.add_child(gcs)
	ground.set_meta("ground", true)
	add_child(ground)
	var gm := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	plane.subdivide_width = 1
	gm.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("mode", int(theme.ground))
	mat.set_shader_parameter("col_a", Color(theme.ga))
	mat.set_shader_parameter("col_b", Color(theme.gb))
	gm.material_override = mat
	gm.position.y = gy - 0.01
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gm)


func _build_start() -> void:
	var a := at(0.0)
	var fin := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(W, 3)
	fin.mesh = fm
	var fsm := ShaderMaterial.new()
	fsm.shader = load("res://shaders/checker.gdshader")
	fin.material_override = fsm
	fin.transform = Transform3D(a.basis, a.pos + a.up * 0.06)
	add_child(fin)


func _build_pads() -> void:
	var sh := load("res://shaders/pad.gdshader") as Shader
	for p in pads:
		var a := at(p.s, p.lat)
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(float(p.wid), 6.0)
		mi.mesh = pm
		var sm := ShaderMaterial.new()
		sm.shader = sh
		mi.material_override = sm
		mi.transform = Transform3D(a.basis, a.pos + a.up * 0.09)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


## pontos para decoração: placas de curva, postes, pneus, bandeiras e outdoors
func decor_spots() -> Array:
	var out: Array = []
	var i := 0
	while i < n:
		if feat[i] == 0 and gap[i] == 0 and U[i].y > 0.9 and absf(curv[i]) > 1.0 / 45.0:
			# placa do lado de fora da curva, virada para quem chega
			var outside := -signf(-curv[i])  # curva para a esquerda -> lado de fora é a direita
			var k := idx(i - 6)
			var pos := P[k] + L[k] * outside * (WALL + 1.6)
			out.append({"kind": "prop_sign", "xf": Transform3D(Basis(-L[k], Vector3.UP, -T[k]).orthonormalized(), pos), "flip": outside < 0})
			var k2 := idx(i + 4)
			out.append({"kind": "prop_tirewall", "xf": Transform3D(Basis(Vector3.UP, atan2(T[k2].x, T[k2].z)), P[k2] + L[k2] * outside * (WALL + 2.2))})
			i += 18
			continue
		i += 1
	for k in range(0, n, 22):
		if gap[k] == 1 or loopf[k] == 1 or U[k].y < 0.9:
			continue
		var sgn := 1.0 if (k / 22) % 2 == 0 else -1.0
		var pos := P[k] + L[k] * sgn * (WALL + 1.0)
		out.append({"kind": "prop_lamp", "xf": Transform3D(Basis(Vector3.UP, atan2(-L[k].x * sgn, -L[k].z * sgn)), pos)})
	for k in [6, 12, 18]:
		for sgn: float in [1.0, -1.0]:
			var pos: Vector3 = P[k] + L[k] * sgn * (WALL + 2.0)
			out.append({"kind": "prop_flag", "xf": Transform3D(Basis(Vector3.UP, atan2(T[k].x, T[k].z)), pos)})
	var kb := idx(int(40.0 / ds))
	out.append({"kind": "prop_billboard", "xf": Transform3D(Basis(Vector3.UP, atan2(-L[kb].x, -L[kb].z)), P[kb] + L[kb] * (WALL + 6.0))})
	return out


## distância horizontal ao trecho mais próximo (para espalhar cenário sem cobrir a pista)
func clearance_xz(p: Vector3) -> float:
	var best := 1e9
	for i in range(0, n, 3):
		best = minf(best, Vector2(p.x - P[i].x, p.z - P[i].z).length())
	return best


## checagens de construção: raio mínimo, cruzamentos sem altura suficiente, altura mínima
func validate() -> Dictionary:
	var min_r := 1e9
	var min_at := Vector3.ZERO
	for i in n:
		if loopf[i] == 0 and absf(curv[i]) > 1e-5 and 1.0 / absf(curv[i]) < min_r:
			min_r = 1.0 / absf(curv[i])
			min_at = P[i]
	var conflicts := 0
	var worst := 1e9
	var wa := Vector3.ZERO
	var skip := int(45.0 / ds)
	for i in range(0, n, 2):
		for j in range(i + skip, n - (skip if i < skip else 0), 2):
			var dxz := Vector2(P[i].x - P[j].x, P[i].z - P[j].z).length()
			if dxz < W + 3.0:
				var dy := absf(P[i].y - P[j].y)
				if dy < 5.5 and loopf[i] == 0 and loopf[j] == 0:
					conflicts += 1
					if dxz < worst:
						worst = dxz
						wa = P[i]
	var min_y := 1e9
	for i in n:
		if gap[i] == 0:
			min_y = minf(min_y, P[i].y)
	return {"len": int(length), "min_r": snappedf(min_r, 0.1), "at": Vector3i(min_at), "wat": Vector3i(wa), "conflicts": conflicts, "worst": snappedf(worst, 0.1), "min_y": snappedf(min_y, 0.1)}
