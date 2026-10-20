extends MapBase
## Bản đồ "Động phủ Linh Đài" 52 x 30 m dựng bằng code, theo ảnh thiết kế
## (ban-do/ban_do_v4.png và ảnh dựng 3D): phòng truyền tống mái đỏ bên trái
## (đệ tử xuất hiện ở trận tròn xanh), huyết trận ở giữa, 4 trận linh ngũ tinh
## vàng ở 4 góc, phế tích có hốc tường phía trên (ma tu xuất hiện), động phủ
## tường đá bên phải với 2 cửa phong ấn cam (2 lối ra), linh đài và 4 cột đá bên
## trong, cửa hang mật đạo, đá tảng, cây cổ thụ, lối đất và bụi cỏ cao để nấp.
## Sau này có thể thay bằng scene dựng trong editor, giữ nguyên các hàm của MapBase.
## Phần chỉ để nhìn gộp thành một mesh cho mỗi material: cả bản đồ tĩnh chỉ vài
## chục lần vẽ (draw call) thay vì vài trăm.

const SIZE := Vector2(52, 30) # x, z
const WALL_HEIGHT := 1.5 # tường thấp, camera nhìn qua được (vẫn cao hơn đường đạn 1.1 m)
const RUIN_HEIGHT := 1.2 # tường phế tích đổ nát
## Tường trên mặt sàn: Rect2(x, z, rộng theo x, sâu theo z), đơn vị mét.
const WALLS := [
	# Viền đá
	Rect2(0, 0, 52, 0.5), Rect2(0, 29.5, 52, 0.5),
	Rect2(0, 0, 0.5, 30), Rect2(51.5, 0, 0.5, 30),
	# Phòng truyền tống (trái): 3 cửa mở sẵn trên, dưới, phải
	Rect2(0.5, 11.5, 2.5, 0.5), Rect2(5.6, 11.5, 2.9, 0.5),
	Rect2(0.5, 22, 2.5, 0.5), Rect2(5.6, 22, 2.9, 0.5),
	Rect2(8, 12, 0.5, 3.8), Rect2(8, 18.6, 0.5, 3.4),
	# Động phủ (phải trên): khe ở giữa tường trái và tường dưới là 2 cửa phong ấn
	Rect2(40.6, 0.5, 0.5, 5.2), Rect2(40.6, 8.1, 0.5, 5.0),
	Rect2(40.6, 12.6, 4.9, 0.5), Rect2(47.9, 12.6, 3.6, 0.5),
]
## Tường phế tích (thấp hơn, đầu tường lởm chởm): hốc tường trên có 2 khe vào, đoạn tường đổ dưới phải.
const RUINS := [
	Rect2(16.3, 0.5, 0.6, 2.3), Rect2(16.3, 5.2, 0.6, 2.1),
	Rect2(25.2, 0.5, 0.6, 2.3), Rect2(25.2, 5.2, 0.6, 2.1),
	Rect2(16.3, 6.7, 9.5, 0.6),
	Rect2(30.2, 25.4, 2.4, 0.5), Rect2(32.9, 23.4, 2.2, 0.5),
]
## Nhà mái đỏ trong phòng truyền tống (chắn đường), thấp để không che camera lúc vào trận.
const PAVILION := Rect2(0.5, 12, 2.6, 5.2)
## Cửa hang mật đạo sát tường phải (chỉ để nhìn, chắn đường).
const CAVE := Rect2(49.6, 14.6, 1.9, 2.8)
## 4 trận linh ngũ tinh ở 4 phía, cần giải MatchConfig.safes_required.
const SAFES := [
	Vector3(7.9, 0, 4.8), Vector3(35.6, 0, 3.6), Vector3(20.8, 0, 27.0), Vector3(45.7, 0, 26.6),
]
## 2 lối ra là 2 cửa phong ấn của động phủ: tường trái (quay theo trục x) và tường dưới (xoay 90°).
const EXIT_GATES := [Vector3(40.85, 0, 6.9), Vector3(46.7, 0, 12.85)]
const EXIT_GATE_YAW := [0.0, PI / 2]
## Thanh chắn trong khe cửa: cửa phong ấn đóng thì không vào động phủ được,
## vùng thoát của lối ra vẫn chìa ra ngoài tường.
const GATE_BLOCKERS := [Rect2(40.75, 5.7, 0.2, 2.4), Rect2(45.5, 12.75, 2.4, 0.2)]
## Huyết trận ở giữa, kết giới cao 3 m, chỉ đệm lò xo bay qua được.
const PRISONS := [Vector3(27.1, 0, 13.6)]
## Bụi cỏ cao để nấp: Vector3(x, z, bán kính).
const BUSHES: Array[Vector3] = [
	Vector3(13.6, 4.6, 1.5), Vector3(29.8, 3.4, 1.1), Vector3(36.4, 8.4, 1.3), Vector3(10.2, 8.2, 1.1),
	Vector3(11.6, 15.0, 1.2), Vector3(20.6, 18.4, 1.0), Vector3(14.8, 21.4, 1.6), Vector3(26.4, 25.0, 1.4),
	Vector3(22.6, 9.6, 1.1), Vector3(23.0, 17.4, 1.2), Vector3(31.4, 17.6, 1.2), Vector3(38.0, 17.0, 1.0),
	Vector3(40.4, 17.0, 1.0), Vector3(37.4, 23.4, 1.4), Vector3(46.4, 21.0, 1.4), Vector3(33.8, 28.0, 0.9),
	Vector3(6.6, 13.4, 0.9), Vector3(1.8, 20.4, 0.9),
]
## Bụi cỏ trang trí trong động phủ (không vào được nên không tính luật nấp): Vector3(x, z, bán kính).
const DECOR_BUSHES: Array[Vector3] = [
	Vector3(42.0, 1.8, 0.8), Vector3(44.6, 1.6, 0.7), Vector3(48.2, 1.7, 0.8), Vector3(50.4, 3.6, 0.7),
	Vector3(41.9, 4.4, 0.7), Vector3(42.0, 10.2, 0.8), Vector3(50.3, 9.6, 0.8), Vector3(43.0, 11.8, 0.7),
	Vector3(49.6, 11.8, 0.7),
]
## Đá tảng chắn đường: Vector3(x, z, bán kính).
const ROCKS: Array[Vector3] = [
	Vector3(28.2, 2.2, 0.55), Vector3(13.9, 10.4, 0.5), Vector3(17.6, 13.8, 0.6), Vector3(18.9, 15.2, 0.4),
	Vector3(10.6, 20.6, 0.55), Vector3(32.4, 19.6, 0.5), Vector3(35.0, 16.2, 0.45), Vector3(42.2, 27.2, 0.5),
	Vector3(26.0, 20.8, 1.0), Vector3(27.4, 21.8, 0.55),
]
## Cây cổ thụ: thân chắn đường, tán che: Vector3(x, z, cỡ).
const TREES: Array[Vector3] = [
	Vector3(12.0, 1.8, 1.0), Vector3(44.6, 16.8, 1.0), Vector3(5.0, 25.4, 0.9), Vector3(10.2, 27.6, 0.8),
	Vector3(38.6, 10.6, 0.8),
]
## Lối đất: mỗi lối là một chuỗi điểm (x, z).
const PATHS := [
	[Vector2(4.3, 11.0), Vector2(8.4, 8.4), Vector2(17.4, 8.6), Vector2(23.8, 10.0)],
	[Vector2(4.3, 23.0), Vector2(8.4, 25.4), Vector2(20.5, 22.6), Vector2(25.6, 17.6), Vector2(30.4, 16.4),
		Vector2(35.1, 13.6), Vector2(46.7, 14.2)],
	[Vector2(35.1, 13.6), Vector2(37.8, 8.6), Vector2(40.2, 6.9)],
	[Vector2(8.6, 17.2), Vector2(11.0, 17.6)],
]
const PATH_WIDTH := 1.5
const TELEPORT := Vector3(5.4, 0, 18.2) # truyền tống trận trong phòng trái
const ALTAR := Vector3(46.0, 0, 6.7) # linh đài trong động phủ
const HUNTER_SPAWN := Vector3(21.0, 0.05, 3.8) # trong hốc tường phế tích
const ESCAPEE_SPAWNS: Array[Vector3] = [
	Vector3(4.6, 0.05, 17.4), Vector3(6.2, 0.05, 17.4), Vector3(4.6, 0.05, 19.0), Vector3(6.2, 0.05, 19.0),
]
## Linh thạch rải sẵn trên sàn.
const COIN_SPOTS: Array[Vector3] = [
	Vector3(5.0, 0, 8.6), Vector3(4.6, 0, 26.6), Vector3(12.4, 0, 12.6), Vector3(8.8, 0, 23.6),
	Vector3(20.6, 0, 4.4), Vector3(19.8, 0, 11.4), Vector3(17.4, 0, 25.6), Vector3(23.6, 0, 27.6),
	Vector3(31.0, 0, 8.6), Vector3(33.4, 0, 11.6), Vector3(38.6, 0, 2.6), Vector3(35.4, 0, 19.6),
	Vector3(29.6, 0, 21.4), Vector3(38.8, 0, 13.6), Vector3(43.8, 0, 19.6), Vector3(49.0, 0, 19.6),
	Vector3(49.2, 0, 27.2), Vector3(39.6, 0, 27.4), Vector3(28.2, 0, 27.8), Vector3(23.4, 0, 6.4),
]

