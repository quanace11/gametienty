class_name MatchRules
extends RefCounted
## Luật trận đấu, thuần logic: không dùng node, không dùng mạng.
## GameState giữ một bản trên mỗi máy; chỉ server quyết định thay đổi.

var config: MatchConfig
var state: GameTypes.MatchState = GameTypes.MatchState.COUNTDOWN
var countdown_left := 0.0
var time_left := 0.0
var roles := {} # id -> GameTypes.Role
var names := {} # id -> String
var player_states := {} # id -> GameTypes.PlayerState
var safe_progress := {} # safe_id -> 0.0..1.0
var gate_open := false
var winner: GameTypes.Winner = GameTypes.Winner.NONE


func _init(cfg: MatchConfig, p_roles: Dictionary, p_names: Dictionary, total_safes: int) -> void:
	config = cfg
	roles = p_roles
	names = p_names
	countdown_left = cfg.countdown
	time_left = cfg.duration
	for id: int in roles:
		player_states[id] = GameTypes.PlayerState.IDLE
	for i in total_safes:
		safe_progress[i] = 0.0


func is_playing() -> bool:
	return state == GameTypes.MatchState.PLAYING


func tick(delta: float) -> void:
	match state:
		GameTypes.MatchState.COUNTDOWN:
			countdown_left -= delta
			if countdown_left <= 0.0:
				state = GameTypes.MatchState.PLAYING
		GameTypes.MatchState.PLAYING:
			time_left = maxf(0.0, time_left - delta)


func set_player_state(id: int, s: GameTypes.PlayerState) -> bool:
	if not player_states.has(id) or player_states[id] == s:
		return false
	player_states[id] = s
	return true


## Trả về true nếu lần cập nhật này làm két mở xong.
func set_safe_progress(safe_id: int, p: float) -> bool:
	if not safe_progress.has(safe_id):
		return false
	var was_done: bool = safe_progress[safe_id] >= 1.0
	safe_progress[safe_id] = clampf(p, 0.0, 1.0)
	var done_now: bool = safe_progress[safe_id] >= 1.0 and not was_done
	if safes_unlocked() >= safes_required():
		gate_open = true
	return done_now


func total_safes() -> int:
	return safe_progress.size()


func safes_unlocked() -> int:
	var n := 0
	for p: float in safe_progress.values():
		if p >= 1.0:
			n += 1
	return n


func safes_required() -> int:
	return mini(config.safes_required, total_safes())


func escapee_ids() -> Array:
	return roles.keys().filter(func(id: int) -> bool: return roles[id] == GameTypes.Role.ESCAPEE)


func hunter_id() -> int:
	for id: int in roles:
		if roles[id] == GameTypes.Role.HUNTER:
			return id
	return 0


func count_escapees(s: GameTypes.PlayerState) -> int:
	return escapee_ids().filter(func(id: int) -> bool: return player_states[id] == s).size()


func active_escapees() -> int:
	return escapee_ids().filter(func(id: int) -> bool: return not GameTypes.is_out(player_states[id])).size()


func escapees_to_win() -> int:
	var total := escapee_ids().size()
	if config.escapees_to_win > 0:
		return mini(config.escapees_to_win, total)
	return ceili(total / 2.0)


## NONE nếu trận chưa kết thúc. Trận kết thúc khi không còn người trốn nào
## đang chạy (bị nhốt hết hoặc đã thoát) hoặc hết giờ.
func evaluate() -> GameTypes.Winner:
	if state != GameTypes.MatchState.PLAYING:
		return GameTypes.Winner.NONE
	if active_escapees() > 0 and time_left > 0.0:
		return GameTypes.Winner.NONE
	if count_escapees(GameTypes.PlayerState.ESCAPED) >= escapees_to_win():
		return GameTypes.Winner.ESCAPEES
	return GameTypes.Winner.HUNTER


func finish(w: GameTypes.Winner) -> void:
	winner = w
	state = GameTypes.MatchState.ENDED


func summary() -> Dictionary:
	return {
		"escapees": escapee_ids().size(),
		"escaped": count_escapees(GameTypes.PlayerState.ESCAPED),
		"imprisoned": count_escapees(GameTypes.PlayerState.IMPRISONED),
		"safes_unlocked": safes_unlocked(),
		"time_left": time_left,
	}
