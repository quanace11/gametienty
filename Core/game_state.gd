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
const PROGRESS_SYNC_INTERVAL := 0.1 ## tiến độ cứu, máu trong tù chỉ gửi 10 lần/giây
## Các trường đổi liên tục; chỉ đổi những trường này thì gửi thưa hơn.
const _CONTINUOUS_KEYS := ["rescue_progress", "prison_time_left", "invulnerable_left", "attack_cooldown_left", "stunned_left", "chest_work",
	"item_cooldowns", "speed_boost_left"]

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


## Túi máu của `healer_id` trúng `target_id` (Items gọi khi túi tới nơi).
func server_heal(healer_id: int, target_id: int) -> bool:
	return _can_mutate() and rules.heal(healer_id, target_id)


func server_speed_boost(id: int, seconds: float, factor: float) -> bool:
	return _can_mutate() and rules.speed_boost(id, seconds, factor)


## Đặt bẫy / đệm lò xo / hộp gỗ. Trả về id vật thể (0 = không đặt được).
func server_place(type: GameTypes.ItemType, pos: Vector3, yaw: float, owner_id: int, lifetime: float) -> int:
	if not _can_mutate():
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
	# Nút đi từ client lên mất một chiều trễ + nửa nhịp gửi input.
	var lag := Net.latency_of(id)
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
		if key in _CONTINUOUS_KEYS:
			continue
		if old.get(key) != new[key]:
			return true
	# Tiến độ cứu về 0 hoặc đầy cũng gửi ngay.
	return new["rescue_progress"] != old["rescue_progress"] and (new["rescue_progress"] == 0.0 or new["rescue_progress"] >= 1.0)


## Rương xong, về 0, cổng, tiền: gửi ngay; tiến độ rương bình thường gửi 10 lần/giây.
func _world_significant(old: Dictionary, new: Dictionary) -> bool:
	if old.is_empty() or old["gate_open"] != new["gate_open"] or old["gate_opening"] != new["gate_opening"]:
		return true
	if old["coins_taken"].size() != new["coins_taken"].size() or old["placed"].size() != new["placed"].size():
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
