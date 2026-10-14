extends "res://Items/effects/place_object.gd"
## Bẫy kẹp: đặt dưới chân, thợ săn dẫm vào thì bị kẹp (chạy chậm). Thợ săn thấy mờ.

func _type() -> GameTypes.ItemType:
	return GameTypes.ItemType.TRAP


func _distance() -> float:
	return 0.0


func _lifetime() -> float:
	return 45.0
