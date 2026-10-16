extends Interactable
## Đệm lò xo (id = obj_id). Người trốn bước lên là bị hất về phía trước, đủ
## cao để bay qua tường nhà tù.

const RADIUS := 0.6
const LAUNCH_UP := 11.0 # m/s, đỉnh ~3 m với trọng lực 20
const LAUNCH_FORWARD := 4.0 # m/s
const REUSE_TIME := 0.6 # một người không bị bật liên tục

static var _mesh: CylinderMesh

var _last_launch := {} # chỉ server: peer_id -> giây


func _ready() -> void:
	super()
	add_to_group(GameTypes.GROUP_JUMP_PADS)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = 1.0
	shape.shape = cyl
	shape.position.y = 0.5
	add_child(shape)
	if DisplayServer.get_name() == "headless":
		return # server riêng: chỉ cần va chạm, không dựng hình
	if _mesh == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.75, 0.95)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.4, 0.5)
		_mesh = CylinderMesh.new()
		_mesh.top_radius = 0.55
		_mesh.bottom_radius = 0.6
		_mesh.height = 0.25
		_mesh.radial_segments = 12
		_mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.position.y = 0.12
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func can_interact(entity: EntityBase) -> bool:
	return not entity.is_hunter() and GameTypes.is_active(entity.state)


func interact_tick(users: Array[EntityBase], _delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var forward := Vector3(0, 0, -1).rotated(Vector3.UP, rotation.y)
	for e in users:
		if now - _last_launch.get(e.peer_id, -10.0) < REUSE_TIME:
			continue
		_last_launch[e.peer_id] = now
		e.server_launch(forward * LAUNCH_FORWARD + Vector3.UP * LAUNCH_UP)
