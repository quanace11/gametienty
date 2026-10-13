extends Node
## Autoload "EventBus": kênh tín hiệu chung. Module chỉ giao tiếp với nhau
## qua đây và qua API công khai của Core, không gọi thẳng hàm module khác.
##
## Nhóm 1 (đồng bộ mạng): chỉ GameState phát, trên MỌI máy, sau khi server
## đã quyết. Module khác chỉ nghe, không tự emit.
## Nhóm 2 (cục bộ): module nào cũng được phát, chỉ có tác dụng trên máy đó.

# --- Nhóm 1: GameState phát ---
signal match_state_changed(state: GameTypes.MatchState)
signal player_state_changed(id: int, old_state: GameTypes.PlayerState, new_state: GameTypes.PlayerState)
signal player_downed(id: int)
signal player_imprisoned(id: int)
signal player_rescued(id: int)
signal player_escaped(id: int)
signal safe_progress_changed(safe_id: int, progress: float)
signal safe_unlocked(safe_id: int, unlocked: int, required: int)
signal gate_opened
signal match_ended(winner: GameTypes.Winner, summary: Dictionary)

# --- Nhóm 2: cục bộ ---
## Tiếng động cho AI "nghe": bước chân, va chạm, fail QTE...
signal noise_made(position: Vector2, loudness: float)
signal qte_failed(safe_id: int, position: Vector2)
