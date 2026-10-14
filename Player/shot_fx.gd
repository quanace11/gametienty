extends Node3D
## Hình đạn và vụ nổ (chỉ để nhìn, không quyết định trúng hay trượt).
## Súng thợ săn bắn tên lửa chibi có lửa đuôi, bay thẳng rồi nổ thành quả cầu
## lửa + khói ở chỗ chạm (người đầu tiên trên đường bay, tường, hoặc hết tầm).
## Súng lục bắn viên đạn vàng, chạm thì tóe lửa nhỏ. Ai bị trúng thật do server
## tính (GameState), file này chỉ đoán chỗ nổ cho đẹp.
## Tên lửa và vụ nổ lấy từ pool, không tạo/xóa node mỗi phát; _process chỉ chạy
## khi có thứ đang bay hoặc đang nổ.

const ROCKET_SCALE := 1.6
const EXPLOSION_TIME := 0.7
const ROCKET_BLAST := 1.0 # bán kính quả cầu lửa lớn nhất, mét
const BULLET_BLAST := 0.35
const SMOKE_PUFFS := 5
const HIT_PADDING := 0.3

class Shot:
	var node: Node3D
	var flame: Node3D
	var kind: GameTypes.ShotKind
	var owner_id := 0
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var flight := 0.1
	var age := 0.0
	var targets: Array[Node] = []

class Blast:
	var node: Node3D
	var fire: Node3D
	var core: Node3D
	var puffs: Array[Node3D] = []
	var size := 1.0
	var age := 0.0

var _shots: Array[Shot] = []
var _blasts: Array[Blast] = []
var _free_rockets: Array[Shot] = []
var _free_bullets: Array[Shot] = []
var _free_blasts: Array[Blast] = []

static var _built := false
static var _body_mesh: CylinderMesh
static var _nose_mesh: CylinderMesh
static var _fin_mesh: BoxMesh
static var _flame_mesh: SphereMesh
static var _bullet_mesh: SphereMesh
static var _fire_mesh: SphereMesh
static var _core_mesh: SphereMesh
static var _smoke_mesh: SphereMesh
static var _puff_dirs: Array[Vector3] = []


func _ready() -> void:
	top_level = true
	set_process(false)


## Bắt đầu vẽ một viên đạn bay từ `from` tới `to` trong `flight` giây.
func fire(kind: GameTypes.ShotKind, owner_id: int, from: Vector3, to: Vector3, flight: float) -> void:
	_build_shared()
	var shot := _take_shot(kind)
	shot.kind = kind
	shot.owner_id = owner_id
	shot.from = from
	shot.to = to
	shot.flight = maxf(flight, 0.05)
	shot.age = 0.0
	shot.targets.clear()
	for n in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		if (n as EntityBase).peer_id != owner_id:
			shot.targets.append(n)
	shot.node.visible = true
	shot.node.global_position = from
	if Vector2(to.x - from.x, to.z - from.z).length_squared() > 0.0001:
		shot.node.look_at(to, Vector3.UP)
	_shots.append(shot)
	set_process(true)


func _process(delta: float) -> void:
	var i := _shots.size() - 1
	while i >= 0:
		var shot := _shots[i]
		shot.age += delta
		var t := minf(shot.age / shot.flight, 1.0)
		shot.node.global_position = shot.from.lerp(shot.to, t)
		if shot.flame:
			var f := 1.0 + 0.25 * sin(shot.age * 60.0)
			shot.flame.scale = Vector3(0.16 * f, 0.16 * f, 0.38 * f)
		if t >= 1.0 or _touches_target(shot):
			_explode(shot.node.global_position, ROCKET_BLAST if shot.kind == GameTypes.ShotKind.RIFLE else BULLET_BLAST)
			_release_shot(shot)
			_shots.remove_at(i)
		i -= 1
	i = _blasts.size() - 1
	while i >= 0:
		var b := _blasts[i]
		b.age += delta
		if b.age >= EXPLOSION_TIME:
			b.node.visible = false
			_free_blasts.append(b)
			_blasts.remove_at(i)
		else:
			_animate_blast(b, b.age / EXPLOSION_TIME)
		i -= 1
	if _shots.is_empty() and _blasts.is_empty():
		set_process(false)


## Đạn chạm người đầu tiên mà loại đạn này trúng được (đang nhìn thấy) thì nổ luôn ở đó.
func _touches_target(shot: Shot) -> bool:
	if GameState.rules == null:
		return false
	var r := GameState.rules.shot_radius(shot.kind) + HIT_PADDING
	var p := shot.node.global_position
	for n in shot.targets:
		if not is_instance_valid(n):
			continue
		var e := n as EntityBase
		if not e.visible or not GameState.rules.can_be_shot(shot.kind, e.peer_id):
			continue
		var q := e.flat_position()
		if Vector2(p.x, p.z).distance_squared_to(q) <= r * r:
			return true
	return false


func _explode(pos: Vector3, size: float) -> void:
	var b: Blast = _free_blasts.pop_back() if not _free_blasts.is_empty() else _new_blast()
	b.size = size
	b.age = 0.0
	b.node.global_position = pos
	b.node.visible = true
	_animate_blast(b, 0.0)
	_blasts.append(b)


