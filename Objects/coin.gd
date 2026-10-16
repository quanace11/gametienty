class_name Coin
extends Interactable
## Linh thạch trên sàn (trong code gọi là tiền / coin): đệ tử chạm vào là nhặt. interactable_id là id
## cọc trong MatchRules.coins (rải sẵn: 0, 1, 2...; văng từ rương: xem
## MatchRules.chest_coin_ids). Nhặt rồi thì ẩn trên mọi máy.

const RADIUS := 0.6

static var _shared_mesh: SphereMesh # mọi viên linh thạch dùng chung một mesh + material

var _mesh: MeshInstance3D


func _ready() -> void:
	super()
	add_to_group(GameTypes.GROUP_COINS)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	shape.position.y = 0.4
	add_child(shape)
	EventBus.coin_taken.connect(func(coin_id: int, _by: int) -> void:
		if coin_id == interactable_id:
			queue_free())
	if DisplayServer.get_name() == "headless": # server riêng: không hình, không quay
		set_process(false)
		return

	if _shared_mesh == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.95, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.15, 0.5, 0.6)
		_shared_mesh = SphereMesh.new() # cầu 4 múi, 2 tầng = viên tinh thể hình thoi
		_shared_mesh.radius = 0.16
		_shared_mesh.height = 0.45
		_shared_mesh.radial_segments = 4
		_shared_mesh.rings = 2
		_shared_mesh.material = mat
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _shared_mesh
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.position.y = 0.35
	add_child(_mesh)


func _process(delta: float) -> void:
	_mesh.rotate_y(delta * 2.5)


func can_interact(entity: EntityBase) -> bool:
	return not entity.is_hunter() and GameTypes.is_active(entity.state)


func interact_tick(users: Array[EntityBase], _delta: float) -> void:
	if not users.is_empty():
		GameState.server_take_coin(users[0].peer_id, interactable_id)
