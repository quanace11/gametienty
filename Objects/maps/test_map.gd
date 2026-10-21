extends MapBase
## Bản đồ "Động phủ Linh Đài" 60 x 36 m dựng bằng code, theo ảnh thiết kế
## (ban-do/ban_do_v4.png và ảnh dựng 3D): phòng truyền tống mái đỏ bên trái
## (đệ tử xuất hiện ở trận tròn xanh), huyết trận ở giữa, 6 trận linh ngũ tinh
## vàng, phế tích có hốc tường phía trên, ma tu chui ra từ cửa hang bên phải, động phủ
## tường đá bên phải với 2 cửa phong ấn cam (2 lối ra), linh đài và 4 cột đá bên
## trong, cửa hang mật đạo, đá tảng, cây cổ thụ, lối đất và bụi cỏ cao để nấp.
## Sau này có thể thay bằng scene dựng trong editor, giữ nguyên các hàm của MapBase.
## Cây, đá, cỏ, hoa, sỏi kiểu tranh vẽ dùng Quaternius Stylized Nature MegaKit (CC0);
## tường, cột, nhà mái đỏ dùng KayKit (CC0, Kay Lousberg: Dungeon Remastered và
## Medieval Hexagon). Nền cỏ và lối đất loang màu bằng nhiễu (shaders/nen.gdshader).
## Tỉ lệ so với nhân vật theo kiểu Liên Quân: tường cao hơn người, cây gấp 3 lần
## người, bụi cỏ thành đám rộng 3 - 5 m.
## Phần chỉ để nhìn gộp thành một mesh cho mỗi material trong mỗi ô 15 x 12 m: ít
## lần vẽ (draw call) mà ô nằm ngoài màn hình vẫn bị bỏ qua không vẽ.

