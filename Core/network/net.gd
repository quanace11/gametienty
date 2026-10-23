extends Node
## Autoload "Net": tạo/vào phòng, danh sách người chơi, bắt đầu trận.
## Server (peer id 1) là nơi duy nhất quyết định luật chơi. Server có thể là
## máy một người chơi (host), server riêng không chơi, hoặc chính máy mình khi
## chơi offline (OfflineMultiplayerPeer, vẫn chạy đúng đường code server).
##
## Ghế (seat): mỗi người chơi có một số ghế cố định cả trận, bằng peer id lúc
## vào phòng. Nhân vật, PlayerRecord, kết quả đều theo số ghế. Rớt mạng thì
## peer id mất nhưng ghế còn: bot vào thay, chơi tiếp đúng nhân vật đó. Ghế
## giữ tới hết trận; máy cũ vào lại bằng mã vào lại (token) thì tiếp quản
## nhân vật ở đúng trạng thái hiện tại (không hồi máu, không sống lại; đã bị
## loại / đã thoát thì chỉ xem), dù peer id mới khác. Code
## gameplay chỉ dùng số ghế; đổi qua lại với peer id bằng seat_of() / peer_of().

signal players_changed
signal match_started(info: Dictionary)
signal player_left(seat: int) ## chỉ server: ghế `seat` mất kết nối (giữa trận thì bot vào thay)
signal player_returned(seat: int) ## chỉ server: ghế `seat` có máy vào lại giữa trận
signal status(msg: String)
signal disconnected

const PORT := 7777
const MAX_PLAYERS := 5 # 1 thợ săn + 4 người trốn
const PROTOCOL_VERSION := 2 ## tăng mỗi khi đổi gói tin, enum hay thứ tự trường đồng bộ; khác số thì không vào được phòng
const EXTRA_PEERS := 3 ## chỗ ENet chừa thêm cho máy vào lại khi kết nối cũ chưa hết hạn
const REGISTER_TIMEOUT := 5.0 ## giây: kết nối không đăng ký tên trong chừng này thì bị cắt (khỏi giữ chỗ phòng)
const REJOIN_MARGIN := 15.0 ## giây client thử vào lại thêm sau giờ hết trận dự kiến
const RECONNECT_INTERVAL := 3.0 ## giây giữa hai lần thử vào lại
## Số gói tối đa mỗi giây một máy được gửi, theo loại. Vượt thì bỏ gói;
## vượt liên tục KICK_AFTER giây thì bị đá ra (bot vào thay).
const RATE_LIMITS := {&"input": 45, &"aim_point": 15, &"register": 3, &"loaded": 3}
const KICK_AFTER := 5.0
## ENet coi như rớt mạng khi không nhận được gì trong chừng này ms (mặc định
## tới 30 giây). Ngắn hơn để bot vào thay sớm, đủ dài để mạng điện thoại khựng 2-3 giây không bị tính là rớt.
const PEER_TIMEOUT_MIN := 4000
const PEER_TIMEOUT_MAX := 8000

enum Reject { VERSION, FULL, IN_MATCH, SEAT_EXPIRED }
const REJECT_TEXT := {
	Reject.VERSION: "Khác phiên bản với chủ phòng, cần cập nhật game",
	Reject.FULL: "Phòng đã đủ người",
	Reject.IN_MATCH: "Phòng đang trong trận",
	Reject.SEAT_EXPIRED: "Trận đã kết thúc, không vào lại được",
}

var players := {} # seat -> {"name": String, "deck": Array (ItemType người trốn tự chọn)}
var my_name := "Player"
var my_deck := [] ## bộ bài người trốn chọn ở menu (rỗng = mặc định). Luật tự lọc thẻ sai.
var in_match := false
var bot := false # máy này để bot tự điều khiển nhân vật của mình (test)
var idle_hunter := false ## chỉ server, test: thợ săn đứng yên (kiểm tra đường người trốn thoát)
var config_path := "res://Core/config/match_config.tres" ## chỉ server: file MatchConfig của trận

var _my_seat := 0 # 0 = chưa có ghế (dùng peer id)
var _my_token := 0
var _last_ip := ""
var _last_port := PORT
var _reconnect_until := 0.0 # giây (Time.get_ticks_msec / 1000); > 0 = đang thử vào lại
var _reconnect_timer := 0.0
var _rejected := false

