class_name PlayerCharacter
extends EntityBase
## Nhân vật mặc định: di chuyển 8 hướng, thợ săn chạm là bắt.
## Bản nền: chạm là nhốt luôn. Sau này thay bằng đánh -> DOWNED -> vác -> nhà tù.

const HUNTER_SPEED := 240.0
const ESCAPEE_SPEED := 210.0
const HUNTER_RADIUS := 20.0
const ESCAPEE_RADIUS := 16.0 # người trốn chậm hơn nhưng hitbox nhỏ hơn
const CATCH_DIST := 42.0
const LERP_SPEED := 15.0

var _target_pos := Vector2.ZERO


func setup(id: int, p_role: GameTypes.Role, p_name: String, pos: Vector2, local: bool) -> void:
	super(id, p_role, p_name, pos, local)
	_target_pos = pos
	collision_layer = 2 # nhân vật
	collision_mask = 1 # chỉ va vào tường, không chặn nhau
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius()
	shape.shape = circle
	add_child(shape)
	var label := Label.new()
	label.text = p_name
	label.position = Vector2(-50, -_radius() - 26)
	label.size = Vector2(100, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)


func server_move(input: InputSource, _delta: float) -> void:
	if is_out():
		velocity = Vector2.ZERO
		return
	var speed := HUNTER_SPEED if is_hunter() else ESCAPEE_SPEED
	velocity = input.get_move().limit_length(1.0) * speed
	move_and_slide()
	if is_hunter():
		_try_catch()


func _try_catch() -> void:
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		var e := node as EntityBase
		if e == self or e.is_hunter() or e.is_out():
			continue
		if position.distance_to(e.position) < CATCH_DIST:
			GameState.server_set_player_state(e.peer_id, GameTypes.PlayerState.IMPRISONED)


func apply_snapshot(data: Variant) -> void:
	_target_pos = data


func client_update(delta: float) -> void:
	position = position.lerp(_target_pos, minf(1.0, delta * LERP_SPEED))


func _on_state_changed(new_state: GameTypes.PlayerState) -> void:
	visible = new_state != GameTypes.PlayerState.ESCAPED
	queue_redraw()


func _radius() -> float:
	return HUNTER_RADIUS if is_hunter() else ESCAPEE_RADIUS


func _draw() -> void:
	var col := Color(0.9, 0.25, 0.25) if is_hunter() else Color(0.3, 0.6, 1.0)
	if state == GameTypes.PlayerState.IMPRISONED:
		col = Color(0.45, 0.45, 0.45, 0.6)
	draw_circle(Vector2.ZERO, _radius(), col)
	if is_local:
		draw_arc(Vector2.ZERO, _radius() + 4, 0, TAU, 32, Color.WHITE, 2)
