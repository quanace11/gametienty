class_name Safe
extends Interactable
## Rương báu (trong code Core gọi là "safe"): người trốn đứng sát rương để
## cạy, càng đông càng nhanh. Trong lúc cạy, vòng căn hiện ra (UI vẽ), bấm E
## khi kim vào vùng sáng: vùng đậm mở nhanh thêm + tiền, vùng mờ ít tiền,
## trượt thì rương nổ, về 0 và báo vị trí cho thợ săn. Mở xong nhả chìa khóa
## và văng tiền ra sàn. Luật nằm ở MatchRules (channel_chest, resolve_qte).

const SIZE := Vector3(1.0, 1.0, 0.8)
const REACH := 0.9 # đứng cách mép rương bao xa thì cạy được
const COIN_RING := 1.6 # tiền văng ra quanh rương, bán kính (mét)
const ALERT_TIME := 4.0 # giây cột khói đỏ báo vị trí sau khi nổ

const CoinScript = preload("res://Objects/coin.gd")
const WOOD_COLOR := Color(0.6, 0.38, 0.15)
const OPEN_COLOR := Color(0.95, 0.8, 0.2)
const BURNT_COLOR := Color(0.1, 0.1, 0.1)

var _body_parts: Array[MeshInstance3D] = [] # thân + nắp, đổi màu theo tiến độ
var _burn_material: StandardMaterial3D # chỉ tạo khi rương nổ lần đầu (tween màu riêng rương này)
var _label: Label3D
var _alert: MeshInstance3D
var _alert_left := 0.0

# Dùng chung cho mọi rương: hình và màu (gỗ / đã mở) đổi bằng material_override.
static var _base_mesh: BoxMesh
static var _lid_mesh: CylinderMesh
static var _band_mesh: BoxMesh # đai vàng
static var _pillar_mesh: CylinderMesh # cột khói đỏ báo vị trí
static var _wood_mat: StandardMaterial3D
static var _open_mat: StandardMaterial3D


func _ready() -> void:
	super()
	add_to_group(GameTypes.GROUP_SAFES)
	set_process(false) # chỉ chạy lúc cột khói đỏ đang hiện

	var area_shape := CollisionShape3D.new()
	var area_box := BoxShape3D.new()
	area_box.size = SIZE + Vector3(REACH * 2, 1.0, REACH * 2)
	area_shape.shape = area_box
	area_shape.position.y = SIZE.y / 2
	add_child(area_shape)

	# Thân rương chắn đường như tường.
	var body := StaticBody3D.new()
	var body_shape := CollisionShape3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = SIZE
	body_shape.shape = body_box
	body_shape.position.y = SIZE.y / 2
	body.add_child(body_shape)
	add_child(body)

	EventBus.safe_unlocked.connect(_on_unlocked) # tiền văng ra là vật nhặt được: server cũng cần
	EventBus.qte_resolved.connect(_on_qte_resolved)
	if DisplayServer.get_name() == "headless": # server riêng: không hình, không chữ
		return
	_build_visuals()
	EventBus.safe_progress_changed.connect(func(id: int, _p: float) -> void:
		if id == interactable_id:
			_refresh())
	_refresh()


## Rương chibi: thân gỗ (đổi màu theo tiến độ), nắp tròn, đai vàng; cột khói ẩn sẵn.
func _build_visuals() -> void:
	_build_shared()
	var mi := MeshInstance3D.new()
	mi.mesh = _base_mesh
	mi.position.y = SIZE.y * 0.3
	add_child(mi)
	_body_parts.append(mi)
	var lid_mi := MeshInstance3D.new()
	lid_mi.mesh = _lid_mesh
	lid_mi.rotation.z = PI / 2
	lid_mi.position.y = SIZE.y * 0.6
	add_child(lid_mi)
	_body_parts.append(lid_mi)
	_set_body_material(_wood_mat)
	for x: float in [-SIZE.x * 0.3, SIZE.x * 0.3]:
		var b := MeshInstance3D.new()
		b.mesh = _band_mesh
		b.position = Vector3(x, _band_mesh.size.y / 2, 0)
		add_child(b)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = SIZE.y + 0.5
	_label.font_size = 48
	add_child(_label)

	_alert = MeshInstance3D.new()
	_alert.mesh = _pillar_mesh
	_alert.position.y = 3.0
	_alert.visible = false
	add_child(_alert)


