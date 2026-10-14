extends PanelContainer
## Bảng kết quả cuối trận: kết quả thợ săn, rồi từng người xếp theo điểm.
## HUD tạo khi nhận EventBus.match_ended (MatchRules.results()).

const HUNTER_TEXT := {
	GameTypes.HunterResult.LOSE: "THUA",
	GameTypes.HunterResult.PARTIAL: "THẮNG MỘT PHẦN",
	GameTypes.HunterResult.TOTAL: "CHIẾN THẮNG TUYỆT ĐỐI",
}
const HEADERS := ["Người chơi", "Vai", "Kết quả", "Rương", "Cứu", "Bắn trúng", "Tiền", "Điểm"]


func show_result(res: Dictionary, my_id: int) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.08, 0.88)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(18)
	add_theme_stylebox_override("panel", bg)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "KẾT QUẢ: thợ săn %s (bắt %d/%d, thoát %d)" % [
		HUNTER_TEXT[res["hunter_result"]], res["caught"], res["escapees"], res["escaped"]]
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = HEADERS.size()
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for h: String in HEADERS:
		_cell(grid, h, Color(1, 1, 1, 0.6))

	var players: Dictionary = res["players"]
	var ids := players.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return players[a]["score"] > players[b]["score"])
	for id: int in ids:
		var row: Dictionary = players[id]
		var hunter: bool = row["role"] == GameTypes.Role.HUNTER
		var result: String = HUNTER_TEXT[row["result"]] if hunter \
			else ("THOÁT" if row["result"] == GameTypes.EscapeeResult.ESCAPED else "BỊ BẮT")
		var c := Color(1, 0.9, 0.3) if id == my_id else Color.WHITE
		_cell(grid, ("▶ " if id == my_id else "") + str(row["name"]), c)
		_cell(grid, "Thợ săn" if hunter else "Người trốn", c)
		_cell(grid, result, c)
		_cell(grid, "-" if hunter else "%.1f" % row["chests"], c)
		_cell(grid, "-" if hunter else str(row["rescues"]), c)
		_cell(grid, "-" if hunter else str(row.get("damage", 0)), c)
		_cell(grid, str(row["coins"]), c)
		_cell(grid, str(row["score"]), c)


func _cell(grid: GridContainer, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = color
	l.add_theme_font_size_override("font_size", 20)
	grid.add_child(l)
