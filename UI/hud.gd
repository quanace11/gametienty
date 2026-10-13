extends CanvasLayer
## HUD trong trận: chỉ đọc GameState.rules và nghe EventBus, không đổi gì.

var _label: Label
var _result := ""


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 20)
	add_child(_label)
	EventBus.match_ended.connect(_on_match_ended)


func _process(_delta: float) -> void:
	var rules := GameState.rules
	if rules == null:
		return
	var lines: PackedStringArray = []
	match GameState.my_role():
		GameTypes.Role.HUNTER:
			lines.append("Bạn là THỢ SĂN: chạm vào người trốn để bắt")
		GameTypes.Role.ESCAPEE:
			lines.append("Bạn là NGƯỜI TRỐN: đứng trong két vàng để mở, đủ két thì chạy ra cổng")
		_:
			lines.append("Server (không chơi)")
	if rules.state == GameTypes.MatchState.COUNTDOWN:
		lines.append("Bắt đầu sau %d" % ceili(rules.countdown_left))
	lines.append("Thời gian: %d   Két: %d/%d   Cổng: %s" % [
		ceili(rules.time_left), rules.safes_unlocked(), rules.safes_required(), "MỞ" if rules.gate_open else "khóa"])
	lines.append("Còn chạy: %d   Bị nhốt: %d   Đã thoát: %d" % [
		rules.active_escapees(), rules.count_escapees(GameTypes.PlayerState.IMPRISONED),
		rules.count_escapees(GameTypes.PlayerState.ESCAPED)])
	if _result != "":
		lines.append("")
		lines.append(_result)
	_label.text = "\n".join(lines)


func _on_match_ended(winner: GameTypes.Winner, _summary: Dictionary) -> void:
	_result = "NGƯỜI TRỐN THẮNG!" if winner == GameTypes.Winner.ESCAPEES else "THỢ SĂN THẮNG!"
