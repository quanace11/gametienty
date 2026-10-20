extends CanvasLayer
## Menu chính kiểu game chibi, gồm ba màn trên cùng một sân khấu 3D:
## - Sảnh: nhân vật đã chọn (nhớ từ lần trước, mặc định đệ tử) đứng nghỉ ở giữa,
##   tên người chơi góc trái, nút Phù bảo / Cài đặt góc phải, nút ĐỔI NHÂN VẬT và
##   BẮT ĐẦU góc phải dưới.
## - Chọn nhân vật: Tiên Môn (đệ tử) bên trái, Ma Đạo (ma tu) bên phải; chạm ô
##   nào thì sân khấu đổi ngay sang nhân vật đó, Xác nhận mới lưu.
## - Chọn chế độ: luyện công với bot (offline) hoặc phòng LAN; vai trong trận theo
##   nhân vật đang chọn.
## Đang ở trong phòng LAN thì hiện bảng phòng thay ba màn trên.
## Bộ phù bảo của đệ tử (tối đa DECK_SIZE thẻ) lưu vào Net.my_deck, server gửi kèm
## thông tin trận. Ma tu dùng bộ bài cố định. Chỉ gọi API công khai của Net.

enum Screen { LOBBY, SELECT, MODE }

const DECK_SIZE := 5 # khớp MatchConfig.deck_size
const UiTheme = preload("res://UI/ui_theme.gd")
const GraphicsSettings = preload("res://UI/graphics_settings.gd")
const CharacterRoster = preload("res://UI/character_roster.gd")
const LobbyStage = preload("res://UI/lobby_stage.gd")
const ORANGE := Color(0.98, 0.58, 0.15)
const SIDE_COLORS := {GameTypes.Role.ESCAPEE: Color(0.22, 0.62, 0.9), GameTypes.Role.HUNTER: Color(0.62, 0.2, 0.42)}

var match_time := 180.0
var _deck_checks := {} # ItemType -> Button (ô thẻ bật/tắt)
var _deck_order := [] # thứ tự chọn = thứ tự ô 1..5
var _deck_label: Label

var _character: Dictionary # nhân vật đã lưu
var _preview: Dictionary # nhân vật đang xem ở màn chọn (chưa xác nhận)
var _screen := Screen.LOBBY
var _stage: LobbyStage # null trên máy không có màn hình (server riêng, test)

var _lobby_ui: Control
var _select_ui: Control
var _mode_ui: Control
var _room_ui: Control
var _deck_ui: Control
var _settings_ui: Control
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _char_name: Label
var _char_title: Label
var _start_hint: Label
var _deck_btn: Button
var _select_cards := {} # id nhân vật -> Button
var _select_name: Label
var _select_blurb: Label
var _mode_title: Label
var _lobby: Label
var _fill_bots: CheckBox
var _start_btn: Button
var _status: Label


func _ready() -> void:
	GraphicsSettings.load_and_apply(get_viewport()) # trước khi dựng nhân vật / bản đồ
	_character = CharacterRoster.load_selected()
	_preview = _character
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	root.add_child(_Backdrop.new())
	if DisplayServer.get_name() != "headless":
		_stage = LobbyStage.new()
		root.add_child(_stage)

	var inset := UiTheme.safe_insets(get_viewport(), 18.0)
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("margin_left", int(inset.x))
	frame.add_theme_constant_override("margin_top", int(inset.y))
	frame.add_theme_constant_override("margin_right", int(inset.z))
	frame.add_theme_constant_override("margin_bottom", int(inset.w))
	root.add_child(frame)

	_lobby_ui = _layer(frame)
	_build_lobby(_lobby_ui)
	_select_ui = _layer(frame)
	_build_select(_select_ui)
	_mode_ui = _layer(frame)
	_build_mode(_mode_ui)
	_room_ui = _layer(frame)
	_build_room(_room_ui)
	_status = Label.new()
	_status.modulate = Color(1, 1, 1, 0.85)
	_status.add_theme_font_size_override("font_size", 16)
	frame.add_child(_status)
	_status.size_flags_vertical = Control.SIZE_SHRINK_END
	_status.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_deck_ui = _layer(root) # bảng phủ tối cả màn hình, ngoài lề an toàn
	_build_deck_overlay(_deck_ui)
	_settings_ui = _layer(root)
	_build_settings_overlay(_settings_ui)

	Net.players_changed.connect(refresh)
	Net.disconnected.connect(refresh)
	Net.status.connect(func(msg: String) -> void: _status.text = msg)
	_show_character(_character)
	refresh()


