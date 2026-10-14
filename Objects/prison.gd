class_name Prison
extends Interactable
## Nhà tù: thợ săn kéo người trốn bước vào là nhốt. Người bị nhốt mất máu
## dần (MatchConfig.prison_time), hết thì bị đốt chết; chỉ túi máu cứu được.
## Chưa có tường cao và đệm lò xo: được cứu thì đi thẳng ra ngoài.

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
	_refresh()


func _process(_delta: float) -> void:
	_refresh() # máu người trong tù tụt liên tục


func can_interact(entity: EntityBase) -> bool:
	return entity.is_hunter()


func interact_tick(users: Array[EntityBase], _delta: float) -> void:
	for e in users:
		if GameState.rules.record(e.peer_id).carrying_id != 0:
			GameState.server_imprison(e.peer_id, interactable_id)


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
	var least := INF
	for id: int in inmates:
		least = minf(least, GameState.rules.players[id].prison_time_left)
	_label.text = "Nhà tù: %d người (cháy sau %d giây)" % [inmates.size(), ceili(least)]
