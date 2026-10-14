class_name MatchRules
extends RefCounted
## Luật trận đấu, thuần logic: không dùng node, không dùng mạng.
## GameState giữ một bản trên mỗi máy; chỉ server gọi các lệnh (attack,
## pick_up, ...). Mỗi lệnh tự kiểm tra điều kiện và trả về false nếu không
## hợp lệ, nên module gọi sai lúc (gọi 2 lần, gọi khi đã bị nhốt...) cũng
## không làm hỏng trạng thái. Người chơi nào đổi dữ liệu thì được đánh dấu
## "dirty" để GameState gửi xuống client.

const RESCUE_CHANNEL_GRACE := 0.25 ## ngừng cứu chừng này giây thì hết trạng thái RESCUING
const CHEST_CHANNEL_GRACE := 0.25 ## rời rương chừng này giây thì vòng căn đang chạy bị hủy (không phạt)
const CHEST_COIN_BASE := 10000 ## id cọc tiền văng từ rương: CHEST_COIN_BASE + rương * 100 + k

var config: MatchConfig
var state: GameTypes.MatchState = GameTypes.MatchState.COUNTDOWN
var countdown_left := 0.0
var time_left := 0.0
var roles := {} # id -> GameTypes.Role
var names := {} # id -> String
var players := {} # id -> PlayerRecord
var elapsed := 0.0 ## giây đã chơi (đồng hồ chung cho vòng căn)
var hunter_left := false ## thợ săn thoát game giữa trận
var result := {} ## kết quả cuối trận (results()), có khi state = ENDED

## Thế giới (đồng bộ bằng WorldRecord): rương, cổng, tiền trên sàn.
var safe_progress := {} # safe_id -> 0.0..1.0
var gate_open := false
var gate_opening_left := 0.0 ## > 0: cổng đang rung, chưa qua được
var coins := {} # coin_id -> giá trị, những cọc tiền còn trên sàn
var coins_taken := {} # coin_id -> id người nhặt
var placed := {} # obj_id -> {"type": ItemType, "pos": Vector3, "yaw": float, "owner": id, "expires": elapsed}
var catalog := {} ## ItemType -> {"cost": int, "cooldown": float}, Items khai báo (setup_items)
## Đạn đang bay: shot_id -> {"kind": ShotKind, "owner": id, "from": Vector3, "to": Vector3, "fired": elapsed, "lands": elapsed}
var shots := {}

var _next_placed_id := 1
var _next_shot_id := 1
var _teleports_done := [] # chỉ server: id thợ săn vừa tụ lực xong, GameState dời nhân vật

var rng := RandomNumberGenerator.new() ## chỉ server dùng (vị trí vùng sáng, giờ hiện vòng căn)

var _dirty := {} # id -> true
var _world_dirty := false


func _init(cfg: MatchConfig, p_roles: Dictionary, p_names: Dictionary, total_safes: int, floor_coins: int = 0) -> void:
	config = cfg
	roles = p_roles
	names = p_names
	countdown_left = cfg.countdown
	time_left = cfg.duration
	rng.randomize()
	for i in floor_coins:
		coins[i] = cfg.floor_coin_value
	for id: int in roles:
		var hp := cfg.hunter_max_hp if roles[id] == GameTypes.Role.HUNTER else cfg.max_hp
		players[id] = PlayerRecord.new(id, roles[id], hp)
		players[id].coins = cfg.start_coins
	for i in total_safes:
		safe_progress[i] = 0.0


# ---------- Đọc ----------

func is_playing() -> bool:
	return state == GameTypes.MatchState.PLAYING


func record(id: int) -> PlayerRecord:
	return players.get(id)


func state_of(id: int) -> GameTypes.PlayerState:
	return players[id].state if players.has(id) else GameTypes.PlayerState.ELIMINATED


## Có được tự di chuyển không (bị kéo, bị nhốt, bị choáng, đang tụ lực dịch chuyển thì không).
func can_move(id: int) -> bool:
	var p := record(id)
	if p == null or p.stunned_left > 0.0 or p.teleport_left > 0.0:
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
	return p.speed_boost_factor if p.speed_boost_left > 0.0 else 1.0


