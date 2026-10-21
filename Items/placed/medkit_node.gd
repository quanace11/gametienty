extends Interactable
## Trận bàn hồi phục nằm chờ (thẻ túi cứu thương, id = obj_id của MatchRules.placed):
## trận bàn ném ra mà lúc rơi không ai trong vùng cần cứu thì nằm chờ PICKUP_TIME
## giây (Items đặt lifetime): đĩa trận lơ lửng xoay, vòng sáng và 5 lá cờ ngũ hành
## nhỏ quanh mép. Người trốn cần cứu / mất máu chạy tới là được cứu ngay, trận
## tan. Thợ săn không dùng được.

const RADIUS := 0.8
const FLAG_SCALE := 0.55
const MedkitMesh = preload("res://Items/medkit_mesh.gd")

static var _ring_mesh: TorusMesh

var _kit: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	super()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = 1.5
	shape.shape = cyl
	shape.position.y = 0.75
	add_child(shape)
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	var ring := MeshInstance3D.new()
	ring.mesh = shared_mesh()
	ring.scale = Vector3(1, 0.2, 1)
	ring.position.y = 0.04
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	for k in MedkitMesh.FLAG_COLORS.size():
		var a := TAU * k / MedkitMesh.FLAG_COLORS.size()
		var flag := MeshInstance3D.new()
		flag.mesh = MedkitMesh.get_flag_mesh(k)
		flag.position = Vector3(sin(a), 0, cos(a)) * RADIUS
		flag.rotation.y = a
		flag.scale = Vector3.ONE * FLAG_SCALE
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flag)
	_kit = MeshInstance3D.new()
	_kit.mesh = MedkitMesh.get_mesh()
	_kit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_kit)


## Vòng sáng dùng chung (ItemVisuals lấy trước để dịch sẵn shader; đĩa và cờ ở MedkitMesh).
static func shared_mesh() -> Mesh:
	if _ring_mesh == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.85, 0.35, 0.8)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = RADIUS - 0.08
		_ring_mesh.outer_radius = RADIUS
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 4
		_ring_mesh.material = m
	return _ring_mesh


## Trận bàn nhún nhẹ và xoay chậm cho dễ thấy.
func _process(delta: float) -> void:
	_t += delta
	_kit.position.y = 0.35 + 0.08 * sin(_t * 4.0)
	_kit.rotation.y = _t * 1.5


func can_interact(entity: EntityBase) -> bool:
	return not entity.is_hunter()


func interact_tick(users: Array[EntityBase], _delta: float) -> void:
	if users.is_empty():
		return
	var rules := GameState.rules
	var info: Dictionary = rules.placed.get(interactable_id, {})
	var owner_id: int = info.get("owner", 0)
	var healed := false
	for e in users:
		if rules.can_heal(owner_id, e.peer_id):
			healed = GameState.server_heal(owner_id, e.peer_id) or healed
		elif rules.can_heal(e.peer_id, e.peer_id): # người ném đang gục / bị nhốt: tự dùng
			healed = GameState.server_heal(e.peer_id, e.peer_id) or healed
	if healed:
		GameState.server_remove_placed(interactable_id)
