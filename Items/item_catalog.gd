class_name ItemCatalog
extends RefCounted
## Bảng thẻ đạo cụ: giá (tiền mỗi lần dùng), hồi chiêu, hiệu ứng. Core đọc qua
## ModuleRegistry.ITEM_CATALOG. Đổi cân bằng thẻ ở đây.

const T := GameTypes.ItemType


static func all() -> Dictionary:
	var items := {}
	for it: ItemData in [
		# Kéo thẻ để chọn chỗ ném (tầm, bán kính vùng); chạm nhanh thì dưới chân.
		_aimed(ItemData.new(T.MEDKIT, "Túi cứu thương", 10, 6.0, "res://Items/effects/medkit.gd"), 8.0, 2.0),
		_aimed(ItemData.new(T.STUN_GRENADE, "Lựu đạn làm chậm", 10, 12.0, "res://Items/effects/stun_grenade.gd"), 8.0, 2.5),
		ItemData.new(T.SPEED_BOOST, "Ván trượt", 5, 12.0, "res://Items/effects/speed_boost.gd"),
		_aimed(ItemData.new(T.JUMP_PAD, "Đệm lò xo", 6, 8.0, "res://Items/effects/jump_pad.gd"), 6.0, 0.6),
		_aimed(ItemData.new(T.TRAP, "Bẫy kẹp", 6, 10.0, "res://Items/effects/trap.gd"), 4.0, 0.6),
		_aimed(ItemData.new(T.CRATE, "Hộp gỗ", 5, 10.0, "res://Items/effects/crate.gd"), 4.0, 0.8),
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


static func _aimed(it: ItemData, aim_range: float, area: float) -> ItemData:
	it.aim_range = aim_range
	it.area_radius = area
	return it


static func _hunter(it: ItemData) -> ItemData:
	it.allowed_roles = [GameTypes.Role.HUNTER]
	return it
