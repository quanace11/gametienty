class_name MapBase
extends Node3D
## Hợp đồng cho bản đồ. Bản đồ tự tạo tường, két (Interactable có
## interactable_id = 0, 1, 2...), cổng, nhà tù, tiền trên sàn (id = chỉ số trong
## get_coin_spots()) và gắn group trong GameTypes.


func get_hunter_spawn() -> Vector3:
	return Vector3.ZERO


func get_escapee_spawns() -> Array[Vector3]:
	return [Vector3.ZERO]


func get_safe_count() -> int:
	return 0


## Vị trí các cọc tiền rải sẵn trên sàn lúc đầu trận. Thứ tự là id của cọc.
func get_coin_spots() -> Array[Vector3]:
	return []
