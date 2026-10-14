class_name PlayerRecord
extends RefCounted
## Toàn bộ trạng thái gameplay của một người chơi trong trận.
## Server giữ bản gốc trong MatchRules và gửi nguyên bản (to_dict) xuống
## client mỗi khi đổi. Client không tự sửa, chỉ thay bằng bản mới nhận được.
## Sự kiện (bị đánh, ngã, được cứu...) được suy ra bằng cách so bản cũ với
## bản mới (events_between), nên mọi máy luôn ra cùng sự kiện, kể cả khi
## gói tin bị gộp hay đến trễ.

var id := 0
var role: GameTypes.Role = GameTypes.Role.ESCAPEE
var state: GameTypes.PlayerState = GameTypes.PlayerState.IDLE
var hp := 0
var max_hp := 0
var imprison_count := 0
var carrier_id := 0 ## người trốn: ai đang kéo mình (0 = không)
var carrying_id := 0 ## thợ săn: đang kéo ai (0 = không)
var prison_id := -1
var prison_time_left := 0.0 ## máu còn lại trong tù tính bằng giây, hết là bị đốt chết
var rescue_progress := 0.0 ## tiến độ đồng đội đỡ mình dậy (giữ E), 0..1
var deck := [] ## ItemType trong từng ô thẻ (nút skill_1..)
var item_cooldowns := [] ## giây hồi chiêu còn lại của từng ô
var item_seq := 0 ## tăng mỗi lần dùng thẻ, để mọi máy phát item_used
var item_last_type := -1
var item_target_id := 0
var item_target_pos := Vector3.ZERO
var teleport_left := 0.0 ## thợ săn đang tụ lực dịch chuyển (> 0: đứng yên)
var teleport_pos := Vector3.ZERO ## điểm sẽ tới
var speed_boost_left := 0.0
var speed_boost_factor := 1.0
var flinch_left := 0.0 ## khựng lại sau khi bắn / trúng đạn (chỉ server dùng để tính di chuyển, không gửi đi)
var heal_seq := 0 ## tăng mỗi lần được dùng túi máu, để phân biệt "được cứu" với "được buông"
var invulnerable_left := 0.0
var attack_cooldown_left := 0.0
var stunned_left := 0.0
var attack_seq := 0 ## tăng mỗi lần thợ săn vung đòn / bắn súng, để client phát anim
var last_attacker_id := 0
var last_rescuer_id := 0
var coins := 0 ## tiền đang có, dùng để mua/kích hoạt thẻ
var coins_earned := 0 ## tổng tiền nhặt được cả trận (tính điểm)
var chest_work := 0.0 ## tổng phần rương mình đã mở (1.0 = một rương)
var rescues := 0 ## số lần cứu đồng đội
var damage_dealt := 0 ## người trốn: số máu đã bắn mất của thợ săn
var qte_perfect := 0 ## số lần căn trúng vùng sáng đậm
var qte_chest := -1 ## vòng căn đang hiện cho rương nào (-1 = không có)
var qte_started := 0.0 ## MatchRules.elapsed lúc vòng căn hiện ra
var qte_zone := 0.0 ## tâm vùng sáng trên vòng (0..1)
var qte_seq := 0 ## tăng mỗi lần một vòng căn kết thúc
var qte_result: GameTypes.QteResult = GameTypes.QteResult.NONE ## kết quả vòng căn gần nhất
var qte_result_chest := -1

## Chỉ server dùng, không gửi đi.
var channel_left := 0.0 ## còn bao lâu thì hết trạng thái RESCUING nếu không cứu tiếp
var chest_id := -1 ## đang mở rương nào
var chest_channel_left := 0.0
var qte_next_left := 0.0 ## còn bao lâu thì vòng căn tiếp theo hiện ra

const _SYNCED := [
	"role", "state", "hp", "max_hp", "imprison_count", "carrier_id", "carrying_id",
	"prison_id", "prison_time_left", "rescue_progress", "heal_seq", "invulnerable_left",
	"attack_cooldown_left", "stunned_left", "attack_seq", "last_attacker_id", "last_rescuer_id",
	"coins", "coins_earned", "chest_work", "rescues", "damage_dealt", "qte_perfect",
	"qte_chest", "qte_started", "qte_zone", "qte_seq", "qte_result", "qte_result_chest",
	"deck", "item_cooldowns", "item_seq", "item_last_type", "item_target_id", "item_target_pos",
	"speed_boost_left", "speed_boost_factor", "teleport_left", "teleport_pos",
]


func _init(p_id: int = 0, p_role: GameTypes.Role = GameTypes.Role.ESCAPEE, p_max_hp: int = 0) -> void:
	id = p_id
	role = p_role
	max_hp = p_max_hp
	hp = p_max_hp


func is_hunter() -> bool:
	return role == GameTypes.Role.HUNTER


