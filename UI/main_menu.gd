extends CanvasLayer
## Menu chính và sảnh chờ kiểu game chibi: nền trời, bảng bo tròn, nút màu
## to dễ bấm trên điện thoại. Chỉ gọi API công khai của Net.
## Chọn bộ bài người trốn (tối đa DECK_SIZE thẻ) trước khi vào trận: lưu vào
## Net.my_deck, server gửi kèm thông tin trận. Thợ săn dùng bộ bài cố định.

const DECK_SIZE := 5 # khớp MatchConfig.deck_size
const UiTheme = preload("res://UI/ui_theme.gd")

var match_time := 180.0
var _deck_checks := {} # ItemType -> Button (ô thẻ bật/tắt)
var _deck_order := [] # thứ tự chọn = thứ tự ô 1..5
var _deck_label: Label

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _online_row: HBoxContainer
var _offline_row: HBoxContainer
var _lobby: Label
var _fill_bots: CheckBox
var _start_btn: Button
var _leave_btn: Button
var _status: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	root.add_child(_Backdrop.new())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	center.add_child(row)

	# Cột trái: tên game, tên người chơi, chọn vai, chơi qua mạng.
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(470, 0)
	row.add_child(left)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	left.add_child(box)

	var title := Label.new()
	title.text = "TIỀN TỶ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.add_theme_constant_override("outline_size", 14)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Rượt đuổi 1 thợ săn vs 4 người trốn"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	box.add_child(sub)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Tên của bạn"
	_name_edit.text = Net.my_name if Net.my_name != "Player" else "Người chơi %d" % (randi() % 1000)
	box.add_child(_name_edit)

	_offline_row = HBoxContainer.new()
	_offline_row.add_theme_constant_override("separation", 12)
	box.add_child(_offline_row)
	var hunt := _add_button(_offline_row, "THỢ SĂN", func() -> void: _offline(GameTypes.Role.HUNTER))
	UiTheme.color_button(hunt, UiTheme.RED)
	var run := _add_button(_offline_row, "NGƯỜI TRỐN", func() -> void: _offline(GameTypes.Role.ESCAPEE))
	for b: Button in [hunt, run]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		b.add_theme_font_size_override("font_size", 26)

	var online_title := Label.new()
	online_title.text = "Chơi qua mạng LAN"
	online_title.add_theme_font_size_override("font_size", 18)
	online_title.modulate = Color(1, 1, 1, 0.75)
	box.add_child(online_title)
	_online_row = HBoxContainer.new()
	_online_row.add_theme_constant_override("separation", 8)
	box.add_child(_online_row)
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.placeholder_text = "IP chủ phòng"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_online_row.add_child(_ip_edit)
	var host := _add_button(_online_row, "Tạo phòng", func() -> void:
		Net.my_name = _player_name()
		Net.host(Net.PORT, true))
	UiTheme.color_button(host, UiTheme.GREEN)
	_add_button(_online_row, "Vào", func() -> void:
		Net.my_name = _player_name()
		Net.join(_ip_edit.text.strip_edges(), Net.PORT))

	_lobby = Label.new()
	box.add_child(_lobby)

	_fill_bots = CheckBox.new()
	_fill_bots.text = "Thêm bot cho đủ 5 người"
	_fill_bots.button_pressed = true
	_fill_bots.toggled.connect(func(_on: bool) -> void: refresh())
	box.add_child(_fill_bots)

	_start_btn = _add_button(box, "Bắt đầu trận", func() -> void: Net.start_match(match_time, _fill_bots.button_pressed))
	UiTheme.color_button(_start_btn, UiTheme.GREEN)
	_leave_btn = _add_button(box, "Rời phòng", func() -> void: Net.leave())
	UiTheme.color_button(_leave_btn, UiTheme.MUTED)

	_status = Label.new()
	_status.modulate = Color(1, 1, 1, 0.75)
	_status.add_theme_font_size_override("font_size", 16)
	box.add_child(_status)

	# Cột phải: bộ bài người trốn.
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(430, 0)
	row.add_child(right)
	var deck_box := VBoxContainer.new()
	deck_box.add_theme_constant_override("separation", 10)
	right.add_child(deck_box)
	_build_deck_picker(deck_box)

	Net.players_changed.connect(refresh)
	Net.disconnected.connect(refresh)
	Net.status.connect(func(msg: String) -> void: _status.text = msg)
	refresh()


