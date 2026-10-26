class_name BotInputSource
extends InputSource
## Bot thay chỗ bàn phím, có 3 mức độ khó (BotLevel). Làm việc trên mặt phẳng
## sàn (x, z): get_move().x = trục x, get_move().y = trục z của thế giới.
## Bot chỉ chọn hướng đi và nút bấm; đúng/sai do GameState quyết như người thật.
##
## Chơi công bằng: bot chỉ thấy phe kia trong khung nhìn quanh mình (cỡ màn hình
## điện thoại, BotLevel.sight), không thấy người nấp bụi (GameState.can_see),
## nhớ chỗ thấy lần cuối một lúc (BotLevel.memory) rồi quên. Đồng đội thì thấy
## hết như trên minimap. Thợ săn bật radar thì đọc dấu chân như màn hình radar.
## Tìm đường bằng lưới A* (BotNavGrid) dựng từ khối va chạm của bản đồ.
##
## Thợ săn: kéo người thì mang về nhà tù gần nhất; thấy người gục thì tới túm;
## thấy người trốn thì đuổi (tới chỗ đoán người đó sẽ tới), vào tầm và không
## vướng tường thì bắn (mức khó ngắm đón đầu theo hướng chạy). Mất dấu thì tới
## chỗ thấy lần cuối, bật radar, dịch chuyển tới dấu chân xa; không còn gì thì
## canh rương sắp mở xong / cổng đang mở (mức dễ đi lung tung giữa các rương).
## Người trốn: bị kéo thì chịu; trong tù được cứu thì giẫm đệm lò xo; đạn bay
## tới thì bước ngang né; cổng mở thì chạy ra cổng (cổng bị canh thì cổng kia);
## thợ săn tới gần thì chạy về chỗ thoáng xa nó, nấp bụi; đồng đội gục thì
## người gần nhất tới đỡ; có túi máu thì ném cứu người bị kéo / bị nhốt; nhặt
## tiền gần; còn lại cạy rương xa thợ săn và căn vòng. Thợ săn đứng im lâu
## (không đi, không bắn) thì chỉ né khi nó sát bên.

const THINK_INTERVAL := 0.1 # bot nghĩ 10 lần/giây (đỡ tốn CPU server), giữa hai lần giữ nguyên nút
const ARRIVE_DIST := 1.2
const ACT_DIST := 1.3 # đủ gần để nhấc / đỡ
const SAFE_TO_RESCUE_DIST := 6.0 # thợ săn xa hơn chừng này mới đi cứu
const COIN_GRAB_DIST := 5.0 # tiền trong bán kính này thì ghé nhặt
const PRISON_INSIDE := 2.4 # mét từ giữa nhà tù: đang kẹt trong tường (huyết trận cạnh trong 4,2 m)
const TELEPORT_DIST := 14.0 # thợ săn: người trốn biết chỗ xa hơn chừng này thì dịch chuyển tới
const TELEPORT_AFTER := 30.0 # giây: đầu trận thợ săn chưa dịch chuyển, để người trốn kịp tản ra
const SHOT_HEIGHT := 1.1 # ngang nòng súng, raycast xem tường có chặn không
const IDLE_HUNTER_TIME := 3.0 # giây thợ săn không đi không bắn thì coi là đứng im
const CLOSE_DIST := 1.6 # thợ săn đứng im mà sát hơn chừng này thì vẫn né
const STUN_DIST := 3.0 # thợ săn gần hơn chừng này thì ném lựu đạn làm chậm
const BOOST_DIST := 4.0 # thợ săn gần hơn chừng này thì dùng ván trượt
const PISTOL_DIST := 5.0 # thợ săn gần hơn chừng này (hoặc đang kéo người) thì bắn súng lục
# Đi đường
const STUCK_CHECK := 0.5
const DETOUR_TIME := 0.6
const REPATH_MOVE := 1.0 # đích dời hơn chừng này mét thì tìm đường lại
const REPATH_TIME := 0.6 # giây, tìm đường lại định kỳ (đích đang chạy)
const WAYPOINT_DIST := 0.35
const LOOKAHEAD := 6 # nhìn trước bấy nhiêu điểm trên đường để đi tắt cho thẳng
# Chạy trốn
const FLEE_PROBES := 12 # số hướng thử
const FLEE_STEP := 6.0 # mét mỗi hướng
const FLEE_KEEP := 0.8 # giây giữ chỗ chạy tới cho khỏi đổi ý liên tục
const BUSH_SEARCH := 8.0 # mét: bụi gần hơn chừng này mới tính chạy vào nấp
const HIDE_MAX := 6.0 # giây ngồi im trong bụi tối đa rồi đi làm tiếp
const HIDE_BREAK := 2.0 # thợ săn tới gần hơn chừng này thì bỏ bụi chạy
# Thợ săn đi tuần
const PATROL_KEEP := 10.0 # giây giữ một điểm tuần
const GATE_CAMP_DIST := 5.0 # thợ săn đứng gần cổng hơn chừng này: coi như canh cổng
const JUKE_TIME := Vector2(0.3, 0.6) # giây giữa hai lần đổi hướng chữ chi
const COVER_BONUS := 3.0 # chỗ chạy có tường chắn giữa mình và thợ săn thì được cộng điểm

