class_name ItemCatalog
extends RefCounted
## Bảng thẻ đạo cụ: giá (tiền mỗi lần dùng), hồi chiêu, hiệu ứng. Core đọc qua
## ModuleRegistry.ITEM_CATALOG. Đổi cân bằng thẻ ở đây.

const T := GameTypes.ItemType


static func all() -> Dictionary:
	var items := {}
	for it: ItemData in [
		ItemData.new(T.MEDKIT, "Túi cứu thương", 10, 6.0, "res://Items/effects/medkit.gd"),
		ItemData.new(T.STUN_GRENADE, "Lựu đạn choáng", 10, 12.0, "res://Items/effects/stun_grenade.gd"),
		ItemData.new(T.SPEED_BOOST, "Ván trượt", 5, 12.0, "res://Items/effects/speed_boost.gd"),
		ItemData.new(T.JUMP_PAD, "Đệm lò xo", 6, 8.0, "res://Items/effects/jump_pad.gd"),
		ItemData.new(T.TRAP, "Bẫy kẹp", 6, 10.0, "res://Items/effects/trap.gd"),
		ItemData.new(T.CRATE, "Hộp gỗ", 5, 10.0, "res://Items/effects/crate.gd"),
		ItemData.new(T.PISTOL, "Súng lục", 4, 1.5, "res://Items/effects/pistol.gd"),
		_hunter(ItemData.new(T.RADAR, "Radar dấu chân", 0, 15.0, "res://Items/effects/radar.gd")),
		_hunter(ItemData.new(T.TELEPORT, "Dịch chuyển", 0, 30.0, "res://Items/effects/teleport.gd")),
	]:
		items[it.type] = it
	return items


## Bộ bài mặc định khi người chơi chưa chọn (thứ tự = ô 1, 2, 3, 4, 5).
static func default_deck(role: GameTypes.Role) -> Array:
	if role == GameTypes.Role.ESCAPEE:
		return [T.MEDKIT, T.STUN_GRENADE, T.PISTOL, T.SPEED_BOOST, T.JUMP_PAD]
	return [T.RADAR, T.TELEPORT]


## Thẻ chọn được cho bộ bài của vai `role` (màn chọn bài dùng).
static func choices(role: GameTypes.Role) -> Array:
	var out := []
	for it: ItemData in all().values():
		if role in it.allowed_roles:
			out.append(it.type)
	return out


static func _hunter(it: ItemData) -> ItemData:
	it.allowed_roles = [GameTypes.Role.HUNTER]
	return it


static func display_name(type: int) -> String:
	var it: ItemData = all().get(type)
	return it.display_name if it else "?"
