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
## Hình: thợ săn là ma tu của dự án, người trốn là Mage của bộ KayKit Adventurers
## (CC0). Cả hai dùng động tác KayKit (ma tu dùng bản đã chuyển sang khung xương
## của nó), đặt thẳng lên khung xương (_pose_bones). Thợ săn có ma khí tím
## đỏ dưới chân để nhận ra từ xa.
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

# Thợ săn: ma tu của dự án (gắn xương AccuRig), mỗi mức đồ họa một tệp
# (ProjectSettings "game/graphics_quality": 0 Thấp ~6k tam giác, 1 Vừa ~20k, 2 Cao ~60k).
# Động tác KayKit đã chuyển sẵn sang khung xương của nó, 18 xương chính mang tên
# KayKit (Player/tools/retarget/). Người trốn: Mage của KayKit Adventurers 1.0
# (Kay Lousberg, CC0, ~6k tam giác, khung xương và 76 động tác). Gốc ở chân, nhìn về +Z.
const MODELS := {
	true: ["res://Player/models/ma_tu/ma_tu_thap.glb", "res://Player/models/ma_tu/ma_tu_vua.glb", "res://Player/models/ma_tu/ma_tu_cao.glb"],
	false: ["res://Player/models/kaykit/Mage.glb"],
}
const QUALITY_SETTING := "game/graphics_quality"
const MODEL_HEIGHT := {true: 1.85, false: 2.2} # đơn vị mô hình, từ chân tới đỉnh đầu (không tính mũ, búi tóc)
const WEAPONS := {true: "1H_Axe", false: ""} # vũ khí cầm tay giữ lại, các món khác trong tệp bỏ đi
const HUNTER_TALL := 2.05 # mét
const ESCAPEE_TALL := 1.9
const LABEL_HEIGHT := 2.7 # mét, tên trên đầu (cao hơn mũ phù thủy)
const RUN_SPEED_MIN := 0.6 # m/s, chậm hơn thì đứng yên
const POSE_SPEED := 10.0 # mô hình không xương: cả người đổi tư thế mượt theo tốc độ này
# Tên động tác trong game -> tên động tác trong tệp. Chỉ Stand và Run bắt buộc; tệp
# thiếu động tác nào thì bỏ qua (ma tu chỉ giữ đứng, chạy, phóng phi kiếm, chém khi
# túm người, kéo người): thiếu Walk thì đi chậm dùng Run, thiếu tư thế nền thì đứng / chạy.
const CLIPS := {
	"Stand": "Idle", "Walk": "Walking_A", "Run": "Running_A",
	"Attack": "Spellcast_Shoot", "Grab": "1H_Melee_Attack_Chop", "Drag": "Drag",
	"Throw": "Throw", "Hit": "Hit_A",
	"Lie": "Lie_Idle", "Sit": "Sit_Floor_Idle", "Jump": "Jump_Idle", "PickUp": "PickUp",
}
# Tốc độ đi / chạy của động tác gốc (đơn vị mô hình mỗi giây, đo theo bàn chân chạm
# đất) và lúc chân trái ra trước nhất (phần chu kỳ), để đi và chạy cùng pha.
# Ma tu cao hơn KayKit nên động tác đã chuyển bước dài hơn theo tỉ lệ chiều cao hông (x2,65).
const CLIP_SPEED := {true: {"Walk": 1.67, "Run": 5.82}, false: {"Walk": 0.63, "Run": 2.2}}
const CLIP_PHASE := {"Walk": 0.84, "Run": 0.0}
const MAX_RATE := 1.8 # phát nhanh nhất chừng này lần tốc độ gốc; nhanh hơn thì chân trượt chút
const BONES: Array[String] = ["hips", "spine", "chest", "head",
	"upperarm.l", "lowerarm.l", "hand.l", "upperarm.r", "lowerarm.r", "hand.r",
	"upperleg.l", "lowerleg.l", "foot.l", "toes.l", "upperleg.r", "lowerleg.r", "foot.r", "toes.r"]