## Gọi lại khi danh sách phòng đổi, mất kết nối, hoặc hết trận về menu.
func refresh() -> void:
	var online := Net.is_online()
	_lobby_ui.visible = not online and _screen == Screen.LOBBY
	_select_ui.visible = not online and _screen == Screen.SELECT
	_mode_ui.visible = not online and _screen == Screen.MODE
	_room_ui.visible = online
	if online:
		_deck_ui.visible = false
		_settings_ui.visible = false
	var names: PackedStringArray = []
	for id: int in Net.players:
		names.append("• " + str(Net.players[id]["name"]) + (" (chủ phòng)" if id == 1 else ""))
	_lobby.text = "Trong phòng (%d/%d):\n%s" % [Net.players.size(), Net.MAX_PLAYERS, "\n".join(names)]
	var can_start := online and multiplayer.is_server()
	_fill_bots.visible = can_start
	_start_btn.visible = can_start
	_start_btn.disabled = Net.players.size() < 2 and not _fill_bots.button_pressed


func _go(screen: Screen) -> void:
	_screen = screen
	if _stage: # bảng chế độ nằm bên phải: dời nhân vật sang trái cho khỏi bị che
		_stage.shift_left(screen == Screen.MODE)
	refresh()


# --- Sảnh ---

func _build_lobby(layer: Control) -> void:
	# Góc trái trên: tên người chơi.
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.16, 0.2, 0.32, 0.8), 22))
	_place(layer, badge, Vector2(0, 0))
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 10)
	badge.add_child(badge_row)
	var title := Label.new()
	title.text = "TIỀN TỶ"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.add_theme_constant_override("outline_size", 10)
	badge_row.add_child(title)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Đạo hiệu của bạn"
	_name_edit.text = Net.my_name if Net.my_name != "Player" else "Đạo hữu %d" % (randi() % 1000)
	_name_edit.custom_minimum_size = Vector2(230, 0)
	_name_edit.max_length = 16
	badge_row.add_child(_name_edit)

	# Góc phải trên: phù bảo (chỉ đệ tử), cài đặt.
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	_place(layer, tools, Vector2(1, 0))
	_deck_btn = _add_button(tools, "Phù bảo", func() -> void: _deck_ui.visible = true)
	UiTheme.color_button(_deck_btn, UiTheme.GOLD.darkened(0.15))
	var gear := _add_button(tools, "Cài đặt", func() -> void: _settings_ui.visible = true)
	UiTheme.color_button(gear, UiTheme.MUTED)

	# Giữa dưới: tên nhân vật dưới chân.
	var plate := VBoxContainer.new()
	plate.add_theme_constant_override("separation", 0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(layer, plate, Vector2(0.5, 1))
	_char_name = Label.new()
	_char_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_name.add_theme_font_size_override("font_size", 34)
	_char_name.add_theme_constant_override("outline_size", 10)
	plate.add_child(_char_name)
	_char_title = Label.new()
	_char_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_title.add_theme_font_size_override("font_size", 18)
	plate.add_child(_char_title)

	# Góc phải dưới: đổi nhân vật, bắt đầu.
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	_place(layer, actions, Vector2(1, 1))
	var swap := _add_button(actions, "ĐỔI NHÂN VẬT", func() -> void:
		_preview = _character
		_update_select()
		_go(Screen.SELECT))
	UiTheme.color_button(swap, Color(0.3, 0.72, 0.98))
	swap.custom_minimum_size = Vector2(320, 70)
	swap.add_theme_font_size_override("font_size", 28)
	var start := _add_button(actions, "BẮT ĐẦU", func() -> void: _go(Screen.MODE))
	UiTheme.color_button(start, ORANGE)
	start.custom_minimum_size = Vector2(320, 100)
	start.add_theme_font_size_override("font_size", 44)
	_start_hint = Label.new()
	_start_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start_hint.add_theme_font_size_override("font_size", 17)
	actions.add_child(_start_hint)


## Đổi nhân vật trên sân khấu và chữ ở sảnh / màn chọn chế độ.
func _show_character(c: Dictionary) -> void:
	if _stage:
		_stage.show_character(c)
	var role: GameTypes.Role = c["role"]
	_char_name.text = c["name"]
	_char_name.add_theme_color_override("font_color", UiTheme.GOLD if role == GameTypes.Role.ESCAPEE else Color(1, 0.55, 0.6))
	_char_title.text = "%s · %s" % [CharacterRoster.SIDE_NAMES[role], c["title"]]
	_start_hint.text = "Tìm trận: %s" % ("đệ tử" if role == GameTypes.Role.ESCAPEE else "ma tu")
	_deck_btn.visible = role == GameTypes.Role.ESCAPEE
	_mode_title.text = "Vào trận với %s (%s)" % [c["name"], "đệ tử" if role == GameTypes.Role.ESCAPEE else "ma tu"]


# --- Chọn nhân vật ---

func _build_select(layer: Control) -> void:
	var group := ButtonGroup.new()
	for role: GameTypes.Role in [GameTypes.Role.ESCAPEE, GameTypes.Role.HUNTER]:
		var side := PanelContainer.new()
		side.add_theme_stylebox_override("panel", UiTheme.panel(Color(SIDE_COLORS[role].darkened(0.55), 0.88), 22))
		side.custom_minimum_size = Vector2(330, 0)
		_place(layer, side, Vector2(0 if role == GameTypes.Role.ESCAPEE else 1, 0.42))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		side.add_child(box)
		var head := Label.new()
		head.text = CharacterRoster.SIDE_NAMES[role]
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_theme_font_size_override("font_size", 34)
		head.add_theme_color_override("font_color", UiTheme.GOLD if role == GameTypes.Role.ESCAPEE else Color(1, 0.55, 0.6))
		box.add_child(head)
		var hint := Label.new()
		hint.text = CharacterRoster.SIDE_HINTS[role]
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 15)
		hint.modulate = Color(1, 1, 1, 0.8)
		box.add_child(hint)
		for c: Dictionary in CharacterRoster.of_role(role):
			var card := Button.new()
			card.toggle_mode = true
			card.button_group = group
			card.custom_minimum_size = Vector2(0, 76)
			card.add_theme_font_size_override("font_size", 20)
			card.text = "%s\n%s" % [c["name"], "Sắp ra mắt" if c["locked"] else c["title"]]
			card.disabled = c["locked"]
			UiTheme.color_button(card, SIDE_COLORS[role])
			card.pressed.connect(func() -> void:
				_preview = c
				_update_select())
			box.add_child(card)
			_select_cards[c["id"]] = card

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	_place(layer, info, Vector2(0.5, 1))
	_select_name = Label.new()
	_select_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_select_name.add_theme_font_size_override("font_size", 32)
	_select_name.add_theme_constant_override("outline_size", 10)
	info.add_child(_select_name)
	_select_blurb = Label.new()
	_select_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_select_blurb.add_theme_font_size_override("font_size", 17)
	info.add_child(_select_blurb)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	info.add_child(row)
	var back := _add_button(row, "Quay lại", func() -> void:
		_show_character(_character)
		_go(Screen.LOBBY))
	UiTheme.color_button(back, UiTheme.MUTED)
	var ok := _add_button(row, "XÁC NHẬN", func() -> void:
		_character = _preview
		CharacterRoster.save_selected(_character["id"])
		_show_character(_character)
		_go(Screen.LOBBY))
	UiTheme.color_button(ok, ORANGE)
	ok.custom_minimum_size = Vector2(220, 64)
	ok.add_theme_font_size_override("font_size", 28)