const SIZE := Vector2(60, 36) # x, z
const WALL_HEIGHT := 2.4 # cao hơn đầu người (1,7 m) như tường Liên Quân, camera chéo 49° vẫn thấy sau tường
const RUIN_HEIGHT := 1.8 # tường phế tích đổ nát
## Tường trên mặt sàn: Rect2(x, z, rộng theo x, sâu theo z), đơn vị mét.
const WALLS := [
	# Viền ngoài (4 rect đầu): hình là vách đá, không phải tường gạch
	Rect2(0, 0, 60, 0.5), Rect2(0, 35.5, 60, 0.5),
	Rect2(0, 0, 0.5, 36), Rect2(59.5, 0, 0.5, 36),
	# Phòng truyền tống (trái): 3 cửa mở sẵn trên, dưới, phải
	Rect2(0.5, 14.5, 2.5, 0.5), Rect2(5.6, 14.5, 2.9, 0.5),
	Rect2(0.5, 25, 2.5, 0.5), Rect2(5.6, 25, 2.9, 0.5),
	Rect2(8, 15, 0.5, 3.8), Rect2(8, 21.6, 0.5, 3.4),
	# Động phủ (phải trên): khe ở giữa tường trái và tường dưới là 2 cửa phong ấn
	Rect2(48.6, 0.5, 0.5, 5.2), Rect2(48.6, 8.1, 0.5, 5.0),
	Rect2(48.6, 12.6, 4.9, 0.5), Rect2(55.9, 12.6, 3.6, 0.5),
]
## Tường phế tích (thấp hơn, đầu tường lởm chởm): hốc tường trên có 2 khe vào, đoạn tường đổ dưới phải.
const RUINS := [
	Rect2(18.8, 0.5, 0.6, 2.3), Rect2(18.8, 5.2, 0.6, 2.1),
	Rect2(27.7, 0.5, 0.6, 2.3), Rect2(27.7, 5.2, 0.6, 2.1),
	Rect2(18.8, 6.7, 9.5, 0.6),
	Rect2(34.8, 30.5, 2.4, 0.5), Rect2(38.0, 28.1, 2.2, 0.5),
]
## Nhà mái đỏ trong phòng truyền tống (chắn đường), ở phía bắc chỗ xuất hiện nên không che camera.
const PAVILION := Rect2(0.5, 15.4, 2.8, 3.0)
## Cửa hang mật đạo sát tường phải (chỉ để nhìn, chắn đường).
const CAVE := Rect2(57.6, 17.6, 1.9, 2.8)
## 6 trận linh ngũ tinh: 4 ở 4 phía, 2 ở giữa (trái và phải dưới); cần giải MatchConfig.safes_required.
const SAFES := [
	Vector3(9.1, 0, 5.8), Vector3(41.1, 0, 4.3), Vector3(24.0, 0, 32.4), Vector3(52.7, 0, 31.9), Vector3(17.5, 0, 20.5),
	Vector3(36.5, 0, 26.5),
]
## 2 lối ra là 2 cửa phong ấn của động phủ: tường trái (quay theo trục x) và tường dưới (xoay 90°).
const EXIT_GATES := [Vector3(48.85, 0, 6.9), Vector3(54.7, 0, 12.85)]
const EXIT_GATE_YAW := [0.0, PI / 2]
## Thanh chắn trong khe cửa: cửa phong ấn đóng thì không vào động phủ được,
## vùng thoát của lối ra vẫn chìa ra ngoài tường.
const GATE_BLOCKERS := [Rect2(48.75, 5.7, 0.2, 2.4), Rect2(53.5, 12.75, 2.4, 0.2)]
## Huyết trận ở giữa, kết giới cao 3 m, chỉ đệm lò xo bay qua được.
const PRISONS := [Vector3(31.3, 0, 16.3)]
## Bụi cỏ cao (hơn đầu người) để nấp, thành đám rộng như Liên Quân: Vector3(x, z, bán kính).
const BUSHES: Array[Vector3] = [
	Vector3(15.7, 5.5, 2.4), Vector3(34.4, 4.1, 1.8), Vector3(42.0, 10.1, 2.2), Vector3(11.8, 9.8, 1.8),
	Vector3(13.4, 18.0, 1.9), Vector3(23.3, 22.7, 1.6), Vector3(17.1, 25.7, 2.5), Vector3(30.5, 30.0, 2.3),
	Vector3(26.1, 11.5, 1.8), Vector3(26.5, 20.9, 1.9), Vector3(36.2, 21.1, 1.9), Vector3(43.4, 20.4, 1.6),
	Vector3(47.2, 20.6, 1.6), Vector3(43.2, 28.1, 2.3), Vector3(53.5, 25.2, 2.3), Vector3(39.0, 33.6, 1.5),
	Vector3(6.6, 16.6, 1.1), Vector3(1.9, 23.4, 1.1), Vector3(6.0, 33.4, 1.8), Vector3(49.5, 15.8, 1.8),
	Vector3(20.5, 13.5, 1.8), Vector3(30.0, 8.6, 1.9), Vector3(46.4, 33.4, 1.8),
]
## Bụi cỏ trang trí trong động phủ (không vào được nên không tính luật nấp): Vector3(x, z, bán kính).
const DECOR_BUSHES: Array[Vector3] = [
	Vector3(50.0, 1.8, 0.8), Vector3(52.6, 1.6, 0.7), Vector3(56.2, 1.7, 0.8), Vector3(58.4, 3.6, 0.7),
	Vector3(49.9, 4.4, 0.7), Vector3(50.0, 10.2, 0.8), Vector3(58.3, 9.6, 0.8), Vector3(51.0, 11.8, 0.7),
	Vector3(57.6, 11.8, 0.7),
]
## Đá tảng chắn đường (và chắn phi kiếm): Vector3(x, z, bán kính).
const ROCKS: Array[Vector3] = [
	Vector3(32.5, 2.6, 0.55), Vector3(16.0, 12.5, 0.5), Vector3(20.3, 16.6, 0.6), Vector3(21.8, 18.2, 0.4),
	Vector3(12.2, 24.7, 0.55), Vector3(37.4, 23.5, 0.5), Vector3(40.4, 19.4, 0.45), Vector3(48.7, 32.6, 0.5),
	Vector3(30.0, 25.0, 1.0), Vector3(31.6, 26.2, 0.55),
	Vector3(8.0, 12.0, 0.6), Vector3(20.0, 24.0, 0.7), Vector3(28.0, 28.5, 0.6), Vector3(17.0, 30.5, 0.6),
	Vector3(45.5, 24.0, 0.7), Vector3(48.5, 28.5, 0.6), Vector3(39.0, 7.5, 0.6), Vector3(36.0, 12.0, 0.6),
	Vector3(24.5, 15.0, 0.6), Vector3(47.0, 17.5, 0.55), Vector3(56.0, 28.0, 0.6), Vector3(12.5, 7.0, 0.5),
]
## Cây cổ thụ: thân chắn đường, tán che: Vector3(x, z, cỡ).
const TREES: Array[Vector3] = [
	Vector3(13.8, 2.2, 1.0), Vector3(51.5, 20.2, 1.0), Vector3(5.8, 30.5, 0.9), Vector3(11.8, 33.1, 0.8),
	Vector3(44.5, 12.7, 0.8),
]
## Lối đất: mỗi lối là một chuỗi điểm (x, z).
const PATHS := [
	[Vector2(4.3, 14.0), Vector2(9.7, 10.1), Vector2(20.1, 10.3), Vector2(27.5, 12.0)],
	[Vector2(4.3, 26.0), Vector2(9.7, 30.5), Vector2(23.7, 27.1), Vector2(29.5, 21.1), Vector2(35.1, 19.7),
		Vector2(40.5, 16.3), Vector2(54.7, 14.2)],
	[Vector2(40.5, 16.3), Vector2(43.6, 10.3), Vector2(48.2, 6.9)],
	[Vector2(8.6, 20.2), Vector2(12.0, 20.6)],
]
const PATH_WIDTH := 1.5
## Lối chính (chéo từ phòng truyền tống sang động phủ) lát đá phiến như bản Meshy; bước giữa 2 hàng đá (m),
## máy yếu không lát (0).
const STONE_PATH := 1
const SLAB_STEP := [0.0, 1.0, 0.8]
const TELEPORT := Vector3(5.4, 0, 21.2) # truyền tống trận trong phòng trái
const ALTAR := Vector3(54.0, 0, 6.7) # linh đài trong động phủ
const COURTYARD := Rect2(49.1, 0.5, 10.4, 12.1) # sàn động phủ trong tường
const HUNTER_SPAWN := Vector3(55.6, 0.05, 19.0) # ma tu chui ra từ cửa hang mật đạo, xa phòng truyền tống
const ESCAPEE_SPAWNS: Array[Vector3] = [
	Vector3(4.6, 0.05, 20.4), Vector3(6.2, 0.05, 20.4), Vector3(4.6, 0.05, 22.0), Vector3(6.2, 0.05, 22.0),
]
## Linh thạch rải sẵn trên sàn.
const COIN_SPOTS: Array[Vector3] = [
	Vector3(5.8, 0, 10.3), Vector3(5.3, 0, 31.9), Vector3(14.3, 0, 15.1), Vector3(10.2, 0, 28.3),
	Vector3(23.1, 0, 4.4), Vector3(22.8, 0, 13.7), Vector3(20.1, 0, 30.7), Vector3(27.2, 0, 33.1),
	Vector3(35.8, 0, 10.3), Vector3(38.5, 0, 13.9), Vector3(44.5, 0, 3.1), Vector3(40.8, 0, 25.0),
	Vector3(34.2, 0, 25.7), Vector3(44.8, 0, 16.3), Vector3(50.5, 0, 23.5), Vector3(56.5, 0, 23.5),
	Vector3(56.8, 0, 32.6), Vector3(45.7, 0, 32.9), Vector3(32.5, 0, 33.4), Vector3(25.9, 0, 5.6),
]

