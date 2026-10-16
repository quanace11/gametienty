extends RefCounted
## Cài đặt đồ họa Thấp / Vừa / Cao, lưu ở user://cai_dat.cfg. Menu chính gọi
## apply() lúc mở game và mỗi lần đổi: ghi mức vào ProjectSettings
## "game/graphics_quality" (0, 1, 2) để module khác đọc khi dựng hình (mô hình
## nhân vật, bóng đổ của bản đồ), rồi chỉnh viewport.
## Thấp: mô hình ~4,5k tam giác, texture 512, không bóng, vẽ 3D ở 75% độ phân
## giải, LOD gắt. Vừa: ~10k tam giác, texture 1024, có bóng, 100%. Cao: mô hình
## gốc ~31k tam giác, texture 2048 + normal map, có bóng, khử răng cưa MSAA 2x.
## Mặc định: điện thoại Thấp, máy tính Vừa. Dòng lệnh --quality=0|1|2 ghi đè.

const SETTING := "game/graphics_quality"
const FILE := "user://cai_dat.cfg"
const NAMES := ["Thấp", "Vừa", "Cao"]
const RENDER_SCALE := [0.75, 1.0, 1.0]
const LOD_THRESHOLD := [4.0, 1.0, 1.0] # pixel lỗi cho phép khi Godot tự hạ LOD mesh
const MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X]


static func current() -> int:
	return clampi(int(ProjectSettings.get_setting(SETTING, default_level())), 0, 2)


static func default_level() -> int:
	return 0 if OS.has_feature("mobile") else 1


## Đọc mức đã lưu (hoặc --quality=), ghi vào ProjectSettings và chỉnh viewport.
static func load_and_apply(viewport: Viewport) -> void:
	var level := default_level()
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		level = int(cfg.get_value("do_hoa", "muc", level))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			level = a.get_slice("=", 1).to_int()
	apply(viewport, level)


## Đổi mức (từ menu): lưu lại rồi áp dụng. Mô hình nhân vật đổi từ trận sau.
static func save_and_apply(viewport: Viewport, level: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("do_hoa", "muc", clampi(level, 0, 2))
	cfg.save(FILE)
	apply(viewport, level)


static func apply(viewport: Viewport, level: int) -> void:
	level = clampi(level, 0, 2)
	ProjectSettings.set_setting(SETTING, level)
	viewport.scaling_3d_scale = RENDER_SCALE[level]
	viewport.mesh_lod_threshold = LOD_THRESHOLD[level]
	viewport.msaa_3d = MSAA[level]
