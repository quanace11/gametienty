extends Node
## Autoload "GameState": cổng duy nhất để đổi trạng thái trận.
##
## Mô hình: server giữ bản gốc (MatchRules), module gọi lệnh server_*(),
## lệnh hợp lệ thì MatchRules đổi dữ liệu và đánh dấu người chơi bị đổi.
## Cuối mỗi physics frame, flush() gửi những trường đã đổi của những người đó
## (PlayerRecord.diff, kênh reliable có thứ tự) xuống từng máy, và áp luôn cho
## chính server. Mỗi máy dựng lại bản đầy đủ, so bản cũ với bản mới để tự sinh
## sự kiện EventBus. Vì gửi trạng thái chứ không gửi lệnh, client không bao giờ
## lệch dù gói tin bị gộp; offline đi đúng đường này.
##
## Ẩn thông tin: mỗi máy nhận một bản riêng (_views) đã lọc theo người ngồi
## máy đó (_view_of). Phe kia không nhận bộ bài, tiền, vòng căn của mình; thẻ
## dùng ở chỗ họ không thấy (trong bụi) thì họ không biết; vật đặt trong bụi
## chỉ hiện khi họ thấy được chỗ đó. Máy chỉ được nhận dữ liệu sau khi báo đã
## dựng xong trận (server_peer_ready), nhận nguyên phần đã đổi từ đầu trận,
## nên máy vào lại giữa trận dùng chung đường này.
##
## Gọi server_*() trên client sẽ bị bỏ qua (trả về false), nên module cứ gọi.

const TIME_SYNC_INTERVAL := 0.5
const INPUT_SEND_HALF_INTERVAL := 1.0 / 60.0 ## client gửi input 30 lần/giây: trung bình trễ thêm nửa nhịp
const PRESS_TIME_TOLERANCE := 0.04 ## giây: giờ bấm client ghi được lệch tối đa chừng này so với ước tính của server
const HIT_PADDING := 0.3 ## mét, cộng vào bán kính đạn cho bằng thân người
const SHOT_HEIGHT := 1.1 ## mét, đạn bay ngang tầm ngực
const TELEPORT_CLEARANCE := 0.45 ## mét, bán kính khoảng trống cần có ở điểm dịch chuyển tới
const PRISON_KEEP_OUT := 2.8 ## mét từ giữa nhà tù: không dịch chuyển vào trong tường
const PROGRESS_SYNC_INTERVAL := 0.1 ## tiến độ cứu, máu trong tù chỉ gửi 10 lần/giây
## Các trường đổi liên tục; chỉ đổi những trường này thì gửi thưa hơn (Dictionary để tra O(1)).
const _CONTINUOUS_KEYS := {"rescue_progress": true, "prison_time_left": true, "invulnerable_left": true, "attack_cooldown_left": true,
	"stunned_left": true, "chest_work": true, "item_cooldowns": true, "speed_boost_left": true}

## Trường của người khác phe mà máy mình không được nhận (luôn giữ giá trị đầu trận).
const _ENEMY_PRIVATE := ["deck", "item_cooldowns", "coins", "coins_earned", "chest_work", "qte_chest", "qte_started", "qte_zone"]
## Trường mô tả lần dùng thẻ gần nhất: phe kia chỉ nhận khi thấy người dùng hoặc thấy chỗ thẻ rơi.
const _ITEM_KEYS := ["item_seq", "item_last_type", "item_target_id", "item_target_pos"]

var rules: MatchRules = null

