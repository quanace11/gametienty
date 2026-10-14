extends Node3D
## Một trận đấu: dựng bản đồ, tạo nhân vật, chuyển input lên server và
## vị trí xuống client. Luật nằm ở GameState/MatchRules và trong các module.

const SNAPSHOT_INTERVAL := 1.0 / 20.0
const INPUT_INTERVAL := 1.0 / 30.0

var entities := {} # id -> EntityBase
var input_sources := {} # chỉ server: id -> InputSource
var map: MapBase

var _local_input: InputSource
var _my_id := 0
var _snapshot_timer := 0.0
var _input_timer := 0.0


func setup(info: Dictionary) -> void:
	_my_id = multiplayer.get_unique_id()
	map = load(ModuleRegistry.MAP).new()
	map.name = "Map"
	add_child(map)
	GameState.begin(info, map.get_safe_count(), map.get_coin_spots().size())

	var entities_node := Node3D.new()
	entities_node.name = "Entities"
	add_child(entities_node)
	var roles: Dictionary = info["roles"]
	var ids := roles.keys()
	ids.sort()
	var spawns := map.get_escapee_spawns()
	var spawn_index := 0
	for id: int in ids:
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
		for id: int in ids:
			var src: InputSource
			if id == _my_id:
				src = _local_input
			elif GameTypes.is_bot_id(id):
				src = load(ModuleRegistry.BOT_INPUT).new()
				src.attach(entities[id])
			else:
				src = NetworkInputSource.new()
			input_sources[id] = src

	add_child(load(ModuleRegistry.ITEM_VISUALS).new())
	add_child(load(ModuleRegistry.HUD).new())
	print("[%d] Trận bắt đầu: %s" % [_my_id, info["names"]])


func _physics_process(delta: float) -> void:
	GameState.tick(delta)
	var rules := GameState.rules
	if rules == null or not rules.is_playing():
		return

	if _local_input and not multiplayer.is_server():
		_local_input.update(delta)
		_input_timer -= delta
		if _input_timer <= 0.0:
			_input_timer = INPUT_INTERVAL
			_submit_input.rpc_id(1, _local_input.get_move(), _local_input.get_buttons(), _local_input.get_aim_yaw())

	if multiplayer.is_server():
		for id: int in entities:
			var src: InputSource = input_sources[id]
			src.update(delta)
			entities[id].server_read_input(src)
			entities[id].server_move(src, delta)
			_server_use_items(entities[id])
		GameState.server_land_shots(entities.values())
		GameState.flush(delta)
		_send_snapshot(delta)
	else:
		for e: EntityBase in entities.values():
			e.client_update(delta)


## Nút ô thẻ vừa bấm thì dùng thẻ (GameState kiểm tra tiền, hồi chiêu).
func _server_use_items(e: EntityBase) -> void:
	for slot in InputSource.SKILL_ACTIONS.size():
		if e.just_pressed(InputSource.SKILL_ACTIONS[slot]):
			GameState.server_use_item(e, slot)


func _send_snapshot(delta: float) -> void:
	_snapshot_timer -= delta
	if _snapshot_timer > 0.0 or multiplayer.get_peers().is_empty():
		return
	_snapshot_timer = SNAPSHOT_INTERVAL
	var snap := {}
	for id: int in entities:
		snap[id] = entities[id].get_snapshot()
	_snapshot.rpc(snap)


@rpc("any_peer", "unreliable_ordered")
func _submit_input(move: Vector2, buttons: int, aim_yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var src = input_sources.get(multiplayer.get_remote_sender_id())
	if src is NetworkInputSource:
		src.move = move.limit_length(1.0) # không tin client
		src.buttons = buttons
		src.aim_yaw = wrapf(aim_yaw, -PI, PI)


@rpc("authority", "unreliable_ordered")
func _snapshot(snap: Dictionary) -> void:
	for id: int in snap:
		if entities.has(id):
			entities[id].apply_snapshot(snap[id])
