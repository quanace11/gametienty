extends Control
## Vòng căn khi cạy rương, vẽ nằm trên sàn quanh nhân vật của máy này: vòng mờ,
## vùng trắng sáng (hoàn hảo) và vùng nhạt (được) trên vòng, kim đỏ quay từ
## giữa. Chỉ vẽ theo dữ liệu GameState (qte_zone, qte_started, elapsed);
## việc chấm điểm do server làm khi người chơi bấm E.

const RADIUS_M := 1.6 # mét, bán kính vòng trên sàn
const WIDTH := 7.0
const RING := Color(1, 1, 1, 0.3)
const GOOD := Color(1, 1, 1, 0.45)
const PERFECT := Color(1, 1, 1, 1.0)
const NEEDLE := Color(1, 0.2, 0.15)
const OUTLINE := Color(0.12, 0.1, 0.16)

var _flash := 0.0
var _flash_color := Color.WHITE
var _flash_text := ""
var _me_node: Node3D
var _drawn := false # frame trước có vẽ gì không (không có gì thì khỏi vẽ lại)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.qte_resolved.connect(_on_resolved)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	var me := GameState.rules.record(multiplayer.get_unique_id()) if GameState.rules else null
	var show := _flash > 0.0 or (me != null and me.qte_chest >= 0)
	if show or _drawn:
		queue_redraw()
	_drawn = show


func _draw() -> void:
	var rules := GameState.rules
	var cam := get_viewport().get_camera_3d()
	var node := _my_node()
	if rules == null or cam == null or node == null:
		return
	var feet := node.global_position + Vector3(0, 0.05, 0)
	if cam.is_position_behind(feet):
		return
	var center := cam.unproject_position(feet)
	var font := get_theme_default_font()
	var rx := (cam.unproject_position(feet + Vector3(RADIUS_M, 0, 0)) - center).length()
	var ry := (cam.unproject_position(feet + Vector3(0, 0, RADIUS_M)) - center).length()
	if _flash > 0.0: # cao hơn dòng "Bấm E" để hai chữ không đè nhau khi vòng mới hiện ngay
		var p := center + Vector2(-120, -ry - 104)
		draw_string_outline(font, p, _flash_text, HORIZONTAL_ALIGNMENT_CENTER, 240, 28, 8, OUTLINE)
		draw_string(font, p, _flash_text, HORIZONTAL_ALIGNMENT_CENTER, 240, 28, _flash_color)
	var me := rules.record(multiplayer.get_unique_id())
	if me == null or me.qte_chest < 0 or rx <= 1.0:
		return
	var cfg := rules.config
	var hint := center + Vector2(-120, -ry - 70)
	draw_string_outline(font, hint, "Bấm E / nút xanh!", HORIZONTAL_ALIGNMENT_CENTER, 240, 24, 7, OUTLINE)
	draw_string(font, hint, "Bấm E / nút xanh!", HORIZONTAL_ALIGNMENT_CENTER, 240, 24)
	# Vòng nằm trên sàn: vẽ hình tròn bán kính rx rồi ép dọc theo phối cảnh camera.
	draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	draw_arc(Vector2.ZERO, rx, 0, TAU, 64, RING, WIDTH)
	_draw_zone(rx, me.qte_zone, cfg.qte_good_width, GOOD)
	_draw_zone(rx, me.qte_zone, cfg.qte_perfect_width, PERFECT)
	var a := _angle(clampf(rules.qte_needle(me.id), 0.0, 1.0))
	var tip := Vector2(cos(a), sin(a)) * (rx + WIDTH)
	draw_line(Vector2.ZERO, tip, Color(NEEDLE, 0.3), 14.0)
	draw_line(Vector2.ZERO, tip, NEEDLE, 5.0)
	draw_set_transform(Vector2.ZERO)


func _draw_zone(r: float, zone: float, half: float, color: Color) -> void:
	draw_arc(Vector2.ZERO, r, _angle(zone - half), _angle(zone + half), 24, color, WIDTH + 3.0)


## 0 ở phía trên (xa camera), chạy theo chiều kim đồng hồ.
func _angle(fraction: float) -> float:
	return -PI / 2.0 + fraction * TAU


func _my_node() -> Node3D:
	if is_instance_valid(_me_node):
		return _me_node
	var my_id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		if (node as EntityBase).peer_id == my_id:
			_me_node = node as Node3D
	return _me_node


func _on_resolved(id: int, _safe_id: int, result: GameTypes.QteResult) -> void:
	if id != multiplayer.get_unique_id():
		return
	_flash = 1.0
	match result:
		GameTypes.QteResult.PERFECT:
			_flash_text = "Hoàn hảo! +tốc"
			_flash_color = Color(0.5, 1.0, 0.55)
		GameTypes.QteResult.GOOD:
			_flash_text = "Được, +tiền"
			_flash_color = Color(0.9, 0.9, 0.5)
		_:
			_flash_text = "ĐOÀNG! Hỏng"
			_flash_color = Color(1, 0.3, 0.2)
