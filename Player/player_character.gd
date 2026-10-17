class_name PlayerCharacter
extends EntityBase
## Nhân vật mặc định (3D): di chuyển 8 hướng trên mặt sàn, có trọng lực,
## quay mặt theo hướng chạy.
## Nút tương tác (E/Space): thợ săn túm người đang gục (kéo lê phía sau) hoặc
## bắn súng theo đường thẳng (tự nhắm chỗ người gần nhất phía trước đang đứng,
## tường chặn đạn); người trốn giữ để đỡ đồng đội đang gục.
## Nút "shoot" (thả cần ngắm / chuột phải): thợ săn bắn theo hướng đã ngắm.
## Trên máy người chơi, lúc đang ngắm thì vẽ luồng tím chỉ hướng và tầm phi kiếm
## (dừng ở tường), chỉ máy đó thấy.
## Nút thẻ đạo cụ (skill_1..4) do Core + Items xử lý, file này chỉ lo bị hất
## tung (server_launch) khi giẫm đệm lò xo.
## Mọi quyết định đúng/sai nằm ở GameState; file này chỉ chọn điểm ngắm và vị trí.
## Hình: mô hình ma tu (áo đen đỏ, tóc đỏ, cầm kiếm) và đệ tử (áo trắng, búi
## tóc) của dự án, 3 mức chi tiết theo cài đặt đồ họa. Mô hình có khung xương
## người 17 xương (gắn tự động); động tác tính bằng code (_pose_bones): bước chân,
## đánh tay, gập gối, cúi cạy rương, ngồi, nằm, vung tay phóng kiếm. Cả người
## nghiêng / nhún / nằm thêm bằng _apply_pose. Ma tu có ma khí tím đỏ dưới chân
## và 3 phi kiếm sau lưng, một nửa đệ tử có cánh lửa.
## Tư thế chọn trên mọi máy theo trạng thái + tốc độ, không gửi qua mạng.
## Hình (model, tên, vòng đỏ) nằm trong một node riêng, mỗi frame vẽ được nội
## suy giữa hai lần tính vật lý (60 lần/giây) nên màn hình 90/120 Hz hay FPS
## lệch nhịp vẫn mượt, không giật / xé hình khi chạy. Camera bám theo hình này.

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

