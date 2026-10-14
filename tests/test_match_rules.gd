extends SceneTree
## Test luật trận (thuần logic, không mạng). Chạy:
##   godot --headless --path . -s tests/test_match_rules.gd

const H := 1 # thợ săn
const A := 2 # người trốn
const B := 3
const C := 4
const D := 5
const S := GameTypes.PlayerState

var _failed := 0
var _count := 0


func _initialize() -> void:
	for t: StringName in [
		&"_test_countdown_then_playing",
		&"_test_all_imprisoned_hunter_wins",
		&"_test_half_escape_escapees_win",
		&"_test_gate_opens_after_required_safes",
		&"_test_timeout",
		&"_test_two_hits_down",
		&"_test_attack_cooldown",
		&"_test_invulnerable_after_hit",
		&"_test_cannot_hit_non_active",
		&"_test_pick_up_and_imprison",
		&"_test_pick_up_requires_downed_and_free_hands",
		&"_test_drop",
		&"_test_carried_cannot_escape_alone",
		&"_test_stun_hunter_releases_carried",
		&"_test_revive",
		&"_test_two_rescuers_twice_as_fast",
		&"_test_rescuing_state_times_out",
		&"_test_hit_interrupts_rescue",
		&"_test_prison_cannot_rescue_by_hand",
		&"_test_prison_timeout_eliminates",
		&"_test_no_imprison_limit_by_default",
		&"_test_imprison_limit_when_set",
		&"_test_medkit_starting_count",
		&"_test_medkit_revives_downed",
		&"_test_medkit_frees_carried",
		&"_test_medkit_frees_inmate",
		&"_test_medkit_heals_standing",
		&"_test_medkit_rejected",
		&"_test_medkit_runs_out",
		&"_test_escape_requires_open_gate",
		&"_test_hunter_disconnect",
		&"_test_carried_disconnect_frees_hunter",
		&"_test_speed_factor",
		&"_test_client_tick_never_changes_state",
		&"_test_dirty_tracking",
		&"_test_record_roundtrip",
		&"_test_events_down",
		&"_test_events_pickup_imprison_rescue",
		&"_test_events_batched_changes",
		&"_test_events_medkit",
		&"_test_events_stun_release",
		&"_test_items_copied_not_shared",
	]:
		call(t)
	if _failed:
		print("FAILED: %d/%d" % [_failed, _count])
	else:
		print("Tất cả %d kiểm tra đều qua" % _count)
	quit(1 if _failed else 0)


func _rules() -> MatchRules:
	var cfg := MatchConfig.new()
	cfg.countdown = 0.0
	var roles := {H: GameTypes.Role.HUNTER, A: GameTypes.Role.ESCAPEE, B: GameTypes.Role.ESCAPEE, C: GameTypes.Role.ESCAPEE, D: GameTypes.Role.ESCAPEE}
	var r := MatchRules.new(cfg, roles, {}, 3)
	r.tick(0.001)
	return r


func _check(cond: bool, what: String) -> void:
	_count += 1
	if not cond:
		_failed += 1
		push_error("FAIL: " + what)


## Đánh A cho tới khi ngã (bỏ qua hồi chiêu và bất tử giữa các đòn).
func _down(r: MatchRules, id: int) -> void:
	for i in r.config.max_hp:
		r.tick(r.config.attack_cooldown + 0.01)
		r.attack(H, [id])


func _imprison(r: MatchRules, id: int, prison: int = 0) -> void:
	_down(r, id)
	r.tick(0.01)
	r.pick_up(H, id)
	r.imprison(H, prison)


# ---------- Trận ----------

func _test_countdown_then_playing() -> void:
	var cfg := MatchConfig.new()
	var r := MatchRules.new(cfg, {H: GameTypes.Role.HUNTER, A: GameTypes.Role.ESCAPEE}, {}, 1)
	_check(r.state == GameTypes.MatchState.COUNTDOWN, "bắt đầu bằng đếm ngược")
	_check(not r.attack(H, [A]), "không đánh được khi đang đếm ngược")
	r.tick(cfg.countdown + 0.1)
	_check(r.is_playing(), "hết đếm ngược thì vào trận")


