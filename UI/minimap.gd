extends Control
## Minimap góc trên phải. Vẽ tường, rương (màu theo tiến độ), cổng, nhà tù,
## mình và đồng đội (người trốn). Thợ săn thấy dấu chân radar mờ dần, và chạm
## vào minimap để chọn điểm dịch chuyển (GameState.set_aim_point).
## Chỉ đọc GameState / EventBus, vẽ lại 10 lần/giây (đỡ tốn pin điện thoại).

const WIDTH := 220.0
const REDRAW_INTERVAL := 0.1
const BG := Color(0, 0, 0, 0.55)
const WALL := Color(0.75, 0.72, 0.65)
const ME := Color(1, 0.9, 0.3)
const ALLY := Color(0.35, 0.65, 1.0)
const ALLY_OUT := Color(0.5, 0.5, 0.5)
const PRISON := Color(0.6, 0.45, 0.9)
const STEP := Color(1, 0.3, 0.3)
const BUSH := Color(0.3, 0.68, 0.3, 0.7)

var _bounds := Rect2()
var _walls: Array[Rect2] = []
var _bushes: Array[Vector3] = []
var _scale := 1.0
var _redraw_left := 0.0
var _footprints := PackedVector3Array() # x, z: vị trí; y: tuổi (giây) lúc nhận
var _footprint_left := 0.0
var _footprint_time := 1.0
var _aim: Variant = null # Vector2 trên mặt sàn


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	EventBus.footprints_revealed.connect(func(points: PackedVector3Array, seconds: float) -> void:
		_footprints = points
		_footprint_left = seconds
		_footprint_time = maxf(seconds, 0.01))


func _process(delta: float) -> void:
	_footprint_left = maxf(0.0, _footprint_left - delta)
	_redraw_left -= delta
	if _redraw_left > 0.0:
		return
	_redraw_left = REDRAW_INTERVAL
	if _bounds.size == Vector2.ZERO:
		var map := get_tree().get_first_node_in_group(GameTypes.GROUP_MAP) as MapBase
		if map == null or map.get_bounds().size == Vector2.ZERO:
			return
		_bounds = map.get_bounds()
		_walls = map.get_walls()
		_bushes = map.get_bushes()
		_scale = WIDTH / _bounds.size.x
		custom_minimum_size = _bounds.size * _scale
		size = custom_minimum_size
		position = Vector2(get_viewport_rect().size.x - size.x - 12, 12)
	queue_redraw()


func _draw() -> void:
	var rules := GameState.rules
	if rules == null or _bounds.size == Vector2.ZERO:
		return
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for w in _walls:
		draw_rect(Rect2(_to_map(w.position), w.size * _scale), WALL)
	for b in _bushes:
		draw_circle(_to_map(Vector2(b.x, b.y)), b.z * _scale, BUSH)
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_PRISONS):
		draw_rect(Rect2(_at(node) - Vector2(6, 6), Vector2(12, 12)), PRISON, false, 2.0)
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_SAFES):
		var progress: float = rules.safe_progress.get((node as Interactable).interactable_id, 0.0)
		var c := Color(0.3, 0.9, 0.3) if progress >= 1.0 else Color(0.6, 0.4, 0.2).lerp(Color(1, 0.85, 0.2), progress)
		draw_rect(Rect2(_at(node) - Vector2(4, 4), Vector2(8, 8)), c)
	var gate_color := Color(0.3, 1, 0.4) if rules.gate_open else Color(1, 0.3, 0.3)
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_EXIT_GATES):
		draw_circle(_at(node), 5.0, gate_color)

	var my_id := multiplayer.get_unique_id()
	var hunter := GameState.my_role() == GameTypes.Role.HUNTER
	if hunter and _footprint_left > 0.0:
		var fade := _footprint_left / _footprint_time
		var history := rules.config.footprint_history
		for f in _footprints:
			var a := clampf(1.0 - f.y / history, 0.15, 1.0) * fade
			draw_circle(_to_map(Vector2(f.x, f.z)), 2.5, Color(STEP, a))
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e.peer_id == my_id:
			continue
		if not hunter and not e.is_hunter() and e.state != GameTypes.PlayerState.ESCAPED:
			draw_circle(_at(e), 3.5, ALLY if not GameTypes.is_out(e.state) else ALLY_OUT)
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e.peer_id == my_id:
			draw_circle(_at(e), 4.5, ME)
	if _aim != null:
		var p := _to_map(_aim)
		draw_line(p - Vector2(5, 5), p + Vector2(5, 5), ME, 2.0)
		draw_line(p - Vector2(5, -5), p + Vector2(5, -5), ME, 2.0)


## Thợ săn chạm minimap: chọn điểm dịch chuyển (bấm thẻ Dịch chuyển để đi).
func _gui_input(event: InputEvent) -> void:
	if GameState.my_role() != GameTypes.Role.HUNTER or _scale <= 0.0:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var world: Vector2 = _bounds.position + (event.position as Vector2) / _scale
	_aim = world
	GameState.set_aim_point(Vector3(world.x, 0, world.y))
	accept_event()
	queue_redraw()


func _at(node: Node) -> Vector2:
	var p := (node as Node3D).global_position
	return _to_map(Vector2(p.x, p.z))


func _to_map(p: Vector2) -> Vector2:
	return (p - _bounds.position) * _scale
