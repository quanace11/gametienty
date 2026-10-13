class_name BotInputSource
extends InputSource
## Bot đơn giản, thay chỗ bàn phím. Làm việc trên mặt phẳng sàn (x, z):
## get_move().x = trục x, get_move().y = trục z của thế giới.
## Chưa có NavMesh: đi thẳng tới mục tiêu,
## kẹt tường thì rẽ ngẫu nhiên một lúc.
## Thợ săn: đuổi người trốn gần nhất. Người trốn: tới két chưa mở gần nhất
## đứng mở, cổng mở thì chạy ra cổng, thợ săn lại gần thì né.

const FLEE_DIST := 3.6 # mét
const ARRIVE_DIST := 1.2
const STUCK_CHECK := 0.5
const DETOUR_TIME := 0.8

var _move := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _check_timer := 0.0
var _detour_time := 0.0
var _detour_dir := Vector2.ZERO


func get_move() -> Vector2:
	return _move


func update(delta: float) -> void:
	_move = Vector2.ZERO
	var rules := GameState.rules
	if entity == null or entity.is_out() or rules == null or not rules.is_playing():
		return

	var me := entity.flat_position()
	var target := me
	if entity.is_hunter():
		target = _nearest(_active_escapees().map(func(e: EntityBase) -> Vector2: return e.flat_position()), target)
	elif rules.gate_open:
		target = _nearest(_positions(GameTypes.GROUP_EXIT_GATES), target)
	else:
		var safes := entity.get_tree().get_nodes_in_group(GameTypes.GROUP_SAFES).filter(
			func(s: Interactable) -> bool: return rules.safe_progress.get(s.interactable_id, 1.0) < 1.0)
		target = _nearest(safes.map(func(s: Node3D) -> Vector2: return _flat(s.global_position)), target)

	var to_target := target - me
	var dir := to_target.normalized() if to_target.length() > ARRIVE_DIST else Vector2.ZERO
	if not entity.is_hunter():
		for e: EntityBase in _hunters():
			if me.distance_to(e.flat_position()) < FLEE_DIST:
				dir = (dir + (me - e.flat_position()).normalized() * 1.5).normalized()

	_check_timer += delta
	if _check_timer >= STUCK_CHECK:
		if dir != Vector2.ZERO and _detour_time <= 0.0 and me.distance_to(_last_pos) < 0.3:
			_detour_time = DETOUR_TIME
			_detour_dir = dir.rotated(randf_range(PI / 2.0, PI * 1.5))
		_last_pos = me
		_check_timer = 0.0
	if _detour_time > 0.0:
		_detour_time -= delta
		dir = _detour_dir
	_move = dir


func _entities() -> Array:
	return entity.get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES)


func _active_escapees() -> Array:
	return _entities().filter(func(e: EntityBase) -> bool: return not e.is_hunter() and not e.is_out())


func _hunters() -> Array:
	return _entities().filter(func(e: EntityBase) -> bool: return e.is_hunter())


func _positions(group: StringName) -> Array:
	return entity.get_tree().get_nodes_in_group(group).map(func(n: Node3D) -> Vector2: return _flat(n.global_position))


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _nearest(points: Array, fallback: Vector2) -> Vector2:
	var best := fallback
	var best_d := INF
	for p: Vector2 in points:
		var d := entity.flat_position().distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best