func can_attack(id: int) -> bool:
	var p := record(id)
	return p != null and p.is_hunter() and p.stunned_left <= 0.0 and p.attack_cooldown_left <= 0.0 and p.teleport_left <= 0.0 \
		and p.carrying_id == 0 and is_playing()


func is_hittable(id: int) -> bool:
	var p := record(id)
	return p != null and not p.is_hunter() and GameTypes.is_active(p.state) and p.invulnerable_left <= 0.0


# ---------- Lệnh (server gọi qua GameState) ----------

## Đòn trúng ngay (không bay): `targets` là những người trốn trúng đòn. Thợ
## săn hiện dùng cối (fire_mortar); hàm này để dành cho vũ khí cận chiến.
## Trả về true nếu đòn được vung (kể cả trượt).
func attack(attacker_id: int, targets: Array) -> bool:
	if not can_attack(attacker_id):
		return false
	_start_attack(record(attacker_id))
	for target_id: int in targets:
		_hit_escapee(target_id, attacker_id)
	return true


## Thợ săn bắn cối từ `from` tới `to` (bị kẹp trong tầm mortar_range). Đạn rơi
## sau một lúc; GameState xét ai đứng trong vùng nổ rồi gọi land_shot.
## Trả về id viên đạn, 0 nếu không bắn được.
func fire_mortar(hunter_id: int, from: Vector3, to: Vector3) -> int:
	if not can_attack(hunter_id):
		return 0
	_start_attack(record(hunter_id))
	return _add_shot(GameTypes.ShotKind.MORTAR, hunter_id, from, to)


## Người trốn bắn súng lục (tiền và hồi chiêu đã tính ở use_item).
func shoot_bullet(owner_id: int, from: Vector3, to: Vector3) -> int:
	var p := record(owner_id)
	if p == null or p.is_hunter() or not is_playing() or not GameTypes.is_active(p.state) or p.stunned_left > 0.0:
		return 0
	return _add_shot(GameTypes.ShotKind.BULLET, owner_id, from, to)


## Bán kính trúng của một loại đạn.
func shot_radius(kind: GameTypes.ShotKind) -> float:
	return config.mortar_radius if kind == GameTypes.ShotKind.MORTAR else config.bullet_radius


## Những viên đạn đã tới nơi, chờ xét trúng.
func due_shots() -> Array:
	return shots.keys().filter(func(shot_id: int) -> bool: return shots[shot_id]["lands"] <= elapsed)


## Đạn rơi xuống; `hit_ids` là những người đứng trong vùng trúng (GameState
## tính theo vị trí). Cối chỉ trúng người trốn, đạn súng chỉ trúng thợ săn.
func land_shot(shot_id: int, hit_ids: Array) -> bool:
	if not shots.has(shot_id):
		return false
	var s: Dictionary = shots[shot_id]
	shots.erase(shot_id)
	_world_dirty = true
	for id: int in hit_ids:
		if s["kind"] == GameTypes.ShotKind.MORTAR:
			_hit_escapee(id, s["owner"])
		else:
			damage_hunter(id, config.bullet_damage, s["owner"])
	return true


## Thợ săn mất máu (súng lục). Hết máu thì bị choáng (buông người đang kéo),
## hết choáng thì hồi đầy.
func damage_hunter(id: int, amount: int, attacker_id: int) -> bool:
	var p := record(id)
	if p == null or not p.is_hunter() or p.hp <= 0 or amount <= 0 or not is_playing():
		return false
	var dealt := mini(amount, p.hp)
	p.hp -= dealt
	p.last_attacker_id = attacker_id
	_mark(id)
	var shooter := record(attacker_id)
	if shooter:
		shooter.damage_dealt += dealt
		_mark(attacker_id)
	if p.hp == 0:
		stun(id, config.hunter_knockout_stun)
	return true


## Thợ săn túm người đang gục, kéo lê phía sau.
func pick_up(hunter_id: int, target_id: int) -> bool:
	var hunter := record(hunter_id)
	var p := record(target_id)
	if hunter == null or p == null or not hunter.is_hunter() or not is_playing():
		return false
	if hunter.carrying_id != 0 or hunter.stunned_left > 0.0 or p.state != GameTypes.PlayerState.DOWNED:
		return false
	p.state = GameTypes.PlayerState.CARRIED
	p.carrier_id = hunter_id
	p.rescue_progress = 0.0
	hunter.carrying_id = target_id
	_mark(hunter_id)
	_mark(target_id)
	return true


