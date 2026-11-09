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
	_fair()
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
	var shifts := {}
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
			var sv := (lf if tl else -lf) * (W + 8.0) * (1.0 if i + 1 < m else 0.0)
			shifts[i] = sv
			acc += sv
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
				# entrada e saída retas e tangentes ao círculo; as quinas até os pontos vizinhos são arredondadas em _fair
				var st0 := p + dh_dir * 12.0
				cps.append({"p": st0, "feat": true, "kind": "helix", "lead": true})
				var c := st0 + lft * R * sg
				var steps := int(absf(turns) * 24.0)
				for k in range(1, steps + 1):
					var a := sg * float(k) / steps * absf(turns) * TAU
					var off := Vector3(st0.x - c.x, 0, st0.z - c.z).rotated(Vector3.UP, a)
					cps.append({"p": Vector3(c.x + off.x, st0.y + dh * k / steps, c.z + off.z), "feat": true, "kind": "helix"})
				cps.append({"p": Vector3(st0.x, st0.y + dh, st0.z) + dh_dir * 12.0, "feat": true, "kind": "helix", "lead": true})
			"loop":
				var R: float = f[1]
				# o looping sai deslocado para o lado da próxima curva; o resto da pista já foi
				# deslocado junto (acc), então a reta de entrada e a de saída ficam paralelas à original
				var sv: Vector3 = shifts.get(i, Vector3.ZERO)
				var nxt_u := nxt - sv
				d = Vector3(nxt_u.x - p.x, 0, nxt_u.z - p.z).normalized()
				var mid := p.lerp(nxt_u, 0.4)
				var right := sv.normalized() if sv.length() > 0.1 else Vector3(d.z, 0, -d.x)
				var shift := sv.length()
				cps.append({"p": mid - d * 16.0, "feat": true, "kind": "loop"})
				cps.append({"p": mid - d * 7.0, "feat": true, "kind": "loop"})
				for k in range(0, 29):
					var th := float(k) / 28.0 * TAU
					# deslocamento lateral em "smoothstep": sem quina na entrada nem na saída do looping
					var u := th / TAU
					var q := mid + d * R * sin(th) + Vector3.UP * R * (1.0 - cos(th)) + right * shift * (u * u * (3.0 - 2.0 * u))
					cps.append({"p": q, "loop": true, "feat": true, "lc": mid + Vector3.UP * R, "la": right, "lr": R, "kind": "loop"})
				cps.append({"p": mid + sv + d * 7.0, "feat": true, "kind": "loop"})
				cps.append({"p": mid + sv + d * 16.0, "feat": true, "kind": "loop"})
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
				# saca-rolhas (espiral de 360°), estilo montanha-russa: a pista gira em volta de um eixo
				# R metros acima dela ("heartline"), com taxa de giro constante no meio e rampas suaves
				# (smoothstep) na entrada e na saída — começa e termina sem tranco.
				var sg := signf(f[1])
				var R := 6.5
				var N := 32
				var A0 := p.lerp(nxt, 0.1)
				var A1 := p.lerp(nxt, 0.9)
				var dd := (A1 - A0).normalized()
				var up0 := (Vector3.UP - dd * dd.y).normalized()
				var racc := [0.0]
				for k in N:
					var um := (float(k) + 0.5) / N
					var rate := smoothstep(0.0, 0.24, um) * smoothstep(1.0, 0.76, um)
					racc.append(float(racc[k]) + rate)
				for k in N + 1:
					var u := float(k) / N
					var roll := deg_to_rad(360.0 * float(racc[k]) / float(racc[N])) * sg
					var A := A0.lerp(A1, u)
					var Ur := up0.rotated(dd, -roll)
					var q := A + (up0 - Ur) * R
					cps.append({"p": q, "feat": true, "kind": "cork", "ckc": A0 + up0 * R, "ckd": dd})
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
var fcore := PackedByteArray()
var corkf := PackedByteArray()
var _lc := PackedVector3Array()
var _la := PackedVector3Array()
var _lr := PackedFloat32Array()


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
		var in_cork: bool = a.has("ckc") and b.has("ckc")
		corkf.append(1 if in_cork else 0)
		if in_cork:
			_lc.append(a.ckc)
			_la.append(a.ckd)
		else:
			_lc.append(a.get("lc", Vector3.ZERO))
			_la.append(a.get("la", Vector3.RIGHT))
		_lr.append(float(a.get("lr", b.get("lr", 0.0))))
		feat.append(1 if (a.get("feat", false) or b.get("feat", false)) else 0)
		ftype.append(String(a.get("kind", b.get("kind", ""))))
		# miolo do elemento: os dois pontos de controle do trecho são do mesmo elemento
		fcore.append(1 if (a.has("kind") and String(a.get("kind")) == String(b.get("kind", "")) and not b.get("lead", false) and not a.get("lead", false)) else 0)
		_bank.append(0.0)