const SafeScript = preload("res://Objects/safe.gd")
const ExitGateScript = preload("res://Objects/exit_gate.gd")
const PrisonScript = preload("res://Objects/prison.gd")
const CoinScript = preload("res://Objects/coin.gd")
const BushScript = preload("res://Objects/bush.gd")

const GRASS := Color(0.33, 0.5, 0.24)
const GRASS_SPOTS: Array[Color] = [Color(0.29, 0.45, 0.22), Color(0.37, 0.54, 0.26)]
const OUTSIDE := Color(0.2, 0.3, 0.24) # sườn núi ngoài tường
const DIRT := Color(0.56, 0.43, 0.3)
const STONE := Color(0.44, 0.45, 0.43) # tường đá
const MOSS := Color(0.32, 0.42, 0.26) # rêu đầu tường
const RUIN := Color(0.42, 0.41, 0.38)
const ROCK := Color(0.4, 0.41, 0.42)
const PAVING := Color(0.45, 0.47, 0.5) # sàn đá lát
const PAVING_LINE := Color(0.36, 0.37, 0.4)
const PLASTER := Color(0.86, 0.8, 0.68)
const WOOD := Color(0.5, 0.22, 0.14)
const ROOF_RED := Color(0.74, 0.2, 0.12)
const MARBLE := Color(0.88, 0.88, 0.86)
const TRUNK := Color(0.42, 0.28, 0.2)
const LEAVES := Color(0.27, 0.48, 0.25)
const CAVE_DARK := Color(0.07, 0.06, 0.06)
const GOLD_GLOW := Color(1.0, 0.78, 0.25)
const BLOOD_STONE := Color(0.36, 0.12, 0.11)
const BLOOD_GLOW := Color(1.0, 0.18, 0.15)
const BLUE_GLOW := Color(0.4, 0.75, 1.0)
const BLUE_SOFT := Color(0.3, 0.55, 0.85)

