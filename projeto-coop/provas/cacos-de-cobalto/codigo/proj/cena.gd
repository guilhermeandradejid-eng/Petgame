extends RefCounted
# Cenário do Cais da Salga: piso, parede, mar, meio-fio; mapas de estado do chão (por azulejo) e
# propagação da Condução pelo grafo do rejunte (Dijkstra com custo menor para seguir reto).

const T := 0.25
const NX := 72      # azulejos em x (18 m)
const NZ := 48      # azulejos em z (12 m)
const X0 := -9.0
const Z0 := -6.0
const BOND_X := -0.75
const ROPE_X := -1.0

var main: Node3D
var puddles: Array = []   # [cx, cz, rx, rz, força]
var oil_spots: Array = []
var burn_spots: Array = []
var salt_spots: Array = []
var quay := Vector3(-6.4, 0.55, 0.0)   # água onde x < a + b*z
var state_img: Image
var state_tex: ImageTexture
var shock_img: Image
var shock_tex: ImageTexture
var floor_mat: ShaderMaterial
var wall_mat: ShaderMaterial
var sea_mat: ShaderMaterial

func _init(m: Node3D) -> void:
	main = m

func blob(list: Array, x: float, z: float) -> float:
	var v := 0.0
	for b in list:
		var dx: float = (x - b[0]) / b[2]
		var dz: float = (z - b[1]) / b[3]
		v = max(v, float(b[4]) * clamp(1.15 - (dx * dx + dz * dz), 0.0, 1.0))
	return clamp(v, 0.0, 1.0)

func wet_at(x: float, z: float) -> float:
	return blob(puddles, x, z)

func make_state() -> void:
	state_img = Image.create(NX, NZ, false, Image.FORMAT_RGBA8)
	for j in NZ:
		for i in NX:
			var x := X0 + (i + 0.5) * T
			var z := Z0 + (j + 0.5) * T
			state_img.set_pixel(i, j, Color(blob(puddles, x, z), blob(oil_spots, x, z), blob(burn_spots, x, z), blob(salt_spots, x, z)))
	if state_tex:
		state_tex.update(state_img)
	else:
		state_tex = ImageTexture.create_from_image(state_img)

func build(atlas_piso: Texture2D, atlas_parede: Texture2D, painel: Texture2D, placa: Texture2D, sm: Callable) -> void:
	make_state()
	shock_img = Image.create(73, 97, false, Image.FORMAT_RGBA8)
	shock_img.fill(Color(1, 1, 0, 0))
	shock_tex = ImageTexture.create_from_image(shock_img)
	# piso
	floor_mat = sm.call("piso", {"atlas": atlas_piso, "state": state_tex, "shock": shock_tex, "bond_x": BOND_X, "rope_x0": ROPE_X,
		"state_rect": Vector4(X0, Z0, NX * T, NZ * T), "quay": quay})
	var pm := PlaneMesh.new()
	pm.size = Vector2(NX * T, NZ * T)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	var fl := MeshInstance3D.new()
	fl.mesh = pm
	fl.material_override = floor_mat
	fl.position = Vector3(X0 + NX * T * 0.5, 0, Z0 + NZ * T * 0.5)
	main.add_child(fl)
	# película de reflexo do molhado (Forward+)
	var rm := MeshInstance3D.new()
	rm.mesh = pm
	rm.material_override = sm.call("reflexo", {"state": state_tex, "state_rect": Vector4(X0, Z0, NX * T, NZ * T)})
	rm.position = fl.position + Vector3(0, 0.004, 0)
	rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(rm)
	# parede (norte)
	wall_mat = sm.call("parede", {"atlas": atlas_parede, "painel": painel, "placa": placa})
	var wm := QuadMesh.new()
	wm.size = Vector2(NX * T + 4.0, 6.0)
	var wl := MeshInstance3D.new()
	wl.mesh = wm
	wl.material_override = wall_mat
	wl.position = Vector3(0, 3.0, Z0)
	main.add_child(wl)
	# mar
	sea_mat = sm.call("mar", {})
	var sp := PlaneMesh.new()
	sp.size = Vector2(30, 30)
	var se := MeshInstance3D.new()
	se.mesh = sp
	se.material_override = sea_mat
	se.position = Vector3(-14, -0.55, 4)
	main.add_child(se)

# ------------------------------------------------------------------ Condução pelo rejunte
# Nós em (iv, k): x = iv*T, z = k*T/2. Juntas verticais sempre contínuas; horizontais dependem do
# assentamento da coluna (amarração desloca meia peça nas colunas ímpares a leste).
func _zoff(ci: int) -> int:
	return 1 if (ci * T >= BOND_X and posmod(ci, 2) == 1) else 0

func _nid(iv: int, k: int) -> int:
	return (iv + 36) + (k + 48) * 73

