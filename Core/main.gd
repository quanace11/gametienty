extends Node
## Gốc của game: đọc tham số dòng lệnh, hiện menu, mở/đóng trận.
##
## Tham số (đặt sau "--"):
##   --offline=hunter|escapee  chơi offline với bot
##   --server                  server riêng, không chơi (dùng khi thuê VPS)
##   --host                    tạo phòng và chơi luôn
##   --join=IP                 vào phòng
##   --port=7777  --name=Ten  --time=180
##   --auto-start=N            server tự bắt đầu khi đủ N người
##   --fill-bots               thêm bot cho đủ 5 người khi bắt đầu
##   --bot                     bot tự điều khiển nhân vật của máy này (test)
##   --quit-after-match        thoát sau một trận (test)

const MatchScript = preload("res://Core/match/match.gd")
const RESULT_SCREEN_TIME := 4.0

var args := {}
var match_time := 180.0
var current_match: Node2D
var menu: CanvasLayer


func _ready() -> void:
	_parse_args()
	Net.bot = args.has("bot")
	match_time = str(args.get("time", "180")).to_float()
	if args.has("name"):
		Net.my_name = str(args["name"])

	menu = load(ModuleRegistry.MAIN_MENU).new()
	menu.match_time = match_time
	add_child(menu)

	Net.match_started.connect(_on_match_started)
	Net.players_changed.connect(_on_players_changed)
	Net.disconnected.connect(_on_disconnected)
	Net.status.connect(func(msg: String) -> void: print("[%d] %s" % [multiplayer.get_unique_id(), msg]))
	EventBus.match_ended.connect(_on_match_ended)

	var port := str(args.get("port", str(Net.PORT))).to_int()
	if args.has("offline"):
		var role := GameTypes.Role.HUNTER if args["offline"] == "hunter" else GameTypes.Role.ESCAPEE
		Net.start_offline(match_time, role)
	elif args.has("server"):
		Net.host(port, false)
	elif args.has("host"):
		Net.host(port, true)
	elif args.has("join"):
		Net.join(str(args["join"]), port)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else true


func _on_players_changed() -> void:
	var auto_start := str(args.get("auto-start", "0")).to_int()
	if multiplayer.is_server() and auto_start > 0 and not Net.in_match and Net.players.size() >= auto_start:
		Net.start_match(match_time, args.has("fill-bots"))


func _on_match_started(info: Dictionary) -> void:
	current_match = MatchScript.new()
	current_match.name = "Match" # cùng đường dẫn node trên mọi máy để RPC tìm đúng
	add_child(current_match)
	current_match.setup(info)
	menu.visible = false


func _on_match_ended(_winner: GameTypes.Winner, _summary: Dictionary) -> void:
	await get_tree().create_timer(RESULT_SCREEN_TIME).timeout
	_close_match()
	if args.has("quit-after-match"):
		get_tree().quit()


func _on_disconnected() -> void:
	_close_match()
	if args.has("quit-after-match"):
		get_tree().quit()


func _close_match() -> void:
	if current_match:
		remove_child(current_match)
		current_match.queue_free()
		current_match = null
	GameState.clear()
	Net.in_match = false
	if not Net.is_online():
		Net.players.clear() # hết trận offline thì về menu
	menu.visible = true
	menu.refresh()
