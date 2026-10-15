extends ItemEffect
## Túi cứu thương: kéo thẻ để chọn chỗ ném (tối đa ItemData.aim_range), chạm
## nhanh thì thả ngay dưới chân. Túi bay chậm (THROW_SPEED m/s, xa thì bay lâu
## hơn), rơi xuống thì cứu mọi người trốn (cả người ném) đứng trong vùng tròn
## bán kính ItemData.area_radius. Người được nhắm (ưu tiên bị kéo, rồi bị nhốt,
## rồi gục, rồi mất máu, gần tâm nhất) còn ở gần chỗ rơi cũng được cứu.
## Lúc rơi không ai cần cứu thì túi nằm chờ PICKUP_TIME giây (Items/placed/
## medkit_node.gd): vừa chạy vừa ném sau lưng rồi quay lại đón, hoặc ném trước
## cho đồng đội chạy tới. Hết giờ không ai đón thì mất (vẫn mất tiền).

const AimPoint = preload("res://Items/effects/aim_point.gd")
const THROW_SPEED := 6.0 # m/s trên mặt sàn
const MIN_FLIGHT := 0.4 # giây, ném ngắn / dưới chân vẫn thấy túi tung lên
const PICKUP_TIME := 8.0
const TARGET_GRACE := 0.6 # mét, người được nhắm lệch khỏi vùng chừng này vẫn được cứu
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
	var dist := user.flat_position().distance_to(Vector2(center.x, center.z))
	tree.create_timer(flight_time(dist), false, true).timeout.connect(func() -> void: _land(tree, healer, target, center))


## Giây túi bay khi ném xa `dist` mét (hình bay ở mọi máy dùng cùng công thức).
static func flight_time(dist: float) -> float:
	return maxf(MIN_FLIGHT, dist / THROW_SPEED)


## Túi rơi: cứu người được nhắm nếu còn ở gần, rồi cả vùng; không ai thì túi nằm chờ.
func _land(tree: SceneTree, healer: int, target: int, center: Vector3) -> void:
	var rules := GameState.rules
	if rules == null or not rules.is_playing():
		return
	var c := Vector2(center.x, center.z)
	var area := _area()
	var healed := false
	for node in tree.get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		var reach := area + (TARGET_GRACE if e.peer_id == target else 0.0)
		if e.flat_position().distance_to(c) > reach:
			continue
		if rules.can_heal(healer, e.peer_id):
			healed = GameState.server_heal(healer, e.peer_id) or healed
	if not healed: # nằm chờ ở chỗ đứng tới được gần nhất (rơi vào tường thì lăn ra)
		var spot: Variant = GameState.find_standing_spot(center)
		var at: Vector3 = spot if spot != null else center
		at.y = 0.0
		GameState.server_place(GameTypes.ItemType.MEDKIT, at, 0.0, healer, PICKUP_TIME)


func _area() -> float:
	return float(GameState.rules.catalog.get(GameTypes.ItemType.MEDKIT, {}).get("area", 2.0))
