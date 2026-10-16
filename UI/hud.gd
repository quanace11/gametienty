extends CanvasLayer
## HUD trong trận kiểu game chibi: thanh trên giữa (đồng hồ, chìa khóa, cổng),
## hàng đầu người trốn (màu theo trạng thái), thẻ vai + máu + tiền góc trái,
## dải trạng thái của mình khi bị gục / kéo / nhốt, và thông báo nổi ở giữa.
## Hướng dẫn điều khiển chỉ hiện vài giây đầu trận. Chỉ đọc GameState.rules và
## nghe EventBus, không đổi gì. Cập nhật 10 lần/giây, chữ chỉ đặt lại khi đổi.
## Server riêng (không chơi) không dựng gì.

const UiTheme = preload("res://UI/ui_theme.gd")
const QteRing = preload("res://UI/qte_ring.gd")
const Minimap = preload("res://UI/minimap.gd")
const ResultsScreen = preload("res://UI/results_screen.gd")
const TouchControls = preload("res://UI/touch_controls.gd")
const ALERT_TIME := 3.0
const HINT_TIME := 7.0
const UPDATE_INTERVAL := 0.1

var _root: Control
var _timer: Label
var _keys: Label
var _keys_bar: _Bar
var _gate: Label
var _gate_panel: PanelContainer
var _team: _TeamRow
var _role: Label
var _hearts: _Hearts
var _coins: Label
var _status: Label
var _status_panel: PanelContainer
var _toast: Label
var _toast_panel: PanelContainer
var _toast_left := 0.0
var _hint_left := HINT_TIME
var _update_left := 0.0
var _touch: Control
var _minimap: Control


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or GameState.my_role() < 0:
		set_process(false) # server riêng: không ai nhìn HUD
		return
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	_root.add_child(QteRing.new())
	_touch = TouchControls.new()
	_root.add_child(_touch)
	_minimap = Minimap.new()
	_root.add_child(_minimap)
	_build_top_bar()
	_build_player_card()
	_build_banners()
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.teleport_started.connect(func(id: int, _t: Vector3, s: float) -> void:
		if id != multiplayer.get_unique_id() and GameState.my_role() == GameTypes.Role.ESCAPEE:
			_show_toast("Ma tu huyết độn tới cột tím sau %.1f giây!" % s, UiTheme.RED))
	EventBus.footprints_revealed.connect(func(_p: PackedVector3Array, _s: float) -> void:
		_show_toast("Ma tu dò thần thức: dấu chân đỏ trên bản đồ", UiTheme.RED))
	EventBus.qte_resolved.connect(func(_id: int, safe_id: int, result: GameTypes.QteResult) -> void:
		if result == GameTypes.QteResult.FAIL:
			_show_toast("Trận linh %d vừa bùng!" % (safe_id + 1), UiTheme.RED))
	EventBus.gate_opening.connect(func(_s: float) -> void: _show_toast("Đã giải đủ trận linh! 2 lối ra đang mở...", UiTheme.GREEN))
	EventBus.gate_opened.connect(func() -> void: _show_toast("LỐI RA ĐÃ MỞ! Chạy ra lối ra!", UiTheme.GREEN))
	_show_toast(_hint_text(), UiTheme.BLUE, HINT_TIME)


func _process(delta: float) -> void:
	_toast_left -= delta
	if _toast_left <= 0.0 and _toast_panel.visible:
		_toast_panel.visible = false
	_update_left -= delta
	if _update_left > 0.0:
		return
	_update_left = UPDATE_INTERVAL
	var rules := GameState.rules
	if rules == null:
		return
	_refresh(rules)


func _refresh(rules: MatchRules) -> void:
	var t := ceili(rules.time_left)
	if rules.state == GameTypes.MatchState.COUNTDOWN:
		_set_text(_timer, "Bắt đầu sau %d" % ceili(rules.countdown_left))
	else:
		_set_text(_timer, "%d:%02d" % [t / 60, t % 60])
	_timer.add_theme_color_override("font_color", UiTheme.RED if t <= 30 else Color.WHITE)
	_set_text(_keys, "Trận linh %d/%d" % [rules.safes_unlocked(), rules.safes_required()])
	_keys_bar.set_value(float(rules.safes_unlocked()) / maxf(1.0, rules.safes_required()))
	if rules.gate_open:
		_set_gate("LỐI RA MỞ", UiTheme.GREEN)
	elif rules.gate_opening_left > 0.0:
		_set_gate("Mở sau %.0f" % ceilf(rules.gate_opening_left), UiTheme.GOLD.darkened(0.15))
	else:
		_set_gate("Lối ra phong ấn", UiTheme.MUTED)
	_team.update_from(rules)
	var me := rules.record(multiplayer.get_unique_id())
	if me == null:
		return
	_hearts.set_hp(me.hp, me.max_hp)
	_coins.get_parent().visible = not me.is_hunter()
	_set_text(_coins, "● %d" % me.coins)
	var status := _my_status(me)
	_status_panel.visible = status != ""
	_set_text(_status, status)


