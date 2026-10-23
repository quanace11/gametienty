class_name Safe
extends Interactable
## Trận linh nhỏ (trong code Core gọi là "safe", xưa là rương): người trốn đứng
## sát trận để giải, càng đông càng nhanh. Trong lúc giải, vòng căn hiện ra (UI
## vẽ), bấm E khi kim vào vùng sáng: vùng đậm giải nhanh thêm + linh thạch, vùng
## mờ ít linh thạch, trượt thì trận bùng đỏ, về 0 và báo vị trí cho ma tu. Giải
## xong thì tính một trận đã phá và văng linh thạch ra sàn. Luật nằm ở
## MatchRules (channel_chest, resolve_qte).
## Hình (models/tran_linh/tran_linh.glb, dựng bằng tools/tran_linh/): bệ cỏ có vòng
## phù văn, 4 đá trấn ở 4 góc, linh thạch lơ lửng xoay giữa trận. Mỗi 25% tiến độ
## một đá trấn rung, phóng linh khí vào linh thạch rồi vỡ vụn; đủ 100% linh thạch
## bay lên, xoay nhanh, sáng rực rồi nổ tung thành mảnh, sóng linh khí loang ra và
## vòng phù văn sáng vàng. Căn trượt (về 0) thì đá trấn mọc lại, linh thạch chớp đỏ.
## Hình chỉ chạy theo EventBus (safe_progress_changed), máy vào sau thấy ngay trạng
## thái hiện tại, không chạy lại hiệu ứng.

const MODEL_PATH := "res://Objects/models/tran_linh/tran_linh.glb"
const FX_SHADER := "res://Objects/shaders/tran_linh_fx.gdshader"
const MODEL_SCALE := 1.3 # mô hình bán kính ~0,95 -> bệ rộng ~2,5 m
const MODEL_SINK := 0.08 # mét bệ lún xuống đất
const BODY_RADIUS := 1.0 # thân trận chắn đường, trong mép bệ một chút
const BODY_HEIGHT := 0.6
const REACH := 0.9 # đứng cách thân trận bao xa thì giải được
const COIN_RING := 1.7 # linh thạch văng ra quanh trận, bán kính (mét)
const ALERT_TIME := 4.0 # giây cột sáng đỏ báo vị trí sau khi trận bùng
const LABEL_HEIGHT := 2.7 # mét
const STONES := 4 # mỗi đá trấn ứng với 1 / STONES tiến độ

# Kích thước trong mô hình (đơn vị mô hình, số in ra từ build_tran_linh.py), để mảnh vỡ rơi đúng mặt.
const GRASS_TOP := 0.161
const RUNE_TOP := 0.313
const PLATFORM_R := 0.9
const RUNE_R := 0.45
const STONE_TOP := 0.45 # luồng linh khí bắt đầu từ chừng này trên chân đá

const SPIN := 1.2 # rad/giây linh thạch xoay, thêm SPIN_PER_STONE mỗi đá đã vỡ
const SPIN_PER_STONE := 0.5
const BOB := 0.06 # biên độ lơ lửng (đơn vị mô hình)
const STONE_CHARGE := 0.35 # giây đá rung, phóng linh khí trước khi vỡ
const STONE_STAGGER := 0.3 # nhảy nhiều mức một lúc (căn trúng) thì các đá vỡ cách nhau chừng này
const CRYSTAL_DELAY := 0.5 # giây sau khi đá cuối vỡ thì linh thạch bắt đầu dồn sức
const CRYSTAL_CHARGE := 1.0 # giây linh thạch bay lên, xoay nhanh, sáng dần
const CRYSTAL_RISE := 0.35
const PIECE_LIFE := 1.4 # giây mảnh đá nằm lại trước khi tan (mảnh linh thạch thêm 0,6)
const PIECE_FADE := 0.45
const GRAVITY := 9.8 / MODEL_SCALE # mảnh vỡ bay trong không gian mô hình

const CYAN := Color(0.35, 0.95, 1.0)
const WHITE := Color(0.9, 1.0, 1.0)
const GOLD := Color(1.0, 0.8, 0.3)
const RED := Color(1.0, 0.12, 0.1)