## Thợ săn thả người đang kéo (vẫn nằm gục).
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


## Thợ săn kéo người vào nhà tù `prison_id`. Người bị nhốt mất máu dần
## (prison_time_left), hết thì bị đốt chết; chỉ túi máu cứu được.
func imprison(hunter_id: int, prison_id: int) -> bool:
	var hunter := record(hunter_id)
	if hunter == null or hunter.carrying_id == 0 or not is_playing():
		return false
	var p := record(hunter.carrying_id)
	_detach(hunter, p)
	p.imprison_count += 1
	p.rescue_progress = 0.0
	if config.max_imprisonments > 0 and p.imprison_count >= config.max_imprisonments:
		p.state = GameTypes.PlayerState.ELIMINATED
		p.prison_id = -1
	else:
		p.state = GameTypes.PlayerState.IMPRISONED
		p.prison_id = prison_id
		p.prison_time_left = config.prison_time
	_mark(p.id)
	return true


## Người trốn `rescuer_id` đỡ `target_id` (đang gục dưới đất) thêm `delta`
## giây. Gọi mỗi physics frame khi đang giữ nút E. Nhiều người cứu cùng lúc
## thì cộng dồn. Trả về true nếu lần này đỡ dậy xong. Người bị kéo hoặc bị
## nhốt không đỡ tay được, phải dùng túi máu (heal).
func channel_rescue(rescuer_id: int, target_id: int, delta: float) -> bool:
	var r := record(rescuer_id)
	var p := record(target_id)
	if r == null or p == null or r.is_hunter() or p.is_hunter() or rescuer_id == target_id:
		return false
	if not GameTypes.is_active(r.state) or r.stunned_left > 0.0 or not is_playing():
		return false
	if p.state != GameTypes.PlayerState.DOWNED:
		return false
	var duration := config.revive_time

	r.channel_left = RESCUE_CHANNEL_GRACE
	if r.state != GameTypes.PlayerState.RESCUING:
		r.state = GameTypes.PlayerState.RESCUING
		_mark(rescuer_id)
	p.rescue_progress = minf(1.0, p.rescue_progress + delta / maxf(duration, 0.01))
	p.last_rescuer_id = rescuer_id
	_mark(target_id)
	if p.rescue_progress < 1.0:
		return false

	p.hp = config.revive_hp
	p.state = GameTypes.PlayerState.IDLE
	p.rescue_progress = 0.0
	p.invulnerable_left = config.hit_invulnerable_time
	r.rescues += 1
	return true


## Gán bảng giá thẻ (`items`: ItemType -> ItemData hoặc {"cost", "cooldown"}) và
## bộ bài từng người (`decks`: id -> Array[ItemType]; thiếu thì dùng `defaults`:
## Role -> Array). Gọi một lần lúc vào trận, trên mọi máy giống nhau.
func setup_items(items: Dictionary, decks: Dictionary, defaults: Dictionary) -> void:
	catalog.clear()
	for type: int in items:
		var it: Variant = items[type]
		catalog[type] = {"cost": it.cost, "cooldown": it.cooldown, "roles": Array(it.allowed_roles)} if it is Resource else it
	for id: int in players:
		var p: PlayerRecord = players[id]
		p.deck = _valid_deck(decks.get(id, []), p.role)
		if p.deck.is_empty():
			p.deck = _valid_deck(defaults.get(p.role, []), p.role)
		p.item_cooldowns = []
		p.item_cooldowns.resize(p.deck.size())
		p.item_cooldowns.fill(0.0)


## Bộ bài người chơi gửi lên: bỏ thẻ không có, thẻ không dành cho vai này, thẻ trùng; tối đa deck_size ô.
func _valid_deck(deck: Variant, role: GameTypes.Role) -> Array:
	var out := []
	if not deck is Array:
		return out
	for t: Variant in deck:
		if not t is int or not catalog.has(t) or t in out:
			continue
		if role not in catalog[t].get("roles", [role]):
			continue
		out.append(t)
		if out.size() >= config.deck_size:
			break
	return out


