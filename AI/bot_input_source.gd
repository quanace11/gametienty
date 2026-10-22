class_name BotInputSource
extends InputSource
## Bot đơn giản, thay chỗ bàn phím. Làm việc trên mặt phẳng sàn (x, z):
## get_move().x = trục x, get_move().y = trục z của thế giới.
## Chưa có NavMesh: đi thẳng tới mục tiêu, kẹt tường thì rẽ ngẫu nhiên một lúc.
## Bot chỉ chọn hướng đi và nút bấm; đúng/sai do GameState quyết như người thật.
##
## Thợ săn: kéo người thì mang về nhà tù gần nhất; thấy người gục thì tới túm;
## còn lại đuổi người gần nhất, vào tầm thì bắn súng (nhân vật tự nhắm chỗ người đó đang đứng);
## người gần nhất còn xa thì dịch chuyển tới (chọn điểm như chạm minimap), bật radar.
## Người trốn: bị kéo thì chịu (bị khóa); cổng mở thì chạy ra cổng; đồng đội
## gục mà thợ săn ở xa thì tới đỡ; còn túi máu và có người bị kéo / bị nhốt
## thì tới gần để ném; tiền gần mà thợ săn xa thì nhặt; còn lại đi cạy rương
## và căn vòng (không phải lúc nào cũng trúng). Thợ săn lại gần thì né. Ai cần
## cứu lọt vào tầm ném thì ném luôn. Thợ săn đang kéo người hoặc đuổi sát
## thì bắn súng lục. Được cứu mà còn kẹt trong tường nhà tù thì bước lên
## đệm lò xo để bật ra.

const FLEE_DIST := 3.6 # mét
const SAFE_TO_RESCUE_DIST := 6.0 # thợ săn xa hơn chừng này mới đi cứu
const ARRIVE_DIST := 1.2
const ACT_DIST := 1.3 # đủ gần để đánh / nhấc / đỡ
const STUCK_CHECK := 0.5
const DETOUR_TIME := 0.8
const THINK_INTERVAL := 0.1 # bot nghĩ 10 lần/giây (đỡ tốn CPU server), giữa hai lần giữ nguyên nút
const COIN_GRAB_DIST := 5.0 # tiền trong bán kính này thì ghé nhặt
const SHOOT_DIST := 8.0 # thợ săn bắn súng khi người trốn gần hơn chừng này
const PRISON_INSIDE := 2.4 # mét từ giữa nhà tù: đang kẹt trong tường (huyết trận cạnh trong 4,2 m)
const TELEPORT_DIST := 14.0 # thợ săn: người trốn gần nhất xa hơn chừng này thì dịch chuyển tới
const TELEPORT_AFTER := 30.0 # giây: đầu trận thợ săn chưa dịch chuyển, để người trốn kịp tản ra
## Tỉ lệ bot căn vòng: trúng vùng đậm / vùng mờ, còn lại trượt.
const QTE_PERFECT_CHANCE := 0.65
const QTE_GOOD_CHANCE := 0.25

var _move := Vector2.ZERO
var _interact := false
var _skill_slot := -1 # ô thẻ bot bấm trong frame này (-1 = không)
var _item_aim := Vector2.ZERO # chỗ ném thẻ (như người kéo thẻ): hướng x, z thế giới, độ xa 0..1
var _last_pos := Vector2.ZERO
var _check_timer := 0.0
var _detour_time := 0.0
var _detour_dir := Vector2.ZERO
var _qte_for := -1.0 # qte_started của vòng căn đang tính
var _qte_offset := 0.0 # bot định bấm lệch vùng sáng chừng này
var _qte_done := false
var _think_left := 0.0
var _qte_pressed := false # vừa bấm trong vòng căn: thả nút ngay khi vòng căn kết thúc


func get_move() -> Vector2:
	return _move


func get_aim() -> Vector2:
	return _item_aim if _skill_slot >= 0 else Vector2.ZERO


func is_pressed(action: StringName) -> bool:
	if action == &"interact":
		return _interact
	return _skill_slot >= 0 and action == InputSource.SKILL_ACTIONS[_skill_slot]


