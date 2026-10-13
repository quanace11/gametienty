class_name NetworkInputSource
extends InputSource
## Input mới nhất mà một client gửi lên server.

var move := Vector2.ZERO
var buttons := 0
var aim_yaw := 0.0


func get_move() -> Vector2:
	return move


func get_aim_yaw() -> float:
	return aim_yaw


func is_pressed(action: StringName) -> bool:
	var i := ACTIONS.find(action)
	return i >= 0 and (buttons & (1 << i)) != 0
