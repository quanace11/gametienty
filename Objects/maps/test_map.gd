extends MapBase
## Bản đồ "Động phủ Linh Đài" 50 x 45 m: hình là mô hình Meshy quan gửi (một lưới liền: tường đá,
## rừng viền, phòng truyền tống bên trái, động phủ có 2 cửa phong ấn ở góc đông bắc, lối đá, phế
## tích, đá tảng, bụi tròn), đã thu nhỏ ảnh và dịu màu bằng Objects/tools/ban_do_meshy/build_ban_do.py.
## Va chạm (tường, đá, bụi tròn, cây, động phủ) đo từ độ cao của chính lưới đó (meshy_va_cham.gd),
## nên chỗ nào trông cao hơn đầu gối là chỗ không đi qua được.
## Bản đồ tự đặt thêm: 6 trận linh, huyết trận ở giữa, 2 lối ra ở 2 cửa phong ấn, linh thạch,
## và các đám bụi cỏ cao để nấp (kiểu Liên Quân) ở khoảng trống giữa các bụi tròn.

const MeshyLayout = preload("res://Objects/maps/meshy_va_cham.gd")
const MODEL := "res://Objects/models/ban_do_meshy/ban_do.glb"
const SIZE := Vector2(50, 45) # x, z
const BORDER := 0.5 # tường viền ngoài khung (dày, m)
const BORDER_HEIGHT := 3.0
const BLOCK_HEIGHT := 2.4 # vật cản đo từ lưới cao hơn đầu gối: chặn người và phi kiếm
## 6 trận linh quanh sân, chừa giữa cho huyết trận; cần giải MatchConfig.safes_required.
const SAFES := [
	Vector3(6.6, 0, 3.4), Vector3(21.9, 0, 6.1), Vector3(37.6, 0, 3.4), Vector3(44.4, 0, 25.6),
	Vector3(45.1, 0, 41.1), Vector3(22.6, 0, 42.1),
]
## 2 lối ra là 2 cửa phong ấn cam của động phủ: tường tây (quay theo trục x) và tường nam (xoay 90°).
const EXIT_GATES := [Vector3(40.25, 0, 8.7), Vector3(46.2, 0, 14.9)]
const EXIT_GATE_YAW := [0.0, PI / 2]
## Huyết trận ở giữa sân (khoảng trống lớn nhất), kết giới cao 3 m, chỉ đệm lò xo bay qua được.
const PRISONS := [Vector3(26.0, 0, 23.5)]
## Bụi cỏ cao (hơn đầu người) để nấp, ở khoảng trống giữa các bụi tròn: Vector3(x, z, bán kính).
const BUSHES: Array[Vector3] = [
	Vector3(12.9, 16.4, 1.8), Vector3(10.1, 39.1, 1.8), Vector3(2.4, 14.1, 1.6), Vector3(34.9, 14.1, 1.8),
	Vector3(14.6, 27.9, 1.8), Vector3(28.9, 34.6, 1.8), Vector3(20.6, 33.4, 1.8), Vector3(2.4, 37.6, 1.6),
	Vector3(30.4, 7.9, 1.8), Vector3(13.4, 8.9, 1.8), Vector3(35.9, 25.4, 1.8), Vector3(20.6, 15.1, 1.8),
	Vector3(15.1, 2.6, 1.6), Vector3(5.6, 19.6, 1.6), Vector3(26.9, 14.9, 1.8), Vector3(9.4, 33.1, 1.6),
]
## Đệ tử xuất hiện quanh truyền tống trận trong phòng bên trái (cửa ra ở tường bắc của phòng).
const ESCAPEE_SPAWNS: Array[Vector3] = [
	Vector3(3.2, 0.05, 28.9), Vector3(4.8, 0.05, 28.9), Vector3(3.2, 0.05, 30.6), Vector3(4.8, 0.05, 30.6),
]
const HUNTER_SPAWN := Vector3(38.6, 0.05, 32.9) # ma tu xuất hiện phía đông nam, xa phòng truyền tống
## Linh thạch rải sẵn trên sàn.
const COIN_SPOTS: Array[Vector3] = [
	Vector3(34.6, 0, 43.4), Vector3(47.1, 0, 16.1), Vector3(47.1, 0, 33.4), Vector3(39.6, 0, 19.9),
	Vector3(29.6, 0, 1.4), Vector3(29.9, 0, 41.1), Vector3(1.4, 0, 7.9), Vector3(16.4, 0, 38.1),
	Vector3(5.9, 0, 43.6), Vector3(7.4, 0, 10.9), Vector3(38.6, 0, 39.1), Vector3(12.4, 0, 22.4),
	Vector3(34.1, 0, 38.9), Vector3(38.6, 0, 9.6), Vector3(14.1, 0, 43.4), Vector3(32.9, 0, 30.4),
	Vector3(15.1, 0, 34.1), Vector3(18.1, 0, 22.6), Vector3(47.4, 0, 20.1), Vector3(39.4, 0, 43.1),
]

