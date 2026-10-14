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
signal match_ended(winner: GameTypes.Winner, summary: Dictionary)
signal safe_progress_changed(safe_id: int, progress: float)
signal safe_unlocked(safe_id: int, unlocked: int, required: int)
signal gate_opened

# --- Nhóm 1: người chơi ---
signal player_state_changed(id: int, old_state: GameTypes.PlayerState, new_state: GameTypes.PlayerState)
signal player_attacked(attacker_id: int) ## thợ săn vung đòn (trúng hay trượt)
signal player_hit(id: int, attacker_id: int, hp_left: int)
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

# --- Nhóm 2: cục bộ ---
## Tiếng động cho AI "nghe": bước chân, va chạm, fail QTE...
signal noise_made(position: Vector3, loudness: float)
signal qte_failed(safe_id: int, position: Vector3)
