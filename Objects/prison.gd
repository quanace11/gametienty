class_name Prison
extends Interactable
## Huyết trận (trong code Core gọi là "prison", xưa là nhà tù): khu kết giới đỏ
## cao kín, không có cửa. Ma tu kéo đệ tử tới sát kết giới là nhốt (người bị nhốt
## bị ném vào giữa trận). Người bị nhốt bị tế huyết dần (MatchConfig.prison_time),
## hết thì chết; chỉ trận bàn hồi phục ném qua kết giới cứu được. Được cứu thì
## vẫn kẹt trong trận (không bị tế nữa), phải bước lên trận truyền tống nhỏ trong
## trận (đệm lò xo) để bật ra ngoài, hoặc tự đặt đệm lò xo của mình.
## Hình: dựng bằng chính đá của bản đồ: bệ đá tròn vẽ tay (shaders/da_ve_tay, ảnh nen_ve_tay/da_tang.png),
## 4 cột đá KayKit nhuộm đỏ thẫm đầu ngọc đỏ ở góc, kết giới đỏ mờ, trận văn đỏ (2 vòng + sao năm cánh)
## trên bệ, quay nhanh hơn khi có người đang bị tế.

const INNER := 4.2 # mét, cạnh trong của khu tường (nửa cạnh ngoài 2,4 m < GameState.PRISON_KEEP_OUT 2,8 m)
const WALL_HEIGHT := 3.0 # cao hơn tường thường, chỉ đệm lò xo bay qua được
const WALL_THICK := 0.3
const REACH := 1.0 # mét ngoài tường: thợ săn đứng trong khoảng này là nhốt được
const PAD_RADIUS := 0.6
const PAD_OFFSET := 0.9 # tâm đệm cách giữa tù, về phía exit_side
const LAUNCH_UP := 11.0 # m/s, giống đệm lò xo trong bộ bài: đỉnh ~3 m
const LAUNCH_OUT := 4.5 # m/s, rơi xuống cách tường ~3 m
const REUSE_TIME := 0.6
const BushScript = preload("res://Objects/bush.gd") # mip_texture: ảnh có mipmap dùng chung
const DAIS_HEIGHT := 0.2 # bệ đá dưới trận văn
const STONE_TEXTURE := "res://Objects/models/nen_ve_tay/da_tang.png" # cùng ảnh đá tảng của bản đồ
const MOSS_TEXTURE := "res://Objects/models/nen_ve_tay/co_1.png"
const PILLAR_MODEL := "res://Objects/models/kaykit_dungeon/pillar_decorated.obj" # cùng cột động phủ
const PILLAR_TEXTURE := "res://Objects/models/kaykit_dungeon/dungeon_texture.png"

## Hướng đệm lò xo bắn người ra (bản đồ đặt trước add_child, nên hướng về giữa bản đồ).
var exit_side := Vector3(0, 0, 1)

var _label: Label3D
var _seal: Node3D
var _pad: Node3D
var _last_launch := {} # chỉ server: peer_id -> giây
var _has_inmates := false

# Dùng chung cho mọi nhà tù.
static var _wall_material: StandardMaterial3D
static var _pad_mesh: CylinderMesh
static var _seal_mesh: ArrayMesh # trận văn dưới sàn
static var _dais_mesh: CylinderMesh
static var _post_mesh: ArrayMesh # cột đá góc + đầu ngọc đỏ
static var _wall_meshes := {} # kích thước (Vector3) -> BoxMesh, mọi nhà tù chỉ có 2 cỡ tường


