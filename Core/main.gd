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
##   --perf-log                in các khung hình bị giật lúc đầu trận (tools/frame_probe.gd)
##   --config=duong/dan.tres   thông số trận (MatchConfig) cho server; mặc định Core/config/match_config.tres
##   --log=duong/dan.log       ghi log ra file; server riêng mặc định user://logs/server_<giờ>.log
##   --idle-hunter             (test) thợ săn đứng yên, để kiểm tra đường người trốn thoát qua cổng

const MatchScript = preload("res://Core/match/match.gd")
const RESULT_SCREEN_TIME := 4.0

var args := {}
var match_time := 180.0
var current_match: Node3D
var menu: CanvasLayer


func _ready() -> void:
	_parse_args()
	Net.bot = args.has("bot")
	if args.has("perf-log"):
		add_child(load("res://tools/frame_probe.gd").new())
	match_time = str(args.get("time", "180")).to_float()
	if args.has("name"):
		Net.my_name = str(args["name"])
	if args.has("config"):
		Net.config_path = str(args["config"])
	Net.idle_hunter = args.has("idle-hunter")
	if args.has("log") or args.has("server"):
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		var path := GameLog.open_file(str(args.get("log", "user://logs/server_%s.log" % stamp)))
		print("Ghi log ra %s" % path)

	menu = load(ModuleRegistry.MAIN_MENU).new()
	menu.match_time = match_time
	add_child(menu)

	Net.match_started.connect(_on_match_started)
	Net.players_changed.connect(_on_players_changed)
	Net.disconnected.connect(_on_disconnected)
	Net.status.connect(GameLog.info)
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
	if current_match: # trận cũ còn đang hiện bảng kết quả: bỏ luôn, không đụng Net / GameState
		remove_child(current_match)
		current_match.queue_free()
	current_match = MatchScript.new()
	current_match.name = "Match" # cùng đường dẫn node trên mọi máy để RPC tìm đúng
	add_child(current_match)
	current_match.setup(info)
	menu.visible = false


func _on_match_ended(_result: Dictionary) -> void:
	var ended := current_match
	await get_tree().create_timer(RESULT_SCREEN_TIME).timeout
	if ended != current_match:
		return # trận này đã đóng (mất kết nối) và đã sang trận khác: đừng đóng nhầm trận mới
	if args.has("quit-after-match"):
		get_tree().quit() # thoát luôn, khỏi để --auto-start mở trận mới ngay lúc đóng trận
		return
	_close_match()


func _on_disconnected() -> void:
	_close_match()
	if args.has("quit-after-match") and not Net.is_reconnecting():
		get_tree().quit()


func _close_match() -> void:
	if current_match:
		remove_child(current_match)
		current_match.queue_free()
		current_match = null
	GameState.clear()
	Net.end_match()
	if not Net.is_online():
		Net.players.clear() # hết trận offline thì về menu
	menu.visible = true
	menu.refresh()