## Ô thẻ `slot` của `id` dùng được ngay không (đủ tiền, hết hồi chiêu, đang đứng).
func can_use_item(id: int, slot: int) -> bool:
	var p := record(id)
	if p == null or not is_playing() or not GameTypes.is_active(p.state) or p.stunned_left > 0.0 or p.teleport_left > 0.0:
		return false
	if slot < 0 or slot >= p.deck.size() or p.item_cooldowns[slot] > 0.0:
		return false
	return p.coins >= catalog[p.deck[slot]]["cost"]


## Trả tiền và tính hồi chiêu cho ô thẻ `slot`, ghi lại để mọi máy phát
## item_used. Hiệu ứng do Items làm sau đó. Trả về false nếu không dùng được.
func use_item(id: int, slot: int, target_id: int = 0, target_pos: Vector3 = Vector3.ZERO) -> bool:
	if not can_use_item(id, slot):
		return false
	var p := record(id)
	var info: Dictionary = catalog[p.deck[slot]]
	p.coins -= info["cost"]
	p.item_cooldowns[slot] = info["cooldown"]
	p.item_seq += 1
	p.item_last_type = p.deck[slot]
	p.item_target_id = target_id
	p.item_target_pos = target_pos
	_mark(id)
	return true


## Có hồi máu / cứu được `target_id` bằng túi máu của `healer_id` không.
func can_heal(healer_id: int, target_id: int) -> bool:
	var t := record(healer_id)
	var p := record(target_id)
	if t == null or p == null or t.is_hunter() or p.is_hunter() or not is_playing():
		return false
	if not GameTypes.is_active(t.state) or t.stunned_left > 0.0:
		return false
	match p.state:
		GameTypes.PlayerState.DOWNED, GameTypes.PlayerState.CARRIED, GameTypes.PlayerState.IMPRISONED:
			return true
	return GameTypes.is_active(p.state) and p.hp < p.max_hp


## Túi máu của `healer_id` trúng `target_id` (có thể là chính mình khi đang
## đứng). Người đang gục, bị kéo hoặc bị nhốt thì đứng dậy ngay; đang đứng thì
## hồi máu. Tiền đã trả khi dùng thẻ (use_item). Trả về false nếu không có tác dụng.
func heal(healer_id: int, target_id: int) -> bool:
	if not can_heal(healer_id, target_id):
		return false
	var t := record(healer_id)
	var p := record(target_id)
	var amount := maxi(config.medkit_heal, 1)
	if GameTypes.is_active(p.state):
		p.hp = mini(p.hp + amount, p.max_hp)
	else:
		if p.carrier_id != 0:
			_detach(record(p.carrier_id), p)
		p.state = GameTypes.PlayerState.IDLE
		p.hp = mini(amount, p.max_hp)
		p.prison_id = -1
		p.prison_time_left = 0.0
		p.rescue_progress = 0.0
		p.invulnerable_left = config.hit_invulnerable_time
		if healer_id != target_id:
			t.rescues += 1
	p.last_rescuer_id = healer_id
	p.heal_seq += 1
	_mark(healer_id)
	_mark(target_id)
	return true


## Tăng tốc (xe / ván trượt): nhân tốc độ chạy với `factor` trong `seconds` giây.
func speed_boost(id: int, seconds: float, factor: float) -> bool:
	var p := record(id)
	if p == null or seconds <= 0.0 or factor <= 0.0 or not is_playing() or GameTypes.is_out(p.state):
		return false
	p.speed_boost_left = seconds
	p.speed_boost_factor = factor
	_mark(id)
	return true


## Đặt vật thể xuống đất (bẫy, đệm lò xo, hộp gỗ). Tự biến mất sau `lifetime`
## giây (0 = tới hết trận). Trả về id vật thể, 0 nếu không đặt được.
func place(type: GameTypes.ItemType, pos: Vector3, yaw: float, owner_id: int, lifetime: float) -> int:
	if not is_playing():
		return 0
	var obj_id := _next_placed_id
	_next_placed_id += 1
	placed[obj_id] = {"type": type, "pos": pos, "yaw": yaw, "owner": owner_id,
		"expires": elapsed + lifetime if lifetime > 0.0 else INF}
	_world_dirty = true
	return obj_id


func remove_placed(obj_id: int) -> bool:
	if not placed.erase(obj_id):
		return false
	_world_dirty = true
	return true


