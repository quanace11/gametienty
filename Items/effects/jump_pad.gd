extends "res://Items/effects/place_object.gd"
## Đệm lò xo: đặt trước mặt, người trốn bước lên là bật vút qua tường cao.

func _type() -> GameTypes.ItemType:
	return GameTypes.ItemType.JUMP_PAD


func _distance() -> float:
	return 1.0


func _lifetime() -> float:
	return 25.0
