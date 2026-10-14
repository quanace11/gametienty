class_name Prison
extends Interactable
## Nhà tù: thợ săn vác người trốn bước vào là nhốt. Người trốn đứng trong
## vùng thì phá khóa, cứu tất cả người đang bị nhốt ở đây.

const SIZE := Vector3(2.4, 2.6, 2.4)

var _label: Label3D


func _ready() -> void:
	super()
	add_to_group(GameTypes.GROUP_PRISONS)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE + Vector3(0.8, 0, 0.8)
	shape.shape = box
	shape.position.y = SIZE.y / 2
	add_child(shape)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.6, 0.75, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := BoxMesh.new()
	mesh.size = SIZE
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = SIZE.y / 2
	add_child(mi)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = SIZE.y + 0.5
	_label.font_size = 48
	add_child(_label)
	for sig: Signal in [EventBus.player_imprisoned, EventBus.player_rescued, EventBus.player_eliminated, EventBus.rescue_progress_changed]:
		sig.connect(func(_a: Variant = null, _b: Variant = null) -> void: _refresh())
	_refresh()


func can_interact(entity: EntityBase) -> bool:
	return entity.is_hunter() or GameTypes.is_active(entity.state)


func interact_tick(users: Array[EntityBase], delta: float) -> void:
	var rules := GameState.rules
	var inmates := _inmates()
	for e in users:
		if e.is_hunter():
			if rules.record(e.peer_id).carrying_id != 0:
				GameState.server_imprison(e.peer_id, interactable_id)
		else:
			for id: int in inmates:
				GameState.server_channel_rescue(e.peer_id, id, delta)


func _inmates() -> Array:
	var rules := GameState.rules
	if rules == null:
		return []
	return rules.players.keys().filter(func(id: int) -> bool:
		var p: PlayerRecord = rules.players[id]
		return p.state == GameTypes.PlayerState.IMPRISONED and p.prison_id == interactable_id)


func _refresh() -> void:
	var inmates := _inmates()
	if inmates.is_empty():
		_label.text = "Nhà tù"
		return
	var progress: float = GameState.rules.players[inmates[0]].rescue_progress
	_label.text = "Nhà tù: %d người" % inmates.size() + (" (cứu %d%%)" % roundi(progress * 100) if progress > 0.0 else "")
