class_name EntityBase
extends CharacterBody2D
## Hợp đồng cho mọi nhân vật trong trận (người và bot, thợ săn và người trốn).
## Module Player kế thừa và cài đặt chi tiết. Core chỉ gọi các hàm dưới đây.

var peer_id := 0
var role: GameTypes.Role = GameTypes.Role.ESCAPEE
var display_name := ""
var is_local := false ## nhân vật của người đang ngồi máy này
var state: GameTypes.PlayerState = GameTypes.PlayerState.IDLE


## Lớp con override thì phải gọi super(...).
func setup(id: int, p_role: GameTypes.Role, p_name: String, pos: Vector2, local: bool) -> void:
	peer_id = id
	role = p_role
	display_name = p_name
	is_local = local
	position = pos
	name = "Entity_%d" % id
	add_to_group(GameTypes.GROUP_ENTITIES)
	EventBus.player_state_changed.connect(_on_any_state_changed)


## Chỉ chạy trên server, mỗi physics frame khi trận đang chơi.
func server_move(_input: InputSource, _delta: float) -> void:
	pass


## Server gói trạng thái hiển thị gửi xuống client (vị trí, hướng, anim...).
func get_snapshot() -> Variant:
	return position


## Client nhận gói từ get_snapshot().
func apply_snapshot(_data: Variant) -> void:
	pass


## Chỉ chạy trên client, mỗi physics frame (nội suy, anim).
func client_update(_delta: float) -> void:
	pass


## Gọi trên mọi máy khi GameState đổi trạng thái nhân vật này.
func _on_state_changed(_new_state: GameTypes.PlayerState) -> void:
	pass


func is_hunter() -> bool:
	return role == GameTypes.Role.HUNTER


func is_out() -> bool:
	return GameTypes.is_out(state)


func _on_any_state_changed(id: int, _old: GameTypes.PlayerState, new_state: GameTypes.PlayerState) -> void:
	if id == peer_id:
		state = new_state
		_on_state_changed(new_state)
