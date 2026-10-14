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
var items := {} ## GameTypes.ItemType -> số lượng còn lại
var heal_seq := 0 ## tăng mỗi lần được dùng túi máu, để phân biệt "được cứu" với "được buông"
var invulnerable_left := 0.0
var attack_cooldown_left := 0.0
var stunned_left := 0.0
var attack_seq := 0 ## tăng mỗi lần thợ săn vung đòn, để client phát anim
var last_attacker_id := 0
var last_rescuer_id := 0

## Chỉ server dùng, không gửi đi.
var channel_left := 0.0 ## còn bao lâu thì hết trạng thái RESCUING nếu không cứu tiếp

const _SYNCED := [
	"role", "state", "hp", "max_hp", "imprison_count", "carrier_id", "carrying_id",
	"prison_id", "prison_time_left", "rescue_progress", "items", "heal_seq", "invulnerable_left",
	"attack_cooldown_left", "stunned_left", "attack_seq", "last_attacker_id", "last_rescuer_id",
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
		d[key] = v.duplicate() if v is Dictionary else v # bản sao để so cũ/mới không dùng chung
	return d


func apply_dict(d: Dictionary) -> void:
	for key: String in _SYNCED:
		if d.has(key):
			var v: Variant = d[key]
			set(key, v.duplicate() if v is Dictionary else v)


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