var level: BotLevel # chọn lúc vào trận (BotLevel.for_role), cần biết vai mình

var _move := Vector2.ZERO
var _interact := false
var _shoot := false # thợ săn bắn theo hướng _shoot_dir, chỉ bật đúng frame bot nghĩ
var _shoot_dir := Vector2.ZERO
var _skill_slot := -1 # ô thẻ bot bấm trong frame này (-1 = không)
var _item_aim := Vector2.ZERO # chỗ ném thẻ (như người kéo thẻ): hướng x, z thế giới, độ xa 0..1
var _clock := 0.0 # giây, đồng hồ riêng của bot
var _think_left := 0.0
# Vòng căn
var _qte_for := -1.0 # qte_started của vòng căn đang tính
var _qte_offset := 0.0 # bot định bấm lệch vùng sáng chừng này
var _qte_done := false
var _qte_pressed := false # vừa bấm trong vòng căn: thả nút ngay khi vòng căn kết thúc
# Đi đường
var _nav: BotNavGrid
var _path := PackedVector2Array()
var _path_i := 0
var _path_goal := Vector2.INF
var _path_age := 0.0
var _direct := false # tới đích đi thẳng được, không cần đường
var _last_pos := Vector2.ZERO
var _check_timer := 0.0
var _detour_time := 0.0
var _detour_dir := Vector2.ZERO
var _pause_left := 0.0 # bot dễ đứng ngẩn ra
# Vật đứng yên trên bản đồ, tìm một lần
var _static_ready := false
var _safes: Array[Vector2] = []
var _safe_ids: Array[int] = []
var _gates: Array[Vector2] = []
var _prisons: Array[Vector2] = []
var _bushes: Array[Vector3] = [] # x, z, bán kính
# Giác quan: id phe kia -> {"pos", "vel", "seen", "since", "active", "attack_seq", "state"}
var _known := {}
var _dodge_rolls := {} # id viên đạn -> có né không (quyết một lần mỗi viên)
# Người trốn
var _flee_goal := Vector2.INF
var _flee_until := 0.0
var _hide_until := 0.0
var _juke_sign := 1.0
var _juke_until := 0.0
var _dodging := false # đang bước né đạn (xét từng frame)
var _chest_goal := -1 # chỉ số trong _safes
# Thợ săn
var _patrol_goal := Vector2.INF
var _patrol_until := 0.0
var _ready_since := INF # lúc súng hồi xong (chờ fire_delay rồi mới bắn)


func get_move() -> Vector2:
	return _move


func get_aim() -> Vector2:
	if _shoot:
		return _shoot_dir
	return _item_aim if _skill_slot >= 0 else Vector2.ZERO


func is_pressed(action: StringName) -> bool:
	if action == &"interact":
		return _interact
	if action == &"shoot":
		return _shoot
	return _skill_slot >= 0 and action == InputSource.SKILL_ACTIONS[_skill_slot]


func update(delta: float) -> void:
	_skill_slot = -1 # nút thẻ / bắn bấm một lần, chỉ bật đúng frame bot nghĩ
	_shoot = false
	_clock += delta
	var rules := GameState.rules
	if entity == null or rules == null or not entity.is_inside_tree():
		return
	if not _static_ready: # dựng lưới trong lúc đếm ngược, không làm khựng lúc đang chơi
		_setup_static()
	if not rules.is_playing() or rules.record(entity.peer_id) == null:
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
	if not entity.is_hunter() and GameTypes.is_active(entity.state) and not rules.shots.is_empty():
		var dodge := _dodge_dir(rules, entity.flat_position()) # né đạn cần chính xác từng frame
		if dodge != Vector2.ZERO:
			_move = dodge
			_interact = false
			_dodging = true
			return
	if _dodging: # vừa né xong: nghĩ lại ngay
		_dodging = false
		_think_left = 0.0
	_think_left -= delta
	if _think_left > 0.0:
		return
	_think_left = THINK_INTERVAL
	_think(rules, rec)


