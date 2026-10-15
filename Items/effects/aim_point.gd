extends RefCounted
## Chỗ rơi của thẻ kéo-thả (túi cứu, lựu đạn, đệm lò xo, bẫy, hộp gỗ): người
## chơi kéo thẻ ra xa bao nhiêu thì ném xa bấy nhiêu, tối đa ItemData.aim_range;
## chạm nhanh (không kéo) thì ngay dưới chân. Kẹp trong bản đồ. Chỉ server.


static func of(user: EntityBase, type: GameTypes.ItemType) -> Vector3:
	var info: Dictionary = GameState.rules.catalog.get(type, {})
	var a := user.aim_offset() * float(info.get("aim_range", 0.0))
	var p := Vector3(user.global_position.x + a.x, 0.0, user.global_position.z + a.y)
	var map := user.get_tree().get_first_node_in_group(GameTypes.GROUP_MAP) as MapBase
	if map:
		var b := map.get_bounds()
		p.x = clampf(p.x, b.position.x, b.end.x)
		p.z = clampf(p.z, b.position.y, b.end.y)
	return p


## Có kéo thẻ (ném ra xa) hay chạm nhanh (dưới chân).
static func is_tossed(user: EntityBase) -> bool:
	return user.aim_offset().length() > 0.05