## arredonda quinas: fora de loopings, espirais e saltos, nenhuma curva fica mais fechada que RMIN
## (as emendas entre elementos — fim da espiral e começo da torção, por exemplo — viravam cotovelos)
const RMIN := 26.0


func _fair() -> void:
	var lock := PackedByteArray()
	lock.resize(n)
	for i in n:
		var lk := ftype[i] == "helix" and fcore[i] == 1
		for k in range(-6, 7):
			var j := idx(i + k)
			if loopf[j] == 1 or corkf[j] == 1 or (gap[j] == 1 and absi(k) <= 4):
				lk = true
		lock[i] = 1 if lk else 0
	var amax := ds / RMIN
	for it in 400:
		var moved := false
		for i in n:
			if lock[i] == 1:
				continue
			var a := P[idx(i - 1)]
			var b := P[i]
			var c := P[idx(i + 1)]
			var d1 := Vector2(b.x - a.x, b.z - a.z)
			var d2 := Vector2(c.x - b.x, c.z - b.z)
			if d1.length() < 0.01 or d2.length() < 0.01:
				continue
			if absf(d1.angle_to(d2)) > amax:
				var mid := (a + c) * 0.5
				P[i] = Vector3(lerpf(b.x, mid.x, 0.5), b.y, lerpf(b.z, mid.z, 0.5))
				moved = true
		if not moved:
			break


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
		curv[i] = c if (loopf[i] == 0 and corkf[i] == 0) else 0.0
		kl[i] = -curv[i] if ftype[i] != "cork" else 0.0
	var base := PackedVector3Array()
	base.resize(n)
	for i in n:
		var t := T[i]
		if loopf[i] == 1 or corkf[i] == 1:
			# no looping e no saca-rolhas o "para cima" aponta para o eixo (o asfalto fica por dentro)
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
		var auto := clampf((acc / maxi(cnt, 1)) * 420.0, -16.0, 16.0) if (loopf[i] == 0 and corkf[i] == 0) else 0.0
		var bdeg := auto + _bank[i]
		if loopf[i] == 0 and corkf[i] == 0:
			# perto do chão a inclinação é limitada: a borda baixa do asfalto nunca desce abaixo do terreno
			var elev := P[i].y - float(theme.gy)
			var maxb := rad_to_deg(asin(clampf((elev - 0.15) / (WALL + 0.5), 0.0, 1.0)))
			bdeg = clampf(bdeg, -maxb, maxb)
		var b := deg_to_rad(bdeg)
		var up := base[i].rotated(T[i], -b)
		var lf := up.cross(T[i]).normalized()
		L[i] = lf
		U[i] = T[i].cross(lf).normalized()


## centro, eixo e raio do looping na amostra i (para a câmera lateral)
func loop_info(i: int) -> Dictionary:
	return {"center": _lc[i], "axis": _la[i], "r": _lr[i]}


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