## Làm choáng (súng, lựu đạn, bẫy...). Thợ săn đang kéo người mà bị choáng thì buông tay, người đó đứng dậy chạy tiếp.
func stun(id: int, seconds: float) -> bool:
	var p := record(id)
	if p == null or seconds <= 0.0 or not is_playing() or GameTypes.is_out(p.state):
		return false
	p.stunned_left = maxf(p.stunned_left, seconds)
	p.teleport_left = 0.0 # bị choáng thì hủy dịch chuyển
	_mark(id)
	if p.carrying_id != 0:
		_release(p)
	return true


## Thợ săn bắt đầu tụ lực dịch chuyển tới `pos` (GameState đã kiểm tra chỗ
## đứng được). Đứng yên teleport_charge giây rồi mới tới; bị choáng thì hủy.
func start_teleport(id: int, pos: Vector3) -> bool:
	var p := record(id)
	if p == null or not p.is_hunter() or not is_playing() or p.carrying_id != 0:
		return false
	if p.stunned_left > 0.0 or p.teleport_left > 0.0:
		return false
	p.teleport_left = maxf(config.teleport_charge, 0.001)
	p.teleport_pos = pos
	_mark(id)
	return true


## Những thợ săn vừa tụ lực xong (server dời nhân vật tới teleport_pos), rồi xóa danh sách.
func take_teleports() -> Array:
	var ids := _teleports_done
	_teleports_done = []
	return ids


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
		hunter_left = true
		return true
	if p.carrier_id != 0:
		_detach(record(p.carrier_id), p)
	if not GameTypes.is_out(p.state):
		p.state = GameTypes.PlayerState.ELIMINATED
		_mark(id)
	return false


## Người trốn `id` mở rương `safe_id` thêm `delta` giây. Gọi mỗi physics
## frame khi đang đứng ở rương. Nhiều người mở cùng lúc thì cộng dồn. Trong
## lúc mở, vòng căn hiện ra theo nhịp (qte_*): xem resolve_qte(). Trả về true
## nếu lần này mở xong rương.
func channel_chest(id: int, safe_id: int, delta: float) -> bool:
	var p := record(id)
	if p == null or p.is_hunter() or not GameTypes.is_active(p.state) or p.stunned_left > 0.0 or not is_playing():
		return false
	if not safe_progress.has(safe_id) or safe_progress[safe_id] >= 1.0:
		return false
	if p.chest_id != safe_id:
		_cancel_qte(p)
		p.chest_id = safe_id
		p.qte_next_left = rng.randf_range(config.qte_interval_min, config.qte_interval_max)
	p.chest_channel_left = CHEST_CHANNEL_GRACE
	var gain := minf(delta / maxf(config.chest_open_time, 0.01), 1.0 - safe_progress[safe_id])
	p.chest_work += gain
	_mark(id)
	if p.qte_chest < 0:
		p.qte_next_left -= delta
		if p.qte_next_left <= 0.0:
			p.qte_chest = safe_id
			p.qte_started = elapsed
			p.qte_zone = rng.randf_range(config.qte_zone_min, config.qte_zone_max)
	return _add_chest_progress(safe_id, gain)


## Vị trí kim trên vòng căn của `id` (0..1, quá 1 là đã chạy hết vòng), -1 nếu không có vòng.
func qte_needle(id: int) -> float:
	var p := record(id)
	if p == null or p.qte_chest < 0:
		return -1.0
	return (elapsed - p.qte_started) * config.qte_speed


## Người chơi bấm nút khi vòng căn đang chạy. Vùng sáng đậm: rương mở thêm
## một đoạn + tiền; vùng mờ: ít tiền hơn; ngoài vùng: hỏng, rương về 0 và
## nổ báo vị trí. `lag` (giây) là độ trễ từ lúc người chơi bấm tới lúc server
## nhận, do server tự đo (không tin client), kẹp tối đa qte_grace.
## Trả về kết quả (NONE nếu không có vòng căn).
func resolve_qte(id: int, lag: float = 0.0) -> GameTypes.QteResult:
	var p := record(id)
	if p == null or p.qte_chest < 0 or not is_playing():
		return GameTypes.QteResult.NONE
	var needle := qte_needle(id) - clampf(lag, 0.0, config.qte_grace) * config.qte_speed
	var dist := absf(needle - p.qte_zone)
	var res := GameTypes.QteResult.FAIL
	if dist <= config.qte_perfect_width:
		res = GameTypes.QteResult.PERFECT
	elif dist <= config.qte_good_width:
		res = GameTypes.QteResult.GOOD
	_finish_qte(p, res)
	return res


