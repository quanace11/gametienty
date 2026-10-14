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
			lines.append("Bạn là THỢ SĂN: đánh ngã, vác vào tù")
		GameTypes.Role.ESCAPEE:
			lines.append("Bạn là NGƯỜI TRỐN: đứng trong két vàng để mở, đủ két thì chạy ra cổng")
		_:
			lines.append("Server (không chơi)")
	if rules.state == GameTypes.MatchState.COUNTDOWN:
		lines.append("Bắt đầu sau %d" % ceili(rules.countdown_left))
	lines.append("Thời gian: %d   Két: %d/%d   Cổng: %s" % [
		ceili(rules.time_left), rules.safes_unlocked(), rules.safes_required(), "MỞ" if rules.gate_open else "khóa"])
	lines.append("Còn ngoài: %d   Bị nhốt: %d   Bị loại: %d   Đã thoát: %d" % [
		rules.active_escapees(), rules.count_escapees(GameTypes.PlayerState.IMPRISONED),
		rules.count_escapees(GameTypes.PlayerState.ELIMINATED), rules.count_escapees(GameTypes.PlayerState.ESCAPED)])
	var me := rules.record(multiplayer.get_unique_id())
	if me:
		lines.append(_my_status(me))
	if _result != "":
		lines.append("")
		lines.append(_result)
	_label.text = "\n".join(lines)


func _my_status(me: PlayerRecord) -> String:
	if me.is_hunter():
		if me.stunned_left > 0.0:
			return "Bị choáng %.1f giây" % me.stunned_left
		if me.carrying_id != 0:
			return "Đang vác người: mang tới nhà tù"
		return "E / Space: đánh, hoặc nhấc người đang ngã"
	match me.state:
		GameTypes.PlayerState.DOWNED:
			return "Bạn bị ngã! Chờ đồng đội đỡ (%d%%)" % roundi(me.rescue_progress * 100)
		GameTypes.PlayerState.CARRIED:
			return "Bị vác! Bấm E liên tục để vùng thoát (%d%%)" % roundi(me.struggle * 100)
		GameTypes.PlayerState.IMPRISONED:
			return "Trong tù, còn %d giây (lần %d/%d)" % [ceili(me.prison_time_left), me.imprison_count, GameState.rules.config.max_imprisonments]
		GameTypes.PlayerState.ELIMINATED:
			return "Bạn đã bị loại"
		GameTypes.PlayerState.ESCAPED:
			return "Bạn đã thoát!"
	return "Máu: %d/%d   Giữ E gần đồng đội ngã để đỡ dậy" % [me.hp, me.max_hp]


func _on_match_ended(winner: GameTypes.Winner, _summary: Dictionary) -> void:
	_result = "NGƯỜI TRỐN THẮNG!" if winner == GameTypes.Winner.ESCAPEES else "THỢ SĂN THẮNG!"