const SafeScript = preload("res://Objects/safe.gd")
const ExitGateScript = preload("res://Objects/exit_gate.gd")
const PrisonScript = preload("res://Objects/prison.gd")
const CoinScript = preload("res://Objects/coin.gd")
const BushScript = preload("res://Objects/bush.gd")
const DUNGEON := "res://Objects/models/kaykit_dungeon/" # tường, cột, đá vụn (khuôn tường 4 x 4 x 1 m)
const HEX := "res://Objects/models/kaykit_hex/" # nhà mái đỏ (khuôn ô lục giác ~1 m)
const NATURE := "res://Objects/models/quaternius_nature/" # cây, đá, cỏ, hoa, sỏi (đơn vị mét)
const TREE_LEAVES := [["vo", "vo_cay.png", false], ["la", "la_cay.png", true]]
const SMALL_PLANT := [["la_hoa", "la_nho.png", true]]
const FLOWER := [["la_hoa", "la_nho.png", true], ["hoa", "hoa.png", true]]
const STONE_PART := [["da", "da.png", false]]
const PEBBLE := [["soi", "soi.png", false]]
## Mô hình Quaternius: tên -> các phần [đuôi file, ảnh, lá cắt viền theo kênh alpha].
const NATURE_PARTS := {
	"CommonTree_3": TREE_LEAVES, "CommonTree_5": TREE_LEAVES,
	"Pine_5": [["vo", "vo_cay.png", false], ["la", "la_thong.png", true]],
	"Bush_Large": [["la", "la_bui.png", true]],
	"Rock_Medium_1": STONE_PART, "Rock_Medium_2": STONE_PART, "Rock_Medium_3": STONE_PART, "Rock_Medium_4": STONE_PART,
	"Rock_Big_1": STONE_PART, "Rock_Big_2": STONE_PART,
	"Flower_3_Single": FLOWER, "Flower_4_Single": FLOWER, "Flower_7_Single": FLOWER,
	"Plant_2": SMALL_PLANT,
	"Pebble_Round_1": PEBBLE, "Pebble_Round_3": PEBBLE, "Pebble_Square_2": PEBBLE, "Pebble_Square_5": PEBBLE,
}
## Đá vừa: tên -> chiều rộng khuôn (m), để co theo bán kính tảng đá.
const ROCK_WIDTHS := {"Rock_Medium_1": 3.2, "Rock_Medium_2": 3.0, "Rock_Medium_3": 3.4, "Rock_Medium_4": 3.8}
const FLOWERS: Array[String] = ["Flower_3_Single", "Flower_4_Single", "Flower_7_Single"]
## Nhuộm ảnh gốc cho dịu như bản đồ MOBA: đá, tường ngả xám rêu; lá cây bớt vàng chanh, ngả xanh lục sẫm.
const TEXTURE_TINTS := {
	"soi.png": Color(0.55, 0.54, 0.5), "da.png": Color(0.7, 0.72, 0.7), "dungeon_texture.png": Color(0.72, 0.75, 0.72),
	"la_cay.png": Color(0.56, 0.64, 0.6), "la_thong.png": Color(0.54, 0.62, 0.6), "la_bui.png": Color(0.56, 0.64, 0.6),
	"la_nho.png": Color(0.6, 0.66, 0.62), "vo_cay.png": Color(0.8, 0.78, 0.76),
}
const PEBBLES: Array[String] = ["Pebble_Round_1", "Pebble_Round_3", "Pebble_Square_2", "Pebble_Square_5"]
## Số khóm cỏ thấp rải trên sân theo mức đồ họa 0 Thấp, 1 Vừa, 2 Cao (mỗi khóm ~155 tam giác).
const TUFT_CLUSTERS := [14, 45, 75]
const BORDER_WALLS := 4 # số rect viền ngoài ở đầu WALLS
## Khoảng cách giữa các tảng vách đá viền theo mức đồ họa (m).
const CLIFF_SPACING := [3.4, 2.8, 2.5]
## Khoảng cách giữa các cột đá trên vành viền theo mức đồ họa (m).
const RIM_COLUMN_SPACING := [10.0, 7.5, 7.5]
const RIM_STONE := Color(0.5, 0.53, 0.57) # đá trắng xám của lan can, vòng cổng
## Khoảng cách giữa các cây rừng ngoài viền theo mức đồ họa (m): máy yếu ít cây hơn.
const BORDER_SPACING := [9.0, 6.0, 4.8]