# Mô hình ma tu / đệ tử của dự án, 3 mức chi tiết theo cài đặt đồ họa
# (ProjectSettings "game/graphics_quality": 0 Thấp, 1 Vừa, 2 Cao; UI ghi lúc mở game).
# Tam giác: Thấp ~4,5k, Vừa ~10k, Cao ~31k. Gốc ở chân, cao 1 đơn vị, nhìn về +Z.
const MODELS := {
	true: ["res://Player/models/ma_tu_thap.glb", "res://Player/models/ma_tu_vua.glb", "res://Player/models/ma_tu_cao.glb"],
	false: ["res://Player/models/de_tu_thap.glb", "res://Player/models/de_tu_vua.glb", "res://Player/models/de_tu_cao.glb"],
}
const QUALITY_SETTING := "game/graphics_quality"
const HUNTER_TALL := 2.05 # mét (mô hình ma tu xòe tay, cầm kiếm)
const ESCAPEE_TALL := 1.9
const HALO_SWORDS := 3 # phi kiếm lơ lửng sau lưng ma tu
const RUN_SPEED_MIN := 0.6 # m/s, chậm hơn thì đứng yên
const POSE_SPEED := 10.0 # tư thế cả người đổi mượt theo tốc độ này
const BONE_SPEED := 18.0 # góc từng xương đuổi theo góc đích (bước chạy cần nhanh)
# Xương do tools rig gắn vào mô hình (tên trong .glb). Góc xương tính theo độ,
# trục của mô hình: X dương = bên trái nhân vật, Z dương = trước mặt.
# Xoay quanh X góc âm: chân / tay đang buông đưa ra trước; dương: ra sau.
# Xoay quanh Z góc dương: tay trái dang ra; tay phải thì góc âm.
const BONES: Array[String] = ["hips", "spine", "chest", "neck", "head",
	"upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r",
	"thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
enum Bone { HIPS, SPINE, CHEST, NECK, HEAD, UPPER_ARM_L, FOREARM_L, HAND_L, UPPER_ARM_R,
	FOREARM_R, HAND_R, THIGH_L, SHIN_L, FOOT_L, THIGH_R, SHIN_R, FOOT_R }
const RUN_CADENCE := 11.5 # radian / giây ở tốc độ chạy chuẩn: ~1,8 chu kỳ (3,7 bước) mỗi giây
const LEG := 0.21 # chiều dài đùi = cẳng chân, theo chiều cao 1, mặc định trước khi đọc khung xương
# Dáng chạy: mỗi bàn chân đi theo quỹ đạo (chạm đất trượt lùi đúng tốc độ chạy, rồi
# nhấc lên vòng ra trước); góc đùi / gối tính ngược từ chỗ bàn chân (IK hai đoạn) nên
# gối luôn gập về trước, bàn chân dẫm đất không trượt. Đơn vị theo chiều cao 1.
const GAIT_DUTY_RUN := 0.34 # phần chu kỳ bàn chân chạm đất khi chạy nhanh
const GAIT_DUTY_WALK := 0.6 # ... khi đi chậm
const STEP_LIFT := 0.19 # bàn chân nhấc cao nhất (gót đá lên gần mông khi chạy)
const STANCE_MAX := 0.26 # quãng bàn chân trượt lùi khi chống, dài nhất chân với tới (hông cao 0,42)
const STANCE_WALK := 0.34 # ... khi đi bộ: chân gần thẳng, bàn chân trước - sau đều nhau nên với xa hơn
const WALK_FULL := 2.0 # m/s, chậm hơn thì đi bộ hẳn (đẩy cần điều khiển ít, bị làm chậm)
const RUN_FULL := 4.0 # m/s, nhanh hơn thì chạy hẳn; ở giữa trộn dần
const GAIT_DUTY_MIN := 0.2 # chạy nhanh: chống ngắn, bay dài như người chạy nước rút
const RUN_DROP := 0.012 # hông hạ thấp khi chạy (gối hơi chùng)
const RUN_BOB := 0.022 # hông nhún thêm lúc dồn lực lên một chân
const FOOT_TOE := 0.09 # từ mắt cá tới đầu ngón / gót (chiều cao 1)
const FOOT_HEEL := 0.025
const CROUCH_DROP := 0.13 # hông hạ khi ngồi xổm cạy rương
# Chuỗi xương phụ trong mô hình (Player/tools/rig): tên chuỗi, độ cứng, lực cản,
# trọng lực. Cứng thấp, cản thấp thì bay theo quán tính nhiều, lắc lâu.
const SPRING_CHAINS := [
	["hair", 2.0, 0.5, 0.4],
	["sleeve_l", 3.5, 0.4, 0.5],
	["sleeve_r", 3.5, 0.4, 0.5],
	["skirt_b", 1.4, 0.5, 0.2],
]
const CHEST_CHECK := 0.1 # giây giữa hai lần xem có đứng ở rương không
const HIT_FLASH_TIME := 0.18 # giây người bị trúng chớp đỏ

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _pose_node: Node3D # khung giữa _visual và _model: nghiêng, nhún, nằm
var _model: Node3D
var _skeleton: Skeleton3D # null nếu mô hình không có xương
var _bone_ids := PackedInt32Array() # chỉ số xương trong _skeleton, theo thứ tự BONES
var _springs: SpringBoneSimulator3D # tóc, tay áo, vạt áo đung đưa; null nếu mô hình không có
var _bone_now: Array[Vector3] = [] # góc đang hiện (độ)
var _bone_goal: Array[Vector3] = [] # góc đích frame này (độ); Array để g bên dưới là tham chiếu, không chép
var _tall := 1.0 # mét, chiều cao mô hình
var _hip_y := 0.48 # khớp háng, đùi, cẳng chân, mắt cá theo khung xương (chiều cao 1)
var _thigh_len := LEG
var _shin_len := LEG
var _ankle_y := 0.06
var _leg_splay := Vector2.ZERO # độ, chân trái / phải xòe ra ngoài ở dáng gốc (bàn chân xa hông)
var _hips_rest := Vector3.ZERO
var _hips_drop := 0.0 # hông đang hạ bao nhiêu
var _hips_drop_goal := 0.0
var _fast_legs := false # chân đang theo IK: đặt góc ngay, không làm mượt (khỏi trượt)
var _safes: Array[Node] = [] # rương trên bản đồ (lấy một lần)
var _chest: Node3D # rương đang cạy (đứng yên trong vùng rương chưa mở xong), null = không
var _chest_check_left := 0.0
var _anim_name := "" # tư thế đang theo: Idle, Running_A, Lie_Idle, Sit_Floor_Idle, Jump_Idle, PickUp
var _anim_speed := 1.0
var _oneshot_name := "" # tư thế một lần đang phát (vung kiếm, bị trúng, ném), chồng lên phần thân trên
var _oneshot_left := 0.0
var _oneshot_total := 0.0
var _pose_time := 0.0
var _run_phase := 0.0 # pha bước chạy (radian), cộng dồn theo tốc độ để đổi tốc không giật chân
var _walk := 0.0 # 1: đi bộ, 0: chạy (_update_gait)
var _gait_hz := 1.0 # chu kỳ bước / giây
var _duty := GAIT_DUTY_RUN # phần chu kỳ bàn chân chạm đất
var _last_pos := Vector3.ZERO
var _speed := 0.0 # m/s trên mặt sàn, đo từ vị trí (client không có velocity thật)
var _visual: Node3D # hình, top_level, nội suy theo khung hình (không có trên server riêng)
var _xf_prev := Transform3D.IDENTITY # vị trí ở hai lần tính vật lý gần nhất
var _xf_curr := Transform3D.IDENTITY
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
static var _hunter_mist: CylinderMesh
static var _halo_sword_mesh: ArrayMesh
static var _feather_mesh: ArrayMesh
static var _hit_flash_mat: StandardMaterial3D # phủ đỏ lúc bị trúng, dùng chung

var _body_meshes: Array[MeshInstance3D] = [] # các mảnh thân đang hiện, để phủ chớp đỏ
var _flash_left := 0.0

var _halo: Node3D # phi kiếm sau lưng ma tu (chỉ máy có hình)
var _wings: Array[Node3D] = [] # cánh lửa của đệ tử (một nửa số đệ tử)


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


func _ready() -> void:
	set_process(_visual != null) # hình nội suy, animation, luồng ngắm; server riêng không cần
	set_physics_process(_visual != null)
	_snap_visual()


## Đặt hình đúng chỗ nhân vật, bỏ nội suy (vừa vào trận, dịch chuyển).
func _snap_visual() -> void:
	_xf_curr = global_transform
	_xf_prev = _xf_curr
	if _visual:
		_visual.global_transform = _xf_curr
	_reset_springs()


## Dịch chuyển: tóc / áo bắt đầu lại từ dáng nghỉ, không bị kéo dài cả quãng đường.
func _reset_springs() -> void:
	if is_instance_valid(_springs):
		_springs.reset()


## Chạy sau khi Match đã di chuyển nhân vật trong lần tính vật lý này (node con
## chạy sau node cha): ghi lại vị trí để _process nội suy.
func _physics_process(_delta: float) -> void:
	_xf_prev = _xf_curr
	_xf_curr = global_transform
	if _xf_prev.origin.distance_squared_to(_xf_curr.origin) > SNAP_DIST * SNAP_DIST:
		_xf_prev = _xf_curr # dịch chuyển: nhảy luôn, không trượt ngang bản đồ
		_reset_springs()


## Vị trí đang vẽ trên màn hình (đã nội suy). Camera và luồng ngắm bám theo đây.
func visual_position() -> Vector3:
	return _visual.global_position if _visual else global_position


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
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.top_level = true
	add_child(_visual)
	_build_model()

	var label := Label3D.new()
	label.text = ("▼ " if is_local else "") + display_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = HUNTER_TALL + 0.3
	label.font_size = 48
	label.modulate = Color(1, 0.9, 0.3) if is_local else Color.WHITE
	_visual.add_child(label)


func _build_model() -> void:
	var quality := clampi(int(ProjectSettings.get_setting(QUALITY_SETTING, 0)), 0, 2)
	var model: Node3D = (load(MODELS[is_hunter()][quality]) as PackedScene).instantiate()
	_model = model
	_tall = HUNTER_TALL if is_hunter() else ESCAPEE_TALL
	model.scale = Vector3.ONE * _tall
	_find_bones(model)
	model.rotation.y = PI # model nhìn về +Z, nhân vật nhìn về -Z
	_pose_node = Node3D.new()
	_visual.add_child(_pose_node)
	_pose_node.add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		_body_meshes.append(node as MeshInstance3D)
	if is_hunter():
		_add_sword_halo()
	elif absi(peer_id) % 2 == 0:
		_add_flame_wings()
	if is_hunter(): # ma khí tím đỏ dưới chân để nhận ra ma tu từ xa
		if _hunter_ring == null:
			_hunter_ring = TorusMesh.new()
			_hunter_ring.inner_radius = 0.5
			_hunter_ring.outer_radius = 0.6
			_hunter_ring.rings = 24
			_hunter_ring.ring_segments = 4
			_hunter_ring.material = _glow_mat(Color(0.85, 0.15, 0.55, 0.85))
			_hunter_mist = CylinderMesh.new()
			_hunter_mist.top_radius = 0.75
			_hunter_mist.bottom_radius = 0.75
			_hunter_mist.height = 0.02
			_hunter_mist.radial_segments = 24
			_hunter_mist.rings = 1
			_hunter_mist.material = _glow_mat(Color(0.35, 0.05, 0.3, 0.45))
		var ring := MeshInstance3D.new()
		ring.mesh = _hunter_ring
		ring.scale = Vector3(1, 0.1, 1)
		ring.position.y = 0.05
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(ring)
		var mist := MeshInstance3D.new()
		mist.mesh = _hunter_mist
		mist.position.y = 0.03
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(mist)
	_play("Idle")


func _find_bones(model: Node3D) -> void:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	var skeleton := found[0] as Skeleton3D
	for bone_name in BONES:
		var i := skeleton.find_bone(bone_name)
		if i < 0:
			push_warning("Mô hình thiếu xương %s, chỉ cử động cả người" % bone_name)
			_bone_ids.clear()
			return
		_bone_ids.append(i)
	_skeleton = skeleton
	var hip := skeleton.get_bone_global_rest(_bone_ids[Bone.THIGH_L]).origin
	var knee := skeleton.get_bone_global_rest(_bone_ids[Bone.SHIN_L]).origin
	var ankle := skeleton.get_bone_global_rest(_bone_ids[Bone.FOOT_L]).origin
	_hip_y = hip.y
	_thigh_len = Vector2(knee.y - hip.y, knee.z - hip.z).length()
	_shin_len = Vector2(ankle.y - knee.y, ankle.z - knee.z).length()
	_ankle_y = ankle.y
	for side in 2: # dáng gốc đứng dạng chân: đo để khi bước khép bàn chân về dưới hông
		var h := skeleton.get_bone_global_rest(_bone_ids[Bone.THIGH_L + 3 * side]).origin
		var f := skeleton.get_bone_global_rest(_bone_ids[Bone.FOOT_L + 3 * side]).origin
		_leg_splay[side] = rad_to_deg(atan2(f.x - h.x, h.y - f.y))
	_hips_rest = skeleton.get_bone_rest(_bone_ids[Bone.HIPS]).origin
	_bone_now.resize(BONES.size())
	_bone_goal.resize(BONES.size())
	_bone_now.fill(Vector3.ZERO)
	_add_springs(skeleton)


## Tóc, tay áo, vạt áo theo lò xo (SpringBoneSimulator3D của Godot, chạy C++):
## đứng yên thì giữ nguyên dáng, chạy / quay người thì văng theo quán tính rồi lắc về.
func _add_springs(skeleton: Skeleton3D) -> void:
	var sim := SpringBoneSimulator3D.new()
	for c: Array in SPRING_CHAINS:
		var first := skeleton.find_bone("%s_1" % c[0])
		if first < 0:
			continue
		var last := first
		var k := 2
		while skeleton.find_bone("%s_%d" % [c[0], k]) >= 0:
			last = skeleton.find_bone("%s_%d" % [c[0], k])
			k += 1
		var i := sim.setting_count
		sim.setting_count = i + 1
		sim.set_root_bone(i, first)
		sim.set_end_bone(i, last)
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT)
		sim.set_end_bone_length(i, skeleton.get_bone_rest(last).origin.length())
		sim.set_stiffness(i, c[1])
		sim.set_drag(i, c[2])
		sim.set_gravity(i, c[3])
	if sim.setting_count == 0:
		sim.free()
		return
	skeleton.add_child(sim)
	_springs = sim


