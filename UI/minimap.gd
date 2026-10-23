extends Control
## Minimap góc trên phải. Vẽ tường, trận linh (hình thoi, màu theo tiến độ),
## lối ra, huyết trận, mình và đồng môn (đệ tử). Thợ săn thấy dấu chân radar mờ dần, và chạm
## vào minimap để chọn điểm dịch chuyển (GameState.set_aim_point).
## Chỉ đọc GameState / EventBus, vẽ lại 10 lần/giây (đỡ tốn pin điện thoại).

const UiTheme = preload("res://UI/ui_theme.gd")
const WIDTH := 220.0
const REDRAW_INTERVAL := 0.1
const BG := Color(0, 0, 0, 0.55)
const WALL := Color(0.75, 0.72, 0.65)
const ME := Color(1, 0.9, 0.3)
const ALLY := Color(0.35, 0.65, 1.0)
const ALLY_OUT := Color(0.5, 0.5, 0.5)
const PRISON := Color(0.95, 0.2, 0.25) # huyết trận
const STEP := Color(1, 0.3, 0.3)
const BUSH := Color(0.3, 0.68, 0.3, 0.7)

var _diamond := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]) # dùng lại, không tạo mới mỗi lần vẽ

var _bounds := Rect2()
var _walls: Array[Rect2] = []
var _bushes: Array[Vector3] = []
var _scale := 1.0
var _redraw_left := 0.0
var _footprints := PackedVector3Array() # x, z: vị trí; y: tuổi (giây) lúc nhận
var _footprint_left := 0.0
var _footprint_time := 1.0
var _aim: Variant = null # Vector2 trên mặt sàn
# Vật đứng yên (nhà tù, rương, cổng) chỉ tìm một lần lúc dựng minimap.
var _prisons: PackedVector2Array = []
var _safes: Array[Interactable] = []
var _gates: PackedVector2Array = []
var _frame: StyleBoxFlat


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
		_place()
		get_viewport().size_changed.connect(_place)
		for node in get_tree().get_nodes_in_group(GameTypes.GROUP_PRISONS):
			_prisons.append(_at(node))
		for node in get_tree().get_nodes_in_group(GameTypes.GROUP_SAFES):
			_safes.append(node as Interactable)
		for node in get_tree().get_nodes_in_group(GameTypes.GROUP_EXIT_GATES):
			_gates.append(_at(node))
		_frame = StyleBoxFlat.new()
		_frame.bg_color = BG
		_frame.set_corner_radius_all(12)
		_frame.set_border_width_all(3)
		_frame.border_color = Color(0.12, 0.1, 0.16)
		_frame.set_expand_margin_all(4)
	queue_redraw()


## Góc trên phải (gọi lại khi đổi kích thước màn hình / xoay máy).
func _place() -> void:
	var inset := UiTheme.safe_insets(get_viewport(), 14.0)
	position = Vector2(get_viewport_rect().size.x - size.x - inset.z, inset.y)


func _draw() -> void:
	var rules := GameState.rules
	if rules == null or _bounds.size == Vector2.ZERO:
		return
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	for w in _walls:
		draw_rect(Rect2(_to_map(w.position), w.size * _scale), WALL)
	for b in _bushes:
		draw_circle(_to_map(Vector2(b.x, b.y)), b.z * _scale, BUSH)
	for p in _prisons:
		draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), PRISON, false, 2.5)
	for safe in _safes:
		if not is_instance_valid(safe):
			continue
		var progress: float = rules.safe_progress.get(safe.interactable_id, 0.0)
		var c := Color(1, 0.82, 0.3) if progress >= 1.0 else Color(0.3, 0.6, 0.8).lerp(Color(0.5, 0.95, 1.0), progress)
		var p := _at(safe)
		_diamond[0] = p + Vector2(0, -6)
		_diamond[1] = p + Vector2(5, 0)
		_diamond[2] = p + Vector2(0, 6)
		_diamond[3] = p + Vector2(-5, 0)
		draw_colored_polygon(_diamond, c) # linh tinh
	var gate_color := Color(0.3, 1, 0.4) if rules.gate_open else Color(1, 0.3, 0.3)
	for p in _gates:
		draw_circle(p, 6.0, Color(0.12, 0.1, 0.16))
		draw_circle(p, 4.5, gate_color)

	var my_id := GameState.my_id()
	var hunter := GameState.my_role() == GameTypes.Role.HUNTER
	if hunter and _footprint_left > 0.0:
		var fade := _footprint_left / _footprint_time
		var history := rules.config.footprint_history
		for f in _footprints:
			var a := clampf(1.0 - f.y / history, 0.15, 1.0) * fade
			draw_circle(_to_map(Vector2(f.x, f.z)), 2.5, Color(STEP, a))
	var me: EntityBase = null
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e.peer_id == my_id:
			me = e
		elif not hunter and not e.is_hunter() and e.state != GameTypes.PlayerState.ESCAPED:
			draw_circle(_at(e), 3.5, ALLY if not GameTypes.is_out(e.state) else ALLY_OUT)
	if me: # mình vẽ sau cùng cho nổi lên trên, có viền
		draw_circle(_at(me), 6.0, Color(0.12, 0.1, 0.16))
		draw_circle(_at(me), 4.5, ME)
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