const GRASS_DARK := Color(0.14, 0.2, 0.14)
const GRASS_LIGHT := Color(0.22, 0.29, 0.19)
const DIRT_DARK := Color(0.36, 0.31, 0.24)
const DIRT_LIGHT := Color(0.48, 0.42, 0.32)
const PAVING := Color(0.45, 0.47, 0.5) # sàn đá lát
const PAVING_LINE := Color(0.36, 0.37, 0.4)
const MARBLE := Color(0.88, 0.88, 0.86)
const CAVE_DARK := Color(0.07, 0.06, 0.06)
const GOLD_GLOW := Color(1.0, 0.78, 0.25)
const BLOOD_STONE := Color(0.36, 0.12, 0.11)
const BLOOD_GLOW := Color(1.0, 0.18, 0.15)
const BLUE_GLOW := Color(0.4, 0.75, 1.0)
const BLUE_SOFT := Color(0.3, 0.55, 0.85)

var _materials := {} # màu -> material dùng chung
var _glows := {} # màu -> material tự sáng (trận pháp), không đổ bóng
var _shapes := {} # tên -> mesh khuôn dùng chung (vòng, đĩa, khối)
var _models := {} # đường dẫn -> mô hình KayKit đã nạp
var _textured := {} # đường dẫn ảnh (+ cắt viền) -> material dùng chung cho mọi mô hình dùng ảnh đó
var _quality := clampi(int(ProjectSettings.get_setting("game/graphics_quality", 0)), 0, 2)
var _batches := {} # Vector3i(ô x, ô z, id material) -> SurfaceTool gom hình tĩnh, dựng thành một mesh lúc xong
var _batch_mats := {} # id material -> material
var _no_shadow := {} # material -> true: mesh gộp của nó không đổ bóng (hình sát sàn, trận pháp)
var _rng := RandomNumberGenerator.new() # hình trang trí lệch ngẫu nhiên nhưng cố định mỗi lần dựng
var _headless := DisplayServer.get_name() == "headless" # server riêng: chỉ dựng va chạm, không dựng hình


func _ready() -> void:
	_rng.seed = 20261020
	_add_collider(Rect2(-8, -8, SIZE.x + 16, SIZE.y + 16), 0.2, -0.2) # sàn
	for i in WALLS.size():
		if i < BORDER_WALLS:
			_add_collider(WALLS[i], WALL_HEIGHT) # hình: vách đá trong _add_border_cliffs()
		else:
			_add_wall(WALLS[i], WALL_HEIGHT, false)
	for r: Rect2 in RUINS:
		_add_wall(r, RUIN_HEIGHT, true)
	for r: Rect2 in GATE_BLOCKERS:
		_add_collider(r, WALL_HEIGHT)
	_add_collider(PAVILION, 2.5)
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
	_add_ground()
	var dirt := _painted(DIRT_DARK, DIRT_LIGHT, 0.09)
	var disc := _cylinder(&"disc", 1.0, 1.0, 0.01, 16)
	for path: Array in PATHS:
		for k in path.size() - 1:
			_add_strip(path[k], path[k + 1], PATH_WIDTH, 0.012, dirt)
		for p: Vector2 in path:
			_batch(disc, Transform3D(Basis.from_scale(Vector3(PATH_WIDTH / 2, 1, PATH_WIDTH / 2)), Vector3(p.x, 0.013, p.y)), dirt)
	_add_stone_path(PATHS[STONE_PATH])
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
	_add_ground_cover()


