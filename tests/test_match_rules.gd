extends SceneTree
## Test luật trận (thuần logic). Chạy:
##   godot --headless --path . -s tests/test_match_rules.gd

var _failed := 0


func _initialize() -> void:
	_test_countdown_then_playing()
	_test_all_imprisoned_hunter_wins()
	_test_half_escape_escapees_win()
	_test_gate_opens_after_required_safes()
	_test_timeout()
	print("FAILED: %d" % _failed if _failed else "Tất cả test đều qua")
	quit(1 if _failed else 0)


func _rules() -> MatchRules:
	var cfg := MatchConfig.new()
	cfg.countdown = 0.0
	var roles := {1: GameTypes.Role.HUNTER, 2: GameTypes.Role.ESCAPEE, 3: GameTypes.Role.ESCAPEE, 4: GameTypes.Role.ESCAPEE, 5: GameTypes.Role.ESCAPEE}
	var r := MatchRules.new(cfg, roles, {}, 3)
	r.tick(0.01)
	return r


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failed += 1
		push_error("FAIL: " + what)


func _test_countdown_then_playing() -> void:
	var cfg := MatchConfig.new()
	var r := MatchRules.new(cfg, {1: GameTypes.Role.HUNTER, 2: GameTypes.Role.ESCAPEE}, {}, 1)
	_check(r.state == GameTypes.MatchState.COUNTDOWN, "bắt đầu bằng đếm ngược")
	r.tick(cfg.countdown + 0.1)
	_check(r.is_playing(), "hết đếm ngược thì vào trận")


func _test_all_imprisoned_hunter_wins() -> void:
	var r := _rules()
	for id in [2, 3, 4]:
		r.set_player_state(id, GameTypes.PlayerState.IMPRISONED)
	_check(r.evaluate() == GameTypes.Winner.NONE, "còn 1 người chạy thì chưa hết trận")
	r.set_player_state(5, GameTypes.PlayerState.IMPRISONED)
	_check(r.evaluate() == GameTypes.Winner.HUNTER, "nhốt hết thì thợ săn thắng")


func _test_half_escape_escapees_win() -> void:
	var r := _rules()
	r.set_player_state(2, GameTypes.PlayerState.ESCAPED)
	r.set_player_state(3, GameTypes.PlayerState.ESCAPED)
	r.set_player_state(4, GameTypes.PlayerState.IMPRISONED)
	r.set_player_state(5, GameTypes.PlayerState.IMPRISONED)
	_check(r.evaluate() == GameTypes.Winner.ESCAPEES, "2/4 thoát thì người trốn thắng")


func _test_gate_opens_after_required_safes() -> void:
	var r := _rules()
	_check(not r.set_safe_progress(0, 0.5), "chưa đủ 100% thì chưa mở két")
	_check(r.set_safe_progress(0, 1.0), "đủ 100% thì mở két")
	r.set_safe_progress(1, 1.0)
	_check(not r.gate_open, "2/3 két thì cổng chưa mở")
	r.set_safe_progress(2, 1.0)
	_check(r.gate_open, "3/3 két thì cổng mở")


func _test_timeout() -> void:
	var r := _rules()
	r.set_player_state(2, GameTypes.PlayerState.ESCAPED)
	r.tick(1000.0)
	_check(r.evaluate() == GameTypes.Winner.HUNTER, "hết giờ mà mới 1/4 thoát thì thợ săn thắng")
