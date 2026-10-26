extends RefCounted
## Cài đặt đồ họa Thấp / Vừa / Cao, lưu ở user://cai_dat.cfg. Menu chính gọi
## apply() lúc mở game và mỗi lần đổi: ghi mức vào ProjectSettings
## "game/graphics_quality" (0, 1, 2) để module khác đọc khi dựng hình (mô hình
## nhân vật, bóng đổ của bản đồ), rồi chỉnh viewport.
## Thấp: ma tu ~6k tam giác, không bóng, LOD gắt. Mọi mức vẽ 3D đủ 100% độ phân giải: vẽ thấp hơn rồi
## phóng lên làm cả trận nhòe như phim mờ (nền sân, chữ trên đầu), máy yếu bớt tải bằng bóng, LOD, vân nền.
## Vừa: ma tu ~20k tam giác, có bóng, 100%. Cao: ma tu ~60k tam giác, có bóng,
## khử răng cưa MSAA 2x.
## Mặc định: điện thoại Thấp, máy tính Vừa. Dòng lệnh --quality=0|1|2 ghi đè.
## Khung hình: 30 / 60 / Tối đa (không khóa, cho màn 90/120 Hz), lưu riêng. Mặc định
## 60: màn 90/120 Hz không vẽ thừa, đỡ nóng máy, tốn pin.

const SETTING := "game/graphics_quality"
const FILE := "user://cai_dat.cfg"
const NAMES := ["Thấp", "Vừa", "Cao"]
const RENDER_SCALE := [1.0, 1.0, 1.0]
const LOD_THRESHOLD := [4.0, 1.0, 1.0] # pixel lỗi cho phép khi Godot tự hạ LOD mesh
const MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X]
const FPS_CHOICES := [30, 60, 0] # 0 = không khóa
const FPS_NAMES := ["30", "60", "Tối đa"]
const DEFAULT_FPS := 1


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
	apply_fps(int(cfg.get_value("do_hoa", "fps", DEFAULT_FPS)))


static func current_fps() -> int:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	return clampi(int(cfg.get_value("do_hoa", "fps", DEFAULT_FPS)), 0, FPS_CHOICES.size() - 1)


## Đổi khung hình (từ menu): lưu lại rồi áp dụng ngay.
static func save_and_apply_fps(choice: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("do_hoa", "fps", clampi(choice, 0, FPS_CHOICES.size() - 1))
	cfg.save(FILE)
	apply_fps(choice)


static func apply_fps(choice: int) -> void:
	Engine.max_fps = FPS_CHOICES[clampi(choice, 0, FPS_CHOICES.size() - 1)]


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
