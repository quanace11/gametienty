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
## Hình: nhân vật chibi KayKit Adventurers (CC0, Player/models/), ma tu (thợ săn)
## là Rogue trùm đầu áo tím đen, ma khí tím đỏ dưới chân, tay không (phi kiếm
## hóa ra khi bắn); đệ tử (người trốn) là Mage áo trắng xanh, búi tóc trâm ngọc.
## Animation chọn trên mọi máy theo trạng thái + tốc độ, không gửi qua mạng.
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

const HUNTER_MODEL := "res://Player/models/rogue_hooded.glb"
const ESCAPEE_MODEL := "res://Player/models/mage.glb" # chỉ có lưới, không có animation
const ANIM_MODEL := "res://Player/models/knight.glb" # đệ tử mượn khung xương + animation của Knight
const ESCAPEE_HIDDEN := ["Mage_Hat"] # bỏ mũ phù thủy, thay bằng búi tóc
const HALO_SWORDS := 3 # phi kiếm lơ lửng sau lưng ma tu
const HUNTER_TEXTURE := "res://Player/models/ma_tu_texture.png" # bảng màu Rogue tô tím đen
const ESCAPEE_TEXTURE := "res://Player/models/de_tu_texture.png" # bảng màu Mage tô trắng ngọc
const MODEL_SCALE := 0.72 # model KayKit cao ~2.4 m, thu về ~1.75 m
const LOOP_ANIMS := ["Idle", "Running_A", "Lie_Idle", "Sit_Floor_Idle", "Jump_Idle"]
const RUN_SPEED_MIN := 0.6 # m/s, chậm hơn thì đứng yên
const BLEND := 0.15
# Cạy rương: lặp đoạn ngồi xổm của anim PickUp tới lui, tay mò mẫm ở ổ khóa.
const LOCK_ANIM := "PickUp"
const LOCK_FROM := 0.4 # giây trong anim: đã ngồi xuống
const LOCK_TO := 0.85 # giây: tay với ra
const LOCK_SPEED := 0.7
const CHEST_CHECK := 0.1 # giây giữa hai lần xem có đứng ở rương không
const HIT_FLASH_TIME := 0.18 # giây người bị trúng chớp đỏ

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _anim: AnimationPlayer
var _model: Node3D
var _safes: Array[Node] = [] # rương trên bản đồ (lấy một lần)
var _chest: Node3D # rương đang cạy (đứng yên trong vùng rương chưa mở xong), null = không
var _chest_check_left := 0.0
var _anim_name := ""
var _oneshot_left := 0.0 # đang phát anim một lần (bắn, bị trúng, ném)
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
static var _robes := {} # đường dẫn bảng màu -> material dùng chung
static var _bun_mesh: ArrayMesh
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
	label.position.y = HEIGHT + 0.4
	label.font_size = 48
	label.modulate = Color(1, 0.9, 0.3) if is_local else Color.WHITE
	_visual.add_child(label)


func _build_model() -> void:
	var path := HUNTER_MODEL if is_hunter() else ANIM_MODEL
	var model: Node3D = (load(path) as PackedScene).instantiate()
	_model = model
	model.scale = Vector3.ONE * MODEL_SCALE * (1.1 if is_hunter() else 1.0)
	model.rotation.y = PI # model nhìn về +Z, nhân vật nhìn về -Z
	_visual.add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.get_parent().name.begins_with("handslot") or not is_hunter():
			mi.visible = false # bỏ vũ khí cầm tay; đệ tử thì bỏ cả người Knight, chỉ mượn khung xương + animation
		else:
			mi.material_override = _robe(mi, HUNTER_TEXTURE)
	if not is_hunter():
		_wear_disciple_robe(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).visible:
			_body_meshes.append(node as MeshInstance3D)
	if is_hunter():
		_add_sword_halo()
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
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim = players[0] as AnimationPlayer
	for anim_name: String in LOOP_ANIMS:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")


