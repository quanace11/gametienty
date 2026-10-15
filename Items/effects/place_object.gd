extends ItemEffect
## Đặt một vật thể xuống đất (lớp cha của bẫy, đệm lò xo, hộp gỗ): kéo thẻ để
## chọn chỗ (tối đa ItemData.aim_range), chạm nhanh thì đặt ngay chỗ đứng
## (_distance() mét trước mặt). Vật quay theo hướng ném.
## Lớp con chỉ đổi TYPE / DISTANCE / LIFETIME.

const AimPoint = preload("res://Items/effects/aim_point.gd")


func _type() -> GameTypes.ItemType:
	return GameTypes.ItemType.CRATE


## Chạm nhanh: đặt cách chân chừng này mét về phía trước.
func _distance() -> float:
	return 0.0


func _lifetime() -> float:
	return 15.0


func plan(user: EntityBase) -> Dictionary:
	if AimPoint.is_tossed(user):
		return {"target_pos": AimPoint.of(user, _type())}
	var pos := user.global_position + user.facing() * _distance()
	pos.y = 0.0
	return {"target_pos": pos}


func server_apply(user: EntityBase, p: Dictionary) -> void:
	var f := user.facing()
	var a := user.aim_offset()
	if a.length() > 0.05:
		f = Vector3(a.x, 0.0, a.y) # quay theo hướng ném (đệm lò xo hất về phía đó)
	GameState.server_place(_type(), p["target_pos"], atan2(-f.x, -f.z), user.peer_id, _lifetime())
