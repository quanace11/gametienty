class_name ModuleRegistry
extends RefCounted
## Nơi duy nhất Core biết module nào cài đặt interface nào.
## Đổi bản cài đặt (bản đồ khác, HUD khác...) thì chỉ sửa ở đây.

const ENTITY := "res://Player/player_character.gd" # extends EntityBase
const LOCAL_INPUT := "res://Player/local_input_source.gd" # extends InputSource
const BOT_INPUT := "res://AI/bot_input_source.gd" # extends InputSource
const MAP := "res://Objects/maps/test_map.gd" # extends MapBase
const HUD := "res://UI/hud.gd"
const MAIN_MENU := "res://UI/main_menu.gd"