## Người trốn `id` nhặt cọc tiền `coin_id`. Trả về true nếu nhặt được.
func take_coin(id: int, coin_id: int) -> bool:
	var p := record(id)
	if p == null or p.is_hunter() or not GameTypes.is_active(p.state) or not coins.has(coin_id) or not is_playing():
		return false
	_add_coins(p, coins[coin_id])
	coins.erase(coin_id)
	coins_taken[coin_id] = id
	_world_dirty = true
	return true


## Id các cọc tiền văng ra từ rương `safe_id` khi mở xong (mọi máy tính ra như nhau).
func chest_coin_ids(safe_id: int) -> Array:
	var ids := []
	for k in config.chest_coins:
		ids.append(CHEST_COIN_BASE + safe_id * 100 + k)
	return ids


# ---------- Thời gian ----------

## `authoritative` = true trên server: chạy đủ luật (bị đốt trong tù...).
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
			elapsed += delta
			if gate_opening_left > 0.0:
				gate_opening_left = maxf(0.0, gate_opening_left - delta)
				if gate_opening_left == 0.0 and authoritative:
					gate_open = true
					_world_dirty = true
			for p: PlayerRecord in players.values():
				_tick_player(p, delta, authoritative)
			if authoritative:
				for obj_id: int in placed.keys():
					if placed[obj_id]["expires"] <= elapsed:
						remove_placed(obj_id)


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
	if p.speed_boost_left > 0.0:
		p.speed_boost_left = maxf(0.0, p.speed_boost_left - delta)
	if p.teleport_left > 0.0:
		p.teleport_left = maxf(0.0, p.teleport_left - delta)
		if p.teleport_left == 0.0 and authoritative:
			_teleports_done.append(p.id)
			_mark(p.id)
	if authoritative and p.is_hunter() and p.hp <= 0 and p.stunned_left <= 0.0:
		p.hp = p.max_hp # tỉnh lại sau khi bị bắn gục
		_mark(p.id)
	for i in p.item_cooldowns.size():
		if p.item_cooldowns[i] > 0.0:
			p.item_cooldowns[i] = maxf(0.0, p.item_cooldowns[i] - delta)
	if not authoritative:
		if p.state == GameTypes.PlayerState.IMPRISONED:
			p.prison_time_left = maxf(0.0, p.prison_time_left - delta)
		return

	if p.chest_id >= 0:
		p.chest_channel_left -= delta
		if p.chest_channel_left <= 0.0 or not GameTypes.is_active(p.state):
			_cancel_qte(p)
			p.chest_id = -1
	if p.qte_chest >= 0 and qte_needle(p.id) > 1.0 + config.qte_grace * config.qte_speed:
		_finish_qte(p, GameTypes.QteResult.FAIL) # kim chạy hết vòng mà không bấm

	if p.state == GameTypes.PlayerState.RESCUING:
		p.channel_left -= delta
		if p.channel_left <= 0.0:
			p.state = GameTypes.PlayerState.IDLE
			_mark(p.id)

	if p.state == GameTypes.PlayerState.IMPRISONED:
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


## Người trốn chưa bị loại khỏi bản đồ (kể cả đang gục / bị kéo).
func active_escapees() -> int:
	return escapee_ids().filter(func(id: int) -> bool: return not GameTypes.is_out(state_of(id))).size()


## Trận kết thúc khi không còn người trốn nào ở ngoài (bị nhốt, bị loại
## hoặc đã thoát), hết giờ, hoặc thợ săn rời trận.
func is_over() -> bool:
	if state != GameTypes.MatchState.PLAYING:
		return false
	return active_escapees() == 0 or time_left <= 0.0 or hunter_left