## t từ 0 tới 1: chớp vàng, rồi cầu lửa cam phồng ra và xẹp, khói bung ra bay lên rồi tan.
func _animate_blast(b: Blast, t: float) -> void:
	var flash := minf(t / 0.06, 1.0) * clampf(1.0 - (t - 0.06) / 0.16, 0.0, 1.0)
	b.core.scale = Vector3.ONE * maxf(b.size * 2.3 * flash, 0.001)
	var grow := 1.0 - pow(1.0 - minf(t / 0.3, 1.0), 3.0)
	var fire := b.size * 2.0 * grow * clampf(1.0 - (t - 0.4) / 0.3, 0.0, 1.0)
	b.fire.scale = Vector3.ONE * maxf(fire, 0.001)
	var puff := b.size * 1.1 * sin(PI * t)
	for k in b.puffs.size():
		var d := _puff_dirs[k]
		b.puffs[k].position = (d * (0.3 + 0.9 * t) + Vector3.UP * (0.9 * t)) * b.size
		b.puffs[k].scale = Vector3.ONE * maxf(puff * (0.8 + 0.1 * k), 0.001)


func _take_shot(kind: GameTypes.ShotKind) -> Shot:
	var rocket := kind == GameTypes.ShotKind.RIFLE
	var pool := _free_rockets if rocket else _free_bullets
	if not pool.is_empty():
		return pool.pop_back()
	return _new_rocket() if rocket else _new_bullet()


func _release_shot(shot: Shot) -> void:
	shot.node.visible = false
	shot.targets.clear()
	(_free_rockets if shot.kind == GameTypes.ShotKind.RIFLE else _free_bullets).append(shot)


## Tên lửa chibi: thân trắng, mũi đỏ, cánh đỏ, lửa đuôi; mũi hướng -Z để look_at quay theo đường bay.
func _new_rocket() -> Shot:
	var shot := Shot.new()
	shot.node = Node3D.new()
	shot.node.scale = Vector3.ONE * ROCKET_SCALE
	add_child(shot.node)
	_part(shot.node, _body_mesh, Vector3.ZERO, Vector3(-90, 0, 0))
	_part(shot.node, _nose_mesh, Vector3(0, 0, -0.36), Vector3(-90, 0, 0))
	_part(shot.node, _fin_mesh, Vector3(0, 0, 0.2), Vector3.ZERO)
	_part(shot.node, _fin_mesh, Vector3(0, 0, 0.2), Vector3(0, 0, 90))
	shot.flame = _part(shot.node, _flame_mesh, Vector3(0, 0, 0.42), Vector3.ZERO)
	return shot


func _new_bullet() -> Shot:
	var shot := Shot.new()
	shot.node = Node3D.new()
	add_child(shot.node)
	_part(shot.node, _bullet_mesh, Vector3.ZERO, Vector3.ZERO)
	return shot


func _new_blast() -> Blast:
	var b := Blast.new()
	b.node = Node3D.new()
	add_child(b.node)
	for k in SMOKE_PUFFS:
		b.puffs.append(_part(b.node, _smoke_mesh, Vector3.ZERO, Vector3.ZERO))
	b.fire = _part(b.node, _fire_mesh, Vector3.ZERO, Vector3.ZERO)
	b.core = _part(b.node, _core_mesh, Vector3.ZERO, Vector3.ZERO)
	return b


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _build_shared() -> void:
	if _built:
		return
	_built = true
	var white := _mat(Color(0.95, 0.95, 0.92), false)
	var red := _mat(Color(0.9, 0.25, 0.2), false)
	_body_mesh = CylinderMesh.new()
	_body_mesh.top_radius = 0.11
	_body_mesh.bottom_radius = 0.11
	_body_mesh.height = 0.5
	_body_mesh.radial_segments = 8
	_body_mesh.rings = 1
	_body_mesh.material = white
	_nose_mesh = CylinderMesh.new()
	_nose_mesh.top_radius = 0.0
	_nose_mesh.bottom_radius = 0.11
	_nose_mesh.height = 0.22
	_nose_mesh.radial_segments = 8
	_nose_mesh.rings = 1
	_nose_mesh.material = red
	_fin_mesh = BoxMesh.new()
	_fin_mesh.size = Vector3(0.38, 0.04, 0.16)
	_fin_mesh.material = red
	_flame_mesh = _sphere(0.5, _mat(Color(1.0, 0.7, 0.15), true))
	_bullet_mesh = _sphere(0.08, _mat(Color(1, 0.95, 0.4), true))
	var fire := _mat(Color(1.0, 0.5, 0.12), false)
	fire.emission_enabled = true # tự sáng nhưng vẫn có khối (mặt khuất tối hơn)
	fire.emission = Color(1.0, 0.4, 0.05)
	fire.emission_energy_multiplier = 0.7
	_fire_mesh = _sphere(0.5, fire)
	_core_mesh = _sphere(0.5, _mat(Color(1.0, 0.92, 0.45), true))
	_smoke_mesh = _sphere(0.5, _mat(Color(0.66, 0.64, 0.62), false))
	for k in SMOKE_PUFFS:
		var a := TAU * k / SMOKE_PUFFS
		_puff_dirs.append(Vector3(cos(a), 0.15 * (k % 2), sin(a)))


static func _mat(color: Color, glow: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _sphere(radius: float, material: Material) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	mesh.material = material
	return mesh
