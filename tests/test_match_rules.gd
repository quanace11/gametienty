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
		&"_test_hunter_result_tiers",
		&"_test_individual_results_and_score",
		&"_test_timeout_counts_as_caught",
		&"_test_hunter_left_remaining_escape",
		&"_test_chest_opens_with_time",
		&"_test_two_openers_faster",
		&"_test_gate_opens_after_delay",
		&"_test_escape_waits_for_gate",
		&"_test_qte_appears",
		&"_test_qte_perfect",
		&"_test_qte_good",
		&"_test_qte_fail_resets_chest",
		&"_test_qte_timeout_fails",
		&"_test_qte_cancel_when_leaving",
		&"_test_qte_grace_for_late_press",
		&"_test_qte_rejected",
		&"_test_chest_coins_spawn",
		&"_test_take_coin",
		&"_test_world_roundtrip_and_events",
		&"_test_events_qte_and_coins",
		&"_test_player_diff_small",
		&"_test_world_diff",
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
		&"_test_use_item_rules",
		&"_test_item_cooldown_client_tick",
		&"_test_speed_boost",
		&"_test_place_objects",
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
		&"_test_mortar_flies_then_hits",
		&"_test_mortar_range_clamped_and_cooldown",
		&"_test_mortar_only_hits_escapees",
		&"_test_bullet_damages_hunter",
		&"_test_hunter_knockout_releases_and_recovers",
		&"_test_shots_world_sync",
		&"_test_damage_scores",
		&"_test_teleport_charge",
		&"_test_teleport_rejected_and_cancelled",
		&"_test_deck_validation",
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
	var r := MatchRules.new(cfg, roles, {}, 3, 2)
	r.rng.seed = 42
	var items := {
		GameTypes.ItemType.MEDKIT: {"cost": 10, "cooldown": 6.0},
		GameTypes.ItemType.STUN_GRENADE: {"cost": 10, "cooldown": 12.0},
	}
	r.setup_items(items, {}, {GameTypes.Role.ESCAPEE: [GameTypes.ItemType.MEDKIT, GameTypes.ItemType.STUN_GRENADE, 999]})
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


## Mở xong rương ngay (bỏ qua vòng căn).
func _open_chest(r: MatchRules, safe_id: int) -> void:
	r.safe_progress[safe_id] = 0.99
	r._add_chest_progress(safe_id, 0.01)


## Cạy rương cho tới khi vòng căn hiện ra.
func _start_qte(r: MatchRules, id: int, safe_id: int = 0) -> PlayerRecord:
	for i in 100:
		r.channel_chest(id, safe_id, 0.05)
		if r.record(id).qte_chest >= 0:
			break
	return r.record(id)


## Đặt đồng hồ để kim nằm ở vị trí `needle` trên vòng.
func _set_needle(r: MatchRules, p: PlayerRecord, needle: float) -> void:
	r.elapsed = p.qte_started + needle / r.config.qte_speed


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
	for id in [A, B, C]:
		_imprison(r, id)
	_check(not r.is_over(), "còn 1 người chạy thì chưa hết trận")
	_imprison(r, D)
	_check(r.is_over(), "nhốt hết thì hết trận")
	_check(r.results()["hunter_result"] == GameTypes.HunterResult.TOTAL, "bắt cả 4: thắng tuyệt đối")


func _test_hunter_result_tiers() -> void:
	var r := _rules()
	_check(r.hunter_result(0, 4) == GameTypes.HunterResult.LOSE, "bắt 0/4: thua")
	_check(r.hunter_result(1, 4) == GameTypes.HunterResult.LOSE, "bắt 1/4: thua")
	_check(r.hunter_result(2, 4) == GameTypes.HunterResult.PARTIAL, "bắt 2/4: thắng một phần")
	_check(r.hunter_result(3, 4) == GameTypes.HunterResult.PARTIAL, "bắt 3/4: thắng một phần")
	_check(r.hunter_result(4, 4) == GameTypes.HunterResult.TOTAL, "bắt 4/4: thắng tuyệt đối")
	_check(r.hunter_result(0, 1) == GameTypes.HunterResult.LOSE and r.hunter_result(1, 1) == GameTypes.HunterResult.TOTAL, "1 người trốn")


