class_name ExitGate
extends Interactable
## Lối ra (trong code gọi là cổng thoát): sơn môn đá có phong ấn đỏ, khóa cho tới
## khi giải đủ trận linh. Đủ thì cả 2 lối ra rung, phong ấn nháy trong
## MatchConfig.gate_open_delay giây rồi vỡ thành cổng xoáy ngọc. Mở rồi thì đệ
## tử bước vào là thoát.

const SIZE := Vector3(0.8, 3.0, 2.4)
const LOCKED_COLOR := Color(0.9, 0.1, 0.15, 0.6) # phong ấn đỏ
const OPEN_COLOR := Color(0.4, 1.0, 0.85, 0.75) # cổng xoáy ngọc
const FLASH_COLOR := Color(1.0, 0.7, 0.2, 0.7)
const SEAL_Y := 1.25 # tâm phong ấn

var _mesh: MeshInstance3D # phong ấn / cổng xoáy
var _label: Label3D

# Dùng chung cho mọi lối ra: khung sơn môn, phong ấn ba màu (khóa / nháy / mở) đổi bằng material_override.
static var _frame: ArrayMesh
static var _box: CylinderMesh
static var _locked_mat: StandardMaterial3D
static var _flash_mat: StandardMaterial3D
static var _open_mat: StandardMaterial3D


func _ready() -> void:
	super()
	add_to_group(GameTypes.GROUP_EXIT_GATES)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE + Vector3(0.8, 0, 0.4)
	shape.shape = box
	shape.position.y = SIZE.y / 2
	add_child(shape)
	set_process(false) # chỉ chạy lúc cổng đang mở (rung, nháy, đếm giây)
	if DisplayServer.get_name() == "headless": # server riêng: chỉ cần vùng thoát
		return

	_build_shared()
	var frame := MeshInstance3D.new()
	frame.mesh = _frame
	add_child(frame)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _box
	_mesh.material_override = _locked_mat
	_mesh.position.y = SEAL_Y
	_mesh.rotation.z = PI / 2 # mặt tròn quay ra hai phía cổng (trục X)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = SIZE.y + 0.5
	_label.font_size = 48
	_label.text = "Lối ra (phong ấn)"
	add_child(_label)
	EventBus.gate_opening.connect(func(_seconds: float) -> void:
		set_process(true))
	EventBus.gate_opened.connect(func() -> void:
		set_process(false)
		_mesh.material_override = _open_mat
		_mesh.position = Vector3(0, SEAL_Y, 0)
		_label.text = "Lối ra MỞ")
	var rules := GameState.rules
	set_process(rules != null and rules.gate_opening_left > 0.0 and not rules.gate_open)


static func _build_shared() -> void:
	if _box:
		return
	_box = CylinderMesh.new()
	_box.top_radius = SIZE.z * 0.4
	_box.bottom_radius = _box.top_radius
	_box.height = 0.08
	_box.radial_segments = 20
	_box.rings = 1
	_locked_mat = _seal_mat(LOCKED_COLOR)
	_flash_mat = _seal_mat(FLASH_COLOR)
	_open_mat = _seal_mat(OPEN_COLOR)
	RenderWarmup.register(_flash_mat) # đổi màu khi cổng mở
	RenderWarmup.register(_open_mat)
	# Sơn môn: 2 cột đỏ son, xà ngang, mái ngói đen hai tầng.
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.65, 0.12, 0.1)
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color(0.15, 0.17, 0.2)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.75, 0.25)
	var post_h := SIZE.y - 0.4
	var half_w := SIZE.z / 2 - 0.15
	_frame = ArrayMesh.new()
	_add_boxes(_frame, red, [
		[Vector3(0.3, post_h, 0.3), Vector3(0, post_h / 2, -half_w)],
		[Vector3(0.3, post_h, 0.3), Vector3(0, post_h / 2, half_w)],
		[Vector3(0.36, 0.25, SIZE.z + 0.2), Vector3(0, post_h - 0.35, 0)],
	])
	_add_boxes(_frame, roof, [
		[Vector3(SIZE.x + 0.5, 0.18, SIZE.z + 1.0), Vector3(0, post_h + 0.05, 0)],
		[Vector3(SIZE.x + 0.1, 0.22, SIZE.z + 0.4), Vector3(0, post_h + 0.25, 0)],
	])
	_add_boxes(_frame, gold, [
		[Vector3(0.38, 0.12, 0.5), Vector3(0, post_h - 0.35, 0)], # biển hiệu
		[Vector3(0.12, 0.12, SIZE.z + 0.5), Vector3(0, post_h + 0.4, 0)], # nóc
	])


static func _add_boxes(mesh: ArrayMesh, mat: Material, boxes: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b: Array in boxes:
		var box := BoxMesh.new()
		box.size = b[0]
		st.append_from(box, 0, Transform3D(Basis(), b[1]))
	st.set_material(mat)
	st.commit(mesh)


static func _seal_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _process(_delta: float) -> void:
	var rules := GameState.rules
	if rules == null or rules.gate_opening_left <= 0.0 or rules.gate_open:
		set_process(false)
		return
	# Đang mở: phong ấn rung và nháy.
	var t := Time.get_ticks_msec() / 1000.0
	_mesh.material_override = _flash_mat if fmod(t, 0.4) < 0.2 else _locked_mat
	_mesh.position = Vector3(randf_range(-0.05, 0.05), SEAL_Y, randf_range(-0.05, 0.05))
	var text := "Lối ra mở sau %.1f" % rules.gate_opening_left
	if _label.text != text:
		_label.text = text


func can_interact(entity: EntityBase) -> bool:
	return not entity.is_hunter() and GameState.rules.gate_open and GameTypes.is_active(entity.state)


func interact_tick(users: Array[EntityBase], _delta: float) -> void:
	for e in users:
		GameState.server_escape(e.peer_id)
