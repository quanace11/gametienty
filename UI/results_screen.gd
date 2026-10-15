extends PanelContainer
## Bảng kết quả cuối trận: dải lớn kết quả của mình (màu theo thắng / thua),
## kết quả thợ săn, rồi từng người xếp theo điểm, mỗi người một hàng bo tròn
## (hàng của mình viền vàng). HUD tạo khi nhận EventBus.match_ended
## (MatchRules.results()) và đặt giữa màn hình.

const UiTheme = preload("res://UI/ui_theme.gd")
const HUNTER_TEXT := {
	GameTypes.HunterResult.LOSE: "THUA",
	GameTypes.HunterResult.PARTIAL: "THẮNG MỘT PHẦN",
	GameTypes.HunterResult.TOTAL: "THẮNG TUYỆT ĐỐI",
}
const COLUMNS := ["Người chơi", "Kết quả", "Rương", "Cứu", "Trúng", "Tiền", "Điểm"]
const WIDTHS := [190, 170, 70, 55, 65, 60, 70]


func show_result(res: Dictionary, my_id: int) -> void:
	theme = UiTheme.get_theme()
	add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PANEL, 22, 4))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var players: Dictionary = res["players"]
	var mine: Dictionary = players.get(my_id, {})
	var banner := PanelContainer.new()
	var won := _is_win(mine)
	banner.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.GREEN if won else UiTheme.RED, 16, 3))
	box.add_child(banner)
	var big := _label(banner, _my_title(mine), 40)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var hunter_line := "Bắt %d/%d người trốn, %d người thoát" % [res["caught"], res["escapees"], res["escaped"]]
	if mine.get("role", -1) != GameTypes.Role.HUNTER:
		hunter_line = "Thợ săn %s: %s" % [HUNTER_TEXT[res["hunter_result"]], hunter_line.to_lower()]
	var sub := _label(box, hunter_line, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	box.add_child(_row(COLUMNS, Color(1, 1, 1, 0.65), null))
	var ids := players.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return players[a]["score"] > players[b]["score"])
	for id: int in ids:
		var row: Dictionary = players[id]
		var hunter: bool = row["role"] == GameTypes.Role.HUNTER
		var result: String = HUNTER_TEXT[row["result"]] if hunter \
			else ("THOÁT" if row["result"] == GameTypes.EscapeeResult.ESCAPED else "BỊ BẮT")
		var cells := [
			("[Thợ săn] " if hunter else "") + str(row["name"]), result,
			"-" if hunter else "%.1f" % row["chests"],
			"-" if hunter else str(row["rescues"]),
			"-" if hunter else str(row.get("damage", 0)),
			str(row["coins"]), str(row["score"]),
		]
		var bg := UiTheme.panel(Color(1, 1, 1, 0.08), 12, 0)
		if id == my_id:
			bg.bg_color = Color(1.0, 0.8, 0.25, 0.25)
			bg.set_border_width_all(3)
			bg.border_color = UiTheme.GOLD
		bg.set_content_margin_all(6)
		box.add_child(_row(cells, Color.WHITE, bg))
	# Hiện ra kiểu "nảy" cho vui mắt.
	pivot_offset = get_combined_minimum_size() / 2.0
	scale = Vector2(0.8, 0.8)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _is_win(row: Dictionary) -> bool:
	if row.is_empty():
		return false
	if row["role"] == GameTypes.Role.HUNTER:
		return row["result"] != GameTypes.HunterResult.LOSE
	return row["result"] == GameTypes.EscapeeResult.ESCAPED


func _my_title(row: Dictionary) -> String:
	if row.is_empty():
		return "HẾT TRẬN"
	if row["role"] == GameTypes.Role.HUNTER:
		return "THỢ SĂN " + HUNTER_TEXT[row["result"]]
	return "BẠN ĐÃ THOÁT!" if row["result"] == GameTypes.EscapeeResult.ESCAPED else "BẠN BỊ BẮT"


func _row(cells: Array, color: Color, bg: StyleBox) -> Control:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", bg if bg else StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	holder.add_child(row)
	for i in cells.size():
		var l := _label(row, str(cells[i]), 18)
		l.custom_minimum_size = Vector2(WIDTHS[i], 0)
		l.clip_text = true
		l.modulate = color
		if i > 0:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return holder


func _label(parent: Control, text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l
