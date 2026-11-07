class_name Track
extends Node3D
## Pista de teste: spline fechada, malhas (asfalto, zebras, muros), colisores, rampas e boost pads.

const ROAD_W := 22.0
const HALF := 11.0
const WALL := 12.6
const LANES_FWD := [-2.75, -8.25]   # mão (lado direito no sentido da corrida)
const LANES_ONC := [2.75, 8.25]     # contramão

# pontos de controle (x, z) no sentido da corrida
const CTRL := [
	Vector2(-70, 52), Vector2(-20, 60), Vector2(30, 58), Vector2(78, 50), Vector2(104, 24), Vector2(104, -12),
	Vector2(84, -40), Vector2(56, -46), Vector2(32, -28), Vector2(6, -18), Vector2(-18, -36), Vector2(-36, -62),
	Vector2(-74, -66), Vector2(-104, -40), Vector2(-108, 2), Vector2(-98, 34),
]

var n := 0
var length := 0.0
var ds := 2.0
var pts := PackedVector2Array()
var tans := PackedVector2Array()
var nors := PackedVector2Array()   # normal à esquerda
var curv := PackedFloat32Array()
var ramps: Array = []
var pads: Array = []


func _init() -> void:
	_build_spline()


static func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	# Catmull-Rom centrípeta (Barry-Goldman)
	var t0 := 0.0
	var t1 := t0 + pow(maxf(p0.distance_to(p1), 1e-4), 0.5)
	var t2 := t1 + pow(maxf(p1.distance_to(p2), 1e-4), 0.5)
	var t3 := t2 + pow(maxf(p2.distance_to(p3), 1e-4), 0.5)
	var tt := lerpf(t1, t2, t)
	var a1 := p0 * (t1 - tt) / (t1 - t0) + p1 * (tt - t0) / (t1 - t0)
	var a2 := p1 * (t2 - tt) / (t2 - t1) + p2 * (tt - t1) / (t2 - t1)
	var a3 := p2 * (t3 - tt) / (t3 - t2) + p3 * (tt - t2) / (t3 - t2)
	var b1 := a1 * (t2 - tt) / (t2 - t0) + a2 * (tt - t0) / (t2 - t0)
	var b2 := a2 * (t3 - tt) / (t3 - t1) + a3 * (tt - t1) / (t3 - t1)
	return b1 * (t2 - tt) / (t2 - t1) + b2 * (tt - t1) / (t2 - t1)


func _build_spline() -> void:
	var m := CTRL.size()
	var dense := PackedVector2Array()
	for i in m:
		for k in 80:
			dense.append(_cr(CTRL[(i - 1 + m) % m], CTRL[i], CTRL[(i + 1) % m], CTRL[(i + 2) % m], k / 80.0))
	var cum := PackedFloat32Array()
	cum.append(0.0)
	for i in range(1, dense.size() + 1):
		cum.append(cum[i - 1] + dense[i - 1].distance_to(dense[i % dense.size()]))
	length = cum[cum.size() - 1]
	n = int(round(length / 2.0))
	ds = length / n
	var j := 0
	for i in n:
		var s := i * ds
		while cum[j + 1] < s:
			j += 1
		var f := (s - cum[j]) / maxf(cum[j + 1] - cum[j], 1e-6)
		pts.append(dense[j].lerp(dense[(j + 1) % dense.size()], f))
	for i in n:
		var t := (pts[(i + 1) % n] - pts[(i - 1 + n) % n]).normalized()
		tans.append(t)
		nors.append(Vector2(t.y, -t.x))
	for i in n:
		var a := tans[i]
		var b := tans[(i + 1) % n]
		curv.append((a.x * b.y - a.y * b.x) / ds)


func idx(i: int) -> int:
	return posmod(i, n)