var _time_sync_timer := 0.0
var _progress_sync_timer := 0.0
var _pending := {} # chỉ server: id -> true, người chơi có dữ liệu chưa gửi
var _cur := {} # chỉ server: id -> dict đã chốt lần cuối (bản gốc, chưa lọc)
var _applied := {} # mọi máy: id -> dict đã áp dụng lần cuối (để sinh sự kiện)
var _initial := {} # chỉ server: id -> dict lúc vào trận (máy mới nhận phần đổi so với bản này)
var _world_pending := false # chỉ server
var _world_cur := {} # chỉ server
var _world_initial := {} # chỉ server
var _world_applied := {} # mọi máy
var _views := {} # chỉ server: peer -> {"seat", "players": {id: dict}, "world": dict, "hidden_items": {id: seq}, "seen": {obj_id: true}}
var _effects := {} # ItemType -> ItemEffect (chỉ server dùng)
var _footprint_timer := 0.0
var _bushes: Array[Vector3] = [] # mọi máy: bụi cây của bản đồ (x, z, bán kính)
var _bushes_loaded := false


func _ready() -> void:
	Net.player_left.connect(_on_player_left)
	Net.player_returned.connect(_on_player_returned)


func begin(info: Dictionary, total_safes: int, floor_coins: int = 0) -> void:
	var cfg := MatchConfig.from_array(info.get("config", []))
	cfg.duration = info["time"]
	rules = MatchRules.new(cfg, info["roles"], info["names"], total_safes, floor_coins)
	if info.has("seed"):
		rules.rng.seed = info["seed"]
	_setup_items(info.get("decks", {}))
	_time_sync_timer = 0.0
	_progress_sync_timer = 0.0
	_pending.clear()
	_cur.clear()
	_applied.clear()
	_initial.clear()
	_views.clear()
	for id: int in rules.players:
		_applied[id] = rules.players[id].to_dict()
		_cur[id] = _applied[id]
		_initial[id] = _applied[id]
	_world_pending = false
	_footprint_timer = 0.0
	_bushes = [] # gán mới, không clear(): mảng bản đồ trả về có thể là hằng chỉ đọc
	_bushes_loaded = false
	_world_applied = rules.world_dict()
	_world_cur = _world_applied
	_world_initial = _world_applied
	if multiplayer.is_server():
		_log("Trận %s, hạt giống random %d, %d thông số" % [info.get("match_id", "-"), info.get("seed", 0), info.get("config", []).size()])
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
	return rules.roles.get(my_id(), -1)


## Số ghế (id nhân vật) của người ngồi máy này. UI dùng hàm này, không dùng
## multiplayer.get_unique_id(): vào lại giữa trận thì peer id đổi, ghế thì không.
func my_id() -> int:
	return Net.my_seat()


## Match gọi đầu mỗi physics frame trên mọi máy.
func tick(delta: float) -> void:
	if rules == null:
		return
	var before := rules.state
	var server := multiplayer.is_server()
	rules.tick(delta, server)
	if rules.state != before:
		EventBus.match_state_changed.emit(rules.state)
		if server:
			_log("Giai đoạn trận: %s" % GameTypes.MatchState.keys()[rules.state])
	if not server or rules.state == GameTypes.MatchState.ENDED:
		return
	_time_sync_timer -= delta
	if _time_sync_timer <= 0.0:
		_time_sync_timer = TIME_SYNC_INTERVAL
		for peer: int in _views:
			_sync_clock.rpc_id(peer, rules.state, rules.countdown_left, rules.time_left)


## Chỉ server (Match gọi): mọi máy đã dựng xong trận hoặc hết hạn chờ.
func server_start_countdown() -> void:
	if rules == null or not multiplayer.is_server() or rules.state != GameTypes.MatchState.LOADING:
		return
	rules.start_countdown()
	EventBus.match_state_changed.emit(rules.state)
	_log("Giai đoạn trận: COUNTDOWN")
	for peer: int in _views:
		_sync_clock_now.rpc_id(peer, rules.state, rules.countdown_left, rules.time_left)


