extends MapBase
## Bản đồ "Động phủ Linh Đài" 50 x 45 m dựng bằng code, xếp theo bố cục bản Meshy quan gửi:
## pháp trận truyền tống ở bờ tây (đệ tử xuất hiện trên vòng phù văn, mô hình Meshy quan gửi), động phủ
## sàn đá góc đông bắc với linh đài, 5 cột cao và 2 cửa phong ấn cam (2 lối ra), huyết trận ở giữa, 6 trận
## linh quanh sân, tảng đá to có cây mọc ở phía bắc, cột đá đổ, bụi cỏ cao để nấp. Mặt sân và viền
## (vách đá, lan can, cổng vòng 2 góc bắc) là mô hình bản Meshy thứ hai (ban_do_meshy/ban_do.glb), giữ
## nguyên màu gốc bằng shaders/ban_do_meshy.gdshader.
## Cây, đá, cỏ, hoa kiểu tranh vẽ dùng Quaternius Stylized Nature MegaKit (CC0);
## tường, cột dùng KayKit Dungeon Remastered (CC0, Kay Lousberg). Đá, tường dùng ảnh vẽ tay CC0
## (rubberduck, MELLE; shaders/da_ve_tay), nắng ấm bóng xanh tím, phù văn phát sáng (phu_van).
## Tỉ lệ so với nhân vật theo kiểu Liên Quân: tường cao hơn người, cây gấp 3 lần
## người, bụi cỏ thành đám rộng 3 - 4 m.
## Phần chỉ để nhìn gộp thành một mesh cho mỗi material trong mỗi ô 15 x 12 m: ít
## lần vẽ (draw call) mà ô nằm ngoài màn hình vẫn bị bỏ qua không vẽ.