var _materials := {} # màu -> material dùng chung
var _glows := {} # màu -> material tự sáng (trận pháp), không đổ bóng
var _shapes := {} # tên -> mesh khuôn dùng chung (đá, vòng, tán cây)
var _batches := {} # material -> SurfaceTool gom hình tĩnh, dựng thành một mesh lúc xong
var _no_shadow := {} # material -> true: mesh gộp của nó không đổ bóng (hình sát sàn, trận pháp)
var _rng := RandomNumberGenerator.new() # hình trang trí lệch ngẫu nhiên nhưng cố định mỗi lần dựng
var _headless := DisplayServer.get_name() == "headless" # server riêng: chỉ dựng va chạm, không dựng hình


func _ready() -> void:
	_rng.seed = 20261020
	_add_collider(Rect2(-8, -8, SIZE.x + 16, SIZE.y + 16), 0.2, -0.2) # sàn
	for r: Rect2 in WALLS:
		_add_wall(r, WALL_HEIGHT, STONE)
	for r: Rect2 in RUINS:
		_add_wall(r, RUIN_HEIGHT, RUIN)
	for r: Rect2 in GATE_BLOCKERS:
		_add_collider(r, WALL_HEIGHT)
	_add_collider(PAVILION, 2.0)
	_add_collider(CAVE, 1.5)
	for rock in ROCKS:
		_add_collider(Rect2(rock.x - rock.z * 0.7, rock.y - rock.z * 0.7, rock.z * 1.4, rock.z * 1.4), 1.0)
	for tree in TREES:
		_add_collider(Rect2(tree.x - 0.3, tree.y - 0.3, 0.6, 0.6), 2.0)
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


