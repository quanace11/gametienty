extends "res://Items/effects/place_object.gd"
## Bẫy kẹp: thợ săn dẫm vào thì bị kẹp (chạy chậm). Thợ săn thấy mờ.
## Kéo thẻ để đặt xa, chạm nhanh thì đặt dưới chân.

func _type() -> GameTypes.ItemType:
	return GameTypes.ItemType.TRAP


func _lifetime() -> float:
	return 45.0