static func _build_shared() -> void:
	if _base_mesh:
		return
	_wood_mat = StandardMaterial3D.new()
	_wood_mat.albedo_color = WOOD_COLOR
	_open_mat = StandardMaterial3D.new()
	_open_mat.albedo_color = OPEN_COLOR
	_base_mesh = BoxMesh.new()
	_base_mesh.size = Vector3(SIZE.x, SIZE.y * 0.6, SIZE.z)
	_lid_mesh = CylinderMesh.new()
	_lid_mesh.top_radius = SIZE.z / 2
	_lid_mesh.bottom_radius = SIZE.z / 2
	_lid_mesh.height = SIZE.x
	_lid_mesh.radial_segments = 10
	_band_mesh = BoxMesh.new()
	_band_mesh.size = Vector3(0.14, SIZE.y * 0.62 + SIZE.z / 2, SIZE.z + 0.04)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.8, 0.25)
	_band_mesh.material = gold
	_pillar_mesh = CylinderMesh.new()
	_pillar_mesh.top_radius = 0.5
	_pillar_mesh.bottom_radius = 0.8
	_pillar_mesh.height = 6.0
	var alert_mat := StandardMaterial3D.new()
	alert_mat.albedo_color = Color(0.9, 0.1, 0.1, 0.45)
	alert_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	alert_mat.emission_enabled = true
	alert_mat.emission = Color(0.9, 0.1, 0.1)
	_pillar_mesh.material = alert_mat


func _set_body_material(mat: Material) -> void:
	for mi in _body_parts:
		mi.material_override = mat


func can_interact(entity: EntityBase) -> bool:
	return not entity.is_hunter() and GameTypes.is_active(entity.state)


func interact_tick(users: Array[EntityBase], delta: float) -> void:
	var rules := GameState.rules
	for e in users:
		GameState.server_channel_chest(e.peer_id, interactable_id, delta)
		var rec := rules.record(e.peer_id)
		if rec and rec.qte_chest == interactable_id and e.just_pressed(&"interact"):
			GameState.server_resolve_qte(e.peer_id)


func _process(delta: float) -> void:
	_alert_left -= delta
	_alert.visible = _alert_left > 0.0
	_alert.scale = Vector3.ONE * (1.0 + 0.1 * sin(_alert_left * 12.0))
	if _alert_left <= 0.0:
		set_process(false)


func _on_unlocked(id: int, _unlocked: int, _required: int) -> void:
	if id != interactable_id:
		return
	_refresh()
	var ids := GameState.rules.chest_coin_ids(id)
	for k in ids.size():
		var coin: Interactable = CoinScript.new()
		coin.interactable_id = ids[k]
		var angle := TAU * k / ids.size()
		coin.position = Vector3(cos(angle), 0, sin(angle)) * COIN_RING
		add_child(coin)


func _on_qte_resolved(_id: int, safe_id: int, result: GameTypes.QteResult) -> void:
	if safe_id != interactable_id or result != GameTypes.QteResult.FAIL:
		return
	# "Đoàng!": khói đỏ báo vị trí cho mọi người, kể cả thợ săn.
	EventBus.noise_made.emit(global_position, 1.0)
	if _alert == null: # server riêng không vẽ
		return
	_alert_left = ALERT_TIME
	_alert.visible = true
	set_process(true)
	# Cháy đen rồi về màu gỗ: material riêng rương này chỉ trong lúc tween.
	if _burn_material == null:
		_burn_material = StandardMaterial3D.new()
	_burn_material.albedo_color = BURNT_COLOR
	_set_body_material(_burn_material)
	var tween := create_tween()
	tween.tween_property(_burn_material, "albedo_color", WOOD_COLOR, 0.8)
	tween.tween_callback(func() -> void:
		_set_body_material(_wood_mat) # xong tween thì về material dùng chung
		_refresh())


func _refresh() -> void:
	if _label == null:
		return
	var p := 0.0
	if GameState.rules:
		p = GameState.rules.safe_progress.get(interactable_id, 0.0)
	if p >= 1.0:
		_set_body_material(_open_mat)
		_label.text = "Đã mở 🔑"
	else:
		_label.text = "Rương %d%%" % roundi(p * 100)
