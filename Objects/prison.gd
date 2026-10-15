class_name Prison
extends Interactable
## Nhà tù: khu tường cao kín, không có cửa. Thợ săn kéo người trốn tới sát
## tường là nhốt (người bị nhốt bị ném vào giữa). Người bị nhốt mất máu dần
## (MatchConfig.prison_time), hết thì bị đốt chết; chỉ túi máu ném qua tường
## cứu được. Được cứu thì vẫn kẹt trong tường (không bị đốt nữa), phải bước
## lên đệm lò xo trong tù để bật ra ngoài, hoặc tự đặt đệm lò xo của mình.

const INNER := 3.0 # mét, cạnh trong của khu tường
const WALL_HEIGHT := 3.0 # cao hơn tường thường, chỉ đệm lò xo bay qua được
const WALL_THICK := 0.3
const REACH := 1.0 # mét ngoài tường: thợ săn đứng trong khoảng này là nhốt được
const PAD_RADIUS := 0.6
const PAD_OFFSET := 0.9 # tâm đệm cách giữa tù, về phía exit_side
const LAUNCH_UP := 11.0 # m/s, giống đệm lò xo trong bộ bài: đỉnh ~3 m
const LAUNCH_OUT := 4.5 # m/s, rơi xuống cách tường ~3 m
const REUSE_TIME := 0.6

## Hướng đệm lò xo bắn người ra (bản đồ đặt trước add_child, nên hướng về giữa bản đồ).
var exit_side := Vector3(0, 0, 1)

var _label: Label3D
var _pad: Node3D
var _last_launch := {} # chỉ server: peer_id -> giây

# Dùng chung cho mọi nhà tù.
static var _wall_material: StandardMaterial3D
static var _pad_mesh: CylinderMesh
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
	_wall_material.albedo_color = Color(0.55, 0.6, 0.75, 0.55) # hơi trong để camera trên cao vẫn thấy người bên trong
	_wall_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.2, 0.75, 0.95)
	pad_mat.emission_enabled = true
	pad_mat.emission = Color(0.1, 0.4, 0.5)
	_pad_mesh = CylinderMesh.new()
	_pad_mesh.top_radius = PAD_RADIUS - 0.05
	_pad_mesh.bottom_radius = PAD_RADIUS
	_pad_mesh.height = 0.25
	_pad_mesh.radial_segments = 12
	_pad_mesh.material = pad_mat


func _process(_delta: float) -> void:
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
	var text := "Nhà tù"
	if not inmates.is_empty():
		var least := INF
		for id: int in inmates:
			least = minf(least, GameState.rules.players[id].prison_time_left)
		text = "Nhà tù: %d người (cháy sau %d giây)" % [inmates.size(), ceili(least)]
	if _label.text != text:
		_label.text = text