const SIZE := Vector2(50, 45) # x, z
const WALL_HEIGHT := 2.4 # cao hơn đầu người (1,7 m) như tường Liên Quân, camera chéo 49° vẫn thấy sau tường
const RUIN_HEIGHT := 1.8 # tường phế tích đổ nát
## Tường trên mặt sàn: Rect2(x, z, rộng theo x, sâu theo z), đơn vị mét.
const WALLS := [
	# Viền ngoài (5 rect đầu): hình là vách đá, không phải tường gạch
	Rect2(0, 0, 50, 0.5), Rect2(0, 44.5, 50, 0.5),
	Rect2(49.5, 0, 0.5, 45),
	# Bờ tây (2 rect): hở chỗ lối vào từ pháp trận truyền tống
	Rect2(0, 0, 0.5, 25.5), Rect2(0, 33.3, 0.5, 11.7),
	# Động phủ (đông bắc): khe ở tường tây và tường nam là 2 cửa phong ấn
	Rect2(40.0, 0.5, 0.5, 7.0), Rect2(40.0, 9.9, 0.5, 4.6),
	Rect2(40.0, 14.5, 5.0, 0.5), Rect2(47.4, 14.5, 2.1, 0.5),
]
## Tường phế tích (thấp, đầu lởm chởm): Rect2 như WALLS.
const RUINS: Array[Rect2] = []
## 6 trận linh quanh sân, chừa giữa cho huyết trận; cần giải MatchConfig.safes_required.
const SAFES := [
	Vector3(6.6, 0, 3.4), Vector3(21.9, 0, 6.1), Vector3(37.6, 0, 3.4), Vector3(41.8, 0, 28.0),
	Vector3(45.1, 0, 41.1), Vector3(22.6, 0, 42.1),
]
## 2 lối ra là 2 cửa phong ấn của động phủ: tường tây (quay theo trục x) và tường nam (xoay 90°).
const EXIT_GATES := [Vector3(40.25, 0, 8.7), Vector3(46.2, 0, 14.75)]
const EXIT_GATE_YAW := [0.0, PI / 2]
## Thanh chắn trong khe cửa: cửa phong ấn đóng thì không vào động phủ được,
## vùng thoát của lối ra vẫn chìa ra ngoài tường.
const GATE_BLOCKERS := [Rect2(40.15, 7.5, 0.2, 2.4), Rect2(45.0, 14.65, 2.4, 0.2)]
## Huyết trận ở giữa, kết giới cao 3 m, chỉ đệm lò xo bay qua được.
const PRISONS := [Vector3(26.0, 0, 22.5)]
## Bụi cỏ cao (hơn đầu người) để nấp, đúng chỗ các bụi tròn của bản Meshy: Vector3(x, z, bán kính).
const BUSHES: Array[Vector3] = [
	Vector3(5.1, 41.5, 1.9), Vector3(9.3, 9.7, 1.6), Vector3(10.2, 14.1, 1.8), Vector3(10.2, 23.8, 1.9),
	Vector3(16.3, 20.5, 2.0), Vector3(16.6, 13.0, 2.0), Vector3(18.2, 29.6, 1.8), Vector3(20.6, 19.0, 1.6),
	Vector3(21.0, 28.1, 1.7), Vector3(21.3, 11.6, 1.9), Vector3(28.2, 2.8, 1.7), Vector3(29.2, 29.6, 1.8),
	Vector3(35.0, 29.0, 1.8), Vector3(35.3, 10.6, 2.1), Vector3(35.6, 36.0, 2.0), Vector3(38.0, 41.2, 2.0),
	Vector3(38.4, 27.8, 1.6), Vector3(40.4, 24.5, 1.8), Vector3(43.0, 21.9, 1.5), Vector3(44.3, 34.5, 2.0),
	Vector3(47.8, 42.4, 1.4),
]
## Bụi lá trang trí trong động phủ (không vào được nên không tính luật nấp): Vector3(x, z, bán kính).
const DECOR_BUSHES: Array[Vector3] = [
	Vector3(41.3, 1.5, 0.8), Vector3(48.6, 1.6, 0.7), Vector3(41.2, 13.5, 0.8), Vector3(48.7, 13.4, 0.8),
	Vector3(41.3, 5.6, 0.7),
]
## Đá tảng chắn đường (và chắn phi kiếm): Vector3(x, z, bán kính).
const ROCKS: Array[Vector3] = [
	Vector3(26.0, 10.3, 1.7), Vector3(18.0, 41.5, 2.0), Vector3(43.0, 17.6, 1.5), Vector3(48.1, 26.8, 1.0),
	Vector3(3.8, 34.8, 0.7), Vector3(6.0, 11.3, 0.45), Vector3(12.8, 36.3, 0.6), Vector3(15.0, 30.4, 0.6),
	Vector3(22.5, 35.9, 0.55), Vector3(23.6, 32.0, 0.8), Vector3(32.9, 6.6, 0.45), Vector3(38.6, 12.7, 0.4),
	Vector3(39.6, 35.5, 0.5), Vector3(46.1, 36.1, 0.45), Vector3(44.6, 18.8, 0.9),
]
## Cây cổ thụ: thân chắn đường, tán che: Vector3(x, z, cỡ).
const TREES: Array[Vector3] = [
	Vector3(9.8, 42.3, 0.9), Vector3(12.1, 4.2, 1.1), Vector3(12.9, 32.3, 0.9), Vector3(24.4, 38.0, 0.8),
	Vector3(31.9, 42.0, 0.8), Vector3(37.7, 19.8, 0.8), Vector3(37.8, 15.4, 0.85), Vector3(43.4, 30.1, 0.9),
	Vector3(26.9, 9.2, 0.6),
]
## Cột đá đổ nằm chéo phía bắc huyết trận (chắn đường): 2 đầu (x, z).
const FALLEN_PILLAR := [Vector2(28.6, 12.4), Vector2(31.4, 17.4)]
## Bề rộng lối gạch (m).
const PATH_WIDTH := 1.5
## Lối gạch của bản Meshy (đo theo mô hình): không rải cỏ lên.
const STONE_PATHS := [
	[Vector2(14.9, 33.6), Vector2(18.8, 30.1), Vector2(23.8, 27.1), Vector2(29.4, 25.4), Vector2(35.0, 24.1),
		Vector2(40.0, 22.5), Vector2(43.1, 21.4)],
	[Vector2(36.8, 23.5), Vector2(37.8, 19.1), Vector2(39.0, 14.0), Vector2(39.6, 9.2)],
]
## Pháp trận truyền tống lùi ra bờ tây (người trốn hiện ra trên vòng phù văn): mũi 2 cánh tường rìa chạm
## lan can bờ kè (x ~ -1), đoạn bờ kè giữa 2 cánh đã phá (CUT trong tools/ban_do_meshy/build_ban_do.py),
## vòng bậc thềm bán nguyệt chìa ra sân.
const TELEPORT := Vector3(-2.5, 0, 29.4)
const TELEPORT_WING := 3.9 # m: nửa khoảng cách 2 mũi cánh theo z
const TELEPORT_WALL_RADIUS := 3.2 # m, tâm tường vòng (khối va chạm)
const TELEPORT_CLEAR := 4.6 # m: không rải cỏ, hoa trong vòng này
const ALTAR := Vector3(45.0, 0, 8.5) # linh đài trong động phủ
const COURTYARD := Rect2(40.5, 0.5, 9.0, 14.0) # sàn động phủ trong tường
## 5 cột cao trong động phủ (như bản Meshy): 3 cột hàng bắc, 2 cột dọc tường đông.
const MANSION_PILLARS := [Vector2(42.4, 2.6), Vector2(45.6, 2.6), Vector2(48.6, 2.6), Vector2(48.6, 7.0), Vector2(48.6, 11.2)]
const HUNTER_SPAWN := Vector3(42.5, 0.05, 39.5) # ma tu xuất hiện ở phế tích đông nam, xa pháp trận truyền tống
const ESCAPEE_SPAWNS: Array[Vector3] = [
	Vector3(-3.15, 0.05, 28.7), Vector3(-1.85, 0.05, 28.7), Vector3(-3.15, 0.05, 30.1), Vector3(-1.85, 0.05, 30.1),
]
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
const DUNGEON := "res://Objects/models/kaykit_dungeon/" # tường, cột, đá vụn (khuôn tường 4 x 4 x 1 m)
const NATURE := "res://Objects/models/quaternius_nature/" # cây, đá, cỏ, hoa, sỏi (đơn vị mét)
const GROUND := "res://Objects/models/nen_ve_tay/" # ảnh vẽ tay CC0: nền, đá, tường, phù văn
## Ảnh lớp nền tách từ bản Meshy quan gửi (R: lối đất, G: nền đá vỡ), phủ đúng sân SIZE.
const LAYOUT := "res://Objects/models/ban_do_meshy/lop_nen.png"
## Mô hình bản Meshy đã đưa về tọa độ trận (tools/ban_do_meshy/build_ban_do.py).
const MODEL := "res://Objects/models/ban_do_meshy/ban_do.glb"
## Pháp trận truyền tống Meshy quan gửi (4k tam giác, ngang 9 m, vòng phù văn bán kính ~1,6 m ở tâm, tường vòng
## cao ~1,4 m sau lưng): quay tường vòng ra phía tây, mở về phía sân.
const TELEPORT_MODEL := "res://Objects/models/phap_tran/phap_tran.glb"
const MESHY_ORIGINAL := "res://Objects/models/ban_do_meshy/mau_goc.jpg" # ảnh màu gốc 2048 px, chỉ đồ họa Cao
const MESHY_SHARPEN := [0.0, 0.35, 0.6] # độ làm nét ảnh Meshy theo mức đồ họa
const MESHY_DETAIL := 0.22 # hạt chi tiết đồ họa Cao (chỉ đổi độ sáng)
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
## Số khóm cỏ thấp rải trên sân theo mức đồ họa 0 Thấp, 1 Vừa, 2 Cao (mỗi khóm ~155 tam giác).
const TUFT_CLUSTERS := [14, 45, 75]
const BORDER_WALLS := 5 # số rect viền ngoài ở đầu WALLS
const ROCK_TINT := Color(1.0, 1.0, 1.05) # tảng đá, vách viền
const WALL_TINT := Color(0.85, 0.85, 0.9) # tường gạch phòng xuất phát, động phủ
const MOSS_TINT := Color(0.5, 0.58, 0.45) # rêu trên mặt đá

