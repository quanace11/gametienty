extends CanvasLayer
## HUD trong trận: chỉ đọc GameState.rules và nghe EventBus, không đổi gì.

const QteRing = preload("res://UI/qte_ring.gd")
const Minimap = preload("res://UI/minimap.gd")
const ResultsScreen = preload("res://UI/results_screen.gd")
const ALERT_TIME := 3.0

var _label: Label
var _alert := ""
var _alert_left := 0.0
var _item_names := {} # ItemType -> tên thẻ (đọc một lần)


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
	add_child(Minimap.new())
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.teleport_started.connect(func(id: int, _t: Vector3, s: float) -> void:
		if id != multiplayer.get_unique_id() and GameState.my_role() == GameTypes.Role.ESCAPEE:
			_show_alert("Thợ săn đang dịch chuyển (cột tím) sau %.1f giây!" % s))
	EventBus.footprints_revealed.connect(func(_p: PackedVector3Array, _s: float) -> void: _show_alert("Radar: dấu chân đỏ trên bản đồ"))
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
			lines.append("Bạn là THỢ SĂN: bắn gục, kéo vào tù. Chạm bản đồ góc phải để chọn chỗ dịch chuyển")
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
	var text := "\n".join(lines)
	if _label.text != text: # đổi chữ mới dựng lại layout
		_label.text = text


func _my_status(me: PlayerRecord) -> String:
	if me.is_hunter():
		if me.stunned_left > 0.0:
			return "Bị choáng %.1f giây" % me.stunned_left
		if me.carrying_id != 0:
			return "Đang kéo người: mang tới nhà tù"
		if me.teleport_left > 0.0:
			return "Đang tụ lực dịch chuyển %.1f giây" % me.teleport_left
		return "Máu: %d/%d   E / Space: bắn cối, hoặc túm người đang gục\n%s" % [me.hp, me.max_hp, _deck_line(me)]
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
	return "Máu: %d/%d   Tiền: %d   Giữ E gần đồng đội gục để đỡ dậy\n%s" % [me.hp, me.max_hp, me.coins, _deck_line(me)]


## Bộ bài: "1 Túi cứu thương (10) | 2 Lựu đạn choáng (hồi 4s) ...". Tên thẻ lấy từ Items qua ModuleRegistry.
func _deck_line(me: PlayerRecord) -> String:
	if _item_names.is_empty():
		var items: Dictionary = load(ModuleRegistry.ITEM_CATALOG).call(&"all")
		for type: int in items:
			_item_names[type] = items[type].display_name
	var parts: PackedStringArray = []
	for i in me.deck.size():
		var cd: float = me.item_cooldowns[i]
		var cost: int = GameState.rules.catalog[me.deck[i]]["cost"]
		var state := "hồi %ds" % ceili(cd) if cd > 0.0 else ("%d xu" % cost if me.coins >= cost else "thiếu tiền")
		parts.append("%d %s (%s)" % [i + 1, _item_names.get(me.deck[i], "?"), state])
	return " | ".join(parts)


func _show_alert(text: String) -> void:
	_alert = text
	_alert_left = ALERT_TIME


## Bảng kết quả từng người (thợ săn theo số người bắt được, người trốn tính riêng).
func _on_match_ended(res: Dictionary) -> void:
	var panel := ResultsScreen.new()
	add_child(panel)
	panel.show_result(res, multiplayer.get_unique_id())
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
