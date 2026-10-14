class_name MatchRules
extends RefCounted
## Luật trận đấu, thuần logic: không dùng node, không dùng mạng.
## GameState giữ một bản trên mỗi máy; chỉ server gọi các lệnh (attack,
## pick_up, ...). Mỗi lệnh tự kiểm tra điều kiện và trả về false nếu không
## hợp lệ, nên module gọi sai lúc (gọi 2 lần, gọi khi đã bị nhốt...) cũng
## không làm hỏng trạng thái. Người chơi nào đổi dữ liệu thì được đánh dấu
## "dirty" để GameState gửi xuống client.

const RESCUE_CHANNEL_GRACE := 0.25 ## ngừng cứu chừng này giây thì hết trạng thái RESCUING

var config: MatchConfig
var state: GameTypes.MatchState = GameTypes.MatchState.COUNTDOWN
var countdown_left := 0.0
var time_left := 0.0
var roles := {} # id -> GameTypes.Role
var names := {} # id -> String
var players := {} # id -> PlayerRecord
var safe_progress := {} # safe_id -> 0.0..1.0
var gate_open := false
var winner: GameTypes.Winner = GameTypes.Winner.NONE

var _dirty := {} # id -> true


func _init(cfg: MatchConfig, p_roles: Dictionary, p_names: Dictionary, total_safes: int) -> void:
	config = cfg
	roles = p_roles
	names = p_names
	countdown_left = cfg.countdown
	time_left = cfg.duration
	for id: int in roles:
		var hp := 0 if roles[id] == GameTypes.Role.HUNTER else cfg.max_hp
		players[id] = PlayerRecord.new(id, roles[id], hp)
	for i in total_safes:
		safe_progress[i] = 0.0


# ---------- Đọc ----------

func is_playing() -> bool:
	return state == GameTypes.MatchState.PLAYING


func record(id: int) -> PlayerRecord:
	return players.get(id)


func state_of(id: int) -> GameTypes.PlayerState:
	return players[id].state if players.has(id) else GameTypes.PlayerState.ELIMINATED


## Có được tự di chuyển không (bị vác, bị nhốt, bị choáng thì không).
func can_move(id: int) -> bool:
	var p := record(id)
	if p == null or p.stunned_left > 0.0:
		return false
	return GameTypes.is_active(p.state) or p.state == GameTypes.PlayerState.DOWNED


## Hệ số nhân tốc độ chạy, 0 nếu không được đi.
func speed_factor(id: int) -> float:
	if not can_move(id):
		return 0.0
	var p := record(id)
	match p.state:
		GameTypes.PlayerState.DOWNED:
			return config.downed_speed
		GameTypes.PlayerState.RESCUING:
			return config.rescuing_speed
	if p.carrying_id != 0:
		return config.carrying_speed
	return 1.0


func can_attack(id: int) -> bool:
	var p := record(id)
	return p != null and p.is_hunter() and p.stunned_left <= 0.0 and p.attack_cooldown_left <= 0.0 \
		and p.carrying_id == 0 and is_playing()


func is_hittable(id: int) -> bool:
	var p := record(id)
	return p != null and not p.is_hunter() and GameTypes.is_active(p.state) and p.invulnerable_left <= 0.0


# ---------- Lệnh (server gọi qua GameState) ----------

## Thợ săn vung đòn. `targets` là những người trốn trong tầm đánh (module
## Player tự tính hitbox). Trả về true nếu đòn được vung (kể cả trượt).
func attack(attacker_id: int, targets: Array) -> bool:
	if not can_attack(attacker_id):
		return false
	var hunter := record(attacker_id)
	hunter.attack_cooldown_left = config.attack_cooldown
	hunter.attack_seq += 1
	_mark(attacker_id)
	for target_id: int in targets:
		if not is_hittable(target_id):
			continue
		var p := record(target_id)
		p.hp -= 1
		p.last_attacker_id = attacker_id
		p.invulnerable_left = config.hit_invulnerable_time
		if p.hp <= 0:
			p.hp = 0
			p.state = GameTypes.PlayerState.DOWNED
			p.rescue_progress = 0.0
		elif p.state == GameTypes.PlayerState.RESCUING:
			p.state = GameTypes.PlayerState.IDLE # bị đánh thì ngừng cứu
		_mark(target_id)
	return true


## Thợ săn nhấc người đang ngã lên vai.
func pick_up(hunter_id: int, target_id: int) -> bool:
	var hunter := record(hunter_id)
	var p := record(target_id)
	if hunter == null or p == null or not hunter.is_hunter() or not is_playing():
		return false
	if hunter.carrying_id != 0 or hunter.stunned_left > 0.0 or p.state != GameTypes.PlayerState.DOWNED:
		return false
	p.state = GameTypes.PlayerState.CARRIED
	p.carrier_id = hunter_id
	p.struggle = 0.0
	p.rescue_progress = 0.0
	hunter.carrying_id = target_id
	_mark(hunter_id)
	_mark(target_id)
	return true


