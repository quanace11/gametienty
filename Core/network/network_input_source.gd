class_name NetworkInputSource
extends InputSource
## Input mới nhất mà một client gửi lên server, cộng hàng đợi cú bấm (có số
## thứ tự và giờ bấm) để không mất cú chạm ngắn hay gói bị rớt.

const MAX_QUEUE := 16 ## hàng đợi cú bấm tối đa, quá thì bỏ cú cũ (client gửi rác)

var move := Vector2.ZERO
var buttons := 0
var aim_yaw := 0.0
var aim := Vector2.ZERO
var last_event_seq := -1 ## số thứ tự cú bấm mới nhất đã nhận (gửi lại client làm ack)

var _queue_actions := PackedByteArray()
var _queue_times := PackedFloat32Array()
var _times := PackedFloat32Array() # giờ bấm theo nút của lần take_presses() gần nhất


func get_move() -> Vector2:
	return move


func get_aim_yaw() -> float:
	return aim_yaw


func get_aim() -> Vector2:
	return aim


func is_pressed(action: StringName) -> bool:
	var i := ACTIONS.find(action)
	return i >= 0 and (buttons & (1 << i)) != 0


## Nhận một cú bấm; số đã nhận rồi (gói gửi lặp) thì bỏ qua.
func receive_event(seq: int, action: int, time: float) -> void:
	if seq <= last_event_seq:
		return
	last_event_seq = seq
	if _queue_actions.size() >= MAX_QUEUE:
		_queue_actions.remove_at(0)
		_queue_times.remove_at(0)
	_queue_actions.append(action)
	_queue_times.append(time)


func take_presses() -> int:
	if _queue_actions.is_empty():
		return 0
	if _times.is_empty():
		_times.resize(ACTIONS.size())
	var bits := 0
	var k := 0
	while k < _queue_actions.size():
		var bit := 1 << _queue_actions[k]
		if bits & bit:
			k += 1 # bấm hai lần cùng nút trong một frame: lần sau để frame tới
			continue
		bits |= bit
		_times[_queue_actions[k]] = _queue_times[k]
		_queue_actions.remove_at(k)
		_queue_times.remove_at(k)
	return bits


func press_time(i: int) -> float:
	return _times[i] if i >= 0 and i < _times.size() else -1.0


## Máy vào lại (tiến trình mới, đếm cú bấm lại từ 0): bỏ input và cú bấm cũ.
func reset() -> void:
	move = Vector2.ZERO
	buttons = 0
	aim = Vector2.ZERO
	last_event_seq = -1
	_queue_actions.clear()
	_queue_times.clear()