## ponto na distância s, deslocado lateralmente (lat > 0 = esquerda)
func at(s: float, lat := 0.0) -> Dictionary:
	var f := fposmod(s / ds, n)
	var i := int(f)
	var j := (i + 1) % n
	var t := f - i
	var p := pts[i].lerp(pts[j], t)
	var tg := tans[i].lerp(tans[j], t).normalized()
	var nl := Vector2(tg.y, -tg.x)
	var q := p + nl * lat
	return {"pos": Vector3(q.x, 0, q.y), "tan": Vector3(tg.x, 0, tg.y), "heading": atan2(tg.x, tg.y)}


## projeta um ponto na pista; hint = índice anterior (-1 = busca completa)
func project(p: Vector3, hint := -1) -> Dictionary:
	var best := 1e18
	var bi := 0
	var q := Vector2(p.x, p.z)
	if hint < 0:
		for i in n:
			var d := q.distance_squared_to(pts[i])
			if d < best:
				best = d
				bi = i
	else:
		for k in range(-24, 25):
			var i := idx(hint + k)
			var d := q.distance_squared_to(pts[i])
			if d < best:
				best = d
				bi = i
	var dd := q - pts[bi]
	var along := dd.dot(tans[bi])
	var lat := dd.dot(nors[bi])
	return {"i": bi, "s": fposmod(bi * ds + along, length), "lat": lat}


func add_ramp(s: float, lat: float) -> void:
	var a := at(s, lat)
	ramps.append({"pos": a.pos, "heading": a.heading, "len": 6.0, "wid": 7.0, "h": 1.6})


func add_pad(s: float, lat: float) -> void:
	var a := at(s, lat)
	pads.append({"pos": a.pos, "tan": a.tan, "heading": a.heading, "len": 6.0, "wid": 4.6})


func pad_at(p: Vector3) -> Variant:
	for pad in pads:
		var d: Vector3 = p - pad.pos
		var t: Vector3 = pad.tan
		var al := d.x * t.x + d.z * t.z
		var sd := d.x * t.z - d.z * t.x
		if absf(al) < pad.len * 0.5 and absf(sd) < pad.wid * 0.5:
			return pad
	return null


# ------------------------------------------------------------------ malhas e colisores
func _p3(i: int, off: float, y := 0.0) -> Vector3:
	var k := idx(i)
	var q := pts[k] + nors[k] * off
	return Vector3(q.x, y, q.y)


