class_name LocalInputSource
extends InputSource
## Đọc bàn phím của người ngồi máy này.

const KEYS := {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"interact": [KEY_E, KEY_SPACE],
	&"dash": [KEY_SHIFT],
	&"skill_1": [KEY_1, KEY_Q], # ô thẻ 1..4
	&"skill_2": [KEY_2, KEY_R],
	&"skill_3": [KEY_3, KEY_F],
	&"skill_4": [KEY_4, KEY_G],
}


func _init() -> void:
	for action: StringName in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func get_move() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func is_pressed(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)
