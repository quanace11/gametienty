extends Control
## Điều khiển cảm ứng (chơi được cả bằng chuột): cần di chuyển bên trái, nút
## lớn bên phải, thanh thẻ đạo cụ có giá tiền ở giữa dưới.
## Cần di chuyển nổi: đặt ngón ở đâu trong nửa trái màn hình thì cần hiện ngay
## dưới ngón đó (không phải nhắm đúng vòng tròn); thả tay thì về chỗ cũ.
## Mọi nút tránh tai thỏ / lỗ camera / góc bo (vùng an toàn của điện thoại).
## App bị ẩn (có cuộc gọi, kéo thanh thông báo) thì nhả hết nút, khỏi kẹt chạy.
## Thợ săn: nút phải là cần ngắm. Kéo ra thì máy mình hiện luồng xanh chỉ
## hướng bắn, thả tay là bắn; kéo về giữa hoặc thả tay trên nút "Hủy" thì không bắn;
## chạm nhanh là tự nhắm / túm người gục. Phía trên cần ngắm có nút TRÓI: sáng
## lên khi có đệ tử đang gục trong tầm túm, chạm là trói người đó kéo đi (bấm
## interact như phím E); không ai trong tầm thì nút mờ, chạm không làm gì (không
## lỡ phóng kiếm). Người trốn: vòng căn hiện ra thì chạm
## bất kỳ chỗ trống nào trên màn hình để căn; giữ nút phải để cạy rương,
## đỡ đồng đội; đã thoát / bị loại thì nút phải thành nút đổi người xem.
## Thẻ ném được (túi cứu, lựu đạn, đệm lò xo, bẫy, hộp gỗ: ItemData.aim_range > 0)
## dùng kiểu kỹ năng định hướng: giữ thẻ rồi kéo, dưới đất hiện vòng tầm xa nhất
## quanh nhân vật và vòng chỗ sẽ rơi (đúng bán kính vùng tác dụng); thả tay mới
## dùng. Kéo tới nút "Hủy" rồi thả thì thôi; chạm nhanh (không kéo) thì dùng ngay
## dưới chân. Thẻ khác chạm là dùng.
## Máy tính (không có màn hình cảm ứng): WASD / mũi tên để đi, hoặc giữ chuột
## trái ở chỗ trống thì nhân vật đi tới con trỏ (bấm đúng cần trái thì vẫn kéo cần
## như cảm ứng). Phím 1..5 (card_N): thẻ ném được thì giữ phím, vòng chỗ rơi bám
## theo con trỏ chuột, thả phím là ném; chuột phải hoặc Esc thì thôi. Thẻ khác bấm là dùng.
## Chỉ bấm các action trong InputMap (move_*, aim_*, interact, skill_N) mà
## LocalInputSource đọc, không gọi thẳng vào nhân vật hay luật.

const STICK_R := 95.0
const MOVE_ZONE := 0.45 # phần bề ngang bên trái nhận cần di chuyển nổi
const MOVE_ZONE_TOP := 0.28 # phía trên mức này (theo chiều cao) để dành cho bảng HUD
const AIM_R := 75.0
const KNOB_R := 36.0
const MARGIN := 150.0 # tâm cần cách mép dưới / mép bên
const CANCEL_R := 40.0
const CANCEL_OFFSET := Vector2(-150, -130) # nút Hủy so với tâm cần ngắm
const CARD_SIZE := Vector2(108, 108)
const CARD_ICON := 42.0
const CARD_GAP := 10.0
const TAP_TIME := 0.25 # giây: chạm nhanh hơn chừng này mà không kéo là "chạm"
const PULSE_TIME := 0.15 # giây giữ nút khi chạm (để server kịp nhận)
const REDRAW_INTERVAL := 0.1
const CARD_DRAG_R := 110.0 # px kéo từ giữa thẻ thì ném xa nhất
const CARD_DEAD := 0.15 # kéo ít hơn chừng này (phần của CARD_DRAG_R) thì coi như chạm, dùng dưới chân
const RING_STEPS := 40
const BIND_R := 46.0
const BIND_OFFSET := Vector2(-20, -178) # nút Trói so với tâm cần ngắm
const BIND_RANGE := 1.5 # mét, khớp tầm túm người gục của nhân vật (PICKUP_RANGE)
const WALK_STOP := 0.3 # mét: đi bằng chuột, tới gần con trỏ chừng này thì đứng lại
const CARD_KEYS: Array[StringName] = [&"card_1", &"card_2", &"card_3", &"card_4", &"card_5"] # phím ô thẻ (LocalInputSource)

