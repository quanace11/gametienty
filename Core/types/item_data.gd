class_name ItemData
extends Resource
## Dữ liệu một thẻ kỹ năng / vật phẩm. Module Items tạo các file .tres từ đây.

@export var id: StringName
@export var type: GameTypes.ItemType = GameTypes.ItemType.DISGUISE
@export var display_name := ""
@export var icon: Texture2D
@export var cooldown := 10.0 # giây
@export var duration := 0.0 # giây, 0 = dùng một lần
@export var allowed_roles: Array[GameTypes.Role] = [GameTypes.Role.ESCAPEE]