# Chỉ server:
var _seat_of_peer := {} # peer -> seat
var _peer_of_seat := {} # seat -> peer (không có = ghế đang trống, bot chơi thay)
var _tokens := {} # seat -> mã vào lại
var _away_since := {} # seat -> giây lúc rớt (ghế giữ tới hết trận)
var _unregistered := {} # peer -> giây lúc kết nối
var _rate := {} # peer -> {kind: [giây bắt đầu cửa sổ, số gói]}
var _over_since := {} # peer -> giây bắt đầu vượt giới hạn liên tục
var _match_info := {} # thông tin trận đang chơi, gửi lại cho máy vào lại


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if _reconnect_until > 0.0:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0.0:
			_try_reconnect()
		return
	if _unregistered.is_empty() or not multiplayer.is_server():
		return
	var now := _now()
	for peer: int in _unregistered.keys():
		if now - _unregistered[peer] > REGISTER_TIMEOUT:
			_unregistered.erase(peer)
			_log("Cắt kết nối %d: không đăng ký" % peer)
			multiplayer.multiplayer_peer.disconnect_peer(peer)


func is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


## Số ghế của máy này (chủ phòng / offline là 1).
func my_seat() -> int:
	return _my_seat if _my_seat != 0 else multiplayer.get_unique_id()


## Chỉ server: ghế của máy `peer`, 0 nếu máy đó chưa có ghế.
func seat_of(peer: int) -> int:
	if peer == multiplayer.get_unique_id():
		return my_seat()
	return _seat_of_peer.get(peer, 0)


## Chỉ server: peer id đang ngồi ghế `seat`, 0 nếu ghế trống (rớt mạng) hoặc là bot.
func peer_of(seat: int) -> int:
	if seat == my_seat() and players.has(seat):
		return multiplayer.get_unique_id()
	return _peer_of_seat.get(seat, 0)


## Chỉ server: ghế này đang có máy kết nối (không phải bot, không rớt).
func is_connected_seat(seat: int) -> bool:
	return peer_of(seat) != 0


## Đang thử vào lại trận sau khi rớt mạng.
func is_reconnecting() -> bool:
	return _reconnect_until > 0.0


## Chỉ server: độ trễ một chiều ước tính tới ghế `seat` (giây). Bot và
## người chơi ngay trên server là 0. Dùng để bù trễ khi chấm thời điểm bấm nút.
func latency_of(seat: int) -> float:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var peer := peer_of(seat)
	if enet == null or peer <= 1:
		return 0.0
	var packet_peer := enet.get_peer(peer)
	if packet_peer == null:
		return 0.0
	return packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 2000.0


## Client: độ trễ một chiều ước tính tới server (giây), 0 nếu chính là server.
func server_latency() -> float:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or multiplayer.is_server():
		return 0.0
	var packet_peer := enet.get_peer(1)
	if packet_peer == null:
		return 0.0
	return packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 2000.0


## Chỉ server: máy `peer` còn được gửi gói loại `kind` không (RATE_LIMITS).
## Gửi quá giới hạn thì bỏ gói; quá liên tục KICK_AFTER giây thì bị đá.
func allow(peer: int, kind: StringName) -> bool:
	if peer <= 1:
		return true
	var limit: int = RATE_LIMITS.get(kind, 10)
	var now := _now()
	var per_peer: Dictionary = _rate.get(peer, {})
	if per_peer.is_empty():
		_rate[peer] = per_peer
	var w: Array = per_peer.get(kind, [now, 0])
	if now - w[0] >= 1.0:
		w[0] = now
		w[1] = 0
	w[1] += 1
	per_peer[kind] = w
	if w[1] <= limit:
		if w[1] == limit and _over_since.has(peer) and now - w[0] < 0.5:
			pass # vừa chạm giới hạn: chưa tính là hết vượt
		elif w[1] < limit / 2:
			_over_since.erase(peer)
		return true
	if not _over_since.has(peer):
		_over_since[peer] = now
	elif now - _over_since[peer] > KICK_AFTER:
		kick(peer, "gửi quá nhiều gói (%s)" % kind)
	return false


## Chỉ server: đá máy `peer` ra (gửi dữ liệu sai, spam). Giữa trận thì bot vào thay.
func kick(peer: int, reason: String) -> void:
	if peer <= 1 or not multiplayer.is_server() or not peer in multiplayer.get_peers():
		return
	_log("Đá máy %d (ghế %d): %s" % [peer, seat_of(peer), reason])
	_over_since.erase(peer)
	multiplayer.multiplayer_peer.disconnect_peer(peer)


