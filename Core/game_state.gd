extends Node
## Autoload "GameState": cổng duy nhất để đổi trạng thái trận.
##
## Mô hình: server giữ bản gốc (MatchRules), module gọi lệnh server_*(),
## lệnh hợp lệ thì MatchRules đổi dữ liệu và đánh dấu người chơi bị đổi.
## Cuối mỗi physics frame, flush() gửi những trường đã đổi của những người đó
## (PlayerRecord.diff, kênh reliable có thứ tự) xuống mọi máy, kể cả chính
## server. Mỗi máy dựng lại bản đầy đủ, so bản cũ với bản mới để tự sinh sự
## kiện EventBus. Vì gửi trạng thái chứ không gửi lệnh, client không bao giờ
## lệch dù gói tin bị gộp; offline đi đúng đường này.
##
## Gọi server_*() trên client sẽ bị bỏ qua (trả về false), nên module cứ gọi.

const TIME_SYNC_INTERVAL := 0.5
const INPUT_SEND_HALF_INTERVAL := 1.0 / 60.0 ## client gửi input 30 lần/giây: trung bình trễ thêm nửa nhịp
const HIT_PADDING := 0.3 ## mét, cộng vào bán kính đạn cho bằng thân người
const SHOT_HEIGHT := 1.1 ## mét, đạn bay ngang tầm ngực
const TELEPORT_CLEARANCE := 0.45 ## mét, bán kính khoảng trống cần có ở điểm dịch chuyển tới
const PRISON_KEEP_OUT := 2.8 ## mét từ giữa nhà tù: không dịch chuyển vào trong tường
const PROGRESS_SYNC_INTERVAL := 0.1 ## tiến độ cứu, máu trong tù chỉ gửi 10 lần/giây
## Các trường đổi liên tục; chỉ đổi những trường này thì gửi thưa hơn (Dictionary để tra O(1)).
const _CONTINUOUS_KEYS := {"rescue_progress": true, "prison_time_left": true, "invulnerable_left": true, "attack_cooldown_left": true,
	"stunned_left": true, "chest_work": true, "item_cooldowns": true, "speed_boost_left": true}

var rules: MatchRules = null

var _time_sync_timer := 0.0
var _progress_sync_timer := 0.0
var _pending := {} # chỉ server: id -> true, người chơi có dữ liệu chưa gửi
var _sent := {} # chỉ server: id -> dict đã gửi lần cuối
var _applied := {} # mọi máy: id -> dict đã áp dụng lần cuối (để sinh sự kiện)
var _world_pending := false # chỉ server
var _world_sent := {} # chỉ server
var _world_applied := {} # mọi máy
var _effects := {} # ItemType -> ItemEffect (chỉ server dùng)
var _aim_points := {} # chỉ server: id -> Vector3, điểm người chơi chọn trên minimap
var _footprints := {} # chỉ server: id người trốn -> [Vector3 (y = elapsed lúc ghi)]
var _footprint_timer := 0.0
var _bush_of := {} # chỉ server: id -> chỉ số bụi cây đang đứng trong, -1 nếu không
var _shot_progress := {} # chỉ server: shot_id -> phần đường đạn (0..1) đã xét va chạm
var _bushes: Array[Vector3] = [] # mọi máy: bụi cây của bản đồ (x, z, bán kính)
var _bushes_loaded := false


func _ready() -> void:
	Net.player_left.connect(_on_player_left)


func begin(info: Dictionary, total_safes: int, floor_coins: int = 0) -> void:
	var cfg := MatchConfig.new()
	cfg.duration = info["time"]
	rules = MatchRules.new(cfg, info["roles"], info["names"], total_safes, floor_coins)
	_setup_items(info.get("decks", {}))
	_time_sync_timer = 0.0
	_progress_sync_timer = 0.0
	_pending.clear()
	_sent.clear()
	_applied.clear()
	for id: int in rules.players:
		_applied[id] = rules.players[id].to_dict()
		_sent[id] = _applied[id]
	_world_pending = false
	_aim_points.clear()
	_footprints.clear()
	_footprint_timer = 0.0
	_bush_of.clear()
	_shot_progress.clear()
	_bushes = [] # gán mới, không clear(): mảng bản đồ trả về có thể là hằng chỉ đọc
	_bushes_loaded = false
	_world_applied = rules.world_dict()
	_world_sent = _world_applied
	EventBus.match_state_changed.emit(rules.state)