# Sắc nhân lên ảnh nền vẽ tay (1 = giữ nguyên màu ảnh): vệt tối và vệt sáng loang như bản Meshy.
const GROUND_SATURATION := 0.5 # nền bớt rực để nhân vật, đạn, hiệu ứng nổi lên
const PAVING_DARK := Color(0.82, 0.84, 0.88) # sắc nhân lên ảnh sàn đá lát
const PAVING_LIGHT := Color(0.95, 0.96, 1.0)
const MARBLE := Color(0.88, 0.88, 0.86)
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
var _layout: Image # ảnh lớp nền Meshy (chỉ máy có hình), để rải cỏ tránh lối đất
var _stones := {} # bộ tham số -> material đá vẽ tay dùng chung
var _ground_materials := {} # bộ tham số -> material nền vẽ tay dùng chung
var _no_shadow := {} # material -> true: mesh gộp của nó không đổ bóng (hình sát sàn, trận pháp)
var _rng := RandomNumberGenerator.new() # hình trang trí lệch ngẫu nhiên nhưng cố định mỗi lần dựng
var _headless := DisplayServer.get_name() == "headless" # server riêng: chỉ dựng va chạm, không dựng hình


func _ready() -> void:
	_rng.seed = 20261020
	_add_collider(Rect2(-8, -8, SIZE.x + 16, SIZE.y + 16), 0.2, -0.2) # sàn
	for i in WALLS.size():
		if i < BORDER_WALLS:
			_add_collider(WALLS[i], WALL_HEIGHT) # hình: vách đá, lan can của mô hình Meshy
		else:
			_add_wall(WALLS[i], WALL_HEIGHT, false)
	for r: Rect2 in RUINS:
		_add_wall(r, RUIN_HEIGHT, true)
	for r: Rect2 in GATE_BLOCKERS:
		_add_collider(r, WALL_HEIGHT)
	for r: Rect2 in _teleport_walls():
		_add_collider(r, WALL_HEIGHT)
	var fa: Vector2 = FALLEN_PILLAR[0]
	var fb: Vector2 = FALLEN_PILLAR[1]
	for k in 3: # cột đổ: 3 khúc chắn dọc thân
		var c := fa.lerp(fb, (k + 0.5) / 3.0)
		_add_collider(Rect2(c.x - 0.55, c.y - 0.55, 1.1, 1.1), 1.0)
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
	_add_teleport()
	_add_cave_mansion()
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
	_add_runes()
	_add_ground_cover()


