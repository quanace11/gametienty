class_name PlayerCharacter
extends EntityBase
## Nhân vật mặc định (3D): di chuyển 8 hướng trên mặt sàn, có trọng lực,
## quay mặt theo hướng chạy.
## Nút tương tác (E/Space): thợ săn nhấc người đang ngã hoặc vung đòn; người trốn
## giữ để đỡ đồng đội đang ngã, bấm liên tục để vùng vẫy khi bị vác.
## Mọi quyết định đúng/sai nằm ở GameState; file này chỉ tính tầm đánh và vị trí.
## Hình dạng tạm là khối capsule; thay bằng model + AnimationTree sau.

const HUNTER_SPEED := 4.8 # m/s
const ESCAPEE_SPEED := 4.2
const HUNTER_RADIUS := 0.4
const ESCAPEE_RADIUS := 0.32 # người trốn chậm hơn nhưng hitbox nhỏ hơn
const HEIGHT := 1.7
const ATTACK_RANGE := 1.6 # mét, tầm đòn trước mặt thợ săn
const ATTACK_ANGLE := 100.0 # độ, góc hình nón đòn đánh
const PICKUP_RANGE := 1.5
const REVIVE_RANGE := 1.5
const STRUGGLE_PER_PRESS := 0.015 # mỗi lần bấm khi bị vác (bấm 8 lần/giây: ~5 giây thoát)
const CARRY_OFFSET := Vector3(0, 1.2, 0)
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
var _interact_was_pressed := false


func setup(id: int, p_role: GameTypes.Role, p_name: String, pos: Vector3, local: bool) -> void:
	super(id, p_role, p_name, pos, local)
	_target_pos = pos
	collision_layer = 2 # nhân vật
	collision_mask = 1 # chỉ va vào tường/sàn, không chặn nhau
	_build_body()
	EventBus.player_hit.connect(_on_hit)
	EventBus.player_attacked.connect(_on_attacked)
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
	var rules := GameState.rules
	var me := rules.record(peer_id)
	match state:
		GameTypes.PlayerState.CARRIED:
			_follow_carrier(me)
			if input.is_pressed(&"interact") and not _interact_was_pressed:
				GameState.server_add_struggle(peer_id, STRUGGLE_PER_PRESS)
			_interact_was_pressed = input.is_pressed(&"interact")
			return
		GameTypes.PlayerState.IMPRISONED:
			_stay_in_prison(me.prison_id)
			return
		GameTypes.PlayerState.ESCAPED, GameTypes.PlayerState.ELIMINATED:
			velocity = Vector3.ZERO
			return

	var speed := (HUNTER_SPEED if is_hunter() else ESCAPEE_SPEED) * rules.speed_factor(peer_id)
	var move := input.get_move().limit_length(1.0)
	var dir := Vector3(move.x, 0, move.y).rotated(Vector3.UP, input.get_aim_yaw())
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if dir.length_squared() > 0.01 and speed > 0.0:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * TURN_SPEED))

	_interact_was_pressed = input.is_pressed(&"interact")
	if not _interact_was_pressed:
		return
	if is_hunter():
		_hunter_interact()
	elif GameTypes.is_active(state):
		_escapee_interact(delta)


## Nút tương tác của thợ săn: ưu tiên nhấc người đang ngã, không thì vung đòn.
func _hunter_interact() -> void:
	var downed := _nearest_entity(PICKUP_RANGE, func(e: EntityBase) -> bool:
		return e.state == GameTypes.PlayerState.DOWNED)
	if downed:
		GameState.server_pick_up(peer_id, downed.peer_id)
		return
	if not GameState.rules.can_attack(peer_id):
		return
	var forward := -global_transform.basis.z
	var targets: Array = []
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e == self or e.is_hunter():
			continue
		var to := e.global_position - global_position
		to.y = 0.0
		var in_cone := to.length() < 0.3 or forward.angle_to(to) <= deg_to_rad(ATTACK_ANGLE / 2.0)
		if to.length() <= ATTACK_RANGE and in_cone:
			targets.append(e.peer_id)
	GameState.server_attack(peer_id, targets)


## Nút tương tác của người trốn: giữ để đỡ đồng đội đang ngã gần đó.
func _escapee_interact(delta: float) -> void:
	var downed := _nearest_entity(REVIVE_RANGE, func(e: EntityBase) -> bool:
		return not e.is_hunter() and e.state == GameTypes.PlayerState.DOWNED)
	if downed:
		GameState.server_channel_rescue(peer_id, downed.peer_id, delta)


func _follow_carrier(me: PlayerRecord) -> void:
	velocity = Vector3.ZERO
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e.peer_id == me.carrier_id:
			global_position = e.global_position + CARRY_OFFSET
			rotation.y = e.rotation.y
			return


func _stay_in_prison(prison_id: int) -> void:
	velocity = Vector3.ZERO
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_PRISONS):
		if node is Interactable and node.interactable_id == prison_id:
			global_position = node.global_position
			return


func _nearest_entity(max_dist: float, filter: Callable) -> EntityBase:
	var best: EntityBase = null
	var best_d := max_dist
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e == self or not filter.call(e):
			continue
		var d := flat_position().distance_to(e.flat_position())
		if d <= best_d:
			best_d = d
			best = e
	return best


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
	visible = new_state != GameTypes.PlayerState.ESCAPED and new_state != GameTypes.PlayerState.ELIMINATED
	var lying := new_state == GameTypes.PlayerState.DOWNED or new_state == GameTypes.PlayerState.CARRIED
	_body_mesh.rotation.x = -PI / 2.0 if lying else 0.0
	_body_mesh.position.y = _radius() if lying else HEIGHT / 2.0
	_material.albedo_color = OUT_COLOR if new_state == GameTypes.PlayerState.IMPRISONED else _base_color()


func _on_hit(id: int, _attacker_id: int, _hp_left: int) -> void:
	if id != peer_id:
		return
	_material.albedo_color = Color.WHITE
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if is_instance_valid(self) and state != GameTypes.PlayerState.IMPRISONED:
			_material.albedo_color = _base_color())


func _on_attacked(attacker_id: int) -> void:
	if attacker_id != peer_id:
		return
	var tween := create_tween()
	tween.tween_property(_body_mesh, "scale", Vector3(1.25, 1.0, 1.25), 0.08)
	tween.tween_property(_body_mesh, "scale", Vector3.ONE, 0.12)


func _base_color() -> Color:
	return HUNTER_COLOR if is_hunter() else ESCAPEE_COLOR


func _radius() -> float:
	return HUNTER_RADIUS if is_hunter() else ESCAPEE_RADIUS
