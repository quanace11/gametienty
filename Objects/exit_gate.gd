class_name ExitGate
extends Interactable
## Cổng thoát: khóa cho tới khi đủ két. Mở rồi thì người trốn bước vào là thoát.

var size := Vector2(40, 120)


func _ready() -> void:
	super()
	add_to_group(GameTypes.GROUP_EXIT_GATES)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size + Vector2(20, 20)
	shape.shape = rect
	add_child(shape)
	EventBus.gate_opened.connect(queue_redraw)


func can_interact(entity: EntityBase) -> bool:
	return not entity.is_hunter() and GameState.rules.gate_open


func interact_tick(users: Array[EntityBase], _delta: float) -> void:
	for e in users:
		GameState.server_set_player_state(e.peer_id, GameTypes.PlayerState.ESCAPED)


func _draw() -> void:
	var open := GameState.rules != null and GameState.rules.gate_open
	draw_rect(Rect2(-size / 2, size), Color(0.2, 0.85, 0.35) if open else Color(0.45, 0.15, 0.15))
