class_name GameLog
extends RefCounted
## Ghi log có giờ, mã trận và số ghế: "[12:03:44.120][a1b2c3d4][ghế 1] Mở rương 3".
## Server riêng (--server) ghi thêm ra file user://logs/server_<ngày giờ>.log
## (Core/main mở file). Chỉ ghi sự kiện thưa (đổi trạng thái, rớt mạng, kết
## quả), không ghi mỗi frame.

static var match_id := "" ## mã trận đang chơi (Net đặt lúc vào trận)
static var _file: FileAccess


## Mở file log (gọi một lần lúc khởi động server riêng). Trả về đường dẫn thật.
static func open_file(path: String) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_file = FileAccess.open(path, FileAccess.WRITE)
	return ProjectSettings.globalize_path(path) if _file else ""


static func info(msg: String) -> void:
	_write("", msg)


static func warn(msg: String) -> void:
	_write("CẢNH BÁO ", msg)


static func _write(level: String, msg: String) -> void:
	var t := Time.get_time_dict_from_system()
	var seat := 0
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node(^"Net"):
		seat = tree.root.get_node(^"Net").my_seat()
	var line := "[%02d:%02d:%02d.%03d][%s][%d] %s%s" % [t["hour"], t["minute"], t["second"], Time.get_ticks_msec() % 1000,
		match_id if match_id != "" else "-", seat, level, msg]
	print(line)
	if _file:
		_file.store_line(line)
		_file.flush()
