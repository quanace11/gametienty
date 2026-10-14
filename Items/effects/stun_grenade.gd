extends ItemEffect
## Lựu đạn (tên cũ "lựu đạn choáng"): tự nhắm thợ săn gần nhất trong tầm (dễ
## dùng trên điện thoại), không có thì ném thẳng trước mặt. Nổ sau FLIGHT_TIME
## giây, thợ săn trong bán kính chạy chậm SLOW_FACTOR trong SLOW_TIME giây.
## Người trốn không làm choáng được thợ săn.

const RANGE := 8.0
const RADIUS := 2.5
const SLOW_TIME := 2.0
const SLOW_FACTOR := 0.5
const FLIGHT_TIME := 0.6


func plan(user: EntityBase) -> Dictionary:
	var target := user.global_position + user.facing() * RANGE * 0.75
	var best_d := RANGE
	for node in user.get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		var d := user.flat_position().distance_to(e.flat_position())
		if e.is_hunter() and d <= best_d and GameState.can_see(user.peer_id, e.peer_id): # nấp trong bụi thì không tự nhắm được
			best_d = d
			target = e.global_position
	return {"target_pos": target}


func server_apply(user: EntityBase, p: Dictionary) -> void:
	var tree := user.get_tree()
	var pos: Vector3 = p["target_pos"]
	tree.create_timer(FLIGHT_TIME, false, true).timeout.connect(func() -> void:
		for node in tree.get_nodes_in_group(GameTypes.GROUP_ENTITIES):
			var e := node as EntityBase
			if e.is_hunter() and e.flat_position().distance_to(Vector2(pos.x, pos.z)) <= RADIUS:
				GameState.server_speed_boost(e.peer_id, SLOW_TIME, SLOW_FACTOR))
