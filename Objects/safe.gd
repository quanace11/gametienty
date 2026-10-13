class_name Safe
extends Interactable
## Két sắt: người trốn đứng sát két để mở. Càng đông mở càng nhanh.
## Chưa có QTE (việc tiếp theo của module Objects).

const UNLOCK_TIME := 4.0 # giây, một người
const SPEED_BY_COUNT := [0.0, 1.0, 1.5, 2.0] # 0, 1, 2, 3+ người
const SIZE := Vector3(1.0, 1.2, 1.0)
const REACH := 0.9 # đứng cách mép két bao xa thì mở được

var _progress := 0.0 # chỉ server dùng
var _material: StandardMaterial3D
var _label: Label3D


func _ready() -> void:
	super()
	add_to_group(GameTypes.GROUP_SAFES)

	var area_shape := CollisionShape3D.new()
	var area_box := BoxShape3D.new()
	area_box.size = SIZE + Vector3(REACH * 2, 1.0, REACH * 2)
	area_shape.shape = area_box
	area_shape.position.y = SIZE.y / 2
	add_child(area_shape)

	# Thân két chắn đường như tường.
	var body := StaticBody3D.new()
	var body_shape := CollisionShape3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = SIZE
	body_shape.shape = body_box
	body_shape.position.y = SIZE.y / 2
	body.add_child(body_shape)
	add_child(body)

	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.85, 0.7, 0.2)
	var mesh := BoxMesh.new()
	mesh.size = SIZE
	mesh.material = _material
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = SIZE.y / 2
	add_child(mi)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = SIZE.y + 0.5
	_label.font_size = 48
	add_child(_label)

	EventBus.safe_progress_changed.connect(func(id: int, _p: float) -> void:
		if id == interactable_id:
			_refresh())
	_refresh()


func can_interact(entity: EntityBase) -> bool:
	return not entity.is_hunter()


func interact_tick(users: Array[EntityBase], delta: float) -> void:
	if users.is_empty() or _progress >= 1.0:
		return
	var speed: float = SPEED_BY_COUNT[mini(users.size(), SPEED_BY_COUNT.size() - 1)]
	_progress = minf(1.0, _progress + delta / UNLOCK_TIME * speed)
	GameState.server_set_safe_progress(interactable_id, _progress)


func _refresh() -> void:
	var p := 0.0
	if GameState.rules:
		p = GameState.rules.safe_progress.get(interactable_id, 0.0)
	if p >= 1.0:
		_material.albedo_color = Color(0.2, 0.75, 0.35)
		_label.text = "Đã mở"
	else:
		_label.text = "Két %d%%" % roundi(p * 100)
