extends ItemEffect
## Dịch chuyển (thợ săn): tới điểm đã chạm trên minimap; chưa chạm thì tới
## rương đang được mở nhiều nhất. Đứng tụ lực MatchConfig.teleport_charge giây
## (bị choáng thì hủy). Không có chỗ đứng được thì không dùng, không tính hồi chiêu.


func plan(user: EntityBase) -> Dictionary:
	var rules := GameState.rules
	var me := rules.record(user.peer_id)
	if me.carrying_id != 0 or me.teleport_left > 0.0:
		return {}
	var target: Variant = GameState.aim_point(user.peer_id)
	if target == null:
		target = _busiest_chest(user, rules)
	if target == null:
		return {}
	var spot: Variant = GameState.find_standing_spot(target)
	if spot == null:
		return {}
	return {"target_pos": spot}


func server_apply(user: EntityBase, p: Dictionary) -> void:
	GameState.server_start_teleport(user.peer_id, p["target_pos"])


## Cạnh rương chưa mở xong có tiến độ cao nhất (người trốn chắc đang ở đó).
func _busiest_chest(user: EntityBase, rules: MatchRules) -> Variant:
	var best: Variant = null
	var best_progress := -1.0
	for node in user.get_tree().get_nodes_in_group(GameTypes.GROUP_SAFES):
		var safe := node as Interactable
		var progress: float = rules.safe_progress.get(safe.interactable_id, 1.0)
		if progress < 1.0 and progress > best_progress:
			best_progress = progress
			best = safe.global_position + Vector3(1.5, 0, 0)
	return best
