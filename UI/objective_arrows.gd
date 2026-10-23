extends Control
## Mũi tên mép màn hình chỉ tới mục tiêu đang ở ngoài khung nhìn, kèm khoảng
## cách (mét), để khỏi phải mở minimap mới biết đi đâu:
## - Đệ tử: trận linh chưa giải gần nhất (xanh); lối ra gần nhất khi lối ra đang
##   mở / đã mở (xanh lá); đồng môn đang gục (cam) hay bị nhốt trong huyết trận (tím).
## - Ma tu đang kéo người: huyết trận gần nhất (đỏ).
## Mục tiêu tính lại 10 lần/giây; vẽ lại mỗi lần đó. Chỉ đọc GameState / group.

const UiTheme = preload("res://UI/ui_theme.gd")
const INK := Color(0.12, 0.1, 0.16)
const UPDATE_INTERVAL := 0.1
const MAX_ARROWS := 4
const EDGE := 56.0 # px cách mép trái / phải màn hình
const TOP := 150.0 # dưới thanh trên (đồng hồ, hàng đồng môn)
const BOTTOM := 190.0 # trên thanh thẻ, cần, nút
const MINIMAP_CLEAR := Vector2(280.0, 260.0) # góc phải trên có minimap: mũi tên xuống dưới chỗ này
const ARROW_R := 24.0
const COLOR_CHEST := Color(0.4, 0.8, 1.0)
const COLOR_GATE := Color(0.33, 0.9, 0.4)
const COLOR_DOWNED := Color(0.98, 0.6, 0.2)
const COLOR_PRISON := Color(0.75, 0.5, 1.0)
const COLOR_HUNTER_PRISON := Color(0.95, 0.25, 0.3)

var _left := 0.0
# Mục tiêu đang chỉ (dùng lại mảng, không tạo mới mỗi lần): vị trí màn hình mép, góc, màu, mét.
var _pos := PackedVector2Array()
var _angle := PackedFloat32Array()
var _dist := PackedFloat32Array()
var _colors := PackedColorArray()
var _kinds := PackedInt32Array() # 0 trận linh, 1 lối ra, 2 người gục, 3 huyết trận
var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _outline := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _diamond := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _inset := Vector4.ZERO
var _me_entity: EntityBase


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset = UiTheme.safe_insets(get_viewport())
	get_viewport().size_changed.connect(func() -> void: _inset = UiTheme.safe_insets(get_viewport()))
	RenderWarmup.register_text(get_theme_default_font(), 15)
	RenderWarmup.register_text(get_theme_default_font(), 15, 4)


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = UPDATE_INTERVAL
	_collect()
	queue_redraw()


func _collect() -> void:
	_pos.clear()
	_angle.clear()
	_dist.clear()
	_colors.clear()
	_kinds.clear()
	var rules := GameState.rules
	var me := rules.record(GameState.my_id()) if rules else null
	var body := _my_entity()
	var cam := get_viewport().get_camera_3d()
	if me == null or body == null or cam == null or not rules.is_playing():
		return
	var at := body.flat_position()
	if me.is_hunter():
		if me.carrying_id != 0:
			_nearest(cam, at, GameTypes.GROUP_PRISONS, COLOR_HUNTER_PRISON, 3, func(_n: Node) -> bool: return true)
		return
	if not GameTypes.is_active(me.state):
		return
	if rules.gate_open or rules.gate_opening_left > 0.0:
		_nearest(cam, at, GameTypes.GROUP_EXIT_GATES, COLOR_GATE, 1, func(_n: Node) -> bool: return true)
	else:
		_nearest(cam, at, GameTypes.GROUP_SAFES, COLOR_CHEST, 0, func(n: Node) -> bool:
			return rules.safe_progress.get((n as Interactable).interactable_id, 1.0) < 1.0)
	# Đồng môn cần giúp: gục (đỡ dậy) hoặc bị nhốt (phá huyết trận).
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e == body or e.is_hunter():
			continue
		var rec := rules.record(e.peer_id)
		if rec == null:
			continue
		if rec.state == GameTypes.PlayerState.DOWNED:
			_add(cam, at, e.global_position, COLOR_DOWNED, 2)
		elif rec.state == GameTypes.PlayerState.IMPRISONED:
			_add(cam, at, e.global_position, COLOR_PRISON, 3)