func _update_select() -> void:
	var card: Button = _select_cards[_preview["id"]]
	card.set_pressed_no_signal(true)
	for id: String in _select_cards:
		var b: Button = _select_cards[id]
		var c := CharacterRoster.by_id(id)
		if not b.disabled:
			UiTheme.color_button(b, ORANGE if b == card else SIDE_COLORS[c["role"]])
	_select_name.text = _preview["name"]
	_select_blurb.text = _preview["blurb"]
	if _stage:
		_stage.show_character(_preview)


# --- Chọn chế độ ---

func _build_mode(layer: Control) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	_place(layer, panel, Vector2(1, 0.5))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var head := Label.new()
	head.text = "CHỌN CHẾ ĐỘ"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 34)
	head.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(head)
	_mode_title = Label.new()
	_mode_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_title.add_theme_font_size_override("font_size", 17)
	box.add_child(_mode_title)

	var practice := _add_button(box, "Luyện công cùng bot", func() -> void:
		Net.my_name = _player_name()
		Net.start_offline(match_time, _character["role"]))
	UiTheme.color_button(practice, ORANGE)
	practice.custom_minimum_size = Vector2(0, 80)
	practice.add_theme_font_size_override("font_size", 30)

	var lan := Label.new()
	lan.text = "Đấu cùng bằng hữu (mạng LAN)"
	lan.add_theme_font_size_override("font_size", 17)
	lan.modulate = Color(1, 1, 1, 0.8)
	box.add_child(lan)
	var host := _add_button(box, "Mở động phủ (tạo phòng)", func() -> void:
		Net.my_name = _player_name()
		Net.host(Net.PORT, true))
	UiTheme.color_button(host, UiTheme.GREEN)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	box.add_child(join_row)
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.placeholder_text = "IP chủ phòng"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_ip_edit)
	_add_button(join_row, "Vào phòng", func() -> void:
		Net.my_name = _player_name()
		Net.join(_ip_edit.text.strip_edges(), Net.PORT))

	var back := _add_button(box, "Quay lại", func() -> void: _go(Screen.LOBBY))
	UiTheme.color_button(back, UiTheme.MUTED)