## Cánh lửa: mỗi bên 4 lông vũ lửa xòe ra sau lưng, vỗ nhẹ. Gắn vào hình nhân vật
## (không theo xương) cho đơn giản; nhân vật nhìn về -Z nên sau lưng là +Z.
func _add_flame_wings() -> void:
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(0.12 * side, 1.05, 0.22)
		_pose_node.add_child(wing)
		for k in 4:
			var f := MeshInstance3D.new()
			f.mesh = _feather()
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			f.rotation = Vector3(0.3, 0.0, -side * (0.5 + 0.3 * k))
			f.scale = Vector3.ONE * (0.85 - 0.1 * k)
			wing.add_child(f)
		_wings.append(wing)


## Ma tu: 3 thanh phi kiếm lơ lửng xòe hình quạt sau lưng, mũi chĩa lên.
func _add_sword_halo() -> void:
	_halo = Node3D.new()
	_halo.position = Vector3(0, 1.35, 0.42) # sau lưng (nhân vật nhìn về -Z)
	_pose_node.add_child(_halo)
	for k in HALO_SWORDS:
		var mi := MeshInstance3D.new()
		mi.mesh = _halo_sword()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := (k - (HALO_SWORDS - 1) / 2.0) * 0.55
		mi.position = Vector3(sin(a) * 0.55, cos(a) * 0.35, 0)
		mi.rotation.z = -a
		_halo.add_child(mi)


## Phi kiếm sau lưng / cánh lửa: lơ lửng, vỗ nhẹ (chỉ đổi transform vài node).
func _animate_aura() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if _halo:
		for k in _halo.get_child_count():
			var c := _halo.get_child(k) as Node3D
			c.position.y = cos((k - 1) * 0.55) * 0.35 + 0.06 * sin(t * 2.4 + k * 1.3)
	for k in _wings.size():
		_wings[k].rotation.y = 0.2 * sin(t * 3.0) * (1.0 if k == 0 else -1.0)