func _test_individual_results_and_score() -> void:
	var r := _rules()
	r.gate_open = true
	r.record(A).coins_earned = 10
	r.record(A).rescues = 1
	r.escape(A)
	r.record(B).coins_earned = 10
	r.record(B).rescues = 1
	r.players[B].state = S.ELIMINATED
	r.players[C].state = S.ELIMINATED
	r.escape(D)
	_check(r.is_over(), "không còn ai ở ngoài thì hết trận")
	var res := r.results()
	var rows: Dictionary = res["players"]
	_check(rows[A]["result"] == GameTypes.EscapeeResult.ESCAPED and rows[B]["result"] == GameTypes.EscapeeResult.CAUGHT, "kết quả tính riêng từng người")
	_check(rows[A]["score"] == rows[B]["score"] + r.config.score_escape, "người thoát có thêm điểm sống sót, còn lại bằng nhau")
	_check(rows[B]["score"] == 10 * r.config.score_per_coin + r.config.score_rescue, "người bị bắt vẫn có điểm tiền + cứu bạn")
	_check(res["caught"] == 2 and res["escaped"] == 2, "đếm bắt / thoát")
	_check(res["hunter_result"] == GameTypes.HunterResult.PARTIAL and rows[H]["result"] == GameTypes.HunterResult.PARTIAL, "bắt 2: thợ săn thắng một phần")


func _test_timeout_counts_as_caught() -> void:
	var r := _rules()
	r.gate_open = true
	r.escape(A)
	r.tick(1000.0)
	_check(r.is_over(), "hết giờ thì hết trận")
	var res := r.results()
	_check(res["caught"] == 3, "kẹt lại trong map khi hết giờ tính là bị bắt")
	_check(res["hunter_result"] == GameTypes.HunterResult.PARTIAL, "bắt 3/4")


func _test_hunter_left_remaining_escape() -> void:
	var r := _rules()
	_imprison(r, A)
	r.remove_player(H)
	_check(r.is_over(), "thợ săn rời trận thì hết trận")
	var res := r.results()
	_check(res["caught"] == 1 and res["players"][B]["result"] == GameTypes.EscapeeResult.ESCAPED, "ai chưa bị nhốt coi như thoát")


# ---------- Rương, cổng, vòng căn, tiền ----------

func _test_chest_opens_with_time() -> void:
	var r := _rules()
	r.config.qte_interval_min = 999.0 # không cho vòng căn hiện
	r.config.qte_interval_max = 999.0
	_check(not r.channel_chest(A, 0, r.config.chest_open_time * 0.5), "mở được một nửa")
	_check(is_equal_approx(r.safe_progress[0], 0.5), "tiến độ 50%")
	_check(r.channel_chest(A, 0, r.config.chest_open_time * 0.5), "mở xong")
	_check(r.safes_unlocked() == 1, "có 1 chìa")
	_check(not r.channel_chest(A, 0, 1.0), "rương đã mở thì thôi")
	_check(is_equal_approx(r.record(A).chest_work, 1.0), "ghi công mở rương")
	_check(not r.channel_chest(H, 1, 1.0), "thợ săn không cạy rương")
	_down(r, B)
	_check(not r.channel_chest(B, 1, 1.0), "đang gục thì không cạy")


func _test_two_openers_faster() -> void:
	var r := _rules()
	r.config.qte_interval_min = 999.0
	r.config.qte_interval_max = 999.0
	var half := r.config.chest_open_time * 0.5
	r.channel_chest(A, 0, half)
	_check(r.channel_chest(B, 0, half), "hai người cùng cạy thì nhanh gấp đôi")


func _test_gate_opens_after_delay() -> void:
	var r := _rules()
	_open_chest(r, 0)
	_open_chest(r, 1)
	_check(r.gate_opening_left == 0.0 and not r.gate_open, "chưa đủ chìa thì cổng im")
	_open_chest(r, 2)
	_check(is_equal_approx(r.gate_opening_left, r.config.gate_open_delay) and not r.gate_open, "đủ chìa: cổng rung 3 giây")
	r.tick(r.config.gate_open_delay - 0.1)
	_check(not r.gate_open, "chưa hết 3 giây thì chưa mở")
	r.tick(0.2)
	_check(r.gate_open, "hết 3 giây thì mở hẳn")
	r.tick(100.0)
	_check(r.gate_open, "mở vĩnh viễn")


func _test_escape_waits_for_gate() -> void:
	var r := _rules()
	for i in 3:
		_open_chest(r, i)
	_check(not r.escape(A), "cổng đang rung thì chưa thoát được")
	r.tick(r.config.gate_open_delay + 0.1)
	_check(r.escape(A), "cổng mở thì thoát")


