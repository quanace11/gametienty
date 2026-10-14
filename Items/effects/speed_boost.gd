extends ItemEffect
## Ván trượt: chạy nhanh gấp FACTOR lần trong DURATION giây.

const DURATION := 3.5
const FACTOR := 1.7


func plan(user: EntityBase) -> Dictionary:
	return {"target_id": user.peer_id}


func server_apply(user: EntityBase, _p: Dictionary) -> void:
	GameState.server_speed_boost(user.peer_id, DURATION, FACTOR)