enum Bone { HIPS, SPINE, CHEST, HEAD, UPPER_ARM_L, FOREARM_L, HAND_L,
	UPPER_ARM_R, FOREARM_R, HAND_R, THIGH_L, SHIN_L, FOOT_L, TOES_L,
	THIGH_R, SHIN_R, FOOT_R, TOES_R }
const WALK_TO_RUN := Vector2(2.0, 3.4) # m/s: chậm hơn x thì đi bộ hẳn, nhanh hơn y thì chạy hẳn
const FADE_TIME := 0.2 # giây trộn khi đổi động tác nền (đứng dậy, ngã, nhảy...)
const PICKUP_HOLD := 0.5 # giây trong động tác cúi nhặt lúc ngồi thấp nhất (giữ khi cạy rương)
const ONESHOT_RATE := {"Attack": 1.6, "Grab": 1.6, "Throw": 2.0, "Hit": 1.3}
const DRAG_FADE := 6.0 # tay phải đưa ra sau / thu về khi bắt đầu / thôi kéo người (lần mỗi giây) # phát nhanh hơn gốc cho đòn gọn
const CHEST_CHECK := 0.1 # giây giữa hai lần xem có đứng ở rương không
const HIT_FLASH_TIME := 0.18 # giây người bị trúng chớp đỏ

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _pose_node: Node3D # khung giữa _visual và _model: nghiêng, nhún, nằm
var _model: Node3D
var _skeleton: Skeleton3D # null nếu mô hình không có xương
var _bone_ids := PackedInt32Array() # chỉ số xương trong _skeleton, theo thứ tự BONES
var _tall := 1.0 # mét, chiều cao nhân vật
var _scale := 1.0 # mét mỗi đơn vị mô hình
var _clips := {} # tên động tác -> Animation
var _clip_tracks := {} # tên động tác -> chỉ số track xoay của từng xương theo BONES, rồi track vị trí hông
var _pose_out: Array[Quaternion] = [] # dáng đang hiện (xoay từng xương)
var _pose_from: Array[Quaternion] = [] # dáng lúc bắt đầu đổi động tác nền
var _pose_a: Array[Quaternion] = [] # chỗ tạm để trộn đi / chạy, tư thế một lần
var _pose_b: Array[Quaternion] = []
var _pose_one: Array[Quaternion] = []
var _hips_out := Vector3.ZERO
var _hips_from := Vector3.ZERO
var _fade := 1.0
var _walk_is_run := false # tệp không có Walk: đi chậm dùng Run
var _dragging := false # thợ săn đang kéo người (đọc từ luật, mọi máy)
var _drag_w := 0.0 # độ chồng tư thế kéo lên tay phải (0..1)
var _move_phase := 0.0 # pha bước đi / chạy (0..1), cộng dồn theo quãng đường
var _safes: Array[Node] = [] # rương trên bản đồ (lấy một lần)
var _chest: Node3D # rương đang cạy (đứng yên trong vùng rương chưa mở xong), null = không
var _chest_check_left := 0.0
var _anim_name := "" # động tác nền: Move (đứng / đi / chạy), Lie, Sit, Jump, PickUp
var _oneshot_name := "" # tư thế một lần đang phát (Attack, Throw, Hit), "" = không
var _oneshot_time := 0.0
var _oneshot_length := 0.0
var _pose_time := 0.0
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
static var _hit_flash_mat: StandardMaterial3D # phủ đỏ lúc bị trúng, dùng chung

var _body_meshes: Array[MeshInstance3D] = [] # các mảnh thân đang hiện, để phủ chớp đỏ
var _flash_left := 0.0



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


