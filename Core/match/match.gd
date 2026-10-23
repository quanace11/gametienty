extends Node3D
## Một trận đấu: dựng bản đồ, tạo nhân vật, chuyển input lên server và
## vị trí xuống client. Luật nằm ở GameState/MatchRules và trong các module.
##
## Mỗi ghế có một nguồn lệnh: bàn phím (người ngồi server), mạng (client) hoặc
## bot. Máy rớt mạng hay chưa dựng xong trận thì bot chơi thay đúng nhân vật
## đó; máy vào lại báo dựng xong thì lấy lại quyền điều khiển.
##
## Cú bấm nút: client ghi mỗi lần bấm thành một sự kiện có số thứ tự và giờ bấm
## (đồng hồ trận của máy đó), gửi lặp trong các gói input tới khi server báo đã
## nhận (ack trong gói vị trí). Gói input mất hay cú chạm ngắn hơn một nhịp gửi
## thì server vẫn thấy lần bấm; server bỏ sự kiện trùng số.

const SNAPSHOT_INTERVAL := 1.0 / 20.0
const INPUT_INTERVAL := 1.0 / 30.0
const LOAD_TIMEOUT := 20.0 ## giây server chờ các máy dựng trận, quá thì bắt đầu luôn (bot chơi thay máy chậm)
const MAX_EVENTS := 8 ## số cú bấm chưa được xác nhận gửi kèm mỗi gói input
const POS_SCALE := 100.0 ## gói vị trí: 1 đơn vị = 1 cm, int16 đủ ±327 m
const YAW_SCALE := 65536.0 / TAU

var entities := {} # id -> EntityBase
var input_sources := {} # chỉ server: id -> InputSource đang điều khiển
var map: MapBase

var _local_input: InputSource
var _my_id := 0
var _snapshot_timer := 0.0
var _input_timer := 0.0
var _ids: Array = [] # id nhân vật theo thứ tự tăng dần (mọi máy giống nhau): chỉ số trong gói vị trí
# Chỉ server:
var _net_inputs := {} # seat -> NetworkInputSource (giữ suốt trận, máy vào lại dùng tiếp)
var _bots := {} # seat -> BotInputSource dùng khi máy đó vắng
var _loaded := {} # peer -> seat: máy đã dựng xong trận và đang nhận dữ liệu
var _load_left := LOAD_TIMEOUT
var _self_loaded := false
# Chỉ client:
var _last_buttons := 0
var _events: Array = [] # [seq, chỉ số nút, giờ bấm] chưa được server xác nhận
var _next_event_seq := 0
var _clock_offset := 0.0 # giờ server - giờ máy mình (giây), ước lượng từ gói vị trí
var _clock_ready := false
var _start_msec := Time.get_ticks_msec() # server: mốc giờ trong gói vị trí (giờ tính từ lúc dựng trận, float32 đủ chính xác)


func setup(info: Dictionary) -> void:
	_my_id = Net.my_seat()
	map = load(ModuleRegistry.MAP).new()
	map.name = "Map"
	add_child(map)
	GameState.begin(info, map.get_safe_count(), map.get_coin_spots().size())

	var entities_node := Node3D.new()
	entities_node.name = "Entities"
	add_child(entities_node)
	var roles: Dictionary = info["roles"]
	_ids = roles.keys()
	_ids.sort()
	var spawns := map.get_escapee_spawns()
	var spawn_index := 0
	for id: int in _ids:
		var e: EntityBase = load(ModuleRegistry.ENTITY).new()
		var pos := map.get_hunter_spawn()
		if roles[id] == GameTypes.Role.ESCAPEE:
			pos = spawns[spawn_index % spawns.size()]
			spawn_index += 1
		e.setup(id, roles[id], info["names"][id], pos, id == _my_id)
		entities_node.add_child(e)
		entities[id] = e

	if entities.has(_my_id):
		_local_input = load(ModuleRegistry.BOT_INPUT if Net.bot else ModuleRegistry.LOCAL_INPUT).new()
		_local_input.attach(entities[_my_id])
	if multiplayer.is_server():
		for id: int in _ids:
			if id == _my_id:
				input_sources[id] = _local_input
			elif Net.idle_hunter and roles[id] == GameTypes.Role.HUNTER:
				input_sources[id] = InputSource.new() # test: thợ săn đứng yên
			elif GameTypes.is_bot_id(id):
				input_sources[id] = _bot_for(id)
			else:
				_net_inputs[id] = NetworkInputSource.new()
				input_sources[id] = _bot_for(id) # chưa dựng xong trận thì bot đứng thay
		Net.player_left.connect(_on_player_left)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	add_child(load(ModuleRegistry.ITEM_VISUALS).new())
	add_child(load(ModuleRegistry.HUD).new())
	if DisplayServer.get_name() != "headless": # dịch sẵn shader dưới màn che, khỏi khựng mấy giây đầu trận
		var warmup := RenderWarmup.new(self)
		warmup.warmed.connect(_on_loaded_here)
		add_child(warmup)
	else:
		_on_loaded_here.call_deferred()
	GameLog.info("Trận bắt đầu: %s" % [info["names"]])


