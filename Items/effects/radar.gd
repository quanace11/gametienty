extends ItemEffect
## Radar (thợ săn): dấu chân mờ của người trốn trong vài giây gần nhất hiện
## trên minimap và dưới đất trong MatchConfig.radar_time giây. Chỉ máy thợ săn thấy.


func plan(user: EntityBase) -> Dictionary:
	return {"target_id": user.peer_id}


func server_apply(user: EntityBase, _p: Dictionary) -> void:
	GameState.server_reveal_footprints(user.peer_id, GameState.rules.config.radar_time)