func _setup_static() -> void:
	_static_ready = true
	level = BotLevel.make(BotLevel.for_role(GameTypes.Role.HUNTER if entity.is_hunter() else GameTypes.Role.ESCAPEE))
	var tree := entity.get_tree()
	for sf in tree.get_nodes_in_group(GameTypes.GROUP_SAFES):
		_safes.append(_flat((sf as Node3D).global_position))
		_safe_ids.append((sf as Interactable).interactable_id)
	_gates.assign(_positions(GameTypes.GROUP_EXIT_GATES))
	_prisons.assign(_positions(GameTypes.GROUP_PRISONS))
	var map := tree.get_first_node_in_group(GameTypes.GROUP_MAP) as Node3D
	if map:
		if map.has_method(&"get_bushes"):
			_bushes.assign(map.get_bushes())
		_nav = BotNavGrid.for_map(map)
		if not _nav.logged:
			_nav.logged = true
			GameLog.info("Bot: lưới tìm đường dựng trong %d ms" % _nav.build_ms)
	GameLog.info("Bot %s (%s): mức %s" % [entity.peer_id, "thợ săn" if entity.is_hunter() else "người trốn", BotLevel.NAMES[level.level]])


func _think(rules: MatchRules, rec: PlayerRecord) -> void:
	_move = Vector2.ZERO
	_interact = false
	_path_age += THINK_INTERVAL
	match entity.state:
		GameTypes.PlayerState.CARRIED, GameTypes.PlayerState.IMPRISONED, \
				GameTypes.PlayerState.ESCAPED, GameTypes.PlayerState.ELIMINATED:
			return
	var me := entity.flat_position()
	var ents := entity.get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES)
	_perceive(rules, ents, me)
	var dir := _think_hunter(rules, rec, me, ents) if entity.is_hunter() else _think_escapee(rules, rec, me, ents)
	dir = _unstick(me, dir)
	if _pause_left > 0.0:
		_pause_left -= THINK_INTERVAL
		if not _interact:
			dir = Vector2.ZERO
	elif level.hesitate > 0.0 and randf() < level.hesitate * THINK_INTERVAL:
		_pause_left = randf_range(0.4, 0.9)
	_move = dir


# ---------- Giác quan ----------

## Cập nhật trí nhớ về phe kia: chỉ người trong khung nhìn và không nấp bụi.
func _perceive(rules: MatchRules, ents: Array, me: Vector2) -> void:
	for node in ents:
		var e := node as EntityBase
		if e == entity or e.is_hunter() == entity.is_hunter():
			continue
		var p := e.flat_position()
		var off := (p - me).abs()
		if off.x > level.sight.x or off.y > level.sight.y or not GameState.can_see(entity.peer_id, e.peer_id):
			continue
		var k: Dictionary = _known.get(e.peer_id, {})
		if k.is_empty():
			k = {"pos": p, "vel": Vector2.ZERO, "seen": -INF, "since": 0.0, "active": _clock, "attack_seq": -1, "state": e.state}
			_known[e.peer_id] = k
		var gap: float = _clock - k["seen"]
		if gap > level.memory:
			k["since"] = _clock # lần thấy mới: cần thời gian phản ứng
			k["vel"] = Vector2.ZERO
		elif gap > 0.0 and gap < 0.5:
			k["vel"] = (k["vel"] as Vector2).lerp((p - k["pos"]) / gap, 0.5)
		if (k["vel"] as Vector2).length() > 0.5:
			k["active"] = _clock
		var r := rules.record(e.peer_id)
		if r and r.attack_seq != k["attack_seq"]:
			if k["attack_seq"] >= 0:
				k["active"] = _clock
			k["attack_seq"] = r.attack_seq
		k["pos"] = p
		k["seen"] = _clock
		k["state"] = e.state


## Đã nhận ra người `id` (thấy đủ lâu để phản ứng, chưa quên).
func _noticed(id: int) -> bool:
	if not _known.has(id):
		return false
	var k: Dictionary = _known[id]
	return _clock - k["seen"] <= level.memory and _clock - k["since"] >= level.reaction


## Chỗ đoán người `id` đang ở: chỗ thấy lần cuối cộng hướng chạy (tối đa 1,5 giây).
func _guess_pos(id: int) -> Vector2:
	var k: Dictionary = _known[id]
	var age: float = minf(_clock - k["seen"], 1.5)
	return (k["pos"] as Vector2) + (k["vel"] as Vector2) * age


func _visible_now(id: int) -> bool:
	return _known.has(id) and _clock - _known[id]["seen"] < THINK_INTERVAL * 0.5


