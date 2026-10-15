class_name ItemData
extends Resource
## Dữ liệu một thẻ đạo cụ. Module Items khai báo trong ItemCatalog. Core chỉ
## đọc cost / cooldown để kiểm tra khi dùng; hiệu ứng nằm ở `effect_script`.

@export var type: GameTypes.ItemType = GameTypes.ItemType.MEDKIT
@export var display_name := ""
@export var icon: Texture2D
@export var cost := 0 ## tiền mỗi lần kích hoạt
@export var cooldown := 10.0 ## giây
## Kéo thẻ để chọn chỗ ném / đặt (kiểu kỹ năng định hướng): tầm xa nhất, mét.
## 0 = không kéo được, chạm là dùng (radar, ván trượt...).
@export var aim_range := 0.0
@export var area_radius := 0.0 ## bán kính vùng tác dụng chỗ rơi, mét (vòng vẽ khi kéo)
@export var allowed_roles: Array[GameTypes.Role] = [GameTypes.Role.ESCAPEE]
@export_file("*.gd") var effect_script := "" ## extends ItemEffect


func _init(p_type: GameTypes.ItemType = GameTypes.ItemType.MEDKIT, p_name: String = "", p_cost: int = 0,
		p_cooldown: float = 10.0, p_effect: String = "") -> void:
	type = p_type
	display_name = p_name
	cost = p_cost
	cooldown = p_cooldown
	effect_script = p_effect
