extends CanvasLayer
## HUD trong trận: chỉ đọc GameState.rules và nghe EventBus, không đổi gì.

const QteRing = preload("res://UI/qte_ring.gd")
const ALERT_TIME := 3.0

var _label: Label
var _result := ""
var _alert := ""
var _alert_left := 0.0


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 20)
	add_child(_label)
	var ring: Control = QteRing.new()
	ring.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ring.position = Vector2(-ring.custom_minimum_size.x / 2, -ring.custom_minimum_size.y - 40)
	ring.size = ring.custom_minimum_size
	add_child(ring)
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.qte_resolved.connect(func(_id: int, safe_id: int, result: GameTypes.QteResult) -> void:
		if result == GameTypes.QteResult.FAIL:
			_show_alert("Rương %d vừa nổ! (khói đỏ)" % safe_id))
	EventBus.gate_opening.connect(func(_s: float) -> void: _show_alert("Đủ chìa! 2 cổng đang mở..."))


func _process(delta: float) -> void:
	var rules := GameState.rules
	if rules == null:
		return
	_alert_left = maxf(0.0, _alert_left - delta)
	var lines: PackedStringArray = []
	match GameState.my_role():
		GameTypes.Role.HUNTER:
			lines.append("Bạn là THỢ SĂN: đánh gục, kéo vào tù")
		GameTypes.Role.ESCAPEE:
			lines.append("Bạn là NGƯỜI TRỐN: cạy rương lấy chìa (E khi kim vào vùng sáng), đủ chìa thì chạy ra 1 trong 2 cổng")
		_:
			lines.append("Server (không chơi)")
	if rules.state == GameTypes.MatchState.COUNTDOWN:
		lines.append("Bắt đầu sau %d" % ceili(rules.countdown_left))
	var gate := "MỞ" if rules.gate_open else ("mở sau %.1f" % rules.gate_opening_left if rules.gate_opening_left > 0.0 else "khóa")
	lines.append("Thời gian: %d   Chìa: %d/%d   Cổng: %s" % [
		ceili(rules.time_left), rules.safes_unlocked(), rules.safes_required(), gate])
	lines.append("Còn ngoài: %d   Bị nhốt: %d   Bị loại: %d   Đã thoát: %d" % [
		rules.active_escapees(), rules.count_escapees(GameTypes.PlayerState.IMPRISONED),
		rules.count_escapees(GameTypes.PlayerState.ELIMINATED), rules.count_escapees(GameTypes.PlayerState.ESCAPED)])
	var me := rules.record(multiplayer.get_unique_id())
	if me:
		lines.append(_my_status(me))
	if _alert_left > 0.0:
		lines.append(">> " + _alert)
	if _result != "":
		lines.append("")
		lines.append(_result)
	var text := "\n".join(lines)
	if _label.text != text: # đổi chữ mới dựng lại layout
		_label.text = text


func _my_status(me: PlayerRecord) -> String:
	if me.is_hunter():
		if me.stunned_left > 0.0:
			return "Bị choáng %.1f giây" % me.stunned_left
		if me.carrying_id != 0:
			return "Đang kéo người: mang tới nhà tù"
		return "E / Space: đánh, hoặc túm người đang gục"
	match me.state:
		GameTypes.PlayerState.DOWNED:
			return "Bạn bị gục! Chờ đồng đội đỡ (%d%%) hoặc ném túi máu" % roundi(me.rescue_progress * 100)
		GameTypes.PlayerState.CARRIED:
			return "Bị thợ săn kéo đi! Chờ đồng đội ném túi máu hoặc làm choáng thợ săn"
		GameTypes.PlayerState.IMPRISONED:
			return "Trong tù, bị đốt chết sau %d giây! Chờ túi máu" % ceili(me.prison_time_left)
		GameTypes.PlayerState.ELIMINATED:
			return "Bạn đã bị loại"
		GameTypes.PlayerState.ESCAPED:
			return "Bạn đã thoát!"
	return "Máu: %d/%d   Tiền: %d   Túi máu: %d (Q)   Giữ E gần đồng đội gục để đỡ dậy" % [
		me.hp, me.max_hp, me.coins, me.items.get(GameTypes.ItemType.MEDKIT, 0)]


func _show_alert(text: String) -> void:
	_alert = text
	_alert_left = ALERT_TIME


const HUNTER_TEXT := {
	GameTypes.HunterResult.LOSE: "THUA",
	GameTypes.HunterResult.PARTIAL: "THẮNG MỘT PHẦN",
	GameTypes.HunterResult.TOTAL: "CHIẾN THẮNG TUYỆT ĐỐI",
}


## Bảng kết quả: mỗi người trốn tính riêng, thợ săn theo số người bắt được.
func _on_match_ended(res: Dictionary) -> void:
	var lines: PackedStringArray = ["===== KẾT QUẢ =====",
		"Thợ săn %s (bắt %d/%d)" % [HUNTER_TEXT[res["hunter_result"]], res["caught"], res["escapees"]]]
	var me := multiplayer.get_unique_id()
	var players: Dictionary = res["players"]
	for id: int in players:
		var row: Dictionary = players[id]
		if row["role"] == GameTypes.Role.HUNTER:
			continue
		var status := "THOÁT HIỂM THÀNH CÔNG" if row["result"] == GameTypes.EscapeeResult.ESCAPED else "BỊ BẮT / THẤT BẠI"
		lines.append("%s%s: %s   %d điểm (tiền %d, cứu %d, căn đẹp %d)" % [
			"▶ " if id == me else "", row["name"], status, row["score"], row["coins"], row["rescues"], row["qte_perfect"]])
	_result = "\n".join(lines)
