extends CanvasLayer
## Menu chính và sảnh chờ. Chỉ gọi API công khai của Net.
## Chọn bộ bài người trốn (tối đa DECK_SIZE thẻ) trước khi vào trận: lưu vào
## Net.my_deck, server gửi kèm thông tin trận. Thợ săn dùng bộ bài cố định.

const DECK_SIZE := 5 # khớp MatchConfig.deck_size

var match_time := 180.0
var _deck_checks := {} # ItemType -> CheckBox
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
	var box := VBoxContainer.new()
	box.position = Vector2(40, 40)
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "Game Tiền Tỷ (bản nền)"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Tên của bạn"
	_name_edit.text = Net.my_name if Net.my_name != "Player" else "Người chơi %d" % (randi() % 1000)
	box.add_child(_name_edit)

	_build_deck_picker(box)

	_offline_row = HBoxContainer.new()
	box.add_child(_offline_row)
	_add_button(_offline_row, "Offline: làm Thợ săn", func() -> void: _offline(GameTypes.Role.HUNTER))
	_add_button(_offline_row, "Offline: làm Người trốn", func() -> void: _offline(GameTypes.Role.ESCAPEE))

	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.placeholder_text = "IP chủ phòng"
	box.add_child(_ip_edit)

	_online_row = HBoxContainer.new()
	box.add_child(_online_row)
	_add_button(_online_row, "Tạo phòng", func() -> void:
		Net.my_name = _player_name()
		Net.host(Net.PORT, true))
	_add_button(_online_row, "Vào phòng", func() -> void:
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
	_leave_btn = _add_button(box, "Rời phòng", func() -> void: Net.leave())

	_status = Label.new()
	_status.modulate = Color(1, 1, 1, 0.7)
	box.add_child(_status)

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
	box.add_child(_deck_label)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for type: int in catalog.call(&"choices", GameTypes.Role.ESCAPEE):
		var it: ItemData = items[type]
		var cb := CheckBox.new()
		cb.text = "%s (%d xu, hồi %ds)" % [it.display_name, it.cost, roundi(it.cooldown)]
		cb.button_pressed = type in _deck_order
		cb.toggled.connect(func(on: bool) -> void: _on_deck_toggled(type, on))
		grid.add_child(cb)
		_deck_checks[type] = cb
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


func _update_deck() -> void:
	Net.my_deck = _deck_order.duplicate()
	_deck_label.text = "Bộ bài người trốn (%d/%d thẻ, phím 1-%d theo thứ tự chọn):" % [
		_deck_order.size(), DECK_SIZE, DECK_SIZE]


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