func update(delta: float) -> void:
	_skill_slot = -1 # nút thẻ bấm một lần, chỉ bật đúng frame bot nghĩ
	var rules := GameState.rules
	if entity == null or rules == null or not rules.is_playing() or rules.record(entity.peer_id) == null:
		_move = Vector2.ZERO
		_interact = false
		return
	var rec := rules.record(entity.peer_id)
	if rec.qte_chest >= 0: # vòng căn cần chính xác từng frame
		_move = Vector2.ZERO
		_interact = false
		_play_qte(rules, rec)
		_qte_pressed = _interact
		return
	if _qte_pressed: # không giữ nút căn sang lúc chờ nghĩ (đỡ đồng đội thì vẫn giữ như cũ)
		_qte_pressed = false
		_interact = false
	_think_left -= delta
	if _think_left > 0.0:
		return
	_think_left = THINK_INTERVAL
	_think(rules, rec, THINK_INTERVAL)


func _think(rules: MatchRules, rec: PlayerRecord, delta: float) -> void:
	_move = Vector2.ZERO
	_interact = false
	var me := entity.flat_position()

	match entity.state:
		GameTypes.PlayerState.CARRIED, GameTypes.PlayerState.IMPRISONED, \
				GameTypes.PlayerState.ESCAPED, GameTypes.PlayerState.ELIMINATED:
			return

	# Quét group một lần mỗi lần nghĩ, các hàm bên dưới dùng lại.
	var ents := _entities()
	var prisons := _positions(GameTypes.GROUP_PRISONS)
	var hunter_pos := Vector2.ZERO
	var hunter_dist := INF
	var target := me
	var act := false # tới nơi thì bấm nút
	var arrive := ARRIVE_DIST
	if entity.is_hunter():
		if rec.carrying_id != 0:
			target = _nearest(prisons, me, me)
		else:
			var downed := _reachable_downed(ents, prisons)
			var victims := downed if not downed.is_empty() else _escapees_where(ents, func(e: EntityBase) -> bool:
				return GameTypes.is_active(e.state))
			target = _nearest(_flat_positions(victims), me, me)
			act = not victims.is_empty()
			var runners := _escapees_where(ents, func(e: EntityBase) -> bool: return rules.is_hittable(e.peer_id))
			var prey := _nearest(_flat_positions(runners), me, me + Vector2(1000, 0))
			if rules.can_attack(entity.peer_id) and me.distance_to(prey) <= SHOOT_DIST:
				_interact = true # bắn súng; người gục trong tầm túm thì nhân vật ưu tiên túm
			elif not runners.is_empty() and me.distance_to(prey) > TELEPORT_DIST and rules.elapsed >= TELEPORT_AFTER:
				_use_slot_of(rules, rec, GameTypes.ItemType.TELEPORT, func() -> void:
					_set_aim_point(Vector3(prey.x, 0, prey.y)))
			elif runners.is_empty() or me.distance_to(prey) > SHOOT_DIST * 1.5:
				_use_slot_of(rules, rec, GameTypes.ItemType.RADAR, Callable())
	else:
		hunter_pos = _nearest_hunter_pos(ents, me)
		hunter_dist = me.distance_to(hunter_pos)
		var downed := _reachable_downed(ents, prisons).filter(func(e: EntityBase) -> bool: return e != entity)
		var medkit_slot := rec.deck.find(GameTypes.ItemType.MEDKIT)
		var has_medkit: bool = medkit_slot >= 0 and rec.coins >= rules.catalog[GameTypes.ItemType.MEDKIT]["cost"]
		var captured := _escapees_where(ents, func(e: EntityBase) -> bool:
			return e.state == GameTypes.PlayerState.CARRIED or e.state == GameTypes.PlayerState.IMPRISONED)
		var throw_range := rules.config.medkit_range * 0.9
		if entity.state != GameTypes.PlayerState.DOWNED:
			var needy := captured.duplicate()
			if hunter_dist < SAFE_TO_RESCUE_DIST:
				needy.append_array(downed) # thợ săn ở gần thì ném luôn, không kịp đỡ tay
			var in_range := needy.filter(func(e: EntityBase) -> bool: return me.distance_to(e.flat_position()) <= throw_range)
			var ally: Variant = _nearest(_flat_positions(in_range), me, me) if not in_range.is_empty() else null
			_use_items(rules, rec, me, ally, hunter_pos, hunter_dist)
		if entity.state == GameTypes.PlayerState.DOWNED:
			target = me # đang ngã thì chỉ bò né thợ săn
		elif _inside_prison(me, prisons):
			target = _nearest(_positions(GameTypes.GROUP_JUMP_PADS), me, me)
			arrive = 0.05 # phải giẫm hẳn lên đệm
		elif rules.gate_open or rules.gate_opening_left > 0.0:
			target = _nearest(_positions(GameTypes.GROUP_EXIT_GATES), me, me)
		elif not downed.is_empty() and hunter_dist > SAFE_TO_RESCUE_DIST:
			target = _nearest(_flat_positions(downed), me, me)
			act = true
		elif has_medkit and not captured.is_empty() and hunter_dist > FLEE_DIST:
			target = _nearest(_flat_positions(captured), me, me)
		else:
			var coins := _near_coins(me) if hunter_dist > SAFE_TO_RESCUE_DIST else []
			if not coins.is_empty():
				target = _nearest(coins, me, me)
			else:
				var safes := entity.get_tree().get_nodes_in_group(GameTypes.GROUP_SAFES).filter(
					func(sf: Interactable) -> bool: return rules.safe_progress.get(sf.interactable_id, 1.0) < 1.0)
				target = _nearest(safes.map(func(sf: Node3D) -> Vector2: return _flat(sf.global_position)), me, me)

	var to_target := target - me
	var dir := to_target.normalized() if to_target.length() > arrive else Vector2.ZERO
	if act and to_target.length() <= ACT_DIST:
		_interact = true
		dir = to_target.normalized() * 0.2 # quay mặt về mục tiêu để đòn trúng
	if not entity.is_hunter() and hunter_dist < FLEE_DIST and not _interact:
		var away := (me - hunter_pos).normalized()
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


