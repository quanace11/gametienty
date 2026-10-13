class_name InputSource
extends RefCounted
## Nguồn điều khiển của một nhân vật: bàn phím, mạng hoặc bot.
## Nhân vật chỉ đọc InputSource, không biết ai đang điều khiển mình.

## Các nút hành động, theo thứ tự bit khi gửi qua mạng.
const ACTIONS := [&"interact", &"dash", &"skill_1", &"skill_2"]

## Nhân vật đang được điều khiển (Match gán khi tạo).
var entity: EntityBase


func attach(e: EntityBase) -> void:
	entity = e


## Gọi mỗi physics frame trước khi đọc. Bot tính quyết định ở đây.
func update(_delta: float) -> void:
	pass


## Hướng di chuyển, độ dài tối đa 1.
func get_move() -> Vector2:
	return Vector2.ZERO


func is_pressed(_action: StringName) -> bool:
	return false


func get_buttons() -> int:
	var bits := 0
	for i in ACTIONS.size():
		if is_pressed(ACTIONS[i]):
			bits |= 1 << i
	return bits