## Chỉ server (Match gọi): máy `peer` đã dựng xong trận, từ giờ được nhận dữ
## liệu. Gửi ngay mọi thứ đã đổi từ đầu trận (máy vào lại cũng vậy), đã lọc.
func server_peer_ready(peer: int) -> void:
	if rules == null or not multiplayer.is_server() or _views.has(peer):
		return
	var view := {"seat": Net.seat_of(peer), "players": {}, "world": _world_initial, "hidden_items": {}, "seen": {}}
	for id: int in _initial:
		view["players"][id] = _initial[id]
	_views[peer] = view
	_sync_clock_now.rpc_id(peer, rules.state, rules.countdown_left, rules.time_left)
	_send_players_to(peer, view, _cur.keys())
	_send_world_to(peer, view)


## Chỉ server: máy `peer` rời trận, thôi gửi.
func server_peer_gone(peer: int) -> void:
	_views.erase(peer)


## Chỉ server: các máy đang nhận dữ liệu trận.
func ready_peers() -> Array:
	return _views.keys()


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
	var changed := []
	for id: int in _pending.keys():
		var d: Dictionary = rules.players[id].to_dict()
		# Chỉ số đổi liên tục (hồi chiêu, tiến độ...) thì đợi nhịp 10 lần/giây.
		if not send_continuous and not _is_significant(_cur[id], d):
			continue
		_pending.erase(id)
		if d != _cur[id]:
			_cur[id] = d
			changed.append(id)
	if not changed.is_empty():
		var batch := {}
		for id: int in changed:
			batch[id] = PlayerRecord.diff(_applied[id], _cur[id])
		_apply_players(batch)
		for peer: int in _views:
			_send_players_to(peer, _views[peer], changed)
	if rules.take_world_dirty():
		_world_pending = true
	if _world_pending:
		var w := rules.world_dict()
		if send_continuous or _world_significant(_world_cur, w):
			_world_cur = w
			_world_pending = false
			_apply_world(WorldRecord.diff(_world_applied, w))
			for peer: int in _views:
				_send_world_to(peer, _views[peer])
	elif send_continuous:
		for peer: int in _views: # vật đặt chưa thấy: xem giờ đã thấy chưa
			if _views[peer]["world"]["placed"].size() < _world_cur["placed"].size():
				_send_world_to(peer, _views[peer])
	if rules.is_over():
		_apply_match_end.rpc(rules.results())


# ---------- Lọc theo người xem ----------

## Bản PlayerRecord của `id` mà người ngồi ghế `viewer` được biết. `prev` là bản máy đó đang có.
func _view_of(viewer: int, view: Dictionary, id: int, d: Dictionary, prev: Dictionary) -> Dictionary:
	if viewer == id or rules.roles.get(viewer, -1) == rules.roles.get(id, -2):
		return d # chính mình, đồng đội: biết hết
	var v := d.duplicate() # nông: chỉ thay vài trường, không sửa mảng bên trong
	for key: String in _ENEMY_PRIVATE:
		v[key] = prev[key]
	if d["item_seq"] != prev["item_seq"]:
		var hidden: Dictionary = view["hidden_items"]
		if hidden.get(id, -1) == d["item_seq"] or not (can_see(viewer, id) or can_see_point(viewer, d["item_target_pos"])):
			hidden[id] = d["item_seq"] # lần dùng thẻ này máy đó không bao giờ biết
			for key: String in _ITEM_KEYS:
				v[key] = prev[key]
	return v


func _send_players_to(peer: int, view: Dictionary, ids: Array) -> void:
	var batch := {}
	var seen: Dictionary = view["players"]
	for id: int in ids:
		var v := _view_of(view["seat"], view, id, _cur[id], seen[id])
		var changes := PlayerRecord.diff(seen[id], v)
		if not changes.is_empty():
			batch[id] = changes
			seen[id] = v
	if not batch.is_empty():
		_sync_players.rpc_id(peer, batch)