## Nền cỏ loang màu (một tấm phẳng phủ cả sân lẫn sườn núi ngoài tường).
func _add_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE.x + 60, SIZE.y + 50)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = _painted(GRASS_DARK, GRASS_LIGHT, 0.035)
	mi.position = Vector3(SIZE.x / 2, 0, SIZE.y / 2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Material nền tranh vẽ: 2 màu loang theo nhiễu, không đổ bóng.
func _painted(dark: Color, light: Color, scale: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://Objects/shaders/nen.gdshader")
	m.set_shader_parameter(&"noise", BushScript.mip_texture(NATURE + "nhieu.png"))
	m.set_shader_parameter(&"dark", dark)
	m.set_shader_parameter(&"light", light)
	m.set_shader_parameter(&"scale", scale)
	_no_shadow[m] = true
	return m


## Cỏ thấp, hoa, cỏ ba lá rải thành cụm trên sân; sỏi dọc lối đất; cây bụi nhỏ chân tường.
## Chỉ để nhìn, không đổ bóng; số lượng theo mức đồ họa.
func _add_ground_cover() -> void:
	var tuft := BushScript.grass_material(0.5, Color(0.1, 0.17, 0.11), Color(0.24, 0.32, 0.2), 1.0)
	_no_shadow[tuft] = true
	var short: Mesh = load(NATURE + "Grass_Common_Short_co.obj")
	var wide: Mesh = load(NATURE + "Grass_Wide_Short_co.obj")
	for c in TUFT_CLUSTERS[_quality]:
		var center := _free_spot()
		if center.x < 0:
			continue
		for k in _rng.randi_range(2, 4):
			var p := center + Vector3(_rng.randf_range(-0.7, 0.7), 0, _rng.randf_range(-0.7, 0.7))
			var mesh := wide if _quality == 2 and k == 0 else short
			var sc := _rng.randf_range(0.3, 0.42)
			_batch(mesh, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3(sc, sc, sc)), p), tuft)
		if c % 7 == 0 and _quality > 0: # hoa lác đác, ít thôi cho khỏi rối mắt
			var f: String = FLOWERS[_rng.randi() % FLOWERS.size()]
			for k in _quality:
				_add_nature(f, center + Vector3(_rng.randf_range(-0.9, 0.9), 0, _rng.randf_range(-0.9, 0.9)), _rng.randf() * TAU, 0.7, false)
	for path: Array in PATHS: # sỏi lác đác hai bên lối đất
		for k in path.size() - 1:
			var a: Vector2 = path[k]
			var b: Vector2 = path[k + 1]
			var side := (b - a).orthogonal().normalized()
			var t := _rng.randf_range(0.5, 2.0)
			while t < a.distance_to(b):
				var q := a.lerp(b, t / a.distance_to(b)) + side * _rng.randf_range(-0.95, 0.95)
				_add_nature(PEBBLES[_rng.randi() % PEBBLES.size()], Vector3(q.x, 0, q.y), _rng.randf() * TAU, _rng.randf_range(0.8, 1.3), false)
				t += _rng.randf_range(6.0, 9.0) # sỏi thưa, chỉ điểm xuyết
	for r: Rect2 in WALLS + RUINS: # cây bụi nhỏ chân tường (máy yếu bỏ)
		if _quality == 0 or r.size.x > 50 or r.size.y > 30:
			continue
		var along_x := r.size.x >= r.size.y
		var n := int(maxf(r.size.x, r.size.y) / (3.0 if _quality == 2 else 6.0))
		for k in n:
			var t := _rng.randf_range(0.3, 0.9) * maxf(r.size.x, r.size.y)
			var side := 1.0 if _rng.randf() < 0.5 else -1.0
			var pos := Vector3(r.position.x + t, 0, r.get_center().y + side * (r.size.y / 2 + 0.25)) if along_x \
				else Vector3(r.get_center().x + side * (r.size.x / 2 + 0.25), 0, r.position.y + t)
			_add_nature("Plant_2", pos, _rng.randf() * TAU, 0.45, false)


## Chỗ trống trên sân cỏ để rải cỏ hoa (tránh sàn lát, lối đi, trận, tường); hết chỗ thì x < 0.
func _free_spot() -> Vector3:
	for attempt in 12:
		var p := Vector2(_rng.randf_range(1.0, SIZE.x - 1.0), _rng.randf_range(1.0, SIZE.y - 1.0))
		if Rect2(0.5, 14.5, 8.0, 11.0).grow(0.3).has_point(p) or COURTYARD.grow(0.6).has_point(p):
			continue
		if p.distance_to(Vector2(PRISONS[0].x, PRISONS[0].z)) < 4.2:
			continue
		var ok := true
		for s: Vector3 in SAFES:
			if p.distance_to(Vector2(s.x, s.z)) < 2.0:
				ok = false
		for r: Rect2 in WALLS + RUINS:
			if r.grow(0.6).has_point(p):
				ok = false
		for path: Array in PATHS:
			for k in path.size() - 1:
				if _segment_distance(p, path[k], path[k + 1]) < PATH_WIDTH / 2 + 0.3:
					ok = false
		if ok:
			return Vector3(p.x, 0, p.y)
	return Vector3(-1, 0, -1)


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## Phòng truyền tống: sàn đá, nhà mái ngói đỏ, trận tròn xanh có 6 viên sáng.
func _add_spawn_room() -> void:
	_add_mesh(Vector3(4.25, 0.01, 20.0), Vector3(7.5, 0.02, 10.0), PAVING)
	_add_rock(Vector3(1.4, 0, 24.2), 0.35)
	_add_rock(Vector3(7.2, 0, 24.3), 0.3)
	var c := PAVILION.get_center()
	# Nhà KayKit 0,8 x 0,93 x 0,85: phóng to cỡ nhà thật (cao ~3,2 m), cửa quay về phía đông.
	_add_model(HEX + "building_home_A_red.obj", Vector3(c.x, 0, c.y), PI / 2, Vector3.ONE * 3.4, HEX + "hexagons_medieval.png")
	# Truyền tống trận
	_add_disc(TELEPORT + Vector3(0, 0.02, 0), 1.25, BLUE_SOFT, true)
	_add_ring(TELEPORT + Vector3(0, 0.03, 0), 1.3, BLUE_GLOW)
	_add_ring(TELEPORT + Vector3(0, 0.035, 0), 0.75, BLUE_GLOW)
	for k in 6:
		var a := TAU * k / 6
		_add_disc(TELEPORT + Vector3(cos(a) * 1.3, 0.04, sin(a) * 1.3), 0.17, Color.WHITE, true)


