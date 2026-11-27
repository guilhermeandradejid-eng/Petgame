extends SkeletonModifier3D
# Molas de continuidade (follow-through) sobre a pose animada: chapéu, saia, pernas soltas, gorro, antenas.
# Cada osso vira um ponto com massa na ponta, preso por mola amortecida à ponta animada. Roda a 60 Hz fixo,
# depois da AnimationPlayer; a escala de tempo vai a 0 no congelamento de impacto.


var cfg: Array = []      # [{bone:int, len:float, k:float, c:float, g:float}]
var st: Dictionary = {}  # bone -> [p, v]
var time_scale := 1.0
var dt_fixo := 1.0 / 60.0

func add_spring(skel: Skeleton3D, name: String, freq: float, zeta: float, grav := 0.0) -> void:
	var b := skel.find_bone(name)
	if b < 0:
		return
	var L := 0.15
	var kids := skel.get_bone_children(b)
	if kids.size() > 0:
		L = skel.get_bone_rest(kids[0]).origin.length()
	var w := TAU * freq
	cfg.append({"bone": b, "len": max(L, 0.08), "k": w * w, "c": 2.0 * zeta * w, "g": grav})

func reset() -> void:
	st.clear()

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	var W := skel.global_transform
	var dt := dt_fixo * time_scale
	for c in cfg:
		var b: int = c["bone"]
		var G := W * skel.get_bone_global_pose(b)
		var head := G.origin
		var tgt := G * Vector3(0, c["len"], 0)
		if not st.has(b):
			st[b] = [tgt, Vector3.ZERO]
		var p: Vector3 = st[b][0]
		var v: Vector3 = st[b][1]
		if dt > 0.0:
			var sub := 4
			var h := dt / sub
			for i in sub:
				var a: Vector3 = (tgt - p) * c["k"] - v * c["c"] + Vector3(0, -c["g"], 0)
				v += a * h
				p += v * h
			# mantém o comprimento do osso
			p = head + (p - head).normalized() * (tgt - head).length()
		st[b] = [p, v]
		var d0 := (tgt - head).normalized()
		var d1 := (p - head).normalized()
		if d0.dot(d1) > 0.99999:
			continue
		var q := Quaternion(d0, d1)
		var nb := Basis(q) * G.basis
		var NG := W.affine_inverse() * Transform3D(nb, head)
		skel.set_bone_global_pose(b, NG)