## Chọn điểm như chạm minimap. Bot chạy trên client (--join --bot) thì gửi lên server.
func _set_aim_point(p: Vector3) -> void:
	if entity.multiplayer.is_server():
		GameState.server_set_aim_point(entity.peer_id, p)
	else:
		GameState.set_aim_point(p)


## Chọn thẻ để bấm: túi máu ném vào người cần cứu trong tầm (`ally`, null nếu
## không có); lựu đạn làm chậm ném vào thợ săn khi nó sát mình; súng khi thợ
## săn đang kéo người (bắn hết máu thì nó buông) hoặc đuổi gần; ván trượt khi
## bị đuổi sát. Thẻ ném được thì kéo tới đúng chỗ như người chơi kéo thẻ.
func _use_items(rules: MatchRules, rec: PlayerRecord, me: Vector2, ally: Variant, hunter_pos: Vector2, hunter_dist: float) -> void:
	var hunter := _hunter_record(rules)
	var wants := []
	var spots := {} # loại thẻ -> chỗ ném
	if ally != null:
		wants.append(GameTypes.ItemType.MEDKIT)
		spots[GameTypes.ItemType.MEDKIT] = ally
	if hunter and hunter_dist < FLEE_DIST * 0.8 and hunter.speed_boost_left <= 0.0:
		wants.append(GameTypes.ItemType.STUN_GRENADE)
		spots[GameTypes.ItemType.STUN_GRENADE] = hunter_pos
	var hunter_up := hunter != null and hunter.hp > 0
	if hunter_up and hunter_dist < rules.config.bullet_range * 0.9 \
			and (hunter.carrying_id != 0 or hunter_dist < FLEE_DIST * 1.5):
		wants.append(GameTypes.ItemType.PISTOL)
	if hunter_dist < FLEE_DIST:
		wants.append(GameTypes.ItemType.SPEED_BOOST)
	if rec.hp < rec.max_hp and hunter_dist > SAFE_TO_RESCUE_DIST:
		wants.append(GameTypes.ItemType.MEDKIT) # tự hồi máu khi an toàn: thả dưới chân
	for type: int in wants:
		var slot := rec.deck.find(type)
		if slot >= 0 and rules.can_use_item(entity.peer_id, slot):
			_skill_slot = slot
			_item_aim = Vector2.ZERO
			var range_m := float(rules.catalog[type].get("aim_range", 0.0))
			if spots.has(type) and range_m > 0.0:
				_item_aim = ((spots[type] as Vector2) - me).limit_length(range_m) / range_m
			return


