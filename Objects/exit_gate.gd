class_name ExitGate
extends Interactable
## Cổng thoát: khóa cho tới khi đủ két. Mở rồi thì người trốn bước vào là thoát.

const SIZE := Vector3(0.8, 3.0, 2.4)

var _material: StandardMaterial3D


func _ready() -> void:
	super()
	add_to_group(GameTypes.GROUP_EXIT_GATES)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE + Vector3(0.8, 0, 0.4)
	shape.shape = box
	shape.position.y = SIZE.y / 2
	add_child(shape)

	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.45, 0.15, 0.15)
	var mesh := BoxMesh.new()
	mesh.size = SIZE
	mesh.material = _material
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = SIZE.y / 2
	add_child(mi)
	EventBus.gate_opened.connect(func() -> void: _material.albedo_color = Color(0.2, 0.85, 0.35))


func can_interact(entity: EntityBase) -> bool:
	return not entity.is_hunter() and GameState.rules.gate_open


func interact_tick(users: Array[EntityBase], _delta: float) -> void:
	for e in users:
		GameState.server_set_player_state(e.peer_id, GameTypes.PlayerState.ESCAPED)
