extends Control
## Thanh máu nổi trên đầu mọi nhân vật đang thấy được (cả ma tu lẫn đệ tử):
## mỗi ô là một máu (đệ tử 2 ô, ma tu 6 ô). Của mình viền vàng, cùng phe xanh
## lục, phe kia đỏ. Vừa mất máu thì ô vừa mất chớp trắng và hiện số "-1" bay lên.
## Chỉ đọc GameState.rules và vị trí nhân vật, không đổi gì. Vẽ tất cả trong một
## lần _draw (một batch), danh sách nhân vật lấy lại mỗi giây.
## Vị trí thanh nội suy giữa hai lần tính vật lý giống hình nhân vật (60 lần/giây
## vật lý, màn hình có thể 90/120 Hz), nên thanh dính theo đầu, không giật / xé.

const HEAD_HEIGHT := 2.75 # mét trên chân, ngay trên tên
const PIP_W := 14.0
const PIP_H := 9.0
const PIP_GAP := 2.0
const FLASH_TIME := 0.35
const POP_TIME := 0.7
const REFRESH_INTERVAL := 1.0
const SNAP_DIST := 6.0 # mét trong một lần tính vật lý: dịch chuyển, không nội suy
const OWN := Color(1.0, 0.85, 0.3)
const ALLY := Color(0.35, 0.9, 0.45)
const ENEMY := Color(0.95, 0.25, 0.25)
const EMPTY := Color(0.15, 0.12, 0.15, 0.85)
const BORDER := Color(0.05, 0.03, 0.05, 0.9)

var _entities: Array[EntityBase] = []
var _prev: Array[Vector3] = [] # vị trí ở lần tính vật lý trước, theo thứ tự _entities
var _curr: Array[Vector3] = []
var _refresh_left := 0.0
var _hit_left := {} # peer_id -> giây còn chớp / còn hiện "-1"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_physics_priority = 100 # ghi vị trí sau khi trận đã di chuyển nhân vật
	EventBus.player_hit.connect(func(id: int, _a: int, _hp: int) -> void: _hit_left[id] = POP_TIME)


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_INTERVAL
		_entities.clear()
		for n in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
			_entities.append(n as EntityBase)
		_prev.resize(_entities.size())
		_curr.resize(_entities.size())
		for i in _entities.size():
			_curr[i] = _entities[i].global_position
			_prev[i] = _curr[i]
	for id: int in _hit_left.keys():
		_hit_left[id] -= delta
		if _hit_left[id] <= 0.0:
			_hit_left.erase(id)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	for i in _entities.size():
		if is_instance_valid(_entities[i]):
			_prev[i] = _curr[i]
			_curr[i] = _entities[i].global_position
			if _prev[i].distance_squared_to(_curr[i]) > SNAP_DIST * SNAP_DIST:
				_prev[i] = _curr[i] # dịch chuyển: nhảy luôn


func _draw() -> void:
	var rules := GameState.rules
	var cam := get_viewport().get_camera_3d()
	if rules == null or cam == null:
		return
	var my_role := GameState.my_role()
	var me := multiplayer.get_unique_id()
	var font := get_theme_default_font()
	var frac := Engine.get_physics_interpolation_fraction()
	for i in _entities.size():
		var e := _entities[i]
		if not is_instance_valid(e) or not e.is_visible_in_tree() or e.is_out():
			continue
		var head := _prev[i].lerp(_curr[i], frac) + Vector3.UP * HEAD_HEIGHT
		if cam.is_position_behind(head):
			continue
		var p := rules.record(e.peer_id)
		if p == null or p.max_hp <= 0:
			continue
		var color := OWN if e.peer_id == me else (ALLY if int(e.role) == my_role else ENEMY)
		var at := cam.unproject_position(head)
		var width := p.max_hp * PIP_W + (p.max_hp - 1) * PIP_GAP
		var left := at.x - width / 2.0
		draw_rect(Rect2(left - 2.0, at.y - 2.0, width + 4.0, PIP_H + 4.0), BORDER)
		var hit: float = _hit_left.get(e.peer_id, 0.0)
		var flash := hit > POP_TIME - FLASH_TIME
		for k in p.max_hp:
			var c := color if k < p.hp else EMPTY
			if flash and k == p.hp:
				c = Color.WHITE # ô vừa mất
			draw_rect(Rect2(left + k * (PIP_W + PIP_GAP), at.y, PIP_W, PIP_H), c)
		if hit > 0.0 and font:
			var t := 1.0 - hit / POP_TIME
			var pop := Color(1.0, 0.35, 0.2, 1.0 - t * t)
			var spot := Vector2(at.x + width / 2.0 + 4.0, at.y - 4.0 - 26.0 * t)
			draw_string_outline(font, spot, "-1", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color(0, 0, 0, pop.a))
			draw_string(font, spot, "-1", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, pop)
