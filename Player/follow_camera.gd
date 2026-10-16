extends Camera3D
## Camera nhìn chéo từ trên xuống, bám theo nhân vật của máy này.
## Không xoay theo nhân vật (top_level). Muốn camera xoay thì trả góc qua
## LocalInputSource.get_aim_yaw() để server tính hướng đi cho đúng.
## Bám theo hình đã nội suy của nhân vật (visual_position), không bám vị trí
## vật lý, để khung hình không giật khi FPS lệch nhịp 60 lần tính vật lý / giây.
## Mình đã thoát hoặc bị loại thì xem người khác (ưu tiên đồng đội còn chơi);
## nút "spectate_next" (Tab, nút Đổi người xem trên màn hình) chuyển người.
## Chỉ là hình: camera đọc nút trực tiếp, không đụng luật.

const OFFSET := Vector3(0, 7.5, 6.5) # gần hơn để thấy rõ nhân vật chibi
const FOLLOW_SPEED := 8.0
const SPECTATE := &"spectate_next"

var _watch: EntityBase # người đang xem khi mình đã ra khỏi trận (null = chính mình)
var _retry_left := 0.0


func _ready() -> void:
	top_level = true
	fov = 55
	var start := (get_parent() as Node3D).global_position # hình chưa đặt chỗ (node cha _ready sau)
	global_position = start + OFFSET
	look_at(start)
	make_current()


func _process(delta: float) -> void:
	var target: Vector3 = _target() + OFFSET
	global_position = global_position.lerp(target, minf(1.0, delta * FOLLOW_SPEED))


func _target() -> Vector3:
	var node: Node3D = _watched()
	return node.visual_position() if node.has_method(&"visual_position") else node.global_position


## Mình còn trong trận (kể cả trong tù) thì xem mình; đã thoát / bị loại thì xem người khác.
func _watched() -> Node3D:
	var me := get_parent() as EntityBase
	if me == null or not (me.state == GameTypes.PlayerState.ESCAPED or me.state == GameTypes.PlayerState.ELIMINATED):
		_watch = null
		return get_parent()
	var next := InputMap.has_action(SPECTATE) and Input.is_action_just_pressed(SPECTATE)
	_retry_left -= get_process_delta_time()
	if next or (not _watchable(_watch, me) and _retry_left <= 0.0):
		_retry_left = 0.25 # không ai để xem thì 0,25 giây mới tìm lại, khỏi quét nhóm mỗi frame
		_watch = _next_watch(me, not next)
	return _watch if _watch else me


func _watchable(e: EntityBase, me: EntityBase) -> bool:
	return is_instance_valid(e) and e != me and e.visible and not GameTypes.is_out(e.state)


## Người kế tiếp sau `_watch` (theo id); tự chọn thì ưu tiên cùng phe, bấm đổi
## thì lần lượt mọi người (cả thợ săn). Không còn ai thì null.
func _next_watch(me: EntityBase, prefer_team: bool) -> EntityBase:
	var ids := []
	var by_id := {}
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if _watchable(e, me):
			ids.append(e.peer_id)
			by_id[e.peer_id] = e
	if ids.is_empty():
		return null
	ids.sort()
	var current: int = _watch.peer_id if is_instance_valid(_watch) else -1000000
	for pass_same_team: bool in ([true, false] if prefer_team else [false]):
		for k in ids.size():
			var e: EntityBase = by_id[ids[(ids.bsearch(current, false) + k) % ids.size()]]
			if e.peer_id != current and (not pass_same_team or e.role == me.role):
				return e
	return by_id[ids[0]]
