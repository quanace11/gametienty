extends Node3D
## Bụi cỏ cao để nấp: một đám nhiều khóm cỏ cao (mô hình Quaternius Stylized Nature
## MegaKit, CC0) rộng 3 - 5 m như bụi Liên Quân, không chặn đường. Ai đứng trong bụi thì phe
## kia không thấy (luật ở GameState.can_see, server không gửi vị trí). Máy nào
## có nhân vật của mình đứng trong bụi thì bụi đó trong mờ để còn thấy mình.
## Màu kiểu tranh vẽ: gốc xanh đậm, ngọn xanh non (shaders/co.gdshader).
## Mức chi tiết theo cài đặt đồ họa (ProjectSettings "game/graphics_quality"):
## Thấp 4 x 326, Vừa 6 x 326, Cao 9 khóm (xen 326 và 622) tam giác mỗi bụi. Cả bụi là
## một mesh dùng chung (bụi bán kính 1 m, cao ~2,1 m), mỗi bụi một lần vẽ.

const CHECK_INTERVAL := 0.1
const MODEL_DIR := "res://Objects/models/quaternius_nature/"
const CLUMP_MODELS: Array[String] = ["Grass_Common_Tall_co.obj", "Grass_Wispy_Tall_co.obj"]
const CLUMPS := [4, 6, 9] # số khóm mỗi bụi theo mức đồ họa 0 Thấp, 1 Vừa, 2 Cao
const GRASS_SHADER := "res://Objects/shaders/co.gdshader"
const GRASS_TEXTURE := "res://Objects/models/quaternius_nature/co.png"
const HEIGHT := 2.1 # mét, cao hơn đầu nhân vật (1,7 m): đứng trong là khuất hẳn
const ROOT_COLOR := Color(0.08, 0.24, 0.1)
const TIP_COLOR := Color(0.42, 0.7, 0.26)

var index := 0 ## chỉ số trong MapBase.get_bushes()
var radius := 1.4

var _mesh: MeshInstance3D
var _see_through := false
var _check_left := 0.0
var _me: Node3D

static var _leaf_mesh: ArrayMesh # bụi bán kính 1 m
static var _solid: ShaderMaterial
static var _faded: ShaderMaterial
static var _textures := {} # đường dẫn -> ảnh có mipmap dùng chung


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


static func leaf_material() -> ShaderMaterial:
	_build_shared()
	return _solid


static func _build_shared() -> void:
	if _leaf_mesh:
		return
	var quality := clampi(int(ProjectSettings.get_setting("game/graphics_quality", 0)), 0, CLUMPS.size() - 1)
	var count: int = CLUMPS[quality]
	# Một khóm giữa, các khóm còn lại vòng quanh cách tâm 0,5 (bụi bán kính 1 m), cao
	# đúng HEIGHT; mức Cao xen khóm cỏ rủ (622 tam giác) cho dày hơn.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var clump: Mesh = load(MODEL_DIR + CLUMP_MODELS[i % 2 if quality == 2 else 0])
		var aabb := clump.get_aabb()
		var k := 1.0 if i == 0 else 0.86 + 0.08 * (i % 3)
		var s := 1.05 / maxf(aabb.size.x, aabb.size.z) * k
		var h := HEIGHT / maxf(aabb.end.y, 0.01) * k
		var spot := Vector3.ZERO
		if i > 0:
			var a := TAU * (i - 1) / (count - 1)
			spot = Vector3(cos(a), 0, sin(a)) * 0.5
		st.append_from(clump, 0, Transform3D(Basis(Vector3.UP, 1.1 * i) * Basis.from_scale(Vector3(s, h, s)), spot))
	_leaf_mesh = st.commit()
	_solid = grass_material(HEIGHT, ROOT_COLOR, TIP_COLOR, 1.0)
	_faded = grass_material(HEIGHT, ROOT_COLOR, TIP_COLOR, 0.35)
	RenderWarmup.register(_faded) # chỉ hiện khi mình bước vào bụi


## Material cỏ tranh vẽ (gốc đậm, ngọn sáng); `fade` < 1 thì trong mờ. Bản đồ dùng cho cỏ trang trí.
static func grass_material(height: float, root: Color, tip: Color, fade: float) -> ShaderMaterial:
	var shader := load(GRASS_SHADER) as Shader
	if fade < 1.0:
		var see_through := Shader.new()
		see_through.code = shader.code.replace("; //MO_RENDER", ", depth_draw_always;").replace("//MO_ALPHA", "ALPHA = fade;")
		shader = see_through
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"tex", mip_texture(GRASS_TEXTURE))
	m.set_shader_parameter(&"root_color", root)
	m.set_shader_parameter(&"tip_color", tip)
	m.set_shader_parameter(&"height", height)
	m.set_shader_parameter(&"fade", fade)
	return m


## Ảnh có mipmap (file .import không vào git nên tạo ở đây), kẻo nhìn xa bị nhiễu hạt.
static func mip_texture(path: String) -> Texture2D:
	if not _textures.has(path):
		var img := (load(path) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		if not img.has_mipmaps():
			img.generate_mipmaps()
		_textures[path] = ImageTexture.create_from_image(img)
	return _textures[path]


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