func _set_text(label: Label, text: String) -> void:
	if label.text != text: # đổi chữ mới dựng lại layout
		label.text = text


func _set_gate(text: String, color: Color) -> void:
	if _gate.text == text:
		return
	_gate.text = text
	_gate_panel.add_theme_stylebox_override("panel", _chip(color))


func _hint_text() -> String:
	if GameState.my_role() == GameTypes.Role.HUNTER:
		return "Kéo nút PHI KIẾM để ngắm, thả tay là phóng kiếm. Đánh gục đệ tử, bấm TRÓI rồi kéo vào huyết trận!"
	return "Đứng ở trận linh để giải, kim tới vùng sáng thì chạm màn hình (hoặc E). Giải đủ thì chạy ra lối ra!"


## Dòng trạng thái của mình; chuỗi rỗng là không có gì đặc biệt (ẩn dải).
func _my_status(me: PlayerRecord) -> String:
	if me.is_hunter():
		if me.stunned_left > 0.0:
			return "Bị choáng %.1f giây" % me.stunned_left
		if me.carrying_id != 0:
			return "Đang kéo người: mang tới huyết trận!"
		if me.teleport_left > 0.0:
			return "Đang tụ lực huyết độn %.1f giây" % me.teleport_left
		return ""
	match me.state:
		GameTypes.PlayerState.DOWNED:
			return "Bạn bị gục! Chờ đồng môn đỡ (%d%%)" % roundi(me.rescue_progress * 100)
		GameTypes.PlayerState.CARRIED:
			return "Bị kéo đi! Chờ trận bàn hồi phục hoặc phù kiếm của đồng môn"
		GameTypes.PlayerState.IMPRISONED:
			return "Trong huyết trận: bị tế huyết sau %d giây!" % ceili(me.prison_time_left)
		GameTypes.PlayerState.ELIMINATED:
			return "Bạn đã bị loại. Đang xem người khác (Tab / nút xanh để đổi)"
		GameTypes.PlayerState.ESCAPED:
			return "Bạn đã thoát! Đang xem người khác (Tab / nút xanh để đổi)"
	return ""


func _show_toast(text: String, color: Color, seconds := ALERT_TIME) -> void:
	_toast.text = text
	_toast_panel.add_theme_stylebox_override("panel", _chip(color))
	_toast_panel.visible = true
	_toast_left = seconds


## Bảng kết quả: ẩn HUD trong trận, hiện bảng giữa màn hình.
func _on_match_ended(res: Dictionary) -> void:
	for c: Control in [_touch, _minimap, _status_panel, _toast_panel]:
		c.visible = false
	set_process(false)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := ResultsScreen.new()
	center.add_child(panel)
	panel.show_result(res, multiplayer.get_unique_id())


# ---------- Dựng giao diện ----------

func _build_top_bar() -> void:
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 10
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 6)
	_root.add_child(top)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _pill(UiTheme.PANEL))
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	_timer = _label(row, "3:00", 34)
	_timer.custom_minimum_size = Vector2(96, 0)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var keys := VBoxContainer.new()
	keys.add_theme_constant_override("separation", 2)
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(keys)
	_keys = _label(keys, "Trận linh 0/3", 18)
	_keys_bar = _Bar.new()
	_keys_bar.custom_minimum_size = Vector2(110, 12)
	keys.add_child(_keys_bar)
	_gate_panel = PanelContainer.new()
	_gate_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_gate_panel)
	_gate = _label(_gate_panel, "", 18)
	_team = _TeamRow.new()
	_team.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(_team)


func _build_player_card() -> void:
	var card := PanelContainer.new()
	card.position = Vector2(12, 10)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hunter := GameState.my_role() == GameTypes.Role.HUNTER
	card.add_theme_stylebox_override("panel", _pill(UiTheme.RED if hunter else UiTheme.BLUE))
	_root.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	_role = _label(box, "MA TU" if hunter else "ĐỆ TỬ", 22)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_hearts = _Hearts.new()
	_hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hearts)
	var coin_chip := PanelContainer.new()
	coin_chip.add_theme_stylebox_override("panel", _chip(UiTheme.INK))
	row.add_child(coin_chip)
	_coins = _label(coin_chip, "● 0", 18)
	_coins.add_theme_color_override("font_color", UiTheme.GOLD)


