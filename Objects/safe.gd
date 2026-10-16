class_name Safe
extends Interactable
## Trận linh nhỏ (trong code Core gọi là "safe", xưa là rương): người trốn đứng
## sát trận để giải, càng đông càng nhanh. Trong lúc giải, vòng căn hiện ra (UI
## vẽ), bấm E khi kim vào vùng sáng: vùng đậm giải nhanh thêm + linh thạch, vùng
## mờ ít linh thạch, trượt thì trận bùng đỏ, về 0 và báo vị trí cho ma tu. Giải
## xong thì tính một trận đã phá và văng linh thạch ra sàn. Luật nằm ở
## MatchRules (channel_chest, resolve_qte).
## Hình: bệ đá lục giác, 4 trụ phù văn, vòng trận dưới đất sáng dần theo tiến độ,
## linh tinh xanh lơ lửng xoay ở giữa (giải xong thành vàng, hạ xuống bệ).

const SIZE := Vector3(1.0, 1.0, 0.8)
const REACH := 0.9 # đứng cách mép rương bao xa thì cạy được
const COIN_RING := 1.6 # tiền văng ra quanh rương, bán kính (mét)
const ALERT_TIME := 4.0 # giây cột sáng đỏ báo vị trí sau khi trận bùng
const CRYSTAL_HEIGHT := 1.0

const CoinScript = preload("res://Objects/coin.gd")
const WOOD_COLOR := Color(0.35, 0.85, 1.0) # linh tinh chưa giải (tên cũ giữ cho dễ đọc diff)
const OPEN_COLOR := Color(1.0, 0.82, 0.3)
const BURNT_COLOR := Color(1.0, 0.1, 0.1) # trận bùng đỏ khi căn trượt

var _body_parts: Array[MeshInstance3D] = [] # linh tinh + vòng trận, đổi màu theo tiến độ
var _burn_material: StandardMaterial3D # chỉ tạo khi trận bùng lần đầu (tween màu riêng trận này)
var _burn_tween: Tween # bùng lần nữa khi đang bùng thì bỏ tween cũ, khỏi bị cắt ngang
var _label: Label3D
var _alert: MeshInstance3D
var _alert_left := 0.0
var _crystal: MeshInstance3D
var _ring: MeshInstance3D
var _t := 0.0
var _opened := false

# Dùng chung cho mọi trận linh: hình và màu (chưa giải / đã giải) đổi bằng material_override.
static var _base_mesh: CylinderMesh # bệ đá lục giác
static var _lid_mesh: SphereMesh # linh tinh (cầu 4 múi = hình thoi)
static var _band_mesh: BoxMesh # trụ phù văn
static var _cap_mesh: SphereMesh # đầu trụ phát sáng
static var _ring_mesh: TorusMesh # vòng trận dưới đất
static var _pillar_mesh: CylinderMesh # cột sáng đỏ báo vị trí
static var _wood_mat: StandardMaterial3D
static var _open_mat: StandardMaterial3D


func _ready() -> void:
	super()
	add_to_group(GameTypes.GROUP_SAFES)
	set_process(false) # chỉ máy có hình: linh tinh xoay, cột sáng đỏ

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
	set_process(true)
	EventBus.safe_progress_changed.connect(func(id: int, _p: float) -> void:
		if id == interactable_id:
			_refresh())
	_refresh()


