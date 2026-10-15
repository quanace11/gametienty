extends Interactable
## Túi cứu thương nằm dưới đất (id = obj_id của MatchRules.placed): túi ném ra
## mà lúc rơi không ai trong vùng cần cứu thì nằm chờ PICKUP_TIME giây (Items
## đặt lifetime). Người trốn cần cứu / mất máu chạy tới đón là được cứu ngay,
## túi biến mất. Thợ săn không nhặt được.

const RADIUS := 0.8
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
	if _ring_mesh == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.35, 1.0, 0.45, 0.7)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = RADIUS - 0.08
		_ring_mesh.outer_radius = RADIUS
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 4
		_ring_mesh.material = m
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.scale = Vector3(1, 0.2, 1)
	ring.position.y = 0.04
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_kit = MeshInstance3D.new()
	_kit.mesh = MedkitMesh.get_mesh()
	_kit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_kit)


## Túi nhún nhẹ và xoay chậm cho dễ thấy.
func _process(delta: float) -> void:
	_t += delta
	_kit.position.y = 0.3 + 0.08 * sin(_t * 4.0)
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