## Động phủ: sàn đá lát kẻ ô, linh đài cẩm thạch với trận xanh, 4 cột đá, bụi cỏ quanh tường.
func _add_cave_mansion() -> void:
	var x0 := COURTYARD.position.x
	var z0 := COURTYARD.position.y
	var x1 := COURTYARD.end.x
	var z1 := COURTYARD.end.y
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
	for p: Vector2 in [Vector2(x0 + 1.7, 2.8), Vector2(x1 - 2.3, 2.8), Vector2(x0 + 1.7, 10.6), Vector2(x1 - 2.3, 10.6)]:
		_add_model(DUNGEON + "pillar_decorated.obj", Vector3(p.x, 0, p.y), 0.0, Vector3(0.4, 0.95, 0.4), DUNGEON + "dungeon_texture.png")
	for i in DECOR_BUSHES.size(): # bụi lá xanh (máy yếu một nửa)
		if _quality == 0 and i % 2 == 1:
			continue
		var b := DECOR_BUSHES[i]
		_add_nature("Bush_Large", Vector3(b.x, 0, b.y), _rng.randf() * TAU, b.z * 0.45, true)


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


## Phế tích phía dưới phải: nền đá lát vỡ quanh tường đổ, cột gãy nằm cạnh (chỉ để nhìn, phẳng sát đất).
func _add_rubble() -> void:
	_add_model(DUNGEON + "pillar_decorated.obj", Vector3(38.8, 0, 30.0), 0.4, Vector3(0.5, 0.35, 0.5), DUNGEON + "dungeon_texture.png")
	for i in 6 + _quality * 5:
		var p := Vector3(_rng.randf_range(34.5, 41.5), 0.0, _rng.randf_range(26.5, 32.0))
		if p.distance_to(SAFES[5]) < 2.4: # chừa trận linh
			continue
		_add_slab(p, _rng.randf() * TAU, _rng.randf_range(2.2, 3.2))


## Lát đá phiến dọc một lối: 2 hàng so le, mỗi phiến lệch xoay một chút cho tự nhiên.
func _add_stone_path(path: Array) -> void:
	var step: float = SLAB_STEP[_quality]
	if step <= 0.0:
		return
	for k in path.size() - 1:
		var a: Vector2 = path[k]
		var b: Vector2 = path[k + 1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var yaw := atan2(dir.x, dir.y)
		var t := 0.3
		var row := 0
		while t < a.distance_to(b):
			var q := a + dir * t + side * (0.32 if row % 2 == 0 else -0.32) + side * _rng.randf_range(-0.08, 0.08)
			_add_slab(Vector3(q.x, 0.0, q.y), yaw + _rng.randf_range(-0.25, 0.25), _rng.randf_range(1.6, 1.9))
			t += step * 0.5
			row += 1


## Một phiến đá dẹt (khuôn sỏi vuông ép mỏng), không đổ bóng.
func _add_slab(pos: Vector3, yaw: float, size: float) -> void:
	var model: String = PEBBLES[2 + _rng.randi() % 2]
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(size, 0.22, size)), pos)
	_batch(_load_model(NATURE + model + "_soi.obj"), xf, _textured_material(NATURE + "soi.png", false, false))


## Cửa hang mật đạo: ụ đá to có lỗ tối, cây mọc trên.
func _add_cave() -> void:
	var c := CAVE.get_center()
	_add_nature("Rock_Big_1", Vector3(c.x + 0.9, 0, c.y), PI / 2, 0.62, true)
	_add_nature("Rock_Big_2", Vector3(c.x + 0.7, 0, c.y - 1.8), 1.0, 0.4, true)
	_add_rock(Vector3(c.x + 0.4, 0, c.y + 1.7), 0.7)
	var hole := _shape(&"hole") as SphereMesh
	if hole == null:
		hole = SphereMesh.new()
		hole.radius = 0.5
		hole.height = 1.0
		hole.radial_segments = 10
		hole.rings = 5
		_shapes[&"hole"] = hole
	_batch(hole, Transform3D(Basis.from_scale(Vector3(0.5, 1.6, 1.6)), Vector3(c.x - 0.9, 0.5, c.y)), _material(CAVE_DARK))
	_add_nature("Bush_Large", Vector3(c.x + 1.3, 1.6, c.y + 0.4), 0.5, 0.5, true)