## Trận linh: bệ đá, 4 trụ phù văn, vòng trận, linh tinh lơ lửng; cột sáng đỏ ẩn sẵn.
func _build_visuals() -> void:
	_build_shared()
	var base := MeshInstance3D.new()
	base.mesh = _base_mesh
	base.position.y = _base_mesh.height / 2
	add_child(base)
	for k in 4:
		var a := TAU * (k + 0.5) / 4
		var pos := Vector3(cos(a), 0, sin(a)) * SIZE.x * 0.62
		var pillar := MeshInstance3D.new()
		pillar.mesh = _band_mesh
		pillar.position = pos + Vector3(0, _band_mesh.size.y / 2, 0)
		pillar.rotation.y = -a
		add_child(pillar)
		var cap := MeshInstance3D.new()
		cap.mesh = _cap_mesh
		cap.position = pos + Vector3(0, _band_mesh.size.y + 0.06, 0)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cap)
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_mesh
	_ring.position.y = 0.04
	_ring.scale = Vector3(1, 0.1, 1)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_body_parts.append(_ring)
	_crystal = MeshInstance3D.new()
	_crystal.mesh = _lid_mesh
	_crystal.position.y = CRYSTAL_HEIGHT
	add_child(_crystal)
	_body_parts.append(_crystal)
	_set_body_material(_wood_mat)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = CRYSTAL_HEIGHT + 0.8
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
	_wood_mat = _glow_mat(WOOD_COLOR)
	_open_mat = _glow_mat(OPEN_COLOR)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.4, 0.42, 0.48)
	_base_mesh = CylinderMesh.new()
	_base_mesh.top_radius = SIZE.x * 0.5
	_base_mesh.bottom_radius = SIZE.x * 0.58
	_base_mesh.height = 0.25
	_base_mesh.radial_segments = 6
	_base_mesh.rings = 1
	_base_mesh.material = stone
	_lid_mesh = SphereMesh.new()
	_lid_mesh.radius = 0.24
	_lid_mesh.height = 0.7
	_lid_mesh.radial_segments = 4
	_lid_mesh.rings = 2
	_band_mesh = BoxMesh.new()
	_band_mesh.size = Vector3(0.14, 0.75, 0.14)
	var rune := StandardMaterial3D.new()
	rune.albedo_color = Color(0.3, 0.27, 0.32)
	_band_mesh.material = rune
	_cap_mesh = SphereMesh.new()
	_cap_mesh.radius = 0.07
	_cap_mesh.height = 0.14
	_cap_mesh.radial_segments = 6
	_cap_mesh.rings = 3
	_cap_mesh.material = _glow_mat(Color(0.5, 0.9, 1.0))
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = SIZE.x * 0.85
	_ring_mesh.outer_radius = SIZE.x * 0.95
	_ring_mesh.rings = 24
	_ring_mesh.ring_segments = 4
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


static func _glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.6
	return m


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
	_t += delta
	if not _opened: # linh tinh lơ lửng xoay; giải xong thì nằm yên trên bệ
		_crystal.rotation.y = _t * 1.2
		_crystal.position.y = CRYSTAL_HEIGHT + 0.08 * sin(_t * 2.5)
	if _alert_left > 0.0:
		_alert_left -= delta
		_alert.visible = _alert_left > 0.0
		_alert.scale = Vector3.ONE * (1.0 + 0.1 * sin(_alert_left * 12.0))


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
	# Trận bùng: cột sáng đỏ báo vị trí cho mọi người, kể cả ma tu.
	EventBus.noise_made.emit(global_position, 1.0)
	if _alert == null: # server riêng không vẽ
		return
	_alert_left = ALERT_TIME
	_alert.visible = true
	# Bùng đỏ rồi về màu linh tinh: material riêng trận này chỉ trong lúc tween.
	if _burn_material == null:
		_burn_material = _glow_mat(BURNT_COLOR)
	_burn_material.albedo_color = BURNT_COLOR
	_burn_material.emission = BURNT_COLOR
	_set_body_material(_burn_material)
	if _burn_tween:
		_burn_tween.kill()
	_burn_tween = create_tween().set_parallel()
	_burn_tween.tween_property(_burn_material, "albedo_color", WOOD_COLOR, 0.8)
	_burn_tween.tween_property(_burn_material, "emission", WOOD_COLOR, 0.8)
	_burn_tween.chain()
	_burn_tween.tween_callback(func() -> void:
		_set_body_material(_wood_mat) # xong tween thì về material dùng chung
		_refresh())


func _refresh() -> void:
	if _label == null:
		return
	var p := 0.0
	if GameState.rules:
		p = GameState.rules.safe_progress.get(interactable_id, 0.0)
	_ring.scale = Vector3(0.7 + 0.3 * minf(p, 1.0), 0.1, 0.7 + 0.3 * minf(p, 1.0)) # vòng trận loang ra theo tiến độ
	if p >= 1.0:
		_opened = true
		_set_body_material(_open_mat)
		_crystal.position.y = _base_mesh.height + 0.3
		_label.text = "Đã giải ✦"
	else:
		_label.text = "Trận linh %d%%" % roundi(p * 100)
