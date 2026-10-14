class_name GameTypes
extends RefCounted
## Enum và hằng số dùng chung cho mọi module. Chỉ Lead được sửa.

enum Role { HUNTER, ESCAPEE }

## Bảng chuyển trạng thái của người trốn (chỉ MatchRules được đổi):
##   IDLE/RESCUING --đánh hết máu--> DOWNED --nhấc lên--> CARRIED --vào tù--> IMPRISONED
##   CARRIED --vùng thoát / thợ săn bị choáng--> IDLE        CARRIED --bị thả--> DOWNED
##   DOWNED --đồng đội cứu--> IDLE                           IMPRISONED --đồng đội phá khóa--> IDLE
##   IMPRISONED --hết giờ / bị nhốt quá số lần--> ELIMINATED
##   IDLE/RESCUING --vào cổng đã mở--> ESCAPED
## Thợ săn luôn IDLE. RUNNING để dành cho anim, luật không dùng.
enum PlayerState {
	IDLE,
	RUNNING,
	DOWNED, # hết máu, đang bò
	CARRIED, # bị thợ săn vác
	IMPRISONED, # trong nhà tù
	RESCUING, # đang cứu đồng đội
	ESCAPED, # đã thoát qua cổng
	ELIMINATED, # bị loại hẳn
}

enum MatchState { LOBBY, COUNTDOWN, PLAYING, ENDED }

enum Winner { NONE, HUNTER, ESCAPEES }

enum ItemType { DISGUISE, BARRIER, SPEED_SHOES, GUN }

## Group mà các module dùng để tìm nhau mà không cần biết class cụ thể.
const GROUP_ENTITIES := &"entities"
const GROUP_SAFES := &"safes"
const GROUP_EXIT_GATES := &"exit_gates"
const GROUP_PRISONS := &"prisons"

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