func _test_qte_appears() -> void:
	var r := _rules()
	var p := _start_qte(r, A)
	_check(p.qte_chest == 0, "cạy một lúc thì vòng căn hiện ra")
	_check(p.qte_zone >= r.config.qte_zone_min and p.qte_zone <= r.config.qte_zone_max, "vùng sáng nằm trong khoảng cho phép")
	_check(is_equal_approx(r.qte_needle(A), 0.0) or r.qte_needle(A) >= 0.0, "kim bắt đầu từ đầu vòng")
	_check(r.qte_needle(B) == -1.0, "người không cạy thì không có vòng")


func _test_qte_perfect() -> void:
	var r := _rules()
	var p := _start_qte(r, A)
	var before: float = r.safe_progress[0]
	_set_needle(r, p, p.qte_zone)
	_check(r.resolve_qte(A) == GameTypes.QteResult.PERFECT, "kim ở giữa vùng sáng: hoàn hảo")
	_check(is_equal_approx(r.safe_progress[0], before + r.config.qte_perfect_bonus), "rương mở nhanh thêm một đoạn")
	_check(p.coins == r.config.start_coins + r.config.qte_perfect_coins and p.qte_perfect == 1, "được tiền, đếm lần căn đẹp")
	_check(p.qte_chest == -1, "vòng căn biến mất")
	_check(r.resolve_qte(A) == GameTypes.QteResult.NONE, "bấm thêm khi không có vòng thì không sao")


func _test_qte_good() -> void:
	var r := _rules()
	var p := _start_qte(r, A)
	var before: float = r.safe_progress[0]
	_set_needle(r, p, p.qte_zone - (r.config.qte_perfect_width + r.config.qte_good_width) / 2.0)
	_check(r.resolve_qte(A) == GameTypes.QteResult.GOOD, "kim ở vùng mờ: được")
	_check(is_equal_approx(r.safe_progress[0], before), "vùng mờ không tăng tốc")
	_check(p.coins == r.config.start_coins + r.config.qte_good_coins, "nhưng được ít tiền hơn")


func _test_qte_fail_resets_chest() -> void:
	var r := _rules()
	var p := _start_qte(r, A)
	_check(r.safe_progress[0] > 0.0, "đã cạy được một ít")
	_set_needle(r, p, p.qte_zone - r.config.qte_good_width * 2.0)
	_check(r.resolve_qte(A) == GameTypes.QteResult.FAIL, "bấm ngoài vùng: hỏng")
	_check(r.safe_progress[0] == 0.0, "rương về 0, mở lại từ đầu")
	_check(p.coins == r.config.start_coins and p.qte_result == GameTypes.QteResult.FAIL and p.qte_result_chest == 0, "không được tiền, ghi kết quả")


func _test_qte_timeout_fails() -> void:
	var r := _rules()
	var p := _start_qte(r, A)
	var seq := p.qte_seq
	for i in 100: # vẫn đứng cạy nhưng không bấm
		r.channel_chest(A, 0, 0.05)
		r.tick(0.05)
		if p.qte_seq > seq:
			break
	_check(p.qte_result == GameTypes.QteResult.FAIL and p.qte_chest == -1, "kim chạy hết vòng mà không bấm: hỏng")
	_check(r.safe_progress[0] == 0.0, "rương về 0")


func _test_qte_cancel_when_leaving() -> void:
	var r := _rules()
	var p := _start_qte(r, A)
	var seq := p.qte_seq
	r.tick(MatchRules.CHEST_CHANNEL_GRACE + 0.05)
	_check(p.qte_chest == -1 and p.qte_seq == seq, "rời rương: vòng căn biến mất, không tính hỏng")
	_check(r.safe_progress[0] > 0.0, "tiến độ rương vẫn giữ")


func _test_qte_grace_for_late_press() -> void:
	var r := _rules()
	var p := _start_qte(r, A)
	# Người chơi bấm đúng giữa vùng, server nhận sau 0.1 giây.
	_set_needle(r, p, p.qte_zone + 0.1 * r.config.qte_speed)
	_check(r.resolve_qte(A, 0.1) == GameTypes.QteResult.PERFECT, "bù đúng độ trễ đo được")
	p = _start_qte(r, A)
	_set_needle(r, p, p.qte_zone + 0.5 * r.config.qte_speed)
	_check(r.resolve_qte(A, 5.0) == GameTypes.QteResult.FAIL, "độ trễ khai quá lớn bị kẹp, không gian lận được")


func _test_qte_rejected() -> void:
	var r := _rules()
	_check(r.resolve_qte(A) == GameTypes.QteResult.NONE, "không có vòng căn thì không chấm")
	var p := _start_qte(r, A)
	r.attack(H, [A])
	r.tick(r.config.attack_cooldown + 0.01)
	r.attack(H, [A])
	r.tick(0.01)
	_check(p.qte_chest == -1, "bị đánh gục thì vòng căn bị hủy")


