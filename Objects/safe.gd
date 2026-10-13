class_name Safe
extends Interactable
## Két sắt: người trốn đứng trong vùng để mở. Càng đông mở càng nhanh.
## Chưa có QTE (việc tiếp theo của module Objects).

const UNLOCK_TIME := 4.0 # giây, một người
const SPEED_BY_COUNT := [0.0, 1.0, 1.5, 2.0] # 0, 1, 2, 3+ người
const SIZE := Vector2(56, 56)

var _progress := 0.0 # chỉ server dùng


func _ready() -> void:
	super()
	add_to_group(GameTypes.GROUP_SAFES)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	EventBus.safe_progress_changed.connect(func(id: int, _p: float) -> void:
		if id == interactable_id:
			queue_redraw())


func can_interact(entity: EntityBase) -> bool:
	return not entity.is_hunter()


func interact_tick(users: Array[EntityBase], delta: float) -> void:
	if users.is_empty() or _progress >= 1.0:
		return
	var speed: float = SPEED_BY_COUNT[mini(users.size(), SPEED_BY_COUNT.size() - 1)]
	_progress = minf(1.0, _progress + delta / UNLOCK_TIME * speed)
	GameState.server_set_safe_progress(interactable_id, _progress)


func _draw() -> void:
	var p := 0.0
	if GameState.rules:
		p = GameState.rules.safe_progress.get(interactable_id, 0.0)
	var r := Rect2(-SIZE / 2, SIZE)
	draw_rect(r, Color(0.2, 0.75, 0.35) if p >= 1.0 else Color(0.85, 0.7, 0.2))
	draw_rect(r, Color(0, 0, 0, 0.5), false, 2)
	if p > 0.0 and p < 1.0:
		draw_rect(Rect2(r.position + Vector2(0, -12), Vector2(SIZE.x * p, 6)), Color.WHITE)