static func _halo_sword() -> ArrayMesh:
	if _halo_sword_mesh == null:
		var blade := StandardMaterial3D.new()
		blade.albedo_color = Color(0.55, 0.85, 1.0)
		blade.emission_enabled = true
		blade.emission = Color(0.4, 0.5, 1.0)
		blade.emission_energy_multiplier = 0.9
		var hilt := StandardMaterial3D.new()
		hilt.albedo_color = Color(0.15, 0.1, 0.2)
		var b := BoxMesh.new()
		b.size = Vector3(0.07, 0.5, 0.02)
		var tip := PrismMesh.new()
		tip.size = Vector3(0.07, 0.13, 0.02)
		var guard := BoxMesh.new()
		guard.size = Vector3(0.2, 0.04, 0.04)
		var grip := BoxMesh.new()
		grip.size = Vector3(0.035, 0.16, 0.035)
		_halo_sword_mesh = ArrayMesh.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(b, 0, Transform3D(Basis(), Vector3(0, 0.25, 0)))
		st.append_from(tip, 0, Transform3D(Basis(), Vector3(0, 0.565, 0)))
		st.set_material(blade)
		st.commit(_halo_sword_mesh)
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(guard, 0, Transform3D.IDENTITY)
		st.append_from(grip, 0, Transform3D(Basis(), Vector3(0, -0.1, 0)))
		st.set_material(hilt)
		st.commit(_halo_sword_mesh)
	return _halo_sword_mesh


## Một lông vũ lửa: tam giác dài, gốc vàng tâm cam, tự sáng, hai mặt.
static func _feather() -> ArrayMesh:
	if _feather_mesh == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.55, 0.15)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.35, 0.05)
		m.emission_energy_multiplier = 0.8
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var p := PrismMesh.new() # mũi ở +Y; dời gốc về chỗ gắn
		p.size = Vector3(0.26, 1.15, 0.02)
		_feather_mesh = ArrayMesh.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(p, 0, Transform3D(Basis(), Vector3(0, 0.575, 0)))
		st.set_material(m)
		st.commit(_feather_mesh)
	return _feather_mesh


static func _glow_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _play(anim_name: String, speed := 1.0) -> void:
	_anim_speed = speed
	if anim_name != _anim_name:
		_anim_name = anim_name
		_pose_time = 0.0


## Phát tư thế một lần (vung kiếm, bị trúng, ném) chồng lên tư thế đang có: đang
## chạy thì chân vẫn chạy, chỉ thân trên ra đòn; đứng yên thì bước tới một bước.
func _play_once(anim_name: String, seconds: float) -> void:
	if _pose_node == null:
		return
	_oneshot_name = anim_name
	_oneshot_left = seconds
	_oneshot_total = seconds


## Mọi máy: chọn anim theo trạng thái và tốc độ đo được.
func _update_anim(delta: float) -> void:
	var pos := _visual.global_position
	var flat := pos - _last_pos
	flat.y = 0.0
	_last_pos = pos
	if delta > 0.0:
		_speed = lerpf(_speed, flat.length() / delta, minf(1.0, delta * 10.0))
	_pose_time += delta
	_oneshot_left = maxf(0.0, _oneshot_left - delta)
	match state:
		GameTypes.PlayerState.DOWNED, GameTypes.PlayerState.CARRIED:
			_play("Lie_Idle")
			_apply_pose(delta)
			return
		GameTypes.PlayerState.IMPRISONED:
			_play("Sit_Floor_Idle")
			_apply_pose(delta)
			return
	_chest_check_left -= delta
	if _chest_check_left <= 0.0:
		_chest_check_left = CHEST_CHECK
		_chest = _chest_here()
	_face_chest(delta)
	if _flying or pos.y > 0.4:
		_play("Jump_Idle")
	elif _chest != null:
		_play("PickUp")
	elif _speed > RUN_SPEED_MIN:
		_play("Running_A", clampf(_speed / ESCAPEE_SPEED, 0.6, 1.6))
	else:
		_play("Idle")
	_apply_pose(delta)


## Cả người trong _pose_node: chạy thì chúi về trước, nhún và lắc; gục thì nằm
## ngửa; ngồi / cúi thì hạ thấp cho chân chạm đất; bị trúng thì giật ngửa;
## phóng kiếm / ném thì lao người tới. Tay chân do _pose_bones.
func _apply_pose(delta: float) -> void:
	var t := _pose_time
	if _anim_name == "Running_A":
		_update_gait()
		_run_phase = fmod(_run_phase + delta * TAU * _gait_hz, TAU)
	var pitch := 0.0 # dương: ngửa ra sau, âm: chúi về trước
	var roll := 0.0
	var lift := 0.0
	var squash := 1.0
	match _anim_name:
		"Idle":
			squash = 1.0 + 0.008 * sin(t * 2.2) # thở
		"Running_A":
			pitch = -0.04 # nghiêng người bằng sống lưng, nhún bằng hông (_pose_bones)
			roll = 0.03 * sin(_run_phase)
		"Lie_Idle":
			pitch = PI / 2.0
			lift = 0.18
		"Sit_Floor_Idle":
			pitch = 0.05
			lift = -0.44 * _tall # mông chạm đất
		"Jump_Idle":
			pitch = -0.25
			roll = 0.1 * sin(t * 6.0)
		"PickUp":
			pitch = 0.02 * sin(t * 7.0)
	if _oneshot_left > 0.0 and _oneshot_name == "Hit_A":
		pitch += 0.25 * _oneshot_fade()
	if _skeleton == null: # mô hình không xương: bù bằng cả người
		match _anim_name:
			"Sit_Floor_Idle":
				lift = 0.0
				squash = 0.62
			"PickUp":
				pitch = -0.4
				squash = 0.82
	var w := minf(1.0, delta * POSE_SPEED * (2.0 if _oneshot_left > 0.0 else 1.0))
	var target := Vector3(pitch, 0.0, roll)
	_pose_node.rotation = _pose_node.rotation.lerp(target, w)
	_pose_node.position = _pose_node.position.lerp(Vector3(0, lift, 0), w)
	_pose_node.scale = _pose_node.scale.lerp(Vector3(1.0 + (1.0 - squash) * 0.3, squash, 1.0 + (1.0 - squash) * 0.3), w)
	if _skeleton and _visual.is_visible_in_tree():
		_pose_bones(delta)


## Nhịp bước theo tốc độ. Chạy: nhịp theo RUN_CADENCE, nhanh hơn thì bước dài ra;
## chân không với tới thì chống ngắn lại, bay lâu hơn (không cho bàn chân trượt).
## Đi bộ: bàn chân luôn có một chân chạm đất, bước đủ ngắn để chân gần thẳng, nên
## nhịp tự nhanh lên theo tốc độ thay vì nhảy cóc.
func _update_gait() -> void:
	_walk = 1.0 - clampf((_speed - WALK_FULL) / (RUN_FULL - WALK_FULL), 0.0, 1.0)
	var v := _speed / _tall # tốc độ theo đơn vị mô hình
	var reach := lerpf(STANCE_MAX, STANCE_WALK, _walk)
	_duty = lerpf(GAIT_DUTY_RUN, GAIT_DUTY_WALK, _walk)
	var hz := maxf(RUN_CADENCE * _anim_speed / TAU, 0.1)
	hz = maxf(hz, lerpf(hz, v * _duty / reach, _walk))
	if v * _duty / hz > reach:
		_duty = maxf(GAIT_DUTY_MIN, reach * hz / v)
	_gait_hz = hz