func _test_chest_coins_spawn() -> void:
	var r := _rules()
	var ids := r.chest_coin_ids(1)
	_check(ids.size() == r.config.chest_coins, "đủ số cọc tiền")
	_check(not r.coins.has(ids[0]), "chưa mở thì chưa có tiền")
	_open_chest(r, 1)
	_check(ids.all(func(c: int) -> bool: return r.coins.has(c)), "mở xong thì tiền văng ra")
	_check(r.coins.has(0) and r.coins.has(1), "tiền rải sẵn trên sàn")


func _test_take_coin() -> void:
	var r := _rules()
	_check(r.take_coin(A, 0), "nhặt tiền")
	_check(r.record(A).coins == r.config.start_coins + r.config.floor_coin_value and r.record(A).coins_earned == r.config.floor_coin_value, "cộng tiền")
	_check(not r.take_coin(B, 0), "cọc đã nhặt thì thôi")
	_check(not r.take_coin(H, 1), "thợ săn không nhặt tiền")
	_check(not r.take_coin(A, 999), "cọc không tồn tại")
	_check(r.coins_taken[0] == A, "ghi ai nhặt")


func _test_world_roundtrip_and_events() -> void:
	var r := _rules()
	var w0 := r.world_dict()
	for i in 3:
		_open_chest(r, i)
	r.take_coin(A, 0)
	var w1 := r.world_dict()
	var ev := _signals(WorldRecord.events_between(w0, w1, r.safes_required()))
	_check(ev.count(&"safe_unlocked") == 3 and &"gate_opening" in ev and &"coin_taken" in ev, "sự kiện rương, cổng đang mở, nhặt tiền")
	_check(not &"gate_opened" in ev, "chưa mở hẳn")
	var client := _rules()
	client.apply_world_dict(w1)
	_check(client.safes_unlocked() == 3 and client.coins.has(r.chest_coin_ids(0)[0]) and not client.coins.has(0), "client dựng lại đúng rương và tiền")
	r.tick(r.config.gate_open_delay + 0.1)
	_check(&"gate_opened" in _signals(WorldRecord.events_between(w1, r.world_dict(), 3)), "sự kiện cổng mở hẳn")


func _test_events_qte_and_coins() -> void:
	var r := _rules()
	var d0 := r.record(A).to_dict()
	var p := _start_qte(r, A)
	var d1 := p.to_dict()
	_check(&"qte_started" in _signals(PlayerRecord.events_between(A, d0, d1)), "sự kiện vòng căn hiện")
	_set_needle(r, p, p.qte_zone)
	r.resolve_qte(A)
	var ev := _signals(PlayerRecord.events_between(A, d1, p.to_dict()))
	_check(&"qte_resolved" in ev and &"coins_changed" in ev, "sự kiện kết quả căn + tiền")


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
	_check(not r.heal(B, A), "chết rồi thì túi máu không cứu được")


func _test_no_imprison_limit_by_default() -> void:
	var r := _rules()
	for i in 3:
		_imprison(r, A)
		_check(r.state_of(A) == S.IMPRISONED, "bị nhốt lần %d vẫn còn cơ hội" % (i + 1))
		r.heal(B, A)
		r.tick(r.config.hit_invulnerable_time + 0.1)


func _test_imprison_limit_when_set() -> void:
	var r := _rules()
	r.config.max_imprisonments = 2
	_imprison(r, A)
	r.heal(B, A)
	r.tick(r.config.hit_invulnerable_time + 0.1)
	_imprison(r, A)
	_check(r.state_of(A) == S.ELIMINATED, "đặt giới hạn 2 thì bị nhốt lần 2 là bị loại")


# ---------- Túi máu ----------

func _test_medkit_starting_count() -> void:
	var r := _rules()
	_check(r.record(A).deck == [GameTypes.ItemType.MEDKIT, GameTypes.ItemType.STUN_GRENADE], "người trốn có bộ bài mặc định")
	_check(r.record(H).deck.is_empty(), "thợ săn chưa có thẻ")
	_check(r.record(A).coins == r.config.start_coins, "vào trận có sẵn ít tiền")


func _test_medkit_revives_downed() -> void:
	var r := _rules()
	_down(r, A)
	_check(r.heal(B, A), "ném túi máu cho người gục")
	_check(r.state_of(A) == S.IDLE and r.record(A).hp == r.config.medkit_heal, "đứng dậy ngay với máu hồi")
	_check(r.record(A).invulnerable_left > 0.0, "vừa được cứu thì bất tử một lúc")
	_check(r.record(A).last_rescuer_id == B, "ghi lại người cứu")