## Radar: dấu chân như trên màn hình thợ săn (vị trí cuối của mỗi người trốn trong footprint_history).
func _read_radar(rules: MatchRules) -> void:
	for id: int in rules.footprints:
		var trail: Array = rules.footprints[id]
		var st := rules.state_of(id)
		if trail.is_empty() or not (GameTypes.is_active(st) or st == GameTypes.PlayerState.DOWNED):
			continue
		var f: Vector3 = trail[trail.size() - 1]
		var age := rules.elapsed - f.y
		if age > rules.config.footprint_history:
			continue
		var seen := _clock - age
		var k: Dictionary = _known.get(id, {})
		if k.is_empty():
			k = {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "seen": -INF, "since": 0.0, "active": _clock, "attack_seq": -1, "state": st}
			_known[id] = k
		if k["seen"] < seen:
			k["pos"] = Vector2(f.x, f.z)
			k["vel"] = Vector2.ZERO
			k["seen"] = seen
			k["since"] = seen - level.reaction
			k["state"] = st


# ---------- Thợ săn ----------

func _think_hunter(rules: MatchRules, rec: PlayerRecord, me: Vector2, ents: Array) -> Vector2:
	if rec.carrying_id != 0:
		_patrol_until = 0.0
		return _steer(me, _nearest(_prisons, me, me), ARRIVE_DIST)

	# Người gục đã thấy, đi bộ tới được: tới túm.
	var downed_id := 0
	var downed_d := INF
	var prey_id := 0
	var prey_score := INF
	for id: int in _known:
		if not _noticed(id):
			continue
		var st: GameTypes.PlayerState = _known[id]["state"] # trạng thái lúc thấy lần cuối
		var p := _guess_pos(id)
		var d := me.distance_to(p)
		if st == GameTypes.PlayerState.DOWNED and not _inside_prison(p) and d < downed_d:
			downed_d = d
			downed_id = id
		elif rules.is_hittable(id) or GameTypes.is_active(st):
			var score := d
			if level.smart_patrol: # ưu tiên người sắp gục, người đang cạy rương (đứng yên)
				var r := rules.record(id)
				if r and r.hp <= 1:
					score -= 2.0
				if r and r.chest_id >= 0:
					score -= 1.5
			if score < prey_score:
				prey_score = score
				prey_id = id
	if downed_id != 0:
		var p := _guess_pos(downed_id)
		_patrol_until = 0.0
		if me.distance_to(p) <= ACT_DIST:
			_interact = true # nhân vật túm người gục gần nhất
			return (p - me).normalized() * 0.2
		return _steer(me, p, 0.6)

	if not rules.can_attack(entity.peer_id):
		_ready_since = INF
	elif _ready_since == INF:
		_ready_since = _clock
	if prey_id != 0:
		_patrol_until = 0.0
		var p := _guess_pos(prey_id)
		var d := me.distance_to(p)
		if _visible_now(prey_id) and _clock - _ready_since >= level.fire_delay and d <= level.shoot_dist \
				and rules.is_hittable(prey_id) and _pause_left <= 0.0:
			_try_shoot(rules, me, prey_id)
		elif d > TELEPORT_DIST and level.use_teleport and rules.elapsed >= TELEPORT_AFTER:
			_use_slot_of(rules, rec, GameTypes.ItemType.TELEPORT, func() -> void:
				_set_aim_point(Vector3(p.x, 0, p.y)))
		# Chạy tới chỗ người đó sắp tới, không chạy theo đuôi.
		var lead := p + (_known[prey_id]["vel"] as Vector2) * clampf(d / 5.0, 0.0, 1.0) * level.aim_lead
		var dir := _steer(me, lead, 0.3)
		if not _visible_now(prey_id) and me.distance_to(p) < 1.0:
			_known[prey_id]["seen"] = -INF # tới chỗ thấy lần cuối mà không có ai: quên
		return dir

	# Mất dấu hết: radar rồi đi tuần.
	if level.use_radar and _use_slot_of(rules, rec, GameTypes.ItemType.RADAR, Callable()):
		_read_radar(rules)
	return _steer(me, _patrol_point(rules, me), ARRIVE_DIST)


## Bắn theo hướng (như người kéo cần ngắm): đón đầu theo hướng chạy, lệch ngẫu nhiên theo mức.
func _try_shoot(rules: MatchRules, me: Vector2, id: int) -> void:
	var k: Dictionary = _known[id]
	var pos: Vector2 = k["pos"]
	if not _clear_shot(me, pos):
		return
	var vel: Vector2 = k["vel"] * level.aim_lead
	var aim := pos
	for i in 2: # đạn bay mất một lúc: đoán chỗ người đó sẽ tới
		aim = pos + vel * (me.distance_to(aim) / rules.config.rifle_speed)
	var to := aim - me
	if to.length() < 0.1:
		to = pos - me
	_shoot_dir = to.normalized().rotated(deg_to_rad(randfn(0.0, level.aim_error)))
	_shoot = true