## Thợ săn thả người đang vác xuống đất (vẫn nằm ngã).
func drop(hunter_id: int) -> bool:
	var hunter := record(hunter_id)
	if hunter == null or hunter.carrying_id == 0:
		return false
	var p := record(hunter.carrying_id)
	_detach(hunter, p)
	if p:
		p.state = GameTypes.PlayerState.DOWNED
		_mark(p.id)
	return true


## Thợ săn đưa người đang vác vào nhà tù `prison_id`.
func imprison(hunter_id: int, prison_id: int) -> bool:
	var hunter := record(hunter_id)
	if hunter == null or hunter.carrying_id == 0 or not is_playing():
		return false
	var p := record(hunter.carrying_id)
	_detach(hunter, p)
	p.imprison_count += 1
	p.rescue_progress = 0.0
	if p.imprison_count >= config.max_imprisonments:
		p.state = GameTypes.PlayerState.ELIMINATED
		p.prison_id = -1
	else:
		p.state = GameTypes.PlayerState.IMPRISONED
		p.prison_id = prison_id
		p.prison_time_left = config.prison_time
	_mark(p.id)
	return true


## Người trốn `rescuer_id` cứu `target_id` (đang ngã hoặc đang bị nhốt) thêm
## `delta` giây. Gọi mỗi physics frame khi đang giữ nút / đứng trong vùng.
## Nhiều người cứu cùng lúc thì cộng dồn. Trả về true nếu lần này cứu xong.
func channel_rescue(rescuer_id: int, target_id: int, delta: float) -> bool:
	var r := record(rescuer_id)
	var p := record(target_id)
	if r == null or p == null or r.is_hunter() or p.is_hunter() or rescuer_id == target_id:
		return false
	if not GameTypes.is_active(r.state) or r.stunned_left > 0.0 or not is_playing():
		return false
	var duration: float
	match p.state:
		GameTypes.PlayerState.DOWNED:
			duration = config.revive_time
		GameTypes.PlayerState.IMPRISONED:
			duration = config.prison_rescue_time
		_:
			return false

	r.channel_left = RESCUE_CHANNEL_GRACE
	if r.state != GameTypes.PlayerState.RESCUING:
		r.state = GameTypes.PlayerState.RESCUING
		_mark(rescuer_id)
	p.rescue_progress = minf(1.0, p.rescue_progress + delta / maxf(duration, 0.01))
	p.last_rescuer_id = rescuer_id
	_mark(target_id)
	if p.rescue_progress < 1.0:
		return false

	p.hp = config.revive_hp if p.state == GameTypes.PlayerState.DOWNED else p.max_hp
	p.state = GameTypes.PlayerState.IDLE
	p.rescue_progress = 0.0
	p.prison_id = -1
	p.invulnerable_left = config.hit_invulnerable_time
	return true


## Người bị vác vùng vẫy (ví dụ bấm liên tục). `amount` 0..1 cộng vào tiến độ.
## Không gọi thì tiến độ vẫn tự tăng theo thời gian (carry_escape_time).
func add_struggle(target_id: int, amount: float) -> void:
	var p := record(target_id)
	if p and p.state == GameTypes.PlayerState.CARRIED and is_playing():
		p.struggle = minf(1.0, p.struggle + maxf(amount, 0.0))
		_mark(target_id)


## Làm choáng (súng, bẫy...). Thợ săn đang vác mà bị choáng thì người bị vác thoát ra.
func stun(id: int, seconds: float) -> bool:
	var p := record(id)
	if p == null or seconds <= 0.0 or not is_playing() or GameTypes.is_out(p.state):
		return false
	p.stunned_left = maxf(p.stunned_left, seconds)
	_mark(id)
	if p.carrying_id != 0:
		_release(p)
	return true


## Người trốn bước qua cổng đã mở.
func escape(id: int) -> bool:
	var p := record(id)
	if p == null or p.is_hunter() or not gate_open or not GameTypes.is_active(p.state) or not is_playing():
		return false
	p.state = GameTypes.PlayerState.ESCAPED
	_mark(id)
	return true


## Người chơi thoát game giữa trận. Trả về true nếu là thợ săn (người trốn thắng).
func remove_player(id: int) -> bool:
	var p := record(id)
	if p == null:
		return false
	if p.is_hunter():
		if p.carrying_id != 0:
			_release(p)
		return true
	if p.carrier_id != 0:
		_detach(record(p.carrier_id), p)
	if not GameTypes.is_out(p.state):
		p.state = GameTypes.PlayerState.ELIMINATED
		_mark(id)
	return false


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


# ---------- Thời gian ----------

