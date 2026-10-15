extends "res://Items/effects/place_object.gd"
## Đệm lò xo: người trốn bước lên là bật vút qua tường cao, theo hướng ném.
## Chạm nhanh thì đặt ngay dưới chân (bật luôn, thoát khỏi chỗ kẹt).

func _type() -> GameTypes.ItemType:
	return GameTypes.ItemType.JUMP_PAD


func _lifetime() -> float:
	return 25.0