## Bảng thẻ do Items khai báo (ModuleRegistry.ITEM_CATALOG). Mọi máy dựng giống nhau.
func _setup_items(decks: Dictionary) -> void:
	var catalog_script: Script = load(ModuleRegistry.ITEM_CATALOG)
	var items: Dictionary = catalog_script.call(&"all")
	var defaults := {}
	for role: int in [GameTypes.Role.HUNTER, GameTypes.Role.ESCAPEE]:
		defaults[role] = catalog_script.call(&"default_deck", role)
	rules.setup_items(items, decks, defaults)
	_effects.clear()
	for type: int in items:
		var data: ItemData = items[type]
		if data.effect_script != "":
			_effects[type] = load(data.effect_script).new()


func clear() -> void:
	rules = null


func my_role() -> int:
	if rules == null:
		return -1
	return rules.roles.get(multiplayer.get_unique_id(), -1)


## Match gọi đầu mỗi physics frame trên mọi máy.
func tick(delta: float) -> void:
	if rules == null:
		return
	var before := rules.state
	var server := multiplayer.is_server()
	rules.tick(delta, server)
	if rules.state != before:
		EventBus.match_state_changed.emit(rules.state)
	if not server or not rules.is_playing():
		return
	_time_sync_timer -= delta
	if _time_sync_timer <= 0.0:
		_time_sync_timer = TIME_SYNC_INTERVAL
		_sync_time.rpc(rules.time_left)


## Match gọi cuối mỗi physics frame trên server: gửi thay đổi rồi xét hết trận.
func flush(delta: float) -> void:
	if rules == null or not multiplayer.is_server():
		return
	for id: int in rules.take_dirty():
		_pending[id] = true
	_progress_sync_timer -= delta
	var send_continuous := _progress_sync_timer <= 0.0
	if send_continuous:
		_progress_sync_timer = PROGRESS_SYNC_INTERVAL
	var batch := {}
	for id: int in _pending.keys():
		var d: Dictionary = rules.players[id].to_dict()
		var old: Dictionary = _sent.get(id, {})
		if send_continuous or _is_significant(old, d):
			var changes := PlayerRecord.diff(old, d)
			if not changes.is_empty():
				batch[id] = changes
			_sent[id] = d
			_pending.erase(id)
	if not batch.is_empty():
		_sync_players.rpc(batch)
	if rules.take_world_dirty():
		_world_pending = true
	if _world_pending:
		var w := rules.world_dict()
		if send_continuous or _world_significant(_world_sent, w):
			var changes := WorldRecord.diff(_world_sent, w)
			_world_sent = w
			_world_pending = false
			if not changes.is_empty():
				_sync_world.rpc(changes)
	if rules.is_over():
		_apply_match_end.rpc(rules.results())


# ---------- API cho server (module gọi) ----------

## Thợ săn vung đòn vào những người trong tầm (module Player tính hitbox).
func server_attack(attacker_id: int, target_ids: Array) -> bool:
	return _can_mutate() and rules.attack(attacker_id, target_ids)


## Thợ săn bắn súng về phía `target` (module Player tự chọn điểm ngắm), đạn
## bay thẳng. Tầm bắn do luật kẹp, tường chặn đạn. Trả về id viên đạn, 0 nếu
## chưa bắn được (hồi chiêu...).
func server_fire_rifle(hunter: EntityBase, target: Vector3) -> int:
	if not _can_mutate() or not target.is_finite() or not rules.can_attack(hunter.peer_id):
		return 0
	var from := hunter.global_position + Vector3.UP * SHOT_HEIGHT
	return rules.fire_rifle(hunter.peer_id, from, _until_wall(hunter, from, target, rules.config.rifle_range))


## Người trốn bắn súng lục (Items gọi sau khi thẻ đã trả tiền). Tường chặn đạn.
func server_shoot_bullet(shooter: EntityBase, target: Vector3) -> int:
	if not _can_mutate() or not target.is_finite():
		return 0
	var from := shooter.global_position + Vector3.UP * SHOT_HEIGHT
	return rules.shoot_bullet(shooter.peer_id, from, _until_wall(shooter, from, target, rules.config.bullet_range))


