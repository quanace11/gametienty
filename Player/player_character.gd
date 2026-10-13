class_name PlayerCharacter
extends EntityBase
## Nhân vật mặc định (3D): di chuyển 8 hướng trên mặt sàn, có trọng lực,
## quay mặt theo hướng chạy, thợ săn chạm là bắt.
## Bản nền: chạm là nhốt luôn. Sau này thay bằng đánh -> DOWNED -> vác -> nhà tù.
## Hình dạng tạm là khối capsule; thay bằng model + AnimationTree sau.

const HUNTER_SPEED := 4.8 # m/s
const ESCAPEE_SPEED := 4.2
const HUNTER_RADIUS := 0.4
const ESCAPEE_RADIUS := 0.32 # người trốn chậm hơn nhưng hitbox nhỏ hơn
const HEIGHT := 1.7
const CATCH_DIST := 0.9
const GRAVITY := 20.0
const TURN_SPEED := 12.0
const LERP_SPEED := 15.0

const HUNTER_COLOR := Color(0.9, 0.25, 0.25)
const ESCAPEE_COLOR := Color(0.3, 0.6, 1.0)
const OUT_COLOR := Color(0.45, 0.45, 0.45)

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _body_mesh: MeshInstance3D
var _material: StandardMaterial3D


func setup(id: int, p_role: GameTypes.Role, p_name: String, pos: Vector3, local: bool) -> void:
	super(id, p_role, p_name, pos, local)
	_target_pos = pos
	collision_layer = 2 # nhân vật
	collision_mask = 1 # chỉ va vào tường/sàn, không chặn nhau
	_build_body()
	if local:
		add_child(load("res://Player/follow_camera.gd").new())


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = _radius()
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position.y = HEIGHT / 2.0 # gốc nhân vật ở dưới chân
	add_child(shape)

	_material = StandardMaterial3D.new()
	_material.albedo_color = HUNTER_COLOR if is_hunter() else ESCAPEE_COLOR
	var mesh := CapsuleMesh.new()
	mesh.radius = _radius()
	mesh.height = HEIGHT
	mesh.material = _material
	_body_mesh = MeshInstance3D.new()
	_body_mesh.mesh = mesh
	_body_mesh.position.y = HEIGHT / 2.0
	add_child(_body_mesh)

	# Mũi nhỏ phía trước để thấy hướng nhìn.
	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.15, 0.15, 0.3)
	nose_mesh.material = _material
	nose.mesh = nose_mesh
	nose.position = Vector3(0, HEIGHT * 0.25, -_radius())
	_body_mesh.add_child(nose)

	var label := Label3D.new()
	label.text = ("▼ " if is_local else "") + display_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = HEIGHT + 0.4
	label.font_size = 48
	label.modulate = Color(1, 0.9, 0.3) if is_local else Color.WHITE
	add_child(label)


func server_move(input: InputSource, delta: float) -> void:
	if is_out():
		velocity = Vector3.ZERO
		return
	var speed := HUNTER_SPEED if is_hunter() else ESCAPEE_SPEED
	var move := input.get_move().limit_length(1.0)
	var dir := Vector3(move.x, 0, move.y).rotated(Vector3.UP, input.get_aim_yaw())
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if dir.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * TURN_SPEED))
	if is_hunter():
		_try_catch()


func _try_catch() -> void:
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e == self or e.is_hunter() or e.is_out():
			continue
		if flat_position().distance_to(e.flat_position()) < CATCH_DIST:
			GameState.server_set_player_state(e.peer_id, GameTypes.PlayerState.IMPRISONED)


func get_snapshot() -> Variant:
	return [position, rotation.y]


func apply_snapshot(data: Variant) -> void:
	_target_pos = data[0]
	_target_yaw = data[1]


func client_update(delta: float) -> void:
	var t := minf(1.0, delta * LERP_SPEED)
	position = position.lerp(_target_pos, t)
	rotation.y = lerp_angle(rotation.y, _target_yaw, t)


func _on_state_changed(new_state: GameTypes.PlayerState) -> void:
	visible = new_state != GameTypes.PlayerState.ESCAPED
	if new_state == GameTypes.PlayerState.IMPRISONED:
		_material.albedo_color = OUT_COLOR


func _radius() -> float:
	return HUNTER_RADIUS if is_hunter() else ESCAPEE_RADIUS