func _test_medkit_frees_carried() -> void:
	var r := _rules()
	_down(r, A)
	r.pick_up(H, A)
	_check(r.heal(B, A), "ném túi máu cho người đang bị kéo")
	_check(r.state_of(A) == S.IDLE and r.record(A).carrier_id == 0, "bung khỏi tay thợ săn")
	r.tick(r.config.attack_cooldown + 0.01)
	_check(r.record(H).carrying_id == 0 and r.can_attack(H), "thợ săn hết kéo, đánh tiếp được")


func _test_medkit_frees_inmate() -> void:
	var r := _rules()
	_imprison(r, A, 1)
	r.tick(10.0)
	_check(r.heal(B, A), "ném túi máu vào tù")
	_check(r.state_of(A) == S.IDLE and r.record(A).prison_id == -1, "người trong tù sống lại")
	r.tick(100.0)
	_check(r.state_of(A) == S.IDLE, "sống rồi thì không bị đốt nữa")


func _test_medkit_heals_standing() -> void:
	var r := _rules()
	r.attack(H, [A])
	_check(r.heal(A, A), "tự dùng túi máu khi mất máu")
	_check(r.record(A).hp == r.config.max_hp, "hồi máu")
	_check(not r.heal(A, A) and not r.can_heal(A, A), "đầy máu thì không có tác dụng")


func _test_medkit_rejected() -> void:
	var r := _rules()
	_down(r, A)
	_down(r, B)
	_check(not r.heal(A, B), "đang gục thì không ném được")
	_check(not r.heal(H, A), "thợ săn không dùng túi máu")
	_check(not r.heal(C, H), "không hồi máu cho thợ săn")
	r.stun(C, 1.0)
	_check(not r.heal(C, A), "đang choáng thì không ném được")
	r.take_dirty()
	_check(not r.heal(C, A) and r.take_dirty().is_empty(), "bị từ chối thì không đổi gì")


func _test_medkit_runs_out() -> void:
	var r := _rules()
	r.record(B).coins = 15 # đủ 1 túi (10), thiếu túi thứ 2
	_down(r, A)
	_check(r.use_item(B, 0, A), "trả tiền dùng thẻ túi máu")
	_check(r.record(B).coins == 5 and r.record(B).item_cooldowns[0] == 6.0, "trừ tiền, tính hồi chiêu")
	_check(not r.can_use_item(B, 0), "đang hồi chiêu thì chưa dùng lại được")
	r.tick(6.1)
	_check(not r.can_use_item(B, 0), "hết hồi chiêu nhưng thiếu tiền thì không dùng được")
	r.record(B).coins = 100
	_check(r.can_use_item(B, 0), "đủ tiền thì dùng được")


# ---------- Thẻ đạo cụ ----------

func _test_use_item_rules() -> void:
	var r := _rules()
	_check(not r.can_use_item(A, 5), "ô thẻ không tồn tại")
	_check(not r.can_use_item(H, 0), "thợ săn không có thẻ")
	var seq := r.record(A).item_seq
	_check(r.use_item(A, 1, H, Vector3(1, 0, 2)), "dùng lựu đạn")
	var p := r.record(A)
	_check(p.item_seq == seq + 1 and p.item_last_type == GameTypes.ItemType.STUN_GRENADE and p.item_target_pos == Vector3(1, 0, 2), "ghi lại để mọi máy phát item_used")
	_down(r, B)
	_check(not r.can_use_item(B, 0), "đang gục thì không dùng thẻ")
	r.stun(C, 1.0)
	_check(not r.can_use_item(C, 0), "đang choáng thì không dùng thẻ")


func _test_item_cooldown_client_tick() -> void:
	var r := _rules()
	r.use_item(A, 1)
	r.tick(2.0, false)
	_check(is_equal_approx(r.record(A).item_cooldowns[1], 10.0), "client cũng đếm lùi hồi chiêu để hiển thị")


func _test_speed_boost() -> void:
	var r := _rules()
	_check(r.speed_boost(A, 2.0, 1.5), "tăng tốc")
	_check(is_equal_approx(r.speed_factor(A), 1.5), "chạy nhanh hơn")
	r.tick(2.1)
	_check(r.speed_factor(A) == 1.0, "hết giờ thì về bình thường")
	r.speed_boost(A, 2.0, 1.5)
	_down(r, A)
	_check(is_equal_approx(r.speed_factor(A), r.config.downed_speed), "đang gục thì không được tăng tốc")


