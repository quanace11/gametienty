class_name NetworkInputSource
extends InputSource
## Input mới nhất mà một client gửi lên server.

var move := Vector2.ZERO
var buttons := 0


func get_move() -> Vector2:
	return move


func is_pressed(action: StringName) -> bool:
	var i := ACTIONS.find(action)
	return i >= 0 and (buttons & (1 << i)) != 0
