class_name GameTypes
extends RefCounted
## Enum và hằng số dùng chung cho mọi module. Chỉ Lead được sửa.

enum Role { HUNTER, ESCAPEE }

## Bảng chuyển trạng thái của người trốn (chỉ MatchRules được đổi):
##   IDLE/RESCUING --đánh hết máu--> DOWNED --bị túm--> CARRIED --kéo vào tù--> IMPRISONED
##   DOWNED --đồng đội giữ E / túi máu--> IDLE               CARRIED --bị thả--> DOWNED
##   CARRIED --túi máu / thợ săn hết máu--> IDLE           IMPRISONED --túi máu--> IDLE
##   IMPRISONED --bị đốt hết giờ (prison_time)--> ELIMINATED
##   IDLE/RESCUING --vào cổng đã mở--> ESCAPED
## Thợ săn luôn IDLE; người trốn không làm choáng được thợ săn. Thợ săn bị bắn hết máu
## thì buông người đang kéo, chạy chậm một lúc rồi hồi đầy máu. RUNNING để dành cho anim, luật không dùng.
enum PlayerState {
	IDLE,
	RUNNING,
	DOWNED, # hết máu, đang bò
	CARRIED, # bị thợ săn kéo lê phía sau, không tự làm gì được
	IMPRISONED, # gục trong nhà tù, đang bị đốt
	RESCUING, # đang cứu đồng đội
	ESCAPED, # đã thoát qua cổng
	ELIMINATED, # bị loại hẳn
}

## LOADING: các máy đang dựng bản đồ; server đợi mọi máy báo xong (có hạn) rồi mới đếm ngược.
## Thêm ở CUỐI để số của giá trị cũ không đổi.
enum MatchState { LOBBY, COUNTDOWN, PLAYING, ENDED, LOADING }

## Kết quả của thợ săn khi hết trận, theo số người trốn bị bắt (không thoát được).
## Với 4 người trốn: 0-1 thua, 2-3 thắng một phần, 4 thắng tuyệt đối.
enum HunterResult { LOSE, PARTIAL, TOTAL }

## Kết quả riêng từng người trốn.
enum EscapeeResult { CAUGHT, ESCAPED }

## Kết quả một lần căn vòng khi mở rương.
enum QteResult { NONE, PERFECT, GOOD, FAIL }

## Thẻ đạo cụ trong bộ bài. Cũng dùng làm loại vật thể đặt xuống đất (TRAP, JUMP_PAD, CRATE).
## Thêm loại mới ở CUỐI để số của loại cũ không đổi.
enum ItemType { MEDKIT, STUN_GRENADE, TRAP, JUMP_PAD, CRATE, SPEED_BOOST, PISTOL, DISGUISE, TELEPORT, RADAR }

## Loại đạn bay. Server tính đường bay và điểm rơi, client chỉ vẽ lại.
## RIFLE: súng của thợ săn, bay thẳng, trúng người trốn đầu tiên trên đường đạn.
## BULLET: đạn súng lục của người trốn, bay thẳng, trúng thì thợ săn mất máu.
enum ShotKind { RIFLE, BULLET }

## Group mà các module dùng để tìm nhau mà không cần biết class cụ thể.
const GROUP_ENTITIES := &"entities"
const GROUP_SAFES := &"safes"
const GROUP_EXIT_GATES := &"exit_gates"
const GROUP_PRISONS := &"prisons"
const GROUP_COINS := &"coins"
const GROUP_MAP := &"map" ## bản đồ đang chơi (MapBase), UI minimap và GameState đọc
const GROUP_JUMP_PADS := &"jump_pads" ## Node3D đệm lò xo (trong nhà tù, đặt từ bộ bài): bot tìm đường thoát

## Bot dùng id âm (-1, -2, ...), người thật dùng peer id của Godot (luôn dương).
static func is_bot_id(id: int) -> bool:
	return id < 0


## Không còn chạy ngoài bản đồ (bị nhốt, đã thoát, bị loại). Dùng để xét hết trận.
static func is_out(state: PlayerState) -> bool:
	return state == PlayerState.IMPRISONED or state == PlayerState.ESCAPED or state == PlayerState.ELIMINATED


## Đứng trên hai chân, tự hành động được (mở két, cứu người, bị đánh).
static func is_active(state: PlayerState) -> bool:
	return state == PlayerState.IDLE or state == PlayerState.RUNNING or state == PlayerState.RESCUING


static func role_name(role: Role) -> String:
	return "hunter" if role == Role.HUNTER else "escapee"
