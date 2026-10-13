class_name MapBase
extends Node3D
## Hợp đồng cho bản đồ. Bản đồ tự tạo tường, két (Interactable có
## interactable_id = 0, 1, 2...), cổng, nhà tù và gắn group trong GameTypes.


func get_hunter_spawn() -> Vector3:
	return Vector3.ZERO


func get_escapee_spawns() -> Array[Vector3]:
	return [Vector3.ZERO]


func get_safe_count() -> int:
	return 0
