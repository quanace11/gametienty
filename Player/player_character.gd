class_name PlayerCharacter
extends EntityBase
## Nhân vật mặc định (3D): di chuyển 8 hướng trên mặt sàn, có trọng lực,
## quay mặt theo hướng chạy.
## Nút tương tác (E/Space): thợ săn túm người đang gục (kéo lê phía sau) hoặc
## bắn cối (tự nhắm người gần nhất phía trước, ngắm đón đầu); người trốn giữ
## để đỡ đồng đội đang gục.
## Nút thẻ đạo cụ (skill_1..4) do Core + Items xử lý, file này chỉ lo bị hất
## tung (server_launch) khi giẫm đệm lò xo.
## Mọi quyết định đúng/sai nằm ở GameState; file này chỉ chọn điểm ngắm và vị trí.
## Hình dạng tạm là khối capsule; thay bằng model + AnimationTree sau.

const HUNTER_SPEED := 4.8 # m/s
const ESCAPEE_SPEED := 4.2
const HUNTER_RADIUS := 0.4
const ESCAPEE_RADIUS := 0.32 # người trốn chậm hơn nhưng hitbox nhỏ hơn
const HEIGHT := 1.7
const AIM_ANGLE := 150.0 # độ, góc trước mặt để cối tự nhắm người trốn
const BLIND_SHOT_DIST := 6.0 # mét, không ai trong tầm thì bắn thẳng trước mặt
const PICKUP_RANGE := 1.5
const REVIVE_RANGE := 1.5
const DRAG_DISTANCE := 1.1 # mét, người bị kéo nằm sau lưng thợ săn
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
var _air_velocity := Vector3.ZERO # chỉ server: đang bay vì đệm lò xo
var _flying := false

# Hình đạn dùng chung cho mọi nhân vật (đỡ tốn bộ nhớ, đỡ draw call trên điện thoại).
static var _shell_mesh: SphereMesh
static var _bullet_mesh: SphereMesh
static var _marker_mesh: CylinderMesh
static var _blast_material: StandardMaterial3D


func setup(id: int, p_role: GameTypes.Role, p_name: String, pos: Vector3, local: bool) -> void:
	super(id, p_role, p_name, pos, local)
	_target_pos = pos
	collision_layer = 2 # nhân vật
	collision_mask = 1 # chỉ va vào tường/sàn, không chặn nhau
	_build_body()
	EventBus.player_hit.connect(_on_hit)
	EventBus.player_attacked.connect(_on_attacked)
	EventBus.shot_fired.connect(_on_shot_fired)
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
			_follow_carrier(me) # bị khóa hoàn toàn, không nút nào có tác dụng
			return
		GameTypes.PlayerState.IMPRISONED:
			_stay_in_prison(me.prison_id)
			return
		GameTypes.PlayerState.ESCAPED, GameTypes.PlayerState.ELIMINATED:
			velocity = Vector3.ZERO
			return
	if _flying:
		_fly(delta)
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

	if not input.is_pressed(&"interact"):
		return
	if is_hunter():
		_hunter_interact()
	elif GameTypes.is_active(state):
		_escapee_interact(delta)


## Nút tương tác của thợ săn: ưu tiên túm người đang gục, không thì vung đòn.
func _hunter_interact() -> void:
	var downed := _nearest_entity(PICKUP_RANGE, func(e: EntityBase) -> bool:
		return e.state == GameTypes.PlayerState.DOWNED)
	if downed:
		GameState.server_pick_up(peer_id, downed.peer_id)
		return
	var rules := GameState.rules
	if not rules.can_attack(peer_id):
		return
	var cfg := rules.config
	var forward := facing()
	var aim := global_position + forward * BLIND_SHOT_DIST
	var best_d := cfg.mortar_range
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e == self or not rules.is_hittable(e.peer_id):
			continue
		var to := e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and (d < 1.0 or forward.angle_to(to) <= deg_to_rad(AIM_ANGLE / 2.0)):
			best_d = d
			# Đón đầu: đạn cối bay mortar_min_flight + d / mortar_speed giây.
			var flight := cfg.mortar_min_flight + d / cfg.mortar_speed
			aim = e.global_position + Vector3(e.velocity.x, 0.0, e.velocity.z) * flight
	aim.y = 0.0
	if GameState.server_fire_mortar(self, aim) != 0:
		var to_aim := aim - global_position
		if to_aim.length_squared() > 0.01:
			rotation.y = atan2(-to_aim.x, -to_aim.z) # quay mặt về hướng bắn


