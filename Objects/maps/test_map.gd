extends MapBase
## Bản đồ thử 48 x 30 m, phong cách tiên hiệp chibi dựng bằng code: sân cỏ ngọc,
## quảng trường đá xanh ở giữa, tường vôi trắng mái ngói đen có đèn lồng đỏ ở hai
## đầu, hàng rào trúc ở viền, huyết trận ở chính giữa, bụi cây để nấp, cây tùng
## ngoài viền. Sau này có thể thay
## bằng scene dựng trong editor, giữ nguyên các hàm của MapBase.

const SIZE := Vector2(48, 30) # x, z
const WALL_HEIGHT := 1.5 # tường thấp kiểu chibi, camera nhìn qua được (vẫn cao hơn đường đạn 1.1 m)
const CAP := 0.15 # mái ngói trên đầu tường
## Tường trên mặt sàn: Rect2(x, z, rộng theo x, sâu theo z), đơn vị mét.
const WALLS := [
	# Viền
	Rect2(0, 0, 48, 0.4), Rect2(0, 29.6, 48, 0.4),
	Rect2(0, 0, 0.4, 30), Rect2(47.6, 0, 0.4, 30),
	# Chướng ngại
	Rect2(9, 4.5, 0.8, 9), Rect2(9, 18, 0.8, 7.5),
	Rect2(18, 9, 12, 0.8), Rect2(18, 19.8, 12, 0.8),
	Rect2(36, 3, 0.8, 10.5), Rect2(36, 16.5, 0.8, 10.5),
]
## 5 trận linh, cần giải 3 (MatchConfig.safes_required).
const SAFES := [
	Vector3(13.5, 0, 3.9), Vector3(33, 0, 3.9), Vector3(24, 0, 3.9), Vector3(13.5, 0, 26.1), Vector3(33, 0, 26.1),
]
## 2 lối ra ở hai đầu đối diện.
const EXIT_GATES := [Vector3(0.8, 0, 15), Vector3(47.2, 0, 15)]
## Một huyết trận ở chính giữa, kết giới cao 3 m, chỉ đệm lò xo bay qua được.
const PRISONS := [Vector3(24, 0, 15)]
## Bụi cây để nấp: Vector3(x, z, bán kính).
const BUSHES: Array[Vector3] = [
	Vector3(5.25, 15, 1.75), Vector3(42.75, 15, 1.75), Vector3(14.25, 15, 1.62), Vector3(33.75, 15, 1.62),
	Vector3(18.75, 3.6, 1.5), Vector3(29.25, 26.4, 1.5), Vector3(41.25, 23.25, 1.5), Vector3(6.75, 6.75, 1.5),
	Vector3(40, 8.5, 1.5), Vector3(8, 21.5, 1.5), Vector3(20.5, 27, 1.4), Vector3(28.5, 2.6, 1.4),
]
const HUNTER_SPAWN := Vector3(24, 0.05, 24.3)
const ESCAPEE_SPAWNS: Array[Vector3] = [
	Vector3(4.5, 0.05, 4.5), Vector3(4.5, 0.05, 25.5), Vector3(43.5, 0.05, 4.5), Vector3(43.5, 0.05, 25.5),
]
## Linh thạch rải sẵn trên sàn.
const COIN_SPOTS: Array[Vector3] = [
	Vector3(4.5, 0, 10.5), Vector3(4.5, 0, 19.5), Vector3(43.5, 0, 10.5), Vector3(43.5, 0, 19.5),
	Vector3(13.5, 0, 9), Vector3(13.5, 0, 15), Vector3(13.5, 0, 21), Vector3(33, 0, 9), Vector3(33, 0, 15), Vector3(33, 0, 21),
	Vector3(19.5, 0, 6), Vector3(28.5, 0, 6), Vector3(19.5, 0, 24), Vector3(28.5, 0, 24),
	Vector3(24, 0, 8.25), Vector3(24, 0, 21.75), Vector3(40.5, 0, 2.25), Vector3(7.5, 0, 27.75),
	Vector3(40.5, 0, 27.75), Vector3(7.5, 0, 2.25),
]

const SafeScript = preload("res://Objects/safe.gd")
const ExitGateScript = preload("res://Objects/exit_gate.gd")
const PrisonScript = preload("res://Objects/prison.gd")
const CoinScript = preload("res://Objects/coin.gd")
const BushScript = preload("res://Objects/bush.gd")

const GRASS := Color(0.36, 0.55, 0.36)
const PLAZA := Color(0.58, 0.62, 0.62) # đá xanh
const WALL := Color(0.93, 0.91, 0.86) # vôi trắng
const ROOF := Color(0.2, 0.22, 0.27) # ngói đen
const HEDGE := Color(0.42, 0.62, 0.3) # trúc
const TRUNK := Color(0.42, 0.28, 0.2)
const LEAVES := Color(0.18, 0.42, 0.3) # tùng
const LANTERN := Color(0.95, 0.2, 0.15)

var _materials := {} # màu -> material dùng chung
var _lantern_mesh: SphereMesh