func _clear_shot(me: Vector2, to: Vector2) -> bool:
	var space := entity.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(me.x, SHOT_HEIGHT, me.y), Vector3(to.x, SHOT_HEIGHT, to.y), 1)
	return space.intersect_ray(q).is_empty()


## Điểm đi tuần khi không biết người trốn ở đâu.
func _patrol_point(rules: MatchRules, me: Vector2) -> Vector2:
	if _patrol_goal != Vector2.INF and _clock < _patrol_until and me.distance_to(_patrol_goal) > ARRIVE_DIST * 2.0:
		return _patrol_goal
	_patrol_until = _clock + PATROL_KEEP
	var gate_up := rules.gate_open or rules.gate_opening_left > 0.0
	if level.smart_patrol and gate_up and not _gates.is_empty():
		_patrol_goal = _gates[randi() % _gates.size()]
		return _patrol_goal
	var best := -INF
	_patrol_goal = _nearest(_prisons, me, me)
	for i in _safes.size():
		var prog: float = rules.safe_progress.get(_safe_ids[i], 1.0)
		if prog >= 1.0 or me.distance_to(_safes[i]) < ARRIVE_DIST * 2.0:
			continue
		# Mức thường / khó: rương mở dở nhiều nhất (người trốn hay quay lại); mức dễ: ngẫu nhiên.
		var score := randf() + (prog * 3.0 - me.distance_to(_safes[i]) / 30.0 if level.smart_patrol else 0.0)
		if score > best:
			best = score
			_patrol_goal = _safes[i]
	return _patrol_goal


# ---------- Người trốn ----------

func _think_escapee(rules: MatchRules, rec: PlayerRecord, me: Vector2, ents: Array) -> Vector2:
	var hunter_id := rules.hunter_id()
	var hunter_known := _noticed(hunter_id)
	var hunter_pos := _guess_pos(hunter_id) if hunter_known else me + Vector2(1000, 0)
	var hunter_dist := me.distance_to(hunter_pos) if hunter_known else INF
	var hunter_idle: bool = hunter_known and _clock - _known[hunter_id]["active"] > IDLE_HUNTER_TIME
	if hunter_known and _visible_now(hunter_id) and rules.record(hunter_id).carrying_id != 0:
		hunter_idle = true # đang kéo người thì không bắn được: không cần chạy
	var downed_me := entity.state == GameTypes.PlayerState.DOWNED

	# Đồng đội: thấy hết như minimap.
	var downed: Array[EntityBase] = []
	var captured: Array[EntityBase] = []
	var allies: Array[EntityBase] = []
	for node in ents:
		var e := node as EntityBase
		if e == entity or e.is_hunter():
			continue
		match e.state:
			GameTypes.PlayerState.DOWNED:
				if not _inside_prison(e.flat_position()):
					downed.append(e)
			GameTypes.PlayerState.CARRIED, GameTypes.PlayerState.IMPRISONED:
				captured.append(e)
			_:
				if GameTypes.is_active(e.state):
					allies.append(e)

	# Thẻ: túi máu cho người cần cứu trong tầm ném, lựu đạn / súng / ván trượt khi bị đuổi.
	if not downed_me and randf() < level.item_chance:
		var needy: Array[EntityBase] = captured.duplicate()
		if hunter_dist < SAFE_TO_RESCUE_DIST:
			needy.append_array(downed) # thợ săn ở gần thì ném luôn, không kịp đỡ tay
		var throw_range := rules.config.medkit_range * 0.9
		var ally: Variant = null
		var ally_d := throw_range
		for e in needy:
			var d := me.distance_to(e.flat_position())
			if d <= ally_d:
				ally_d = d
				ally = e.flat_position()
		_use_items(rules, rec, me, ally, hunter_id if hunter_known else 0, hunter_pos, hunter_dist)

	var threat: bool = hunter_known and _clock - _known[hunter_id]["seen"] < 1.0 \
			and (hunter_dist < CLOSE_DIST or (not hunter_idle and hunter_dist < level.flee_dist))
	if not threat and hunter_known and not hunter_idle and level.wary_dist > 0.0 and hunter_dist < level.wary_dist:
		var to_me := (me - hunter_pos).normalized()
		threat = (_known[hunter_id]["vel"] as Vector2).dot(to_me) > 1.5 # đang lao về phía mình

	if downed_me:
		if threat:
			return _flee(me, hunter_pos)
		if level.team_rescue and not allies.is_empty(): # bò về phía đồng đội cho nhanh được đỡ
			return _steer(me, _nearest(_flat_positions(allies), me, me), ACT_DIST)
		return Vector2.ZERO

	if _inside_prison(me):
		return _steer(me, _nearest(_positions(GameTypes.GROUP_JUMP_PADS), me, me), 0.05) # phải giẫm hẳn lên đệm

	# Đang nấp trong bụi mà thợ săn chưa tới sát: ngồi im.
	if level.hide_in_bush and _clock < _hide_until and rules.bush_of.get(entity.peer_id, -1) >= 0 \
			and hunter_dist > HIDE_BREAK:
		return Vector2.ZERO

	if rules.gate_open or rules.gate_opening_left > 0.0:
		var gate := _pick_gate(me, hunter_known, hunter_pos)
		if threat and hunter_dist < CLOSE_DIST:
			return _flee(me, hunter_pos)
		return _steer(me, gate, 0.3)

	if threat:
		return _flee(me, hunter_pos)
	_flee_goal = Vector2.INF

	if not downed.is_empty() and hunter_dist > SAFE_TO_RESCUE_DIST:
		var target := _nearest(_flat_positions(downed), me, me)
		if not level.team_rescue or _closest_to(target, me, allies):
			if me.distance_to(target) <= ACT_DIST:
				_interact = true # giữ nút đỡ dậy
				return (target - me).normalized() * 0.2
			return _steer(me, target, ACT_DIST * 0.8)

	var medkit_slot := rec.deck.find(GameTypes.ItemType.MEDKIT)
	var has_medkit: bool = medkit_slot >= 0 and rec.coins >= rules.catalog[GameTypes.ItemType.MEDKIT]["cost"]
	if has_medkit and not captured.is_empty() and hunter_dist > level.flee_dist:
		var target := _nearest(_flat_positions(captured), me, me)
		return _steer(me, target, rules.config.medkit_range * 0.7)

	if hunter_dist > SAFE_TO_RESCUE_DIST:
		var coin := _nearest_coin(me)
		if coin != Vector2.INF:
			return _steer(me, coin, 0.3)

	var chest := _pick_chest(rules, me, hunter_known, hunter_pos, allies)
	if chest < 0:
		return _steer(me, _nearest(_gates, me, me), ARRIVE_DIST) # hết rương: đứng chờ ở cổng
	return _steer(me, _safes[chest], ARRIVE_DIST)


