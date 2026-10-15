extends "res://Items/effects/place_object.gd"
## Hộp gỗ: vật cản chắn đường và chắn đạn trong một lúc. Chạm nhanh thì đặt
## trước mặt (đặt dưới chân thì kẹt chính mình trong hộp).

func _type() -> GameTypes.ItemType:
	return GameTypes.ItemType.CRATE


func _distance() -> float:
	return 1.2