func _ready() -> void:
	# Sân cỏ rộng hơn bản đồ một chút, quảng trường đá xanh quanh huyết trận.
	_add_box(Vector3(SIZE.x / 2, -0.1, SIZE.y / 2), Vector3(SIZE.x + 8, 0.2, SIZE.y + 8), GRASS)
	_add_mesh(Vector3(SIZE.x / 2, 0.005, SIZE.y / 2), Vector3(14, 0.01, 12.6), PLAZA)
	for i in WALLS.size():
		var r: Rect2 = WALLS[i]
		var center := r.get_center()
		var border := i < 4 # 4 cạnh viền là hàng rào cây
		_add_box(Vector3(center.x, WALL_HEIGHT / 2, center.y), Vector3(r.size.x, WALL_HEIGHT, r.size.y), HEDGE if border else WALL)
		if not border: # mái ngói chìa ra, nóc mái, đèn lồng ở hai đầu tường
			_add_mesh(Vector3(center.x, WALL_HEIGHT + CAP / 2, center.y), Vector3(r.size.x + 0.4, CAP, r.size.y + 0.4), ROOF)
			_add_mesh(Vector3(center.x, WALL_HEIGHT + CAP + 0.06, center.y), Vector3(maxf(r.size.x - 0.2, 0.2), 0.12, maxf(r.size.y - 0.2, 0.2)), ROOF)
			var along := Vector2(r.size.x, 0) if r.size.x > r.size.y else Vector2(0, r.size.y)
			for end: float in [-0.5, 0.5]:
				var p := center + along * end
				_add_lantern(Vector3(p.x, WALL_HEIGHT + CAP, p.y))
	for i in BUSHES.size():
		var bush: Node3D = BushScript.new()
		bush.index = i
		bush.radius = BUSHES[i].z
		bush.position = Vector3(BUSHES[i].x, 0, BUSHES[i].y)
		add_child(bush)
	_add_trees()
	for i in SAFES.size():
		var safe: Interactable = SafeScript.new()
		safe.interactable_id = i
		safe.position = SAFES[i]
		add_child(safe)
	for i in EXIT_GATES.size():
		var gate: Interactable = ExitGateScript.new()
		gate.interactable_id = i
		gate.position = EXIT_GATES[i]
		add_child(gate)
	for i in COIN_SPOTS.size():
		var coin: Interactable = CoinScript.new()
		coin.interactable_id = i
		coin.position = COIN_SPOTS[i]
		add_child(coin)
	for i in PRISONS.size():
		var prison: Prison = PrisonScript.new()
		prison.interactable_id = i
		prison.position = PRISONS[i]
		prison.exit_side = Vector3(0, 0, 1) # đệm trong tù bắn người ra phía nam
		add_child(prison)
	_add_lighting()


## Đèn lồng đỏ trên đầu tường (chỉ để nhìn, tự sáng, không đổ bóng).
func _add_lantern(pos: Vector3) -> void:
	if _lantern_mesh == null:
		var glow := _material(LANTERN).duplicate() as StandardMaterial3D
		glow.emission_enabled = true
		glow.emission = LANTERN * 0.6
		_lantern_mesh = SphereMesh.new()
		_lantern_mesh.radius = 0.2
		_lantern_mesh.height = 0.34
		_lantern_mesh.radial_segments = 8
		_lantern_mesh.rings = 4
		_lantern_mesh.material = glow
	var mi := MeshInstance3D.new()
	mi.mesh = _lantern_mesh
	mi.position = pos + Vector3(0, 0.3, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Cây tùng ngoài viền: thân + hai tầng tán hình nón (không va chạm, không ảnh hưởng luật).
func _add_trees() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.25
	trunk.height = 1.2
	trunk.radial_segments = 6
	trunk.material = _material(TRUNK)
	var low := CylinderMesh.new()
	low.top_radius = 0.0
	low.bottom_radius = 1.2
	low.height = 1.4
	low.radial_segments = 8
	low.rings = 1
	var high := CylinderMesh.new()
	high.top_radius = 0.0
	high.bottom_radius = 0.85
	high.height = 1.2
	high.radial_segments = 8
	high.rings = 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(low, 0, Transform3D(Basis(), Vector3(0, -0.3, 0)))
	st.append_from(high, 0, Transform3D(Basis(), Vector3(0, 0.45, 0)))
	st.set_material(_material(LEAVES))
	var crown := st.commit()
	for x in range(-2, int(SIZE.x) + 4, 5):
		for z: float in [-2.2]: # chỉ phía bắc: phía nam gần camera, cây sẽ che màn hình
			_add_tree(Vector3(x, 0, z), trunk, crown)
	for z in range(3, int(SIZE.y), 6):
		for x: float in [-2.2, SIZE.x + 2.2]:
			_add_tree(Vector3(x, 0, z), trunk, crown)


func _add_tree(pos: Vector3, trunk: Mesh, crown: Mesh) -> void:
	var t := MeshInstance3D.new()
	t.mesh = trunk
	t.position = pos + Vector3(0, 0.6, 0)
	add_child(t)
	var c := MeshInstance3D.new()
	c.mesh = crown
	c.position = pos + Vector3(0, 1.9, 0)
	add_child(c)


## Khối chỉ để nhìn (không va chạm).
func _add_mesh(center: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = center
	add_child(mi)


func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		_materials[color] = m
	return _materials[color]


func _add_box(center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)


func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.6
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.72, 0.84, 0.9) # trời mây nhạt
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.9)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC # màu đỡ cháy dưới nắng
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func get_hunter_spawn() -> Vector3:
	return HUNTER_SPAWN


func get_escapee_spawns() -> Array[Vector3]:
	return ESCAPEE_SPAWNS


func get_safe_count() -> int:
	return SAFES.size()


func get_coin_spots() -> Array[Vector3]:
	return COIN_SPOTS


func get_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, SIZE)


func get_bushes() -> Array[Vector3]:
	return BUSHES


func get_walls() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.assign(WALLS)
	return out