func _ready() -> void:
	super()
	add_to_group(GameTypes.GROUP_PRISONS)
	var headless := DisplayServer.get_name() == "headless" # server riêng: chỉ dựng va chạm và đệm
	if not headless:
		_build_shared()
	exit_side = Vector3(exit_side.x, 0, exit_side.z).normalized()
	var reach := INNER + WALL_THICK * 2 + REACH * 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(reach, WALL_HEIGHT, reach)
	shape.shape = box
	shape.position.y = WALL_HEIGHT / 2
	add_child(shape)

	var half := INNER / 2 + WALL_THICK / 2
	var long := INNER + WALL_THICK * 2
	_add_wall(Vector3(0, 0, -half), Vector3(long, WALL_HEIGHT, WALL_THICK))
	_add_wall(Vector3(0, 0, half), Vector3(long, WALL_HEIGHT, WALL_THICK))
	_add_wall(Vector3(-half, 0, 0), Vector3(WALL_THICK, WALL_HEIGHT, INNER))
	_add_wall(Vector3(half, 0, 0), Vector3(WALL_THICK, WALL_HEIGHT, INNER))

	# Đệm lò xo: server cần vị trí (interact_tick, bot tìm group), máy có hình thì vẽ.
	if headless:
		_pad = Node3D.new()
	else:
		var pad_mi := MeshInstance3D.new()
		pad_mi.mesh = _pad_mesh
		pad_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pad = pad_mi
	_pad.position = exit_side * PAD_OFFSET + Vector3(0, 0.12, 0)
	_pad.add_to_group(GameTypes.GROUP_JUMP_PADS)
	add_child(_pad)

	if headless:
		set_process(false)
		return
	var seal := MeshInstance3D.new()
	seal.mesh = _seal_mesh
	seal.position.y = DAIS_HEIGHT + 0.02
	seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(seal)
	_seal = seal
	var dais := MeshInstance3D.new()
	dais.mesh = _dais_mesh
	dais.position.y = DAIS_HEIGHT / 2
	add_child(dais)
	for sx: float in [-half, half]:
		for sz: float in [-half, half]:
			var post := MeshInstance3D.new()
			post.mesh = _post_mesh
			post.position = Vector3(sx, 0, sz)
			add_child(post)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = WALL_HEIGHT + 0.5
	_label.font_size = 48
	add_child(_label)
	_refresh()


func _add_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new() # layer 1 mặc định: chặn mọi nhân vật đi bộ
	body.position = center + Vector3(0, size.y / 2, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	if _wall_material == null: # server riêng: không vẽ
		return
	if not _wall_meshes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = _wall_material
		_wall_meshes[size] = mesh
	var mi := MeshInstance3D.new()
	mi.mesh = _wall_meshes[size]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)