## Chạy sau khi Match đã di chuyển nhân vật trong lần tính vật lý này (node con
## chạy sau node cha): ghi lại vị trí để _process nội suy.
func _physics_process(_delta: float) -> void:
	_xf_prev = _xf_curr
	_xf_curr = global_transform
	if _xf_prev.origin.distance_squared_to(_xf_curr.origin) > SNAP_DIST * SNAP_DIST:
		_xf_prev = _xf_curr # dịch chuyển: nhảy luôn, không trượt ngang bản đồ


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
	label.position.y = LABEL_HEIGHT
	label.font_size = 48
	label.modulate = Color(1, 0.9, 0.3) if is_local else Color.WHITE
	_visual.add_child(label)


func _build_model() -> void:
	var files: Array = MODELS[is_hunter()]
	var quality := clampi(int(ProjectSettings.get_setting(QUALITY_SETTING, 0)), 0, files.size() - 1)
	var model: Node3D = (load(files[quality]) as PackedScene).instantiate()
	_model = model
	_tall = HUNTER_TALL if is_hunter() else ESCAPEE_TALL
	_scale = _tall / float(MODEL_HEIGHT[is_hunter()])
	model.scale = Vector3.ONE * _scale
	for slot in model.find_children("handslot*", "BoneAttachment3D", true, false):
		for item in slot.get_children():
			if item.name != WEAPONS[is_hunter()]:
				item.free()
	_find_bones(model)
	model.rotation.y = PI # model nhìn về +Z, nhân vật nhìn về -Z
	_pose_node = Node3D.new()
	_visual.add_child(_pose_node)
	_pose_node.add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		_body_meshes.append(node as MeshInstance3D)
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
	_anim_name = "Move"


func _find_bones(model: Node3D) -> void:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	var skeleton := found[0] as Skeleton3D
	var names: Array[String] = [] # tên thật trong tệp: GLB xuất từ Godot đổi "." thành "_" (upperarm_l)
	for bone_name in BONES:
		var i := skeleton.find_bone(bone_name)
		if i < 0:
			bone_name = bone_name.replace(".", "_")
			i = skeleton.find_bone(bone_name)
		names.append(bone_name)
		if i < 0:
			push_warning("Mô hình thiếu xương %s, chỉ cử động cả người" % bone_name)
			_bone_ids.clear()
			return
		_bone_ids.append(i)
	_skeleton = skeleton
	# Động tác nằm sẵn trong AnimationPlayer của tệp. Lấy ra rồi bỏ node đó: tự đặt
	# xương ở _pose_bones để trộn đi / chạy và chồng đòn lên thân trên.
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var skel_path := str(model.get_path_to(skeleton))
	for clip: String in CLIPS:
		if not player.has_animation(CLIPS[clip]):
			continue
		var anim := player.get_animation(CLIPS[clip])
		var tracks := PackedInt32Array()
		for bone_name in names:
			tracks.append(anim.find_track(NodePath("%s:%s" % [skel_path, bone_name]), Animation.TYPE_ROTATION_3D))
		tracks.append(anim.find_track(NodePath("%s:hips" % skel_path), Animation.TYPE_POSITION_3D))
		_clips[clip] = anim
		_clip_tracks[clip] = tracks
	if not _clips.has("Walk"):
		_walk_is_run = true
		_clips["Walk"] = _clips["Run"]
		_clip_tracks["Walk"] = _clip_tracks["Run"]
	for arr: Array[Quaternion] in [_pose_out, _pose_from, _pose_a, _pose_b, _pose_one]:
		arr.resize(BONES.size())
		arr.fill(Quaternion.IDENTITY)
	_hips_out = skeleton.get_bone_rest(_bone_ids[Bone.HIPS]).origin
	player.free()


static func _glow_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Phát tư thế một lần (vung kiếm, ném, bị trúng) chồng lên phần thân trên: chân
## vẫn đứng / đi / chạy theo động tác nền nên không bị trượt.
func _play_once(anim_name: String) -> void:
	if _pose_node == null or not _clips.has(anim_name):
		return
	_oneshot_name = anim_name
	_oneshot_time = 0.0
	_oneshot_length = (_clips[anim_name] as Animation).length / ONESHOT_RATE[anim_name]


