class_name TerrainGround
extends StaticBody3D
## Continuous heightfield ground built from a height function h(x, z).
## Renders as one ArrayMesh with the triplanar terrain shader (grass on flat
## ground, layered rock on slopes and cliffs) and collides through a
## HeightMapShape3D sampled on the same 1 m grid.

var x0 := -48
var z0 := -170
var w := 97
var d := 191
var heights := PackedFloat32Array()
var _h: Callable


func build(height_fn: Callable, min_x: int, max_x: int, min_z: int, max_z: int, style := "meadow") -> void:
	_h = height_fn
	x0 = min_x
	z0 = min_z
	w = max_x - min_x + 1
	d = max_z - min_z + 1
	collision_layer = 1
	heights.resize(w * d)
	for j in d:
		for i in w:
			heights[j * w + i] = height_fn.call(float(x0 + i), float(z0 + j))
	# --- collision (HeightMapShape3D is centered on its node)
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = d
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(x0 + (w - 1) * 0.5, 0.0, z0 + (d - 1) * 0.5)
	add_child(cs)
	# --- mesh
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(w * d)
	norms.resize(w * d)
	uvs.resize(w * d)
	for j in d:
		for i in w:
			var k := j * w + i
			verts[k] = Vector3(x0 + i, heights[k], z0 + j)
			norms[k] = normal_at_index(i, j)
			uvs[k] = Vector2(i, j) * 0.25
	var idx := PackedInt32Array()
	idx.resize((w - 1) * (d - 1) * 6)
	var t := 0
	for j in d - 1:
		for i in w - 1:
			var a := j * w + i
			var b := a + 1
			var c := a + w
			var e := c + 1
			idx[t] = a
			idx[t + 1] = b
			idx[t + 2] = c
			idx[t + 3] = b
			idx[t + 4] = e
			idx[t + 5] = c
			t += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Mats.terrain(style)
	add_child(mi)


func _hi(i: int, j: int) -> float:
	return heights[clampi(j, 0, d - 1) * w + clampi(i, 0, w - 1)]


func normal_at_index(i: int, j: int) -> Vector3:
	var dx := _hi(i + 1, j) - _hi(i - 1, j)
	var dz := _hi(i, j + 1) - _hi(i, j - 1)
	return Vector3(-dx, 2.0, -dz).normalized()


## Exact ground height (bilinear on the grid, same as the collider).
func height(x: float, z: float) -> float:
	var fx := x - x0
	var fz := z - z0
	var i := floori(fx)
	var j := floori(fz)
	var tx := fx - i
	var tz := fz - j
	var a := lerpf(_hi(i, j), _hi(i + 1, j), tx)
	var b := lerpf(_hi(i, j + 1), _hi(i + 1, j + 1), tx)
	return lerpf(a, b, tz)


func normal(x: float, z: float) -> Vector3:
	return normal_at_index(roundi(x - x0), roundi(z - z0))