func _test_place_objects() -> void:
	var r := _rules()
	var w0 := r.world_dict()
	var trap := r.place(GameTypes.ItemType.TRAP, Vector3(3, 0, 4), 0.5, A, 5.0)
	var pad := r.place(GameTypes.ItemType.JUMP_PAD, Vector3(5, 0, 4), 0.0, B, 0.0)
	_check(trap > 0 and pad > trap, "id vật thể tăng dần")
	var w1 := r.world_dict()
	var sigs := _signals(WorldRecord.events_between(w0, w1, 3))
	_check(sigs.count(&"object_placed") == 2, "sự kiện đặt vật thể")
	_check(WorldRecord.apply_diff(w0, WorldRecord.diff(w0, w1)) == w1, "diff có vật thể mới")
	r.tick(5.1)
	_check(not r.placed.has(trap) and r.placed.has(pad), "hết giờ thì bẫy biến mất, đệm không hạn thì còn")
	var w2 := r.world_dict()
	_check(&"object_removed" in _signals(WorldRecord.events_between(w1, w2, 3)), "sự kiện vật thể biến mất")
	_check(WorldRecord.apply_diff(w1, WorldRecord.diff(w1, w2)) == w2, "diff có vật thể bị xóa")
	_check(r.remove_placed(pad) and not r.remove_placed(pad), "xóa một lần")


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
	r.heal(B, A)
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
	r.heal(B, A)
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
	r.use_item(A, 1)
	_check(d0["item_cooldowns"][1] == 0.0, "bản cũ không bị đổi theo")
	var copy := PlayerRecord.new()
	copy.apply_dict(d0)
	d0["deck"][0] = 99
	_check(copy.deck[0] == GameTypes.ItemType.MEDKIT, "apply_dict giữ bản sao riêng")


func _test_player_diff_small() -> void:
	var r := _rules()
	var d0 := r.record(A).to_dict()
	r.channel_chest(A, 0, 0.1)
	var d1 := r.record(A).to_dict()
	var changes := PlayerRecord.diff(d0, d1)
	_check(PlayerRecord.apply_diff(d0, changes) == d1, "dựng lại đúng từ diff")
	_check(changes.size() <= 2, "cạy rương chỉ gửi đúng một trường đổi")
	_check(var_to_bytes(changes).size() < 40, "gói cập nhật thường xuyên dưới 40 byte")
	_check(PlayerRecord.diff(d1, d1).is_empty(), "không đổi gì thì không gửi")
	_check(var_to_bytes(PlayerRecord.diff({}, d1)).size() < var_to_bytes(d1).size(), "gói đầy đủ vẫn nhỏ hơn dict có tên trường")


func _test_world_diff() -> void:
	var r := _rules()
	var w0 := r.world_dict()
	r.take_coin(A, 0)
	_open_chest(r, 1)
	var w1 := r.world_dict()
	var changes := WorldRecord.diff(w0, w1)
	_check(WorldRecord.apply_diff(w0, changes) == w1, "dựng lại đúng thế giới từ diff")
	_check(changes["safes"].size() == 1 and changes["coins_taken"].size() == 1, "chỉ gửi rương đổi và cọc mới nhặt")
	_check(WorldRecord.diff(w1, w1).is_empty(), "không đổi gì thì không gửi")


# ---------- Bắn ----------

func _test_mortar_flies_then_hits() -> void:
	var r := _rules()
	var shot := r.fire_mortar(H, Vector3.ZERO, Vector3(7, 0, 0))
	_check(shot != 0 and r.shots.has(shot), "bắn cối tạo đạn bay")
	_check(r.record(H).attack_seq == 1 and r.record(H).attack_cooldown_left > 0.0, "bắn cối tính là một đòn")
	_check(r.due_shots().is_empty(), "đạn chưa tới nơi")
	r.tick(r.config.mortar_min_flight + 7.0 / r.config.mortar_speed + 0.01)
	_check(r.due_shots() == [shot], "hết thời gian bay thì đạn tới nơi")
	_check(r.land_shot(shot, [A, B]), "đạn rơi")
	_check(r.record(A).hp == r.config.max_hp - 1 and r.record(B).hp == r.config.max_hp - 1, "người trong vùng nổ mất máu")
	_check(r.record(A).last_attacker_id == H, "ghi lại người bắn")
	_check(not r.shots.has(shot) and not r.land_shot(shot, [A]), "đạn rơi rồi thì không rơi lần nữa")