func to_dict() -> Dictionary:
	var d := {}
	for key: String in _SYNCED:
		var v: Variant = get(key)
		d[key] = v.duplicate() if v is Dictionary or v is Array else v # bản sao để so cũ/mới không dùng chung
	return d


func apply_dict(d: Dictionary) -> void:
	for key: String in _SYNCED:
		if d.has(key):
			var v: Variant = d[key]
			set(key, v.duplicate() if v is Dictionary or v is Array else v)


## Gói gửi qua mạng: chỉ các trường đổi so với bản đã gửi, dạng phẳng
## [chỉ_số_trường, giá_trị, ...] (chỉ số theo _SYNCED) để không lặp tên trường.
static func diff(old: Dictionary, new: Dictionary) -> Array:
	var out := []
	for i in _SYNCED.size():
		var key: String = _SYNCED[i]
		if old.is_empty() or old.get(key) != new[key]:
			out.append(i)
			out.append(new[key])
	return out


## Dựng bản đầy đủ mới từ bản cũ + gói diff(). Không đổi `base`.
static func apply_diff(base: Dictionary, changes: Array) -> Dictionary:
	var d := base.duplicate(true)
	for k in range(0, changes.size() - 1, 2):
		var i: int = changes[k]
		if i >= 0 and i < _SYNCED.size():
			d[_SYNCED[i]] = changes[k + 1]
	return d


## Danh sách sự kiện suy ra khi trạng thái đổi từ `old` sang `new` (hai dict
## từ to_dict()). Mỗi phần tử: {"signal": tên tín hiệu EventBus, "args": [...]}.
## Hàm thuần, không phụ thuộc mạng, có test trong tests/.
static func events_between(id: int, old: Dictionary, new: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if old.is_empty():
		return out
	if new["attack_seq"] > old["attack_seq"]:
		out.append({"signal": &"player_attacked", "args": [id]})
	if new["hp"] < old["hp"]:
		out.append({"signal": &"player_hit", "args": [id, new["last_attacker_id"], new["hp"]]})
	var healed: bool = new["heal_seq"] > old["heal_seq"]
	if healed:
		out.append({"signal": &"player_healed", "args": [id, new["last_rescuer_id"], new["hp"]]})
	if new["qte_chest"] >= 0 and (old["qte_chest"] < 0 or new["qte_started"] != old["qte_started"]):
		out.append({"signal": &"qte_started", "args": [id, new["qte_chest"]]})
	if new["qte_seq"] > old["qte_seq"]:
		out.append({"signal": &"qte_resolved", "args": [id, new["qte_result_chest"], new["qte_result"]]})
	if new["item_seq"] > old["item_seq"]:
		out.append({"signal": &"item_used", "args": [id, new["item_last_type"], new["item_target_id"], new["item_target_pos"]]})
	if new["coins"] != old["coins"]:
		out.append({"signal": &"coins_changed", "args": [id, new["coins"], new["coins"] - old["coins"]]})
	if new["teleport_left"] > 0.0 and old["teleport_left"] <= 0.0:
		out.append({"signal": &"teleport_started", "args": [id, new["teleport_pos"], new["teleport_left"]]})
	if new["stunned_left"] > 0.0 and old["stunned_left"] <= 0.0:
		out.append({"signal": &"player_stunned", "args": [id, new["stunned_left"]]})

	var a: int = old["state"]
	var b: int = new["state"]
	if a != b:
		out.append({"signal": &"player_state_changed", "args": [id, a, b]})
		match b:
			GameTypes.PlayerState.DOWNED:
				if a == GameTypes.PlayerState.CARRIED:
					out.append({"signal": &"player_dropped", "args": [id]})
				else:
					out.append({"signal": &"player_downed", "args": [id, new["last_attacker_id"]]})
			GameTypes.PlayerState.CARRIED:
				out.append({"signal": &"player_picked_up", "args": [id, new["carrier_id"]]})
			GameTypes.PlayerState.IMPRISONED:
				out.append({"signal": &"player_imprisoned", "args": [id, new["prison_id"]]})
			GameTypes.PlayerState.ESCAPED:
				out.append({"signal": &"player_escaped", "args": [id]})
			GameTypes.PlayerState.ELIMINATED:
				out.append({"signal": &"player_eliminated", "args": [id]})
			GameTypes.PlayerState.IDLE:
				if a == GameTypes.PlayerState.CARRIED and not healed:
					out.append({"signal": &"player_released", "args": [id]})
				elif a == GameTypes.PlayerState.DOWNED or a == GameTypes.PlayerState.IMPRISONED \
						or a == GameTypes.PlayerState.CARRIED:
					out.append({"signal": &"player_rescued", "args": [id, new["last_rescuer_id"]]})

	if not is_equal_approx(new["rescue_progress"], old["rescue_progress"]):
		out.append({"signal": &"rescue_progress_changed", "args": [id, new["rescue_progress"]]})
	return out