## Chọn chỗ chạy: hướng thoáng xa thợ săn nhất, có bụi gần thì chui vào nấp.
func _flee(me: Vector2, hunter_pos: Vector2) -> Vector2:
	var keep := _flee_goal != Vector2.INF and _clock < _flee_until and me.distance_to(_flee_goal) > 0.8 \
			and _flee_goal.distance_to(hunter_pos) > me.distance_to(hunter_pos)
	if not keep:
		_flee_until = _clock + FLEE_KEEP
		var away := (me - hunter_pos).normalized()
		var best := -INF
		_flee_goal = me + away * FLEE_STEP
		for i in FLEE_PROBES:
			var dir := Vector2.RIGHT.rotated(TAU * i / FLEE_PROBES)
			var c := me + dir * FLEE_STEP
			if _nav and (not _nav.is_free(c) or not _nav.clear_line(me, c)):
				continue
			var score := c.distance_to(hunter_pos) + dir.dot(away) * 2.0
			if _nav and not _nav.clear_line(hunter_pos, c, 0.6, 0.6):
				score += COVER_BONUS # tường chắn đạn
			if score > best:
				best = score
				_flee_goal = c
		if level.hide_in_bush:
			for b in _bushes:
				var c := Vector2(b.x, b.y)
				var d := me.distance_to(c)
				if d > BUSH_SEARCH or c.distance_to(hunter_pos) < me.distance_to(hunter_pos) * 0.9:
					continue # bụi phía thợ săn thì không chạy vào
				var score := c.distance_to(hunter_pos) + 4.0 - d * 0.5
				if score > best:
					best = score
					_flee_goal = c
					_hide_until = _clock + HIDE_MAX
	var dir := _steer(me, _flee_goal, 0.3)
	if level.juke > 0.0 and me.distance_to(hunter_pos) < GameState.rules.config.rifle_range and dir != Vector2.ZERO:
		if _clock >= _juke_until:
			_juke_sign = -_juke_sign
			_juke_until = _clock + randf_range(JUKE_TIME.x, JUKE_TIME.y)
		var side := dir.orthogonal() * _juke_sign * level.juke
		if not _nav or _nav.is_free(me + (dir + side).normalized()):
			dir = (dir + side).normalized()
	return dir


