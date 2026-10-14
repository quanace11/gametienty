extends Node
## Autoload "Net": tạo/vào phòng, danh sách người chơi, bắt đầu trận.
## Server (peer id 1) là nơi duy nhất quyết định luật chơi. Server có thể là
## máy một người chơi (host), server riêng không chơi, hoặc chính máy mình khi
## chơi offline (OfflineMultiplayerPeer, vẫn chạy đúng đường code server).

signal players_changed
signal match_started(info: Dictionary)
signal player_left(id: int)
signal status(msg: String)
signal disconnected

const PORT := 7777
const MAX_PLAYERS := 5 # 1 thợ săn + 4 người trốn

var players := {} # peer_id -> {"name": String}
var my_name := "Player"
var in_match := false
var bot := false # máy này để bot tự điều khiển nhân vật của mình (test)


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


## Chỉ server: độ trễ một chiều ước tính tới máy `peer_id` (giây). Bot và
## người chơi ngay trên server là 0. Dùng để bù trễ khi chấm thời điểm bấm nút.
func latency_of(peer_id: int) -> float:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or peer_id <= 1:
		return 0.0
	var packet_peer := enet.get_peer(peer_id)
	if packet_peer == null:
		return 0.0
	return packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 2000.0


func host(port: int = PORT, play: bool = true) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		status.emit("Không mở được cổng %d (lỗi %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	players.clear()
	if play:
		players[1] = {"name": my_name}
	status.emit("Đã tạo phòng ở cổng %d" % port)
	players_changed.emit()
	return OK


func join(ip: String, port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		status.emit("Không tạo được kết nối (lỗi %d)" % err)
		return err
	multiplayer.multiplayer_peer = peer
	status.emit("Đang vào phòng %s:%d..." % [ip, port])
	return OK


## Chơi một mình với bot. Máy mình vẫn là "server", không mở cổng mạng.
func start_offline(match_time: float, my_role: int) -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {1: {"name": my_name}}
	start_match(match_time, true, my_role)


func leave() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	in_match = false
	disconnected.emit()


## Chỉ server. fill_bots: thêm bot cho đủ MAX_PLAYERS.
## host_role: GameTypes.Role muốn cho chủ phòng, -1 = ngẫu nhiên.
func start_match(match_time: float = 180.0, fill_bots: bool = false, host_role: int = -1) -> void:
	if not multiplayer.is_server() or in_match:
		return
	var ids := players.keys()
	ids.sort()
	var names := {}
	for id: int in ids:
		names[id] = players[id]["name"]
	if fill_bots:
		for i in MAX_PLAYERS - ids.size():
			var bot_id := -(i + 1)
			ids.append(bot_id)
			names[bot_id] = "Bot %d" % (i + 1)
	if ids.size() < 2:
		return

	var hunter: int = ids.pick_random()
	if players.has(1) and host_role == GameTypes.Role.HUNTER:
		hunter = 1
	elif players.has(1) and host_role == GameTypes.Role.ESCAPEE:
		hunter = ids.filter(func(id: int) -> bool: return id != 1).pick_random()
	var roles := {}
	for id: int in ids:
		roles[id] = GameTypes.Role.HUNTER if id == hunter else GameTypes.Role.ESCAPEE
	_begin.rpc({"roles": roles, "names": names, "time": match_time})


@rpc("authority", "call_local", "reliable")
func _begin(info: Dictionary) -> void:
	in_match = true
	match_started.emit(info)


func _on_connected() -> void:
	status.emit("Đã vào phòng")
	_register.rpc_id(1, my_name)


@rpc("any_peer", "reliable")
func _register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_match or players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	players[id] = {"name": player_name.strip_edges().left(16)}
	_sync_players.rpc(players)
	players_changed.emit()


@rpc("authority", "reliable")
func _sync_players(p: Dictionary) -> void:
	players = p
	players_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	players.erase(id)
	_sync_players.rpc(players)
	players_changed.emit()
	player_left.emit(id)


func _on_connection_failed() -> void:
	leave()
	status.emit("Không vào được phòng")


func _on_server_disconnected() -> void:
	leave()
	status.emit("Mất kết nối với chủ phòng")
