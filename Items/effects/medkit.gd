extends ItemEffect
## Túi cứu thương: ném ra một vùng tròn xanh. Nhắm đồng đội đang gục / bị kéo /
## bị nhốt gần nhất trong tầm (ưu tiên người bị kéo, rồi bị nhốt, rồi gục);
## không có ai thì ném dưới chân mình nếu mất máu. Túi bay FLIGHT_TIME giây,
## rơi xuống thì cứu người được nhắm và mọi người trốn khác (cả người ném) đứng
## trong bán kính AREA_RADIUS.

const FLIGHT_TIME := 0.3
const AREA_RADIUS := 2.0 # mét
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
	var center: Vector3 = p["target_pos"]
	var tree := user.get_tree()
	if target == healer:
		_land(tree, healer, target, center)
		return
	tree.create_timer(FLIGHT_TIME, false, true).timeout.connect(func() -> void: _land(tree, healer, target, center))


## Túi rơi: cứu người được nhắm (dù đã bị kéo đi một đoạn), rồi cả vùng.
func _land(tree: SceneTree, healer: int, target: int, center: Vector3) -> void:
	GameState.server_heal(healer, target)
	var c := Vector2(center.x, center.z)
	for node in tree.get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e.peer_id != target and e.flat_position().distance_to(c) <= AREA_RADIUS and GameState.rules.can_heal(healer, e.peer_id):
			GameState.server_heal(healer, e.peer_id)
