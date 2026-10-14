class_name ItemEffect
extends RefCounted
## Hiệu ứng của một loại thẻ đạo cụ. Module Items cài đặt, Core gọi trên server
## khi người chơi bấm nút thẻ (GameState.server_use_item):
##   1. plan(user): xem lúc này dùng được không, nhắm vào ai / chỗ nào.
##      Trả {} nếu không dùng được (không mất tiền, không tính hồi chiêu).
##   2. Core trừ tiền, tính hồi chiêu, gửi sự kiện item_used xuống mọi máy.
##   3. server_apply(user, plan): làm hiệu ứng bằng lệnh GameState.server_*().
## Hiệu ứng hình ảnh chạy ở mọi máy theo EventBus.item_used / object_placed.
## Một instance dùng chung cho mọi người chơi: không giữ trạng thái riêng ở đây.


## Trả {"target_id": int, "target_pos": Vector3} (thiếu thì Core điền 0 / vị trí người dùng).
func plan(_user: EntityBase) -> Dictionary:
	return {}


func server_apply(_user: EntityBase, _plan: Dictionary) -> void:
	pass