const MOUSE_FINGER := -1
const INK := Color(0.12, 0.1, 0.16)
const UiTheme = preload("res://UI/ui_theme.gd")
const ItemIcons = preload("res://UI/item_icons.gd")

var _fingers := {} # chỉ số ngón -> "move" | "aim" | "button"
var _move := Vector2.ZERO
var _move_origin := Vector2.ZERO # tâm cần đang dùng (chỗ đặt ngón), ZERO = chỗ mặc định
var _inset := Vector4.ZERO # lề an toàn trái / trên / phải / dưới
var _aim := Vector2.ZERO
var _aim_started := 0.0
var _aim_max := 0.0
var _over_cancel := false
var _card_slot := -1 # thẻ đang giữ kéo (-1 = không)
var _card_center := Vector2.ZERO
var _card_aim := Vector2.ZERO # hướng + độ xa 0..1 (trục màn hình = trục x, z thế giới)
var _card_cancel := false
var _ring_points := PackedVector2Array()
var _me_entity: Node3D
var _redraw_left := 0.0
var _item_names := {}
var _touch := false
var _pie_points := PackedVector2Array()
var _bind_ready := false # có đệ tử đang gục trong tầm trói (tính 10 lần/giây)
var _rescue_id := 0 # đệ tử: đồng môn đang gục trong tầm đỡ (0 = không ai, tính 10 lần/giây)
var _card_key := false # thẻ đang ngắm bằng phím 1..5 theo con trỏ chuột (không phải kéo thẻ)
var _walking := false # đang giữ chuột trái ở chỗ trống: đi tới con trỏ

static var _card_ready: StyleBoxFlat
static var _card_idle: StyleBoxFlat


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE # tự xử lý trong _input, chỗ trống thì minimap vẫn nhận
	_touch = DisplayServer.is_touchscreen_available()
	_update_inset()
	get_viewport().size_changed.connect(_update_inset)
	for size: int in [14, 15, 16, 18, 20, 30]: # các cỡ chữ vẽ tay ở dưới: vẽ sẵn lúc vào trận
		RenderWarmup.register_text(get_theme_default_font(), size)


func _update_inset() -> void:
	_inset = UiTheme.safe_insets(get_viewport())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_release_all() # ngón tay rời màn hình lúc app bị ẩn thì không có sự kiện nhả


func _process(delta: float) -> void:
	_redraw_left -= delta
	if _walking:
		_update_walk()
	if _card_key and _card_slot >= 0:
		_card_aim = _mouse_card_aim(_card_slot)
	if _redraw_left <= 0.0 or _card_slot >= 0 or _walking: # đang kéo thẻ: vòng dưới đất bám theo nhân vật từng frame
		_redraw_left = REDRAW_INTERVAL
		var downed := _downed_in_reach()
		_bind_ready = _hunter() and downed != 0
		_rescue_id = 0 if _hunter() else downed
		queue_redraw()


func _input(event: InputEvent) -> void:
	if GameState.rules == null or GameState.my_role() < 0: # server riêng không chơi, hoặc hết trận
		_release_all()
		return
	if event is InputEventKey:
		_on_key(event as InputEventKey)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _card_key:
		_end_key_card() # chuột phải lúc đang giữ phím thẻ: thôi không ném
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		_on_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position)
	elif _touch and event.device == InputEvent.DEVICE_ID_EMULATION:
		return # chuột giả lập từ cảm ứng: bỏ qua cho khỏi tính hai lần (chuột thật vẫn dùng được)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_touch(MOUSE_FINGER, event.position, event.pressed)
	elif event is InputEventMouseMotion and _fingers.has(MOUSE_FINGER):
		_on_drag(MOUSE_FINGER, event.position)


func _exit_tree() -> void:
	_release_all()


## Nhả mọi nút đang giữ (hết trận, rời màn hình) để trận sau không bị kẹt nút.
func _release_all() -> void:
	_card_cancel = true # đang kéo thẻ thì bỏ, không ném
	for finger: int in _fingers.keys():
		_release(finger)
	if _card_key:
		_end_key_card()


## Phím thẻ 1..5: thẻ ném được thì giữ để ngắm theo chuột, thả là ném; thẻ khác bấm là dùng.
func _on_key(ev: InputEventKey) -> void:
	if ev.echo:
		return
	if _card_key and InputMap.has_action(&"card_cancel") and ev.is_action_pressed(&"card_cancel"):
		_end_key_card()
		return
	for slot in CARD_KEYS.size():
		if not InputMap.has_action(CARD_KEYS[slot]) or not ev.is_action(CARD_KEYS[slot]):
			continue
		if ev.pressed:
			_key_card_down(slot)
		elif _card_key and _card_slot == slot:
			if not _card_cancel and GameState.rules != null:
				_use_card(slot, _mouse_card_aim(slot))
			_end_key_card()
		return