## Mọi thứ chỉ để nhìn: sàn, lối đất, trận pháp, nhà, cây, đá, động phủ.
func _add_scenery() -> void:
	_add_mesh(Vector3(SIZE.x / 2, -0.1, SIZE.y / 2), Vector3(SIZE.x, 0.2, SIZE.y), GRASS)
	_add_mesh(Vector3(SIZE.x / 2, -0.15, SIZE.y / 2), Vector3(SIZE.x + 60, 0.2, SIZE.y + 50), OUTSIDE)
	for i in 46: # vệt cỏ đậm nhạt cho sân đỡ phẳng
		var p := Vector3(_rng.randf_range(1, SIZE.x - 1), 0.004, _rng.randf_range(1, SIZE.y - 1))
		_add_disc(p, _rng.randf_range(0.8, 2.2), GRASS_SPOTS[i % 2], false)
	for path: Array in PATHS:
		for k in path.size() - 1:
			_add_strip(path[k], path[k + 1], PATH_WIDTH, 0.012, _flat(DIRT))
		for p: Vector2 in path:
			_add_disc(Vector3(p.x, 0.013, p.y), PATH_WIDTH / 2, DIRT, false)
	_add_spawn_room()
	_add_cave_mansion()
	for s: Vector3 in SAFES:
		_add_pentagram(s, 1.45)
	for p: Vector3 in PRISONS: # nền đá đỏ thẫm, viền đỏ sáng quanh huyết trận
		_add_mesh(p + Vector3(0, 0.015, 0), Vector3(6.4, 0.02, 6.4), BLOOD_STONE)
		var corners: Array[Vector2] = [Vector2(-3.2, -3.2), Vector2(3.2, -3.2), Vector2(3.2, 3.2), Vector2(-3.2, 3.2)]
		for k in 4:
			var a := Vector2(p.x, p.z) + corners[k]
			var b := Vector2(p.x, p.z) + corners[(k + 1) % 4]
			_add_strip(a, b, 0.12, 0.03, _glow(BLOOD_GLOW))
			var tip := Vector2(p.x, p.z) + (corners[k] + corners[(k + 1) % 4]) * 0.72 # mũi nhọn 4 phía như ảnh
			_add_strip(a.lerp(b, 0.3), tip, 0.1, 0.03, _glow(BLOOD_GLOW))
			_add_strip(a.lerp(b, 0.7), tip, 0.1, 0.03, _glow(BLOOD_GLOW))
	for rock in ROCKS:
		_add_rock(Vector3(rock.x, 0, rock.y), rock.z)
	for tree in TREES:
		_add_tree(Vector3(tree.x, 0, tree.y), tree.z)
	_add_rubble()
	_add_cave()
	_add_border_cliffs()


## Phòng truyền tống: sàn đá, nhà mái ngói đỏ, trận tròn xanh có 6 viên sáng.
func _add_spawn_room() -> void:
	_add_mesh(Vector3(4.25, 0.01, 17.0), Vector3(7.5, 0.02, 10.0), PAVING)
	_add_rock(Vector3(1.4, 0, 21.2), 0.35)
	_add_rock(Vector3(7.2, 0, 21.3), 0.3)
	var c := PAVILION.get_center()
	var pc := Vector3(c.x, 0, c.y)
	_add_mesh(pc + Vector3(0, 0.15, 0), Vector3(PAVILION.size.x, 0.3, PAVILION.size.y), STONE) # nền
	_add_mesh(pc + Vector3(0, 0.85, 0), Vector3(PAVILION.size.x - 0.5, 1.1, PAVILION.size.y - 0.6), PLASTER)
	for dz: float in [-2.2, -0.7, 0.7, 2.2]: # cột gỗ đỏ
		_add_mesh(pc + Vector3(PAVILION.size.x / 2 - 0.2, 0.85, dz), Vector3(0.22, 1.1, 0.22), WOOD)
	var roof := _shape(&"roof") as CylinderMesh # mái chóp 4 mặt
	if roof == null:
		roof = CylinderMesh.new()
		roof.top_radius = 0.18
		roof.bottom_radius = 1.0
		roof.height = 1.0
		roof.radial_segments = 4
		roof.rings = 1
		_shapes[&"roof"] = roof
	_batch(roof, Transform3D(Basis.from_scale(Vector3(PAVILION.size.x * 0.78, 0.8, PAVILION.size.y * 0.78)) * Basis(Vector3.UP, PI / 4), pc + Vector3(0, 1.8, 0)), _material(ROOF_RED))
	_add_mesh(pc + Vector3(0, 2.2, 0), Vector3(0.25, 0.12, PAVILION.size.y * 0.3), WOOD) # nóc
	# Truyền tống trận
	_add_disc(TELEPORT + Vector3(0, 0.02, 0), 1.25, BLUE_SOFT, true)
	_add_ring(TELEPORT + Vector3(0, 0.03, 0), 1.3, BLUE_GLOW)
	_add_ring(TELEPORT + Vector3(0, 0.035, 0), 0.75, BLUE_GLOW)
	for k in 6:
		var a := TAU * k / 6
		_add_disc(TELEPORT + Vector3(cos(a) * 1.3, 0.04, sin(a) * 1.3), 0.17, Color.WHITE, true)