const SafeScript = preload("res://Objects/safe.gd")
const ExitGateScript = preload("res://Objects/exit_gate.gd")
const PrisonScript = preload("res://Objects/prison.gd")
const CoinScript = preload("res://Objects/coin.gd")
const BushScript = preload("res://Objects/bush.gd")
const BLOOD_STONE := Color(0.36, 0.12, 0.11)
const BLOOD_GLOW := Color(1.0, 0.18, 0.15)

var _materials := {} # màu -> material dùng chung
var _glows := {} # màu -> material tự sáng (trận pháp), không đổ bóng
var _shapes := {} # tên -> mesh khuôn dùng chung (khối, dải)
var _batches := {} # Vector3i(ô x, ô z, id material) -> SurfaceTool gom hình tĩnh, dựng thành một mesh lúc xong
var _batch_mats := {} # id material -> material
var _no_shadow := {} # material -> true: mesh gộp của nó không đổ bóng (hình sát sàn, trận pháp)
var _headless := DisplayServer.get_name() == "headless" # server riêng: chỉ dựng va chạm, không dựng hình


func _ready() -> void:
	_add_collider(Rect2(-8, -8, SIZE.x + 16, SIZE.y + 16), 0.2, -0.2) # sàn
	_add_collider(Rect2(-BORDER, -BORDER, SIZE.x + BORDER * 2, BORDER), BORDER_HEIGHT)
	_add_collider(Rect2(-BORDER, SIZE.y, SIZE.x + BORDER * 2, BORDER), BORDER_HEIGHT)
	_add_collider(Rect2(-BORDER, 0, BORDER, SIZE.y), BORDER_HEIGHT)
	_add_collider(Rect2(SIZE.x, 0, BORDER, SIZE.y), BORDER_HEIGHT)
	for r: Rect2 in MeshyLayout.BLOCKS:
		_add_collider(r, BLOCK_HEIGHT)
	for i in BUSHES.size():
		var bush: Node3D = BushScript.new()
		bush.index = i
		bush.radius = BUSHES[i].z
		bush.position = Vector3(BUSHES[i].x, 0, BUSHES[i].y)
		add_child(bush)
	for i in SAFES.size():
		var safe: Interactable = SafeScript.new()
		safe.interactable_id = i
		safe.position = SAFES[i]
		add_child(safe)
	for i in EXIT_GATES.size():
		var gate: Interactable = ExitGateScript.new()
		gate.interactable_id = i
		gate.position = EXIT_GATES[i]
		gate.rotation.y = EXIT_GATE_YAW[i]
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
	if not _headless:
		_add_scenery()
		_add_lighting()
		_commit_batches()


## Mọi thứ chỉ để nhìn: mô hình bản đồ, nền đỏ dưới huyết trận.
func _add_scenery() -> void:
	var map: Node3D = (load(MODEL) as PackedScene).instantiate()
	for mi: MeshInstance3D in map.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # màu đã có bóng vẽ sẵn, đỡ một lượt vẽ bóng
	add_child(map)
	for p: Vector3 in PRISONS: # nền đá đỏ thẫm, viền đỏ sáng quanh huyết trận
		_add_mesh(p + Vector3(0, 0.03, 0), Vector3(6.4, 0.02, 6.4), BLOOD_STONE)
		var corners: Array[Vector2] = [Vector2(-3.2, -3.2), Vector2(3.2, -3.2), Vector2(3.2, 3.2), Vector2(-3.2, 3.2)]
		for k in 4:
			var a := Vector2(p.x, p.z) + corners[k]
			var b := Vector2(p.x, p.z) + corners[(k + 1) % 4]
			_add_strip(a, b, 0.12, 0.045, _glow(BLOOD_GLOW))
			var tip := Vector2(p.x, p.z) + (corners[k] + corners[(k + 1) % 4]) * 0.72 # mũi nhọn 4 phía như ảnh
			_add_strip(a.lerp(b, 0.3), tip, 0.1, 0.045, _glow(BLOOD_GLOW))
			_add_strip(a.lerp(b, 0.7), tip, 0.1, 0.045, _glow(BLOOD_GLOW))


