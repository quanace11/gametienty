extends Camera3D
## Camera nhìn chéo từ trên xuống, bám theo nhân vật của máy này.
## Không xoay theo nhân vật (top_level). Muốn camera xoay thì trả góc qua
## LocalInputSource.get_aim_yaw() để server tính hướng đi cho đúng.

const OFFSET := Vector3(0, 7.5, 6.5) # gần hơn để thấy rõ nhân vật chibi
const FOLLOW_SPEED := 8.0


func _ready() -> void:
	top_level = true
	fov = 55
	global_position = get_parent().global_position + OFFSET
	look_at(get_parent().global_position)
	make_current()


func _process(delta: float) -> void:
	var target: Vector3 = get_parent().global_position + OFFSET
	global_position = global_position.lerp(target, minf(1.0, delta * FOLLOW_SPEED))
