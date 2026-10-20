extends Node3D
## Bụi cây chibi: chùm cầu xanh, không chặn đường. Ai đứng trong bụi thì phe
## kia không thấy (luật ở GameState.can_see, server không gửi vị trí). Máy nào
## có nhân vật của mình đứng trong bụi thì bụi đó trong mờ để còn thấy mình.
## Cả chùm cầu là một mesh dùng chung (bụi bán kính 1 m), mỗi bụi một lần vẽ.

const CHECK_INTERVAL := 0.1

var index := 0 ## chỉ số trong MapBase.get_bushes()
var radius := 1.4

var _mesh: MeshInstance3D
var _see_through := false
var _check_left := 0.0
var _me: Node3D

static var _leaf_mesh: ArrayMesh # chùm cầu của bụi bán kính 1 m
static var _solid: StandardMaterial3D
static var _faded: StandardMaterial3D


func _ready() -> void:
	if DisplayServer.get_name() == "headless": # server riêng: luật bụi cây nằm ở GameState, không cần hình
		set_process(false)
		return
	_build_shared()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _leaf_mesh
	_mesh.material_override = _solid
	_mesh.scale = Vector3.ONE * radius
	add_child(_mesh)


static func _build_shared() -> void:
	if _leaf_mesh:
		return
	# Một cầu giữa + một vòng cầu quanh, cao thấp khác nhau cho giống bụi.
	var leaf := SphereMesh.new()
	leaf.radius = 0.5
	leaf.height = 1.0
	leaf.radial_segments = 8
	leaf.rings = 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(leaf, 0, _leaf_xf(Vector3(0, 0.45, 0), 0.85))
	var count := 6
	for i in count:
		var a := TAU * i / count + 0.4
		var r := 0.6 + 0.1 * (i % 2)
		st.append_from(leaf, 0, _leaf_xf(Vector3(cos(a) * r, 0.3, sin(a) * r), 0.55 + 0.1 * ((i + 1) % 2)))
	_leaf_mesh = st.commit()
	_solid = StandardMaterial3D.new()
	_solid.albedo_color = Color(0.3, 0.6, 0.35)
	_faded = StandardMaterial3D.new()
	_faded.albedo_color = Color(0.3, 0.6, 0.35, 0.35)
	_faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	RenderWarmup.register(_faded) # chỉ hiện khi mình bước vào bụi


static func _leaf_xf(pos: Vector3, size: float) -> Transform3D:
	return Transform3D(Basis().scaled(Vector3(size, size * 0.8, size)), pos)


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	var me := _my_node()
	if me == null and GameState.rules != null and GameState.rules.is_playing():
		set_process(false) # máy này không có nhân vật (server không chơi): khỏi tìm mãi
		return
	var inside := me != null and GameState.bush_at(me.global_position) == index
	if inside == _see_through:
		return
	_see_through = inside
	_mesh.material_override = _faded if inside else _solid
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if inside else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _my_node() -> Node3D:
	if is_instance_valid(_me):
		return _me
	var my_id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		if (node as EntityBase).peer_id == my_id:
			_me = node as Node3D
			break
	return _me
