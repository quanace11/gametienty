class_name PlayerCharacter
extends EntityBase
## Nhân vật mặc định (3D): di chuyển 8 hướng trên mặt sàn, có trọng lực,
## quay mặt theo hướng chạy.
## Nút tương tác (E/Space): thợ săn túm người đang gục (kéo lê phía sau) hoặc
## bắn súng theo đường thẳng (tự nhắm chỗ người gần nhất phía trước đang đứng,
## tường chặn đạn); người trốn giữ để đỡ đồng đội đang gục.
## Nút "shoot" (thả cần ngắm / chuột phải): thợ săn bắn theo hướng đã ngắm.
## Trên máy người chơi, lúc đang ngắm thì vẽ luồng xanh chỉ hướng và tầm bắn
## (dừng ở tường), chỉ máy đó thấy.
## Nút thẻ đạo cụ (skill_1..4) do Core + Items xử lý, file này chỉ lo bị hất
## tung (server_launch) khi giẫm đệm lò xo.
## Mọi quyết định đúng/sai nằm ở GameState; file này chỉ chọn điểm ngắm và vị trí.
## Hình: nhân vật chibi KayKit Adventurers (CC0, Player/models/), thợ săn là
## Rogue trùm đầu cầm nỏ (vòng đỏ dưới chân), người trốn là hiệp sĩ Knight.
## Animation chọn trên mọi máy theo trạng thái + tốc độ, không gửi qua mạng.

const HUNTER_SPEED := 4.8 # m/s
const ESCAPEE_SPEED := 4.5
const HUNTER_RADIUS := 0.4
const ESCAPEE_RADIUS := 0.32 # người trốn chậm hơn nhưng hitbox nhỏ hơn
const HEIGHT := 1.7
const AIM_ANGLE := 150.0 # độ, góc trước mặt để súng tự nhắm người trốn
const BLIND_SHOT_DIST := 6.0 # mét, không ai trong tầm thì bắn thẳng trước mặt
const PICKUP_RANGE := 1.5
const REVIVE_RANGE := 1.5
const DRAG_DISTANCE := 1.1 # mét, người bị kéo nằm sau lưng thợ săn
const GRAVITY := 20.0
const TURN_SPEED := 12.0
const LERP_SPEED := 15.0
const SNAP_DIST := 6.0 # mét, lệch hơn chừng này (dịch chuyển) thì đặt thẳng vị trí
const AIM_MIN := 0.2 # độ dài hướng ngắm tối thiểu để bắn theo tay, ngắn hơn thì tự nhắm
const BEAM_HEIGHT := 1.1 # ngang nòng súng (GameState.SHOT_HEIGHT), để raycast luồng ngắm

const HUNTER_MODEL := "res://Player/models/rogue_hooded.glb"
const ESCAPEE_MODEL := "res://Player/models/knight.glb"
const HUNTER_PROP := "1H_Crossbow" # đồ cầm tay duy nhất được giữ lại (nỏ của thợ săn)
const MODEL_SCALE := 0.72 # model KayKit cao ~2.4 m, thu về ~1.75 m
const LOOP_ANIMS := ["Idle", "Running_A", "Lie_Idle", "Sit_Floor_Idle", "Jump_Idle"]
const RUN_SPEED_MIN := 0.6 # m/s, chậm hơn thì đứng yên
const BLEND := 0.15

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _anim: AnimationPlayer
var _anim_name := ""
var _oneshot_left := 0.0 # đang phát anim một lần (bắn, bị trúng, ném)
var _last_pos := Vector3.ZERO
var _speed := 0.0 # m/s trên mặt sàn, đo từ vị trí (client không có velocity thật)
var _concealed := false # máy này không được thấy (đứng trong bụi cây phe kia)
var _air_velocity := Vector3.ZERO # chỉ server: đang bay vì đệm lò xo
var _flying := false
var _carrier: EntityBase # chỉ server: người đang kéo mình (nhớ lại, khỏi tìm mỗi frame)
var _prison: Node3D # chỉ server: nhà tù đang bị nhốt
var _prison_id := -1

## Chỉ máy người chơi: nguồn input của nhân vật này (LocalInputSource tự gán), để vẽ luồng ngắm.
var aim_input: InputSource
var _beam: Node3D
var _beam_mesh: MeshInstance3D

const ShotFx = preload("res://Player/shot_fx.gd")

# Hình dùng chung cho mọi nhân vật (đỡ tốn bộ nhớ, đỡ draw call trên điện thoại).
static var _shot_fx: ShotFx # tên lửa, đạn, vụ nổ (pool), một node cho cả trận
static var _beam_box: BoxMesh
static var _hunter_ring: TorusMesh


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
	EventBus.item_used.connect(_on_item_used)
	_last_pos = global_position if is_inside_tree() else pos
	set_process(_anim != null or (local and is_hunter())) # animation, luồng ngắm


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = _radius()
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position.y = HEIGHT / 2.0 # gốc nhân vật ở dưới chân
	add_child(shape)

	if DisplayServer.get_name() == "headless": # server riêng không cần hình, chữ
		return
	_build_model()

	var label := Label3D.new()
	label.text = ("▼ " if is_local else "") + display_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = HEIGHT + 0.4
	label.font_size = 48
	label.modulate = Color(1, 0.9, 0.3) if is_local else Color.WHITE
	add_child(label)


