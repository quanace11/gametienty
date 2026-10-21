extends Node3D
## Bụi cỏ cao để nấp: 3 khóm cỏ (mô hình bui_co, giảm từ grass.glb 30k tam giác)
## xoay lệch nhau thành một bụi tròn, không chặn đường. Ai đứng trong bụi thì phe
## kia không thấy (luật ở GameState.can_see, server không gửi vị trí). Máy nào
## có nhân vật của mình đứng trong bụi thì bụi đó trong mờ để còn thấy mình.
## Mức chi tiết theo cài đặt đồ họa (ProjectSettings "game/graphics_quality"):
## mỗi khóm Thấp ~250, Vừa ~400, Cao ~800 tam giác (mỗi bụi 3 khóm). Cả bụi là
## một mesh dùng chung (bụi bán kính 1 m, cao ~2,1 m), mỗi bụi một lần vẽ.

const CHECK_INTERVAL := 0.1
const MODELS := [ # theo mức đồ họa 0 Thấp, 1 Vừa, 2 Cao
	"res://Objects/models/bui_co/bui_co_thap.obj",
	"res://Objects/models/bui_co/bui_co_vua.obj",
	"res://Objects/models/bui_co/bui_co_cao.obj",
]
const LEAF_TEXTURE := "res://Objects/models/bui_co/la_co.jpg"
const HEIGHT := 2.1 # mét, cao hơn đầu nhân vật (1,7 m): đứng trong là khuất hẳn
const TINT := Color(0.62, 0.9, 0.62) # nhuộm lá ngọc của ảnh gốc cho hợp sân cỏ

var index := 0 ## chỉ số trong MapBase.get_bushes()
var radius := 1.4

var _mesh: MeshInstance3D
var _see_through := false
var _check_left := 0.0
var _me: Node3D

static var _leaf_mesh: ArrayMesh # bụi bán kính 1 m
static var _solid: StandardMaterial3D
static var _faded: StandardMaterial3D


func _ready() -> void:
	if DisplayServer.get_name() == "headless": # server riêng: luật bụi cây nằm ở GameState, không cần hình
		set_process(false)
		return
	_mesh = MeshInstance3D.new()
	_mesh.mesh = leaf_mesh()
	_mesh.material_override = _solid
	_mesh.scale = Vector3(radius, 1.0, radius)
	_mesh.rotation.y = index * 1.3 # mỗi bụi xoay một kiểu cho đỡ giống nhau
	add_child(_mesh)


## Mesh bụi bán kính 1 m dùng chung (bản đồ cũng dùng để vẽ bụi trang trí).
static func leaf_mesh() -> ArrayMesh:
	_build_shared()
	return _leaf_mesh


static func leaf_material() -> StandardMaterial3D:
	_build_shared()
	return _solid


static func _build_shared() -> void:
	if _leaf_mesh:
		return
	var quality := clampi(int(ProjectSettings.get_setting("game/graphics_quality", 0)), 0, MODELS.size() - 1)
	var clump: Mesh = load(MODELS[quality])
	# Khóm cỏ gốc dài ~1,6 m, rộng ~0,6 m: 3 khóm xoay 60° thành bụi tròn đường kính ~2 m.
	var aabb := clump.get_aabb()
	var s := 2.0 / maxf(aabb.size.x, 0.01)
	var h := HEIGHT / maxf(aabb.size.y, 0.01)
	var lift := -aabb.position.y * h
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var basis := Basis(Vector3.UP, PI / 3 * i).scaled(Vector3(s * (1.0 - 0.12 * i), h * (1.0 - 0.1 * (i % 2)), s * (1.0 - 0.12 * i)))
		st.append_from(clump, 0, Transform3D(basis, Vector3(0, lift, 0)))
	_leaf_mesh = st.commit()
	# Ảnh lá lấm tấm: cần mipmap kẻo nhìn xa bị nhiễu hạt (file .import không vào git nên tạo ở đây).
	var img := (load(LEAF_TEXTURE) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	if not img.has_mipmaps():
		img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_solid = _leaf_mat(tex, 1.0)
	_faded = _leaf_mat(tex, 0.35)
	RenderWarmup.register(_faded) # chỉ hiện khi mình bước vào bụi


static func _leaf_mat(tex: Texture2D, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(TINT, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED # lá cỏ một mặt
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	var me := _my_node()
	if me == null and GameState.rules != null and GameState.rules.is_playing():
		set_process(false) # máy này không có nhân vật (server không chơi): khỏi tìm mãi
		return
	var inside := me != null and GameState.bush_at(me.global_position) == index
	if inside == _see_through:
		return
	_see_through = inside
	_mesh.material_override = _faded if inside else _solid
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if inside else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _my_node() -> Node3D:
	if is_instance_valid(_me):
		return _me
	var my_id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		if (node as EntityBase).peer_id == my_id:
			_me = node as Node3D
			break
	return _me