## Góc từng xương theo tư thế đang phát (độ), rồi đuổi mượt và đặt vào khung
## xương. 17 xương, không cấp phát gì mỗi frame.
func _pose_bones(delta: float) -> void:
	var t := _pose_time
	var g := _bone_goal
	g.fill(Vector3.ZERO)
	_hips_drop_goal = 0.0
	_fast_legs = false
	match _anim_name:
		"Idle": # thở; tay đung đưa nhẹ, khuỷu và cổ tay theo sau vai một nhịp
			var b := sin(t * 2.2)
			var sway := sin(t * 1.1)
			var lag := sin(t * 1.1 - 0.8)
			g[Bone.CHEST] = Vector3(1.5 * b, 2.0 * sin(t * 0.5), 0)
			g[Bone.HEAD] = Vector3(-1.0 * b, 6.0 * sin(t * 0.6), 0)
			g[Bone.UPPER_ARM_L] = Vector3(3.0 * sway, 0, 3.0 + 2.0 * b)
			g[Bone.UPPER_ARM_R] = Vector3(-3.0 * sway, 0, -3.0 - 2.0 * b)
			g[Bone.FOREARM_L] = Vector3(-4.0 + 4.0 * lag, 0, 0)
			g[Bone.FOREARM_R] = Vector3(-4.0 - 4.0 * lag, 0, 0)
			g[Bone.HAND_L] = Vector3(6.0 * sin(t * 1.1 - 1.6), 0, 0)
			g[Bone.HAND_R] = Vector3(-6.0 * sin(t * 1.1 - 1.6), 0, 0)
		"Running_A":
			var step := _run_phase
			var s := sin(step)
			var c := cos(step)
			# Chân: IK theo quỹ đạo bàn chân; chân phải lệch nửa chu kỳ.
			var v := _speed / _tall # tốc độ theo đơn vị mô hình
			var duty := _duty
			var half := 0.5 * v * duty / _gait_hz
			var p := step / TAU
			var wk := _walk
			_hips_drop_goal = lerpf(RUN_DROP, 0.004, wk) + RUN_BOB * (1.0 - 0.7 * wk) * (0.5 + 0.5 * cos(TAU * 2.0 * (p - duty * 0.5)))
			var zl := _leg_gait(Bone.THIGH_L, p, duty, half)
			var zr := _leg_gait(Bone.THIGH_R, fmod(p + 0.5, 1.0), duty, half)
			_fast_legs = true
			var swing := (zl - zr) / maxf(2.0 * half, 0.01) # 1: chân trái ở trước, -1: chân phải ở trước
			g[Bone.HIPS] = Vector3(0, 8.0 * swing, 0)
			g[Bone.SPINE] = Vector3(8.0, 0, 3.0 * c) # dương: thân đổ tới (âm là ưỡn ra sau); nghiêng sang chân đang đỡ
			g[Bone.CHEST] = Vector3(0, -13.0 * swing, 0) # vai xoay ngược hông
			g[Bone.NECK] = Vector3(0, 6.0 * swing, 0) # đầu giữ thẳng hướng chạy
			g[Bone.HEAD] = Vector3(6.0 + 2.0 * absf(c), 2.0 * swing, 0)
			# Tay đánh ngược chân, khuỷu gập gần vuông như người chạy; gập thêm khi tay
			# đưa ra trước, cổ tay trễ nhịp nên tay mềm. Góc khuỷu tính từ dáng gốc của
			# từng mô hình: tu sĩ dáng gốc tay trái giơ lên (phải duỗi ra), tay phải buông.
			var lag := step - 0.6
			var fwd_l := maxf(0.0, -sin(lag)) # tay trái đang ra trước
			var fwd_r := maxf(0.0, sin(lag))
			if is_hunter():
				# Ma tu: dáng gốc chìa tay trái thẳng ra trước, khi chạy hạ hẳn xuống cạnh
				# người rồi mới đánh tay (chìa tay ra trước mà chạy trông như đi ngang).
				g[Bone.UPPER_ARM_L] = Vector3(70.0 + 30.0 * swing, 0, 4.0 + 4.0 * absf(s))
				g[Bone.FOREARM_L] = Vector3(-55.0 - 20.0 * fwd_l, 0, 0)
				# Tay cầm kiếm: đánh nhẹ về sau, mũi kiếm chúc xuống, không chĩa ngang.
				g[Bone.UPPER_ARM_R] = Vector3(12.0 - 10.0 * swing, 0, -10.0)
				g[Bone.CHEST].y *= 0.5
			else:
				g[Bone.UPPER_ARM_L] = Vector3(35.0 * swing, 0, 8.0 + 4.0 * absf(s))
				g[Bone.FOREARM_L] = Vector3(45.0 - 20.0 * fwd_l, 0, 0)
				g[Bone.UPPER_ARM_R] = Vector3(-35.0 * swing, 0, -8.0 - 4.0 * absf(s))
				g[Bone.FOREARM_R] = Vector3(-40.0 - 20.0 * fwd_r, 0, 0)
			g[Bone.HAND_L] = Vector3(14.0 * sin(step - 1.3), 0, 0)
			g[Bone.HAND_R] = Vector3(-14.0 * sin(step - 1.3), 0, 0)
			if wk > 0.0: # đi bộ: thân thẳng, tay buông cạnh người đung đưa nhẹ, khuỷu hơi cong
				g[Bone.SPINE] = g[Bone.SPINE].lerp(Vector3(3.0, 0, 1.5 * c), wk)
				g[Bone.CHEST] = g[Bone.CHEST].lerp(Vector3(0, -6.0 * swing, 0), wk)
				g[Bone.NECK] = g[Bone.NECK].lerp(Vector3(0, 3.0 * swing, 0), wk)
				g[Bone.HEAD] = g[Bone.HEAD].lerp(Vector3(3.0, swing, 0), wk)
				g[Bone.HAND_L] *= 1.0 - 0.5 * wk
				g[Bone.HAND_R] *= 1.0 - 0.5 * wk
				if is_hunter():
					g[Bone.UPPER_ARM_L] = g[Bone.UPPER_ARM_L].lerp(Vector3(78.0 + 18.0 * swing, 0, 4.0), wk)
					g[Bone.FOREARM_L] = g[Bone.FOREARM_L].lerp(Vector3(-25.0 - 10.0 * fwd_l, 0, 0), wk)
					g[Bone.UPPER_ARM_R] = g[Bone.UPPER_ARM_R].lerp(Vector3(6.0 - 8.0 * swing, 0, -8.0), wk)
				else:
					g[Bone.UPPER_ARM_L] = g[Bone.UPPER_ARM_L].lerp(Vector3(18.0 * swing, 0, 6.0), wk)
					g[Bone.FOREARM_L] = g[Bone.FOREARM_L].lerp(Vector3(90.0 - 10.0 * fwd_l, 0, 0), wk)
					g[Bone.UPPER_ARM_R] = g[Bone.UPPER_ARM_R].lerp(Vector3(-18.0 * swing, 0, -6.0), wk)
					g[Bone.FOREARM_R] = g[Bone.FOREARM_R].lerp(Vector3(-12.0 - 10.0 * fwd_r, 0, 0), wk)
		"Lie_Idle":
			var b := sin(t * 1.6)
			g[Bone.CHEST] = Vector3(2.0 * b, 0, 0)
			g[Bone.HEAD] = Vector3(-12.0, 15.0, 0)
			g[Bone.UPPER_ARM_L] = Vector3(0, 0, 40.0)
			g[Bone.UPPER_ARM_R] = Vector3(0, 0, -30.0)
			g[Bone.THIGH_L] = Vector3(-30.0, 0, 6.0)
			g[Bone.SHIN_L] = Vector3(55.0, 0, 0)
			g[Bone.THIGH_R] = Vector3(-5.0, 0, -6.0)
		"Sit_Floor_Idle":
			var b := sin(t * 2.0)
			g[Bone.THIGH_L] = Vector3(-80.0, 0, 10.0)
			g[Bone.THIGH_R] = Vector3(-80.0, 0, -10.0)
			g[Bone.SHIN_L] = Vector3(35.0, 0, 0)
			g[Bone.SHIN_R] = Vector3(35.0, 0, 0)
			g[Bone.SPINE] = Vector3(-6.0 + 2.0 * b, 0, 0)
			g[Bone.HEAD] = Vector3(14.0, 0, 0) # cúi đầu buồn
			g[Bone.UPPER_ARM_L] = Vector3(-20.0, 0, 8.0)
			g[Bone.UPPER_ARM_R] = Vector3(-20.0, 0, -8.0)
		"Jump_Idle":
			g[Bone.THIGH_L] = Vector3(-50.0, 0, 0)
			g[Bone.SHIN_L] = Vector3(75.0, 0, 0)
			g[Bone.THIGH_R] = Vector3(-15.0, 0, 0)
			g[Bone.SHIN_R] = Vector3(45.0, 0, 0)
			g[Bone.UPPER_ARM_L] = Vector3(0, 0, 45.0 + 8.0 * sin(t * 6.0))
			g[Bone.UPPER_ARM_R] = Vector3(0, 0, -45.0 - 8.0 * sin(t * 6.0))
		"PickUp": # ngồi xổm cạy rương, hai tay mò khóa
			var jiggle := 10.0 * sin(t * 14.0)
			_hips_drop_goal = CROUCH_DROP
			_leg_ik(Bone.THIGH_L, 0.05, 0.0, 0.0, CROUCH_DROP) # bàn chân phẳng trên đất, gối gập ra trước
			_leg_ik(Bone.THIGH_R, -0.02, 0.0, 0.0, CROUCH_DROP)
			g[Bone.THIGH_L].z = 10.0
			g[Bone.THIGH_R].z = -10.0
			g[Bone.SPINE] = Vector3(-18.0, 0, 0)
			g[Bone.CHEST] = Vector3(-10.0, 0, 0)
			g[Bone.HEAD] = Vector3(-8.0, 0, 0)
			g[Bone.UPPER_ARM_L] = Vector3(-45.0, 0, 0)
			g[Bone.UPPER_ARM_R] = Vector3(-50.0, 0, 0)
			g[Bone.FOREARM_L] = Vector3(-15.0 + jiggle, 0, 0)
			g[Bone.FOREARM_R] = Vector3(-35.0 - jiggle, 0, 0)
	if _oneshot_left > 0.0:
		_pose_oneshot(g)
	# Ra đòn: xương đuổi nhanh gấp đôi cho đòn dứt khoát, không bị nhòe.
	var w := minf(1.0, delta * BONE_SPEED * (2.0 if _oneshot_left > 0.0 else 1.0))
	var w_legs := minf(1.0, delta * BONE_SPEED * 3.0) if _fast_legs else w
	for i in _bone_ids.size():
		var now := _bone_now[i].lerp(g[i], w_legs if i >= Bone.THIGH_L else w)
		_bone_now[i] = now
		_skeleton.set_bone_pose_rotation(_bone_ids[i], Quaternion.from_euler(now * (PI / 180.0)))
	_hips_drop = lerpf(_hips_drop, _hips_drop_goal, w_legs)
	_skeleton.set_bone_pose_position(_bone_ids[Bone.HIPS], _hips_rest - Vector3(0, _hips_drop, 0))