func _build_model() -> void:
	var path := HUNTER_MODEL if is_hunter() else ESCAPEE_MODEL
	var model: Node3D = (load(path) as PackedScene).instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE * (1.1 if is_hunter() else 1.0)
	model.rotation.y = PI # model nhìn về +Z, nhân vật nhìn về -Z
	add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		# Vũ khí gắn ở tay (handslot_l/r): ẩn hết, trừ nỏ của thợ săn.
		if mi.get_parent().name.begins_with("handslot") and not (is_hunter() and mi.name == HUNTER_PROP):
			mi.visible = false
	if is_hunter(): # vòng đỏ dưới chân để nhận ra thợ săn từ xa
		if _hunter_ring == null:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1, 0.2, 0.15, 0.8)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_hunter_ring = TorusMesh.new()
			_hunter_ring.inner_radius = 0.5
			_hunter_ring.outer_radius = 0.6
			_hunter_ring.rings = 24
			_hunter_ring.ring_segments = 4
			_hunter_ring.material = m
		var ring := MeshInstance3D.new()
		ring.mesh = _hunter_ring
		ring.scale = Vector3(1, 0.1, 1)
		ring.position.y = 0.05
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim = players[0] as AnimationPlayer
	for anim_name: String in LOOP_ANIMS:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")