func _test_mortar_range_clamped_and_cooldown() -> void:
	var r := _rules()
	var shot := r.fire_mortar(H, Vector3.ZERO, Vector3(100, 0, 0))
	var to: Vector3 = r.shots[shot]["to"]
	_check(is_equal_approx(Vector2(to.x, to.z).length(), r.config.mortar_range), "điểm rơi bị kẹp trong tầm cối")
	_check(r.fire_mortar(H, Vector3.ZERO, Vector3(3, 0, 0)) == 0, "đang hồi chiêu thì không bắn được")
	_check(r.fire_mortar(A, Vector3.ZERO, Vector3(3, 0, 0)) == 0, "người trốn không bắn cối")
	r.stun(H, r.config.attack_cooldown + 1.0)
	r.tick(r.config.attack_cooldown + 0.01)
	_check(r.record(H).stunned_left > 0.0 and r.fire_mortar(H, Vector3.ZERO, Vector3(3, 0, 0)) == 0, "đang choáng thì không bắn")


func _test_mortar_only_hits_escapees() -> void:
	var r := _rules()
	var shot := r.fire_mortar(H, Vector3.ZERO, Vector3(2, 0, 0))
	r.tick(2.0)
	r.land_shot(shot, [H, A])
	_check(r.record(H).hp == r.config.hunter_max_hp, "cối không làm thợ săn mất máu")
	_check(r.record(A).hp == r.config.max_hp - 1, "cối trúng người trốn")


func _test_bullet_damages_hunter() -> void:
	var r := _rules()
	_check(r.record(H).hp == r.config.hunter_max_hp, "thợ săn có máu riêng")
	var shot := r.shoot_bullet(A, Vector3.ZERO, Vector3(5, 0, 0))
	_check(shot != 0, "người trốn bắn được súng")
	_check(r.shoot_bullet(H, Vector3.ZERO, Vector3(5, 0, 0)) == 0, "thợ săn không bắn súng lục")
	r.tick(1.0)
	r.land_shot(shot, [H, B])
	_check(r.record(H).hp == r.config.hunter_max_hp - r.config.bullet_damage, "đạn trúng thợ săn")
	_check(r.record(B).hp == r.config.max_hp, "đạn súng không làm người trốn mất máu")
	_check(r.record(A).damage_dealt == r.config.bullet_damage, "ghi công bắn cho người bắn")


func _test_hunter_knockout_releases_and_recovers() -> void:
	var r := _rules()
	r.attack(H, [A])
	r.tick(r.config.attack_cooldown + 0.01)
	r.attack(H, [A])
	r.pick_up(H, A)
	_check(r.state_of(A) == S.CARRIED, "đang kéo A")
	r.damage_hunter(H, r.config.hunter_max_hp - 1, B)
	_check(r.record(H).stunned_left <= 0.0 and r.state_of(A) == S.CARRIED, "còn máu thì chưa choáng")
	r.damage_hunter(H, 5, B)
	_check(r.record(H).hp == 0 and r.record(H).stunned_left > 0.0, "hết máu thì bị choáng")
	_check(r.state_of(A) == S.IDLE and r.record(H).carrying_id == 0, "bị bắn gục thì buông người đang kéo")
	_check(r.record(B).damage_dealt == r.config.hunter_max_hp, "không tính sát thương thừa")
	_check(not r.damage_hunter(H, 1, B), "đang gục thì bắn không mất thêm máu")
	r.tick(r.config.hunter_knockout_stun + 0.01)
	_check(r.record(H).hp == r.config.hunter_max_hp and r.record(H).stunned_left <= 0.0, "tỉnh lại thì hồi đầy máu")
	var r2 := _rules()
	r2.damage_hunter(H, 99, B)
	r2.tick(r2.config.hunter_knockout_stun + 0.01, false)
	_check(r2.record(H).hp == 0, "client không tự hồi máu thợ săn")


func _test_shots_world_sync() -> void:
	var r := _rules()
	var w0 := r.world_dict()
	var shot := r.fire_mortar(H, Vector3(0, 1, 0), Vector3(4, 0, 0))
	var w1 := r.world_dict()
	var changes := WorldRecord.diff(w0, w1)
	_check(changes.has("shot_add") and changes.size() == 1, "chỉ gửi đạn mới")
	_check(WorldRecord.apply_diff(w0, changes) == w1, "dựng lại đúng đạn từ diff")
	var ev := WorldRecord.events_between(w0, w1, 3)
	_check(ev.size() == 1 and ev[0]["signal"] == &"shot_fired", "sự kiện bắn")
	_check(is_equal_approx(ev[0]["args"][5], r.config.mortar_min_flight + 4.0 / r.config.mortar_speed), "thời gian bay gửi kèm")
	r.tick(2.0)
	r.land_shot(shot, [])
	var w2 := r.world_dict()
	var c2 := WorldRecord.diff(w1, w2)
	_check(c2.get("shot_remove", []) == [shot], "đạn rơi chỉ gửi id")
	_check(WorldRecord.apply_diff(w1, c2) == w2, "dựng lại đúng khi đạn rơi")
	_check(_signals(WorldRecord.events_between(w1, w2, 3)) == [&"shot_landed"], "sự kiện đạn rơi")
	var client := _rules()
	client.apply_world_dict(w1)
	_check(client.shots.has(shot), "client nhận đạn đang bay")