## Hướng bước ngang khi có đạn súng thợ săn sắp trúng mình, ZERO nếu không cần.
func _dodge_dir(rules: MatchRules, me: Vector2) -> Vector2:
	if rules.shots.is_empty():
		_dodge_rolls.clear()
		return Vector2.ZERO
	for id: int in _dodge_rolls.keys():
		if not rules.shots.has(id):
			_dodge_rolls.erase(id)
	var hit_r := rules.config.rifle_radius + 0.7
	for id: int in rules.shots:
		var s: Dictionary = rules.shots[id]
		if s["kind"] != GameTypes.ShotKind.RIFLE or rules.elapsed - s["fired"] < level.reaction * 0.6:
			continue # chưa kịp thấy
		var from := Vector2(s["from"].x, s["from"].z)
		var to := Vector2(s["to"].x, s["to"].z)
		var off := (from - me).abs()
		if off.x > level.sight.x or off.y > level.sight.y:
			continue
		var span: float = s["lands"] - s["fired"]
		var cur := from.lerp(to, clampf((rules.elapsed - s["fired"]) / span, 0.0, 1.0) if span > 0.0 else 1.0)
		var q := Geometry2D.get_closest_point_to_segment(me, cur, to)
		if me.distance_to(q) > hit_r:
			continue
		if not _dodge_rolls.has(id):
			_dodge_rolls[id] = randf() < level.dodge_chance
		if not _dodge_rolls[id]:
			continue
		var axis := (to - from).normalized()
		var side := Vector2(-axis.y, axis.x)
		if (me - q).dot(side) < 0.0:
			side = -side
		if _nav and not _nav.is_free(me + side):
			side = -side
		return side
	return Vector2.ZERO


## Rương để cạy: mức dễ chọn rương gần nhất; mức thường / khó tránh rương gần
## thợ săn, thích rương mở dở, tản ra rương không có đồng đội, giữ rương đang
## làm cho khỏi đổi ý.
func _pick_chest(rules: MatchRules, me: Vector2, hunter_known: bool, hunter_pos: Vector2, allies: Array[EntityBase]) -> int:
	var best := -1
	var best_score := INF
	for i in _safes.size():
		var prog: float = rules.safe_progress.get(_safe_ids[i], 1.0)
		if prog >= 1.0:
			continue
		var score := me.distance_to(_safes[i])
		if level.smart_chest:
			score -= prog * 8.0
			if hunter_known and hunter_pos.distance_to(_safes[i]) < 9.0:
				score += 25.0
			if i == _chest_goal:
				score -= 4.0
			for e in allies: # tản ra: đứng chung một rương thì bị bắt cả đám
				if e.flat_position().distance_to(_safes[i]) < 3.0:
					score += 6.0
		if score < best_score:
			best_score = score
			best = i
	_chest_goal = best
	return best


## Cổng để chạy ra: gần nhất; mức thường / khó tránh cổng thợ săn đang canh.
func _pick_gate(me: Vector2, hunter_known: bool, hunter_pos: Vector2) -> Vector2:
	var best := me
	var best_score := INF
	for g in _gates:
		var score := me.distance_to(g)
		if level.smart_chest and hunter_known and hunter_pos.distance_to(g) < GATE_CAMP_DIST:
			score += 30.0
		if score < best_score:
			best_score = score
			best = g
	return best


## `me` là người đứng gần `target` nhất trong số mình và `others`.
func _closest_to(target: Vector2, me: Vector2, others: Array[EntityBase]) -> bool:
	var mine := me.distance_to(target)
	for e in others:
		if e.flat_position().distance_to(target) < mine - 0.5:
			return false
	return true


## Chọn thẻ để bấm: túi máu ném vào người cần cứu trong tầm (`ally`, null nếu
## không có); lựu đạn làm chậm ném vào thợ săn khi nó sát mình; súng khi thợ
## săn đang kéo người (bắn hết máu thì nó buông) hoặc đuổi gần; ván trượt khi
## bị đuổi sát. Chỉ biết thợ săn khi đang thấy (`hunter_id` = 0 nếu không).
func _use_items(rules: MatchRules, rec: PlayerRecord, me: Vector2, ally: Variant, hunter_id: int, hunter_pos: Vector2, hunter_dist: float) -> void:
	var hunter := rules.record(hunter_id) if hunter_id != 0 and _visible_now(hunter_id) else null
	var wants := []
	var spots := {} # loại thẻ -> chỗ ném
	if ally != null:
		wants.append(GameTypes.ItemType.MEDKIT)
		spots[GameTypes.ItemType.MEDKIT] = ally
	if hunter and hunter_dist < STUN_DIST and hunter.speed_boost_left <= 0.0:
		wants.append(GameTypes.ItemType.STUN_GRENADE)
		spots[GameTypes.ItemType.STUN_GRENADE] = hunter_pos
	if hunter and hunter.hp > 0 and hunter_dist < rules.config.bullet_range * 0.9 \
			and (hunter.carrying_id != 0 or hunter_dist < PISTOL_DIST):
		wants.append(GameTypes.ItemType.PISTOL)
	if hunter and hunter_dist < BOOST_DIST and hunter.carrying_id == 0:
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
func _use_slot_of(rules: MatchRules, rec: PlayerRecord, type: GameTypes.ItemType, before: Callable) -> bool:
	if _shoot:
		return false
	var slot := rec.deck.find(type)
	if slot >= 0 and rules.can_use_item(entity.peer_id, slot):
		if before.is_valid():
			before.call()
		_skill_slot = slot
		_item_aim = Vector2.ZERO
		return true
	return false