func _key_card_down(slot: int) -> void:
	if _spectating() or _card_slot >= 0: # đang kéo một thẻ khác thì thôi
		return
	if not _aimable(slot):
		_pulse(InputSource.SKILL_ACTIONS[slot])
		return
	_card_slot = slot
	_card_key = true
	_card_cancel = false
	_card_aim = _mouse_card_aim(slot)
	queue_redraw()


func _end_key_card() -> void:
	_card_key = false
	_card_slot = -1
	queue_redraw()


## Chỗ con trỏ chuột trên thẻ ô `slot`: hướng + độ xa 0..1 so với tầm ném (trục x, z thế giới).
func _mouse_card_aim(slot: int) -> Vector2:
	var me := _me()
	var body := _my_entity()
	if me == null or body == null or slot >= me.deck.size():
		return Vector2.ZERO
	var range_m := float(GameState.rules.catalog.get(me.deck[slot], {}).get("aim_range", 0.0))
	var ground: Variant = _mouse_ground(body)
	if ground == null or range_m <= 0.0:
		return Vector2.ZERO
	var d: Vector3 = (ground as Vector3) - body.global_position
	return (Vector2(d.x, d.z) / range_m).limit_length(1.0)


## Điểm trên mặt sàn (ngang chân nhân vật) dưới con trỏ chuột, null nếu không chiếu được.
func _mouse_ground(body: Node3D) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var m := get_viewport().get_mouse_position()
	return Plane(Vector3.UP, body.global_position.y).intersects_ray(cam.project_ray_origin(m), cam.project_ray_normal(m))


## Đi bằng chuột: bấm hướng từ nhân vật tới chỗ con trỏ (cập nhật từng frame vì nhân vật đi).
func _update_walk() -> void:
	var body := _my_entity()
	var ground: Variant = _mouse_ground(body) if body else null
	if ground == null:
		return
	var d: Vector3 = (ground as Vector3) - body.global_position
	var v := Vector2(d.x, d.z)
	_press_axis(&"move_left", &"move_right", &"move_up", &"move_down", v.normalized() if v.length() > WALK_STOP else Vector2.ZERO)


func _on_touch(finger: int, pos: Vector2, pressed: bool) -> void:
	if not pressed:
		if _fingers.has(finger):
			_release(finger)
			get_viewport().set_input_as_handled()
		return
	var kind := ""
	if _hunter() and not _spectating() and pos.distance_to(_bind_center()) <= BIND_R * 1.2:
		if _downed_in_reach() != 0: # tính lại lúc chạm, khỏi lệch 0,1 giây
			_pulse(&"interact")
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
	if pos.distance_to(_aim_center()) <= AIM_R * 1.4:
		if _spectating():
			_pulse(&"spectate_next")
			get_viewport().set_input_as_handled()
			return
		kind = "aim" if _hunter() else "button"
	else:
		var slot := -1 if _spectating() else _card_at(pos)
		if slot >= 0:
			get_viewport().set_input_as_handled()
			if _card_slot >= 0: # đang kéo một thẻ: ngón khác chạm thẻ thì bỏ qua
				return
			if not _aimable(slot):
				_pulse(InputSource.SKILL_ACTIONS[slot])
				return
			kind = "card"
			_card_slot = slot
			_card_center = _card_rect(slot).get_center()
			_card_aim = Vector2.ZERO
			_card_cancel = false
		elif finger == MOUSE_FINGER and not _touch and not _spectating() and not _in_qte() \
				and pos.distance_to(_move_center()) > STICK_R * 1.3 and get_viewport().gui_get_hovered_control() == null:
			kind = "walk" # máy tính: giữ chuột trái chỗ trống thì đi tới con trỏ
		elif not _spectating() and _in_move_zone(pos) and not _fingers.values().has("move"):
			kind = "move"
			_move_origin = _clamp_stick(pos)
			if _in_qte(): # vòng căn đang chạy: chạm bên trái cũng là căn
				_pulse(&"interact")
		else:
			if _in_qte(): # vòng căn đang chạy: chạm bất kỳ đâu là căn (như bấm E)
				_pulse(&"interact")
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
		"walk":
			_walking = true
			_update_walk()
	get_viewport().set_input_as_handled()
	queue_redraw()


