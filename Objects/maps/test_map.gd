extends MapBase
## Bản đồ thử 32 x 20 m, phong cách chibi dựng bằng code: sân cỏ, quảng trường
## lát gạch ở giữa, tường thấp màu kem mái ngói, hàng rào cây ở viền, nhà tù ở
## chính giữa, bụi cây để nấp, cây trang trí ngoài viền. Sau này có thể thay
## bằng scene dựng trong editor, giữ nguyên các hàm của MapBase.

const SIZE := Vector2(32, 20) # x, z
const WALL_HEIGHT := 1.5 # tường thấp kiểu chibi, camera nhìn qua được (vẫn cao hơn đường đạn 1.1 m)
const CAP := 0.15 # mái ngói trên đầu tường
## Tường trên mặt sàn: Rect2(x, z, rộng theo x, sâu theo z), đơn vị mét.
const WALLS := [
	# Viền
	Rect2(0, 0, 32, 0.4), Rect2(0, 19.6, 32, 0.4),
	Rect2(0, 0, 0.4, 20), Rect2(31.6, 0, 0.4, 20),
	# Chướng ngại
	Rect2(6, 3, 0.8, 6), Rect2(6, 12, 0.8, 5),
	Rect2(12, 6, 8, 0.8), Rect2(12, 13.2, 8, 0.8),
	Rect2(24, 2, 0.8, 7), Rect2(24, 11, 0.8, 7),
]
## 5 rương, cần mở 3 (MatchConfig.safes_required).
const SAFES := [
	Vector3(9, 0, 2.6), Vector3(22, 0, 2.6), Vector3(16, 0, 2.6), Vector3(9, 0, 17.4), Vector3(22, 0, 17.4),
]
## 2 cổng ở hai đầu đối diện.
const EXIT_GATES := [Vector3(0.8, 0, 10), Vector3(31.2, 0, 10)]
## Một nhà tù ở chính giữa, tường cao 3 m, chỉ đệm lò xo bay qua được.
const PRISONS := [Vector3(16, 0, 10)]
## Bụi cây để nấp: Vector3(x, z, bán kính).
const BUSHES: Array[Vector3] = [
	Vector3(3.5, 10, 1.4), Vector3(28.5, 10, 1.4), Vector3(9.5, 10, 1.3), Vector3(22.5, 10, 1.3),
	Vector3(12.5, 2.4, 1.2), Vector3(19.5, 17.6, 1.2), Vector3(27.5, 15.5, 1.2), Vector3(4.5, 4.5, 1.2),
]
const HUNTER_SPAWN := Vector3(16, 0.05, 16.2)
const ESCAPEE_SPAWNS: Array[Vector3] = [
	Vector3(3, 0.05, 3), Vector3(3, 0.05, 17), Vector3(29, 0.05, 3), Vector3(29, 0.05, 17),
]
## Tiền rải sẵn trên sàn.
const COIN_SPOTS: Array[Vector3] = [
	Vector3(3, 0, 7), Vector3(3, 0, 13), Vector3(29, 0, 7), Vector3(29, 0, 13),
	Vector3(9, 0, 6), Vector3(9, 0, 10), Vector3(9, 0, 14), Vector3(22, 0, 6), Vector3(22, 0, 10), Vector3(22, 0, 14),
	Vector3(13, 0, 4), Vector3(19, 0, 4), Vector3(13, 0, 16), Vector3(19, 0, 16),
	Vector3(16, 0, 5.5), Vector3(16, 0, 14.5), Vector3(27, 0, 1.5), Vector3(5, 0, 18.5),
	Vector3(27, 0, 18.5), Vector3(5, 0, 1.5),
]

const SafeScript = preload("res://Objects/safe.gd")
const ExitGateScript = preload("res://Objects/exit_gate.gd")
const PrisonScript = preload("res://Objects/prison.gd")
const CoinScript = preload("res://Objects/coin.gd")
const BushScript = preload("res://Objects/bush.gd")

const GRASS := Color(0.34, 0.54, 0.26)
const PLAZA := Color(0.8, 0.68, 0.5)
const WALL := Color(0.9, 0.8, 0.62)
const ROOF := Color(0.86, 0.46, 0.32)
const HEDGE := Color(0.24, 0.55, 0.3)
const TRUNK := Color(0.55, 0.36, 0.2)
const LEAVES := Color(0.33, 0.72, 0.35)

var _materials := {} # màu -> material dùng chung

func _ready() -> void:
	# Sân cỏ rộng hơn bản đồ một chút, quảng trường lát gạch quanh nhà tù.
	_add_box(Vector3(SIZE.x / 2, -0.1, SIZE.y / 2), Vector3(SIZE.x + 8, 0.2, SIZE.y + 8), GRASS)
	_add_mesh(Vector3(16, 0.005, 10), Vector3(9, 0.01, 8.4), PLAZA)
	for i in WALLS.size():
		var r: Rect2 = WALLS[i]
		var center := r.get_center()
		var border := i < 4 # 4 cạnh viền là hàng rào cây
		_add_box(Vector3(center.x, WALL_HEIGHT / 2, center.y), Vector3(r.size.x, WALL_HEIGHT, r.size.y), HEDGE if border else WALL)
		if not border:
			_add_mesh(Vector3(center.x, WALL_HEIGHT + CAP / 2, center.y), Vector3(r.size.x + 0.2, CAP, r.size.y + 0.2), ROOF)
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


## Cây trang trí ngoài viền (không va chạm, không ảnh hưởng luật).
func _add_trees() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.25
	trunk.height = 1.2
	trunk.radial_segments = 6
	trunk.material = _material(TRUNK)
	var crown := SphereMesh.new()
	crown.radius = 1.0
	crown.height = 1.8
	crown.radial_segments = 8
	crown.rings = 4
	crown.material = _material(LEAVES)
	for x in range(-2, 36, 5):
		for z: float in [-2.2]: # chỉ phía bắc: phía nam gần camera, cây sẽ che màn hình
			_add_tree(Vector3(x, 0, z), trunk, crown)
	for z in range(3, 20, 6):
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
	env.background_color = Color(0.55, 0.78, 0.95) # trời xanh
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