## Chọn điểm như chạm minimap. Bot chạy trên client (--join --bot) thì gửi lên server.
func _set_aim_point(p: Vector3) -> void:
	if entity.multiplayer.is_server():
		GameState.server_set_aim_point(entity.peer_id, p)
	else:
		GameState.set_aim_point(p)


## Đứng yên ở rương, bấm khi kim tới chỗ đã định (có lúc cố tình lệch để giống người).
func _play_qte(rules: MatchRules, rec: PlayerRecord) -> void:
	if _qte_for != rec.qte_started:
		_qte_for = rec.qte_started
		_qte_done = false
		var roll := randf()
		if roll < level.qte_perfect:
			_qte_offset = randf_range(-0.5, 0.5) * rules.config.qte_perfect_width
		elif roll < level.qte_perfect + level.qte_good:
			_qte_offset = (rules.config.qte_perfect_width + rules.config.qte_good_width) / 2.0
		else:
			_qte_offset = rules.config.qte_good_width * 2.5
	if not _qte_done and rules.qte_needle(entity.peer_id) >= rec.qte_zone + _qte_offset:
		_interact = true
		_qte_done = true


# ---------- Đi đường ----------

## Hướng đi tới `target` theo lưới A*: thấy đường thẳng thì đi thẳng, không thì
## theo đường đã tìm. Chỉ xét lại khi đích dời xa hoặc định kỳ (REPATH_TIME).
func _steer(me: Vector2, target: Vector2, arrive: float) -> Vector2:
	var to_target := target - me
	if to_target.length() <= arrive:
		return Vector2.ZERO
	if _nav == null:
		return to_target.normalized()
	if _path_goal.distance_to(target) > REPATH_MOVE or _path_age > REPATH_TIME:
		_path_goal = target
		_path_age = 0.0
		_path_i = 0
		_direct = _nav.clear_line(me, target, 0.6, arrive + 0.4)
		_path = PackedVector2Array() if _direct else _nav.find_path(me, target)
	if _direct or _path.is_empty():
		return to_target.normalized()
	var last := _path.size() - 1
	while _path_i < last and me.distance_to(_path[_path_i]) < WAYPOINT_DIST:
		_path_i += 1
	var j := mini(_path_i + LOOKAHEAD, last)
	while j > _path_i and not _nav.clear_line(me, _path[j], 0.3):
		j -= 1
	_path_i = j
	var wp := _path[_path_i]
	if _path_i == last and me.distance_to(wp) < WAYPOINT_DIST:
		return to_target.normalized() # hết đường (đích trong vật cản): đi thẳng nốt
	return (wp - me).normalized()


## Kẹt (đứng một chỗ dù đang muốn đi): tìm đường lại, vẫn kẹt thì rẽ một lúc.
func _unstick(me: Vector2, dir: Vector2) -> Vector2:
	_check_timer += THINK_INTERVAL
	if _check_timer >= STUCK_CHECK:
		if dir.length() > 0.5 and _detour_time <= 0.0 and me.distance_to(_last_pos) < 0.3:
			_path_age = REPATH_TIME + 1.0 # lần sau tìm đường lại
			_detour_time = DETOUR_TIME
			_detour_dir = dir.rotated(randf_range(PI / 2.0, PI * 1.5))
		_last_pos = me
		_check_timer = 0.0
	if _detour_time > 0.0 and not _interact:
		_detour_time -= THINK_INTERVAL
		return _detour_dir
	return dir


# ---------- Tiện ích ----------

func _inside_prison(p: Vector2) -> bool:
	for c in _prisons:
		if p.distance_to(c) < PRISON_INSIDE:
			return true
	return false


## Cọc tiền gần nhất trong tầm nhặt (trong khung nhìn), INF nếu không có.
func _nearest_coin(me: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_d := COIN_GRAB_DIST
	for c in entity.get_tree().get_nodes_in_group(GameTypes.GROUP_COINS):
		var coin := c as Interactable
		if not GameState.rules.coins.has(coin.interactable_id):
			continue
		var p := _flat(coin.global_position)
		var d := me.distance_to(p)
		if d <= best_d:
			best_d = d
			best = p
	return best


func _flat_positions(ents: Array[EntityBase]) -> Array:
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