## Rừng cây ngoài tường viền (bắc, tây, đông) như rìa bản đồ Liên Quân.
func _add_border_cliffs() -> void:
	# Vách đá to xếp liền nhau thay tường gạch (bắc, tây, đông), rừng cây đằng sau.
	var x := -1.0
	while x < SIZE.x + 2:
		_add_cliff(Vector3(x, 0, -1.2), 1.0)
		x += CLIFF_SPACING[_quality] * _rng.randf_range(0.85, 1.1)
	var z := 1.5
	while z < SIZE.y:
		_add_cliff(Vector3(-1.2, 0, z), 1.0)
		_add_cliff(Vector3(SIZE.x + 1.2, 0, z), 1.0)
		z += CLIFF_SPACING[_quality] * _rng.randf_range(0.85, 1.1)
	for corner: Vector3 in [Vector3(-1.4, 0, -1.4), Vector3(SIZE.x + 1.4, 0, -1.4)]: # góc bắc to hơn
		_add_cliff(corner, 1.3)
	x = -2.0
	while x < SIZE.x + 3:
		_add_border_trees(Vector3(x, 0, -3.6 + _rng.randf_range(-0.5, 0.3)))
		x += BORDER_SPACING[_quality] * _rng.randf_range(0.9, 1.1)
	z = 2.0
	while z < SIZE.y + 2:
		_add_border_trees(Vector3(-3.6 + _rng.randf_range(-0.3, 0.5), 0, z))
		_add_border_trees(Vector3(SIZE.x + 3.6 + _rng.randf_range(-0.5, 0.3), 0, z))
		z += BORDER_SPACING[_quality] * _rng.randf_range(0.9, 1.1)
	_add_rim()
	x = 0.5
	while x < SIZE.x: # phía nam gần camera: vách đá thấp (~1,4 m) xen bụi lá, không che màn hình
		_add_nature("Rock_Big_2", Vector3(x, 0, SIZE.y + 0.9), _rng.randf() * TAU, _rng.randf_range(0.34, 0.4), true)
		if _quality > 0 and _rng.randf() < 0.6:
			_add_nature("Bush_Large", Vector3(x + 1.4, 0, SIZE.y + 1.3), _rng.randf() * TAU, _rng.randf_range(0.3, 0.38), false)
		x += CLIFF_SPACING[_quality] * _rng.randf_range(0.9, 1.1)


## Vành viền kiểu đền đài: cột đá chạm trổ dọc mép bắc, tây, đông nối nhau bằng lan can
## tròn, 2 góc bắc có cổng đôi cột cao với vòng đá. Phía nam chỉ cột thấp để không che camera.
func _add_rim() -> void:
	var rail := _material(RIM_STONE)
	var line: Array[Vector3] = [] # các cột theo thứ tự đi vòng: tây (nam lên bắc), bắc, đông (bắc xuống nam)
	var step: float = RIM_COLUMN_SPACING[_quality]
	var z := SIZE.y - 3.0
	while z > 0.0:
		line.append(Vector3(-0.7, 0, z))
		z -= step
	var x := 0.0
	while x < SIZE.x:
		line.append(Vector3(x, 0, -0.7))
		x += step
	z = 0.0
	while z < SIZE.y - 2.0:
		line.append(Vector3(SIZE.x + 0.7, 0, z))
		z += step
	for i in line.size():
		_add_model(DUNGEON + "pillar_decorated.obj", line[i], 0.0, Vector3(0.55, 1.0, 0.55), DUNGEON + "dungeon_texture.png")
		if i > 0 and line[i].distance_to(line[i - 1]) < step * 1.6: # lan can nối cột liền trước (hai tầng)
			_add_beam(line[i - 1] + Vector3(0, 3.5, 0), line[i] + Vector3(0, 3.5, 0), 0.24, rail)
			_add_beam(line[i - 1] + Vector3(0, 2.3, 0), line[i] + Vector3(0, 2.3, 0), 0.15, rail)
	for corner: Vector3 in [Vector3(-1.6, 0, -1.6), Vector3(SIZE.x + 1.6, 0, -1.6)]:
		_add_rim_gate(corner)
	x = 4.0
	while x < SIZE.x: # cột thấp phía nam
		_add_model(DUNGEON + "pillar_decorated.obj", Vector3(x, 0, SIZE.y + 0.6), 0.0, Vector3(0.36, 0.32, 0.36), DUNGEON + "dungeon_texture.png")
		x += step * 1.3


## Cổng đôi ở góc: 2 cột cao ~9 m, vòng đá dựng đứng giữa hai cột, đá đỉnh vắt ngang.
func _add_rim_gate(pos: Vector3) -> void:
	var stone := _material(RIM_STONE)
	var face := Basis(Vector3.UP, PI / 4 if pos.x < SIZE.x / 2 else -PI / 4) # hai cổng nhìn chéo vào sân
	for side: float in [-1.0, 1.0]:
		var p := pos + face * Vector3(side * 1.9, 0, 0)
		_add_model(DUNGEON + "pillar_decorated.obj", p, face.get_euler().y, Vector3(0.65, 2.3, 0.65), DUNGEON + "dungeon_texture.png")
	var ring := _shape(&"stone_ring") as TorusMesh
	if ring == null:
		ring = TorusMesh.new()
		ring.inner_radius = 0.78
		ring.outer_radius = 1.0
		ring.rings = 20
		ring.ring_segments = 6
		_shapes[&"stone_ring"] = ring
	var stand := face * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(1.8, 2.4, 1.8))
	_batch(ring, Transform3D(stand, pos + Vector3(0, 6.2, 0)), stone)
	_add_beam(pos + face * Vector3(-2.4, 9.0, 0), pos + face * Vector3(2.4, 9.0, 0), 0.3, stone)
	_add_beam(pos + face * Vector3(-1.9, 3.6, 0), pos + face * Vector3(1.9, 3.6, 0), 0.2, stone)


## Thanh trụ tròn nối 2 điểm (lan can, xà ngang).
func _add_beam(a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var beam := _cylinder(&"beam", 1.0, 1.0, 1.0, 8)
	var d := b - a
	var up := d.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up, side.cross(up)) * Basis.from_scale(Vector3(radius, d.length(), radius))
	_batch(beam, Transform3D(basis, (a + b) / 2), mat)


