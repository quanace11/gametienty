extends ItemEffect
## Đặt một vật thể xuống đất trước mặt (lớp cha của bẫy, đệm lò xo, hộp gỗ).
## Lớp con chỉ đổi TYPE / DISTANCE / LIFETIME.

func _type() -> GameTypes.ItemType:
	return GameTypes.ItemType.CRATE


func _distance() -> float:
	return 1.2


func _lifetime() -> float:
	return 15.0


func plan(user: EntityBase) -> Dictionary:
	var pos := user.global_position + user.facing() * _distance()
	pos.y = 0.0
	return {"target_pos": pos}


func server_apply(user: EntityBase, p: Dictionary) -> void:
	var f := user.facing()
	GameState.server_place(_type(), p["target_pos"], atan2(-f.x, -f.z), user.peer_id, _lifetime())
