extends Node3D
## Bụi cây chibi: chùm cầu xanh, không chặn đường. Ai đứng trong bụi thì phe
## kia không thấy (luật ở GameState.can_see, server không gửi vị trí). Máy nào
## có nhân vật của mình đứng trong bụi thì bụi đó trong mờ để còn thấy mình.

const CHECK_INTERVAL := 0.1

var index := 0 ## chỉ số trong MapBase.get_bushes()
var radius := 1.4

var _parts: Array[MeshInstance3D] = []
var _see_through := false
var _check_left := 0.0
var _me: Node3D

static var _leaf_mesh: SphereMesh
static var _solid: StandardMaterial3D
static var _faded: StandardMaterial3D


func _ready() -> void:
	_build_shared()
	# Một cầu giữa + một vòng cầu quanh, cao thấp khác nhau cho giống bụi.
	var count := 6
	_add_leaf(Vector3(0, radius * 0.45, 0), radius * 0.85)
	for i in count:
		var a := TAU * i / count + 0.4
		var r := radius * (0.6 + 0.1 * (i % 2))
		_add_leaf(Vector3(cos(a) * r, radius * 0.3, sin(a) * r), radius * (0.55 + 0.1 * ((i + 1) % 2)))


func _add_leaf(pos: Vector3, size: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _leaf_mesh
	mi.material_override = _solid
	mi.position = pos
	mi.scale = Vector3(size, size * 0.8, size)
	add_child(mi)
	_parts.append(mi)


static func _build_shared() -> void:
	if _leaf_mesh:
		return
	_leaf_mesh = SphereMesh.new()
	_leaf_mesh.radius = 0.5
	_leaf_mesh.height = 1.0
	_leaf_mesh.radial_segments = 8
	_leaf_mesh.rings = 4
	_solid = StandardMaterial3D.new()
	_solid.albedo_color = Color(0.3, 0.68, 0.3)
	_faded = StandardMaterial3D.new()
	_faded.albedo_color = Color(0.3, 0.68, 0.3, 0.35)
	_faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	var me := _my_node()
	var inside := me != null and GameState.bush_at(me.global_position) == index
	if inside == _see_through:
		return
	_see_through = inside
	for mi in _parts:
		mi.material_override = _faded if inside else _solid
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if inside else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _my_node() -> Node3D:
	if is_instance_valid(_me):
		return _me
	var my_id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		if (node as EntityBase).peer_id == my_id:
			_me = node as Node3D
	return _me