func _test_all_imprisoned_hunter_wins() -> void:
	var r := _rules()
	r.config.max_imprisonments = 99
	for id in [A, B, C]:
		_imprison(r, id)
	_check(r.evaluate() == GameTypes.Winner.NONE, "còn 1 người chạy thì chưa hết trận")
	_imprison(r, D)
	_check(r.evaluate() == GameTypes.Winner.HUNTER, "nhốt hết thì thợ săn thắng")


func _test_half_escape_escapees_win() -> void:
	var r := _rules()
	r.gate_open = true
	r.escape(A)
	r.escape(B)
	r.players[C].state = S.ELIMINATED
	r.players[D].state = S.ELIMINATED
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
	r.gate_open = true
	r.escape(A)
	r.tick(1000.0)
	_check(r.evaluate() == GameTypes.Winner.HUNTER, "hết giờ mà mới 1/4 thoát thì thợ săn thắng")


# ---------- Đánh ----------

func _test_two_hits_down() -> void:
	var r := _rules()
	_check(r.attack(H, [A]), "đòn đầu được vung")
	_check(r.state_of(A) == S.IDLE and r.record(A).hp == 1, "trúng 1 đòn còn 1 máu")
	r.tick(2.0)
	r.attack(H, [A])
	_check(r.state_of(A) == S.DOWNED and r.record(A).hp == 0, "trúng 2 đòn thì ngã")
	_check(r.record(A).last_attacker_id == H, "ghi lại người đánh")


func _test_attack_cooldown() -> void:
	var r := _rules()
	r.attack(H, [A])
	_check(not r.attack(H, [B]), "đang hồi chiêu thì không đánh được")
	_check(r.record(B).hp == r.config.max_hp, "B không mất máu")
	r.tick(r.config.attack_cooldown + 0.01)
	_check(r.attack(H, [B]), "hết hồi chiêu thì đánh được")
	_check(not r.attack(A, [B]), "người trốn không đánh được")


func _test_invulnerable_after_hit() -> void:
	var r := _rules()
	r.config.attack_cooldown = 0.0
	r.attack(H, [A])
	r.attack(H, [A])
	_check(r.record(A).hp == 1, "vừa trúng đòn thì bất tử một lúc, không bị trừ 2 lần")


func _test_cannot_hit_non_active() -> void:
	var r := _rules()
	_down(r, A)
	r.tick(2.0)
	r.attack(H, [A])
	_check(r.record(A).hp == 0 and r.state_of(A) == S.DOWNED, "đánh người đang ngã không có tác dụng")
	_check(not r.is_hittable(H), "thợ săn không bị đánh")


# ---------- Vác & tù ----------

func _test_pick_up_and_imprison() -> void:
	var r := _rules()
	_down(r, A)
	_check(r.pick_up(H, A), "nhấc người đang ngã")
	_check(r.state_of(A) == S.CARRIED and r.record(A).carrier_id == H and r.record(H).carrying_id == A, "liên kết kéo hai chiều")
	_check(not r.can_attack(H), "đang kéo thì không đánh")
	_check(r.imprison(H, 1), "đưa vào tù")
	_check(r.state_of(A) == S.IMPRISONED and r.record(A).prison_id == 1, "ở tù số 1")
	_check(r.record(H).carrying_id == 0 and r.record(A).carrier_id == 0, "gỡ liên kết kéo")
	_check(r.record(A).imprison_count == 1, "đếm số lần bị nhốt")
	_check(not r.imprison(H, 1), "không kéo ai thì không nhốt được")


func _test_pick_up_requires_downed_and_free_hands() -> void:
	var r := _rules()
	_check(not r.pick_up(H, A), "không nhấc người đang đứng")
	_down(r, A)
	_down(r, B)
	r.pick_up(H, A)
	_check(not r.pick_up(H, B), "đang kéo thì không nhấc thêm")
	_check(not r.pick_up(A, B), "người trốn không nhấc được")