func _on_drag(finger: int, pos: Vector2) -> void:
	match _fingers.get(finger, ""):
		"move":
			_set_move(pos)
		"aim":
			_set_aim(pos)
		"card":
			_card_aim = ((pos - _card_center) / CARD_DRAG_R).limit_length(1.0)
			_card_cancel = pos.distance_to(_cancel_center()) <= CANCEL_R * 1.3
		_:
			return
	get_viewport().set_input_as_handled()
	queue_redraw()


func _release(finger: int) -> void:
	var kind: String = _fingers[finger]
	_fingers.erase(finger)
	match kind:
		"move", "walk":
			_move = Vector2.ZERO
			_move_origin = Vector2.ZERO
			_walking = false
			for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
				Input.action_release(a)
		"aim":
			var tap := Time.get_ticks_msec() / 1000.0 - _aim_started < TAP_TIME and _aim_max < 0.3
			_aim = Vector2.ZERO
			_over_cancel = false
			for a: StringName in [&"aim_left", &"aim_right", &"aim_up", &"aim_down", &"aim_hold", &"aim_cancel"]:
				Input.action_release(a)
			if tap and GameState.rules != null:
				_pulse(&"interact") # chạm nhanh: tự nhắm, hoặc túm người đang gục
		"button":
			Input.action_release(&"interact")
		"card":
			if not _card_cancel and GameState.rules != null:
				_use_card(_card_slot, _card_aim if _card_aim.length() >= CARD_DEAD else Vector2.ZERO)
			_card_slot = -1
	queue_redraw()


## Thả thẻ: giữ chỗ ném (item_*) cùng lúc bấm skill_N để server đọc trong cùng gói input.
func _use_card(slot: int, aim: Vector2) -> void:
	if not InputMap.has_action(&"item_left"): # máy này bot chơi, không đọc nút
		return
	_press_axis(&"item_left", &"item_right", &"item_up", &"item_down", aim)
	_pulse(InputSource.SKILL_ACTIONS[slot])
	get_tree().create_timer(PULSE_TIME).timeout.connect(func() -> void:
		for a: StringName in [&"item_left", &"item_right", &"item_up", &"item_down"]:
			Input.action_release(a))


func _set_move(pos: Vector2) -> void:
	_move = ((pos - _stick_center()) / STICK_R).limit_length(1.0)
	_press_axis(&"move_left", &"move_right", &"move_up", &"move_down", _move)


