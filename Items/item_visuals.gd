extends Node3D
## Phần hiển thị của thẻ đạo cụ trên mọi máy: dựng vật thể đặt xuống đất
## (bẫy, đệm lò xo, hộp gỗ, túi cứu nằm chờ) theo EventBus.object_placed / object_removed, và
## hiệu ứng ném (túi máu rơi thành vùng xanh, lựu đạn) theo item_used. Phần luật của vật thể (bẫy
## kẹp, đệm hất) chạy trong chính node đó trên server.
## Hiệu ứng ném, nổ, vùng xanh, cột sáng lấy từ pool (không tạo / xóa node mỗi lần).

const T := GameTypes.ItemType
const MedkitMesh = preload("res://Items/medkit_mesh.gd")
const PLACED_SCRIPTS := {
	T.MEDKIT: preload("res://Items/placed/medkit_node.gd"), # túi cứu nằm chờ người tới đón
	T.TRAP: preload("res://Items/placed/trap_node.gd"),
	T.JUMP_PAD: preload("res://Items/placed/jump_pad_node.gd"),
	T.CRATE: preload("res://Items/placed/crate_node.gd"),
}
const Medkit = preload("res://Items/effects/medkit.gd")
const GRENADE_FLIGHT := 0.6

var _placed := {} # obj_id -> Node3D
var _pool := {} # Mesh -> Array[MeshInstance3D] đang rảnh

static var _grenade_mesh: SphereMesh
static var _blast_mesh: CylinderMesh
static var _heal_mesh: CylinderMesh
static var _pillar_mesh: CylinderMesh


func _ready() -> void:
	name = "ItemVisuals"
	EventBus.object_placed.connect(_on_placed)
	EventBus.object_removed.connect(_on_removed)
	# Vật đặt xuống có luật chạy trên server nên luôn dựng; còn hiệu ứng ném,
	# cột sáng chỉ để nhìn: server riêng (headless) bỏ qua.
	if DisplayServer.get_name() == "headless":
		return
	EventBus.item_used.connect(_on_item_used)
	EventBus.teleport_started.connect(_on_teleport_started)
	_build_meshes()


func _on_placed(obj_id: int, type: GameTypes.ItemType, pos: Vector3, yaw: float, _owner_id: int) -> void:
	var script: Script = PLACED_SCRIPTS.get(type)
	if script == null or _placed.has(obj_id):
		return
	var node: Node3D = script.new()
	if node is Interactable:
		node.interactable_id = obj_id
	node.position = pos
	node.rotation.y = yaw
	add_child(node)
	_placed[obj_id] = node


func _on_removed(obj_id: int) -> void:
	var node: Node = _placed.get(obj_id)
	if node:
		node.queue_free()
	_placed.erase(obj_id)


func _on_item_used(id: int, type: GameTypes.ItemType, _target_id: int, target_pos: Vector3) -> void:
	var from: Variant = _entity_pos(id)
	if from == null:
		return
	match type:
		T.MEDKIT:
			var flat := Vector2((from as Vector3).x - target_pos.x, (from as Vector3).z - target_pos.z)
			_throw(MedkitMesh.get_mesh(), from, target_pos, Medkit.flight_time(flat.length()), _heal_area.bind(target_pos))
		T.STUN_GRENADE:
			_throw(_grenade_mesh, from, target_pos, GRENADE_FLIGHT, _blast.bind(target_pos))


## Thợ săn tụ lực: cột sáng ở chỗ đứng và chỗ sẽ tới (người trốn thấy để chạy).
func _on_teleport_started(id: int, target: Vector3, seconds: float) -> void:
	var from: Variant = _entity_pos(id)
	for pos: Variant in [from, target]:
		if pos == null:
			continue
		var mi := _take(_pillar_mesh)
		mi.global_position = (pos as Vector3) + Vector3(0, 1.5, 0)
		mi.scale = Vector3(0.3, 1, 0.3)
		var tween := mi.create_tween()
		tween.tween_property(mi, "scale", Vector3.ONE, seconds)
		tween.tween_callback(_give.bind(mi))