## Dải phẳng nối 2 điểm trên mặt sàn (lối đất, nét ngũ tinh).
func _add_strip(a: Vector2, b: Vector2, width: float, y: float, mat: Material) -> void:
	var d := b - a
	var box := _shape(&"strip") as BoxMesh
	if box == null:
		box = BoxMesh.new()
		box.size = Vector3(1, 0.01, 1)
		_shapes[&"strip"] = box
	var mid := (a + b) / 2
	var basis := Basis(Vector3.UP, -d.angle()) * Basis.from_scale(Vector3(d.length(), 1, width))
	_batch(box, Transform3D(basis, Vector3(mid.x, y, mid.y)), mat)


func _shape(key: StringName) -> Mesh:
	return _shapes.get(key)


## Khối chỉ để nhìn (không va chạm). Khối mỏng sát sàn thì không đổ bóng.
func _add_mesh(center: Vector3, size: Vector3, color: Color) -> void:
	var box := _shape(&"box") as BoxMesh
	if box == null:
		box = BoxMesh.new()
		_shapes[&"box"] = box
	_batch(box, Transform3D(Basis.from_scale(size), center), _flat(color) if size.y <= 0.02 else _material(color))


## Gom mặt đầu của `mesh` (đặt ở `xf`) vào mesh gộp theo material `mat` và ô 15 x 12 m chứa nó.
func _batch(mesh: Mesh, xf: Transform3D, mat: Material) -> void:
	var key := Vector3i(floori(xf.origin.x / 15.0), floori(xf.origin.z / 12.0), mat.get_instance_id())
	var st: SurfaceTool = _batches.get(key)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(mat)
		_batches[key] = st
		_batch_mats[key.z] = mat
	st.append_from(mesh, 0, xf)


## Dựng mỗi material trong mỗi ô một MeshInstance3D từ các hình đã gom.
func _commit_batches() -> void:
	for key: Vector3i in _batches:
		var mi := MeshInstance3D.new()
		var st := _batches[key] as SurfaceTool
		mi.mesh = st.commit()
		if _no_shadow.has(_batch_mats[key.z]):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_batches.clear()


func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		_materials[color] = m
	return _materials[color]


## Material tự sáng cho trận pháp (không cần đèn, không đổ bóng).
func _glow(color: Color) -> StandardMaterial3D:
	if not _glows.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glows[color] = m
		_no_shadow[m] = true
	return _glows[color]


## Material cho hình nằm sát sàn (vệt cỏ, lối đất, sàn lát): không đổ bóng.
func _flat(color: Color) -> StandardMaterial3D:
	var m := _material(color)
	_no_shadow[m] = true
	return m


## Chỉ va chạm, không hình (hình do phần trang trí vẽ: đá, cây, nhà, cửa phong ấn).
func _add_collider(r: Rect2, height: float, bottom := 0.0) -> void:
	var body := StaticBody3D.new()
	var c := r.get_center()
	body.position = Vector3(c.x, bottom + height / 2, c.y)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(r.size.x, height, r.size.y)
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = int(ProjectSettings.get_setting("game/graphics_quality", 0)) > 0 # đồ họa Thấp: không bóng
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL # camera nhìn từ trên: 1 lượt vẽ bóng thay vì 4
	sun.directional_shadow_max_distance = 32.0 # đủ phủ khung nhìn trong trận
	sun.light_energy = 0.75
	sun.light_color = Color(1.0, 0.96, 0.9) # nắng nhẹ, không gắt
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.4, 0.52, 0.58) # trời xám xanh, không chói
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.72, 0.8) # bóng râm ngả xanh lạnh như bản đồ MOBA
	env.ambient_light_energy = 0.45
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
	return BUSHES.duplicate() # bản sao: hằng là mảng chỉ đọc, GameState xóa / gán lại mỗi trận


func get_walls() -> Array[Rect2]:
	return MeshyLayout.BLOCKS