## referencial interpolado entre as amostras (segue a mesma corda do colisor, sem "degraus" de 2 m)
func frame(p: Vector3, i: int) -> Dictionary:
	var fo := (p - P[i]).dot(T[i]) / ds
	var j := idx(i + (1 if fo >= 0.0 else -1))
	var w := clampf(absf(fo), 0.0, 1.0)
	var tt := T[i].lerp(T[j], w).normalized()
	var tu := U[i].lerp(U[j], w)
	tu = (tu - tt * tt.dot(tu)).normalized()
	var tl := tu.cross(tt).normalized()
	var pp := P[i].lerp(P[j], w)
	var dd := p - pp
	return {"t": tt, "u": tu, "l": tl, "h": dd.dot(tu), "lat": dd.dot(tl)}


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
func _off(i: int, lat: float, h: float) -> Vector3:
	var k := idx(i)
	return P[k] + L[k] * lat + U[k] * h


## quad com normal por vértice (a, b no começo; c, d no fim): sombreado liso, sem facetas
func _qn(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, col: Color, uv := Rect2(0, 0, 0, 0)) -> void:
	var uvs := [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	var vs := [a, b, c, d]
	var ns := [na, na, nb, nb]
	# o Godot considera frente o lado em sentido horário: a ordem dos vértices segue a normal pedida
	# (antes o asfalto ficava "de costas", com a normal virada para baixo e quase sem luz)
	var order := [0, 2, 1, 0, 3, 2] if (b - a).cross(c - a).dot(na + nb) > 0.0 else [0, 1, 2, 0, 2, 3]
	for k in order:
		st.set_color(col)
		st.set_normal(ns[k])
		st.set_uv(uvs[k])
		st.add_vertex(vs[k])


# referenciais finos para a malha: onde a pista curva ou gira rápido (looping, torção, espiral) cada
# trecho de 2 m é dividido, com posição em Hermite (segue a curva, não a corda) e "para cima" interpolado
var fP := PackedVector3Array()
var fL := PackedVector3Array()
var fU := PackedVector3Array()
var fT := PackedVector3Array()
var fi := PackedInt32Array()
var ft := PackedFloat32Array()


func _fine() -> void:
	fP.clear(); fL.clear(); fU.clear(); fT.clear(); fi.clear(); ft.clear()
	for i in n:
		var j := (i + 1) % n
		var ang := maxf(rad_to_deg(T[i].angle_to(T[j])) / 2.5, rad_to_deg(L[i].angle_to(L[j])) / 2.0)
		var m := clampi(int(ceil(ang)), 1, 6)
		for q in m:
			var t := float(q) / m
			var t2 := t * t
			var t3 := t2 * t
			var p := P[i] * (2.0 * t3 - 3.0 * t2 + 1.0) + T[i] * ds * (t3 - 2.0 * t2 + t) + P[j] * (-2.0 * t3 + 3.0 * t2) + T[j] * ds * (t3 - t2)
			var tg := (P[i] * (6.0 * t2 - 6.0 * t) + T[i] * ds * (3.0 * t2 - 4.0 * t + 1.0) + P[j] * (-6.0 * t2 + 6.0 * t) + T[j] * ds * (3.0 * t2 - 2.0 * t)).normalized()
			var up := U[i].slerp(U[j], t)
			up = (up - tg * tg.dot(up)).normalized()
			fP.append(p)
			fT.append(tg)
			fU.append(up)
			fL.append(up.cross(tg).normalized())
			fi.append(i)
			ft.append(t)


func _fo(k: int, lat: float, h: float) -> Vector3:
	return fP[k] + fL[k] * lat + fU[k] * h


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
	# altura/espessura da mureta por amostra, suavizadas: sem degrau ("remendo") na entrada do looping
	var rh0 := PackedFloat32Array()
	var rw0 := PackedFloat32Array()
	var dp0 := PackedFloat32Array()
	for i in n:
		var lp := loopf[i] == 1
		rh0.append(1.4 if lp else (2.2 if feat[i] == 1 else 1.45))
		rw0.append(0.2 if lp else 0.5)
		dp0.append(-0.35 if lp else -0.8)
	var rhs := PackedFloat32Array()
	var rws := PackedFloat32Array()
	var dps := PackedFloat32Array()
	for i in n:
		var a1 := 0.0
		var a2 := 0.0
		var a3 := 0.0
		for k in range(-4, 5):
			var j := (i + k + n) % n
			a1 += rh0[j]
			a2 += rw0[j]
			a3 += dp0[j]
		rhs.append(a1 / 9.0)
		rws.append(a2 / 9.0)
		dps.append(a3 / 9.0)
	_fine()
	var N := fP.size()
	for k in N:
		var i := fi[k]
		if gap[i] == 1:
			continue
		var k2 := (k + 1) % N
		var j := (i + 1) % n
		var t0 := ft[k]
		var t1 := 1.0 if fi[k2] != i else ft[k2]
		var na := fU[k]
		var nb := fU[k2]
		var v0 := (float(i) + t0) * ds
		var v1 := (float(i) + t1) * ds
		# asfalto em faixas: nos trechos que giram cada pedaço fica quase plano (sem dobra na diagonal)
		var strips := 4
		for sidx in strips:
			var la := HALF - 2.0 * HALF * float(sidx) / strips
			var lb := HALF - 2.0 * HALF * float(sidx + 1) / strips
			var a := _fo(k, la, 0.02)
			var b := _fo(k, lb, 0.02)
			var c := _fo(k2, lb, 0.02)
			var d := _fo(k2, la, 0.02)
			_qn(road, a, b, c, d, na, nb, Color.WHITE, Rect2(float(sidx) / strips, v0, 1.0 / strips, v1 - v0))
			road_col.append_array([a, b, c, a, c, d])
		var RH := lerpf(rhs[i], rhs[j], t0)
		var RH2 := lerpf(rhs[i], rhs[j], t1)
		var rw := lerpf(rws[i], rws[j], t0)
		var rw2 := lerpf(rws[i], rws[j], t1)
		var depth := lerpf(dps[i], dps[j], t0)
		var depth2 := lerpf(dps[i], dps[j], t1)
		var cc := curb_a if i % 2 == 1 else curb_b
		var rc := rail_a if (i / 2) % 2 == 0 else rail_b
		for sgn: float in [1.0, -1.0]:
			# zebra levemente elevada
			_qn(side, _fo(k, sgn * HALF, 0.07), _fo(k, sgn * (HALF + 1.0), 0.07), _fo(k2, sgn * (HALF + 1.0), 0.07), _fo(k2, sgn * HALF, 0.07), na, nb, cc)
			# acostamento
			_qn(side, _fo(k, sgn * (HALF + 1.0), 0.04), _fo(k, sgn * WALL, 0.04), _fo(k2, sgn * WALL, 0.04), _fo(k2, sgn * (HALF + 1.0), 0.04), na, nb, shoulder)
			# colisão lisa: zebra e acostamento no mesmo plano do asfalto (sem degrau para o carro engatar)
			var f0 := _fo(k, sgn * HALF, 0.02)
			var f1 := _fo(k, sgn * WALL, 0.02)
			var f2 := _fo(k2, sgn * WALL, 0.02)
			var f3 := _fo(k2, sgn * HALF, 0.02)
			road_col.append_array([f0, f1, f2, f0, f2, f3])
			# guard-rail: face interna, topo e face externa
			var w0 := _fo(k, sgn * WALL, 0.0)
			var w1 := _fo(k, sgn * WALL, RH)
			var w2 := _fo(k2, sgn * WALL, RH2)
			var w3 := _fo(k2, sgn * WALL, 0.0)
			_qn(side, w0, w1, w2, w3, -fL[k] * sgn, -fL[k2] * sgn, rc)
			var o0 := _fo(k, sgn * (WALL + rw), RH)
			var o1 := _fo(k2, sgn * (WALL + rw2), RH2)
			_qn(side, w1, o0, o1, w2, na, nb, rc.lightened(0.15))
			var e0 := _fo(k, sgn * (WALL + rw), depth)
			var e1 := _fo(k2, sgn * (WALL + rw2), depth2)
			_qn(side, o0, e0, e1, o1, fL[k] * sgn, fL[k2] * sgn, rc.darkened(0.25))
			rail_col.append_array([w0, w1, w2, w0, w2, w3, w1, o0, o1, w1, o1, w2])
		# parte de baixo da pista
		_qn(side, _fo(k, -(WALL + rw), depth), _fo(k, WALL + rw, depth), _fo(k2, WALL + rw2, depth2), _fo(k2, -(WALL + rw2), depth2), -na, -nb, under)
		# pontas da pista junto dos vãos de salto: tampa com faixas de perigo
		var caps := []
		if fi[k2] != i and gap[j] == 1:
			caps.append([k2, 1.0, rw2, depth2])
		if ft[k] == 0.0 and gap[idx(i - 1)] == 1:
			caps.append([k, -1.0, rw, depth])
		for cap in caps:
			var kk: int = cap[0]
			var cw: float = cap[2]
			var cd: float = cap[3]
			for sg in range(-6, 6):
				var lq := float(sg) / 6.0 * (WALL + cw)
				var lr := float(sg + 1) / 6.0 * (WALL + cw)
				var hc := Color("#ffcc1f") if (sg % 2 == 0) else Color("#26272d")
				var tn: Vector3 = fT[kk] * float(cap[1])
				_qn(side, _fo(kk, lq, 0.07), _fo(kk, lr, 0.07), _fo(kk, lr, cd), _fo(kk, lq, cd), tn, tn, hc)

	var rm := MeshInstance3D.new()
	road.generate_tangents()   # o asfalto usa normal map (relevo do agregado)
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
	wb.set_meta("rail", true)
	# mureta "segura": sem quique (o carro desliza encostado em vez de ser arremessado)
	var wpm := PhysicsMaterial.new()
	wpm.friction = 0.08
	wpm.bounce = 0.0
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


## pilares sob os trechos elevados: o topo segue a parte de baixo da pista NO PONTO do pilar (em curva
## inclinada o lado de dentro fica mais baixo; antes o topo ficava na altura do centro e furava o asfalto)
## e nenhum pilar atravessa outro trecho da pista que passe por baixo (viaduto).
const PILLAR_R := 0.9


func pillar_xforms() -> Array:
	var out: Array = []
	if not theme.pillars:
		return out
	var gy: float = theme.gy
	for i in range(0, n, 7):
		if gap[i] == 1 or loopf[i] == 1 or U[i].y < 0.8:
			continue
		var tilt := sqrt(maxf(0.0, 1.0 - U[i].y * U[i].y)) / maxf(U[i].y, 0.1)
		for sgn: float in [-1.0, 1.0]:
			var lat := sgn * HALF * 0.55
			var tp := _off(i, lat, -0.9)
			var top := tp.y
			# a pista sobe/desce ao longo do trecho: o topo fica abaixo da parte de baixo dos vizinhos também
			for dk in [-2, -1, 1, 2]:
				if gap[idx(i + dk)] == 0:
					top = minf(top, _off(i + dk, lat, -0.9).y)
			top -= 0.08 + PILLAR_R * tilt
			if top - gy < 1.2:
				continue
			if _hits_other_road(Vector2(tp.x, tp.z), gy, top, i):
				continue
			out.append(Transform3D(Basis().scaled(Vector3(1, top - gy, 1)), Vector3(tp.x, (top + gy) * 0.5, tp.z)))
	return out


## alguma parte da pista (fora o próprio trecho i) cruza a coluna vertical em xz entre y0 e y1?
func _hits_other_road(xz: Vector2, y0: float, y1: float, i: int) -> bool:
	for k in n:
		var dk := absi(k - i)
		if mini(dk, n - dk) < 6 or gap[k] == 1:
			continue
		var t := Vector2(T[k].x, T[k].z)
		if t.length() < 0.2:
			# trecho quase vertical (looping): basta estar perto em xz
			if Vector2(P[k].x, P[k].z).distance_to(xz) < WALL + 1.0 + PILLAR_R and P[k].y > y0 - 1.0 and P[k].y < y1 + 1.5:
				return true
			continue
		t = t.normalized()
		var d := xz - Vector2(P[k].x, P[k].z)
		var along := d.dot(t)
		if absf(along) > ds * 0.75 + PILLAR_R:
			continue
		var lat_h := d.dot(Vector2(-t.y, t.x))
		var lk := Vector2(L[k].x, L[k].z)
		var latk := lat_h * signf(lk.dot(Vector2(-t.y, t.x))) / maxf(lk.length(), 0.3)
		if absf(latk) > WALL + 1.0 + PILLAR_R:
			continue
		var y := _off(k, latk, 0.0).y
		if y > y0 - 1.0 and y < y1 + 1.5:
			return true
	return false


func _build_pillars() -> void:
	var xs := pillar_xforms()
	if xs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = PILLAR_R
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
	# cor da placa: laranja-turbo; ciano onde o chão/pista já são laranja (brinquedo, vulcão, deserto)
	var accent := Color("#ff8a1a")
	if int(theme.road) == 1 or int(theme.ground) == 4 or int(theme.ground) == 1:
		accent = Color("#22d8ff")
	for p in pads:
		# malha que acompanha a pista (curvas, rampas e inclinação): a placa nunca atravessa o asfalto
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var L0 := 6.0
		var segs := 6
		var hw := float(p.wid) * 0.5
		var rows := []
		for k in segs + 1:
			var ss: float = float(p.s) - L0 * 0.5 + L0 * float(k) / segs
			var row := []
			for e in [-1.0, 1.0]:
				var a := at(ss, float(p.lat) - hw * e)
				row.append([(a.pos as Vector3) + (a.up as Vector3) * 0.06, a.up, Vector2((e + 1.0) * 0.5, float(k) / segs)])
			rows.append(row)
		for k in segs:
			var r0: Array = rows[k]
			var r1: Array = rows[k + 1]
			var tri := [r0[0], r0[1], r1[1], r0[0], r1[1], r1[0]]
			var ga: Vector3 = (r0[1][0] as Vector3) - (r0[0][0] as Vector3)
			var gb: Vector3 = (r1[1][0] as Vector3) - (r0[0][0] as Vector3)
			if ga.cross(gb).dot(r0[0][1] as Vector3) > 0.0:
				tri = [r0[0], r1[1], r0[1], r0[0], r1[0], r1[1]]
			for v in tri:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.add_vertex(v[0])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("accent", accent)
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		p["mat"] = sm
		p["hit"] = 0.0
		p["accent"] = accent


## pontos para decoração: placas de curva, postes, pneus, bandeiras e outdoors.
## Pista perto do chão: objeto no chão. Pista elevada: preso em cima da mureta (nada flutuando).
func _elev(k: int) -> float:
	return P[k].y - float(theme.gy)


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, float(theme.gy), p.z)


