extends Node
## Autoload "GameState": cổng duy nhất để đổi trạng thái trận.
##
## Mô hình: server giữ bản gốc (MatchRules), module gọi lệnh server_*(),
## lệnh hợp lệ thì MatchRules đổi dữ liệu và đánh dấu người chơi bị đổi.
## Cuối mỗi physics frame, flush() gửi NGUYÊN bản dữ liệu của những người đó
## xuống mọi máy (kể cả chính server). Mỗi máy so bản cũ với bản mới để tự
## sinh sự kiện EventBus. Vì gửi trạng thái chứ không gửi lệnh, client không
## bao giờ lệch dù gói tin bị gộp; offline đi đúng đường này.
##
## Gọi server_*() trên client sẽ bị bỏ qua (trả về false), nên module cứ gọi.

const TIME_SYNC_INTERVAL := 0.5
const PROGRESS_SYNC_INTERVAL := 0.1 ## tiến độ cứu/vùng vẫy chỉ gửi 10 lần/giây
const SAFE_PROGRESS_STEP := 0.05 ## chỉ gửi tiến độ két khi đổi ít nhất 5%
## Các trường đổi liên tục; chỉ đổi những trường này thì gửi thưa hơn.
const _CONTINUOUS_KEYS := ["rescue_progress", "struggle", "prison_time_left", "invulnerable_left", "attack_cooldown_left", "stunned_left"]

var rules: MatchRules = null

var _time_sync_timer := 0.0
var _progress_sync_timer := 0.0
var _pending := {} # chỉ server: id -> true, người chơi có dữ liệu chưa gửi
var _sent := {} # chỉ server: id -> dict đã gửi lần cuối
var _applied := {} # mọi máy: id -> dict đã áp dụng lần cuối (để sinh sự kiện)


func _ready() -> void:
	Net.player_left.connect(_on_player_left)


func begin(info: Dictionary, total_safes: int) -> void:
	var cfg := MatchConfig.new()
	cfg.duration = info["time"]
	rules = MatchRules.new(cfg, info["roles"], info["names"], total_safes)
	_time_sync_timer = 0.0
	_progress_sync_timer = 0.0
	_pending.clear()
	_sent.clear()
	_applied.clear()
	for id: int in rules.players:
		_applied[id] = rules.players[id].to_dict()
		_sent[id] = _applied[id]
	EventBus.match_state_changed.emit(rules.state)


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
		if send_continuous or _is_significant(_sent.get(id, {}), d):
			batch[id] = d
			_sent[id] = d
			_pending.erase(id)
	if not batch.is_empty():
		_sync_players.rpc(batch)
	if rules.is_playing():
		var w := rules.evaluate()
		if w != GameTypes.Winner.NONE:
			_end(w)


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


## Gọi mỗi physics frame khi `rescuer_id` đang cứu `target_id` (đỡ dậy hoặc phá khóa).
func server_channel_rescue(rescuer_id: int, target_id: int, delta: float) -> bool:
	return _can_mutate() and rules.channel_rescue(rescuer_id, target_id, delta)


func server_add_struggle(target_id: int, amount: float) -> void:
	if _can_mutate():
		rules.add_struggle(target_id, amount)


func server_stun(id: int, seconds: float) -> bool:
	return _can_mutate() and rules.stun(id, seconds)


func server_escape(id: int) -> bool:
	return _can_mutate() and rules.escape(id)


func server_set_safe_progress(safe_id: int, progress: float) -> void:
	if not _can_mutate() or not rules.safe_progress.has(safe_id):
		return
	var old: float = rules.safe_progress[safe_id]
	if old >= 1.0:
		return
	if progress < 1.0 and absf(progress - old) < SAFE_PROGRESS_STEP:
		return
	_apply_safe_progress.rpc(safe_id, progress)


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


func _end(w: GameTypes.Winner) -> void:
	var summary := rules.summary()
	summary["winner"] = w
	_apply_match_end.rpc(w, summary)


func _on_player_left(id: int) -> void:
	if not multiplayer.is_server() or rules == null or not rules.players.has(id):
		return
	if rules.state == GameTypes.MatchState.ENDED:
		return
	var was_hunter := rules.remove_player(id)
	flush(0.0)
	if was_hunter:
		_end(GameTypes.Winner.ESCAPEES)


# ---------- Server -> mọi máy ----------

@rpc("authority", "call_local", "reliable")
func _sync_players(batch: Dictionary) -> void:
	if rules == null:
		return
	var server := multiplayer.is_server()
	for id: int in batch:
		var d: Dictionary = batch[id]
		if not rules.players.has(id):
			continue
		if not server:
			rules.players[id].apply_dict(d)
		var events := PlayerRecord.events_between(id, _applied.get(id, {}), d)
		_applied[id] = d
		for e: Dictionary in events:
			EventBus.emit_signal.callv([e["signal"]] + e["args"])
			if e["signal"] == &"player_state_changed":
				_log("%s: %s -> %s" % [rules.names.get(id, id), GameTypes.PlayerState.keys()[e["args"][1]], GameTypes.PlayerState.keys()[e["args"][2]]])


@rpc("authority", "call_local", "reliable")
func _apply_safe_progress(safe_id: int, progress: float) -> void:
	if rules == null:
		return
	var was_open := rules.gate_open
	var unlocked_now := rules.set_safe_progress(safe_id, progress)
	EventBus.safe_progress_changed.emit(safe_id, rules.safe_progress[safe_id])
	if unlocked_now:
		EventBus.safe_unlocked.emit(safe_id, rules.safes_unlocked(), rules.safes_required())
		_log("Mở két %d (%d/%d)" % [safe_id, rules.safes_unlocked(), rules.safes_required()])
	if rules.gate_open and not was_open:
		EventBus.gate_opened.emit()
		_log("Cổng thoát đã mở")


@rpc("authority", "unreliable_ordered")
func _sync_time(t: float) -> void:
	if rules:
		rules.time_left = t


@rpc("authority", "call_local", "reliable")
func _apply_match_end(w: int, summary: Dictionary) -> void:
	if rules == null or rules.state == GameTypes.MatchState.ENDED:
		return
	rules.finish(w)
	EventBus.match_state_changed.emit(rules.state)
	EventBus.match_ended.emit(w, summary)
	_log("Hết trận: %s thắng, %d/%d người trốn thoát" % [GameTypes.Winner.keys()[w], summary["escaped"], summary["escapees"]])


func _log(msg: String) -> void:
	print("[%d] %s" % [multiplayer.get_unique_id(), msg])