## Nút tương tác của người trốn: giữ để đỡ đồng đội đang ngã gần đó.
func _escapee_interact(delta: float) -> void:
	var downed := _nearest_entity(REVIVE_RANGE, func(e: EntityBase) -> bool:
		return not e.is_hunter() and e.state == GameTypes.PlayerState.DOWNED)
	if downed:
		GameState.server_channel_rescue(peer_id, downed.peer_id, delta)


func server_launch(v: Vector3) -> void:
	_air_velocity = v
	_flying = true
	collision_mask = 0 # bay qua tường, tới đất mới va chạm lại


## Bay theo đường parabol, chạm đất thì đứng lại bình thường.
func _fly(delta: float) -> void:
	_air_velocity.y -= GRAVITY * delta
	global_position += _air_velocity * delta
	if _air_velocity.y < 0.0 and global_position.y <= 0.05:
		global_position.y = 0.05
		_flying = false
		collision_mask = 1
		velocity = Vector3.ZERO


func _follow_carrier(me: PlayerRecord) -> void:
	velocity = Vector3.ZERO
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e.peer_id == me.carrier_id:
			global_position = e.global_position + e.global_transform.basis.z * DRAG_DISTANCE
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


## Vẽ đạn của chính nhân vật này. Cối: vòng đỏ báo trước chỗ rơi (để người
## trốn kịp né), đạn bay vòng cung rồi nổ. Súng: viên đạn bay thẳng.
func _on_shot_fired(_shot_id: int, kind: GameTypes.ShotKind, owner_id: int, from: Vector3, to: Vector3, flight: float) -> void:
	if owner_id != peer_id:
		return
	_build_shot_meshes()
	var root := get_parent()
	var mortar := kind == GameTypes.ShotKind.MORTAR
	var shot := MeshInstance3D.new()
	shot.mesh = _shell_mesh if mortar else _bullet_mesh
	shot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shot)
	shot.global_position = from
	var end := to + (Vector3(0, 0.2, 0) if mortar else Vector3(0, 1.0, 0))
	var arc := clampf(from.distance_to(end) * 0.4, 1.0, 4.0) if mortar else 0.0
	var tween := shot.create_tween()
	tween.tween_method(func(t: float) -> void:
		shot.global_position = from.lerp(end, t) + Vector3(0, sin(t * PI) * arc, 0), 0.0, 1.0, flight)
	tween.tween_callback(shot.queue_free)
	if not mortar:
		return
	var radius := GameState.rules.shot_radius(kind) if GameState.rules else 1.0
	var marker := MeshInstance3D.new()
	marker.mesh = _marker_mesh
	marker.material_override = _blast_material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.transparency = 0.6
	root.add_child(marker)
	marker.global_position = Vector3(to.x, 0.04, to.z)
	marker.scale = Vector3(radius, 1, radius)
	var mt := marker.create_tween()
	mt.tween_interval(flight)
	mt.tween_property(marker, "transparency", 0.0, 0.05) # nổ: sáng lên rồi tắt
	mt.tween_property(marker, "transparency", 1.0, 0.3)
	mt.tween_callback(marker.queue_free)


static func _build_shot_meshes() -> void:
	if _shell_mesh:
		return
	_blast_material = StandardMaterial3D.new()
	_blast_material.albedo_color = Color(1, 0.35, 0.1)
	_blast_material.emission_enabled = true
	_blast_material.emission = Color(1, 0.35, 0.1)
	_blast_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shell_mesh = SphereMesh.new()
	_shell_mesh.radius = 0.2
	_shell_mesh.height = 0.4
	_shell_mesh.radial_segments = 8
	_shell_mesh.rings = 4
	_shell_mesh.material = _blast_material
	_bullet_mesh = SphereMesh.new()
	_bullet_mesh.radius = 0.08
	_bullet_mesh.height = 0.16
	_bullet_mesh.radial_segments = 6
	_bullet_mesh.rings = 3
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1, 0.95, 0.4)
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bullet_mesh.material = bm
	_marker_mesh = CylinderMesh.new()
	_marker_mesh.top_radius = 1.0
	_marker_mesh.bottom_radius = 1.0
	_marker_mesh.height = 0.03
	_marker_mesh.radial_segments = 20
	_marker_mesh.rings = 1


func _base_color() -> Color:
	return HUNTER_COLOR if is_hunter() else ESCAPEE_COLOR


func _radius() -> float:
	return HUNTER_RADIUS if is_hunter() else ESCAPEE_RADIUS
