class_name GameTypes
extends RefCounted
## Enum và hằng số dùng chung cho mọi module. Chỉ Lead được sửa.

enum Role { HUNTER, ESCAPEE }

enum PlayerState {
	IDLE,
	RUNNING,
	DOWNED, # hết máu, đang bò
	CARRIED, # bị thợ săn vác
	IMPRISONED, # trong nhà tù
	RESCUING, # đang cứu đồng đội
	ESCAPED, # đã thoát qua cổng
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


## Người đã bị nhốt hoặc đã thoát thì không còn tham gia di chuyển.
static func is_out(state: PlayerState) -> bool:
	return state == PlayerState.IMPRISONED or state == PlayerState.ESCAPED


static func role_name(role: Role) -> String:
	return "hunter" if role == Role.HUNTER else "escapee"