## Bấm ô có thẻ `type` nếu dùng được; `before` chạy ngay trước khi bấm (chọn điểm...).
func _use_slot_of(rules: MatchRules, rec: PlayerRecord, type: GameTypes.ItemType, before: Callable) -> void:
	var slot := rec.deck.find(type)
	if slot >= 0 and rules.can_use_item(entity.peer_id, slot):
		if before.is_valid():
			before.call()
		_skill_slot = slot
		_item_aim = Vector2.ZERO


func _hunter_record(rules: MatchRules) -> PlayerRecord:
	return rules.record(rules.hunter_id())


## Đứng yên ở rương, bấm khi kim tới chỗ đã định (có lúc cố tình lệch để giống người).
func _play_qte(rules: MatchRules, rec: PlayerRecord) -> void:
	if _qte_for != rec.qte_started:
		_qte_for = rec.qte_started
		_qte_done = false
		var roll := randf()
		if roll < QTE_PERFECT_CHANCE:
			_qte_offset = 0.0
		elif roll < QTE_PERFECT_CHANCE + QTE_GOOD_CHANCE:
			_qte_offset = (rules.config.qte_perfect_width + rules.config.qte_good_width) / 2.0
		else:
			_qte_offset = rules.config.qte_good_width * 2.5
	if not _qte_done and rules.qte_needle(entity.peer_id) >= rec.qte_zone + _qte_offset:
		_interact = true
		_qte_done = true


## Người gục mà đi bộ tới được (không nằm trong tường nhà tù).
func _reachable_downed(ents: Array, prisons: Array) -> Array:
	return _escapees_in(ents, GameTypes.PlayerState.DOWNED).filter(func(e: EntityBase) -> bool:
		return not _inside_prison(e.flat_position(), prisons))


func _inside_prison(p: Vector2, prisons: Array) -> bool:
	for c: Vector2 in prisons:
		if p.distance_to(c) < PRISON_INSIDE:
			return true
	return false


func _near_coins(me: Vector2) -> Array:
	return entity.get_tree().get_nodes_in_group(GameTypes.GROUP_COINS).filter(
		func(c: Interactable) -> bool: return GameState.rules.coins.has(c.interactable_id) \
			and me.distance_to(_flat(c.global_position)) <= COIN_GRAB_DIST).map(
		func(c: Node3D) -> Vector2: return _flat(c.global_position))


## Nhân vật bot này thấy được (người phe kia nấp trong bụi cây thì không thấy).
func _entities() -> Array:
	return entity.get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES).filter(
		func(e: EntityBase) -> bool: return GameState.can_see(entity.peer_id, e.peer_id))


func _escapees_where(ents: Array, filter: Callable) -> Array:
	return ents.filter(func(e: EntityBase) -> bool: return not e.is_hunter() and filter.call(e))


func _escapees_in(ents: Array, s: GameTypes.PlayerState) -> Array:
	return _escapees_where(ents, func(e: EntityBase) -> bool: return e.state == s)


func _nearest_hunter_pos(ents: Array, me: Vector2) -> Vector2:
	var hunters := ents.filter(func(e: EntityBase) -> bool: return e.is_hunter())
	return _nearest(_flat_positions(hunters), me, me + Vector2(1000, 0))


func _flat_positions(ents: Array) -> Array:
	return ents.map(func(e: EntityBase) -> Vector2: return e.flat_position())


func _positions(group: StringName) -> Array:
	return entity.get_tree().get_nodes_in_group(group).map(func(n: Node3D) -> Vector2: return _flat(n.global_position))


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _nearest(points: Array, me: Vector2, fallback: Vector2) -> Vector2:
	var best := fallback
	var best_d := INF
	for p: Vector2 in points:
		var d := me.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best
