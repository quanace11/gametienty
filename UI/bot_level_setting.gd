extends RefCounted
## Độ khó bot Dễ / Trung bình / Khó, lưu ở user://cai_dat.cfg. Menu chính gọi
## load_and_apply() lúc mở game và save_and_apply() mỗi lần đổi: ghi mức vào
## ProjectSettings "game/bot_level" (0, 1, 2) để AI đọc khi vào trận
## (AI/bot_level.gd). Mức áp cho bot phe địch; bot đồng đội luôn Trung bình.
## Chỉ máy chạy bot (máy chơi offline, chủ phòng) cần cài đặt này.

const SETTING := "game/bot_level"
const FILE := "user://cai_dat.cfg"
const NAMES := ["Dễ", "Trung bình", "Khó"]
const DEFAULT_LEVEL := 1


static func current() -> int:
	return clampi(int(ProjectSettings.get_setting(SETTING, DEFAULT_LEVEL)), 0, NAMES.size() - 1)


static func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	ProjectSettings.set_setting(SETTING, clampi(int(cfg.get_value("bot", "muc", DEFAULT_LEVEL)), 0, NAMES.size() - 1))


static func save_and_apply(level: int) -> void:
	level = clampi(level, 0, NAMES.size() - 1)
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("bot", "muc", level)
	cfg.save(FILE)
	ProjectSettings.set_setting(SETTING, level)
