class_name LocalInputSource
extends InputSource
## Đọc bàn phím, chuột và nút cảm ứng (UI bấm qua InputMap) của người ngồi máy này.
## Ngắm bắn: kéo cần ngắm (aim_*) hoặc giữ chuột phải, thả ra là bắn theo hướng
## đó. Kéo về giữa cần hoặc thả tay trên nút hủy (aim_cancel) thì không bắn. Lướt
## ngang qua nút hủy rồi kéo ra thì vẫn ngắm tiếp (không khóa hủy cả lần kéo).

const KEYS := {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"interact": [KEY_E, KEY_SPACE],
	&"dash": [KEY_SHIFT],
	&"skill_1": [KEY_1, KEY_Q], # ô thẻ 1..5
	&"skill_2": [KEY_2, KEY_R],
	&"skill_3": [KEY_3, KEY_F],
	&"skill_4": [KEY_4, KEY_G],
	&"skill_5": [KEY_5, KEY_T],
	# Cần ngắm cảm ứng (UI bấm với độ mạnh 0..1), không có phím.
	&"aim_left": [],
	&"aim_right": [],
	&"aim_up": [],
	&"aim_down": [],
	&"aim_hold": [], # ngón tay đang đặt trên cần ngắm
	&"aim_cancel": [],
}
const AIM_DEAD := 0.3 ## cần ngắm kéo ít hơn chừng này thì coi như không ngắm (thả ra là hủy)
const SHOOT_HOLD := 0.15 ## giây giữ nút "shoot" sau khi thả cần, để server chắc chắn nhận được

var _aim := Vector2.ZERO
var _aiming := false
var _shoot_left := 0.0
var _shot_aim := Vector2.ZERO


func _init() -> void:
	for action: StringName in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.05 if String(action).begins_with("aim") else 0.2)
		for key: Key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func attach(e: EntityBase) -> void:
	super(e)
	if e is PlayerCharacter:
		(e as PlayerCharacter).aim_input = self # để nhân vật vẽ luồng ngắm trên máy này


func update(delta: float) -> void:
	_shoot_left = maxf(0.0, _shoot_left - delta)
	var held := Input.is_action_pressed(&"aim_hold") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if held:
		_aim = Vector2.ZERO if Input.is_action_pressed(&"aim_cancel") else _read_aim()
		_aiming = true
		return
	# Thả tay: còn kéo xa thì bắn; đã kéo về giữa hoặc bấm hủy thì thôi.
	if _aiming and _aim.length() >= AIM_DEAD:
		_shot_aim = _aim.normalized()
		_shoot_left = SHOOT_HOLD
	_aiming = false
	_aim = Vector2.ZERO


## Đang ngắm (để vẽ luồng ngắm): hướng đã chuẩn hóa, Vector2.ZERO nếu không ngắm.
func aiming_direction() -> Vector2:
	return _aim.normalized() if _aiming and _aim.length() >= AIM_DEAD else Vector2.ZERO


func get_move() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func get_aim() -> Vector2:
	if _shoot_left > 0.0:
		return _shot_aim
	return aiming_direction()


func is_pressed(action: StringName) -> bool:
	if action == &"shoot":
		return _shoot_left > 0.0
	return InputMap.has_action(action) and Input.is_action_pressed(action)


## Cần ngắm cảm ứng, không thì chuột phải (hướng từ nhân vật tới con trỏ trên mặt sàn).
func _read_aim() -> Vector2:
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	if stick != Vector2.ZERO:
		return stick
	if entity == null or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or not entity.is_inside_tree():
		return Vector2.ZERO
	var cam := entity.get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.ZERO
	var mouse := entity.get_viewport().get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, entity.global_position.y).intersects_ray(
		cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	if hit == null:
		return Vector2.ZERO
	var d: Vector3 = (hit as Vector3) - entity.global_position
	var flat := Vector2(d.x, d.z)
	return flat.normalized() if flat.length() > 0.3 else Vector2.ZERO
