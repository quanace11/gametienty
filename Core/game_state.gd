extends Node
## Autoload "GameState": giữ MatchRules của trận hiện tại trên mọi máy.
##
## Chỉ server được đổi trạng thái trận, qua các hàm server_*(). Thay đổi được
## gửi xuống mọi client, áp vào MatchRules của từng máy rồi phát ra EventBus.
## Gọi server_*() trên client sẽ bị bỏ qua, nên module cứ gọi mà không lo.

const TIME_SYNC_INTERVAL := 0.5
const SAFE_PROGRESS_STEP := 0.05 # chỉ gửi tiến độ két khi đổi ít nhất 5%

var rules: MatchRules = null

var _time_sync_timer := 0.0


func _ready() -> void:
	Net.player_left.connect(_on_player_left)


func begin(info: Dictionary, total_safes: int) -> void:
	var cfg := MatchConfig.new()
	cfg.duration = info["time"]
	rules = MatchRules.new(cfg, info["roles"], info["names"], total_safes)
	_time_sync_timer = 0.0
	EventBus.match_state_changed.emit(rules.state)


func clear() -> void:
	rules = null


func my_role() -> int:
	if rules == null:
		return -1
	return rules.roles.get(multiplayer.get_unique_id(), -1)


## Match gọi mỗi physics frame trên mọi máy.
func tick(delta: float) -> void:
	if rules == null:
		return
	var before := rules.state
	rules.tick(delta)
	if rules.state != before:
		EventBus.match_state_changed.emit(rules.state)
	if not multiplayer.is_server() or not rules.is_playing():
		return
	_time_sync_timer -= delta
	if _time_sync_timer <= 0.0:
		_time_sync_timer = TIME_SYNC_INTERVAL
		_sync_time.rpc(rules.time_left)
	var w := rules.evaluate()
	if w != GameTypes.Winner.NONE:
		_end(w)


# ---------- API cho server ----------

func server_set_player_state(id: int, s: GameTypes.PlayerState) -> void:
	if _can_mutate() and rules.player_states.has(id) and rules.player_states[id] != s:
		_apply_player_state.rpc(id, s)


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


func _end(w: GameTypes.Winner) -> void:
	var summary := rules.summary()
	summary["winner"] = w
	_apply_match_end.rpc(w, summary)


func _on_player_left(id: int) -> void:
	if not multiplayer.is_server() or rules == null or not rules.roles.has(id):
		return
	if rules.state == GameTypes.MatchState.ENDED:
		return
	if rules.roles[id] == GameTypes.Role.HUNTER:
		_end(GameTypes.Winner.ESCAPEES)
	elif not GameTypes.is_out(rules.player_states[id]):
		_apply_player_state.rpc(id, GameTypes.PlayerState.IMPRISONED)


# ---------- Server -> mọi máy ----------

@rpc("authority", "call_local", "reliable")
func _apply_player_state(id: int, s: int) -> void:
	if rules == null or not rules.player_states.has(id):
		return
	var old: int = rules.player_states[id]
	if not rules.set_player_state(id, s):
		return
	EventBus.player_state_changed.emit(id, old, s)
	match s:
		GameTypes.PlayerState.DOWNED:
			EventBus.player_downed.emit(id)
		GameTypes.PlayerState.IMPRISONED:
			EventBus.player_imprisoned.emit(id)
		GameTypes.PlayerState.ESCAPED:
			EventBus.player_escaped.emit(id)
		GameTypes.PlayerState.IDLE, GameTypes.PlayerState.RUNNING:
			if old == GameTypes.PlayerState.DOWNED or old == GameTypes.PlayerState.IMPRISONED:
				EventBus.player_rescued.emit(id)
	_log("%s: %s -> %s" % [rules.names.get(id, id), GameTypes.PlayerState.keys()[old], GameTypes.PlayerState.keys()[s]])


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