func _test_drop() -> void:
	var r := _rules()
	_down(r, A)
	r.pick_up(H, A)
	_check(r.drop(H), "thả xuống")
	_check(r.state_of(A) == S.DOWNED and r.record(H).carrying_id == 0, "thả xuống thì vẫn nằm ngã")
	_check(not r.drop(H), "không kéo thì không thả")


func _test_carried_cannot_escape_alone() -> void:
	var r := _rules()
	_down(r, A)
	r.pick_up(H, A)
	r.tick(100.0)
	_check(r.state_of(A) == S.CARRIED and r.record(H).carrying_id == A, "bị kéo bao lâu cũng không tự thoát")
	_check(not r.channel_rescue(B, A, 100.0), "không đỡ tay được người đang bị kéo")
	_check(not r.can_move(A), "bị kéo thì không tự đi")

func _test_stun_hunter_releases_carried() -> void:
	var r := _rules()
	_down(r, A)
	r.pick_up(H, A)
	_check(r.stun(H, 2.0), "choáng thợ săn")
	_check(r.state_of(A) == S.IDLE and r.record(H).carrying_id == 0, "thợ săn choáng thì người bị kéo thoát")
	_check(r.record(A).hp == r.config.revive_hp, "thoát ra với máu hồi")
	_check(not r.can_move(H) and not r.can_attack(H), "đang choáng thì không đi, không đánh")


# ---------- Cứu ----------

func _test_revive() -> void:
	var r := _rules()
	_down(r, A)
	_check(not r.channel_rescue(B, A, r.config.revive_time * 0.5), "cứu được một nửa")
	_check(r.state_of(B) == S.RESCUING, "người cứu chuyển sang RESCUING")
	_check(is_equal_approx(r.record(A).rescue_progress, 0.5), "tiến độ 50%")
	_check(r.channel_rescue(B, A, r.config.revive_time * 0.5), "cứu xong")
	_check(r.state_of(A) == S.IDLE and r.record(A).hp == r.config.revive_hp, "được đỡ dậy với máu hồi")
	_check(r.record(A).last_rescuer_id == B, "ghi lại người cứu")
	_check(not r.channel_rescue(B, A, 1.0), "cứu người đang đứng không có tác dụng")
	_check(not r.channel_rescue(A, A, 1.0), "không tự cứu mình")


func _test_two_rescuers_twice_as_fast() -> void:
	var r := _rules()
	_down(r, A)
	var half := r.config.revive_time * 0.5
	r.channel_rescue(B, A, half)
	_check(r.channel_rescue(C, A, half), "hai người cùng cứu thì nhanh gấp đôi")


func _test_rescuing_state_times_out() -> void:
	var r := _rules()
	_down(r, A)
	r.channel_rescue(B, A, 0.1)
	r.tick(MatchRules.RESCUE_CHANNEL_GRACE + 0.05)
	_check(r.state_of(B) == S.IDLE, "ngừng cứu thì về IDLE")
	_check(r.record(A).rescue_progress > 0.0, "tiến độ cứu vẫn giữ")


func _test_hit_interrupts_rescue() -> void:
	var r := _rules()
	_down(r, A)
	r.channel_rescue(B, A, 0.1)
	r.tick(r.config.attack_cooldown + 0.01)
	r.channel_rescue(B, A, 0.01)
	r.attack(H, [B])
	_check(r.state_of(B) == S.IDLE and r.record(B).hp == 1, "bị đánh thì ngừng cứu")


func _test_prison_cannot_rescue_by_hand() -> void:
	var r := _rules()
	_imprison(r, A)
	_check(not r.channel_rescue(B, A, 100.0), "không đỡ tay được người trong tù")
	_check(r.state_of(A) == S.IMPRISONED, "vẫn trong tù")