## Động phủ: sàn đá lát kẻ ô, linh đài cẩm thạch với trận xanh, 4 cột đá, bụi cỏ quanh tường.
func _add_cave_mansion() -> void:
	var x0 := 41.1
	var z0 := 0.5
	var x1 := 51.5
	var z1 := 12.6
	_add_mesh(Vector3((x0 + x1) / 2, 0.01, (z0 + z1) / 2), Vector3(x1 - x0, 0.02, z1 - z0), PAVING)
	var x := x0 + 1.2
	while x < x1:
		_add_mesh(Vector3(x, 0.022, (z0 + z1) / 2), Vector3(0.05, 0.01, z1 - z0), PAVING_LINE)
		x += 1.2
	var z := z0 + 1.2
	while z < z1:
		_add_mesh(Vector3((x0 + x1) / 2, 0.022, z), Vector3(x1 - x0, 0.01, 0.05), PAVING_LINE)
		z += 1.2
	var dais := _cylinder(&"dais", 1.0, 1.1, 1.0, 16)
	_batch(dais, Transform3D(Basis.from_scale(Vector3(1.7, 0.3, 1.7)), ALTAR + Vector3(0, 0.15, 0)), _material(MARBLE))
	_batch(dais, Transform3D(Basis.from_scale(Vector3(1.35, 0.2, 1.35)), ALTAR + Vector3(0, 0.38, 0)), _material(MARBLE))
	_add_ring(ALTAR + Vector3(0, 0.49, 0), 1.05, BLUE_GLOW)
	_add_disc(ALTAR + Vector3(0, 0.485, 0), 0.5, BLUE_SOFT, true)
	var pillar := _cylinder(&"pillar", 0.3, 0.36, 1.0, 8)
	for p: Vector2 in [Vector2(42.8, 2.8), Vector2(49.2, 2.8), Vector2(42.8, 10.6), Vector2(49.2, 10.6)]:
		_batch(pillar, Transform3D(Basis.from_scale(Vector3(1, 2.2, 1)), Vector3(p.x, 1.1, p.y)), _material(STONE))
		_add_mesh(Vector3(p.x, 2.25, p.y), Vector3(0.8, 0.14, 0.8), RUIN)
	for b: Vector3 in DECOR_BUSHES:
		_batch(BushScript.leaf_mesh(), Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(b.z, 1.0, b.z)), Vector3(b.x, 0, b.y)), BushScript.leaf_material())


## Trận linh ngũ tinh vàng dưới bệ trận linh.
func _add_pentagram(center: Vector3, radius: float) -> void:
	var c := center + Vector3(0, 0.025, 0)
	_add_disc(c - Vector3(0, 0.008, 0), radius + 0.1, Color(0.42, 0.33, 0.18), false)
	_add_ring(c, radius, GOLD_GLOW)
	_add_ring(c, radius * 0.86, GOLD_GLOW)
	var pts: Array[Vector2] = []
	for k in 5:
		var a := -PI / 2 + TAU * k / 5
		pts.append(Vector2(c.x + cos(a) * radius * 0.84, c.z + sin(a) * radius * 0.84))
	for k in 5:
		_add_strip(pts[k], pts[(k + 2) % 5], 0.08, c.y + 0.004, _glow(GOLD_GLOW))