## Người trốn này tính là "bị bắt" khi hết trận: không thoát qua cổng
## (trừ khi thợ săn bỏ trận: ai chưa bị nhốt/loại coi như thoát).
func is_caught(id: int) -> bool:
	var s := state_of(id)
	if s == GameTypes.PlayerState.ESCAPED:
		return false
	if hunter_left:
		return s == GameTypes.PlayerState.IMPRISONED or s == GameTypes.PlayerState.ELIMINATED
	return true


func hunter_result(caught: int, total: int) -> GameTypes.HunterResult:
	if total > 0 and caught >= total:
		return GameTypes.HunterResult.TOTAL
	if caught >= ceili(total / 2.0) and caught > 0:
		return GameTypes.HunterResult.PARTIAL
	return GameTypes.HunterResult.LOSE


## Kết quả và điểm từng người. Chỉ server tính, rồi gửi nguyên bản xuống mọi máy.
func results() -> Dictionary:
	var ids := escapee_ids()
	var caught := ids.filter(func(id: int) -> bool: return is_caught(id)).size()
	var per_player := {}
	for id: int in players:
		var p: PlayerRecord = players[id]
		var row := {
			"name": names.get(id, str(id)), "role": p.role, "coins": p.coins_earned,
			"rescues": p.rescues, "qte_perfect": p.qte_perfect, "chests": snappedf(p.chest_work, 0.01),
			"damage": p.damage_dealt,
		}
		if p.is_hunter():
			row["result"] = hunter_result(caught, ids.size())
			row["score"] = caught * config.score_hunter_catch
		else:
			var escaped := not is_caught(id)
			row["result"] = GameTypes.EscapeeResult.ESCAPED if escaped else GameTypes.EscapeeResult.CAUGHT
			row["score"] = (config.score_escape if escaped else 0) + roundi(p.chest_work * config.score_chest) \
				+ p.rescues * config.score_rescue + p.qte_perfect * config.score_perfect_qte + p.coins_earned * config.score_per_coin \
				+ p.damage_dealt * config.score_damage
		per_player[id] = row
	return {
		"hunter_result": hunter_result(caught, ids.size()),
		"caught": caught,
		"escaped": ids.size() - caught,
		"escapees": ids.size(),
		"safes_unlocked": safes_unlocked(),
		"time_left": time_left,
		"players": per_player,
	}


func finish(res: Dictionary) -> void:
	result = res
	state = GameTypes.MatchState.ENDED


# ---------- Dirty tracking ----------

## GameState lấy danh sách người chơi cần gửi xuống client rồi xóa.
func take_dirty() -> Array:
	var ids := _dirty.keys()
	_dirty.clear()
	return ids


## true nếu rương / cổng / tiền đã đổi kể từ lần hỏi trước.
func take_world_dirty() -> bool:
	var d := _world_dirty
	_world_dirty = false
	return d


## Trạng thái thế giới để gửi xuống client (WorldRecord).
func world_dict() -> Dictionary:
	return {
		"safes": safe_progress.duplicate(), "gate_open": gate_open, "gate_opening": gate_opening_left > 0.0,
		"gate_opening_left": gate_opening_left, "coins_taken": coins_taken.duplicate(),
		"placed": placed.duplicate(true), "shots": shots.duplicate(true),
	}


## Client áp bản thế giới server gửi. Tiền văng từ rương cũng tự thêm như server.
func apply_world_dict(d: Dictionary) -> void:
	safe_progress = d["safes"].duplicate()
	gate_open = d["gate_open"]
	gate_opening_left = d["gate_opening_left"]
	coins_taken = d["coins_taken"].duplicate()
	placed = d["placed"].duplicate(true)
	shots = d["shots"].duplicate(true)
	for safe_id: int in safe_progress:
		if safe_progress[safe_id] >= 1.0:
			for c: int in chest_coin_ids(safe_id):
				if not coins_taken.has(c):
					coins[c] = config.chest_coin_value
	for c: int in coins_taken:
		coins.erase(c)


func _mark(id: int) -> void:
	_dirty[id] = true


func _start_attack(hunter: PlayerRecord) -> void:
	hunter.attack_cooldown_left = config.attack_cooldown
	hunter.attack_seq += 1
	_mark(hunter.id)


## Người trốn trúng đòn / trúng cối: mất 1 máu, hết máu thì gục.
func _hit_escapee(target_id: int, attacker_id: int) -> void:
	if not is_hittable(target_id):
		return
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