## Điểm cuối đường đạn: kẹp trong tầm, dừng ở bức tường đầu tiên (một raycast mỗi phát).
func _until_wall(shooter: EntityBase, from: Vector3, target: Vector3, max_range: float) -> Vector3:
	var flat := Vector2(target.x - from.x, target.z - from.z).limit_length(max_range)
	var end := Vector3(from.x + flat.x, from.y, from.z + flat.y)
	var query := PhysicsRayQueryParameters3D.create(from, end, 1) # layer 1: tường, vật cản
	var hit := shooter.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else end


## Match gọi mỗi physics frame trên server sau khi mọi nhân vật đã di chuyển:
## đạn tới nơi thì xét trúng, thợ săn tụ lực xong thì dời tới chỗ mới, ghi dấu chân.
func server_after_move(entities: Array) -> void:
	if not _can_mutate():
		return
	_land_shots(entities)
	for id: int in rules.take_teleports():
		for e: EntityBase in entities:
			if e.peer_id == id:
				e.global_position = rules.record(id).teleport_pos
				e.velocity = Vector3.ZERO
	for e: EntityBase in entities:
		_bush_of[e.peer_id] = bush_at(e.global_position)
	_footprint_timer -= get_physics_process_delta_time()
	if _footprint_timer <= 0.0:
		_footprint_timer = rules.config.footprint_interval
		_record_footprints(entities)


## Bụi cây chứa điểm `pos` (chỉ số trong MapBase.get_bushes()), -1 nếu không có. Mọi máy dùng được.
func bush_at(pos: Vector3) -> int:
	if not _bushes_loaded:
		var map := get_tree().get_first_node_in_group(GameTypes.GROUP_MAP) as MapBase
		if map == null:
			return -1
		_bushes = map.get_bushes()
		_bushes_loaded = true
	for i in _bushes.size():
		var b := _bushes[i]
		if Vector2(pos.x, pos.z).distance_to(Vector2(b.x, b.y)) <= b.z:
			return i
	return -1


## Chỉ server: `viewer_id` có thấy `target_id` không. Đứng trong bụi cây thì
## phe kia không thấy, trừ khi người nhìn đứng cùng bụi; đồng đội luôn thấy nhau.
## Server không gửi vị trí người không thấy xuống máy đó (Match), bot và súng
## tự nhắm cũng dùng hàm này.
func can_see(viewer_id: int, target_id: int) -> bool:
	if viewer_id == target_id or rules == null:
		return true
	var bush: int = _bush_of.get(target_id, -1)
	if bush < 0 or rules.roles.get(viewer_id, -1) == rules.roles.get(target_id, -2):
		return true
	return _bush_of.get(viewer_id, -1) == bush


## Đạn bay thật: mỗi physics frame xét đoạn đạn vừa bay qua (theo mặt sàn),
## chạm người đầu tiên trúng được thì nổ ở đó; tới cuối đường (tường / hết tầm)
## mà không chạm ai thì trượt. Người thấy đạn tới và bước ra khỏi đường bay thì
## né được. Người không trúng được (đang gục, bất tử...) không chặn đạn.
func _land_shots(entities: Array) -> void:
	if rules.shots.is_empty():
		return
	for shot_id: int in rules.shots.keys():
		var s: Dictionary = rules.shots[shot_id]
		var span: float = s["lands"] - s["fired"]
		var t_now := clampf((rules.elapsed - s["fired"]) / span, 0.0, 1.0) if span > 0.0 else 1.0
		var t_prev: float = _shot_progress.get(shot_id, 0.0)
		var from := Vector2(s["from"].x, s["from"].z)
		var to := Vector2(s["to"].x, s["to"].z)
		var a := from.lerp(to, t_prev)
		var b := from.lerp(to, t_now)
		var r := rules.shot_radius(s["kind"]) + HIT_PADDING
		var first_id := 0
		var first_d := INF
		for e: EntityBase in entities:
			if e.peer_id == s["owner"] or not rules.can_be_shot(s["kind"], e.peer_id):
				continue
			var p := e.flat_position()
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			if p.distance_squared_to(q) <= r * r and a.distance_squared_to(q) < first_d:
				first_d = a.distance_squared_to(q)
				first_id = e.peer_id
		if first_id != 0 or t_now >= 1.0:
			_shot_progress.erase(shot_id)
			rules.land_shot(shot_id, [first_id] if first_id != 0 else [])
		else:
			_shot_progress[shot_id] = t_now


