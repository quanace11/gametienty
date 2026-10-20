extends Interactable
## Bẫy kẹp đặt dưới đất (id = obj_id của MatchRules.placed). Thợ săn dẫm vào
## thì chạy chậm một lúc (người trốn không làm choáng được thợ săn) và bẫy
## biến mất. Thợ săn chỉ thấy bẫy mờ mờ.

const RADIUS := 0.7
const SLOW_TIME := 2.5
const SLOW_FACTOR := 0.5

static var _mesh: CylinderMesh


func _ready() -> void:
	super()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = 1.0
	shape.shape = cyl
	shape.position.y = 0.5
	add_child(shape)
	if DisplayServer.get_name() == "headless":
		return # server riêng: chỉ cần va chạm, không dựng hình
	var mi := MeshInstance3D.new()
	mi.mesh = shared_mesh()
	mi.position.y = 0.04
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if GameState.my_role() == GameTypes.Role.HUNTER:
		mi.transparency = 0.8 # thợ săn khó thấy
	add_child(mi)


## Hình dùng chung mọi bẫy (ItemVisuals lấy trước để dịch sẵn shader).
static func shared_mesh() -> Mesh:
	if _mesh == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.35, 0.38, 0.9)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.metallic = 0.8
		_mesh = CylinderMesh.new()
		_mesh.top_radius = 0.45
		_mesh.bottom_radius = 0.5
		_mesh.height = 0.08
		_mesh.radial_segments = 12
		_mesh.material = mat
	return _mesh


func can_interact(entity: EntityBase) -> bool:
	return entity.is_hunter()


func interact_tick(users: Array[EntityBase], _delta: float) -> void:
	if users.is_empty():
		return
	if GameState.server_remove_placed(interactable_id):
		GameState.server_speed_boost(users[0].peer_id, SLOW_TIME, SLOW_FACTOR)
