class_name Interactable
extends Area3D
## Vật thể tương tác (két, cổng, nhà tù...). Luật chạy trên server: mỗi physics
## frame khi trận đang chơi, interact_tick() nhận các nhân vật đang đứng trong
## vùng và thỏa can_interact(). Lớp con override _ready() thì phải gọi super().
## Lớp con không override _physics_process().

var interactable_id := 0

static var _no_users: Array[EntityBase] = [] # dùng chung khi vùng trống (đa số frame), khỏi tạo mảng mới; lớp con không được sửa


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # layer của nhân vật
	monitorable = false
	set_physics_process(multiplayer.is_server()) # luật chỉ chạy trên server


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or GameState.rules == null or not GameState.rules.is_playing():
		return
	if not has_overlapping_bodies():
		interact_tick(_no_users, delta)
		return
	var users: Array[EntityBase] = []
	for body in get_overlapping_bodies():
		if body is EntityBase and not body.is_out() and can_interact(body):
			users.append(body)
	interact_tick(users, delta)


func can_interact(_entity: EntityBase) -> bool:
	return true


## Server: gọi mỗi physics frame, kể cả khi users rỗng.
func interact_tick(_users: Array[EntityBase], _delta: float) -> void:
	pass
