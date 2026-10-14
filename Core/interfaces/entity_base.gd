class_name EntityBase
extends CharacterBody3D
## Hợp đồng cho mọi nhân vật trong trận (người và bot, thợ săn và người trốn).
## Module Player kế thừa và cài đặt chi tiết. Core chỉ gọi các hàm dưới đây.

var peer_id := 0
var role: GameTypes.Role = GameTypes.Role.ESCAPEE
var display_name := ""
var is_local := false ## nhân vật của người đang ngồi máy này
var state: GameTypes.PlayerState = GameTypes.PlayerState.IDLE

var _held_buttons := 0 # chỉ server: nút đang giữ (bit theo InputSource.ACTIONS)
var _pressed_buttons := 0 # chỉ server: nút vừa bấm xuống trong frame này


## Lớp con override thì phải gọi super(...).
func setup(id: int, p_role: GameTypes.Role, p_name: String, pos: Vector3, local: bool) -> void:
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


## Chỉ server: bị hất tung (đệm lò xo...). `velocity` tính bằng m/s. Lớp con
## cài đặt việc bay (bay qua tường, rơi xuống).
func server_launch(_velocity: Vector3) -> void:
	pass


## Hướng nhân vật đang nhìn trên mặt sàn (đã chuẩn hóa).
func facing() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


## Core gọi trên server mỗi physics frame, trước server_move().
func server_read_input(input: InputSource) -> void:
	var b := input.get_buttons()
	_pressed_buttons = b & ~_held_buttons
	_held_buttons = b


## Chỉ server: nút `action` đang được giữ. Dùng cho vật thể (két, cổng...) cần biết người chơi bấm gì.
func is_holding(action: StringName) -> bool:
	return _held_buttons & _action_bit(action) != 0


## Chỉ server: nút `action` vừa được bấm xuống trong frame này (không tính giữ).
func just_pressed(action: StringName) -> bool:
	return _pressed_buttons & _action_bit(action) != 0


func _action_bit(action: StringName) -> int:
	var i := InputSource.ACTIONS.find(action)
	return 1 << i if i >= 0 else 0


## Server gói trạng thái hiển thị gửi xuống client (vị trí, hướng, anim...).
## Giữ gói nhỏ: gửi 20 lần/giây cho mỗi nhân vật.
func get_snapshot() -> Variant:
	return position


## Client nhận gói từ get_snapshot().
func apply_snapshot(_data: Variant) -> void:
	pass


## Chỉ chạy trên client, mỗi physics frame (nội suy, anim).
func client_update(_delta: float) -> void:
	pass


## Mọi máy: máy này không được thấy nhân vật này (đứng trong bụi cây phe kia).
## Lớp con ẩn hình; Match gọi khi gói vị trí của nhân vật này không được gửi tới.
func set_concealed(_concealed: bool) -> void:
	pass


## Gọi trên mọi máy khi GameState đổi trạng thái nhân vật này.
func _on_state_changed(_new_state: GameTypes.PlayerState) -> void:
	pass


func is_hunter() -> bool:
	return role == GameTypes.Role.HUNTER


func is_out() -> bool:
	return GameTypes.is_out(state)


## Vị trí trên mặt phẳng sàn (x, z), dùng cho khoảng cách, bot, minimap.
func flat_position() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func _on_any_state_changed(id: int, _old: GameTypes.PlayerState, new_state: GameTypes.PlayerState) -> void:
	if id == peer_id:
		state = new_state
		_on_state_changed(new_state)