func _physics_process(delta: float) -> void:
	GameState.tick(delta)
	var rules := GameState.rules
	if rules == null:
		return
	if multiplayer.is_server() and rules.state == GameTypes.MatchState.LOADING:
		_server_wait_loading(delta)
	if not rules.is_playing():
		return

	if _local_input and not multiplayer.is_server():
		_local_input.update(delta)
		_record_presses(rules)
		_input_timer -= delta
		if _input_timer <= 0.0:
			_input_timer = INPUT_INTERVAL
			_send_input()

	if multiplayer.is_server():
		for id: int in entities:
			var src: InputSource = input_sources[id]
			src.update(delta)
			entities[id].server_read_input(src)
			entities[id].server_move(src, delta)
			_server_use_items(entities[id])
		GameState.server_after_move(entities.values())
		if entities.has(_my_id): # chủ phòng / offline: tự ẩn người mình không được thấy
			for id: int in entities:
				entities[id].set_concealed(not GameState.can_see(_my_id, id))
		GameState.flush(delta)
		_send_snapshot(delta)
	else:
		EntityBase.render_time = _server_now() - EntityBase.INTERP_DELAY
		for id: int in entities:
			entities[id].client_update(delta)


## Nút ô thẻ vừa bấm thì dùng thẻ (GameState kiểm tra tiền, hồi chiêu).
func _server_use_items(e: EntityBase) -> void:
	for slot in InputSource.SKILL_ACTIONS.size():
		if e.just_pressed(InputSource.SKILL_ACTIONS[slot]):
			GameState.server_use_item(e, slot)


# ---------- Ai điều khiển ghế nào (chỉ server) ----------

func _bot_for(seat: int) -> InputSource:
	if not _bots.has(seat):
		var bot: InputSource = load(ModuleRegistry.BOT_INPUT).new()
		bot.attach(entities[seat])
		_bots[seat] = bot
	return _bots[seat]


## Máy ngồi ghế `seat` có mặt thì nghe máy đó, vắng thì bot chơi thay.
func _set_controller(seat: int, present: bool) -> void:
	if not _net_inputs.has(seat) or (Net.idle_hunter and entities[seat].is_hunter()):
		return
	var src: InputSource = _net_inputs[seat] if present else _bot_for(seat)
	if input_sources[seat] != src:
		input_sources[seat] = src
		if present:
			(src as NetworkInputSource).reset() # bỏ lệnh cũ từ trước khi rớt
		GameLog.info("Ghế %d: %s điều khiển" % [seat, "người chơi" if present else "bot"])


func _on_player_left(seat: int) -> void:
	_set_controller(seat, false)


func _on_peer_disconnected(peer: int) -> void:
	_loaded.erase(peer)
	GameState.server_peer_gone(peer)


# ---------- Chờ tải ----------

## Máy này dựng xong trận (đã làm nóng shader).
func _on_loaded_here() -> void:
	if multiplayer.is_server():
		_self_loaded = true
	else:
		_loaded_rpc.rpc_id(1)


@rpc("any_peer", "reliable")
func _loaded_rpc() -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var seat := Net.seat_of(peer)
	if seat == 0 or _loaded.has(peer) or not Net.allow(peer, &"loaded"):
		return
	_loaded[peer] = seat
	GameState.server_peer_ready(peer)
	_set_controller(seat, true)


func _server_wait_loading(delta: float) -> void:
	_load_left -= delta
	var all_in := _self_loaded or not entities.has(_my_id)
	for seat: int in _net_inputs:
		if Net.is_connected_seat(seat) and not seat in _loaded.values():
			all_in = false
	if all_in or _load_left <= 0.0:
		if not all_in:
			GameLog.warn("Hết %d giây chờ tải, bắt đầu luôn (bot chơi thay máy chưa xong)" % LOAD_TIMEOUT)
		GameState.server_start_countdown()


# ---------- Input (client -> server) ----------

## Client: mỗi nút vừa bấm xuống thành một sự kiện có số thứ tự và giờ bấm.
func _record_presses(rules: MatchRules) -> void:
	var b := _local_input.get_buttons()
	var newly := b & ~_last_buttons
	_last_buttons = b
	if newly == 0:
		return
	for i in InputSource.ACTIONS.size():
		if newly & (1 << i):
			_events.append([_next_event_seq, i, rules.elapsed])
			_next_event_seq += 1
	if _events.size() > MAX_EVENTS * 2:
		_events = _events.slice(_events.size() - MAX_EVENTS * 2) # mất liên lạc lâu: bỏ cú bấm quá cũ


func _send_input() -> void:
	var first := _next_event_seq
	var actions := PackedByteArray()
	var times := PackedFloat32Array()
	var start := maxi(0, _events.size() - MAX_EVENTS)
	for k in range(start, _events.size()):
		if k == start:
			first = _events[k][0]
		actions.append(_events[k][1])
		times.append(_events[k][2])
	_submit_input.rpc_id(1, _local_input.get_move(), _local_input.get_buttons(), _local_input.get_aim_yaw(), _local_input.get_aim(),
		first, actions, times)


