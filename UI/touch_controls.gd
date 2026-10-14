extends Control
## Điều khiển cảm ứng (chơi được cả bằng chuột): cần di chuyển bên trái, nút
## lớn bên phải, thanh thẻ đạo cụ có giá tiền ở giữa dưới.
## Thợ săn: nút phải là cần ngắm. Kéo ra thì máy mình hiện luồng xanh chỉ
## hướng bắn, thả tay là bắn; kéo về giữa hoặc kéo vào nút "Hủy" thì không bắn;
## chạm nhanh là tự nhắm / túm người gục. Người trốn: giữ nút phải để cạy rương,
## đỡ đồng đội.
## Chỉ bấm các action trong InputMap (move_*, aim_*, interact, skill_N) mà
## LocalInputSource đọc, không gọi thẳng vào nhân vật hay luật.

const STICK_R := 85.0
const AIM_R := 75.0
const KNOB_R := 36.0
const MARGIN := 150.0 # tâm cần cách mép dưới / mép bên
const CANCEL_R := 40.0
const CANCEL_OFFSET := Vector2(-150, -130) # nút Hủy so với tâm cần ngắm
const CARD_SIZE := Vector2(108, 92)
const CARD_GAP := 10.0
const TAP_TIME := 0.25 # giây: chạm nhanh hơn chừng này mà không kéo là "chạm"
const PULSE_TIME := 0.15 # giây giữ nút khi chạm (để server kịp nhận)
const REDRAW_INTERVAL := 0.1

const MOUSE_FINGER := -1

var _fingers := {} # chỉ số ngón -> "move" | "aim" | "button"
var _move := Vector2.ZERO
var _aim := Vector2.ZERO
var _aim_started := 0.0
var _aim_max := 0.0
var _over_cancel := false
var _redraw_left := 0.0
var _item_names := {}
var _touch := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE # tự xử lý trong _input, chỗ trống thì minimap vẫn nhận
	_touch = DisplayServer.is_touchscreen_available()


func _process(delta: float) -> void:
	_redraw_left -= delta
	if _redraw_left <= 0.0:
		_redraw_left = REDRAW_INTERVAL
		queue_redraw()


func _input(event: InputEvent) -> void:
	if GameState.rules == null or GameState.my_role() < 0: # server riêng không chơi
		return
	if event is InputEventScreenTouch:
		_on_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position)
	elif _touch:
		return # trên điện thoại chuột là giả lập từ cảm ứng: bỏ qua cho khỏi tính hai lần
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_touch(MOUSE_FINGER, event.position, event.pressed)
	elif event is InputEventMouseMotion and _fingers.has(MOUSE_FINGER):
		_on_drag(MOUSE_FINGER, event.position)


func _on_touch(finger: int, pos: Vector2, pressed: bool) -> void:
	if not pressed:
		if _fingers.has(finger):
			_release(finger)
			get_viewport().set_input_as_handled()
		return
	var kind := ""
	if pos.distance_to(_move_center()) <= STICK_R * 1.6:
		kind = "move"
	elif pos.distance_to(_aim_center()) <= AIM_R * 1.4:
		kind = "aim" if _hunter() else "button"
	else:
		var slot := _card_at(pos)
		if slot >= 0:
			_pulse(InputSource.SKILL_ACTIONS[slot])
			get_viewport().set_input_as_handled()
		return
	_fingers[finger] = kind
	match kind:
		"move":
			_set_move(pos)
		"aim":
			_aim_started = Time.get_ticks_msec() / 1000.0
			_aim_max = 0.0
			Input.action_press(&"aim_hold")
			_set_aim(pos)
		"button":
			Input.action_press(&"interact")
	get_viewport().set_input_as_handled()
	queue_redraw()


func _on_drag(finger: int, pos: Vector2) -> void:
	match _fingers.get(finger, ""):
		"move":
			_set_move(pos)
		"aim":
			_set_aim(pos)
		_:
			return
	get_viewport().set_input_as_handled()
	queue_redraw()


func _release(finger: int) -> void:
	var kind: String = _fingers[finger]
	_fingers.erase(finger)
	match kind:
		"move":
			_move = Vector2.ZERO
			for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
				Input.action_release(a)
		"aim":
			var tap := Time.get_ticks_msec() / 1000.0 - _aim_started < TAP_TIME and _aim_max < 0.3
			_aim = Vector2.ZERO
			_over_cancel = false
			for a: StringName in [&"aim_left", &"aim_right", &"aim_up", &"aim_down", &"aim_hold", &"aim_cancel"]:
				Input.action_release(a)
			if tap:
				_pulse(&"interact") # chạm nhanh: tự nhắm, hoặc túm người đang gục
		"button":
			Input.action_release(&"interact")
	queue_redraw()


func _set_move(pos: Vector2) -> void:
	_move = ((pos - _move_center()) / STICK_R).limit_length(1.0)
	_press_axis(&"move_left", &"move_right", &"move_up", &"move_down", _move)


func _set_aim(pos: Vector2) -> void:
	_aim = ((pos - _aim_center()) / AIM_R).limit_length(1.0)
	_aim_max = maxf(_aim_max, _aim.length())
	_over_cancel = pos.distance_to(_aim_center() + CANCEL_OFFSET) <= CANCEL_R * 1.3
	if _over_cancel:
		Input.action_press(&"aim_cancel")
	_press_axis(&"aim_left", &"aim_right", &"aim_up", &"aim_down", _aim)