func refresh() -> void:
	var online := Net.is_online()
	_offline_row.visible = not online
	_online_row.visible = not online
	_name_edit.editable = not online
	_ip_edit.editable = not online
	var names: PackedStringArray = []
	for id: int in Net.players:
		names.append("• " + str(Net.players[id]["name"]) + (" (chủ phòng)" if id == 1 else ""))
	_lobby.text = ("Trong phòng (%d/%d):\n%s" % [Net.players.size(), Net.MAX_PLAYERS, "\n".join(names)]) if online else ""
	var can_start := online and multiplayer.is_server()
	_fill_bots.visible = can_start
	_start_btn.visible = can_start
	_start_btn.disabled = Net.players.size() < 2 and not _fill_bots.button_pressed
	_leave_btn.visible = online


func _build_deck_picker(box: VBoxContainer) -> void:
	var catalog: Script = load(ModuleRegistry.ITEM_CATALOG)
	var items: Dictionary = catalog.call(&"all")
	_deck_order = catalog.call(&"default_deck", GameTypes.Role.ESCAPEE)
	if not Net.my_deck.is_empty():
		_deck_order = Net.my_deck.duplicate()
	_deck_label = Label.new()
	_deck_label.add_theme_font_size_override("font_size", 24)
	box.add_child(_deck_label)
	var hint := Label.new()
	hint.text = "Chạm để chọn / bỏ. Thứ tự chọn là ô 1-%d trong trận." % DECK_SIZE
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(1, 1, 1, 0.75)
	box.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for type: int in catalog.call(&"choices", GameTypes.Role.ESCAPEE):
		var it: ItemData = items[type]
		var tile := Button.new()
		tile.toggle_mode = true
		tile.custom_minimum_size = Vector2(196, 74)
		tile.add_theme_font_size_override("font_size", 17)
		tile.set_meta(&"label", "%s\n● %d xu · hồi %ds" % [it.display_name, it.cost, roundi(it.cooldown)])
		tile.button_pressed = type in _deck_order
		tile.toggled.connect(func(on: bool) -> void: _on_deck_toggled(type, on))
		grid.add_child(tile)
		_deck_checks[type] = tile
	_update_deck()


func _on_deck_toggled(type: int, on: bool) -> void:
	if on and type not in _deck_order:
		if _deck_order.size() >= DECK_SIZE:
			_deck_checks[type].set_pressed_no_signal(false) # đủ ô rồi, bỏ bớt thẻ khác trước
			return
		_deck_order.append(type)
	elif not on:
		_deck_order.erase(type)
	_update_deck()


## Thẻ đã chọn màu vàng có số ô, thẻ chưa chọn màu xám.
func _update_deck() -> void:
	Net.my_deck = _deck_order.duplicate()
	_deck_label.text = "Bộ bài người trốn  %d/%d" % [_deck_order.size(), DECK_SIZE]
	for type: int in _deck_checks:
		var tile: Button = _deck_checks[type]
		var slot := _deck_order.find(type)
		tile.text = ("%d. " % (slot + 1) if slot >= 0 else "") + str(tile.get_meta(&"label"))
		UiTheme.color_button(tile, Color(0.95, 0.62, 0.15) if slot >= 0 else UiTheme.MUTED)


func _offline(role: GameTypes.Role) -> void:
	Net.my_name = _player_name()
	Net.start_offline(match_time, role)


func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Người chơi"


func _add_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


## Nền trời xanh chuyển màu với vài đám mây và bãi cỏ, vẽ một lần (không chạy _process).
class _Backdrop extends Control:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var s := size
		var top := Color(0.45, 0.75, 0.98)
		var bottom := Color(0.75, 0.9, 1.0)
		var bands := 12
		for i in bands:
			var y0 := s.y * i / bands
			draw_rect(Rect2(0, y0, s.x, s.y / bands + 1), top.lerp(bottom, float(i) / (bands - 1)))
		for c: Vector3 in [Vector3(0.12, 0.18, 1.0), Vector3(0.85, 0.12, 0.8), Vector3(0.6, 0.3, 0.6)]:
			var p := Vector2(s.x * c.x, s.y * c.y)
			for k in 3:
				draw_circle(p + Vector2(k * 44 - 44, -abs(k - 1) * -14) * c.z, 42 * c.z, Color(1, 1, 1, 0.85))
		draw_circle(Vector2(s.x * 0.5, s.y * 2.1), s.y * 1.3, Color(0.4, 0.75, 0.35))
		draw_circle(Vector2(s.x * 0.05, s.y * 1.6), s.y * 0.75, Color(0.35, 0.68, 0.32))
