class_name MapBase
extends Node2D
## Hợp đồng cho bản đồ. Bản đồ tự tạo tường, két (Interactable có
## interactable_id = 0, 1, 2...), cổng, nhà tù và gắn group trong GameTypes.


func get_hunter_spawn() -> Vector2:
	return Vector2.ZERO


func get_escapee_spawns() -> Array[Vector2]:
	return [Vector2.ZERO]


func get_safe_count() -> int:
	return 0
