extends Control
## Vòng căn khi cạy rương, vẽ nằm trên sàn quanh nhân vật của máy này: vòng mờ,
## vùng trắng sáng (hoàn hảo) và vùng nhạt (được) trên vòng, kim đỏ quay từ
## giữa. Vòng hiện ra kiểu bung từ chân ra ngoài, màn hình tối đi một chút cho
## vòng nổi bật; cạnh vùng sáng có chữ nhắc chạm màn hình. Chỉ vẽ theo dữ liệu
## GameState (qte_zone, qte_started, elapsed); việc chấm điểm do server làm khi
## người chơi bấm (E, hoặc chạm bất kỳ đâu trên màn hình: touch_controls bấm hộ).

const RADIUS_M := 2.2 # mét, bán kính vòng trên sàn
const WIDTH := 9.0
const APPEAR_TIME := 0.3 # giây vòng bung ra
const DIM := Color(0, 0, 0, 0.3) # phủ tối màn hình lúc có vòng
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
var _ring_for := -1.0 # qte_started của vòng đang vẽ
var _ring_age := 0.0 # giây từ lúc vòng hiện


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.qte_resolved.connect(_on_resolved)
	RenderWarmup.register_text(get_theme_default_font(), 28, 8) # chữ vẽ tay: vẽ sẵn lúc vào trận
	RenderWarmup.register_text(get_theme_default_font(), 24, 7)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	var me := GameState.rules.record(GameState.my_id()) if GameState.rules else null
	var ring := me != null and me.qte_chest >= 0
	if ring and me.qte_started != _ring_for:
		_ring_for = me.qte_started
		_ring_age = 0.0
	_ring_age += delta
	var show := _flash > 0.0 or ring
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
	if _flash > 0.0: # phía trên vòng, không đè chữ nhắc cạnh vùng sáng
		var p := center + Vector2(-160, -ry - 104)
		draw_string_outline(font, p, _flash_text, HORIZONTAL_ALIGNMENT_CENTER, 320, 28, 8, OUTLINE)
		draw_string(font, p, _flash_text, HORIZONTAL_ALIGNMENT_CENTER, 320, 28, _flash_color)
	var me := rules.record(GameState.my_id())
	if me == null or me.qte_chest < 0 or rx <= 1.0:
		return
	var cfg := rules.config
	# Bung ra: to dần từ 40% lên đủ, hơi vượt rồi về (ease back).
	var k := clampf(_ring_age / APPEAR_TIME, 0.0, 1.0)
	var grow := 0.4 + 0.6 * (1.0 + 2.2 * pow(k - 1.0, 3) + 1.2 * pow(k - 1.0, 2))
	var r := rx * grow
	draw_rect(get_viewport_rect(), Color(DIM, DIM.a * k))
	# Vòng nằm trên sàn: vẽ hình tròn bán kính r rồi ép dọc theo phối cảnh camera.
	draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 0.06 * k))
	draw_arc(Vector2.ZERO, r, 0, TAU, 72, Color(OUTLINE, 0.5 * k), WIDTH + 6.0)
	draw_arc(Vector2.ZERO, r, 0, TAU, 72, Color(RING, RING.a * k), WIDTH)
	var pulse := 0.75 + 0.25 * sin(_ring_age * 10.0)
	_draw_zone(r, me.qte_zone, cfg.qte_good_width + 0.01, Color(1, 0.95, 0.6, 0.25 * k), WIDTH + 16.0) # quầng sáng
	_draw_zone(r, me.qte_zone, cfg.qte_good_width, Color(GOOD, GOOD.a * k), WIDTH + 3.0)
	_draw_zone(r, me.qte_zone, cfg.qte_perfect_width, Color(PERFECT, pulse * k), WIDTH + 7.0)
	var a := _angle(clampf(rules.qte_needle(me.id), 0.0, 1.0))
	var tip := Vector2(cos(a), sin(a)) * (r + WIDTH)
	draw_line(Vector2.ZERO, tip, Color(NEEDLE, 0.3 * k), 16.0)
	draw_line(Vector2.ZERO, tip, Color(NEEDLE, k), 6.0)
	draw_circle(Vector2.ZERO, 9.0, Color(NEEDLE, k))
	draw_set_transform(Vector2.ZERO)
	# Chữ nhắc cạnh vùng sáng, phía ngoài vòng, có mũi tên chỉ vào.
	var za := _angle(me.qte_zone)
	var dir := Vector2(cos(za), sin(za) * ry / rx)
	var edge := center + dir * (r + 14.0)
	var label_at := center + dir * (r + 70.0)
	draw_line(label_at.lerp(edge, 0.35), edge, Color(1, 0.85, 0.3, k), 4.0)
	var hint := "Kim tới đây thì\nchạm màn hình!"
	var y := label_at.y - 20.0
	for line in hint.split("\n"):
		var p := Vector2(label_at.x - 110, y)
		draw_string_outline(font, p, line, HORIZONTAL_ALIGNMENT_CENTER, 220, 24, 7, Color(OUTLINE, k))
		draw_string(font, p, line, HORIZONTAL_ALIGNMENT_CENTER, 220, 24, Color(1, 0.88, 0.35, k))
		y += 28.0


func _draw_zone(r: float, zone: float, half: float, color: Color, width: float) -> void:
	draw_arc(Vector2.ZERO, r, _angle(zone - half), _angle(zone + half), 24, color, width)


## 0 ở phía trên (xa camera), chạy theo chiều kim đồng hồ.
func _angle(fraction: float) -> float:
	return -PI / 2.0 + fraction * TAU


func _my_node() -> Node3D:
	if is_instance_valid(_me_node):
		return _me_node
	var my_id := GameState.my_id()
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		if (node as EntityBase).peer_id == my_id:
			_me_node = node as Node3D
	return _me_node


func _on_resolved(id: int, _safe_id: int, result: GameTypes.QteResult) -> void:
	if id != GameState.my_id():
		return
	_flash = 1.0
	match result:
		GameTypes.QteResult.PERFECT:
			_flash_text = "Hoàn hảo! +tốc"
			_flash_color = Color(0.5, 1.0, 0.55)
		GameTypes.QteResult.GOOD:
			_flash_text = "Được! +linh thạch"
			_flash_color = Color(0.9, 0.9, 0.5)
		_:
			_flash_text = "Trượt! Mở lại từ đầu"
			_flash_color = Color(1, 0.3, 0.2)