func _play(anim_name: String, speed := 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_anim.speed_scale = speed
	if anim_name != _anim_name:
		_anim_name = anim_name
		_anim.play(anim_name, BLEND)


## Phát anim một lần (bắn, bị trúng, ném) rồi quay lại anim theo trạng thái.
func _play_once(anim_name: String, seconds: float) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_oneshot_left = seconds
	_anim_name = ""
	_play(anim_name)


## Mọi máy: chọn anim theo trạng thái và tốc độ đo được.
func _update_anim(delta: float) -> void:
	var flat := global_position - _last_pos
	flat.y = 0.0
	_last_pos = global_position
	if delta > 0.0:
		_speed = lerpf(_speed, flat.length() / delta, minf(1.0, delta * 10.0))
	if _oneshot_left > 0.0:
		_oneshot_left -= delta
		return
	match state:
		GameTypes.PlayerState.DOWNED, GameTypes.PlayerState.CARRIED:
			_play("Lie_Idle")
			return
		GameTypes.PlayerState.IMPRISONED:
			_play("Sit_Floor_Idle")
			return
	if _flying or global_position.y > 0.4:
		_play("Jump_Idle")
	elif _speed > RUN_SPEED_MIN:
		_play("Running_A", clampf(_speed / ESCAPEE_SPEED, 0.6, 1.6))
	else:
		_play("Idle")


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

	if is_hunter() and input.is_pressed(&"shoot"):
		_hunter_shoot(input.get_aim().rotated(-input.get_aim_yaw()))
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
	_hunter_shoot(Vector2.ZERO)


## Thợ săn bắn: `aim` (hướng trên mặt sàn x, z) đủ dài thì bắn theo hướng đó
## hết tầm (tường chặn), không thì tự nhắm người trốn gần nhất phía trước.
func _hunter_shoot(aim_dir: Vector2) -> void:
	var rules := GameState.rules
	if not rules.can_attack(peer_id):
		return
	var cfg := rules.config
	if aim_dir.length() >= AIM_MIN:
		var d := aim_dir.normalized() * cfg.rifle_range
		_fire_at(global_position + Vector3(d.x, 0.0, d.y))
		return
	var forward := facing()
	var aim := global_position + forward * BLIND_SHOT_DIST
	var best_d := cfg.rifle_range
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e == self or not rules.is_hittable(e.peer_id) or not GameState.can_see(peer_id, e.peer_id):
			continue
		var to := e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and (d < 1.0 or forward.angle_to(to) <= deg_to_rad(AIM_ANGLE / 2.0)):
			best_d = d
			# Nhắm vào chỗ người đó đang đứng, không đón đầu: người đang chạy
			# vẫn né được, muốn trúng thì phải tự kéo cần ngắm canh góc.
			aim = e.global_position
	_fire_at(aim)


func _fire_at(aim: Vector3) -> void:
	aim.y = 0.0
	if GameState.server_fire_rifle(self, aim) != 0:
		var to_aim := aim - global_position
		if to_aim.length_squared() > 0.01:
			rotation.y = atan2(-to_aim.x, -to_aim.z) # quay mặt về hướng bắn


## Nút tương tác của người trốn: giữ để đỡ đồng đội đang ngã gần đó.
func _escapee_interact(delta: float) -> void:
	var downed := _nearest_entity(REVIVE_RANGE, func(e: EntityBase) -> bool:
		return not e.is_hunter() and e.state == GameTypes.PlayerState.DOWNED)
	if downed:
		GameState.server_channel_rescue(peer_id, downed.peer_id, delta)


## Máy người chơi (thợ săn): đang kéo cần ngắm thì hiện luồng xanh từ chân tới
## hết tầm, dừng ở tường. Một raycast mỗi frame, chỉ lúc đang ngắm.
func _process(delta: float) -> void:
	if _anim:
		_update_anim(delta)
	if not (is_local and is_hunter()):
		return
	var dir := Vector2.ZERO
	if aim_input is LocalInputSource and GameTypes.is_active(state):
		dir = (aim_input as LocalInputSource).aiming_direction().rotated(-aim_input.get_aim_yaw())
	if dir == Vector2.ZERO or GameState.rules == null:
		if _beam:
			_beam.visible = false
		return
	if _beam == null:
		_build_beam()
	var range_m := GameState.rules.config.rifle_range
	var from := global_position + Vector3(0, BEAM_HEIGHT, 0)
	var to := from + Vector3(dir.x, 0, dir.y) * range_m
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	var length := range_m
	if not hit.is_empty():
		length = Vector2(hit["position"].x - from.x, hit["position"].z - from.z).length()
	_beam.visible = true
	_beam.global_position = global_position + Vector3(0, 0.06, 0)
	_beam.global_rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
	_beam_mesh.scale.z = maxf(length, 0.1)
	_beam_mesh.position.z = -_beam_mesh.scale.z / 2.0


func _build_beam() -> void:
	if _beam_box == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.45, 0.9, 1.0, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_beam_box = BoxMesh.new()
		_beam_box.size = Vector3(GameState.rules.config.rifle_radius * 2.0, 0.04, 1.0)
		_beam_box.material = m
	_beam = Node3D.new()
	_beam.top_level = true
	_beam_mesh = MeshInstance3D.new()
	_beam_mesh.mesh = _beam_box
	_beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.add_child(_beam_mesh)
	add_child(_beam)


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
	if not is_instance_valid(_carrier) or _carrier.peer_id != me.carrier_id:
		_carrier = null
		for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
			if (node as EntityBase).peer_id == me.carrier_id:
				_carrier = node as EntityBase
				break
	if _carrier:
		global_position = _carrier.global_position + _carrier.global_transform.basis.z * DRAG_DISTANCE
		rotation.y = _carrier.rotation.y


func _stay_in_prison(prison_id: int) -> void:
	velocity = Vector3.ZERO
	if not is_instance_valid(_prison) or _prison_id != prison_id:
		_prison = null
		_prison_id = prison_id
		for node in get_tree().get_nodes_in_group(GameTypes.GROUP_PRISONS):
			if node is Interactable and node.interactable_id == prison_id:
				_prison = node as Node3D
				break
	if _prison:
		global_position = _prison.global_position


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
	if position.distance_squared_to(_target_pos) > SNAP_DIST * SNAP_DIST:
		position = _target_pos # dịch chuyển: nhảy luôn, không trượt ngang bản đồ


func client_update(delta: float) -> void:
	var t := minf(1.0, delta * LERP_SPEED)
	position = position.lerp(_target_pos, t)
	rotation.y = lerp_angle(rotation.y, _target_yaw, t)


func _on_state_changed(_new_state: GameTypes.PlayerState) -> void:
	_refresh_visible()
	_oneshot_left = 0.0 # đổi trạng thái (gục, bị nhốt...) thì bỏ anim đang phát dở


func set_concealed(concealed: bool) -> void:
	if concealed != _concealed:
		_concealed = concealed
		_refresh_visible()


func _refresh_visible() -> void:
	visible = not _concealed and state != GameTypes.PlayerState.ESCAPED and state != GameTypes.PlayerState.ELIMINATED


func _on_hit(id: int, _attacker_id: int, _hp_left: int) -> void:
	if id == peer_id and state == GameTypes.PlayerState.IDLE:
		_play_once("Hit_A", 0.4)


func _on_attacked(attacker_id: int) -> void:
	if attacker_id == peer_id:
		_play_once("1H_Ranged_Shoot", 0.45)


func _on_item_used(id: int, _type: GameTypes.ItemType, _target_id: int, _target_pos: Vector3) -> void:
	if id == peer_id and state == GameTypes.PlayerState.IDLE:
		_play_once("Throw", 0.5)


## Vẽ đạn của chính nhân vật này: súng thợ săn bắn tên lửa có lửa đuôi, chạm
## thì nổ; súng lục bắn viên đạn vàng. Hình và pool nằm ở Player/shot_fx.gd,
## dùng chung một node cho cả trận. Server riêng không vẽ gì.
func _on_shot_fired(_shot_id: int, kind: GameTypes.ShotKind, owner_id: int, from: Vector3, to: Vector3, flight: float) -> void:
	if owner_id != peer_id or DisplayServer.get_name() == "headless":
		return
	if not is_instance_valid(_shot_fx):
		_shot_fx = ShotFx.new()
		get_parent().add_child(_shot_fx)
	_shot_fx.fire(kind, owner_id, from, to, flight)


func _radius() -> float:
	return HUNTER_RADIUS if is_hunter() else ESCAPEE_RADIUS