func decor_spots() -> Array:
	var out: Array = []
	var RH := 1.15
	var i := 0
	while i < n:
		if feat[i] == 0 and gap[i] == 0 and U[i].y > 0.9 and absf(curv[i]) > 1.0 / 45.0:
			var outside := signf(curv[i])  # curva para a esquerda -> lado de fora é a direita
			var k := idx(i - 6)
			if feat[k] == 0:
				var yaw := atan2(-T[k].x, -T[k].z)
				if _elev(k) < 1.5:
					var pos := _ground(P[k] + L[k] * outside * (WALL + 1.6))
					out.append({"kind": "prop_sign", "xf": Transform3D(Basis(Vector3.UP, yaw), pos), "flip": outside < 0})
					var k2 := idx(i + 4)
					out.append({"kind": "prop_tirewall", "xf": Transform3D(Basis(Vector3.UP, atan2(T[k2].x, T[k2].z)), _ground(P[k2] + L[k2] * outside * (WALL + 2.2)))})
				else:
					var pos := P[k] + L[k] * outside * (WALL + 0.25) + U[k] * RH
					out.append({"kind": "prop_sign", "xf": Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 0.6), pos), "flip": outside < 0})
			i += 18
			continue
		i += 1
	for k in range(0, n, 22):
		if gap[k] == 1 or feat[k] == 1 or U[k].y < 0.9:
			continue
		var sgn := 1.0 if (k / 22) % 2 == 0 else -1.0
		var yaw := atan2(-L[k].x * sgn, -L[k].z * sgn)
		if _elev(k) < 1.5:
			out.append({"kind": "prop_lamp", "xf": Transform3D(Basis(Vector3.UP, yaw), _ground(P[k] + L[k] * sgn * (WALL + 1.3)))})
		else:
			var pos := P[k] + L[k] * sgn * (WALL + 0.25) + U[k] * RH
			out.append({"kind": "prop_lamp", "xf": Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 0.75), pos)})
	for k in [6, 12, 18]:
		if _elev(k) > 1.5:
			continue
		for sgn: float in [1.0, -1.0]:
			out.append({"kind": "prop_flag", "xf": Transform3D(Basis(Vector3.UP, atan2(T[k].x, T[k].z)), _ground(P[k] + L[k] * sgn * (WALL + 2.0)))})
	var kb := idx(int(40.0 / ds))
	if _elev(kb) < 1.5:
		out.append({"kind": "prop_billboard", "xf": Transform3D(Basis(Vector3.UP, atan2(-L[kb].x, -L[kb].z)), _ground(P[kb] + L[kb] * (WALL + 6.0)))})
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
	# sobreposição real em 3D (no referencial da pista): dois trechos ocupando o mesmo espaço
	var over := 0
	var over_at := []
	var far := int(60.0 / ds)
	for i in range(0, n, 2):
		for j in range(0, n, 2):
			var dij := absi(i - j)
			if mini(dij, n - dij) < far:
				continue
			# bordas e centro do trecho j dentro do "volume do carro" do trecho i (largura da pista x 3,5 m de altura)?
			var hit := false
			for e: float in [-WALL, 0.0, WALL]:
				var d: Vector3 = P[j] + L[j] * e - P[i]
				var dt := d.dot(T[i])
				var du := d.dot(U[i])
				if absf(dt) < 3.0 and absf(d.dot(L[i])) < WALL and du > -1.0 and du < 3.5:
					hit = true
			if hit:
				over += 1
				if over_at.size() < 6:
					over_at.append([int(i * ds), int(j * ds), Vector3i(P[i])])
	var min_y := 1e9
	var under := 0
	var under_at := []
	for i in n:
		if gap[i] == 0:
			min_y = minf(min_y, P[i].y)
			# o asfalto/acostamento não pode ficar abaixo do terreno (senão o chão "vaza" na pista)
			for e: float in [-WALL, WALL]:
				var q := _off(i, e, 0.04)
				if q.y < float(theme.gy) + 0.04:
					under += 1
					if under_at.size() < 4:
						under_at.append([int(i * ds), snappedf(q.y - float(theme.gy), 0.01)])
	var pil := 0
	var pil_at := []
	for xf: Transform3D in pillar_xforms():
		var top := xf.origin.y + xf.basis.y.length() * 0.5
		var c := Vector2(xf.origin.x, xf.origin.z)
		# o asfalto (com zebra/acostamento) mais próximo acima do topo do pilar, no próprio trecho
		var hit := false
		for k in n:
			if gap[k] == 1:
				continue
			for e: float in [-WALL, -HALF, -HALF * 0.55, 0.0, HALF * 0.55, HALF, WALL]:
				var q := _off(k, e, 0.0)
				if Vector2(q.x, q.z).distance_to(c) < PILLAR_R + 0.4 and q.y < top + 0.6 and q.y > float(theme.gy):
					hit = true
		if hit:
			pil += 1
			if pil_at.size() < 4:
				pil_at.append(Vector3i(xf.origin))
	return {"len": int(length), "min_r": snappedf(min_r, 0.1), "pillar_hits": pil, "pil_at": pil_at, "at": Vector3i(min_at), "wat": Vector3i(wa), "conflicts": conflicts, "worst": snappedf(worst, 0.1), "min_y": snappedf(min_y, 0.1), "overlap3d": over, "over_at": over_at, "sub_ground": under, "sub_at": under_at}