func _test_prison_timeout_eliminates() -> void:
	var r := _rules()
	_imprison(r, A)
	_check(is_equal_approx(r.record(A).prison_time_left, 45.0), "vào tù có 45 giây")
	r.tick(r.config.prison_time - 1.0)
	_check(r.state_of(A) == S.IMPRISONED and r.record(A).prison_time_left > 0.0, "chưa hết giờ thì vẫn sống")
	r.tick(1.1)
	_check(r.state_of(A) == S.ELIMINATED, "hết giờ mà không ai cứu thì bị đốt chết")
	_check(not r.use_medkit(B, A), "chết rồi thì túi máu không cứu được")


func _test_no_imprison_limit_by_default() -> void:
	var r := _rules()
	for i in 3:
		_imprison(r, A)
		_check(r.state_of(A) == S.IMPRISONED, "bị nhốt lần %d vẫn còn cơ hội" % (i + 1))
		r.record(B).items[GameTypes.ItemType.MEDKIT] = 1
		r.use_medkit(B, A)
		r.tick(r.config.hit_invulnerable_time + 0.1)


func _test_imprison_limit_when_set() -> void:
	var r := _rules()
	r.config.max_imprisonments = 2
	_imprison(r, A)
	r.use_medkit(B, A)
	r.tick(r.config.hit_invulnerable_time + 0.1)
	_imprison(r, A)
	_check(r.state_of(A) == S.ELIMINATED, "đặt giới hạn 2 thì bị nhốt lần 2 là bị loại")


# ---------- Túi máu ----------

func _test_medkit_starting_count() -> void:
	var r := _rules()
	_check(r.item_count(A, GameTypes.ItemType.MEDKIT) == r.config.medkits_per_escapee, "người trốn có túi máu đầu trận")
	_check(r.item_count(H, GameTypes.ItemType.MEDKIT) == 0, "thợ săn không có túi máu")


func _test_medkit_revives_downed() -> void:
	var r := _rules()
	_down(r, A)
	_check(r.use_medkit(B, A), "ném túi máu cho người gục")
	_check(r.state_of(A) == S.IDLE and r.record(A).hp == r.config.medkit_heal, "đứng dậy ngay với máu hồi")
	_check(r.record(A).invulnerable_left > 0.0, "vừa được cứu thì bất tử một lúc")
	_check(r.item_count(B, GameTypes.ItemType.MEDKIT) == r.config.medkits_per_escapee - 1, "mất một túi")
	_check(r.record(A).last_rescuer_id == B, "ghi lại người cứu")


func _test_medkit_frees_carried() -> void:
	var r := _rules()
	_down(r, A)
	r.pick_up(H, A)
	_check(r.use_medkit(B, A), "ném túi máu cho người đang bị kéo")
	_check(r.state_of(A) == S.IDLE and r.record(A).carrier_id == 0, "bung khỏi tay thợ săn")
	r.tick(r.config.attack_cooldown + 0.01)
	_check(r.record(H).carrying_id == 0 and r.can_attack(H), "thợ săn hết kéo, đánh tiếp được")


func _test_medkit_frees_inmate() -> void:
	var r := _rules()
	_imprison(r, A, 1)
	r.tick(10.0)
	_check(r.use_medkit(B, A), "ném túi máu vào tù")
	_check(r.state_of(A) == S.IDLE and r.record(A).prison_id == -1, "người trong tù sống lại")
	r.tick(100.0)
	_check(r.state_of(A) == S.IDLE, "sống rồi thì không bị đốt nữa")


func _test_medkit_heals_standing() -> void:
	var r := _rules()
	r.attack(H, [A])
	_check(r.use_medkit(A, A), "tự dùng túi máu khi mất máu")
	_check(r.record(A).hp == r.config.max_hp, "hồi máu")
	_check(not r.use_medkit(A, A), "đầy máu thì không dùng, không mất túi")
	_check(r.item_count(A, GameTypes.ItemType.MEDKIT) == r.config.medkits_per_escapee - 1, "chỉ mất một túi")