# --- Phòng LAN ---

func _build_room(layer: Control) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	_place(layer, panel, Vector2(1, 0.5))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_lobby = Label.new()
	box.add_child(_lobby)
	_fill_bots = CheckBox.new()
	_fill_bots.text = "Thêm bot cho đủ 5 người"
	_fill_bots.button_pressed = true
	_fill_bots.toggled.connect(func(_on: bool) -> void: refresh())
	box.add_child(_fill_bots)
	# Chủ phòng vào trận với vai của nhân vật đang chọn.
	_start_btn = _add_button(box, "Bắt đầu trận", func() -> void:
		Net.start_match(match_time, _fill_bots.button_pressed, _character["role"]))
	UiTheme.color_button(_start_btn, ORANGE)
	var leave := _add_button(box, "Rời phòng", func() -> void: Net.leave())
	UiTheme.color_button(leave, UiTheme.MUTED)


# --- Bảng phủ: phù bảo, cài đặt ---

## Bảng giữa màn hình trên nền tối, có nút Đóng; trả hộp để thêm nội dung.
func _overlay(layer: Control, title_text: String) -> VBoxContainer:
	layer.visible = false
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	_place(layer, panel, Vector2(0.5, 0.5))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	head.add_child(title)
	var close := _add_button(head, "Đóng", func() -> void: layer.visible = false)
	UiTheme.color_button(close, UiTheme.MUTED)
	return box


func _build_deck_overlay(layer: Control) -> void:
	_build_deck_picker(_overlay(layer, "Phù bảo của đệ tử"))


func _build_settings_overlay(layer: Control) -> void:
	var box := _overlay(layer, "Cài đặt")
	box.custom_minimum_size = Vector2(460, 0)
	_build_choice_row(box, "Đồ họa", GraphicsSettings.NAMES, GraphicsSettings.current(),
		func(level: int) -> void:
			GraphicsSettings.save_and_apply(get_viewport(), level)
			if _stage:
				_stage.show_character(_preview if _screen == Screen.SELECT else _character))
	_build_choice_row(box, "FPS", GraphicsSettings.FPS_NAMES, GraphicsSettings.current_fps(),
		func(choice: int) -> void: GraphicsSettings.save_and_apply_fps(choice))