## Đá vụn và cột gãy quanh tường đổ phía dưới phải.
func _add_rubble() -> void:
	for i in 14:
		var p := Vector3(_rng.randf_range(28.5, 35.5), 0, _rng.randf_range(21.0, 27.5))
		_add_mesh(p + Vector3(0, 0.08, 0), Vector3(_rng.randf_range(0.2, 0.5), 0.16, _rng.randf_range(0.2, 0.5)), RUIN)
	var pillar := _cylinder(&"pillar", 0.3, 0.36, 1.0, 8)
	_batch(pillar, Transform3D(Basis.from_scale(Vector3(1, 1.3, 1)), Vector3(33.6, 0.65, 25.0)), _material(RUIN))
	_batch(pillar, Transform3D(Basis(Vector3(1, 0, 0.4).normalized(), PI / 2) * Basis.from_scale(Vector3(0.9, 1.4, 0.9)), Vector3(31.4, 0.28, 22.6)), _material(RUIN))


## Cửa hang mật đạo: ụ đá có lỗ tối, rễ cây phủ trên.
func _add_cave() -> void:
	var c := CAVE.get_center()
	_add_rock(Vector3(c.x + 0.3, 0, c.y), 1.6)
	_add_rock(Vector3(c.x + 0.6, 0, c.y - 1.4), 0.8)
	_add_rock(Vector3(c.x + 0.5, 0, c.y + 1.4), 0.7)
	var hole := _shape(&"hole") as SphereMesh
	if hole == null:
		hole = SphereMesh.new()
		hole.radius = 0.5
		hole.height = 1.0
		hole.radial_segments = 10
		hole.rings = 5
		_shapes[&"hole"] = hole
	_batch(hole, Transform3D(Basis.from_scale(Vector3(0.5, 1.6, 1.6)), Vector3(c.x - 1.0, 0.5, c.y)), _material(CAVE_DARK))
	_add_mesh(Vector3(c.x - 0.6, 1.45, c.y), Vector3(1.0, 0.25, 2.0), LEAVES)


## Vách đá ngoài tường viền (bắc, tây, đông) cho giống thung lũng trên núi.
func _add_border_cliffs() -> void:
	var x := -1.0
	while x < SIZE.x + 2:
		_add_rock(Vector3(x, 0.4, -1.4 + _rng.randf_range(-0.4, 0.4)), _rng.randf_range(1.2, 2.0))
		x += _rng.randf_range(2.2, 3.4)
	var z := 1.0
	while z < SIZE.y + 1:
		_add_rock(Vector3(-1.4 + _rng.randf_range(-0.4, 0.4), 0.3, z), _rng.randf_range(1.0, 1.7))
		_add_rock(Vector3(SIZE.x + 1.4 + _rng.randf_range(-0.4, 0.4), 0.3, z), _rng.randf_range(1.0, 1.7))
		z += _rng.randf_range(2.2, 3.2)
	x = 1.0
	while x < SIZE.x: # phía nam gần camera: chỉ đá thấp, không che màn hình
		_add_rock(Vector3(x, 0.0, SIZE.y + 0.9), _rng.randf_range(0.5, 0.8))
		x += _rng.randf_range(2.5, 4.0)


## Tường đá: thân, rêu trên đầu; tường phế tích thì đầu tường lởm chởm.
func _add_wall(r: Rect2, height: float, color: Color) -> void:
	var center := r.get_center()
	_add_box(Vector3(center.x, height / 2, center.y), Vector3(r.size.x, height, r.size.y), color)
	if _headless:
		return
	if color == RUIN:
		var along := r.size.x > r.size.y
		var length := maxf(r.size.x, r.size.y)
		var t := 0.2
		while t < length - 0.2:
			var w := _rng.randf_range(0.3, 0.7)
			var h := _rng.randf_range(0.05, 0.45)
			var p := Vector3(r.position.x + (t if along else r.size.x / 2), height + h / 2, r.position.y + (r.size.y / 2 if along else t))
			_add_mesh(p, Vector3(w if along else r.size.x * 0.9, h, r.size.y * 0.9 if along else w), color)
			t += w + _rng.randf_range(0.2, 0.8)
	else:
		_add_mesh(Vector3(center.x, height + 0.06, center.y), Vector3(r.size.x + 0.12, 0.12, r.size.y + 0.12), MOSS)


## Đá tảng tròn méo (dùng chung một khuôn cầu, lệch tỉ lệ và góc xoay).
func _add_rock(pos: Vector3, radius: float) -> void:
	var rock := _shape(&"rock") as SphereMesh
	if rock == null:
		rock = SphereMesh.new()
		rock.radius = 1.0
		rock.height = 2.0
		rock.radial_segments = 7
		rock.rings = 4
		_shapes[&"rock"] = rock
	var s := Vector3(radius * _rng.randf_range(0.9, 1.15), radius * _rng.randf_range(0.6, 0.8), radius * _rng.randf_range(0.85, 1.05))
	var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(s)
	_batch(rock, Transform3D(b, pos + Vector3(0, s.y * 0.55, 0)), _material(ROCK))