## Một tảng vách đá cao ~2,5 - 3 m (ngoài mép sân, mặt trong sát đường viền va chạm),
## mức Vừa / Cao thêm bụi lá dưới chân phía trong sân.
func _add_cliff(pos: Vector3, size: float) -> void:
	var model := "Rock_Big_1" if _rng.randf() < 0.55 else "Rock_Big_2"
	var s := _rng.randf_range(0.55, 0.68) * size * (1.0 if model == "Rock_Big_1" else 1.1)
	_add_nature(model, pos, _rng.randf() * TAU, s, true)
	if _quality > 0 and _rng.randf() < 0.35:
		var inward := Vector3(clampf(SIZE.x / 2 - pos.x, -1, 1), 0, clampf(SIZE.y / 2 - pos.z, -1, 1)).normalized()
		_add_nature("Bush_Large", pos + inward * 1.9 + Vector3(_rng.randf_range(-0.8, 0.8), 0, 0), _rng.randf() * TAU, _rng.randf_range(0.22, 0.3), true)


## Một cây rừng (thông hoặc cây tán tròn cao ~6 m), mức Cao thêm bụi lá dưới gốc.
## Rừng ngoài viền không đổ bóng (bóng chỉ rơi ra ngoài sân, tốn mà không ai nhìn).
func _add_border_trees(pos: Vector3) -> void:
	var yaw := _rng.randf() * TAU
	if _rng.randf() < 0.5:
		_add_nature("Pine_5", pos, yaw, _rng.randf_range(0.85, 1.0), false)
	else:
		_add_nature("CommonTree_5", pos, yaw, _rng.randf_range(1.25, 1.45), false)
	if _quality == 2:
		_add_nature("Bush_Large", pos + Vector3(_rng.randf_range(-1.8, 1.8), 0, _rng.randf_range(-1.8, 1.8)), yaw, _rng.randf_range(0.55, 0.75), false)


## Tường đá: khuôn tường KayKit 4 x 4 x 1 m kéo theo đoạn tường; phế tích xen tường vỡ.
func _add_wall(r: Rect2, height: float, ruin: bool) -> void:
	_add_collider(r, height)
	if _headless:
		return
	var along_x := r.size.x >= r.size.y
	var length := maxf(r.size.x, r.size.y)
	var count := maxi(1, ceili(length / 4.0))
	var seg := length / count
	var center := r.get_center()
	for k in count:
		var t := seg * (k + 0.5)
		var pos := Vector3(r.position.x + t, 0, center.y) if along_x else Vector3(center.x, 0, r.position.y + t)
		var model := "wall_broken.obj" if ruin and k % 2 == 0 else "wall.obj"
		var scale := Vector3(seg / 4.0, height / 4.0, minf(r.size.x, r.size.y))
		_add_model(DUNGEON + model, pos, 0.0 if along_x else PI / 2, scale, DUNGEON + "dungeon_texture.png")


## Đá tảng tranh vẽ, rộng ~2,2 lần bán kính, xoay ngẫu nhiên.
func _add_rock(pos: Vector3, radius: float) -> void:
	var model: String = ROCK_WIDTHS.keys()[_rng.randi() % ROCK_WIDTHS.size()]
	var s := radius * 2.2 / float(ROCK_WIDTHS[model]) * _rng.randf_range(0.95, 1.1)
	_add_nature(model, pos, _rng.randf() * TAU, s, true)


## Cây cổ thụ tán tròn cao ~5,5 m (gấp 3 lần người), thân chắn đường.
func _add_tree(pos: Vector3, size: float) -> void:
	if _rng.randf() < 0.5:
		_add_nature("CommonTree_3", pos, _rng.randf() * TAU, 0.85 * size, true) # khuôn cao 6,6 m
	else:
		_add_nature("CommonTree_5", pos, _rng.randf() * TAU, 1.25 * size, true) # khuôn cao 4,4 m


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


## Mô hình KayKit chỉ để nhìn, gốc đặt ở `pos`, xoay `yaw` quanh trục đứng.
func _add_model(path: String, pos: Vector3, yaw: float, scale: Vector3, texture: String) -> void:
	_batch(_load_model(path), Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), pos), _textured_material(texture, false, true))


## Mô hình Quaternius (mọi phần: thân, lá, hoa) phóng đều `scale` lần.
func _add_nature(model: String, pos: Vector3, yaw: float, scale: float, shadow: bool) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * scale), pos)
	for part: Array in NATURE_PARTS[model]:
		_batch(_load_model(NATURE + model + "_" + part[0] + ".obj"), xf, _textured_material(NATURE + part[1], part[2], shadow))


func _load_model(path: String) -> Mesh:
	if not _models.has(path):
		_models[path] = load(path)
	return _models[path]


## Material dùng chung cho mọi mô hình cùng một ảnh. Lá thì cắt viền theo alpha, thấy cả 2 mặt.
func _textured_material(path: String, cutout: bool, shadow: bool) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [path, cutout, shadow]
	if not _textured.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = BushScript.mip_texture(path)
		m.albedo_color = TEXTURE_TINTS.get(path.get_file(), Color.WHITE)
		m.roughness = 1.0
		m.metallic_specular = 0.2
		if cutout:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.3
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if not shadow:
			_no_shadow[m] = true
		_textured[key] = m
	return _textured[key]


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
	var out: Array[Rect2] = []
	out.assign(WALLS + RUINS + [PAVILION, CAVE])
	return out