func _test_medkit_rejected() -> void:
	var r := _rules()
	_down(r, A)
	_down(r, B)
	_check(not r.use_medkit(A, B), "đang gục thì không ném được")
	_check(not r.use_medkit(H, A), "thợ săn không dùng túi máu")
	_check(not r.use_medkit(C, H), "không hồi máu cho thợ săn")
	r.stun(C, 1.0)
	_check(not r.use_medkit(C, A), "đang choáng thì không ném được")
	r.take_dirty()
	_check(not r.use_medkit(C, A) and r.take_dirty().is_empty(), "bị từ chối thì không đổi gì")


func _test_medkit_runs_out() -> void:
	var r := _rules()
	for i in r.config.medkits_per_escapee:
		r.tick(r.config.attack_cooldown + 0.01)
		_down(r, A)
		_check(r.use_medkit(B, A), "dùng túi thứ %d" % (i + 1))
		r.tick(r.config.hit_invulnerable_time + 0.1)
	_down(r, A)
	_check(not r.use_medkit(B, A), "hết túi thì không dùng được")
	_check(r.item_count(B, GameTypes.ItemType.MEDKIT) == 0, "số túi không âm")


func _test_escape_requires_open_gate() -> void:
	var r := _rules()
	_check(not r.escape(A), "cổng khóa thì không thoát")
	r.gate_open = true
	_down(r, B)
	_check(not r.escape(B), "đang ngã thì không thoát")
	_check(r.escape(A) and r.state_of(A) == S.ESCAPED, "cổng mở thì thoát")


# ---------- Rời trận ----------

func _test_hunter_disconnect() -> void:
	var r := _rules()
	_down(r, A)
	r.pick_up(H, A)
	_check(r.remove_player(H), "thợ săn rời trận thì báo")
	_check(r.state_of(A) == S.IDLE, "người đang bị kéo được thả ra")


func _test_carried_disconnect_frees_hunter() -> void:
	var r := _rules()
	_down(r, A)
	r.pick_up(H, A)
	_check(not r.remove_player(A), "người trốn rời trận")
	_check(r.state_of(A) == S.ELIMINATED and r.record(H).carrying_id == 0, "thợ săn hết kéo, người rời bị loại")


# ---------- Hỗ trợ module ----------

func _test_speed_factor() -> void:
	var r := _rules()
	_check(r.speed_factor(A) == 1.0, "bình thường x1")
	_down(r, A)
	_check(is_equal_approx(r.speed_factor(A), r.config.downed_speed), "đang ngã thì bò")
	r.pick_up(H, A)
	_check(r.speed_factor(A) == 0.0, "bị kéo thì không tự đi")
	_check(is_equal_approx(r.speed_factor(H), r.config.carrying_speed), "đang kéo người thì chậm hơn")


func _test_client_tick_never_changes_state() -> void:
	var r := _rules()
	_imprison(r, A)
	r.tick(r.config.prison_time * 2, false)
	_check(r.state_of(A) == S.IMPRISONED, "client không tự loại người chơi")
	_check(r.record(A).prison_time_left == 0.0, "client vẫn đếm lùi để hiển thị")


func _test_dirty_tracking() -> void:
	var r := _rules()
	r.take_dirty()
	r.attack(H, [A])
	var dirty := r.take_dirty()
	_check(dirty.has(H) and dirty.has(A) and not dirty.has(B), "đánh dấu đúng người bị đổi")
	_check(r.take_dirty().is_empty(), "lấy xong thì xóa")
	r.attack(H, [B])
	_check(r.take_dirty().is_empty(), "lệnh bị từ chối thì không đánh dấu")


# ---------- Đồng bộ & sự kiện ----------

func _test_record_roundtrip() -> void:
	var r := _rules()
	_down(r, A)
	r.pick_up(H, A)
	var copy := PlayerRecord.new()
	copy.apply_dict(r.record(A).to_dict())
	_check(copy.to_dict() == r.record(A).to_dict(), "to_dict/apply_dict giữ nguyên dữ liệu")


