extends Node3D
## Phần hiển thị của thẻ đạo cụ trên mọi máy: dựng vật thể đặt xuống đất
## (bẫy, đệm lò xo, hộp gỗ) theo EventBus.object_placed / object_removed, và
## hiệu ứng ném (túi máu, lựu đạn) theo item_used. Phần luật của vật thể (bẫy
## kẹp, đệm hất) chạy trong chính node đó trên server.

const T := GameTypes.ItemType
const PLACED_SCRIPTS := {
	T.TRAP: preload("res://Items/placed/trap_node.gd"),
	T.JUMP_PAD: preload("res://Items/placed/jump_pad_node.gd"),
	T.CRATE: preload("res://Items/placed/crate_node.gd"),
}
const MEDKIT_FLIGHT := 0.3
const GRENADE_FLIGHT := 0.6
const GRENADE_RADIUS := 2.5

var _placed := {} # obj_id -> Node3D

static var _kit_mesh: BoxMesh
static var _grenade_mesh: SphereMesh
static var _blast_mesh: CylinderMesh


func _ready() -> void:
	name = "ItemVisuals"
	EventBus.object_placed.connect(_on_placed)
	EventBus.object_removed.connect(_on_removed)
	EventBus.item_used.connect(_on_item_used)
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


func _on_item_used(id: int, type: GameTypes.ItemType, target_id: int, target_pos: Vector3) -> void:
	var from: Variant = _entity_pos(id)
	if from == null:
		return
	match type:
		T.MEDKIT:
			if target_id != id:
				var to: Variant = _entity_pos(target_id)
				_throw(_kit_mesh, from, to if to != null else target_pos, MEDKIT_FLIGHT, Callable())
		T.STUN_GRENADE:
			_throw(_grenade_mesh, from, target_pos, GRENADE_FLIGHT, _blast.bind(target_pos))


## Vật bay theo đường cong từ `from` tới `to` rồi gọi `on_land`.
func _throw(mesh: Mesh, from: Vector3, to: Vector3, time: float, on_land: Callable) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var start := from + Vector3(0, 1.2, 0)
	var end := to + Vector3(0, 0.4, 0)
	var tween := mi.create_tween()
	tween.tween_method(func(t: float) -> void:
		mi.global_position = start.lerp(end, t) + Vector3(0, sin(t * PI) * 1.5, 0), 0.0, 1.0, time)
	tween.tween_callback(func() -> void:
		mi.queue_free()
		if on_land.is_valid():
			on_land.call())


func _blast(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _blast_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.05, 0)
	mi.scale = Vector3(0.2, 1, 0.2)
	var tween := mi.create_tween()
	tween.tween_property(mi, "scale", Vector3(GRENADE_RADIUS, 1, GRENADE_RADIUS), 0.15)
	tween.tween_property(mi, "transparency", 1.0, 0.35)
	tween.tween_callback(mi.queue_free)


func _entity_pos(id: int) -> Variant:
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		if (node as EntityBase).peer_id == id:
			return (node as Node3D).global_position
	return null


func _build_meshes() -> void:
	if _kit_mesh:
		return
	_kit_mesh = BoxMesh.new()
	_kit_mesh.size = Vector3(0.3, 0.3, 0.3)
	_kit_mesh.material = _glow(Color(1, 0.2, 0.3))
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


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	return m