const CoinScript = preload("res://Objects/coin.gd")

var _model: Node3D # gốc mô hình (đã phóng to, lún xuống), mảnh vỡ bay trong không gian này
var _stones: Array[MeshInstance3D] = []
var _stone_pieces: Array[Array] = [] # mỗi đá: Array[MeshInstance3D] mảnh, ẩn sẵn
var _crystal: MeshInstance3D
var _crystal_pieces: Array[MeshInstance3D] = []
var _aura: MeshInstance3D # hào quang phủ linh thạch (dồn sức, chớp đỏ khi căn trượt)
var _beam: MeshInstance3D # luồng linh khí từ đá trấn vào linh thạch
var _wave: MeshInstance3D # vòng sóng trên mặt đất
var _flash: MeshInstance3D # chớp sáng khi linh thạch nổ
var _seal: MeshInstance3D # vòng phù văn sáng vàng khi đã giải
var _sparks: CPUParticles3D
var _label: Label3D
var _alert: MeshInstance3D
var _alert_left := 0.0
var _t := 0.0
var _spin_angle := 0.0
var _rise := 0.0 # linh thạch đang bay lên khi dồn sức
var _shake := 0.0
var _broken := 0 # số đá trấn đang vỡ trên hình
var _shattered := false
var _epoch := 0 # tăng khi trận về 0: hủy các bước hiệu ứng đang chờ
var _shown_percent := -1
var _flying: Array[MeshInstance3D] = [] # mảnh vỡ đang bay / nằm chờ tan
var _fly_vel := PackedVector3Array()
var _fly_spin := PackedVector3Array()
var _fly_age := PackedFloat32Array()
var _fly_life := PackedFloat32Array()

# Dùng chung cho mọi trận linh.
static var _meshes := {} # tên node trong tran_linh.glb -> Mesh
static var _rest := {} # tên node -> Transform3D trong mô hình
static var _fx_solid: ShaderMaterial
static var _fx_ring: ShaderMaterial
static var _fx_soft: ShaderMaterial
static var _beam_mesh: CylinderMesh
static var _plane_mesh: PlaneMesh
static var _flash_mesh: SphereMesh
static var _spark_mesh: BoxMesh
static var _spark_ramp: Gradient
static var _pillar_mesh: CylinderMesh


func _ready() -> void:
	super()
	add_to_group(GameTypes.GROUP_SAFES)
	set_process(false) # chỉ máy có hình: linh thạch xoay, mảnh vỡ, cột sáng đỏ

	var area_shape := CollisionShape3D.new()
	var area_cyl := CylinderShape3D.new()
	area_cyl.radius = BODY_RADIUS + REACH
	area_cyl.height = 2.0
	area_shape.shape = area_cyl
	area_shape.position.y = 1.0
	add_child(area_shape)

	# Bệ trận chắn đường như tường.
	var body := StaticBody3D.new()
	var body_shape := CollisionShape3D.new()
	var body_cyl := CylinderShape3D.new()
	body_cyl.radius = BODY_RADIUS
	body_cyl.height = BODY_HEIGHT
	body_shape.shape = body_cyl
	body_shape.position.y = BODY_HEIGHT / 2
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
			_refresh(true))
	_refresh(false)