## Vật bay theo đường cong từ `from` tới `to` (ném xa thì vòng cao hơn), lộn
## vòng trên không, rơi xuống thì gọi `on_land`.
func _throw(mesh: Mesh, from: Vector3, to: Vector3, time: float, on_land: Callable) -> void:
	var mi := _take(mesh)
	var start := from + Vector3(0, 1.2, 0)
	var end := to + Vector3(0, 0.25, 0)
	var height := 1.2 + 0.2 * Vector2(to.x - from.x, to.z - from.z).length()
	var tween := mi.create_tween()
	tween.tween_method(func(t: float) -> void:
		mi.global_position = start.lerp(end, t) + Vector3(0, sin(t * PI) * height, 0)
		mi.rotation = Vector3(t * TAU, t * PI, 0.0), 0.0, 1.0, time)
	tween.tween_callback(func() -> void:
		_give(mi)
		if on_land.is_valid():
			on_land.call())


func _blast(pos: Vector3) -> void:
	var mi := _take(_blast_mesh)
	mi.global_position = pos + Vector3(0, 0.05, 0)
	mi.scale = Vector3(0.2, 1, 0.2)
	var tween := mi.create_tween()
	var r := _area(T.STUN_GRENADE)
	tween.tween_property(mi, "scale", Vector3(r, 1, r), 0.15)
	tween.tween_property(mi, "transparency", 1.0, 0.35)
	tween.tween_callback(_give.bind(mi))


## Vùng tròn xanh nơi túi máu rơi (đúng bán kính cứu của túi).
func _heal_area(pos: Vector3) -> void:
	var mi := _take(_heal_mesh)
	mi.global_position = pos + Vector3(0, 0.05, 0)
	mi.scale = Vector3(0.3, 1, 0.3)
	var tween := mi.create_tween()
	tween.tween_property(mi, "scale", Vector3.ONE, 0.15)
	tween.tween_interval(0.5)
	tween.tween_property(mi, "transparency", 1.0, 0.4)
	tween.tween_callback(_give.bind(mi))


## Lấy một hình rảnh trong pool (hoặc tạo mới), đặt lại về trạng thái gốc.
func _take(mesh: Mesh) -> MeshInstance3D:
	var free: Array = _pool.get(mesh, [])
	var mi: MeshInstance3D = free.pop_back() if not free.is_empty() else null
	if mi == null:
		mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	mi.visible = true
	mi.rotation = Vector3.ZERO
	mi.scale = Vector3.ONE
	mi.transparency = 0.0
	return mi


func _give(mi: MeshInstance3D) -> void:
	mi.visible = false
	if not _pool.has(mi.mesh):
		_pool[mi.mesh] = []
	_pool[mi.mesh].append(mi)


func _entity_pos(id: int) -> Variant:
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		if (node as EntityBase).peer_id == id:
			return (node as Node3D).global_position
	return null


func _build_meshes() -> void:
	if _grenade_mesh:
		return
	_grenade_mesh = SphereMesh.new()
	_grenade_mesh.radius = 0.15
	_grenade_mesh.height = 0.3
	_grenade_mesh.radial_segments = 8
	_grenade_mesh.rings = 4
	_grenade_mesh.material = _glow(Color(0.3, 0.3, 0.35))
	_blast_mesh = CylinderMesh.new()
	_blast_mesh.top_radius = 1.0
	_blast_mesh.bottom_radius = 1.0
	_blast_mesh.height = 0.05
	_blast_mesh.radial_segments = 16
	var m := _glow(Color(0.9, 0.9, 0.5))
	_blast_mesh.material = m
	_heal_mesh = CylinderMesh.new()
	_heal_mesh.top_radius = _area(T.MEDKIT) # đúng bán kính cứu của túi
	_heal_mesh.bottom_radius = _heal_mesh.top_radius
	_heal_mesh.height = 0.04
	_heal_mesh.radial_segments = 24
	_heal_mesh.rings = 1
	var heal_mat := StandardMaterial3D.new()
	heal_mat.albedo_color = Color(0.35, 1.0, 0.4, 0.45)
	heal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	heal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_heal_mesh.material = heal_mat
	_pillar_mesh = CylinderMesh.new()
	_pillar_mesh.top_radius = 0.6
	_pillar_mesh.bottom_radius = 0.6
	_pillar_mesh.height = 3.0
	_pillar_mesh.radial_segments = 10
	_pillar_mesh.rings = 1
	_pillar_mesh.material = _glow(Color(0.7, 0.2, 1.0))


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	return m


## Bán kính vùng tác dụng của thẻ `type` (ItemData.area_radius).
static func _area(type: GameTypes.ItemType) -> float:
	if GameState.rules == null:
		return 2.0
	return float(GameState.rules.catalog.get(type, {}).get("area", 2.0))