## Tư thế một lần chồng lên tư thế nền đã có trong `g`. Vung kiếm / ném: lấy đà
## (tay phải vòng lên sau vai, vai xoay ra sau, tay kia chỉ về trước) rồi quật
## xuống chéo qua người, vai xoay theo, thân đổ tới, tay kia kéo về; giữ một chút
## rồi về tư thế nền. Đứng yên thì bước chân trái tới, chân sau nhón; đang chạy thì
## chân cứ chạy (bước thêm sẽ làm bàn chân trượt).
func _pose_oneshot(g: Array[Vector3]) -> void:
	var p := 1.0 - _oneshot_fade() # 0 → 1 trong lúc phát
	if _oneshot_name == "Hit_A": # giật ngửa, hai tay bật ra, cộng lên tư thế nền
		var k := 1.0 - p
		g[Bone.SPINE] += Vector3(8.0 * k, 0, 0)
		g[Bone.CHEST] += Vector3(18.0 * k, 0, 0)
		g[Bone.HEAD] += Vector3(15.0 * k, 0, 0)
		g[Bone.UPPER_ARM_L] = g[Bone.UPPER_ARM_L].lerp(Vector3(15.0, 0, 30.0), k)
		g[Bone.UPPER_ARM_R] = g[Bone.UPPER_ARM_R].lerp(Vector3(15.0, 0, -30.0), k)
		g[Bone.FOREARM_L] = g[Bone.FOREARM_L].lerp(Vector3(-35.0, 0, 0), k * k) # khuỷu bật theo sau vai
		g[Bone.FOREARM_R] = g[Bone.FOREARM_R].lerp(Vector3(-35.0, 0, 0), k * k)
		g[Bone.HAND_L] += Vector3(20.0 * k, 0, 0)
		g[Bone.HAND_R] += Vector3(20.0 * k, 0, 0)
		return
	var wind := smoothstep(0.0, 0.28, p) # lấy đà
	var strike := smoothstep(0.28, 0.5, p) # quật tới
	var on := wind * (1.0 - smoothstep(0.72, 1.0, p)) # cả đòn, về 0 lúc hết
	var slash := _oneshot_name == "1H_Ranged_Shoot"
	# Tay phải (tay kiếm của ma tu, tay ném của cả hai): [lấy đà, quật tới].
	_blend(g, Bone.UPPER_ARM_R, Vector3(-140.0, 0, -35.0) if slash else Vector3(-150.0, 0, -40.0),
			Vector3(-55.0, 0, 30.0) if slash else Vector3(-70.0, 0, 15.0), strike, on)
	_blend(g, Bone.FOREARM_R, Vector3(-75.0, 0, 0) if slash else Vector3(-95.0, 0, 0),
			Vector3(-10.0, 0, 0) if slash else Vector3(-5.0, 0, 0), strike, on)
	_blend(g, Bone.HAND_R, Vector3(35.0, 0, 0), Vector3(-25.0, 0, 0), strike, on)
	_blend(g, Bone.SPINE, Vector3(-4.0, 0, 0), Vector3(9.0, 0, 0), strike, on)
	_blend(g, Bone.CHEST, Vector3(-4.0, -22.0, 0), Vector3(2.0, 24.0, 0), strike, on) # dương Y: vai phải ra trước
	_blend(g, Bone.NECK, Vector3(-2.0, 14.0, 0), Vector3(-4.0, -16.0, 0), strike, on) # mắt vẫn nhìn theo hướng đánh
	# Tay trái chỉ về phía đánh rồi kéo về cạnh sườn. Dáng gốc ma tu chìa tay trái
	# ra trước, đệ tử thì buông tay và gập khuỷu lên.
	if is_hunter():
		_blend(g, Bone.UPPER_ARM_L, Vector3(-5.0, 0, -5.0), Vector3(75.0, 0, 20.0), strike, on)
		_blend(g, Bone.FOREARM_L, Vector3.ZERO, Vector3(-50.0, 0, 0), strike, on)
	else:
		_blend(g, Bone.UPPER_ARM_L, Vector3(-60.0, 0, 10.0), Vector3(25.0, 0, 15.0), strike, on)
		_blend(g, Bone.FOREARM_L, Vector3(75.0, 0, 0), Vector3(30.0, 0, 0), strike, on)
	if _anim_name != "Idle":
		return
	# Đứng yên: bước chân trái tới theo đòn, hông hạ, chân sau nhón gót.
	var step := strike * on
	var lift := 0.06 * sin(PI * strike) * on # nhấc bàn chân lúc bước
	_hips_drop_goal = 0.03 * step
	_leg_ik(Bone.THIGH_L, 0.16 * step, lift, -10.0 * sin(PI * strike) * on, _hips_drop_goal)
	_leg_ik(Bone.THIGH_R, -0.1 * step, 0.0, 20.0 * step, _hips_drop_goal)
	for i in range(Bone.THIGH_L, Bone.FOOT_R + 1): # vào / ra đòn từ dáng đứng gốc, không giật chân
		g[i] *= on