func _test_damage_scores() -> void:
	var r := _rules()
	r.damage_hunter(H, 2, A)
	var res := r.results()
	_check(res["players"][A]["damage"] == 2, "kết quả có sát thương")
	_check(res["players"][A]["score"] - res["players"][B]["score"] == 2 * r.config.score_damage, "sát thương được cộng điểm")


# ---------- Dịch chuyển, bộ bài ----------

func _test_teleport_charge() -> void:
	var r := _rules()
	var before := r.record(H).to_dict()
	_check(r.start_teleport(H, Vector3(10, 0, 5)), "thợ săn bắt đầu tụ lực")
	_check(not r.can_move(H) and not r.can_attack(H), "đang tụ lực thì đứng yên, không bắn")
	var ev := PlayerRecord.events_between(H, before, r.record(H).to_dict())
	_check(&"teleport_started" in _signals(ev), "sự kiện tụ lực")
	r.tick(r.config.teleport_charge * 0.5)
	_check(r.take_teleports().is_empty(), "chưa tụ đủ thì chưa đi")
	r.tick(r.config.teleport_charge)
	_check(r.take_teleports() == [H] and r.take_teleports().is_empty(), "tụ đủ thì báo dời một lần")
	_check(r.can_move(H), "tới nơi thì đi lại được")
	var c := _rules()
	c.start_teleport(H, Vector3(10, 0, 5))
	c.tick(c.config.teleport_charge + 0.1, false)
	_check(c.take_teleports().is_empty(), "client không tự dời")


func _test_teleport_rejected_and_cancelled() -> void:
	var r := _rules()
	_check(not r.start_teleport(A, Vector3.ZERO), "người trốn không dịch chuyển")
	r.start_teleport(H, Vector3.ZERO)
	_check(not r.start_teleport(H, Vector3.ONE), "đang tụ lực thì không bắt đầu lại")
	r.stun(H, 1.0)
	_check(r.record(H).teleport_left == 0.0, "bị choáng thì hủy dịch chuyển")
	r.tick(r.config.teleport_charge + 1.1)
	_check(r.take_teleports().is_empty(), "đã hủy thì không dời")
	r.attack(H, [A])
	r.tick(r.config.attack_cooldown + 0.01)
	r.attack(H, [A])
	r.pick_up(H, A)
	_check(not r.start_teleport(H, Vector3.ZERO), "đang kéo người thì không dịch chuyển")


func _test_deck_validation() -> void:
	var cfg := MatchConfig.new()
	var roles := {H: GameTypes.Role.HUNTER, A: GameTypes.Role.ESCAPEE, B: GameTypes.Role.ESCAPEE}
	var r := MatchRules.new(cfg, roles, {}, 3)
	var M := GameTypes.ItemType.MEDKIT
	var G := GameTypes.ItemType.STUN_GRENADE
	var R := GameTypes.ItemType.RADAR
	var items := {
		M: {"cost": 1, "cooldown": 1.0, "roles": [GameTypes.Role.ESCAPEE]},
		G: {"cost": 1, "cooldown": 1.0, "roles": [GameTypes.Role.ESCAPEE]},
		R: {"cost": 0, "cooldown": 1.0, "roles": [GameTypes.Role.HUNTER]},
	}
	var defaults := {GameTypes.Role.ESCAPEE: [M, G], GameTypes.Role.HUNTER: [R]}
	r.setup_items(items, {A: [G, G, R, 999, "x", M], H: [M, G], B: "rác"}, defaults)
	_check(r.record(A).deck == [G, M], "bỏ thẻ trùng, thẻ của vai khác, thẻ không có")
	_check(r.record(H).deck == [R], "thợ săn chọn bài người trốn thì về bộ mặc định")
	_check(r.record(B).deck == [M, G], "dữ liệu rác thì về bộ mặc định")
	_check(r.record(A).item_cooldowns.size() == 2, "hồi chiêu theo số ô")