func server_pick_up(hunter_id: int, target_id: int) -> bool:
	return _can_mutate() and rules.pick_up(hunter_id, target_id)


func server_drop(hunter_id: int) -> bool:
	return _can_mutate() and rules.drop(hunter_id)


func server_imprison(hunter_id: int, prison_id: int) -> bool:
	return _can_mutate() and rules.imprison(hunter_id, prison_id)


## Gọi mỗi physics frame khi `rescuer_id` đang giữ E đỡ `target_id` đang gục.
func server_channel_rescue(rescuer_id: int, target_id: int, delta: float) -> bool:
	return _can_mutate() and rules.channel_rescue(rescuer_id, target_id, delta)


## Người chơi bấm nút ô thẻ `slot`. Core gọi (Match), module không cần gọi.
## Hỏi hiệu ứng (Items) có dùng được không, trả tiền, rồi chạy hiệu ứng.
func server_use_item(user: EntityBase, slot: int) -> bool:
	if not _can_mutate() or not rules.can_use_item(user.peer_id, slot):
		return false
	var type: int = rules.record(user.peer_id).deck[slot]
	var effect: ItemEffect = _effects.get(type)
	if effect == null:
		return false
	var plan := effect.plan(user)
	if plan.is_empty():
		return false
	if not rules.use_item(user.peer_id, slot, plan.get("target_id", 0), plan.get("target_pos", user.global_position)):
		return false
	effect.server_apply(user, plan)
	return true


## Thợ săn bắt đầu tụ lực dịch chuyển (Items gọi). Điểm tới được kẹp trong
## bản đồ, tránh tường và nhà tù; không tìm được chỗ đứng thì không dịch chuyển.
func server_start_teleport(id: int, target: Vector3) -> bool:
	if not _can_mutate() or not target.is_finite():
		return false
	var spot: Variant = find_standing_spot(target)
	return spot != null and rules.start_teleport(id, spot)


## Điểm đứng được gần `target` nhất (trong 3 m), null nếu không có. Chỉ server dùng.
func find_standing_spot(target: Vector3) -> Variant:
	var map := get_tree().get_first_node_in_group(GameTypes.GROUP_MAP) as MapBase
	if map == null:
		return null
	var bounds := map.get_bounds().grow(-TELEPORT_CLEARANCE)
	var space := map.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = TELEPORT_CLEARANCE
	query.shape = shape
	query.collision_mask = 1 # tường, vật cản
	var prisons := _prison_points()
	for ring in 7: # thử chính điểm đó rồi các vòng 0.5 m, 1 m... ra xa dần
		var steps := 1 if ring == 0 else 8
		for k in steps:
			var off := Vector2(ring * 0.5, 0).rotated(TAU * k / steps)
			var p := Vector2(clampf(target.x + off.x, bounds.position.x, bounds.end.x),
				clampf(target.z + off.y, bounds.position.y, bounds.end.y))
			if _near_prison(p, prisons):
				continue
			query.transform = Transform3D(Basis(), Vector3(p.x, 1.0, p.y))
			if space.intersect_shape(query, 1).is_empty():
				return Vector3(p.x, 0.05, p.y)
	return null


## Vị trí (x, z) các nhà tù, lấy một lần cho mỗi lần tìm chỗ đứng.
func _prison_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for node in get_tree().get_nodes_in_group(GameTypes.GROUP_PRISONS):
		var c := (node as Node3D).global_position
		points.append(Vector2(c.x, c.z))
	return points


func _near_prison(p: Vector2, prisons: PackedVector2Array) -> bool:
	for c in prisons:
		if p.distance_to(c) < PRISON_KEEP_OUT:
			return true
	return false


## Điểm người chơi `id` chọn trên minimap (null nếu chưa chọn). Chỉ server có.
func aim_point(id: int) -> Variant:
	return _aim_points.get(id)


## Máy người chơi gọi khi chạm minimap. Bot (trên server) gọi server_set_aim_point.
func set_aim_point(point: Vector3) -> void:
	if multiplayer.is_server():
		server_set_aim_point(multiplayer.get_unique_id(), point)
	else:
		_submit_aim_point.rpc_id(1, point)