func conduct(src: Vector2, targets: Array, speed := 8.0, seed := 7) -> Dictionary:
	# devolve {"vert": {seg: t}, "hor": {seg: t}} e grava a textura de chegada
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var INF := 1e9
	var NN := 73 * 97
	var dist := PackedFloat32Array()
	dist.resize(NN * 5)
	dist.fill(INF)
	var pred := PackedInt32Array()
	pred.resize(NN * 5)
	pred.fill(-1)
	var jit := {}
	var siv := int(round(src.x / T))
	var sk := int(round(src.y / (T * 0.5)))
	var s0 := _nid(siv, sk) * 5
	dist[s0] = 0.0
	var heap: Array = [[0.0, s0]]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while heap.size() > 0:
		var top: Array = _pop(heap)
		var d: float = top[0]
		var st: int = top[1]
		if d > dist[st] + 1e-5:
			continue
		var node := st / 5
		var indir := st % 5
		var iv := node % 73 - 36
		var k := node / 73 - 48
		for di in 4:
			var dv: Vector2i = dirs[di]
			var niv := iv + dv.x
			var nk := k + dv.y
			if niv < -36 or niv > 36 or nk < -48 or nk > 48:
				continue
			var L := T * 0.5
			var mx := iv * T
			var mz := k * T * 0.5
			if dv.x != 0:
				var ci: int = iv if dv.x > 0 else iv - 1
				if posmod(k - _zoff(ci), 2) != 0:
					continue
				L = T
				mx = (ci + 0.5) * T
			else:
				var kk: int = k if dv.y > 0 else k - 1
				mz = (kk + 0.5) * T * 0.5
			if wet_at(mx, mz) < 0.5:
				continue
			var key := node * 4 + di
			if not jit.has(key):
				jit[key] = rng.randf_range(0.8, 1.3)
			var straight: float = 0.5 if indir == di + 1 else 1.0
			var nd: float = d + L / speed * straight * float(jit[key])
			var ns := _nid(niv, nk) * 5 + di + 1
			if nd < dist[ns]:
				dist[ns] = nd
				pred[ns] = st
				_push(heap, [nd, ns])
	# chegada por nó (mínimo sobre direções)
	var best := PackedFloat32Array()
	best.resize(NN)
	for n in NN:
		var m := INF
		for q in 5:
			m = min(m, dist[n * 5 + q])
		best[n] = m
	# trilhas principais: de cada alvo de volta à origem
	var main_v := {}
	var main_h := {}
	for tg in targets:
		var tv := int(round(tg.x / T))
		var tk := int(round(tg.y / (T * 0.5)))
		var tn := _nid(tv, tk)
		var bs := -1
		var bd := INF
		for q in 5:
			if dist[tn * 5 + q] < bd:
				bd = dist[tn * 5 + q]
				bs = tn * 5 + q
		var cur := bs
		var guard := 0
		while cur >= 0 and pred[cur] >= 0 and guard < 2000:
			guard += 1
			var a := pred[cur] / 5
			var b := cur / 5
			var av := a % 73 - 36
			var ak := a / 73 - 48
			var bv := b % 73 - 36
			var bk := b / 73 - 48
			if av == bv:
				main_v[Vector2i(av, min(ak, bk))] = true
			else:
				main_h[Vector2i(min(av, bv), ak)] = true
			cur = pred[cur]
	# textura: R junta vertical, G junta horizontal, B/A trilha principal
	shock_img.fill(Color(1, 1, 0, 0))
	for iv in range(-36, 37):
		for k in range(-48, 49):
			var n := _nid(iv, k)
			var c := Color(1, 1, 0, 0)
			if k < 48:
				var n2 := _nid(iv, k + 1)
				var t: float = max(best[n], best[n2])
				var tmin: float = min(best[n], best[n2])
				if t < 1e8 and (dist_has_edge(best, n, n2)):
					c.r = clamp(((t + tmin) * 0.5) / 0.01 / 255.0, 0.0, 0.99)
					c.b = 1.0 if main_v.has(Vector2i(iv, k)) else 0.0
			if iv < 36 and posmod(k - _zoff(iv), 2) == 0:
				var n3 := _nid(iv + 1, k)
				var t2: float = max(best[n], best[n3])
				var t2m: float = min(best[n], best[n3])
				if t2 < 1e8 and wet_at((iv + 0.5) * T, k * T * 0.5) >= 0.5:
					c.g = clamp(((t2 + t2m) * 0.5) / 0.01 / 255.0, 0.0, 0.99)
					c.a = 1.0 if main_h.has(Vector2i(iv, k)) else 0.0
			shock_img.set_pixel(iv + 36, k + 48, c)
	shock_tex.update(shock_img)
	return {"best": best}

func dist_has_edge(best: PackedFloat32Array, a: int, b: int) -> bool:
	var iv := a % 73 - 36
	var k := a / 73 - 48
	return wet_at(iv * T, (k + 0.5) * T * 0.5) >= 0.5

func arrival_at(res: Dictionary, p: Vector2) -> float:
	var best: PackedFloat32Array = res["best"]
	var m := 1e9
	var iv0 := int(round(p.x / T))
	var k0 := int(round(p.y / (T * 0.5)))
	for dv in range(-1, 2):
		for dk in range(-2, 3):
			var iv := iv0 + dv
			var k := k0 + dk
			if iv < -36 or iv > 36 or k < -48 or k > 48:
				continue
			m = min(m, best[_nid(iv, k)])
	return m

# heap binário mínimo
func _push(h: Array, e: Array) -> void:
	h.append(e)
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if h[p][0] <= h[i][0]:
			break
		var tmp = h[p]
		h[p] = h[i]
		h[i] = tmp
		i = p

func _pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Array = h.pop_back()
	if h.size() > 0:
		h[0] = last
		var i := 0
		while true:
			var l := 2 * i + 1
			var r := l + 1
			var m := i
			if l < h.size() and h[l][0] < h[m][0]:
				m = l
			if r < h.size() and h[r][0] < h[m][0]:
				m = r
			if m == i:
				break
			var tmp = h[m]
			h[m] = h[i]
			h[i] = tmp
			i = m
	return top