func _build_visuals() -> void:
	_build_shared()
	_model = Node3D.new()
	_model.scale = Vector3.ONE * MODEL_SCALE
	_model.position.y = -MODEL_SINK
	add_child(_model)
	_add_part("nen")
	for k in STONES:
		_stones.append(_add_part("da_%d" % k))
		var pieces: Array[MeshInstance3D] = []
		var i := 0
		while _meshes.has("da_%d_manh_%d" % [k, i]):
			pieces.append(_add_piece("da_%d_manh_%d" % [k, i]))
			i += 1
		_stone_pieces.append(pieces)
	_crystal = _add_part("linh_thach")
	var i := 0
	while _meshes.has("linh_thach_manh_%d" % i):
		_crystal_pieces.append(_add_piece("linh_thach_manh_%d" % i))
		i += 1

	_aura = _fx(_meshes["linh_thach"], _fx_soft, _crystal)
	_aura.scale = Vector3.ONE * 1.12
	_beam = _fx(_beam_mesh, _fx_solid, _model)
	_wave = _fx(_plane_mesh, _fx_ring, _model)
	_flash = _fx(_flash_mesh, _fx_soft, _model)
	_seal = _fx(_plane_mesh, _fx_ring, _model)
	_seal.position.y = RUNE_TOP + 0.01
	_seal.scale = Vector3.ONE * RUNE_R * 2.3
	_seal.set_instance_shader_parameter(&"tint", Color(GOLD, 0.8))

	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.amount = 28
	_sparks.lifetime = 0.9
	_sparks.local_coords = false
	_sparks.mesh = _spark_mesh
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 0.15
	_sparks.direction = Vector3.UP
	_sparks.spread = 70.0
	_sparks.gravity = Vector3(0, -6.0, 0)
	_sparks.damping_min = 1.0
	_sparks.damping_max = 2.0
	_sparks.angle_max = 180.0
	_sparks.color_ramp = _spark_ramp
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(_sparks)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = LABEL_HEIGHT
	_label.font_size = 48
	add_child(_label)

	_alert = MeshInstance3D.new()
	_alert.mesh = _pillar_mesh
	_alert.position.y = 3.0
	_alert.visible = false
	add_child(_alert)