## Thêm mũi tên tới vật gần nhất trong `group` thỏa `ok`.
func _nearest(cam: Camera3D, at: Vector2, group: StringName, color: Color, kind: int, ok: Callable) -> void:
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(group):
		var n := node as Node3D
		var d := at.distance_squared_to(Vector2(n.global_position.x, n.global_position.z))
		if d < best_d and ok.call(n):
			best_d = d
			best = n
	if best:
		_add(cam, at, best.global_position, color, kind)


## Thêm một mũi tên nếu điểm `world` nằm ngoài khung nhìn (trong khung thì không cần chỉ).
func _add(cam: Camera3D, at: Vector2, world: Vector3, color: Color, kind: int) -> void:
	if _pos.size() >= MAX_ARROWS:
		return
	var view := get_viewport_rect().size
	var area := Rect2(Vector2(EDGE + _inset.x, TOP + _inset.y),
		Vector2.ZERO).expand(Vector2(view.x - EDGE - _inset.z, view.y - BOTTOM - _inset.w))
	var behind := cam.is_position_behind(world)
	var p := cam.unproject_position(world)
	if not behind and Rect2(Vector2.ZERO, view).grow(-20.0).has_point(p):
		return
	var center := view / 2.0
	var dir := (p - center) * (-1.0 if behind else 1.0)
	if dir.length_squared() < 1.0:
		return
	# Kẹp điểm lên mép khung `area` theo hướng từ giữa màn hình.
	var half := area.size / 2.0
	var c := area.get_center()
	var k := minf(absf(half.x / dir.x) if dir.x != 0.0 else INF, absf(half.y / dir.y) if dir.y != 0.0 else INF)
	var edge := c + dir * k
	if edge.x > view.x - MINIMAP_CLEAR.x - _inset.z and edge.y < MINIMAP_CLEAR.y + _inset.y:
		edge.y = MINIMAP_CLEAR.y + _inset.y
	_pos.append(edge)
	_angle.append(dir.angle())
	_dist.append(at.distance_to(Vector2(world.x, world.z)))
	_colors.append(color)
	_kinds.append(kind)


func _draw() -> void:
	var font := get_theme_default_font()
	for i in _pos.size():
		var p := _pos[i]
		var d := Vector2.from_angle(_angle[i])
		var col := _colors[i]
		# Mũi nhọn chỉ hướng, nằm ngoài vòng tròn.
		_tri[0] = p + d * (ARROW_R + 14)
		_tri[1] = p + d * (ARROW_R - 2) + d.orthogonal() * 12
		_tri[2] = p + d * (ARROW_R - 2) - d.orthogonal() * 12
		draw_colored_polygon(_tri, col)
		for k in 4:
			_outline[k] = _tri[k % 3]
		draw_polyline(_outline, INK, 2.0)
		draw_circle(p, ARROW_R + 3, INK)
		draw_circle(p, ARROW_R, Color(col, 0.9))
		_glyph(_kinds[i], p)
		var meters := "%dm" % roundi(_dist[i])
		draw_string_outline(font, p + Vector2(-40, ARROW_R + 20), meters, HORIZONTAL_ALIGNMENT_CENTER, 80, 15, 4, INK)
		draw_string(font, p + Vector2(-40, ARROW_R + 20), meters, HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Color.WHITE)


## Hình nhỏ trong vòng: thoi (trận linh), cổng, dấu chấm than (người gục), song sắt (huyết trận).
func _glyph(kind: int, p: Vector2) -> void:
	match kind:
		0:
			_diamond[0] = p + Vector2(0, -12)
			_diamond[1] = p + Vector2(9, 0)
			_diamond[2] = p + Vector2(0, 12)
			_diamond[3] = p + Vector2(-9, 0)
			draw_colored_polygon(_diamond, Color.WHITE)
		1:
			draw_rect(Rect2(p + Vector2(-10, -10), Vector2(20, 22)), INK, false, 3.0)
			draw_rect(Rect2(p + Vector2(-5, -3), Vector2(10, 15)), Color.WHITE)
		2:
			draw_line(p + Vector2(0, -12), p + Vector2(0, 4), Color.WHITE, 5.0)
			draw_circle(p + Vector2(0, 10), 3.0, Color.WHITE)
		3:
			for k in 3:
				draw_line(p + Vector2(-8 + k * 8, -11), p + Vector2(-8 + k * 8, 11), Color.WHITE, 3.0)


func _my_entity() -> EntityBase:
	if is_instance_valid(_me_entity):
		return _me_entity
	_me_entity = null
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		if (node as EntityBase).peer_id == GameState.my_id():
			_me_entity = node as EntityBase
	return _me_entity
