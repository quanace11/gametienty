class_name EntityBase
extends CharacterBody3D
## Hợp đồng cho mọi nhân vật trong trận (người và bot, thợ săn và người trốn).
## Module Player kế thừa và cài đặt chi tiết. Core chỉ gọi các hàm dưới đây.

var peer_id := 0
var role: GameTypes.Role = GameTypes.Role.ESCAPEE
var display_name := ""
var is_local := false ## nhân vật của người đang ngồi máy này
var state: GameTypes.PlayerState = GameTypes.PlayerState.IDLE

## Chỉ client: nhân vật người khác được vẽ chậm chừng này sau gói vị trí mới
## nhất, để luôn có hai gói kẹp hai đầu mà nội suy (gói 20 lần/giây, chịu
## được mất một gói hoặc lệch nhịp ~50 ms).
const INTERP_DELAY := 0.1
static var snapshot_time := 0.0 ## chỉ client: giờ server của gói vị trí đang được áp (Match đặt)
static var render_time := 0.0 ## chỉ client: giờ server đang vẽ = giờ server ước lượng - INTERP_DELAY

var _held_buttons := 0 # chỉ server: nút đang giữ (bit theo InputSource.ACTIONS)
var _pressed_buttons := 0 # chỉ server: nút vừa bấm xuống trong frame này
var _aim := Vector2.ZERO # chỉ server: hướng ngắm trên mặt sàn (x, z thế giới), dài 0..1
var _press_times := PackedFloat32Array() # chỉ server: giờ bấm (đồng hồ trận máy người chơi) của nút vừa bấm, -1 = không rõ


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
	# Cú bấm = nút vừa xuống giữa hai frame, cộng cú bấm client báo riêng (chạm
	# quá ngắn hay gói input bị mất thì cạnh lên không tới server).
	var presses := input.take_presses()
	_pressed_buttons = (b & ~_held_buttons) | presses
	_held_buttons = b
	if _pressed_buttons != 0:
		if _press_times.is_empty():
			_press_times.resize(InputSource.ACTIONS.size())
		for i in InputSource.ACTIONS.size():
			if _pressed_buttons & (1 << i):
				_press_times[i] = input.press_time(i) if presses & (1 << i) else -1.0
	var aim := input.get_aim()
	_aim = aim.limit_length(1.0).rotated(-input.get_aim_yaw()) if aim.is_finite() else Vector2.ZERO


## Chỉ server: hướng ngắm lúc này trên mặt sàn (x, z thế giới), dài 0..1. Thẻ
## kéo-thả (ItemData.aim_range > 0) đọc khi dùng: chỗ rơi = vị trí + aim * tầm;
## Vector2.ZERO = chạm nhanh, dùng ngay dưới chân.
func aim_offset() -> Vector2:
	return _aim


## Chỉ server: nút `action` đang được giữ. Dùng cho vật thể (két, cổng...) cần biết người chơi bấm gì.
func is_holding(action: StringName) -> bool:
	return _held_buttons & _action_bit(action) != 0


## Chỉ server: nút `action` vừa được bấm xuống trong frame này (không tính giữ).
func just_pressed(action: StringName) -> bool:
	return _pressed_buttons & _action_bit(action) != 0


## Chỉ server: giờ bấm `action` (đồng hồ trận trên máy người chơi) nếu nút vừa
## được bấm trong frame này và client có báo giờ; -1 nếu không. Luật chỉ tin
## trong một khoảng hẹp (GameState.server_resolve_qte).
func press_time(action: StringName) -> float:
	var i := InputSource.ACTIONS.find(action)
	if i < 0 or _pressed_buttons & (1 << i) == 0 or _press_times.is_empty():
		return -1.0
	return _press_times[i]


func _action_bit(action: StringName) -> int:
	var i := InputSource.ACTIONS.find(action)
	return 1 << i if i >= 0 else 0


## Server gói trạng thái hiển thị gửi xuống client: [vị trí Vector3, góc quay
## quanh Y]. Match nén thành 9 byte (cm, int16), gửi 20 lần/giây.
func get_snapshot() -> Variant:
	return [position, rotation.y]


## Client nhận gói từ get_snapshot(); giờ server của gói ở EntityBase.snapshot_time.
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
