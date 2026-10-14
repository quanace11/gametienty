class_name ExitGate
extends Interactable
## Cổng thoát: khóa cho tới khi đủ chìa khóa. Đủ chìa thì cả 2 cổng rung, nháy
## đèn trong MatchConfig.gate_open_delay giây rồi mở hẳn. Mở rồi thì người
## trốn bước vào là thoát.

const SIZE := Vector3(0.8, 3.0, 2.4)
const LOCKED_COLOR := Color(0.45, 0.15, 0.15)
const OPEN_COLOR := Color(0.2, 0.85, 0.35)
const FLASH_COLOR := Color(1.0, 0.6, 0.1)

var _mesh: MeshInstance3D
var _label: Label3D

# Dùng chung cho mọi cổng: một mesh, ba màu (khóa / nháy / mở) đổi bằng material_override.
static var _box: BoxMesh
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
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _box
	_mesh.material_override = _locked_mat
	_mesh.position.y = SIZE.y / 2
	add_child(_mesh)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = SIZE.y + 0.5
	_label.font_size = 48
	_label.text = "Cổng (khóa)"
	add_child(_label)
	EventBus.gate_opening.connect(func(_seconds: float) -> void:
		set_process(true))
	EventBus.gate_opened.connect(func() -> void:
		set_process(false)
		_mesh.material_override = _open_mat
		_mesh.position = Vector3(0, SIZE.y / 2, 0)
		_label.text = "Cổng MỞ")
	var rules := GameState.rules
	set_process(rules != null and rules.gate_opening_left > 0.0 and not rules.gate_open)


static func _build_shared() -> void:
	if _box:
		return
	_box = BoxMesh.new()
	_box.size = SIZE
	_locked_mat = StandardMaterial3D.new()
	_locked_mat.albedo_color = LOCKED_COLOR
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.albedo_color = FLASH_COLOR
	_open_mat = StandardMaterial3D.new()
	_open_mat.albedo_color = OPEN_COLOR


func _process(_delta: float) -> void:
	var rules := GameState.rules
	if rules == null or rules.gate_opening_left <= 0.0 or rules.gate_open:
		set_process(false)
		return
	# Đang mở: rung và nháy đèn.
	var t := Time.get_ticks_msec() / 1000.0
	_mesh.material_override = _flash_mat if fmod(t, 0.4) < 0.2 else _locked_mat
	_mesh.position = Vector3(randf_range(-0.05, 0.05), SIZE.y / 2, randf_range(-0.05, 0.05))
	var text := "Cổng mở sau %.1f" % rules.gate_opening_left
	if _label.text != text:
		_label.text = text


func can_interact(entity: EntityBase) -> bool:
	return not entity.is_hunter() and GameState.rules.gate_open and GameTypes.is_active(entity.state)


func interact_tick(users: Array[EntityBase], _delta: float) -> void:
	for e in users:
		GameState.server_escape(e.peer_id)