## Thế giới mà máy `peer` được biết: vật đặt của phe kia chỉ có khi đã thấy chỗ đặt.
func _send_world_to(peer: int, view: Dictionary) -> void:
	var w := _world_cur
	var viewer: int = view["seat"]
	var seen_objs: Dictionary = view["seen"]
	var placed := {}
	var filtered := false
	for obj_id: int in w["placed"]:
		var o: Dictionary = w["placed"][obj_id]
		if seen_objs.has(obj_id) or rules.roles.get(o["owner"], -1) == rules.roles.get(viewer, -2) or can_see_point(viewer, o["pos"]):
			seen_objs[obj_id] = true
			placed[obj_id] = o
		else:
			filtered = true
	if filtered:
		w = w.duplicate()
		w["placed"] = placed
	var changes := WorldRecord.diff(view["world"], w)
	if not changes.is_empty():
		view["world"] = w
		_sync_world.rpc_id(peer, changes)


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
		rules.bush_of[e.peer_id] = bush_at(e.global_position)
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
	var bush: int = rules.bush_of.get(target_id, -1)
	if bush < 0 or rules.roles.get(viewer_id, -1) == rules.roles.get(target_id, -2):
		return true
	return rules.bush_of.get(viewer_id, -1) == bush


## Chỉ server: người `viewer_id` có thấy điểm `pos` trên sàn không (trong bụi
## cây thì chỉ người đứng cùng bụi mới thấy).
func can_see_point(viewer_id: int, pos: Vector3) -> bool:
	var bush := bush_at(pos)
	return bush < 0 or rules.bush_of.get(viewer_id, -1) == bush


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
		var t_prev: float = rules.shot_progress.get(shot_id, 0.0)
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
			rules.shot_progress.erase(shot_id)
			rules.land_shot(shot_id, [first_id] if first_id != 0 else [])
		else:
			rules.shot_progress[shot_id] = t_now


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
	return rules.aim_points.get(id)


## Máy người chơi gọi khi chạm minimap. Bot (trên server) gọi server_set_aim_point.
func set_aim_point(point: Vector3) -> void:
	if multiplayer.is_server():
		server_set_aim_point(my_id(), point)
	else:
		_submit_aim_point.rpc_id(1, point)


func server_set_aim_point(id: int, point: Vector3) -> void:
	if rules == null or not rules.players.has(id) or not multiplayer.is_server() or not point.is_finite():
		return
	var map := get_tree().get_first_node_in_group(GameTypes.GROUP_MAP) as MapBase
	var b := map.get_bounds() if map else Rect2(-500, -500, 1000, 1000)
	rules.aim_points[id] = Vector3(clampf(point.x, b.position.x, b.end.x), 0.0, clampf(point.z, b.position.y, b.end.y))


@rpc("any_peer", "reliable")
func _submit_aim_point(point: Vector3) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and Net.allow(peer, &"aim_point"):
		server_set_aim_point(Net.seat_of(peer), point) # chỉ đặt được cho chính mình


## Radar của `viewer_id`: gửi dấu chân người trốn trong footprint_history giây
## gần nhất, CHỈ tới máy người đó (máy khác không biết, đỡ băng thông).
func server_reveal_footprints(viewer_id: int, seconds: float) -> bool:
	if not _can_mutate():
		return false
	if GameTypes.is_bot_id(viewer_id):
		return true # bot vốn đọc được vị trí, không cần gửi
	var points := PackedVector3Array()
	for id: int in rules.footprints:
		if not GameTypes.is_active(rules.state_of(id)) and rules.state_of(id) != GameTypes.PlayerState.DOWNED:
			continue
		for f: Vector3 in rules.footprints[id]:
			points.append(Vector3(f.x, rules.elapsed - f.y, f.z))
	var peer := Net.peer_of(viewer_id)
	if peer == multiplayer.get_unique_id():
		_reveal(points, seconds)
	elif peer != 0 and _views.has(peer):
		_reveal.rpc_id(peer, points, seconds)
	return true


func _record_footprints(entities: Array) -> void:
	var keep := ceili(rules.config.footprint_history / maxf(rules.config.footprint_interval, 0.05))
	for e: EntityBase in entities:
		if e.is_hunter() or e.is_out():
			continue
		var trail: Array = rules.footprints.get(e.peer_id, [])
		trail.append(Vector3(e.global_position.x, rules.elapsed, e.global_position.z))
		if trail.size() > keep:
			trail.pop_front()
		rules.footprints[e.peer_id] = trail


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


