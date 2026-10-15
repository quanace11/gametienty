extends Camera3D
## Camera nhìn chéo từ trên xuống, bám theo nhân vật của máy này.
## Không xoay theo nhân vật (top_level). Muốn camera xoay thì trả góc qua
## LocalInputSource.get_aim_yaw() để server tính hướng đi cho đúng.
## Bám theo hình đã nội suy của nhân vật (visual_position), không bám vị trí
## vật lý, để khung hình không giật khi FPS lệch nhịp 60 lần tính vật lý / giây.

const OFFSET := Vector3(0, 7.5, 6.5) # gần hơn để thấy rõ nhân vật chibi
const FOLLOW_SPEED := 8.0


func _ready() -> void:
	top_level = true
	fov = 55
	var start := (get_parent() as Node3D).global_position # hình chưa đặt chỗ (node cha _ready sau)
	global_position = start + OFFSET
	look_at(start)
	make_current()


func _process(delta: float) -> void:
	var target: Vector3 = _target() + OFFSET
	global_position = global_position.lerp(target, minf(1.0, delta * FOLLOW_SPEED))


func _target() -> Vector3:
	var p := get_parent()
	return p.visual_position() if p.has_method(&"visual_position") else (p as Node3D).global_position