static func _build_shared() -> void:
	if _wall_material:
		return
	_wall_material = StandardMaterial3D.new()
	_wall_material.albedo_color = Color(0.85, 0.1, 0.15, 0.16) # kết giới đỏ mờ nhạt cho thấy pháp trận và người bên trong, camera trên cao vẫn thấy người bên trong
	_wall_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pad_mat := StandardMaterial3D.new() # trận truyền tống: ngọc trắng xanh
	pad_mat.albedo_color = Color(0.6, 0.95, 1.0)
	pad_mat.emission_enabled = true
	pad_mat.emission = Color(0.3, 0.7, 0.8)
	_pad_mesh = CylinderMesh.new()
	_pad_mesh.top_radius = PAD_RADIUS - 0.05
	_pad_mesh.bottom_radius = PAD_RADIUS
	_pad_mesh.height = 0.25
	_pad_mesh.radial_segments = 12
	_pad_mesh.material = pad_mat
	var blood := StandardMaterial3D.new()
	blood.albedo_color = Color(0.9, 0.05, 0.1)
	blood.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zone := INNER / 2 + WALL_THICK + REACH * 0.9 # vòng ngoài kết giới: đứng trong vòng này là nhốt được
	for r: float in [zone, zone - 0.25, INNER * 0.47, INNER * 0.36]:
		var ring := TorusMesh.new()
		ring.inner_radius = r - 0.06
		ring.outer_radius = r
		ring.rings = 32
		ring.ring_segments = 3
		st.append_from(ring, 0, Transform3D(Basis().scaled(Vector3(1, 0.1, 1)), Vector3.ZERO))
	var star_r := INNER * 0.36
	for k in 5: # sao năm cánh: nối đỉnh k với đỉnh k + 2
		var a := TAU * k / 5
		var b := TAU * (k + 2) / 5
		var p1 := Vector3(sin(a), 0, cos(a)) * star_r
		var p2 := Vector3(sin(b), 0, cos(b)) * star_r
		var line := BoxMesh.new()
		line.size = Vector3(0.07, 0.01, p1.distance_to(p2))
		var basis := Basis(Vector3.UP, atan2(p2.x - p1.x, p2.z - p1.z))
		st.append_from(line, 0, Transform3D(basis, (p1 + p2) / 2))
	st.set_material(blood)
	_seal_mesh = st.commit()
	var stone := ShaderMaterial.new() # đá vẽ tay chiếu 3 phía như tảng đá bản đồ
	stone.shader = load("res://Objects/shaders/da_ve_tay.gdshader")
	stone.set_shader_parameter(&"albedo", BushScript.mip_texture(STONE_TEXTURE))
	stone.set_shader_parameter(&"moss", BushScript.mip_texture(MOSS_TEXTURE))
	stone.set_shader_parameter(&"tint", Color(0.72, 0.6, 0.6)) # đá ngả đỏ thẫm
	stone.set_shader_parameter(&"tile", 0.32)
	_dais_mesh = CylinderMesh.new()
	_dais_mesh.top_radius = INNER / 2 + WALL_THICK
	_dais_mesh.bottom_radius = INNER / 2 + WALL_THICK + 0.1
	_dais_mesh.height = DAIS_HEIGHT
	_dais_mesh.radial_segments = 16
	_dais_mesh.rings = 1
	_dais_mesh.material = stone
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_texture = BushScript.mip_texture(PILLAR_TEXTURE)
	pillar_mat.albedo_color = Color(0.7, 0.42, 0.42) # cột động phủ nhuộm đỏ thẫm
	pillar_mat.roughness = 1.0
	var pillar: Mesh = load(PILLAR_MODEL) # khuôn cao 4 m
	var h := (WALL_HEIGHT + 0.2) / 4.0
	var cap := SphereMesh.new()
	cap.radius = 0.2
	cap.height = 0.4
	cap.radial_segments = 8
	cap.rings = 4
	_post_mesh = ArrayMesh.new()
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(pillar, 0, Transform3D(Basis.from_scale(Vector3(0.38, h, 0.38)), Vector3.ZERO))
	st.set_material(pillar_mat)
	st.commit(_post_mesh)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.15, 0.2)
	glow.emission_enabled = true
	glow.emission = Color(0.9, 0.05, 0.1)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(cap, 0, Transform3D(Basis(), Vector3(0, WALL_HEIGHT + 0.4, 0)))
	st.set_material(glow)
	st.commit(_post_mesh)


func _process(delta: float) -> void:
	_seal.rotation.y += delta * (0.8 if _has_inmates else 0.15) # có người đang bị tế thì trận quay nhanh
	if Engine.get_process_frames() % 10 == 0: # chữ đổi theo giây, không cần vẽ lại mỗi frame
		_refresh()


func can_interact(entity: EntityBase) -> bool:
	return entity.is_hunter() or GameTypes.is_active(entity.state)


func interact_tick(users: Array[EntityBase], _delta: float) -> void:
	var pad := Vector2(_pad.global_position.x, _pad.global_position.z)
	var now := Time.get_ticks_msec() / 1000.0
	for e in users:
		if e.is_hunter():
			if GameState.rules.record(e.peer_id).carrying_id != 0:
				GameState.server_imprison(e.peer_id, interactable_id)
		elif e.flat_position().distance_to(pad) <= PAD_RADIUS and now - _last_launch.get(e.peer_id, -10.0) >= REUSE_TIME:
			_last_launch[e.peer_id] = now
			e.server_launch(exit_side * LAUNCH_OUT + Vector3.UP * LAUNCH_UP)


func _inmates() -> Array:
	var rules := GameState.rules
	if rules == null:
		return []
	return rules.players.keys().filter(func(id: int) -> bool:
		var p: PlayerRecord = rules.players[id]
		return p.state == GameTypes.PlayerState.IMPRISONED and p.prison_id == interactable_id)


func _refresh() -> void:
	var inmates := _inmates()
	_has_inmates = not inmates.is_empty()
	var text := "Huyết trận"
	if _has_inmates:
		var least := INF
		for id: int in inmates:
			least = minf(least, GameState.rules.players[id].prison_time_left)
		text = "Huyết trận: %d người (tế huyết sau %d giây)" % [inmates.size(), ceili(least)]
	if _label.text != text:
		_label.text = text
