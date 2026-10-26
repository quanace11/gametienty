class_name BotLevel
extends RefCounted
## Độ khó của bot: bộ số quyết định bot thấy xa bao nhiêu, phản ứng nhanh
## chậm, căn vòng trúng bao nhiêu, có né đạn / nấp bụi / ngắm đón đầu không.
## Mọi mức đều chỉ thấy những gì người chơi cùng vai thấy trên màn hình.
##
## Chọn mức: tham số dòng lệnh `--bot-level=de|tb|kho` (hoặc easy / medium / hard,
## 0 / 1 / 2), không có thì đọc ProjectSettings "game/bot_level" (menu ghi vào).
## Mức chọn áp cho bot phe địch của người chơi máy này; bot cùng phe (đồng đội,
## bot chơi thay mình) luôn ở mức Trung bình. Máy không có người chơi (server
## riêng) thì mọi bot theo mức chọn. Test cân bằng: `--bot-level-hunter=` /
## `--bot-level-escapee=` đặt riêng từng phe.
## Mức do máy chạy bot quyết (server), máy khác không cần biết.

enum Level { EASY, MEDIUM, HARD }

const SETTING := "game/bot_level"
const ARG := "--bot-level="
const ARG_ROLE := ["--bot-level-hunter=", "--bot-level-escapee="] # theo GameTypes.Role
const ALLY_LEVEL := Level.MEDIUM
const NAMES: Array[String] = ["Dễ", "Trung bình", "Khó"]
const ARG_NAMES := {
	"de": Level.EASY, "easy": Level.EASY, "0": Level.EASY,
	"tb": Level.MEDIUM, "medium": Level.MEDIUM, "1": Level.MEDIUM,
	"kho": Level.HARD, "hard": Level.HARD, "2": Level.HARD,
}

var level := Level.MEDIUM
## Nửa khung nhìn quanh mình (x, z) theo mét. Camera điện thoại thấy chừng 9 x 6,5 m
## mỗi bên; bot không thấy xa hơn người chơi.
var sight := Vector2(8.0, 6.0)
var reaction := 0.35 ## giây từ lúc phe kia lọt vào khung nhìn tới lúc bot phản ứng
var memory := 3.0 ## giây còn nhớ chỗ thấy phe kia lần cuối (đuổi / né theo trí nhớ)
var qte_perfect := 0.65 ## tỉ lệ căn trúng vùng đậm
var qte_good := 0.25 ## tỉ lệ căn trúng vùng mờ, còn lại trượt
var flee_dist := 6.0 ## người trốn: thợ săn gần hơn chừng này thì chạy
var wary_dist := 8.0 ## người trốn: thợ săn đang lao tới trong tầm này thì bỏ rương chạy sớm (0 = không)
var dodge_chance := 0.5 ## người trốn: tỉ lệ thấy đạn bay tới thì bước ngang né
var juke := 0.5 ## người trốn: bị đuổi trong tầm súng thì chạy chữ chi (0 = chạy thẳng), thợ săn khó đón đầu
var hide_in_bush := true ## người trốn: chạy vào bụi cây gần, đứng im khi thợ săn mất dấu
var smart_chest := true ## người trốn: chọn rương xa thợ săn, gần xong; cổng bị canh thì chạy cổng kia
var team_rescue := true ## người trốn: chỉ người gần nhất đi cứu, người khác làm tiếp việc mình
var item_chance := 0.4 ## mỗi lần nghĩ (10 lần/giây) có chừng này phần dùng thẻ khi đúng lúc
var aim_lead := 0.4 ## thợ săn: 0 bắn chỗ người đang đứng, 1 đón đầu đủ theo hướng chạy
var aim_error := 9.0 ## thợ săn: độ lệch ngẫu nhiên khi ngắm (độ)
var fire_delay := 0.6 ## thợ săn: súng hồi xong chừng này giây mới bóp cò (người thật không bắn đúng tích tắc)
var shoot_dist := 8.0 ## thợ săn: bắn khi người trốn gần hơn chừng này
var use_radar := true ## thợ săn: mất dấu thì bật radar, đi theo dấu chân
var use_teleport := true
var smart_patrol := true ## thợ săn: mất dấu thì canh rương gần xong / cổng đang mở, không đi lung tung
var hesitate := 0.05 ## mỗi giây có chừng này phần đứng ngẩn ra một lúc (bot dễ)


## Mức đang chọn: tham số dòng lệnh trước, rồi tới cài đặt của menu.
static func current() -> Level:
	var arg := _arg(ARG)
	if arg >= 0:
		return arg as Level
	return clampi(int(ProjectSettings.get_setting(SETTING, Level.MEDIUM)), Level.EASY, Level.HARD) as Level


## Mức cho một bot vai `role` (GameTypes.Role).
static func for_role(role: int) -> Level:
	var arg := _arg(ARG_ROLE[role])
	if arg >= 0:
		return arg as Level
	var mine := GameState.my_role()
	return ALLY_LEVEL if mine >= 0 and mine == role else current()


static func _arg(prefix: String) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return ARG_NAMES.get(a.substr(prefix.length()).to_lower(), -1)
	return -1


static func make(l: Level) -> BotLevel:
	var b := BotLevel.new()
	b.level = l
	match l:
		Level.EASY:
			b.sight = Vector2(6.5, 5.0)
			b.reaction = 0.7
			b.memory = 1.5
			b.qte_perfect = 0.3
			b.qte_good = 0.4
			b.flee_dist = 3.0
			b.wary_dist = 0.0
			b.dodge_chance = 0.1
			b.juke = 0.0
			b.hide_in_bush = false
			b.smart_chest = false
			b.team_rescue = false
			b.item_chance = 0.12
			b.aim_lead = 0.0
			b.aim_error = 14.0
			b.shoot_dist = 7.0
			b.fire_delay = 0.9
			b.use_radar = false
			b.use_teleport = false
			b.smart_patrol = false
			b.hesitate = 0.25
		Level.HARD:
			b.sight = Vector2(9.0, 6.5)
			b.reaction = 0.15
			b.memory = 5.0
			b.qte_perfect = 0.9
			b.qte_good = 0.08
			b.flee_dist = 8.0
			b.wary_dist = 10.0
			b.dodge_chance = 0.9
			b.juke = 0.8
			b.item_chance = 1.0
			b.aim_lead = 1.0
			b.aim_error = 3.0
			b.shoot_dist = 11.0
			b.fire_delay = 0.1
			b.hesitate = 0.0
	return b
