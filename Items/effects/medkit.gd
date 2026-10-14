extends ItemEffect
## Túi cứu thương: ném cho đồng đội đang gục / bị kéo / bị nhốt gần nhất trong
## tầm (ưu tiên người bị kéo, rồi bị nhốt, rồi gục); không có ai thì tự dùng
## nếu mất máu. Túi bay FLIGHT_TIME giây rồi mới có tác dụng.

const FLIGHT_TIME := 0.3
const PRIORITY := {
	GameTypes.PlayerState.CARRIED: 0, GameTypes.PlayerState.IMPRISONED: 1, GameTypes.PlayerState.DOWNED: 2,
}


func plan(user: EntityBase) -> Dictionary:
	var rules := GameState.rules
	var best: EntityBase = null
	var best_key := INF
	for node in user.get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e == user or not PRIORITY.has(e.state) or not rules.can_heal(user.peer_id, e.peer_id):
			continue
		var d := user.flat_position().distance_to(e.flat_position())
		if d > rules.config.medkit_range:
			continue
		var key: float = PRIORITY[e.state] * 1000.0 + d
		if key < best_key:
			best_key = key
			best = e
	if best:
		return {"target_id": best.peer_id, "target_pos": best.global_position}
	if rules.can_heal(user.peer_id, user.peer_id):
		return {"target_id": user.peer_id, "target_pos": user.global_position}
	return {}


func server_apply(user: EntityBase, p: Dictionary) -> void:
	var healer := user.peer_id
	var target: int = p["target_id"]
	if target == healer:
		GameState.server_heal(healer, target)
		return
	user.get_tree().create_timer(FLIGHT_TIME, false, true).timeout.connect(func() -> void:
		GameState.server_heal(healer, target))