func server_set_aim_point(id: int, point: Vector3) -> void:
	if rules == null or not rules.players.has(id) or not multiplayer.is_server() or not point.is_finite():
		return
	var map := get_tree().get_first_node_in_group(GameTypes.GROUP_MAP) as MapBase
	var b := map.get_bounds() if map else Rect2(-500, -500, 1000, 1000)
	_aim_points[id] = Vector3(clampf(point.x, b.position.x, b.end.x), 0.0, clampf(point.z, b.position.y, b.end.y))


@rpc("any_peer", "reliable")
func _submit_aim_point(point: Vector3) -> void:
	server_set_aim_point(multiplayer.get_remote_sender_id(), point) # chỉ đặt được cho chính mình


## Radar của `viewer_id`: gửi dấu chân người trốn trong footprint_history giây
## gần nhất, CHỈ tới máy người đó (máy khác không biết, đỡ băng thông).
func server_reveal_footprints(viewer_id: int, seconds: float) -> bool:
	if not _can_mutate():
		return false
	if GameTypes.is_bot_id(viewer_id):
		return true # bot vốn đọc được vị trí, không cần gửi
	var points := PackedVector3Array()
	for id: int in _footprints:
		if not GameTypes.is_active(rules.state_of(id)) and rules.state_of(id) != GameTypes.PlayerState.DOWNED:
			continue
		for f: Vector3 in _footprints[id]:
			points.append(Vector3(f.x, rules.elapsed - f.y, f.z))
	if viewer_id == multiplayer.get_unique_id():
		_reveal(points, seconds)
	elif viewer_id in multiplayer.get_peers():
		_reveal.rpc_id(viewer_id, points, seconds)
	return true


func _record_footprints(entities: Array) -> void:
	var keep := ceili(rules.config.footprint_history / maxf(rules.config.footprint_interval, 0.05))
	for e: EntityBase in entities:
		if e.is_hunter() or e.is_out():
			continue
		var trail: Array = _footprints.get(e.peer_id, [])
		trail.append(Vector3(e.global_position.x, rules.elapsed, e.global_position.z))
		if trail.size() > keep:
			trail.pop_front()
		_footprints[e.peer_id] = trail


@rpc("authority", "reliable")
func _reveal(points: PackedVector3Array, seconds: float) -> void:
	EventBus.footprints_revealed.emit(points, seconds)


## Túi máu của `healer_id` trúng `target_id` (Items gọi khi túi tới nơi).
func server_heal(healer_id: int, target_id: int) -> bool:
	return _can_mutate() and rules.heal(healer_id, target_id)


func server_speed_boost(id: int, seconds: float, factor: float) -> bool:
	return _can_mutate() and rules.speed_boost(id, seconds, factor)


## Đặt bẫy / đệm lò xo / hộp gỗ. Trả về id vật thể (0 = không đặt được).
func server_place(type: GameTypes.ItemType, pos: Vector3, yaw: float, owner_id: int, lifetime: float) -> int:
	if not _can_mutate() or not pos.is_finite() or not is_finite(yaw):
		return 0
	return rules.place(type, pos, yaw, owner_id, lifetime)


func server_remove_placed(obj_id: int) -> bool:
	return _can_mutate() and rules.remove_placed(obj_id)


func server_stun(id: int, seconds: float) -> bool:
	return _can_mutate() and rules.stun(id, seconds)


func server_escape(id: int) -> bool:
	return _can_mutate() and rules.escape(id)


## Người trốn đang đứng ở rương: gọi mỗi physics frame.
func server_channel_chest(id: int, safe_id: int, delta: float) -> bool:
	return _can_mutate() and rules.channel_chest(id, safe_id, delta)


## Người chơi bấm nút trong lúc vòng căn đang chạy.
func server_resolve_qte(id: int) -> GameTypes.QteResult:
	if not _can_mutate():
		return GameTypes.QteResult.NONE
	# Kim trên máy client vẽ chậm một chiều trễ (gói đồng bộ giờ đã cũ), rồi nút
	# đi từ client lên mất thêm một chiều trễ + nửa nhịp gửi input. Luật kẹp tối đa qte_grace.
	var lag := 2.0 * Net.latency_of(id)
	if lag > 0.0:
		lag += INPUT_SEND_HALF_INTERVAL
	return rules.resolve_qte(id, lag)