func _set_aim(pos: Vector2) -> void:
	_aim = ((pos - _aim_center()) / AIM_R).limit_length(1.0)
	_aim_max = maxf(_aim_max, _aim.length())
	_over_cancel = pos.distance_to(_cancel_center()) <= CANCEL_R * 1.3
	if _over_cancel: # chỉ hủy khi ngón tay đang nằm trên nút; kéo ra khỏi nút thì ngắm tiếp
		Input.action_press(&"aim_cancel")
	else:
		Input.action_release(&"aim_cancel")
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
	_build_styles()
	var font := get_theme_default_font()
	var aiming := false
	var held := false
	for kind: String in _fingers.values():
		aiming = aiming or kind == "aim"
		held = held or kind == "button"
	if _spectating(): # đã ra khỏi trận: chỉ còn nút đổi người xem
		var sc := _aim_center()
		draw_circle(sc, AIM_R + 3, INK)
		draw_circle(sc, AIM_R, UiTheme.BLUE)
		draw_circle(sc + Vector2(-AIM_R * 0.3, -AIM_R * 0.35), AIM_R * 0.28, Color(1, 1, 1, 0.25))
		_text(font, sc, "Đổi người\nxem" if _touch else "Tab\nĐổi người xem", 20, Color.WHITE)
		return
	# Cần di chuyển: đế tròn viền đậm, núm có vệt sáng.
	var mc := _stick_center()
	draw_circle(mc, STICK_R + 3, Color(INK, 0.5))
	draw_circle(mc, STICK_R, Color(0.2, 0.3, 0.45, 0.35))
	draw_arc(mc, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	_knob(mc + _move * STICK_R, Color(0.4, 0.75, 1.0))
	if not _touch:
		_text(font, mc + Vector2(0, STICK_R + 22), "WASD / giữ chuột trái", 16, Color(1, 1, 1, 0.8))
	if _walking:
		_draw_walk_target()
	# Nút phải.
	var ac := _aim_center()
	if _hunter():
		draw_circle(ac, AIM_R + 3, Color(INK, 0.5))
		draw_circle(ac, AIM_R, Color(0.65, 0.25, 0.85, 0.3 if aiming else 0.2)) # tím ma khí
		draw_arc(ac, AIM_R, 0, TAU, 48, Color(1, 1, 1, 0.55), 3.0)
		var k := ac + _aim * AIM_R
		_knob(k, Color(0.7, 0.35, 0.95))
		# Tâm ngắm vẽ trên núm.
		draw_arc(k, 13, 0, TAU, 20, Color.WHITE, 3.0)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(k + d * 8, k + d * 20, Color.WHITE, 3.0)
		_bind_button(font, me)
		if not aiming:
			_text(font, ac + Vector2(0, AIM_R + 18), "PHI KIẾM", 18, Color.WHITE)
		elif _card_slot < 0:
			_cancel_button(font, _over_cancel)
	else:
		_action_button(font, ac, held)
	_draw_cards(me, font)
	if _card_slot >= 0 and _card_slot < me.deck.size():
		_draw_card_aim(me, font)


## Nút hành động của đệ tử, đổi theo tình huống cho biết lúc này bấm thì làm gì:
## vòng căn đang chạy thì vàng "CĂN!"; có đồng môn gục trong tầm thì xanh sáng
## "ĐỠ DẬY" kèm vòng tiến độ đỡ; không có gì thì mờ (giải trận linh là tự động khi đứng trong trận).
func _action_button(font: Font, ac: Vector2, held: bool) -> void:
	var key := "" if _touch else "E · "
	if _in_qte():
		draw_circle(ac, AIM_R + 3, INK)
		draw_circle(ac, AIM_R, UiTheme.GOLD.darkened(0.15 if held else 0.0))
		draw_arc(ac, AIM_R + 9, 0, TAU, 40, Color(1, 0.95, 0.6, 0.9), 4.0)
		_text(font, ac, "CĂN!", 30, Color.WHITE)
		_text(font, ac + Vector2(0, AIM_R + 18), key + "chạm đúng lúc", 16, Color.WHITE)
		return
	var target := GameState.rules.record(_rescue_id) if _rescue_id != 0 else null
	if target:
		draw_circle(ac, AIM_R + 3, INK)
		draw_circle(ac, AIM_R, UiTheme.GREEN.darkened(0.15 if held else 0.0))
		draw_circle(ac + Vector2(-AIM_R * 0.3, -AIM_R * 0.35), AIM_R * 0.28, Color(1, 1, 1, 0.25))
		draw_arc(ac, AIM_R + 9, 0, TAU, 40, Color(INK, 0.6), 7.0)
		if target.rescue_progress > 0.0:
			draw_arc(ac, AIM_R + 9, -PI / 2, -PI / 2 + TAU * target.rescue_progress, 40, UiTheme.GOLD, 7.0)
		_hand_icon(ac + Vector2(0, -16), Color.WHITE)
		_text(font, ac + Vector2(0, 20), "ĐỠ DẬY", 20, Color.WHITE)
		_text(font, ac + Vector2(0, AIM_R + 22), key + "giữ để đỡ", 16, Color.WHITE)
		return
	draw_circle(ac, AIM_R + 3, Color(INK, 0.5))
	draw_circle(ac, AIM_R, Color(0.35, 0.4, 0.45, 0.45))
	_hand_icon(ac + Vector2(0, -16), Color(1, 1, 1, 0.5))
	_text(font, ac + Vector2(0, 20), "Đỡ", 18, Color(1, 1, 1, 0.6))
	if not _touch:
		_text(font, ac + Vector2(0, AIM_R + 18), "E", 16, Color(1, 1, 1, 0.6))


## Hình bàn tay đỡ: lòng bàn tay và bốn ngón.
func _hand_icon(c: Vector2, color: Color) -> void:
	draw_circle(c + Vector2(0, 4), 10, color)
	for k in 4:
		draw_line(c + Vector2(-9 + k * 6, 0), c + Vector2(-9 + k * 6, -12 + absf(k - 1.5) * 2.0), color, 4.0)
	draw_line(c + Vector2(8, 6), c + Vector2(15, -2), color, 4.0)


## Nút Trói của ma tu: đỏ thẫm khi có người gục trong tầm, mờ khi không; đang kéo người thì ghi "Đang trói".
func _bind_button(font: Font, me: PlayerRecord) -> void:
	var bc := _bind_center()
	var carrying := me.carrying_id != 0
	var ready := _bind_ready and not carrying
	draw_circle(bc, BIND_R + 3, INK if ready else Color(INK, 0.5))
	draw_circle(bc, BIND_R, Color(0.75, 0.12, 0.2) if ready else Color(0.35, 0.3, 0.38, 0.55))
	if ready:
		draw_circle(bc + Vector2(-BIND_R * 0.3, -BIND_R * 0.35), BIND_R * 0.28, Color(1, 1, 1, 0.25))
		draw_arc(bc, BIND_R + 8, 0, TAU, 40, Color(1, 0.85, 0.3, 0.8), 3.0) # viền vàng: bấm được
	# Hình dây trói: hai vòng dây chéo.
	var rope := Color(1, 0.9, 0.7) if ready else Color(1, 1, 1, 0.45)
	draw_arc(bc + Vector2(-7, -10), 10, 0, TAU, 16, rope, 3.0)
	draw_arc(bc + Vector2(7, -10), 10, 0, TAU, 16, rope, 3.0)
	_text(font, bc + Vector2(0, 16), "ĐANG TRÓI" if carrying else "TRÓI", 15 if carrying else 18, Color.WHITE if ready or carrying else Color(1, 1, 1, 0.6))


## Id đệ tử đang gục trong tầm trói / đỡ của mình, 0 nếu không có (đọc trạng thái từ GameState, vị trí từ nhân vật).
func _downed_in_reach() -> int:
	var me := _me()
	var body := _my_entity() as EntityBase
	if me == null or body == null or me.carrying_id != 0 or not (me.is_hunter() or GameTypes.is_active(me.state)):
		return 0
	var at := body.flat_position()
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e == body or e.is_hunter():
			continue
		var rec := GameState.rules.record(e.peer_id)
		if rec and rec.state == GameTypes.PlayerState.DOWNED and at.distance_to(e.flat_position()) <= BIND_RANGE:
			return e.peer_id
	return 0


func _cancel_button(font: Font, over: bool) -> void:
	var cc := _cancel_center()
	draw_circle(cc, CANCEL_R + 3, INK)
	draw_circle(cc, CANCEL_R, Color(0.95, 0.3, 0.25) if over else Color(0.55, 0.2, 0.2, 0.85))
	draw_line(cc + Vector2(-12, -12), cc + Vector2(12, 12), Color.WHITE, 5.0)
	draw_line(cc + Vector2(12, -12), cc + Vector2(-12, 12), Color.WHITE, 5.0)
	_text(font, cc + Vector2(0, CANCEL_R + 16), "Hủy", 16, Color.WHITE)


## Đi bằng chuột: vòng nhỏ trên mặt sàn chỗ con trỏ.
func _draw_walk_target() -> void:
	var body := _my_entity()
	var cam := get_viewport().get_camera_3d()
	var ground: Variant = _mouse_ground(body) if body else null
	if cam and ground != null and _ground_ring(cam, ground as Vector3, 0.35):
		draw_polyline(_ring_points, Color(0.6, 0.9, 1.0, 0.9), 3.0, true)


## Đang kéo thẻ: vòng tầm xa nhất quanh nhân vật và vòng chỗ rơi vẽ trên mặt
## sàn (chiếu từ camera), cần nhỏ ở thẻ, nút Hủy.
func _draw_card_aim(me: PlayerRecord, font: Font) -> void:
	var info: Dictionary = GameState.rules.catalog.get(me.deck[_card_slot], {})
	var cam := get_viewport().get_camera_3d()
	var body := _my_entity()
	if cam and body:
		var range_m := float(info.get("aim_range", 0.0))
		var area := maxf(float(info.get("area", 0.5)), 0.3)
		var feet := body.global_position
		feet.y = 0.05
		var aim := _card_aim if _card_aim.length() >= CARD_DEAD else Vector2.ZERO
		var spot := feet + Vector3(aim.x, 0.0, aim.y) * range_m
		if _ground_ring(cam, feet, range_m):
			draw_colored_polygon(_ring_points, Color(0.45, 0.8, 1.0, 0.1))
			draw_polyline(_ring_points, Color(0.6, 0.9, 1.0, 0.85), 3.0, true)
		var tint := Color(1.0, 0.3, 0.25) if _card_cancel else Color(1.0, 0.75, 0.25)
		if _ground_ring(cam, spot, area):
			draw_colored_polygon(_ring_points, Color(tint, 0.3))
			draw_polyline(_ring_points, tint, 3.0, true)
	if _card_key: # ngắm bằng phím: không có cần ở thẻ, chỉ ghi cách hủy
		var tip := get_viewport().get_mouse_position() + Vector2(0, 34)
		_text(font, tip, "Thả phím: ném\nChuột phải / Esc: hủy", 16, Color.WHITE)
		return
	# Cần nhỏ ở thẻ: đế tròn và núm theo ngón tay.
	draw_circle(_card_center, CARD_DRAG_R, Color(INK, 0.25))
	draw_arc(_card_center, CARD_DRAG_R, 0, TAU, 40, Color(1, 1, 1, 0.5), 3.0)
	draw_circle(_card_center + _card_aim * CARD_DRAG_R, 22, INK)
	draw_circle(_card_center + _card_aim * CARD_DRAG_R, 19, Color(1.0, 0.6, 0.2))
	_cancel_button(font, _card_cancel)


## Điểm màn hình của vòng tròn bán kính `radius` mét trên mặt sàn quanh `center`
## (dùng lại một mảng). false nếu có điểm ra sau camera.
func _ground_ring(cam: Camera3D, center: Vector3, radius: float) -> bool:
	if radius <= 0.0:
		return false
	_ring_points.resize(RING_STEPS + 1)
	for k in RING_STEPS + 1:
		var a := TAU * k / RING_STEPS
		var p := center + Vector3(cos(a), 0.0, sin(a)) * radius
		if cam.is_position_behind(p):
			return false
		_ring_points[k] = cam.unproject_position(p)
	return true


func _knob(c: Vector2, color: Color) -> void:
	draw_circle(c, KNOB_R + 3, INK)
	draw_circle(c, KNOB_R, color)
	draw_circle(c + Vector2(-KNOB_R * 0.3, -KNOB_R * 0.35), KNOB_R * 0.32, Color(1, 1, 1, 0.35))


## Thanh thẻ: mỗi thẻ có biểu tượng riêng, tên, giá ở góc (viên linh thạch, đỏ
## nếu thiếu). Dùng được thì viền vàng sáng; chưa dùng được thì mờ cả thẻ. Hồi
## chiêu là phần tối quét dần như kim đồng hồ kèm số giây.
func _draw_cards(me: PlayerRecord, font: Font) -> void:
	_load_names()
	var catalog := GameState.rules.catalog
	var origin := _cards_origin(me.deck.size())
	for i in me.deck.size():
		var r := Rect2(origin + Vector2(i * (CARD_SIZE.x + CARD_GAP), 0), CARD_SIZE)
		var type: int = me.deck[i]
		var cost: int = catalog[type]["cost"]
		var cd: float = me.item_cooldowns[i]
		var afford := me.coins >= cost
		var usable := cd <= 0.0 and afford
		draw_style_box(_card_ready if usable else _card_idle, r)
		ItemIcons.draw_icon(self, type, r.position + Vector2(CARD_SIZE.x / 2, 36), CARD_ICON, not usable)
		draw_multiline_string(font, r.position + Vector2(5, 76), _item_names.get(type, "?"),
			HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x - 10, 14, 2, Color.WHITE if usable else Color(1, 1, 1, 0.6))
		draw_circle(r.position + Vector2(14, 14), 11, INK)
		draw_string(font, r.position + Vector2(3, 19), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 22, 15, Color.WHITE)
		if cost > 0: # giá: viên linh thạch góc phải trên
			var cc := r.position + Vector2(CARD_SIZE.x - 15, 15)
			draw_circle(cc, 14, INK)
			draw_circle(cc, 12, UiTheme.GOLD if afford else Color(0.85, 0.3, 0.28))
			draw_string(font, cc + Vector2(-14, 6), str(cost), HORIZONTAL_ALIGNMENT_CENTER, 28, 16,
				INK if afford else Color.WHITE)
		if cd > 0.0: # đang hồi chiêu: quạt tối + số giây đè lên biểu tượng
			var total: float = maxf(catalog[type].get("cooldown", cd), cd)
			_pie(r.position + Vector2(CARD_SIZE.x / 2, 36), CARD_ICON * 0.75, cd / total)
			_text(font, r.position + Vector2(CARD_SIZE.x / 2, 36), "%d" % ceili(cd), 30, Color.WHITE)


## Hình quạt tối phủ lên thẻ đang hồi chiêu (phần còn lại theo tỉ lệ `left`).
func _pie(c: Vector2, radius: float, left: float) -> void:
	var steps := 24
	_pie_points.resize(steps + 2)
	_pie_points[0] = c
	for k in steps + 1:
		var a := -PI / 2 + TAU * left * k / steps
		_pie_points[k + 1] = c + Vector2(cos(a), sin(a)) * radius
	draw_colored_polygon(_pie_points, Color(0, 0, 0, 0.55))


func _build_styles() -> void:
	if _card_ready:
		return
	_card_ready = UiTheme.panel(Color(0.2, 0.26, 0.42, 0.95), 14, 4)
	_card_ready.border_color = UiTheme.GOLD
	_card_idle = UiTheme.panel(Color(0.22, 0.24, 0.3, 0.75), 14, 3)


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


func _card_rect(slot: int) -> Rect2:
	var me := _me()
	var origin := _cards_origin(me.deck.size() if me else 0)
	return Rect2(origin + Vector2(slot * (CARD_SIZE.x + CARD_GAP), 0), CARD_SIZE)


## Thẻ ô `slot` kéo-thả được: có tầm ném, đang dùng được (hết hồi chiêu, đủ tiền).
## Chưa dùng được thì chạm như thường (server từ chối, không mất gì).
func _aimable(slot: int) -> bool:
	var me := _me()
	if me == null or slot >= me.deck.size():
		return false
	var info: Dictionary = GameState.rules.catalog.get(me.deck[slot], {})
	return float(info.get("aim_range", 0.0)) > 0.0 and me.item_cooldowns[slot] <= 0.0 \
		and me.coins >= int(info.get("cost", 0))


## Nhân vật của máy này (tìm theo group, nhớ lại).
func _my_entity() -> Node3D:
	if is_instance_valid(_me_entity):
		return _me_entity
	_me_entity = null
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		if (node as EntityBase).peer_id == GameState.my_id():
			_me_entity = node as Node3D
	return _me_entity


## Nút Hủy: thợ săn ngắm thì cạnh cần ngắm; kéo thẻ thì ở mép phải giữa màn hình,
## xa thanh thẻ để kéo hết tầm không chạm nhầm.
func _cancel_center() -> Vector2:
	if _card_slot >= 0:
		var s := get_viewport_rect().size
		return Vector2(s.x - 90 - _inset.z, s.y * 0.45)
	return _aim_center() + CANCEL_OFFSET


## Thanh thẻ nằm sát bên trái nút phải, cách mép dưới một chút.
func _cards_origin(count: int) -> Vector2:
	var w := count * CARD_SIZE.x + (count - 1) * CARD_GAP
	var screen := get_viewport_rect().size
	return Vector2(_aim_center().x - AIM_R - 40 - w, screen.y - CARD_SIZE.y - 16 - _inset.w)


func _move_center() -> Vector2:
	return Vector2(MARGIN + _inset.x, get_viewport_rect().size.y - MARGIN - _inset.w)


## Tâm cần di chuyển: chỗ đặt ngón khi đang giữ, không thì chỗ mặc định.
func _stick_center() -> Vector2:
	return _move_origin if _move_origin != Vector2.ZERO else _move_center()


## Chạm ở nửa trái, dưới các bảng HUD trên cùng thì là cần di chuyển.
func _in_move_zone(pos: Vector2) -> bool:
	var s := get_viewport_rect().size
	return pos.x < s.x * MOVE_ZONE and pos.y > s.y * MOVE_ZONE_TOP


## Cần nổi không vẽ lòi ra ngoài mép màn hình.
func _clamp_stick(pos: Vector2) -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(clampf(pos.x, STICK_R + _inset.x + 8, s.x - STICK_R),
		clampf(pos.y, STICK_R + _inset.y + 8, s.y - STICK_R - _inset.w - 8))


func _bind_center() -> Vector2:
	return _aim_center() + BIND_OFFSET


func _aim_center() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(s.x - MARGIN + 20 - _inset.z, s.y - MARGIN + 20 - _inset.w)


func _me() -> PlayerRecord:
	return GameState.rules.record(GameState.my_id()) if GameState.rules else null


func _in_qte() -> bool:
	var me := _me()
	return me != null and me.qte_chest >= 0


## Mình đã thoát / bị loại: nút phải thành nút đổi người xem (camera đọc spectate_next).
func _spectating() -> bool:
	var me := _me()
	return me != null and (me.state == GameTypes.PlayerState.ESCAPED or me.state == GameTypes.PlayerState.ELIMINATED)


func _hunter() -> bool:
	return GameState.my_role() == GameTypes.Role.HUNTER


func _load_names() -> void:
	if not _item_names.is_empty():
		return
	var items: Dictionary = load(ModuleRegistry.ITEM_CATALOG).call(&"all")
	for type: int in items:
		_item_names[type] = items[type].display_name