## `authoritative` = true trên server: chạy đủ luật (hết giờ tù, vùng thoát...).
## Trên client = false: chỉ đếm lùi các con số để hiển thị mượt giữa hai lần
## nhận dữ liệu, không bao giờ tự đổi trạng thái.
func tick(delta: float, authoritative: bool = true) -> void:
	match state:
		GameTypes.MatchState.COUNTDOWN:
			countdown_left -= delta
			if countdown_left <= 0.0:
				state = GameTypes.MatchState.PLAYING
		GameTypes.MatchState.PLAYING:
			time_left = maxf(0.0, time_left - delta)
			for p: PlayerRecord in players.values():
				_tick_player(p, delta, authoritative)


func _tick_player(p: PlayerRecord, delta: float, authoritative: bool) -> void:
	# Bộ đếm hiển thị được: chỉ đánh dấu dirty khi chạm 0, client tự đếm lùi giữa hai lần.
	if p.attack_cooldown_left > 0.0:
		p.attack_cooldown_left = maxf(0.0, p.attack_cooldown_left - delta)
	if p.invulnerable_left > 0.0:
		p.invulnerable_left = maxf(0.0, p.invulnerable_left - delta)
	if p.stunned_left > 0.0:
		p.stunned_left = maxf(0.0, p.stunned_left - delta)
		if p.stunned_left == 0.0:
			_mark(p.id)
	if not authoritative:
		if p.state == GameTypes.PlayerState.IMPRISONED:
			p.prison_time_left = maxf(0.0, p.prison_time_left - delta)
		elif p.state == GameTypes.PlayerState.CARRIED:
			p.struggle = minf(0.99, p.struggle + delta / maxf(config.carry_escape_time, 0.01))
		return

	if p.state == GameTypes.PlayerState.RESCUING:
		p.channel_left -= delta
		if p.channel_left <= 0.0:
			p.state = GameTypes.PlayerState.IDLE
			_mark(p.id)

	match p.state:
		GameTypes.PlayerState.CARRIED:
			p.struggle = minf(1.0, p.struggle + delta / maxf(config.carry_escape_time, 0.01))
			if p.struggle >= 1.0:
				var hunter := record(p.carrier_id)
				_release(hunter)
				if hunter:
					hunter.stunned_left = maxf(hunter.stunned_left, config.stun_after_struggle)
		GameTypes.PlayerState.IMPRISONED:
			p.prison_time_left -= delta
			if p.prison_time_left <= 0.0:
				p.prison_time_left = 0.0
				p.state = GameTypes.PlayerState.ELIMINATED
				p.prison_id = -1
				p.rescue_progress = 0.0
				_mark(p.id)


# ---------- Hết trận ----------

func total_safes() -> int:
	return safe_progress.size()


func safes_unlocked() -> int:
	var n := 0
	for v: float in safe_progress.values():
		if v >= 1.0:
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
	return escapee_ids().filter(func(id: int) -> bool: return state_of(id) == s).size()


## Người trốn chưa bị loại khỏi bản đồ (kể cả đang ngã / bị vác).
func active_escapees() -> int:
	return escapee_ids().filter(func(id: int) -> bool: return not GameTypes.is_out(state_of(id))).size()


func escapees_to_win() -> int:
	var total := escapee_ids().size()
	if config.escapees_to_win > 0:
		return mini(config.escapees_to_win, total)
	return ceili(total / 2.0)


## NONE nếu trận chưa kết thúc. Trận kết thúc khi không còn người trốn nào
## ở ngoài (bị nhốt hết, bị loại hoặc đã thoát) hoặc hết giờ.
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
		"eliminated": count_escapees(GameTypes.PlayerState.ELIMINATED),
		"safes_unlocked": safes_unlocked(),
		"time_left": time_left,
	}


# ---------- Dirty tracking ----------

## GameState lấy danh sách người chơi cần gửi xuống client rồi xóa.
func take_dirty() -> Array:
	var ids := _dirty.keys()
	_dirty.clear()
	return ids


func _mark(id: int) -> void:
	_dirty[id] = true


## Gỡ liên kết vác giữa thợ săn và người bị vác (không đổi state người bị vác).
func _detach(hunter: PlayerRecord, p: PlayerRecord) -> void:
	if hunter:
		hunter.carrying_id = 0
		_mark(hunter.id)
	if p:
		p.carrier_id = 0
		p.struggle = 0.0
		_mark(p.id)


## Người bị vác thoát ra, đứng dậy với máu hồi.
func _release(hunter: PlayerRecord) -> void:
	if hunter == null or hunter.carrying_id == 0:
		return
	var p := record(hunter.carrying_id)
	_detach(hunter, p)
	if p:
		p.state = GameTypes.PlayerState.IDLE
		p.hp = config.revive_hp
		p.invulnerable_left = config.hit_invulnerable_time
