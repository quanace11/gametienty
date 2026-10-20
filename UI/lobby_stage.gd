extends SubViewportContainer
## Sân khấu 3D ở sảnh: nhân vật đang chọn đứng nghỉ (động tác Idle) trên đài
## đá có vòng trận pháp, nền trời 2D của menu lộ ra phía sau (nền trong suốt).
## Rẻ: không bóng đổ thật (vệt tối dưới chân), một đèn, mô hình theo mức đồ họa.
## Menu ẩn (đang trong trận) thì ngừng vẽ và ngừng chạy động tác.

const CharacterRoster = preload("res://UI/character_roster.gd")
const TALL := 2.0 # mét, chiều cao nhân vật trên đài
const TURN_BACK := 2.5 # giây, nhân vật quay lại nhìn camera sau khi bị vuốt xoay

var _viewport: SubViewport
var _camera: Camera3D
var _holder: Node3D # chứa mô hình, xoay bằng tay
var _model_path := ""
var _yaw := 0.0
var _dragging := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = get_viewport().msaa_3d
	add_child(_viewport)

	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(0, 2.0, 8.2)
	_viewport.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0))
	_camera = cam
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.1
	_viewport.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.environment.ambient_light_energy = 0.7
	_viewport.add_child(env)
	_build_dais()
	_holder = Node3D.new()
	_viewport.add_child(_holder)
	visibility_changed.connect(_on_visibility_changed)
	set_process(false)


## Đặt nhân vật lên đài; cùng tệp mô hình thì giữ nguyên, không dựng lại.
func show_character(c: Dictionary) -> void:
	var path := CharacterRoster.model_path(c)
	if path == _model_path:
		return
	_model_path = path
	for child in _holder.get_children():
		child.queue_free()
	var model: Node3D = (load(path) as PackedScene).instantiate()
	var hunter: bool = c["role"] == GameTypes.Role.HUNTER
	model.scale = Vector3.ONE * TALL / float(PlayerCharacter.MODEL_HEIGHT[hunter])
	for slot in model.find_children("handslot*", "BoneAttachment3D", true, false):
		for item in slot.get_children():
			if item.name != PlayerCharacter.WEAPONS[hunter]:
				item.free()
	_holder.add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var player := players[0] as AnimationPlayer
		if player.has_animation("Idle"):
			player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
			player.play("Idle")
	_yaw = 0.0


## Dời khung nhìn để nhân vật đứng lệch trái (khi bảng bên phải che giữa màn hình).
func shift_left(on: bool) -> void:
	_camera.h_offset = 1.6 if on else 0.0


## Vuốt ngang trên sân khấu để xoay nhân vật xem cho kỹ.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
	elif _dragging and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		_yaw += event.relative.x * 0.01
		set_process(true)


func _process(delta: float) -> void:
	if not _dragging:
		_yaw = lerp_angle(_yaw, 0.0, minf(1.0, delta * 3.0 / TURN_BACK))
		if absf(_yaw) < 0.002:
			_yaw = 0.0
			set_process(false)
	_holder.rotation.y = _yaw


func _build_dais() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.82, 0.8, 0.86)
	var top := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.25
	cyl.bottom_radius = 1.4
	cyl.height = 0.3
	cyl.radial_segments = 32
	cyl.rings = 1
	cyl.material = stone
	top.mesh = cyl
	top.position.y = -0.15
	_viewport.add_child(top)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.05
	torus.rings = 32
	torus.ring_segments = 4
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.82, 0.3)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = glow
	ring.mesh = torus
	ring.scale = Vector3(1, 0.15, 1)
	ring.position.y = 0.01
	_viewport.add_child(ring)
	var blob := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.55
	disc.bottom_radius = 0.55
	disc.height = 0.01
	disc.radial_segments = 24
	disc.rings = 1
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.08, 0.15, 0.35)
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material = dark
	blob.mesh = disc
	blob.position.y = 0.02
	_viewport.add_child(blob)
	for m: MeshInstance3D in [top, ring, blob]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _on_visibility_changed() -> void:
	var on := is_visible_in_tree()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	_viewport.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
