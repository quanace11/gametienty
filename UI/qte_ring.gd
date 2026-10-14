extends Control
## Vòng căn khi cạy rương: kim chạy quanh vòng, vùng sáng đậm ở giữa, vùng mờ
## hai bên. Chỉ vẽ theo dữ liệu GameState (qte_zone, qte_started, elapsed);
## việc chấm điểm do server làm khi người chơi bấm E.

const RADIUS := 70.0
const WIDTH := 14.0

var _flash := 0.0
var _flash_color := Color.WHITE
var _flash_text := ""


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2 + 40, RADIUS * 2 + 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.qte_resolved.connect(_on_resolved)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()


func _draw() -> void:
	var rules := GameState.rules
	if rules == null:
		return
	var me := rules.record(multiplayer.get_unique_id())
	var center := size / 2.0
	if _flash > 0.0:
		draw_string(get_theme_default_font(), center + Vector2(-60, RADIUS + 40), _flash_text,
			HORIZONTAL_ALIGNMENT_CENTER, 120, 22, _flash_color)
	if me == null or me.qte_chest < 0:
		return
	var cfg := rules.config
	draw_arc(center, RADIUS, 0, TAU, 64, Color(1, 1, 1, 0.25), WIDTH)
	_draw_zone(center, me.qte_zone, cfg.qte_good_width, Color(0.3, 0.9, 0.4, 0.45))
	_draw_zone(center, me.qte_zone, cfg.qte_perfect_width, Color(0.5, 1.0, 0.55, 1.0))
	var needle := clampf(rules.qte_needle(me.id), 0.0, 1.0)
	var a := _angle(needle)
	draw_line(center, center + Vector2(cos(a), sin(a)) * (RADIUS + WIDTH), Color(1, 0.3, 0.2), 4.0)
	draw_string(get_theme_default_font(), center + Vector2(-60, RADIUS + 40), "Bấm E!", HORIZONTAL_ALIGNMENT_CENTER, 120, 22)


func _draw_zone(center: Vector2, zone: float, half: float, color: Color) -> void:
	draw_arc(center, RADIUS, _angle(zone - half), _angle(zone + half), 24, color, WIDTH)


## 0 ở đỉnh vòng, chạy theo chiều kim đồng hồ.
func _angle(fraction: float) -> float:
	return -PI / 2.0 + fraction * TAU


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
