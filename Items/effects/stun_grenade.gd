extends ItemEffect
## Lựu đạn (tên cũ "lựu đạn choáng"): kéo thẻ để chọn chỗ ném (tối đa
## ItemData.aim_range), chạm nhanh thì nổ ngay dưới chân. Nổ sau FLIGHT_TIME
## giây, thợ săn trong bán kính ItemData.area_radius chạy chậm SLOW_FACTOR trong
## SLOW_TIME giây. Người trốn không làm choáng được thợ săn.

const AimPoint = preload("res://Items/effects/aim_point.gd")
const SLOW_TIME := 2.0
const SLOW_FACTOR := 0.5
const FLIGHT_TIME := 0.6


func plan(user: EntityBase) -> Dictionary:
	return {"target_pos": AimPoint.of(user, GameTypes.ItemType.STUN_GRENADE)}


func server_apply(user: EntityBase, p: Dictionary) -> void:
	var tree := user.get_tree()
	var pos: Vector3 = p["target_pos"]
	var radius := float(GameState.rules.catalog.get(GameTypes.ItemType.STUN_GRENADE, {}).get("area", 2.5))
	tree.create_timer(FLIGHT_TIME, false, true).timeout.connect(func() -> void:
		for node in tree.get_nodes_in_group(GameTypes.GROUP_ENTITIES):
			var e := node as EntityBase
			if e.is_hunter() and e.flat_position().distance_to(Vector2(pos.x, pos.z)) <= radius:
				GameState.server_speed_boost(e.peer_id, SLOW_TIME, SLOW_FACTOR))