## g[bone] từ tư thế nền tới tư thế lấy đà `wind_pose` rồi quật tới `strike_pose`
## (theo `strike`), trộn với tư thế nền theo `on`.
static func _blend(g: Array[Vector3], bone: int, wind_pose: Vector3, strike_pose: Vector3, strike: float, on: float) -> void:
	g[bone] = g[bone].lerp(wind_pose.lerp(strike_pose, strike), on)


## Một chân khi chạy, pha `p` (0..1): đoạn đầu (duty) bàn chân dẫm đất trượt lùi từ
## +half tới -half đúng tốc độ thân; đoạn sau nhấc lên vòng ra trước. Bàn chân lăn
## gót - mũi: chạm gót, đè phẳng, nhón mũi đẩy đi, lúc bay mũi chúc rồi hếch lại.
## Đặt góc đùi / cẳng / bàn chân vào _bone_goal; trả về vị trí trước-sau của bàn chân.
func _leg_gait(thigh: int, p: float, duty: float, half: float) -> float:
	var z: float
	var y := 0.0
	var roll: float # độ, dương: mũi chúc xuống
	var front := half * lerpf(0.8, 1.0, _walk) # chạy: chạm đất ngay trước hông, đạp ra sau xa hơn
	var back := -half * lerpf(1.2, 1.0, _walk) # đi: trước - sau đều nhau
	if p < duty:
		var u := p / duty
		z = lerpf(front, back, u)
		roll = -10.0 * (1.0 - u) * (1.0 - u) + 30.0 * u * u * u
	else:
		var u := (p - duty) / (1.0 - duty)
		# Quỹ đạo bàn chân khi bước, theo dáng chạy thật: vừa rời đất thì gót đá lên sát
		# mông (bàn chân còn sau hông, gối đã ra trước), rồi gối kéo cẳng chân vung ra
		# trước, bàn chân hạ xuống ngay trước hông. Nội suy cong qua 4 điểm.
		var lift := STEP_LIFT * clampf(half / 0.12, 0.3, 1.0) * (1.0 - 0.65 * _walk) # đi bộ nhấc chân thấp
		var k0 := Vector2(back, 0.0)
		var k1 := Vector2(back * 0.4, lift)
		var k2 := Vector2(front * 0.9, lift * 0.5)
		var k3 := Vector2(front, 0.0)
		var q: Vector2
		if u < 0.3:
			q = k0.cubic_interpolate(k1, k0 + Vector2(0.0, -lift), k2, u / 0.3)
		elif u < 0.65:
			q = k1.cubic_interpolate(k2, k0, k3, (u - 0.3) / 0.35)
		else:
			q = k2.cubic_interpolate(k3, k1, k3 + Vector2(-0.05, -lift * 0.3), (u - 0.65) / 0.35)
		z = q.x
		y = maxf(0.0, q.y)
		roll = lerpf(30.0, -12.0, smoothstep(0.0, 0.7, u))
	# Lăn bàn chân: mũi chúc xuống thì xoay quanh đầu ngón (mắt cá nhấc lên),
	# mũi hếch lên thì xoay quanh gót, để bàn chân không lún xuống đất.
	var r := deg_to_rad(roll)
	y = maxf(y, FOOT_TOE * sin(r) if roll > 0.0 else FOOT_HEEL * sin(-r))
	_leg_ik(thigh, z, y, roll, _hips_drop_goal)
	return z