## Mọi máy: chọn động tác nền theo trạng thái và tốc độ đo được.
func _update_anim(delta: float) -> void:
	var pos := _visual.global_position
	var flat := pos - _last_pos
	flat.y = 0.0
	_last_pos = pos
	if delta > 0.0:
		_speed = lerpf(_speed, flat.length() / delta, minf(1.0, delta * 10.0))
	_pose_time += delta
	if _oneshot_name != "":
		_oneshot_time += delta
		if _oneshot_time >= _oneshot_length:
			_oneshot_name = ""
	var base := "Move"
	match state:
		GameTypes.PlayerState.DOWNED, GameTypes.PlayerState.CARRIED:
			base = "Lie"
		GameTypes.PlayerState.IMPRISONED:
			base = "Sit"
		_:
			_chest_check_left -= delta
			if _chest_check_left <= 0.0:
				_chest_check_left = CHEST_CHECK
				_chest = _chest_here()
			_face_chest(delta)
			if _flying or pos.y > 0.4:
				base = "Jump"
			elif _chest != null:
				base = "PickUp"
	if not _clips.has(base):
		base = "Move"
	if is_hunter():
		var rec := GameState.rules.record(peer_id) if GameState.rules else null
		var dragging := rec != null and rec.carrying_id != 0
		if dragging and not _dragging:
			_play_once("Grab") # túm người gục
		_dragging = dragging
	_drag_w = move_toward(_drag_w, 1.0 if _dragging else 0.0, delta * DRAG_FADE)
	if base != _anim_name:
		_anim_name = base
		_pose_time = 0.0
		_fade = 0.0 # trộn từ dáng đang hiện sang động tác mới
		_pose_from.assign(_pose_out)
		_hips_from = _hips_out
	if _skeleton and _visual.is_visible_in_tree():
		_pose_bones(delta)
	elif _skeleton == null:
		_pose_whole_body(delta)


## Mô hình không có khung xương: chỉ nghiêng / nằm / hạ cả người.
func _pose_whole_body(delta: float) -> void:
	var pitch := 0.0
	var squash := 1.0
	match _anim_name:
		"Lie":
			pitch = PI / 2.0
		"Sit":
			squash = 0.62
		"PickUp":
			pitch = -0.4
			squash = 0.82
	var w := minf(1.0, delta * POSE_SPEED)
	_pose_node.rotation = _pose_node.rotation.lerp(Vector3(pitch, 0.0, 0.0), w)
	_pose_node.scale = _pose_node.scale.lerp(Vector3(1.0 + (1.0 - squash) * 0.3, squash, 1.0 + (1.0 - squash) * 0.3), w)


## Đặt khung xương theo thư viện động tác. Đi / chạy / đứng trộn theo tốc độ, cùng
## một pha bước (hai động tác đã cắt cho cùng bắt đầu lúc chân trái chạm đất) và
## phát nhanh chậm theo tốc độ thật nên bàn chân không trượt. Đổi động tác nền thì
## trộn từ dáng cũ trong FADE_TIME. Tư thế một lần chồng lên thân trên. Không cấp
## phát gì mỗi frame.
func _pose_bones(delta: float) -> void:
	var t := _pose_time
	match _anim_name:
		"Move":
			_pose_move(delta)
		"PickUp": # ngồi xổm cạy rương: dừng ở lúc cúi thấp nhất
			_hips_out = _sample("PickUp", minf(t, PICKUP_HOLD), _pose_out)
		_:
			var clip := _clips[_anim_name] as Animation
			_hips_out = _sample(_anim_name, fmod(t, clip.length), _pose_out)
	if _fade < 1.0:
		_fade = minf(1.0, _fade + delta / FADE_TIME)
		var k := smoothstep(0.0, 1.0, _fade)
		for i in BONES.size():
			_pose_out[i] = _pose_from[i].slerp(_pose_out[i], k)
		_hips_out = _hips_from.lerp(_hips_out, k)
	if _drag_w > 0.0 and _clips.has("Drag"): # kéo người: tay phải duỗi ra sau
		_sample("Drag", 0.0, _pose_a)
		for i in range(Bone.UPPER_ARM_R, Bone.HAND_R + 1):
			_pose_out[i] = _pose_out[i].slerp(_pose_a[i], _drag_w)
	if _oneshot_name != "":
		var into := minf(1.0, _oneshot_time / 0.08) # vào đòn nhanh, ra đòn chậm hơn
		var out := minf(1.0, (_oneshot_length - _oneshot_time) / 0.15)
		var k := smoothstep(0.0, 1.0, minf(into, out))
		_sample(_oneshot_name, _oneshot_time * ONESHOT_RATE[_oneshot_name], _pose_one)
		for i in range(Bone.SPINE, Bone.HAND_R + 1):
			_pose_out[i] = _pose_out[i].slerp(_pose_one[i], k)
	for i in BONES.size():
		_skeleton.set_bone_pose_rotation(_bone_ids[i], _pose_out[i])
	_skeleton.set_bone_pose_position(_bone_ids[Bone.HIPS], _hips_out)