## Người chơi bấm nút trong lúc vòng căn đang chạy. `press_time`: lúc bấm theo
## đồng hồ trận của máy người chơi (EntityBase.press_time), < 0 nếu không có.
func server_resolve_qte(id: int, press_time: float = -1.0) -> GameTypes.QteResult:
	if not _can_mutate():
		return GameTypes.QteResult.NONE
	# Đồng hồ trận trên client đã trừ trễ (_apply_clock) nên kim vẽ đúng giờ
	# server; nút đi từ client lên mất một chiều trễ + nửa nhịp gửi input. Luật kẹp tối đa qte_grace.
	var lag := Net.latency_of(id)
	if lag > 0.0:
		lag += INPUT_SEND_HALF_INTERVAL
	# Có giờ bấm do client ghi thì chấm theo đó, nhưng chỉ tin trong khoảng
	# PRESS_TIME_TOLERANCE quanh ước tính của server: gian lận "lùi giờ" tối đa chừng đó.
	if press_time >= 0.0 and lag > 0.0:
		var claimed := rules.elapsed - press_time
		lag = clampf(claimed, lag - PRESS_TIME_TOLERANCE, lag + PRESS_TIME_TOLERANCE)
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


## Máy của ghế `id` rớt mạng: bot chơi thay (Match đổi nguồn lệnh), nhân vật giữ nguyên.
func _on_player_left(id: int) -> void:
	if not multiplayer.is_server() or rules == null or not rules.players.has(id):
		return
	rules.set_away(id, true)


func _on_player_returned(id: int) -> void:
	if multiplayer.is_server() and rules != null and rules.players.has(id):
		rules.set_away(id, false)


# ---------- Server -> mọi máy ----------

@rpc("authority", "reliable")
func _sync_players(batch: Dictionary) -> void:
	_apply_players(batch)


func _apply_players(batch: Dictionary) -> void:
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


@rpc("authority", "reliable")
func _sync_world(changes: Dictionary) -> void:
	_apply_world(changes)


func _apply_world(changes: Dictionary) -> void:
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
func _sync_clock(state: int, countdown_left: float, time_left: float) -> void:
	_apply_clock(state, countdown_left, time_left)


## Lúc bắt đầu đếm ngược / máy vừa vào: gửi chắc chắn tới.
@rpc("authority", "reliable")
func _sync_clock_now(state: int, countdown_left: float, time_left: float) -> void:
	_apply_clock(state, countdown_left, time_left)


## Client: đặt đồng hồ theo server, trừ đi độ trễ một chiều (gói đã cũ chừng đó).
## Mọi máy vào đếm ngược / vào trận cùng lúc với server, chênh nhau chỉ bằng sai số đo trễ.
func _apply_clock(state: int, countdown_left: float, time_left: float) -> void:
	if rules == null or multiplayer.is_server() or rules.state == GameTypes.MatchState.ENDED:
		return
	var lat := Net.server_latency()
	var before := rules.state
	if state == GameTypes.MatchState.COUNTDOWN and before == GameTypes.MatchState.LOADING:
		rules.state = GameTypes.MatchState.COUNTDOWN
	elif state == GameTypes.MatchState.PLAYING:
		rules.state = GameTypes.MatchState.PLAYING
	if rules.state == GameTypes.MatchState.COUNTDOWN:
		rules.countdown_left = countdown_left - lat
	elif rules.state == GameTypes.MatchState.PLAYING:
		rules.countdown_left = 0.0
		rules.time_left = maxf(0.0, time_left - lat)
		rules.elapsed = rules.config.duration - rules.time_left
	if rules.state != before:
		EventBus.match_state_changed.emit(rules.state)


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
	GameLog.info(msg)