@rpc("any_peer", "unreliable_ordered")
func _submit_input(move: Vector2, buttons: int, aim_yaw: float, aim: Vector2, first_event: int, actions: PackedByteArray,
		times: PackedFloat32Array) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if not Net.allow(peer, &"input"):
		return
	var src: NetworkInputSource = _net_inputs.get(Net.seat_of(peer))
	if src == null:
		return
	if actions.size() != times.size() or actions.size() > MAX_EVENTS or first_event < 0:
		Net.kick(peer, "gói input sai")
		return
	src.move = move.limit_length(1.0) if move.is_finite() else Vector2.ZERO # không tin client
	src.buttons = buttons & ((1 << InputSource.ACTIONS.size()) - 1)
	src.aim_yaw = wrapf(aim_yaw, -PI, PI) if is_finite(aim_yaw) else 0.0
	src.aim = aim.limit_length(1.0) if aim.is_finite() else Vector2.ZERO
	for k in actions.size():
		if actions[k] < InputSource.ACTIONS.size() and is_finite(times[k]):
			src.receive_event(first_event + k, actions[k], times[k])


# ---------- Vị trí (server -> client) ----------

## Gói vị trí riêng cho từng máy, nén thành byte: [giờ server float32][ack int32]
## rồi mỗi nhân vật máy đó được thấy 9 byte: chỉ số (u8), x, y, z (int16, cm),
## góc quay (u16). Nhân vật vắng trong gói = máy đó không được thấy (trong bụi).
## 5 người: ~53 byte mỗi gói, 20 gói/giây.
func _send_snapshot(delta: float) -> void:
	_snapshot_timer -= delta
	var peers := GameState.ready_peers()
	if _snapshot_timer > 0.0 or peers.is_empty():
		return
	_snapshot_timer = SNAPSHOT_INTERVAL
	var rows := {}
	for k in _ids.size():
		var data: Variant = entities[_ids[k]].get_snapshot()
		var row := PackedByteArray()
		row.resize(9)
		row.encode_u8(0, k)
		var p: Vector3 = data[0]
		row.encode_s16(1, clampi(roundi(p.x * POS_SCALE), -32768, 32767))
		row.encode_s16(3, clampi(roundi(p.y * POS_SCALE), -32768, 32767))
		row.encode_s16(5, clampi(roundi(p.z * POS_SCALE), -32768, 32767))
		row.encode_u16(7, roundi(fposmod(data[1], TAU) * YAW_SCALE) & 0xffff)
		rows[_ids[k]] = row
	var now := (Time.get_ticks_msec() - _start_msec) / 1000.0
	for peer: int in peers:
		var seat := Net.seat_of(peer)
		var head := PackedByteArray()
		head.resize(8)
		head.encode_float(0, now)
		var src: NetworkInputSource = _net_inputs.get(seat)
		head.encode_s32(4, src.last_event_seq if src else -1)
		var packet := head
		for id: int in _ids:
			if GameState.can_see(seat, id):
				packet.append_array(rows[id])
		_snapshot.rpc_id(peer, packet)


@rpc("authority", "unreliable_ordered")
func _snapshot(packet: PackedByteArray) -> void:
	if packet.size() < 8 or (packet.size() - 8) % 9 != 0:
		return
	var server_t := packet.decode_float(0)
	_update_clock(server_t)
	var ack := packet.decode_s32(4)
	while not _events.is_empty() and _events[0][0] <= ack:
		_events.pop_front()
	var seen := {}
	EntityBase.snapshot_time = server_t
	for o in range(8, packet.size(), 9):
		var k := packet.decode_u8(o)
		if k >= _ids.size():
			continue
		var id: int = _ids[k]
		seen[id] = true
		var pos := Vector3(packet.decode_s16(o + 1), packet.decode_s16(o + 3), packet.decode_s16(o + 5)) / POS_SCALE
		var yaw := packet.decode_u16(o + 7) / YAW_SCALE
		if yaw > PI:
			yaw -= TAU
		entities[id].set_concealed(false)
		entities[id].apply_snapshot([pos, yaw])
	for id: int in entities:
		if not seen.has(id):
			entities[id].set_concealed(true)


## Ước lượng giờ server = giờ máy mình + độ lệch. Gói tới sớm nhất là gói ít
## trễ nhất, nên độ lệch bám theo giá trị lớn nhất, rồi trôi dần xuống để
## theo kịp khi đường truyền chậm đi.
func _update_clock(server_t: float) -> void:
	var o := server_t - Time.get_ticks_msec() / 1000.0
	if not _clock_ready or o > _clock_offset:
		_clock_offset = o
		_clock_ready = true
	else:
		_clock_offset = lerpf(_clock_offset, o, 0.02)


func _server_now() -> float:
	return Time.get_ticks_msec() / 1000.0 + _clock_offset
