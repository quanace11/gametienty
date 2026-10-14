class_name BotInputSource
extends InputSource
## Bot đơn giản, thay chỗ bàn phím. Làm việc trên mặt phẳng sàn (x, z):
## get_move().x = trục x, get_move().y = trục z của thế giới.
## Chưa có NavMesh: đi thẳng tới mục tiêu, kẹt tường thì rẽ ngẫu nhiên một lúc.
## Bot chỉ chọn hướng đi và nút bấm; đúng/sai do GameState quyết như người thật.
##
## Thợ săn: vác người thì mang về nhà tù gần nhất; thấy người ngã thì tới nhấc;
## còn lại đuổi người gần nhất và đánh khi đủ gần.
## Người trốn: bị vác thì vùng vẫy; cổng mở thì chạy ra cổng; đồng đội ngã
## hoặc bị nhốt mà thợ săn ở xa thì đi cứu; còn lại đi mở két. Thợ săn lại
## gần thì né.

const FLEE_DIST := 3.6 # mét
const SAFE_TO_RESCUE_DIST := 6.0 # thợ săn xa hơn chừng này mới đi cứu
const ARRIVE_DIST := 1.2
const ACT_DIST := 1.3 # đủ gần để đánh / nhấc / đỡ
const STUCK_CHECK := 0.5
const DETOUR_TIME := 0.8

var _move := Vector2.ZERO
var _interact := false
var _last_pos := Vector2.ZERO
var _check_timer := 0.0
var _detour_time := 0.0
var _detour_dir := Vector2.ZERO


func get_move() -> Vector2:
	return _move


func is_pressed(action: StringName) -> bool:
	return action == &"interact" and _interact


func update(delta: float) -> void:
	_move = Vector2.ZERO
	_interact = false
	var rules := GameState.rules
	if entity == null or rules == null or not rules.is_playing() or rules.record(entity.peer_id) == null:
		return
	var me := entity.flat_position()
	var rec := rules.record(entity.peer_id)

	match entity.state:
		GameTypes.PlayerState.CARRIED:
			_interact = Engine.get_physics_frames() % 8 == 0 # bấm ~7 lần/giây như người thật
			return
		GameTypes.PlayerState.IMPRISONED, GameTypes.PlayerState.ESCAPED, GameTypes.PlayerState.ELIMINATED:
			return

	var target := me
	var act := false # tới nơi thì bấm nút
	if entity.is_hunter():
		if rec.carrying_id != 0:
			target = _nearest(_positions(GameTypes.GROUP_PRISONS), me)
		else:
			var downed := _escapees_in(GameTypes.PlayerState.DOWNED)
			var victims := downed if not downed.is_empty() else _escapees_where(func(e: EntityBase) -> bool:
				return GameTypes.is_active(e.state))
			target = _nearest(victims.map(func(e: EntityBase) -> Vector2: return e.flat_position()), me)
			act = not victims.is_empty()
	else:
		var hunter_dist := _hunter_distance(me)
		var downed := _escapees_in(GameTypes.PlayerState.DOWNED).filter(func(e: EntityBase) -> bool: return e != entity)
		var has_inmates := rules.count_escapees(GameTypes.PlayerState.IMPRISONED) > 0
		if entity.state == GameTypes.PlayerState.DOWNED:
			target = me # đang ngã thì chỉ bò né thợ săn
		elif rules.gate_open:
			target = _nearest(_positions(GameTypes.GROUP_EXIT_GATES), me)
		elif not downed.is_empty() and hunter_dist > SAFE_TO_RESCUE_DIST:
			target = _nearest(downed.map(func(e: EntityBase) -> Vector2: return e.flat_position()), me)
			act = true
		elif has_inmates and hunter_dist > SAFE_TO_RESCUE_DIST:
			target = _nearest(_occupied_prisons(), me)
		else:
			var safes := entity.get_tree().get_nodes_in_group(GameTypes.GROUP_SAFES).filter(
				func(s: Interactable) -> bool: return rules.safe_progress.get(s.interactable_id, 1.0) < 1.0)
			target = _nearest(safes.map(func(s: Node3D) -> Vector2: return _flat(s.global_position)), me)

	var to_target := target - me
	var dir := to_target.normalized() if to_target.length() > ARRIVE_DIST else Vector2.ZERO
	if act and to_target.length() <= ACT_DIST:
		_interact = true
		dir = to_target.normalized() * 0.2 # quay mặt về mục tiêu để đòn trúng
	if not entity.is_hunter() and _hunter_distance(me) < FLEE_DIST and not _interact:
		var away := (me - _nearest_hunter_pos(me)).normalized()
		dir = (dir + away * 1.5).normalized()

	_check_timer += delta
	if _check_timer >= STUCK_CHECK:
		if dir.length() > 0.5 and _detour_time <= 0.0 and me.distance_to(_last_pos) < 0.3:
			_detour_time = DETOUR_TIME
			_detour_dir = dir.rotated(randf_range(PI / 2.0, PI * 1.5))
		_last_pos = me
		_check_timer = 0.0
	if _detour_time > 0.0 and not _interact:
		_detour_time -= delta
		dir = _detour_dir
	_move = dir


func _entities() -> Array:
	return entity.get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES)


func _escapees_where(filter: Callable) -> Array:
	return _entities().filter(func(e: EntityBase) -> bool: return not e.is_hunter() and filter.call(e))


func _escapees_in(s: GameTypes.PlayerState) -> Array:
	return _escapees_where(func(e: EntityBase) -> bool: return e.state == s)


func _nearest_hunter_pos(me: Vector2) -> Vector2:
	var hunters := _entities().filter(func(e: EntityBase) -> bool: return e.is_hunter())
	return _nearest(hunters.map(func(e: EntityBase) -> Vector2: return e.flat_position()), me + Vector2(1000, 0))


func _hunter_distance(me: Vector2) -> float:
	return me.distance_to(_nearest_hunter_pos(me))


func _occupied_prisons() -> Array:
	var rules := GameState.rules
	var ids := {}
	for p: PlayerRecord in rules.players.values():
		if p.state == GameTypes.PlayerState.IMPRISONED:
			ids[p.prison_id] = true
	return entity.get_tree().get_nodes_in_group(GameTypes.GROUP_PRISONS).filter(
		func(n: Interactable) -> bool: return ids.has(n.interactable_id)).map(
		func(n: Node3D) -> Vector2: return _flat(n.global_position))


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