func host(port: int = PORT, play: bool = true) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS + EXTRA_PEERS)
	if err != OK:
		status.emit("Không mở được cổng %d (lỗi %d)" % [port, err])
		return err
	_reset()
	# Client không được nhờ server chuyển RPC tới client khác: mọi gói đều phải qua luật trên server.
	(multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.multiplayer_peer = peer
	if play:
		players[1] = {"name": my_name, "deck": my_deck.duplicate()}
	status.emit("Đã tạo phòng ở cổng %d" % port)
	_log("Phiên bản giao thức %d, Godot %s" % [PROTOCOL_VERSION, Engine.get_version_info()["string"]])
	players_changed.emit()
	return OK


func join(ip: String, port: int = PORT) -> Error:
	_reset()
	_last_ip = ip
	_last_port = port
	return _connect()


func _connect() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(_last_ip, _last_port)
	if err != OK:
		status.emit("Không tạo được kết nối (lỗi %d)" % err)
		return err
	multiplayer.multiplayer_peer = peer
	status.emit("Đang vào phòng %s:%d..." % [_last_ip, _last_port])
	return OK


## Chơi một mình với bot. Máy mình vẫn là "server", không mở cổng mạng.
func start_offline(match_time: float, my_role: int) -> void:
	_reset()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {1: {"name": my_name, "deck": my_deck.duplicate()}}
	start_match(match_time, true, my_role)


func leave() -> void:
	_reconnect_until = 0.0
	_reset()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	in_match = false
	disconnected.emit()


func _reset() -> void:
	players.clear()
	_my_seat = 0
	_my_token = 0
	_rejected = false
	_seat_of_peer.clear()
	_peer_of_seat.clear()
	_tokens.clear()
	_away_since.clear()
	_unregistered.clear()
	_rate.clear()
	_over_since.clear()
	_match_info = {}


## Chỉ server. fill_bots: thêm bot cho đủ MAX_PLAYERS.
## host_role: GameTypes.Role muốn cho chủ phòng, -1 = ngẫu nhiên.
## Thông số trận đọc từ config_path (server), gửi xuống client trong thông tin trận.
func start_match(match_time: float = 180.0, fill_bots: bool = false, host_role: int = -1) -> void:
	if not multiplayer.is_server() or in_match:
		return
	var cfg := load(config_path) as MatchConfig if ResourceLoader.exists(config_path) else null
	if cfg == null:
		GameLog.warn("Không đọc được %s, dùng thông số mặc định" % config_path)
		cfg = MatchConfig.new()
	var ids := players.keys()
	ids.sort()
	var names := {}
	var decks := {}
	for id: int in ids:
		names[id] = players[id]["name"]
		if not players[id].get("deck", []).is_empty():
			decks[id] = players[id]["deck"]
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
	var match_id := "%08x" % (randi() & 0x7fffffff)
	_match_info = {"roles": roles, "names": names, "time": match_time, "decks": decks, "config": cfg.to_array(),
		"match_id": match_id, "seed": randi()}
	_begin.rpc(_match_info)


## Chỉ server, Core/main gọi khi đóng trận: dọn ghế của người đã rớt hẳn.
func end_match() -> void:
	in_match = false
	if not multiplayer.is_server():
		return
	for seat: int in _away_since.keys():
		players.erase(seat)
		_tokens.erase(seat)
	_away_since.clear()
	_match_info = {}
	if is_online():
		_sync_players.rpc(players)
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _begin(info: Dictionary) -> void:
	in_match = true
	GameLog.match_id = str(info.get("match_id", ""))
	match_started.emit(info)


func _on_peer_connected(peer: int) -> void:
	_set_timeout(peer)
	if multiplayer.is_server():
		_unregistered[peer] = _now()


func _set_timeout(peer: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var packet_peer := enet.get_peer(peer) if enet else null
	if packet_peer:
		packet_peer.set_timeout(32, PEER_TIMEOUT_MIN, PEER_TIMEOUT_MAX)


func _on_connected() -> void:
	_set_timeout(1)
	status.emit("Đã kết nối, đang vào phòng...")
	_register.rpc_id(1, my_name, my_deck, PROTOCOL_VERSION, _my_seat, _my_token)


@rpc("any_peer", "reliable")
func _register(player_name: String, deck: Array, version: int, seat: int, token: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if not allow(peer, &"register"):
		return
	_unregistered.erase(peer)
	if _seat_of_peer.has(peer):
		return # đã vào phòng: gửi lại không làm gì (khỏi bị spam đồng bộ cả phòng)
	if version != PROTOCOL_VERSION:
		_reject(peer, Reject.VERSION)
		return
	if seat != 0:
		_rejoin(peer, seat, token)
		return
	if in_match:
		_reject(peer, Reject.IN_MATCH)
		return
	if players.size() >= MAX_PLAYERS:
		_reject(peer, Reject.FULL)
		return
	var clean_deck := deck.slice(0, 8).filter(func(t: Variant) -> bool: return t is int) # luật lọc tiếp khi vào trận
	players[peer] = {"name": player_name.strip_edges().left(16), "deck": clean_deck}
	_bind(peer, peer)
	_tokens[peer] = _new_token()
	_welcome.rpc_id(peer, peer, _tokens[peer])
	_sync_players.rpc(players)
	players_changed.emit()


## Máy cũ vào lại ghế `seat` giữa trận.
func _rejoin(peer: int, seat: int, token: int) -> void:
	var ok: bool = in_match and token != 0 and _tokens.get(seat, 0) == token and not _peer_of_seat.has(seat) \
		and _away_since.has(seat)
	if not ok:
		_reject(peer, Reject.SEAT_EXPIRED)
		return
	_away_since.erase(seat)
	_bind(seat, peer)
	_log("Ghế %d vào lại trận (máy %d)" % [seat, peer])
	_welcome.rpc_id(peer, seat, token)
	_sync_players.rpc_id(peer, players)
	_begin.rpc_id(peer, _match_info)
	player_returned.emit(seat)


func _bind(seat: int, peer: int) -> void:
	_seat_of_peer[peer] = seat
	_peer_of_seat[seat] = peer


func _reject(peer: int, reason: Reject) -> void:
	_log("Từ chối máy %d: %s" % [peer, REJECT_TEXT[reason]])
	_rejected_by_server.rpc_id(peer, reason)
	# Cắt sau một chút để gói báo lý do kịp tới.
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if multiplayer.is_server() and peer in multiplayer.get_peers():
			multiplayer.multiplayer_peer.disconnect_peer(peer))


@rpc("authority", "reliable")
func _rejected_by_server(reason: int) -> void:
	_rejected = true
	_reconnect_until = 0.0
	status.emit(REJECT_TEXT.get(reason, "Bị từ chối vào phòng"))


@rpc("authority", "reliable")
func _welcome(seat: int, token: int) -> void:
	_my_seat = seat
	_my_token = token
	if _reconnect_until > 0.0:
		_reconnect_until = 0.0
		status.emit("Đã vào lại trận")
	else:
		status.emit("Đã vào phòng")


@rpc("authority", "reliable")
func _sync_players(p: Dictionary) -> void:
	players = p
	players_changed.emit()


func _on_peer_disconnected(peer: int) -> void:
	_unregistered.erase(peer)
	_rate.erase(peer)
	_over_since.erase(peer)
	if not multiplayer.is_server() or not _seat_of_peer.has(peer):
		return
	var seat: int = _seat_of_peer[peer]
	_seat_of_peer.erase(peer)
	_peer_of_seat.erase(seat)
	if in_match:
		_away_since[seat] = _now() # giữ ghế tới hết trận, bot chơi thay
		_log("Ghế %d rớt mạng, bot chơi thay" % seat)
	else:
		players.erase(seat)
		_tokens.erase(seat)
		_sync_players.rpc(players)
	players_changed.emit()
	player_left.emit(seat)


func _on_connection_failed() -> void:
	if _reconnect_until > 0.0:
		return # đang thử vào lại: _process thử tiếp
	leave()
	status.emit("Không vào được phòng")


func _on_server_disconnected() -> void:
	var can_rejoin := in_match and _my_token != 0 and not _rejected
	if not can_rejoin:
		leave()
		status.emit("Mất kết nối với chủ phòng")
		return
	# Rớt giữa trận: đóng trận đang vẽ rồi thử vào lại ghế cũ (giữ ghế, mã vào
	# lại). Chủ phòng tắt hẳn thì hết giờ trận dự kiến là thôi, về menu.
	var left := GameState.rules.time_left + GameState.rules.countdown_left if GameState.rules else 0.0
	_reconnect_until = _now() + maxf(left, 0.0) + REJOIN_MARGIN
	_reconnect_timer = RECONNECT_INTERVAL
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	in_match = false
	disconnected.emit()
	status.emit("Mất kết nối, đang thử vào lại trận...")


func _try_reconnect() -> void:
	if _now() > _reconnect_until:
		leave()
		status.emit("Không vào lại được trận")
		return
	_reconnect_timer = RECONNECT_INTERVAL
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		return # lần thử trước còn đang chờ
	_connect()


func _new_token() -> int:
	return Crypto.new().generate_random_bytes(8).decode_s64(0) & 0x7fffffffffffffff


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _log(msg: String) -> void:
	GameLog.info(msg)