func _build_deck_picker(box: VBoxContainer) -> void:
	var catalog: Script = load(ModuleRegistry.ITEM_CATALOG)
	var items: Dictionary = catalog.call(&"all")
	_deck_order = catalog.call(&"default_deck", GameTypes.Role.ESCAPEE)
	if not Net.my_deck.is_empty():
		_deck_order = Net.my_deck.duplicate()
	_deck_label = Label.new()
	_deck_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_deck_label)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for type: int in catalog.call(&"choices", GameTypes.Role.ESCAPEE):
		var it: ItemData = items[type]
		var tile := Button.new()
		tile.toggle_mode = true
		tile.custom_minimum_size = Vector2(220, 74)
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
	_deck_label.text = "Đã chọn %d/%d · chạm để chọn / bỏ, thứ tự chọn là ô 1-%d trong trận" % [_deck_order.size(), DECK_SIZE, DECK_SIZE]
	for type: int in _deck_checks:
		var tile: Button = _deck_checks[type]
		var slot := _deck_order.find(type)
		tile.text = ("%d. " % (slot + 1) if slot >= 0 else "") + str(tile.get_meta(&"label"))
		UiTheme.color_button(tile, Color(0.95, 0.62, 0.15) if slot >= 0 else UiTheme.MUTED)


func _build_choice_row(box: VBoxContainer, title_text: String, names: Array, selected: int, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var title := Label.new()
	title.text = title_text
	title.custom_minimum_size.x = 80
	title.add_theme_font_size_override("font_size", 20)
	row.add_child(title)
	var group := ButtonGroup.new()
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == selected
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggled.connect(func(on: bool) -> void:
			if on:
				on_pick.call(i))
		row.add_child(b)


# --- Tiện ích ---

func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Đạo hữu"


func _add_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


## Một lớp phủ kín node cha, chạm chỗ trống thì xuyên xuống sân khấu.
func _layer(parent: Control) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Neo node vào một điểm của lớp (0..1 mỗi chiều), co giãn theo cỡ tối thiểu về phía trong.
func _place(layer: Control, node: Control, anchor: Vector2) -> void:
	layer.add_child(node)
	node.anchor_left = anchor.x
	node.anchor_right = anchor.x
	node.anchor_top = anchor.y
	node.anchor_bottom = anchor.y
	node.offset_left = 0
	node.offset_right = 0
	node.offset_top = 0
	node.offset_bottom = 0
	node.grow_horizontal = _grow(anchor.x)
	node.grow_vertical = _grow(anchor.y)


static func _grow(a: float) -> Control.GrowDirection:
	if a <= 0.0:
		return Control.GROW_DIRECTION_END
	if a >= 1.0:
		return Control.GROW_DIRECTION_BEGIN
	return Control.GROW_DIRECTION_BOTH


## Nền trời xanh chuyển màu với vài đám mây và đồi núi xa, vẽ một lần (không chạy _process).
class _Backdrop extends Control:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var s := size
		var top := Color(0.45, 0.75, 0.98)
		var bottom := Color(0.85, 0.93, 1.0)
		var bands := 12
		for i in bands:
			var y0 := s.y * i / bands
			draw_rect(Rect2(0, y0, s.x, s.y / bands + 1), top.lerp(bottom, float(i) / (bands - 1)))
		for c: Vector3 in [Vector3(0.12, 0.16, 1.0), Vector3(0.85, 0.12, 0.8), Vector3(0.62, 0.28, 0.6)]:
			var p := Vector2(s.x * c.x, s.y * c.y)
			for k in 3:
				draw_circle(p + Vector2(k * 44 - 44, -abs(k - 1) * -14) * c.z, 42 * c.z, Color(1, 1, 1, 0.85))
		# Núi xa xanh nhạt rồi đồi cỏ gần.
		for m: Vector3 in [Vector3(0.18, 0.62, 0.42), Vector3(0.45, 0.55, 0.5), Vector3(0.8, 0.6, 0.4)]:
			var peak := Vector2(s.x * m.x, s.y * m.y)
			var half := s.x * m.z * 0.5
			draw_colored_polygon(PackedVector2Array([peak, Vector2(peak.x + half, s.y * 0.8), Vector2(peak.x - half, s.y * 0.8)]), Color(0.55, 0.7, 0.85))
		draw_circle(Vector2(s.x * 0.5, s.y * 2.05), s.y * 1.35, Color(0.4, 0.75, 0.35))
		draw_circle(Vector2(s.x * 0.05, s.y * 1.6), s.y * 0.8, Color(0.35, 0.68, 0.32))
		draw_circle(Vector2(s.x * 0.98, s.y * 1.65), s.y * 0.8, Color(0.36, 0.7, 0.33))