## Cây cổ thụ: thân + 3 cụm tán tròn.
func _add_tree(pos: Vector3, size: float) -> void:
	var trunk := _cylinder(&"trunk", 0.2, 0.3, 1.0, 6)
	_batch(trunk, Transform3D(Basis.from_scale(Vector3(size, 2.2 * size, size)), pos + Vector3(0, 1.1 * size, 0)), _material(TRUNK))
	var crown := _shape(&"crown") as SphereMesh
	if crown == null:
		crown = SphereMesh.new()
		crown.radius = 1.0
		crown.height = 2.0
		crown.radial_segments = 8
		crown.rings = 4
		_shapes[&"crown"] = crown
	for k in 3:
		var a := TAU * k / 3 + _rng.randf()
		var p := pos + Vector3(cos(a) * 0.6, 2.6, sin(a) * 0.6) * size
		_batch(crown, Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 1.0) * size * _rng.randf_range(0.9, 1.15)), p), _material(LEAVES))
	_batch(crown, Transform3D(Basis.from_scale(Vector3(0.9, 0.75, 0.9) * size), pos + Vector3(0, 3.3, 0) * size), _material(LEAVES))


## Vành tròn phẳng sát đất (trận pháp), tự sáng.
func _add_ring(center: Vector3, radius: float, color: Color) -> void:
	var ring := _shape(&"ring") as TorusMesh
	if ring == null:
		ring = TorusMesh.new()
		ring.inner_radius = 0.9
		ring.outer_radius = 1.0
		ring.rings = 32
		ring.ring_segments = 4
		_shapes[&"ring"] = ring
	# Khuôn có bán kính giữa 0,95; co theo bán kính (vành to thì dày hơn), rồi nén dẹt.
	var s := radius / 0.95
	_batch(ring, Transform3D(Basis.from_scale(Vector3(s, 0.2, s)), center), _glow(color))


## Đĩa tròn phẳng (vệt cỏ, lối đất, lòng trận).
func _add_disc(center: Vector3, radius: float, color: Color, glow: bool) -> void:
	var disc := _cylinder(&"disc", 1.0, 1.0, 0.01, 16)
	_batch(disc, Transform3D(Basis.from_scale(Vector3(radius, 1, radius)), center), _glow(color) if glow else _flat(color))


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


func _cylinder(key: StringName, top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var m := _shape(key) as CylinderMesh
	if m == null:
		m = CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = segments
		m.rings = 1
		_shapes[key] = m
	return m


func _shape(key: StringName) -> Mesh:
	return _shapes.get(key)


## Khối chỉ để nhìn (không va chạm). Khối mỏng sát sàn thì không đổ bóng.
func _add_mesh(center: Vector3, size: Vector3, color: Color) -> void:
	var box := _shape(&"box") as BoxMesh
	if box == null:
		box = BoxMesh.new()
		_shapes[&"box"] = box
	_batch(box, Transform3D(Basis.from_scale(size), center), _flat(color) if size.y <= 0.02 else _material(color))


## Gom mặt đầu của `mesh` (đặt ở `xf`) vào mesh gộp theo material `mat`.
func _batch(mesh: Mesh, xf: Transform3D, mat: Material) -> void:
	var st: SurfaceTool = _batches.get(mat)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(mat)
		_batches[mat] = st
	st.append_from(mesh, 0, xf)


## Dựng mỗi material một MeshInstance3D từ các hình đã gom.
func _commit_batches() -> void:
	for mat: Material in _batches:
		var mi := MeshInstance3D.new()
		var st := _batches[mat] as SurfaceTool
		mi.mesh = st.commit()
		if _no_shadow.has(mat):
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


## Khối có va chạm (và hình nếu máy có màn hình).
func _add_box(center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	if not _headless:
		_add_mesh(center, size, color)


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
	sun.light_energy = 0.6
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.7, 0.72) # mây mù trên núi
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.84, 0.9)
	env.ambient_light_energy = 0.3
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
	var out: Array[Rect2] = []
	out.assign(WALLS + RUINS + [PAVILION, CAVE])
	return out
