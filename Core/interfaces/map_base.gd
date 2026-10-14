class_name MapBase
extends Node3D
## Hợp đồng cho bản đồ. Bản đồ tự tạo tường, két (Interactable có
## interactable_id = 0, 1, 2...), cổng, nhà tù, tiền trên sàn (id = chỉ số trong
## get_coin_spots()) và gắn group trong GameTypes. Bản đồ tự vào group
## GameTypes.GROUP_MAP để minimap và GameState tìm.


func _init() -> void:
	add_to_group(GameTypes.GROUP_MAP)


## Khung bản đồ trên mặt sàn: Rect2(x, z, rộng, sâu). Dịch chuyển bị kẹp trong khung này.
func get_bounds() -> Rect2:
	return Rect2()


## Tường để vẽ minimap: Rect2(x, z, rộng, sâu). Không dùng cho va chạm.
func get_walls() -> Array[Rect2]:
	return []


func get_hunter_spawn() -> Vector3:
	return Vector3.ZERO


func get_escapee_spawns() -> Array[Vector3]:
	return [Vector3.ZERO]


func get_safe_count() -> int:
	return 0


## Vị trí các cọc tiền rải sẵn trên sàn lúc đầu trận. Thứ tự là id của cọc.
func get_coin_spots() -> Array[Vector3]:
	return []
