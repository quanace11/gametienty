extends RefCounted
## Hình túi cứu thương chibi: hộp trắng bo cạnh, quai xám, chữ thập đỏ hai mặt.
## Một ArrayMesh dựng bằng code, dùng chung cho túi đang bay và túi nằm dưới đất.

const SIZE := Vector3(0.5, 0.36, 0.34)

static var _mesh: ArrayMesh


static func get_mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	_mesh = ArrayMesh.new()
	_add(_mesh, _mat(Color(0.97, 0.97, 0.95)), [
		[Vector3(SIZE.x, SIZE.y, SIZE.z), Vector3.ZERO],
	])
	_add(_mesh, _mat(Color(0.35, 0.36, 0.4)), [ # quai xách
		[Vector3(0.05, 0.1, 0.06), Vector3(-0.12, SIZE.y / 2 + 0.05, 0)],
		[Vector3(0.05, 0.1, 0.06), Vector3(0.12, SIZE.y / 2 + 0.05, 0)],
		[Vector3(0.29, 0.05, 0.06), Vector3(0, SIZE.y / 2 + 0.1, 0)],
	])
	var red := []
	for side: float in [1.0, -1.0]: # chữ thập ở mặt trước và sau
		var z := side * (SIZE.z / 2 + 0.006)
		red.append([Vector3(0.24, 0.08, 0.012), Vector3(0, 0, z)])
		red.append([Vector3(0.08, 0.24, 0.012), Vector3(0, 0, z)])
	red.append([Vector3(0.2, 0.012, 0.07), Vector3(0, SIZE.y / 2 + 0.006, 0)]) # nắp
	red.append([Vector3(0.07, 0.012, 0.2), Vector3(0, SIZE.y / 2 + 0.006, 0)])
	_add(_mesh, _mat(Color(0.92, 0.15, 0.18)), red)
	return _mesh


## Gộp các hộp (kích thước, tâm) thành một surface của `mesh`.
static func _add(mesh: ArrayMesh, mat: Material, boxes: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b: Array in boxes:
		var box := BoxMesh.new()
		box.size = b[0]
		st.append_from(box, 0, Transform3D(Basis(), b[1]))
	st.set_material(mat)
	st.commit(mesh)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m
