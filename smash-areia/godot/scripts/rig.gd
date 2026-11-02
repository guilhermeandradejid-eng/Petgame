class_name Rig
extends RefCounted
## Controla o esqueleto exportado do Blender com poses descritas nos eixos do
## personagem (X = lado esquerdo, Y = cima, Z = frente), independentemente da
## orientação de cada osso. Cada rotação é relativa ao pai, como num boneco
## articulado: girar o braço leva junto antebraço, mão e raquete.

var sk: Skeleton3D
var bones := {}          # nome -> índice
var order: Array[int] = []
var parent := {}         # índice -> índice do pai (-1)
var rest_global := {}    # índice -> Basis de repouso no espaço do esqueleto
var rest_origin := {}    # índice -> origem local de repouso
var cur := {}            # nome -> Vector3 (euler atual, suavizado)
var hips := -1


func _init(skeleton: Skeleton3D) -> void:
	sk = skeleton
	for i in sk.get_bone_count():
		bones[sk.get_bone_name(i)] = i
		parent[i] = sk.get_bone_parent(i)
		rest_global[i] = sk.get_bone_global_rest(i).basis.orthonormalized()
		rest_origin[i] = sk.get_bone_rest(i).origin
	# ordem: pais antes dos filhos
	var pending: Array[int] = []
	for i in sk.get_bone_count():
		pending.append(i)
	var done := {}
	while pending.size() > 0:
		var keep: Array[int] = []
		for i in pending:
			var p: int = parent[i]
			if p < 0 or done.has(p):
				order.append(i)
				done[i] = true
			else:
				keep.append(i)
		pending = keep
	hips = bones.get("Hips", -1)


func has(name: String) -> bool:
	return bones.has(name)


## Aplica a pose. target: nome -> Vector3 euler (YXZ) nos eixos do personagem.
## k: fator de suavização (0..1) para misturar com a pose atual.
func apply(target: Dictionary, k: float, hips_offset := Vector3.ZERO) -> void:
	for n in target:
		var t: Vector3 = target[n]
		var c: Vector3 = cur.get(n, Vector3.ZERO)
		cur[n] = Vector3(lerp_angle(c.x, t.x, k), lerp_angle(c.y, t.y, k), lerp_angle(c.z, t.z, k))
	for n in cur.keys():
		if not target.has(n):
			var c2: Vector3 = cur[n]
			cur[n] = c2.lerp(Vector3.ZERO, k)
	var acc := {}
	var glob := {}
	for i in order:
		var name := sk.get_bone_name(i)
		var r := Basis.from_euler(cur.get(name, Vector3.ZERO))
		var p: int = parent[i]
		var q: Basis = (acc[p] as Basis) * r if p >= 0 else r
		acc[i] = q
		var g: Basis = q * (rest_global[i] as Basis)
		glob[i] = g
		var local: Basis = g if p < 0 else (glob[p] as Basis).inverse() * g
		sk.set_bone_pose_rotation(i, local.get_rotation_quaternion())
	if hips >= 0:
		sk.set_bone_pose_position(hips, rest_origin[hips] + hips_offset)


## Transform de repouso de um ponto do modelo expresso no espaço do osso
## (para prender objetos rígidos, como a raquete, com BoneAttachment3D).
func local_to_bone(bone: String, model_xf: Transform3D) -> Transform3D:
	var i: int = bones[bone]
	return sk.get_bone_global_rest(i).affine_inverse() * model_xf


## IK de dois ossos (braço): leva a mão até `target` (espaço do esqueleto),
## dobrando o cotovelo na direção de `pole`. weight 0..1 mistura com a pose FK.
func ik_arm(upper: String, lower: String, target: Vector3, pole: Vector3, weight: float) -> void:
	if weight <= 0.001 or not bones.has(upper) or not bones.has(lower):
		return
	var iu: int = bones[upper]
	var il: int = bones[lower]
	var ih: int = -1
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) == il:
			ih = i
	if ih < 0:
		return
	var gu := sk.get_bone_global_pose(iu)
	var gl := sk.get_bone_global_pose(il)
	var gh := sk.get_bone_global_pose(ih)
	var sh := gu.origin
	var el := gl.origin
	var wr := gh.origin
	var l1 := sk.get_bone_global_rest(iu).origin.distance_to(sk.get_bone_global_rest(il).origin)
	var l2 := sk.get_bone_global_rest(il).origin.distance_to(sk.get_bone_global_rest(ih).origin)
	var d := target - sh
	var dist := clampf(d.length(), 0.05, (l1 + l2) * 0.999)
	var dn := d.normalized()
	var a := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pv := pole - sh
	var perp := (pv - dn * pv.dot(dn))
	perp = perp.normalized() if perp.length() > 0.001 else Vector3.DOWN
	var el_new := sh + dn * a + perp * h
	var wr_new := sh + dn * dist
	var q1 := Quaternion((el - sh).normalized(), (el_new - sh).normalized())
	var new_gu := Basis(q1) * gu.basis
	var lower_rot := Basis(q1) * gl.basis
	var l0 := (Basis(q1) * (wr - el)).normalized()
	var q2 := Quaternion(l0, (wr_new - el_new).normalized())
	var new_gl := Basis(q2) * lower_rot
	var pu := sk.get_bone_parent(iu)
	var parent_g := sk.get_bone_global_pose(pu).basis if pu >= 0 else Basis()
	var loc_u := (parent_g.inverse() * new_gu).get_rotation_quaternion()
	var loc_l := (new_gu.inverse() * new_gl).get_rotation_quaternion()
	sk.set_bone_pose_rotation(iu, sk.get_bone_pose_rotation(iu).slerp(loc_u, weight))
	sk.set_bone_pose_rotation(il, sk.get_bone_pose_rotation(il).slerp(loc_l, weight))