## IK hai đoạn (đùi, cẳng chân) trong mặt phẳng trước-sau: mắt cá tới (z, y) với
## y tính từ mặt đất, hông đang hạ `drop`. Gối luôn gập về trước. Bàn chân giữ
## phẳng với đất rồi cộng thêm `roll`.
func _leg_ik(thigh: int, z: float, y: float, roll: float, drop: float) -> void:
	var d := Vector2(z, y + _ankle_y - (_hip_y - drop)) # (trước, lên) từ khớp háng
	var reach := (_thigh_len + _shin_len) * 0.999
	var dist := clampf(d.length(), 0.05, reach)
	var a1 := _thigh_len
	var a2 := _shin_len
	var at_hip := acos(clampf((a1 * a1 + dist * dist - a2 * a2) / (2.0 * a1 * dist), -1.0, 1.0))
	var at_knee := acos(clampf((a1 * a1 + a2 * a2 - dist * dist) / (2.0 * a1 * a2), -1.0, 1.0))
	var thigh_fwd := atan2(d.x, -d.y) + at_hip # góc đùi so với thẳng xuống, dương: ra trước
	var knee := PI - at_knee # gối gập
	var thigh_x := -rad_to_deg(thigh_fwd)
	var shin_x := rad_to_deg(knee)
	# Khép chân: bàn chân bước gần đường giữa, không dạng háng đi ngang như cua.
	var splay := _leg_splay[0 if thigh == Bone.THIGH_L else 1]
	var inward := -splay + (2.0 if thigh == Bone.THIGH_L else -2.0)
	_bone_goal[thigh] = Vector3(thigh_x, 0, inward)
	_bone_goal[thigh + 1] = Vector3(shin_x, 0, 0)
	_bone_goal[thigh + 2] = Vector3(-(thigh_x + shin_x) + roll, 0, 0)


## Tư thế một lần: mạnh nhất lúc đầu rồi nhạt dần về 0.
func _oneshot_fade() -> float:
	return clampf(_oneshot_left / maxf(_oneshot_total, 0.01), 0.0, 1.0)


## Người trốn đang đứng yên trong vùng một rương chưa mở xong (đúng lúc luật
## đang cho cạy, trên mọi máy) thì trả rương đó. Vùng rương do Area3D của rương.
func _chest_here() -> Node3D:
	if is_hunter() or _speed > RUN_SPEED_MIN or not GameTypes.is_active(state) or GameState.rules == null:
		return null
	if _safes.is_empty():
		_safes = get_tree().get_nodes_in_group(GameTypes.GROUP_SAFES)
	for node in _safes:
		var safe := node as Interactable
		if safe and GameState.rules.safe_progress.get(safe.interactable_id, 1.0) < 1.0 and safe.overlaps_body(self):
			return safe
	return null


## Đang cạy thì xoay hình quay mặt vào rương (chỉ hình, không đổi hướng thật).
func _face_chest(delta: float) -> void:
	if _model == null:
		return
	var yaw := PI # model nhìn về +Z
	if _chest:
		var d := _chest.global_position - _visual.global_position
		yaw = PI + atan2(-d.x, -d.z) - _visual.global_rotation.y
	_model.rotation.y = lerp_angle(_model.rotation.y, yaw, minf(1.0, delta * TURN_SPEED))


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


## Mọi máy có màn hình: đặt hình nội suy giữa hai lần tính vật lý.
## Máy người chơi (thợ săn): đang kéo cần ngắm thì hiện luồng xanh từ chân tới
## hết tầm, dừng ở tường. Một raycast mỗi frame, chỉ lúc đang ngắm.
func _process(delta: float) -> void:
	_visual.global_transform = _xf_prev.interpolate_with(_xf_curr, Engine.get_physics_interpolation_fraction())
	if _pose_node:
		_update_anim(delta)
	if _halo or not _wings.is_empty():
		_animate_aura()
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_flash(null)
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
	_beam.global_position = _visual.global_position + Vector3(0, 0.06, 0)
	_beam.global_rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
	_beam_mesh.scale.z = maxf(length, 0.1)
	_beam_mesh.position.z = -_beam_mesh.scale.z / 2.0


func _build_beam() -> void:
	if _beam_box == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.8, 0.45, 1.0, 0.55)
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


## Bị trúng: nổ lửa ngay chỗ mình, thân chớp đỏ, giật người (anim Hit_A).
func _on_hit(id: int, _attacker_id: int, _hp_left: int) -> void:
	if id != peer_id:
		return
	if state == GameTypes.PlayerState.IDLE:
		_play_once("Hit_A", 0.4)
	if _visual == null or not visible:
		return
	if not is_instance_valid(_shot_fx):
		_shot_fx = ShotFx.new()
		get_parent().add_child(_shot_fx)
	_shot_fx.hit_burst(GameTypes.ShotKind.BULLET if is_hunter() else GameTypes.ShotKind.RIFLE, _visual.global_position)
	if _hit_flash_mat == null:
		_hit_flash_mat = StandardMaterial3D.new()
		_hit_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hit_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hit_flash_mat.albedo_color = Color(1.0, 0.15, 0.1, 0.55)
	_set_flash(_hit_flash_mat)
	_flash_left = HIT_FLASH_TIME


func _set_flash(mat: Material) -> void:
	for mi in _body_meshes:
		mi.material_overlay = mat


func _on_attacked(attacker_id: int) -> void:
	if attacker_id == peer_id:
		_play_once("1H_Ranged_Shoot", 0.55)


func _on_item_used(id: int, _type: GameTypes.ItemType, _target_id: int, _target_pos: Vector3) -> void:
	if id == peer_id and state == GameTypes.PlayerState.IDLE:
		_play_once("Throw", 0.55)


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