func _add_part(part: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part # mảnh vỡ tra lại vị trí gốc theo tên
	mi.mesh = _meshes[part]
	mi.transform = _rest[part]
	_model.add_child(mi)
	return mi


func _add_piece(part: String) -> MeshInstance3D:
	var mi := _add_part(part)
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Node hiệu ứng cộng sáng, ẩn sẵn; màu và độ sáng đặt bằng tint.
func _fx(mesh: Mesh, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	return mi


static func _build_shared() -> void:
	if not _meshes.is_empty():
		return
	var scene: Node3D = (load(MODEL_PATH) as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		_meshes[String(mi.name)] = mi.mesh
		_rest[String(mi.name)] = mi.transform
	scene.free()
	var shader: Shader = load(FX_SHADER)
	_fx_solid = _fx_material(shader, 0)
	_fx_ring = _fx_material(shader, 1)
	_fx_soft = _fx_material(shader, 2)
	_beam_mesh = CylinderMesh.new()
	_beam_mesh.top_radius = 0.035
	_beam_mesh.bottom_radius = 0.05
	_beam_mesh.height = 1.0
	_beam_mesh.radial_segments = 6
	_beam_mesh.rings = 1
	_plane_mesh = PlaneMesh.new()
	_plane_mesh.size = Vector2.ONE
	_flash_mesh = SphereMesh.new()
	_flash_mesh.radius = 0.5
	_flash_mesh.height = 1.0
	_flash_mesh.radial_segments = 12
	_flash_mesh.rings = 6
	_spark_mesh = BoxMesh.new()
	_spark_mesh.size = Vector3.ONE * 0.05
	_spark_mesh.material = _fx_solid
	_spark_ramp = Gradient.new()
	_spark_ramp.set_color(0, Color(1, 1, 1, 1))
	_spark_ramp.set_color(1, Color(1, 1, 1, 0))
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
	for m: Material in [_fx_solid, _fx_ring, _fx_soft, alert_mat]: # hiệu ứng chỉ hiện giữa trận
		RenderWarmup.register(m)


static func _fx_material(shader: Shader, shape: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"shape", shape)
	return m


func can_interact(entity: EntityBase) -> bool:
	return not entity.is_hunter() and GameTypes.is_active(entity.state)


func interact_tick(users: Array[EntityBase], delta: float) -> void:
	var rules := GameState.rules
	for e in users:
		GameState.server_channel_chest(e.peer_id, interactable_id, delta)
		var rec := rules.record(e.peer_id)
		if rec and rec.qte_chest == interactable_id and e.just_pressed(&"interact"):
			GameState.server_resolve_qte(e.peer_id, e.press_time(&"interact"))


func _process(delta: float) -> void:
	_t += delta
	if _crystal.visible: # linh thạch lơ lửng xoay, nhanh dần theo số đá đã vỡ
		_spin_angle += delta * (SPIN + SPIN_PER_STONE * _broken + 14.0 * _rise)
		var xf: Transform3D = _rest["linh_thach"]
		xf.origin.y += BOB * sin(_t * 2.5) + _rise
		if _shake > 0.0:
			xf.origin += Vector3(sin(_t * 71.0), 0, cos(_t * 63.0)) * _shake
		_crystal.transform = xf.rotated_local(Vector3.UP, _spin_angle)
	if not _flying.is_empty():
		_update_pieces(delta)
	if _alert_left > 0.0:
		_alert_left -= delta
		_alert.visible = _alert_left > 0.0
		_alert.scale = Vector3.ONE * (1.0 + 0.1 * sin(_alert_left * 12.0))


## Hình theo tiến độ: mỗi 25% một đá trấn vỡ, 100% thì linh thạch vỡ. animate = false
## (vừa dựng, máy vào giữa trận) thì đặt thẳng trạng thái, không chạy hiệu ứng.
func _refresh(animate: bool) -> void:
	var p := 0.0
	if GameState.rules:
		p = GameState.rules.safe_progress.get(interactable_id, 0.0)
	var percent := roundi(p * 100)
	if percent != _shown_percent: # chỉ vẽ lại chữ khi số đổi
		_shown_percent = percent
		_label.text = "Đã giải ✦" if p >= 1.0 else "Trận linh %d%%" % percent
	var target := STONES if p >= 1.0 else clampi(floori(p * STONES + 0.0001), 0, STONES - 1)
	if target < _broken: # căn trượt, trận về 0: đá trấn mọc lại
		_restore(target, animate)
	var delay := 0.0
	while _broken < target:
		if animate:
			_break_stone(_broken, delay)
			delay += STONE_STAGGER
		else:
			_stones[_broken].visible = false
		_broken += 1
	if p >= 1.0 and not _shattered:
		_shattered = true
		if animate:
			_shatter_crystal(delay + STONE_CHARGE + CRYSTAL_DELAY)
		else:
			_crystal.visible = false
			_seal.visible = true


func _restore(target: int, animate: bool) -> void:
	_epoch += 1
	_clear_pieces()
	_beam.visible = false
	for k in range(target, STONES):
		var stone := _stones[k]
		stone.transform = _rest["da_%d" % k]
		stone.visible = true
		if animate and k < _broken:
			stone.scale = Vector3.ONE * 0.05
			create_tween().tween_property(stone, "scale", Vector3.ONE, 0.45) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_broken = target
	if _shattered: # MatchRules không cho trận đã giải về 0, nhưng hình vẫn chịu được
		_shattered = false
		_crystal.visible = true
		_seal.visible = false
	_rise = 0.0
	_shake = 0.0


## Đá trấn k: rung, phóng luồng linh khí vào linh thạch, rồi vỡ vụn văng ra ngoài.
func _break_stone(k: int, delay: float) -> void:
	var epoch := _epoch
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(t: float) -> void:
		if epoch != _epoch:
			return
		var xf: Transform3D = _rest["da_%d" % k]
		xf.origin += Vector3(sin(t * 90.0), 0, cos(t * 77.0)) * 0.025 * t
		_stones[k].transform = xf.scaled_local(Vector3.ONE * (1.0 + 0.08 * t))
		_show_beam(k, t), 0.0, 1.0, STONE_CHARGE)
	tw.tween_callback(func() -> void:
		if epoch == _epoch:
			_burst_stone(k))


func _show_beam(k: int, t: float) -> void:
	var from: Vector3 = _rest["da_%d" % k].origin + Vector3(0, STONE_TOP, 0)
	var to := _crystal.position
	var dir := to - from
	_beam.visible = true
	_beam.basis = Basis.looking_at(dir.normalized()) * Basis(Vector3.RIGHT, -PI / 2) # trục Y của trụ theo luồng
	_beam.scale = Vector3(0.5 + t, dir.length(), 0.5 + t)
	_beam.position = from + dir / 2
	_beam.set_instance_shader_parameter(&"tint", Color(CYAN, 0.4 + 0.6 * t))
	_aura.visible = true
	_aura.set_instance_shader_parameter(&"tint", Color(CYAN, 0.5 * t))


func _burst_stone(k: int) -> void:
	var stone := _stones[k]
	stone.visible = false
	stone.transform = _rest["da_%d" % k]
	var center := stone.position + Vector3(0, STONE_TOP * 0.5, 0)
	var out := Vector3(center.x, 0, center.z).normalized()
	for piece: MeshInstance3D in _stone_pieces[k]:
		var rest: Transform3D = _rest[String(piece.name)]
		var away := (rest.origin - center).normalized()
		var vel := (out * 1.2 + away * 0.8).normalized() * randf_range(0.5, 1.0) + Vector3.UP * randf_range(1.0, 1.8)
		_launch(piece, rest, vel, 8.0, PIECE_LIFE)
	_burst_fx(center, CYAN, 0.9, 2.5, 4.0)
	_beam.visible = false
	# Linh thạch hút linh khí: nảy lên rồi về, hào quang tắt dần.
	var tw := create_tween().set_parallel()
	tw.tween_method(func(a: float) -> void: _aura.set_instance_shader_parameter(&"tint", Color(CYAN, a)), 0.9, 0.0, 0.5)
	tw.tween_property(_crystal, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(_crystal, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void: _aura.visible = false)


## 100%: linh thạch bay lên, xoay nhanh, sáng dần rồi nổ tung.
func _shatter_crystal(delay: float) -> void:
	var epoch := _epoch
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(t: float) -> void:
		if epoch != _epoch:
			return
		_rise = CRYSTAL_RISE * t * t
		_shake = 0.03 * t
		_aura.visible = true
		_aura.scale = Vector3.ONE * (1.1 + 0.2 * t)
		_aura.set_instance_shader_parameter(&"tint", Color(CYAN.lerp(WHITE, t), 0.3 + 0.9 * t)), 0.0, 1.0, CRYSTAL_CHARGE)
	tw.tween_callback(func() -> void:
		if epoch == _epoch:
			_burst_crystal())


func _burst_crystal() -> void:
	var at := _crystal.transform
	var center := at.origin
	_crystal.visible = false
	_aura.visible = false
	_aura.scale = Vector3.ONE * 1.12
	_rise = 0.0
	_shake = 0.0
	var rest_inv: Transform3D = _rest["linh_thach"].affine_inverse()
	for piece in _crystal_pieces:
		var xf: Transform3D = at * rest_inv * _rest[String(piece.name)] # mảnh đặt theo linh thạch lúc nổ (đang xoay, bay lên)
		var away := xf.origin - center
		var vel := Vector3(away.x, 0, away.z).normalized() * randf_range(1.0, 1.8) + Vector3.UP * randf_range(0.8, 2.0)
		_launch(piece, xf, vel, 14.0, PIECE_LIFE + 0.6)
	_burst_fx(center, WHITE, 1.6, 3.0, 4.5)
	_flash.visible = true
	_flash.position = center
	var tw := create_tween().set_parallel()
	tw.tween_property(_flash, "scale", Vector3.ONE * 2.2, 0.45).from(Vector3.ONE * 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float) -> void: _flash.set_instance_shader_parameter(&"tint", Color(WHITE, a)), 1.2, 0.0, 0.45)
	tw.chain().tween_callback(func() -> void: _flash.visible = false)
	# Vòng phù văn sáng vàng dần: trận đã giải.
	_seal.visible = true
	_seal.set_instance_shader_parameter(&"tint", Color(GOLD, 0.0))
	var seal := create_tween()
	seal.tween_method(func(a: float) -> void: _seal.set_instance_shader_parameter(&"tint", Color(GOLD, a)), 0.0, 0.8, 0.8).set_delay(0.3)


## Tia lửa + vòng sóng tại chỗ vỡ (không gian mô hình). Vòng sóng loang ra tới wave_size.
func _burst_fx(at: Vector3, color: Color, wave_size: float, speed_min: float, speed_max: float) -> void:
	_sparks.position = at
	_sparks.initial_velocity_min = speed_min
	_sparks.initial_velocity_max = speed_max
	_sparks.set_instance_shader_parameter(&"tint", Color(color, 1.0))
	_sparks.restart()
	var ground := _floor_at(at) + 0.02
	_wave.visible = true
	_wave.position = Vector3(at.x, ground, at.z)
	var tw := create_tween().set_parallel()
	tw.tween_property(_wave, "scale", Vector3.ONE * wave_size * 2.0, 0.6).from(Vector3.ONE * 0.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float) -> void: _wave.set_instance_shader_parameter(&"tint", Color(color, a)), 1.0, 0.0, 0.6)
	tw.chain().tween_callback(func() -> void: _wave.visible = false)


