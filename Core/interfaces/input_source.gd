class_name InputSource
extends RefCounted
## Nguồn điều khiển của một nhân vật: bàn phím, mạng hoặc bot.
## Nhân vật chỉ đọc InputSource, không biết ai đang điều khiển mình.

## Các nút hành động, theo thứ tự bit khi gửi qua mạng.
## "shoot": thợ săn bắn theo hướng get_aim() (cần ngắm thả tay, hoặc chuột phải);
## get_aim() = 0 thì tự nhắm như nút tương tác.
const ACTIONS := [&"interact", &"dash", &"skill_1", &"skill_2", &"skill_3", &"skill_4", &"skill_5", &"shoot"]
const SKILL_ACTIONS := [&"skill_1", &"skill_2", &"skill_3", &"skill_4", &"skill_5"] ## nút ô thẻ 1..5 trong bộ bài

## Nhân vật đang được điều khiển (Match gán khi tạo).
var entity: EntityBase


func attach(e: EntityBase) -> void:
	entity = e


## Gọi mỗi physics frame trước khi đọc. Bot tính quyết định ở đây.
func update(_delta: float) -> void:
	pass


## Hướng di chuyển trên cần analog / WASD, độ dài tối đa 1.
## x: trái/phải, y: lên/xuống màn hình (y âm = đi tới). Nhân vật tự xoay
## theo get_aim_yaw() để ra hướng trong thế giới 3D.
func get_move() -> Vector2:
	return Vector2.ZERO


## Góc xoay camera quanh trục Y (radian). Camera cố định thì luôn 0.
## Có sẵn trong gói input gửi lên server để sau này xoay camera không phải sửa mạng.
func get_aim_yaw() -> float:
	return 0.0


## Hướng ngắm (cần ngắm bên phải / chuột phải), cùng hệ trục với get_move(),
## độ dài tối đa 1. Vector2.ZERO = không ngắm tay (súng tự nhắm).
func get_aim() -> Vector2:
	return Vector2.ZERO


## Chỉ server: bit các nút client báo đã bấm (kể cả cú chạm quá ngắn mà
## get_buttons() không kịp thấy), mỗi nút tối đa một lần mỗi frame. Gọi xong là
## lấy đi. Bàn phím và bot không cần: cạnh lên của get_buttons() là đủ.
func take_presses() -> int:
	return 0


## Giờ bấm (đồng hồ trận máy người chơi) của nút thứ `i` trong lần take_presses() vừa rồi; -1 nếu không có.
func press_time(_i: int) -> float:
	return -1.0


func is_pressed(_action: StringName) -> bool:
	return false


func get_buttons() -> int:
	var bits := 0
	for i in ACTIONS.size():
		if is_pressed(ACTIONS[i]):
			bits |= 1 << i
	return bits
