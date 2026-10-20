extends RefCounted
## Danh sách nhân vật chọn ở sảnh, chia hai phe: Tiên Môn (đệ tử, chạy trốn)
## và Ma Đạo (ma tu, truy sát). Nhân vật đã chọn lưu ở user://cai_dat.cfg, lần
## sau mở game vẫn còn; mặc định là đệ tử đầu tiên. Vào trận thì tìm trận theo
## vai (Role) của nhân vật này.
## Hình 3D lấy đúng tệp mô hình nhân vật trong trận (PlayerCharacter.MODELS)
## nên đổi mô hình ở Player thì sảnh tự đổi theo.

const FILE := "user://cai_dat.cfg"
const SECTION := "nhan_vat"

## id: khóa lưu trong cài đặt. locked: chưa có mô hình, hiện ô "Sắp ra mắt".
const ALL: Array[Dictionary] = [
	{"id": "lang_van", "role": GameTypes.Role.ESCAPEE, "name": "Lăng Vân Kiếm Tu",
		"title": "Kiếm tu Thanh Vân Tông", "blurb": "Thân pháp nhẹ, giỏi phá cấm chế lấy linh thạch.", "locked": false},
	{"id": "bich_dao", "role": GameTypes.Role.ESCAPEE, "name": "Bích Dao Tiên Tử",
		"title": "Dược sư Bách Thảo Cốc", "blurb": "", "locked": true},
	{"id": "huyen_co", "role": GameTypes.Role.ESCAPEE, "name": "Huyền Cơ Phù Sư",
		"title": "Phù sư Thiên Cơ Các", "blurb": "", "locked": true},
	{"id": "huyet_anh", "role": GameTypes.Role.HUNTER, "name": "Huyết Ảnh Ma Quân",
		"title": "Tông chủ Huyết Sát Tông", "blurb": "Phi kiếm truy hồn, bắt đệ tử nhốt vào Ma Lao.", "locked": false},
	{"id": "u_minh", "role": GameTypes.Role.HUNTER, "name": "U Minh Quỷ Vương",
		"title": "Chủ nhân U Minh Cốc", "blurb": "", "locked": true},
	{"id": "xich_diem", "role": GameTypes.Role.HUNTER, "name": "Xích Diễm Ma Nữ",
		"title": "Thánh nữ Hỏa Ma Điện", "blurb": "", "locked": true},
]
const DEFAULT_ID := "lang_van"
const SIDE_NAMES := {GameTypes.Role.ESCAPEE: "TIÊN MÔN", GameTypes.Role.HUNTER: "MA ĐẠO"}
const SIDE_HINTS := {GameTypes.Role.ESCAPEE: "Đệ tử · phá cấm chế, trốn khỏi ma tu", GameTypes.Role.HUNTER: "Ma tu · truy bắt cả 4 đệ tử"}


static func by_id(id: String) -> Dictionary:
	for c: Dictionary in ALL:
		if c["id"] == id and not c["locked"]:
			return c
	return by_id(DEFAULT_ID) if id != DEFAULT_ID else ALL[0]


static func of_role(role: GameTypes.Role) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in ALL:
		if c["role"] == role:
			out.append(c)
	return out


static func load_selected() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	return by_id(str(cfg.get_value(SECTION, "chon", DEFAULT_ID)))


static func save_selected(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value(SECTION, "chon", id)
	cfg.save(FILE)


## Tệp mô hình của nhân vật theo mức đồ họa đang chọn (giống trong trận).
static func model_path(c: Dictionary) -> String:
	var files: Array = PlayerCharacter.MODELS[c["role"] == GameTypes.Role.HUNTER]
	var quality := clampi(int(ProjectSettings.get_setting(PlayerCharacter.QUALITY_SETTING, 0)), 0, files.size() - 1)
	return files[quality]