func _launch(piece: MeshInstance3D, xf: Transform3D, vel: Vector3, spin: float, life: float) -> void:
	piece.transform = xf
	piece.visible = true
	_flying.append(piece)
	_fly_vel.append(vel)
	_fly_spin.append(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * spin)
	_fly_age.append(0.0)
	_fly_life.append(life * randf_range(0.85, 1.15))


## Mảnh vỡ: rơi, nảy trên bệ / mặt đất, nằm lại một lúc rồi thu nhỏ biến mất.
func _update_pieces(delta: float) -> void:
	var i := _flying.size() - 1
	while i >= 0:
		var piece := _flying[i]
		_fly_age[i] += delta
		var age := _fly_age[i]
		if age >= _fly_life[i] + PIECE_FADE:
			piece.visible = false
			_remove_piece(i)
			i -= 1
			continue
		var vel := _fly_vel[i]
		var spin := _fly_spin[i]
		vel.y -= GRAVITY * delta
		var pos := piece.position + vel * delta
		var floor_y := _floor_at(pos) + 0.03
		if pos.y < floor_y:
			pos.y = floor_y
			if vel.y < -0.6: # nảy
				vel = Vector3(vel.x * 0.5, -vel.y * 0.3, vel.z * 0.5)
				spin *= 0.5
			else: # nằm yên
				vel = Vector3.ZERO
				spin *= 0.0
		_fly_vel[i] = vel
		_fly_spin[i] = spin
		var basis := piece.basis
		if spin != Vector3.ZERO:
			basis = Basis(spin.normalized(), spin.length() * delta) * basis
		if age > _fly_life[i]: # tan dần
			var s := 1.0 - (age - _fly_life[i]) / PIECE_FADE
			basis = basis.orthonormalized().scaled(Vector3.ONE * maxf(s, 0.01))
		piece.transform = Transform3D(basis, pos)
		i -= 1