func _press_axis(left: StringName, right: StringName, up: StringName, down: StringName, v: Vector2) -> void:
	for pair: Array in [[left, -v.x], [right, v.x], [up, -v.y], [down, v.y]]:
		if pair[1] > 0.0:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


## Bấm rồi nhả sau PULSE_TIME giây (chạm thẻ, chạm nhanh nút bắn).
func _pulse(action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	Input.action_press(action)
	get_tree().create_timer(PULSE_TIME).timeout.connect(func() -> void: Input.action_release(action))


func _draw() -> void:
	var me := _me()
	if me == null:
		return
	var accent := Color(0.35, 0.8, 1.0)
	# Cần di chuyển.
	var mc := _move_center()
	draw_circle(mc, STICK_R, Color(accent, 0.12))
	draw_arc(mc, STICK_R, 0, TAU, 48, Color(accent, 0.6), 3.0)
	draw_circle(mc + _move * STICK_R, KNOB_R, Color(accent, 0.55))
	# Nút phải.
	var ac := _aim_center()
	var font := get_theme_default_font()
	if _hunter():
		var aiming := _fingers.values().has("aim")
		draw_circle(ac, AIM_R, Color(accent, 0.2 if aiming else 0.12))
		draw_arc(ac, AIM_R, 0, TAU, 48, Color(accent, 0.7), 3.0)
		draw_circle(ac + _aim * AIM_R, KNOB_R, Color(1, 0.75, 0.2, 0.85))
		_text(font, ac + _aim * AIM_R, "BẮN", 18, Color.BLACK)
		if aiming:
			var cc := ac + CANCEL_OFFSET
			draw_circle(cc, CANCEL_R, Color(1, 0.3, 0.25, 0.6 if _over_cancel else 0.3))
			_text(font, cc, "Hủy", 18, Color.WHITE)
	else:
		var held := _fingers.values().has("button")
		draw_circle(ac, AIM_R, Color(0.3, 0.9, 0.4, 0.35 if held else 0.2))
		draw_arc(ac, AIM_R, 0, TAU, 48, Color(0.3, 0.9, 0.4, 0.8), 3.0)
		_text(font, ac, "E\nCạy / Đỡ", 18, Color.WHITE)
	_draw_cards(me, font)


## Thanh thẻ: tên, giá (vàng, đỏ nếu thiếu tiền), số giây hồi chiêu phủ tối.
func _draw_cards(me: PlayerRecord, font: Font) -> void:
	_load_names()
	var catalog := GameState.rules.catalog
	var origin := _cards_origin(me.deck.size())
	if not me.is_hunter():
		_text(font, origin + Vector2(60, -16), "● %d xu" % me.coins, 22, Color(1, 0.85, 0.3))
	for i in me.deck.size():
		var r := Rect2(origin + Vector2(i * (CARD_SIZE.x + CARD_GAP), 0), CARD_SIZE)
		var cost: int = catalog[me.deck[i]]["cost"]
		var cd: float = me.item_cooldowns[i]
		draw_rect(r, Color(0.08, 0.1, 0.13, 0.85))
		draw_rect(r, Color(0.35, 0.8, 1.0, 0.5), false, 2.0)
		draw_string(font, r.position + Vector2(6, 18), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.5))
		draw_multiline_string(font, r.position + Vector2(4, 38), _item_names.get(me.deck[i], "?"),
			HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x - 8, 15, 2, Color.WHITE)
		if cost > 0:
			_text(font, r.position + Vector2(CARD_SIZE.x / 2, CARD_SIZE.y - 14), "● %d" % cost, 16,
				Color(1, 0.85, 0.3) if me.coins >= cost else Color(1, 0.35, 0.3))
		if cd > 0.0:
			draw_rect(r, Color(0, 0, 0, 0.6))
			_text(font, r.get_center(), "%d" % ceili(cd), 28, Color.WHITE)


func _text(font: Font, center: Vector2, text: String, size_px: int, color: Color) -> void:
	var lines := text.split("\n")
	var y := center.y - (lines.size() - 1) * size_px * 0.6 + size_px * 0.35
	for line in lines:
		draw_string(font, Vector2(center.x - 100, y), line, HORIZONTAL_ALIGNMENT_CENTER, 200, size_px, color)
		y += size_px * 1.2


func _card_at(pos: Vector2) -> int:
	var me := _me()
	if me == null:
		return -1
	var origin := _cards_origin(me.deck.size())
	for i in me.deck.size():
		if Rect2(origin + Vector2(i * (CARD_SIZE.x + CARD_GAP), 0), CARD_SIZE).has_point(pos):
			return i
	return -1


## Thanh thẻ nằm sát bên trái nút phải, cách mép dưới một chút.
func _cards_origin(count: int) -> Vector2:
	var w := count * CARD_SIZE.x + (count - 1) * CARD_GAP
	var screen := get_viewport_rect().size
	return Vector2(_aim_center().x - AIM_R - 40 - w, screen.y - CARD_SIZE.y - 16)


func _move_center() -> Vector2:
	return Vector2(MARGIN, get_viewport_rect().size.y - MARGIN)


func _aim_center() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(s.x - MARGIN + 20, s.y - MARGIN + 20)


func _me() -> PlayerRecord:
	return GameState.rules.record(multiplayer.get_unique_id()) if GameState.rules else null


func _hunter() -> bool:
	return GameState.my_role() == GameTypes.Role.HUNTER


func _load_names() -> void:
	if not _item_names.is_empty():
		return
	var items: Dictionary = load(ModuleRegistry.ITEM_CATALOG).call(&"all")
	for type: int in items:
		_item_names[type] = items[type].display_name