func server_take_coin(id: int, coin_id: int) -> bool:
	return _can_mutate() and rules.take_coin(id, coin_id)


func _can_mutate() -> bool:
	return multiplayer.is_server() and rules != null and rules.is_playing()


func _is_significant(old: Dictionary, new: Dictionary) -> bool:
	if old.is_empty():
		return true
	for key: String in new:
		if _CONTINUOUS_KEYS.has(key):
			continue
		if old.get(key) != new[key]:
			return true
	# Tiến độ cứu về 0 hoặc đầy cũng gửi ngay.
	return new["rescue_progress"] != old["rescue_progress"] and (new["rescue_progress"] == 0.0 or new["rescue_progress"] >= 1.0)


## Rương xong, về 0, cổng, tiền, vật đặt, đạn: gửi ngay; tiến độ rương bình thường gửi 10 lần/giây.
func _world_significant(old: Dictionary, new: Dictionary) -> bool:
	if old.is_empty() or old["gate_open"] != new["gate_open"] or old["gate_opening"] != new["gate_opening"]:
		return true
	if old["coins_taken"].size() != new["coins_taken"].size() or old["placed"].size() != new["placed"].size() \
			or old["shots"].keys() != new["shots"].keys():
		return true
	for safe_id: int in new["safes"]:
		var a: float = old["safes"].get(safe_id, 0.0)
		var b: float = new["safes"][safe_id]
		if b < a or (b >= 1.0 and a < 1.0):
			return true
	return false


func _on_player_left(id: int) -> void:
	if not multiplayer.is_server() or rules == null or not rules.players.has(id):
		return
	if rules.state == GameTypes.MatchState.ENDED:
		return
	rules.remove_player(id)
	flush(0.0) # thợ săn rời trận thì flush thấy is_over() và kết thúc


# ---------- Server -> mọi máy ----------

@rpc("authority", "call_local", "reliable")
func _sync_players(batch: Dictionary) -> void:
	if rules == null:
		return
	var server := multiplayer.is_server()
	for id: int in batch:
		if not rules.players.has(id):
			continue
		var d := PlayerRecord.apply_diff(_applied.get(id, {}), batch[id])
		if not server:
			rules.players[id].apply_dict(d)
		var events := PlayerRecord.events_between(id, _applied.get(id, {}), d)
		_applied[id] = d
		for e: Dictionary in events:
			EventBus.emit_signal.callv([e["signal"]] + e["args"])
			if e["signal"] == &"player_state_changed":
				_log("%s: %s -> %s" % [rules.names.get(id, id), GameTypes.PlayerState.keys()[e["args"][1]], GameTypes.PlayerState.keys()[e["args"][2]]])


@rpc("authority", "call_local", "reliable")
func _sync_world(changes: Dictionary) -> void:
	if rules == null:
		return
	var w := WorldRecord.apply_diff(_world_applied, changes)
	if not multiplayer.is_server():
		rules.apply_world_dict(w)
	var events := WorldRecord.events_between(_world_applied, w, rules.safes_required())
	_world_applied = w
	for e: Dictionary in events:
		EventBus.emit_signal.callv([e["signal"]] + e["args"])
		match e["signal"]:
			&"safe_unlocked":
				_log("Mở rương %d (%d/%d chìa)" % e["args"])
			&"gate_opening":
				_log("Đủ chìa, 2 cổng đang mở")
			&"gate_opened":
				_log("Cổng thoát đã mở")


@rpc("authority", "unreliable_ordered")
func _sync_time(t: float) -> void:
	if rules:
		rules.time_left = t
		rules.elapsed = rules.config.duration - t


@rpc("authority", "call_local", "reliable")
func _apply_match_end(res: Dictionary) -> void:
	if rules == null or rules.state == GameTypes.MatchState.ENDED:
		return
	rules.finish(res)
	EventBus.match_state_changed.emit(rules.state)
	EventBus.match_ended.emit(res)
	_log("Hết trận: thợ săn %s, bắt %d/%d, thoát %d/%d" % [
		GameTypes.HunterResult.keys()[res["hunter_result"]], res["caught"], res["escapees"], res["escaped"], res["escapees"]])


func _log(msg: String) -> void:
	print("[%d] %s" % [multiplayer.get_unique_id(), msg])