## Mô hình bản Meshy quan gửi (mặt sân, lối đi, vách đá, lan can, cổng vòng), giữ nguyên màu gốc
## (shaders/ban_do_meshy.gdshader). Đồ họa Cao dùng ảnh gốc 2048 px, làm nét và thêm hạt chi tiết.
func _add_ground() -> void:
	var map: Node3D = (load(MODEL) as PackedScene).instantiate()
	_meshy_look(map, BushScript.mip_texture(MESHY_ORIGINAL) if _quality == 2 else null)
	add_child(map)
	_layout = (load(LAYOUT) as Texture2D).get_image()
	if _layout.is_compressed():
		_layout.decompress()


## Tô mô hình Meshy bằng shaders/ban_do_meshy.gdshader (giữ đúng màu ảnh gốc, làm nét theo mức đồ họa).
## `original`: ảnh màu độ phân giải cao thay ảnh trong GLB (null: dùng ảnh trong GLB).
func _meshy_look(model: Node3D, original: Texture2D) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://Objects/shaders/ban_do_meshy.gdshader")
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if original == null:
			m.set_shader_parameter(&"meshy_albedo", (mi.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # ảnh gốc đã vẽ sẵn bóng
	m.set_shader_parameter(&"sharpen", MESHY_SHARPEN[_quality])
	if original != null:
		m.set_shader_parameter(&"meshy_albedo", original)
		m.set_shader_parameter(&"texel", Vector2.ONE / float(original.get_width()))
		m.set_shader_parameter(&"detail", BushScript.mip_texture(GROUND + "da_tang.png"))
		m.set_shader_parameter(&"detail_amount", MESHY_DETAIL)


## Lớp nền tại điểm p trên sân (R: đất, G: đá vỡ), đọc từ ảnh lớp Meshy.
func _layout_at(p: Vector2) -> Color:
	var x := clampi(int(p.x / SIZE.x * _layout.get_width()), 0, _layout.get_width() - 1)
	var y := clampi(int(p.y / SIZE.y * _layout.get_height()), 0, _layout.get_height() - 1)
	return _layout.get_pixel(x, y)


## Material nền vẽ tay: 2 ảnh màu nước trộn theo nhiễu, nhân sắc loang dark -> light. Dùng chung theo bộ tham số.
func _hand_painted(a: String, b: String, dark: Color, light: Color, scale: float, tile: float) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [a, b, dark.to_html(), tile]
	if _ground_materials.has(key):
		return _ground_materials[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://Objects/shaders/nen_tranh.gdshader")
	m.set_shader_parameter(&"albedo_a", BushScript.mip_texture(GROUND + a))
	m.set_shader_parameter(&"albedo_b", BushScript.mip_texture(GROUND + b))
	m.set_shader_parameter(&"noise", BushScript.mip_texture(NATURE + "nhieu.png"))
	m.set_shader_parameter(&"dark", dark)
	m.set_shader_parameter(&"light", light)
	m.set_shader_parameter(&"scale", scale)
	m.set_shader_parameter(&"tile", tile)
	m.set_shader_parameter(&"saturation", GROUND_SATURATION)
	_no_shadow[m] = true
	_ground_materials[key] = m
	return m


## Cỏ thấp, hoa, cỏ ba lá rải thành cụm trên sân; cây bụi nhỏ chân tường.
## Chỉ để nhìn, không đổ bóng; số lượng theo mức đồ họa.
func _add_ground_cover() -> void:
	var tuft := BushScript.grass_material(0.5, BushScript.ROOT_COLOR, BushScript.TIP_COLOR, 1.0)
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
		if p.distance_to(Vector2(TELEPORT.x, TELEPORT.z)) < TELEPORT_CLEAR or COURTYARD.grow(0.6).has_point(p):
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
		var lay := _layout_at(p)
		if lay.r > 0.3 or lay.g > 0.3:
			ok = false
		for path: Array in STONE_PATHS:
			for k in path.size() - 1:
				if _segment_distance(p, path[k], path[k + 1]) < PATH_WIDTH / 2 + 0.3:
					ok = false
		if ok:
			return Vector3(p.x, 0, p.y)
	return Vector3(-1, 0, -1)


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## Pháp trận truyền tống Meshy, tường vòng quay ra bờ tây.
func _add_teleport() -> void:
	var tp: Node3D = (load(TELEPORT_MODEL) as PackedScene).instantiate()
	tp.position = TELEPORT
	tp.rotation.y = PI / 2 # mặt sau (-z) của mô hình quay về phía tây
	_meshy_look(tp, null)
	add_child(tp)


## Khối va chạm: 13 khối dọc tường vòng pháp trận (nửa vòng phía tây), 2 bên theo 2 cánh nối tới bờ kè.
func _teleport_walls() -> Array[Rect2]:
	var w := TELEPORT_WING
	var out: Array[Rect2] = [
		Rect2(TELEPORT.x - 0.45, TELEPORT.z - w - 0.5, 0.95 - TELEPORT.x, 0.5), # cánh bắc tới bờ kè
		Rect2(TELEPORT.x - 0.45, TELEPORT.z + w, 0.95 - TELEPORT.x, 0.5), # cánh nam
		Rect2(TELEPORT.x - 0.45, TELEPORT.z - w - 0.5, 0.9, w + 0.5 - TELEPORT_WALL_RADIUS), # nối đầu tường vòng
		Rect2(TELEPORT.x - 0.45, TELEPORT.z + TELEPORT_WALL_RADIUS, 0.9, w + 0.5 - TELEPORT_WALL_RADIUS),
	]
	for k in 13:
		var a := deg_to_rad(-90.0 + 15.0 * k)
		var c := Vector2(TELEPORT.x - cos(a) * TELEPORT_WALL_RADIUS, TELEPORT.z + sin(a) * TELEPORT_WALL_RADIUS)
		out.append(Rect2(c - Vector2(0.45, 0.45), Vector2(0.9, 0.9)))
	return out


## Sàn đá lát phiến lớn (ảnh Poly Haven CC0) phủ một khu chữ nhật.
func _add_floor(r: Rect2) -> void:
	var c := r.get_center()
	var box := _shape(&"floor") as BoxMesh
	if box == null:
		box = BoxMesh.new()
		box.size = Vector3(1, 0.02, 1)
		_shapes[&"floor"] = box
	_batch(box, Transform3D(Basis.from_scale(Vector3(r.size.x, 1, r.size.y)), Vector3(c.x, 0.01, c.y)),
		_hand_painted("san_da.png", "san_da.png", PAVING_DARK, PAVING_LIGHT, 0.08, 0.25))


## Động phủ: sàn đá lát phiến lớn, linh đài cẩm thạch với trận xanh, 4 cột đá, bụi cỏ quanh tường.
func _add_cave_mansion() -> void:
	_add_floor(COURTYARD)
	var dais := _cylinder(&"dais", 1.0, 1.1, 1.0, 16)
	_batch(dais, Transform3D(Basis.from_scale(Vector3(1.7, 0.3, 1.7)), ALTAR + Vector3(0, 0.15, 0)), _material(MARBLE))
	_batch(dais, Transform3D(Basis.from_scale(Vector3(1.35, 0.2, 1.35)), ALTAR + Vector3(0, 0.38, 0)), _material(MARBLE))
	_add_ring(ALTAR + Vector3(0, 0.49, 0), 1.05, BLUE_GLOW)
	_add_disc(ALTAR + Vector3(0, 0.485, 0), 0.5, BLUE_SOFT, true)
	for p: Vector2 in MANSION_PILLARS:
		_add_model(DUNGEON + "pillar_decorated.obj", Vector3(p.x, 0, p.y), 0.0, Vector3(0.4, 1.05, 0.4), DUNGEON + "dungeon_texture.png")
	for i in DECOR_BUSHES.size(): # bụi lá xanh (máy yếu một nửa)
		if _quality == 0 and i % 2 == 1:
			continue
		var b := DECOR_BUSHES[i]
		_add_nature("Bush_Large", Vector3(b.x, 0, b.y), _rng.randf() * TAU, b.z * 0.45, true)


## Phế tích đông nam: cột đá đổ nằm chéo phía bắc huyết trận (chỉ để nhìn,
## va chạm của cột đổ dựng trong _ready).
func _add_rubble() -> void:
	var fa: Vector2 = FALLEN_PILLAR[0]
	var fb: Vector2 = FALLEN_PILLAR[1]
	var d := fb - fa
	var mid := (fa + fb) / 2
	# khuôn cột cao 4 m dựng đứng: quay nằm xuống theo hướng fa -> fb, nửa thân vùi đất
	var lying := Basis(Vector3.UP, atan2(d.x, d.y)) * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(0.45, d.length() / 4.0, 0.45))
	var xf := Transform3D(lying, Vector3(mid.x, 0.25, mid.y) - lying * Vector3(0, 2.0, 0))
	_batch(_load_model(DUNGEON + "pillar_decorated.obj"), xf, _textured_material(DUNGEON + "dungeon_texture.png", false, true))


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
		var xf := Transform3D(Basis(Vector3.UP, 0.0 if along_x else PI / 2) * Basis.from_scale(scale), pos)
		_batch(_load_model(DUNGEON + model), xf, _stone("tuong.png", WALL_TINT, 0.0, 0.5))


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
		var mat: Material = _stone("da_tang.png", ROCK_TINT, 0.3, 0.32) if part[1] == "da.png" else _textured_material(NATURE + part[1], part[2], shadow)
		_batch(_load_model(NATURE + model + "_" + part[0] + ".obj"), xf, mat)


func _load_model(path: String) -> Mesh:
	if not _models.has(path):
		_models[path] = load(path)
	return _models[path]


## Vòng phù văn phát sáng trên nền: quanh linh đài, huyết trận.
func _add_runes() -> void:
	_add_rune(ALTAR, 2.7, BLUE_GLOW, -0.06)
	for p: Vector3 in PRISONS:
		_add_rune(p, 4.6, BLOOD_GLOW, 0.05)


## Một vòng phù văn bán kính `radius` (ảnh vẽ bằng code, shaders/phu_van.gdshader).
func _add_rune(center: Vector3, radius: float, color: Color, spin: float) -> void:
	var quad := _shape(&"rune") as PlaneMesh
	if quad == null:
		quad = PlaneMesh.new()
		quad.size = Vector2(2, 2)
		_shapes[&"rune"] = quad
	var m := ShaderMaterial.new()
	m.shader = load("res://Objects/shaders/phu_van.gdshader")
	m.set_shader_parameter(&"rune", BushScript.mip_texture(GROUND + "phu_van.png"))
	m.set_shader_parameter(&"color", color)
	m.set_shader_parameter(&"spin", spin)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = center + Vector3(0, 0.045, 0)
	mi.scale = Vector3(radius, 1, radius)
	add_child(mi)


## Material đá vẽ tay chiếu 3 phía (shaders/da_ve_tay.gdshader), dùng chung theo bộ tham số.
## `moss`: phần mặt trên phủ rêu (0 không rêu); `tile`: số lần lặp ảnh trên 1 m.
func _stone(texture: String, tint: Color, moss: float, tile: float) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [texture, tint.to_html(), moss, tile]
	if not _stones.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://Objects/shaders/da_ve_tay.gdshader")
		m.set_shader_parameter(&"albedo", BushScript.mip_texture(GROUND + texture))
		m.set_shader_parameter(&"moss", BushScript.mip_texture(GROUND + "co_1.png"))
		m.set_shader_parameter(&"tint", tint)
		m.set_shader_parameter(&"moss_tint", MOSS_TINT)
		m.set_shader_parameter(&"moss_amount", moss)
		m.set_shader_parameter(&"tile", tile)
		_stones[key] = m
	return _stones[key]


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
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.9, 0.72) # nắng vàng ấm, tương phản bóng râm xanh tím
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.4, 0.52, 0.58) # trời xám xanh, không chói
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.6, 0.95) # bóng râm ngả xanh lam tím như bản đồ MOBA
	env.ambient_light_energy = 0.5
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
	out.assign(WALLS + RUINS + _teleport_walls())
	return out
