extends RefCounted
## Hình trận bàn hồi phục (thẻ túi cứu thương): đĩa đồng tám cạnh, mặt ngọc,
## vòng vàng và viên linh thạch ở giữa; cùng 5 lá cờ ngũ hành cắm quanh vùng hồi
## máu (xanh, đỏ, vàng, trắng, đen). Mesh dựng bằng code một lần, dùng chung cho
## trận bàn đang bay, trận bàn nằm chờ và vùng hồi máu.

const DISC_RADIUS := 0.35
const FLAG_HEIGHT := 1.0
const FLAG_COLORS: Array[Color] = [
	Color(0.2, 0.7, 0.35), # mộc
	Color(0.9, 0.2, 0.15), # hỏa
	Color(0.95, 0.78, 0.2), # thổ
	Color(0.95, 0.95, 0.9), # kim
	Color(0.15, 0.2, 0.35), # thủy
]

static var _mesh: ArrayMesh
static var _flags: Array[ArrayMesh] = []


## Trận bàn nằm ngang, mặt ngọc hướng lên.
static func get_mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	_mesh = ArrayMesh.new()
	var bronze := CylinderMesh.new()
	bronze.top_radius = DISC_RADIUS
	bronze.bottom_radius = DISC_RADIUS
	bronze.height = 0.07
	bronze.radial_segments = 8
	bronze.rings = 1
	_add(_mesh, _mat(Color(0.62, 0.42, 0.2), false), [[bronze, Transform3D.IDENTITY]])
	var jade := CylinderMesh.new()
	jade.top_radius = DISC_RADIUS * 0.78
	jade.bottom_radius = jade.top_radius
	jade.height = 0.02
	jade.radial_segments = 8
	jade.rings = 1
	_add(_mesh, _mat(Color(0.35, 0.85, 0.65), true), [[jade, Transform3D(Basis(), Vector3(0, 0.04, 0))]])
	var ring := TorusMesh.new()
	ring.inner_radius = DISC_RADIUS * 0.42
	ring.outer_radius = DISC_RADIUS * 0.5
	ring.rings = 16
	ring.ring_segments = 4
	var gem := SphereMesh.new()
	gem.radius = 0.06
	gem.height = 0.09
	gem.radial_segments = 8
	gem.rings = 4
	_add(_mesh, _mat(Color(1.0, 0.85, 0.35), true), [
		[ring, Transform3D(Basis().scaled(Vector3(1, 0.3, 1)), Vector3(0, 0.055, 0))],
		[gem, Transform3D(Basis(), Vector3(0, 0.07, 0))],
	])
	return _mesh


## Lá cờ thứ `k` (0..4): cán gỗ, đầu vàng, lá cờ tam giác màu ngũ hành. Gốc ở chân cán.
static func get_flag_mesh(k: int) -> ArrayMesh:
	if _flags.is_empty():
		var wood := _mat(Color(0.4, 0.26, 0.15), false)
		var gold := _mat(Color(1.0, 0.85, 0.35), true)
		var pole := CylinderMesh.new()
		pole.top_radius = 0.025
		pole.bottom_radius = 0.03
		pole.height = FLAG_HEIGHT
		pole.radial_segments = 6
		pole.rings = 1
		var tip := SphereMesh.new()
		tip.radius = 0.05
		tip.height = 0.1
		tip.radial_segments = 6
		tip.rings = 3
		var cloth := PrismMesh.new() # tam giác đứng, mũi chĩa ra ngoài cán
		cloth.size = Vector3(0.42, 0.34, 0.02)
		cloth.left_to_right = 0.0
		for color in FLAG_COLORS:
			var m := ArrayMesh.new()
			_add(m, wood, [[pole, Transform3D(Basis(), Vector3(0, FLAG_HEIGHT / 2, 0))]])
			_add(m, gold, [[tip, Transform3D(Basis(), Vector3(0, FLAG_HEIGHT + 0.03, 0))]])
			var cloth_mat := _mat(color, false)
			cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			var lay := Basis(Vector3.BACK, -PI / 2) # cạnh đứng sát cán, mũi chĩa ra ngoài ở mép trên
			_add(m, cloth_mat, [[cloth, Transform3D(lay, Vector3(0.17, FLAG_HEIGHT - 0.25, 0))]])
			_flags.append(m)
	return _flags[k % _flags.size()]


## Gộp các mesh (mesh, transform) thành một surface của `mesh`.
static func _add(mesh: ArrayMesh, mat: Material, parts: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Array in parts:
		st.append_from(p[0], 0, p[1])
	st.set_material(mat)
	st.commit(mesh)


static func _mat(c: Color, glow: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	if glow:
		m.emission_enabled = true
		m.emission = c * 0.5
	return m