func build(ramp_scene: PackedScene) -> void:
	# asfalto (shader procedural com faixas)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var v0 := float(i) * ds
		var v1 := float(i + 1) * ds
		var a := _p3(i, HALF, 0.02)
		var b := _p3(i, -HALF, 0.02)
		var c := _p3(i + 1, -HALF, 0.02)
		var d := _p3(i + 1, HALF, 0.02)
		_quad(st, a, b, c, d, Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1))
	var road := MeshInstance3D.new()
	road.mesh = st.commit()
	var rm := ShaderMaterial.new()
	rm.shader = load("res://shaders/road.gdshader")
	road.material_override = rm
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)

	# zebras e acostamento (cores por vértice)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var red := Color("#e8432f")
	var white := Color("#f7f2e8")
	var shoulder := Color("#8f8a84")
	for i in n:
		var col := red if i % 2 == 1 else white
		for side in [1.0, -1.0]:
			_cquad(st, _p3(i, side * HALF, 0.05), _p3(i, side * (HALF + 1.1), 0.05), _p3(i + 1, side * (HALF + 1.1), 0.05), _p3(i + 1, side * HALF, 0.05), col)
			_cquad(st, _p3(i, side * (HALF + 1.1), 0.03), _p3(i, side * WALL, 0.03), _p3(i + 1, side * WALL, 0.03), _p3(i + 1, side * (HALF + 1.1), 0.03), shoulder)
	var curbs := MeshInstance3D.new()
	curbs.mesh = st.commit()
	curbs.material_override = _vc_mat(0.8)
	curbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(curbs)

	# muros (faixas brancas e azuis) + colisores em caixas
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_cols := [Color("#f5f1ea"), Color("#2e6fe0")]
	var H := 1.1
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	var wmat := PhysicsMaterial.new()
	wmat.friction = 0.15
	wmat.bounce = 0.2
	walls.physics_material_override = wmat
	add_child(walls)
	for i in n:
		var col: Color = wall_cols[(i / 2) % 2]
		for side in [1.0, -1.0]:
			var o: float = WALL * side
			var o2: float = (WALL + 0.6) * side
			_cquad(st, _p3(i, o, 0), _p3(i, o, H), _p3(i + 1, o, H), _p3(i + 1, o, 0), col)
			_cquad(st, _p3(i, o, H), _p3(i, o2, H), _p3(i + 1, o2, H), _p3(i + 1, o, H), col)
			# colisor: caixa grossa atrás da face do muro
			var a := _p3(i, (WALL + 0.75) * side)
			var b := _p3(i + 1, (WALL + 0.75) * side)
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.5, 3.0, a.distance_to(b) + 0.6)
			cs.shape = box
			var mid := (a + b) * 0.5 + Vector3(0, 1.0, 0)
			cs.transform = Transform3D(Basis(Vector3.UP, atan2(b.x - a.x, b.z - a.z)), mid)
			walls.add_child(cs)
	var wm := MeshInstance3D.new()
	wm.mesh = st.commit()
	wm.material_override = _vc_mat(0.6)
	add_child(wm)

	# chão (colisão)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var gcs := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(1200, 2, 1200)
	gcs.shape = gbox
	gcs.position = Vector3(0, -1, 0)
	ground.add_child(gcs)
	var gpm := PhysicsMaterial.new()
	gpm.friction = 0.6
	ground.physics_material_override = gpm
	add_child(ground)
	var gmesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	gmesh.mesh = plane
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grass.gdshader")
	gmesh.material_override = gm
	gmesh.position.y = -0.01
	gmesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gmesh)

	# rampas: visual do Blender + colisor convexo
	for r in ramps:
		var body := StaticBody3D.new()
		var vis: Node3D = ramp_scene.instantiate() if ramp_scene else null
		body.position = r.pos
		# o modelo sobe para -Z local; a pista anda para +heading
		body.rotation.y = r.heading + PI
		if vis:
			body.add_child(vis)
		var cs := CollisionShape3D.new()
		var cv := ConvexPolygonShape3D.new()
		var hw: float = r.wid * 0.5
		var hl: float = r.len * 0.5
		cv.points = PackedVector3Array([
			Vector3(-hw, 0, hl), Vector3(hw, 0, hl), Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl),
			Vector3(-hw, r.h, -hl), Vector3(hw, r.h, -hl)])
		cs.shape = cv
		body.add_child(cs)
		add_child(body)

	# boost pads
	for p in pads:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(p.wid, p.len)
		mi.mesh = pm
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/pad.gdshader")
		mi.material_override = sm
		mi.position = p.pos + Vector3(0, 0.07, 0)
		mi.rotation.y = p.heading
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

	# linha de chegada
	var a0 := at(0)
	var fin := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(ROAD_W, 3)
	fin.mesh = fm
	var fsm := ShaderMaterial.new()
	fsm.shader = load("res://shaders/checker.gdshader")
	fin.material_override = fsm
	fin.position = a0.pos + Vector3(0, 0.05, 0)
	fin.rotation.y = a0.heading
	add_child(fin)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	for v in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
		st.set_normal(Vector3.UP)
		st.set_uv(v[1])
		st.add_vertex(v[0])


func _cquad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	var nrm := (b - a).cross(d - a).normalized()
	if nrm.y < -0.1:
		nrm = -nrm
	for v in [a, b, c, a, c, d]:
		st.set_color(col)
		st.set_normal(nrm)
		st.add_vertex(v)


func _vc_mat(rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