func _remove_piece(i: int) -> void:
	var last := _flying.size() - 1 # đổi chỗ với phần tử cuối rồi bỏ, khỏi dời mảng
	_flying[i] = _flying[last]
	_fly_vel[i] = _fly_vel[last]
	_fly_spin[i] = _fly_spin[last]
	_fly_age[i] = _fly_age[last]
	_fly_life[i] = _fly_life[last]
	_flying.resize(last)
	_fly_vel.resize(last)
	_fly_spin.resize(last)
	_fly_age.resize(last)
	_fly_life.resize(last)


func _clear_pieces() -> void:
	for piece in _flying:
		piece.visible = false
	_flying.clear()
	_fly_vel.clear()
	_fly_spin.clear()
	_fly_age.clear()
	_fly_life.clear()


## Mặt để mảnh vỡ rơi xuống (không gian mô hình): vòng phù văn, mặt cỏ trên bệ, mặt đất.
func _floor_at(p: Vector3) -> float:
	var r := Vector2(p.x, p.z).length()
	if r < RUNE_R:
		return RUNE_TOP
	if r < PLATFORM_R:
		return GRASS_TOP
	return MODEL_SINK / MODEL_SCALE


func _on_unlocked(id: int, _unlocked: int, _required: int) -> void:
	if id != interactable_id:
		return
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
	if not _crystal.visible:
		return
	# Linh thạch chớp đỏ rồi tắt.
	_aura.visible = true
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void: _aura.set_instance_shader_parameter(&"tint", Color(RED, a)), 1.5, 0.0, 0.8)
	tw.tween_callback(func() -> void: _aura.visible = false)
