extends ItemEffect
## Túi cứu thương: kéo thẻ để chọn chỗ ném (tối đa ItemData.aim_range), chạm
## nhanh thì thả ngay dưới chân. Túi bay FLIGHT_TIME giây, rơi xuống thì cứu
## mọi người trốn (cả người ném) đứng trong vùng tròn bán kính ItemData.area_radius.
## Người được nhắm (ưu tiên bị kéo, rồi bị nhốt, rồi gục, rồi mất máu, gần tâm
## nhất) được cứu dù đã bị kéo đi một đoạn trong lúc túi bay.
## Ném vào chỗ không ai cần cứu thì vẫn mất tiền (như ném trượt kỹ năng).

const AimPoint = preload("res://Items/effects/aim_point.gd")
const FLIGHT_TIME := 0.3
const PRIORITY := {
	GameTypes.PlayerState.CARRIED: 0, GameTypes.PlayerState.IMPRISONED: 1, GameTypes.PlayerState.DOWNED: 2,
}


func plan(user: EntityBase) -> Dictionary:
	var rules := GameState.rules
	var center := AimPoint.of(user, GameTypes.ItemType.MEDKIT)
	var c := Vector2(center.x, center.z)
	var area := _area()
	var best := 0
	var best_key := INF
	for node in user.get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		var d := e.flat_position().distance_to(c)
		if d > area or not rules.can_heal(user.peer_id, e.peer_id):
			continue
		var key: float = PRIORITY.get(e.state, 3) * 1000.0 + d
		if key < best_key:
			best_key = key
			best = e.peer_id
	return {"target_id": best, "target_pos": center}


func server_apply(user: EntityBase, p: Dictionary) -> void:
	var healer := user.peer_id
	var target: int = p["target_id"]
	var center: Vector3 = p["target_pos"]
	var tree := user.get_tree()
	if not AimPoint.is_tossed(user):
		_land(tree, healer, target, center)
		return
	tree.create_timer(FLIGHT_TIME, false, true).timeout.connect(func() -> void: _land(tree, healer, target, center))


## Túi rơi: cứu người được nhắm (dù đã bị kéo đi một đoạn), rồi cả vùng.
func _land(tree: SceneTree, healer: int, target: int, center: Vector3) -> void:
	if target != 0:
		GameState.server_heal(healer, target)
	var c := Vector2(center.x, center.z)
	var area := _area()
	for node in tree.get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e.peer_id != target and e.flat_position().distance_to(c) <= area and GameState.rules.can_heal(healer, e.peer_id):
			GameState.server_heal(healer, e.peer_id)


func _area() -> float:
	return float(GameState.rules.catalog.get(GameTypes.ItemType.MEDKIT, {}).get("area", 2.0))