func _build_banners() -> void:
	_status_panel = PanelContainer.new()
	_status_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status_panel.offset_top = 132
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.add_theme_stylebox_override("panel", _chip(Color(0.95, 0.5, 0.15)))
	_status_panel.visible = false
	_root.add_child(_status_panel)
	_status = _label(_status_panel, "", 22)
	_toast_panel = PanelContainer.new()
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast_panel.offset_top = -150
	_toast_panel.offset_bottom = -150
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_root.add_child(_toast_panel)
	_toast = _label(_toast_panel, "", 22)


func _label(parent: Control, text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func _pill(color: Color) -> StyleBoxFlat:
	var s := UiTheme.panel(color, 20, 3)
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.content_margin_left = 16
	s.content_margin_right = 16
	return s


static func _chip(color: Color) -> StyleBoxFlat:
	var s := UiTheme.panel(color, 14, 3)
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s


## Thanh tiến độ bo tròn (chìa khóa).
class _Bar extends Control:
	var _value := 0.0

	func set_value(v: float) -> void:
		if not is_equal_approx(v, _value):
			_value = clampf(v, 0.0, 1.0)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.45))
		if _value > 0.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _value, size.y)), Color(1.0, 0.8, 0.25))
		draw_rect(r, Color(0.12, 0.1, 0.16), false, 2.0)


## Máu: tim vẽ bằng hai hình tròn + tam giác, đỏ là còn, xám là mất.
class _Hearts extends Control:
	var _hp := -1
	var _max := 0

	func set_hp(hp: int, max_hp: int) -> void:
		if hp == _hp and max_hp == _max:
			return
		_hp = hp
		_max = max_hp
		custom_minimum_size = Vector2(maxi(max_hp, 1) * 26, 24)
		queue_redraw()

	func _draw() -> void:
		for i in _max:
			var c := Vector2(13 + i * 26, 12)
			var col := Color(1, 0.3, 0.35) if i < _hp else Color(0.35, 0.35, 0.4)
			var ink := Color(0.12, 0.1, 0.16)
			for k in 2: # viền
				var off := 1.5 if k == 0 else 0.0
				var cc := ink if k == 0 else col
				draw_circle(c + Vector2(-5, -3), 6 + off, cc)
				draw_circle(c + Vector2(5, -3), 6 + off, cc)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-11 - off, -1), c + Vector2(11 + off, -1),
					c + Vector2(0, 11 + off * 1.5)]), cc)


## Hàng đầu người trốn: mỗi người một hình tròn màu theo trạng thái.
class _TeamRow extends Control:
	const SIZE := 34.0
	const GAP := 8.0
	var _key := ""
	var _states: Array[int] = []
	var _mine: Array[bool] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func update_from(rules: MatchRules) -> void:
		var key := ""
		_states.clear()
		_mine.clear()
		var my_id := multiplayer.get_unique_id()
		for id: int in rules.players:
			var p: PlayerRecord = rules.players[id]
			if p.is_hunter():
				continue
			_states.append(p.state)
			_mine.append(id == my_id)
			key += str(p.state) + ("*" if id == my_id else ",")
		if key == _key:
			return
		_key = key
		custom_minimum_size = Vector2(_states.size() * (SIZE + GAP) - GAP, SIZE)
		queue_redraw()

	func _draw() -> void:
		var ink := Color(0.12, 0.1, 0.16)
		for i in _states.size():
			var c := Vector2(SIZE / 2 + i * (SIZE + GAP), SIZE / 2)
			draw_circle(c, SIZE / 2, ink)
			draw_circle(c, SIZE / 2 - 3, _color(_states[i]))
			if _mine[i]:
				draw_arc(c, SIZE / 2 + 1, 0, TAU, 24, Color(1.0, 0.8, 0.25), 3.0)
			match _states[i]:
				GameTypes.PlayerState.ELIMINATED:
					draw_line(c + Vector2(-7, -7), c + Vector2(7, 7), ink, 3.0)
					draw_line(c + Vector2(7, -7), c + Vector2(-7, 7), ink, 3.0)
				GameTypes.PlayerState.IMPRISONED:
					for k in 3:
						draw_line(c + Vector2(-6 + k * 6, -9), c + Vector2(-6 + k * 6, 9), ink, 2.0)
				GameTypes.PlayerState.ESCAPED:
					draw_polyline(PackedVector2Array([c + Vector2(-7, 0), c + Vector2(-2, 6), c + Vector2(8, -6)]), ink, 3.0)

	static func _color(s: int) -> Color:
		match s:
			GameTypes.PlayerState.DOWNED, GameTypes.PlayerState.CARRIED:
				return Color(0.98, 0.6, 0.2)
			GameTypes.PlayerState.IMPRISONED:
				return Color(0.65, 0.45, 0.95)
			GameTypes.PlayerState.ELIMINATED:
				return Color(0.45, 0.45, 0.5)
			GameTypes.PlayerState.ESCAPED:
				return Color(1.0, 0.8, 0.25)
		return Color(0.4, 0.75, 1.0)