## Đứng / đi / chạy theo tốc độ.
func _pose_move(delta: float) -> void:
	var walk := _clips["Walk"] as Animation
	var run := _clips["Run"] as Animation
	var speeds: Dictionary = CLIP_SPEED[is_hunter()]
	var walk_key := "Run" if _walk_is_run else "Walk"
	var walk_v := float(speeds[walk_key]) * _scale # m/s khi phát đúng tốc độ gốc
	var run_v := float(speeds["Run"]) * _scale
	var run_w := smoothstep(WALK_TO_RUN.x, WALK_TO_RUN.y, _speed)
	var move_w := smoothstep(RUN_SPEED_MIN * 0.5, RUN_SPEED_MIN * 1.5, _speed)
	var length := lerpf(walk.length, run.length, run_w) # giây mỗi chu kỳ khi phát tốc độ gốc
	var stride := lerpf(walk_v * walk.length, run_v * run.length, run_w) # mét mỗi chu kỳ
	# Người chibi chân ngắn: chạy nhanh quá thì kẹp tốc độ phát, chịu chân trượt chút.
	_move_phase = fmod(_move_phase + delta * minf(_speed / stride, MAX_RATE / length), 1.0)
	var stand := _clips["Stand"] as Animation
	_hips_out = _sample("Stand", fmod(_pose_time, stand.length), _pose_out)
	if move_w > 0.0:
		var hw := _sample("Walk", fmod(_move_phase + CLIP_PHASE[walk_key], 1.0) * walk.length, _pose_a)
		var hr := _sample("Run", fmod(_move_phase + CLIP_PHASE["Run"], 1.0) * run.length, _pose_b)
		for i in BONES.size():
			_pose_out[i] = _pose_out[i].slerp(_pose_a[i].slerp(_pose_b[i], run_w), move_w)
		_hips_out = _hips_out.lerp(hw.lerp(hr, run_w), move_w)


## Góc các xương của động tác `clip` ở giây `t` vào `out`; trả vị trí hông.
func _sample(clip: String, t: float, out: Array[Quaternion]) -> Vector3:
	var anim := _clips[clip] as Animation
	var tracks := _clip_tracks[clip] as PackedInt32Array
	for i in BONES.size():
		out[i] = anim.rotation_track_interpolate(tracks[i], t)
	return anim.position_track_interpolate(tracks[BONES.size()], t)


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
	_oneshot_name = "" # đổi trạng thái (gục, bị nhốt...) thì bỏ đòn đang phát dở


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
		_play_once("Hit")
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
		_play_once("Attack")


func _on_item_used(id: int, _type: GameTypes.ItemType, _target_id: int, _target_pos: Vector3) -> void:
	if id == peer_id and state == GameTypes.PlayerState.IDLE:
		_play_once("Throw")


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