## Thêm đạn bay. Kẹp tầm bắn theo mặt sàn (không tin vị trí client gửi).
func _add_shot(kind: GameTypes.ShotKind, owner_id: int, from: Vector3, to: Vector3) -> int:
	var mortar := kind == GameTypes.ShotKind.MORTAR
	var flat := Vector2(to.x - from.x, to.z - from.z).limit_length(config.mortar_range if mortar else config.bullet_range)
	var dest := Vector3(from.x + flat.x, to.y, from.z + flat.y)
	var flight := config.mortar_min_flight + flat.length() / config.mortar_speed if mortar \
		else maxf(0.05, flat.length() / config.bullet_speed)
	var shot_id := _next_shot_id
	_next_shot_id += 1
	shots[shot_id] = {"kind": kind, "owner": owner_id, "from": from, "to": dest, "fired": elapsed, "lands": elapsed + flight}
	_world_dirty = true
	return shot_id


## Gỡ liên kết kéo giữa thợ săn và người bị kéo (không đổi state người bị kéo).
func _detach(hunter: PlayerRecord, p: PlayerRecord) -> void:
	if hunter:
		hunter.carrying_id = 0
		_mark(hunter.id)
	if p:
		p.carrier_id = 0
		_mark(p.id)


func _add_coins(p: PlayerRecord, amount: int) -> void:
	p.coins += amount
	p.coins_earned += amount
	_mark(p.id)


## Cộng tiến độ rương; đủ 100% thì nhả tiền, đủ chìa thì cổng bắt đầu mở.
func _add_chest_progress(safe_id: int, amount: float) -> bool:
	var was_done: bool = safe_progress[safe_id] >= 1.0
	safe_progress[safe_id] = clampf(safe_progress[safe_id] + amount, 0.0, 1.0)
	if is_equal_approx(safe_progress[safe_id], 1.0):
		safe_progress[safe_id] = 1.0
	_world_dirty = true
	if was_done or safe_progress[safe_id] < 1.0:
		return false
	for c: int in chest_coin_ids(safe_id):
		coins[c] = config.chest_coin_value
	for p: PlayerRecord in players.values():
		if p.chest_id == safe_id:
			_cancel_qte(p)
			p.chest_id = -1
	if safes_unlocked() >= safes_required() and not gate_open and gate_opening_left <= 0.0:
		gate_opening_left = maxf(config.gate_open_delay, 0.001)
	return true


func _finish_qte(p: PlayerRecord, res: GameTypes.QteResult) -> void:
	var safe_id := p.qte_chest
	p.qte_chest = -1
	p.qte_seq += 1
	p.qte_result = res
	p.qte_result_chest = safe_id
	p.qte_next_left = rng.randf_range(config.qte_interval_min, config.qte_interval_max)
	_mark(p.id)
	match res:
		GameTypes.QteResult.PERFECT:
			p.qte_perfect += 1
			_add_coins(p, config.qte_perfect_coins)
			if safe_progress.has(safe_id) and safe_progress[safe_id] < 1.0:
				var gain := minf(config.qte_perfect_bonus, 1.0 - safe_progress[safe_id])
				p.chest_work += gain
				_add_chest_progress(safe_id, gain)
		GameTypes.QteResult.GOOD:
			_add_coins(p, config.qte_good_coins)
		GameTypes.QteResult.FAIL:
			if safe_progress.has(safe_id) and safe_progress[safe_id] < 1.0:
				safe_progress[safe_id] = 0.0 # hỏng: mở lại từ đầu
				_world_dirty = true


## Rời rương: vòng căn đang chạy biến mất, không phạt.
func _cancel_qte(p: PlayerRecord) -> void:
	if p.qte_chest >= 0:
		p.qte_chest = -1
		_mark(p.id)


## Thợ săn buông người đang kéo, người đó đứng dậy với máu hồi.
func _release(hunter: PlayerRecord) -> void:
	if hunter == null or hunter.carrying_id == 0:
		return
	var p := record(hunter.carrying_id)
	_detach(hunter, p)
	if p:
		p.state = GameTypes.PlayerState.IDLE
		p.hp = config.revive_hp
		p.invulnerable_left = config.hit_invulnerable_time
