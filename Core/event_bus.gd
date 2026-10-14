extends Node
## Autoload "EventBus": kênh tín hiệu chung. Module chỉ giao tiếp với nhau
## qua đây và qua API công khai của Core, không gọi thẳng hàm module khác.
##
## Nhóm 1 (đồng bộ mạng): chỉ GameState phát, trên MỌI máy, sau khi server
## đã quyết. Module khác chỉ nghe, không tự emit. Dùng để chạy anim, âm
## thanh, hiệu ứng, HUD.
## Nhóm 2 (cục bộ): module nào cũng được phát, chỉ có tác dụng trên máy đó.

# --- Nhóm 1: trận ---
signal match_state_changed(state: GameTypes.MatchState)
signal match_ended(result: Dictionary) ## MatchRules.results(): kết quả + điểm từng người
signal safe_progress_changed(safe_id: int, progress: float) ## tiến độ rương (về 0 khi căn hỏng)
signal safe_unlocked(safe_id: int, unlocked: int, required: int) ## rương nhả chìa khóa và tiền
signal gate_opening(seconds: float) ## đủ chìa: cả 2 cổng rung, nháy đèn, mở sau `seconds` giây
signal gate_opened ## cổng mở hẳn tới hết trận
signal coin_taken(coin_id: int, by_id: int)
signal object_placed(obj_id: int, type: GameTypes.ItemType, position: Vector3, yaw: float, owner_id: int) ## bẫy, đệm lò xo, hộp gỗ
signal object_removed(obj_id: int)
## Đạn bay (cối của thợ săn, súng của người trốn): vẽ đường bay trong `flight` giây.
signal shot_fired(shot_id: int, kind: GameTypes.ShotKind, owner_id: int, from: Vector3, to: Vector3, flight: float)
signal shot_landed(shot_id: int, kind: GameTypes.ShotKind, position: Vector3) ## nổ / chạm; ai trúng thì có player_hit riêng

# --- Nhóm 1: người chơi ---
signal player_state_changed(id: int, old_state: GameTypes.PlayerState, new_state: GameTypes.PlayerState)
signal player_attacked(attacker_id: int) ## thợ săn bắn cối / vung đòn (trúng hay trượt)
signal player_hit(id: int, attacker_id: int, hp_left: int) ## người trốn trúng cối, hoặc thợ săn trúng đạn
signal player_downed(id: int, attacker_id: int)
signal player_picked_up(id: int, carrier_id: int)
signal player_dropped(id: int)
signal player_released(id: int) ## thợ săn bị choáng nên buông người đang kéo
signal player_imprisoned(id: int, prison_id: int)
signal player_rescued(id: int, rescuer_id: int) ## được đỡ dậy (giữ E) hoặc được túi máu cứu khi đang gục / bị kéo / bị nhốt
signal player_healed(id: int, healer_id: int, hp: int) ## trúng túi máu (phát trước player_rescued nếu có)
signal player_eliminated(id: int)
signal player_escaped(id: int)
signal player_stunned(id: int, seconds: float)
signal rescue_progress_changed(id: int, progress: float)
signal coins_changed(id: int, coins: int, gained: int) ## gained < 0 là vừa tiêu
signal item_used(id: int, type: GameTypes.ItemType, target_id: int, target_pos: Vector3) ## đã trả tiền, hiệu ứng đang chạy
signal teleport_started(id: int, target: Vector3, seconds: float) ## thợ săn tụ lực, tới `target` sau `seconds` (bị choáng thì hủy)
## Radar: chỉ phát trên máy của thợ săn dùng radar. Mỗi điểm: x, z là vị trí,
## y là số giây trước (dấu chân cũ thì mờ hơn).
signal footprints_revealed(points: PackedVector3Array, seconds: float)
signal qte_started(id: int, safe_id: int) ## vòng căn hiện ra cho người đang mở rương
signal qte_resolved(id: int, safe_id: int, result: GameTypes.QteResult) ## FAIL: rương nổ, báo vị trí cho thợ săn

# --- Nhóm 2: cục bộ ---
## Tiếng động cho AI "nghe": bước chân, va chạm, rương nổ...
signal noise_made(position: Vector3, loudness: float)