func _signals(events: Array[Dictionary]) -> Array:
	return events.map(func(e: Dictionary) -> StringName: return e["signal"])


func _test_events_down() -> void:
	var r := _rules()
	r.tick(2.0)
	var before := r.record(A).to_dict()
	r.attack(H, [A])
	var ev := _signals(PlayerRecord.events_between(A, before, r.record(A).to_dict()))
	_check(ev == [&"player_hit"], "trúng đòn chỉ sinh player_hit")
	before = r.record(A).to_dict()
	r.tick(2.0)
	r.attack(H, [A])
	ev = _signals(PlayerRecord.events_between(A, before, r.record(A).to_dict()))
	_check(&"player_hit" in ev and &"player_downed" in ev and &"player_state_changed" in ev, "ngã sinh hit + downed")


func _test_events_pickup_imprison_rescue() -> void:
	var r := _rules()
	_down(r, A)
	var d0 := r.record(A).to_dict()
	r.pick_up(H, A)
	var d1 := r.record(A).to_dict()
	_check(&"player_picked_up" in _signals(PlayerRecord.events_between(A, d0, d1)), "sự kiện nhấc lên")
	r.imprison(H, 0)
	var d2 := r.record(A).to_dict()
	_check(&"player_imprisoned" in _signals(PlayerRecord.events_between(A, d1, d2)), "sự kiện vào tù")
	r.use_medkit(B, A)
	var d3 := r.record(A).to_dict()
	_check(&"player_rescued" in _signals(PlayerRecord.events_between(A, d2, d3)), "sự kiện được cứu")


## Mạng có thể gộp nhiều thay đổi thành một lần gửi: vẫn phải ra sự kiện hợp lý.
func _test_events_batched_changes() -> void:
	var r := _rules()
	var d0 := r.record(A).to_dict()
	_down(r, A)
	r.pick_up(H, A)
	var ev := _signals(PlayerRecord.events_between(A, d0, r.record(A).to_dict()))
	_check(&"player_picked_up" in ev and &"player_hit" in ev, "gộp nhiều bước vẫn ra sự kiện trạng thái cuối")
	_check(PlayerRecord.events_between(A, {}, d0).is_empty(), "lần đầu (chưa có bản cũ) không sinh sự kiện")


func _test_events_medkit() -> void:
	var r := _rules()
	_down(r, A)
	r.pick_up(H, A)
	var d0 := r.record(A).to_dict()
	r.use_medkit(B, A)
	var ev := _signals(PlayerRecord.events_between(A, d0, r.record(A).to_dict()))
	_check(&"player_healed" in ev and &"player_rescued" in ev, "túi máu cứu người bị kéo: healed + rescued")
	_check(not &"player_released" in ev, "không nhầm thành bị buông")


func _test_events_stun_release() -> void:
	var r := _rules()
	_down(r, A)
	r.pick_up(H, A)
	var d0 := r.record(A).to_dict()
	r.stun(H, 1.0)
	var ev := _signals(PlayerRecord.events_between(A, d0, r.record(A).to_dict()))
	_check(&"player_released" in ev and not &"player_healed" in ev, "thợ săn choáng thì sinh player_released")


func _test_items_copied_not_shared() -> void:
	var r := _rules()
	var d0 := r.record(A).to_dict()
	r.attack(H, [A])
	r.use_medkit(A, A)
	_check(d0["items"][GameTypes.ItemType.MEDKIT] == r.config.medkits_per_escapee, "bản cũ không bị đổi theo")
	var copy := PlayerRecord.new()
	copy.apply_dict(d0)
	d0["items"][GameTypes.ItemType.MEDKIT] = 99
	_check(copy.items[GameTypes.ItemType.MEDKIT] == r.config.medkits_per_escapee, "apply_dict giữ bản sao riêng")
