extends ItemEffect
## Súng lục: tự nhắm thợ săn gần nhất trong tầm bullet_range, ngắm đón đầu theo
## hướng chạy. Không có thợ săn trong tầm thì không bắn (không mất tiền).
## Đạn do Core tính (GameState.server_shoot_bullet); trúng thì thợ săn mất máu,
## hết máu thì buông người đang kéo và chạy chậm vài giây (không bị choáng).


func plan(user: EntityBase) -> Dictionary:
	var cfg := GameState.rules.config
	var best: EntityBase = null
	var best_d := cfg.bullet_range
	for node in user.get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		var d := user.flat_position().distance_to(e.flat_position())
		if e.is_hunter() and d <= best_d:
			best_d = d
			best = e
	if best == null:
		return {}
	var lead := Vector3(best.velocity.x, 0.0, best.velocity.z) * (best_d / cfg.bullet_speed)
	return {"target_id": best.peer_id, "target_pos": best.global_position + lead}


func server_apply(user: EntityBase, p: Dictionary) -> void:
	GameState.server_shoot_bullet(user, p["target_pos"])