## Đệ tử: lấy các mảnh thân Mage (tóc bạc, búi tóc trâm ngọc; cùng khung xương
## Rig KayKit, cùng tư thế gốc) gắn vào khung xương của model mượn animation;
## skin bám theo tên xương. Đệ tử có peer_id chẵn mọc thêm cánh lửa sau lưng
## (chọn theo peer_id nên mọi máy thấy giống nhau).
func _wear_disciple_robe(model: Node3D) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var robe: Node3D = (load(ESCAPEE_MODEL) as PackedScene).instantiate()
	for node in robe.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.skin == null or mi.name in ESCAPEE_HIDDEN:
			continue
		mi.get_parent().remove_child(mi)
		mi.owner = null
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		mi.transform = Transform3D.IDENTITY
		mi.material_override = _robe(mi, ESCAPEE_TEXTURE)
	robe.free()
	if absi(peer_id) % 2 == 0:
		_add_flame_wings()
	var head := skeleton.find_bone("head")
	if head >= 0: # búi tóc + trâm ngọc thay mũ phù thủy
		var attach := BoneAttachment3D.new()
		attach.bone_name = "head"
		skeleton.add_child(attach)
		var bun := MeshInstance3D.new()
		bun.mesh = _hair_bun_mesh()
		bun.position = Vector3(0, 0.95, -0.15)
		attach.add_child(bun)


## Cánh lửa: mỗi bên 4 lông vũ lửa xòe ra sau lưng, vỗ nhẹ. Gắn vào hình nhân vật
## (không theo xương) cho đơn giản; nhân vật nhìn về -Z nên sau lưng là +Z.
func _add_flame_wings() -> void:
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(0.12 * side, 0.95, 0.3)
		_visual.add_child(wing)
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
	_halo.position = Vector3(0, 1.25, 0.42) # sau lưng (nhân vật nhìn về -Z)
	_visual.add_child(_halo)
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


## Đổi bảng màu của model (cùng UV) sang bản đã tô lại; một material cho mỗi bảng màu.
static func _robe(mi: MeshInstance3D, texture_path: String) -> Material:
	if not _robes.has(texture_path):
		var m := (mi.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.albedo_texture = load(texture_path)
		_robes[texture_path] = m
	return _robes[texture_path]


static func _hair_bun_mesh() -> Mesh:
	if _bun_mesh == null:
		var hair := StandardMaterial3D.new()
		hair.albedo_color = Color(0.86, 0.88, 0.93) # tóc bạc
		var jade := StandardMaterial3D.new()
		jade.albedo_color = Color(0.4, 0.9, 0.7)
		var st := SurfaceTool.new()
		var bun := SphereMesh.new()
		bun.radius = 0.16
		bun.height = 0.3
		bun.radial_segments = 10
		bun.rings = 5
		var pin := BoxMesh.new()
		pin.size = Vector3(0.5, 0.04, 0.04)
		_bun_mesh = ArrayMesh.new()
		st.append_from(bun, 0, Transform3D.IDENTITY)
		st.commit(_bun_mesh)
		_bun_mesh.surface_set_material(0, hair)
		st = SurfaceTool.new()
		st.append_from(pin, 0, Transform3D(Basis(), Vector3(0, 0.02, 0)))
		st.commit(_bun_mesh)
		_bun_mesh.surface_set_material(1, jade)
	return _bun_mesh


static func _glow_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


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
	var pos := _visual.global_position
	var flat := pos - _last_pos
	flat.y = 0.0
	_last_pos = pos
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
	_chest_check_left -= delta
	if _chest_check_left <= 0.0:
		_chest_check_left = CHEST_CHECK
		_chest = _chest_here()
	_face_chest(delta)
	if _flying or pos.y > 0.4:
		_play("Jump_Idle")
	elif _chest != null:
		_play_lockpick()
	elif _speed > RUN_SPEED_MIN:
		_play("Running_A", clampf(_speed / ESCAPEE_SPEED, 0.6, 1.6))
	else:
		_play("Idle")


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


## Ngồi xổm, tay mò tới lui ở ổ khóa (đoạn giữa anim PickUp chạy xuôi rồi ngược).
func _play_lockpick() -> void:
	if _anim_name != LOCK_ANIM:
		_play(LOCK_ANIM, LOCK_SPEED)
		return
	var t := _anim.current_animation_position
	if t >= LOCK_TO and _anim.speed_scale > 0.0:
		_anim.speed_scale = -LOCK_SPEED
	elif t <= LOCK_FROM and _anim.speed_scale < 0.0:
		_anim.speed_scale = LOCK_SPEED


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
	if _anim:
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
