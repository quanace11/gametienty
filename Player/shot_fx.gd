extends Node3D
## Hình phi kiếm và kiếm khí (chỉ để nhìn, không quyết định trúng hay trượt).
## Ma tu (súng thợ săn) hóa ra một thanh phi kiếm tím đen trên vai, kiếm xoay
## mũi về phía mục tiêu rồi phóng đi để lại vệt sáng; chạm người đầu tiên trên
## đường bay, tường hoặc hết tầm thì nổ kiếm khí: chớp sáng, vòng khí loang ra và
## mảnh sáng văng tung. Phù kiếm (súng lục) là thanh kiếm nhỏ màu ngọc, nổ nhỏ.
## Ai bị trúng thật do server tính (GameState), file này chỉ đoán chỗ nổ cho đẹp.
## Thời điểm tới nơi giữ đúng `flight` của server: đoạn hóa kiếm ăn vào đầu đường bay.
## Trúng người thật (EventBus.player_hit) thì thêm một vụ nổ lửa vàng đỏ to hơn
## ngay chỗ người đó (hit_burst), để trúng nhìn khác hẳn trượt.
## Kiếm và vụ nổ lấy từ pool, không tạo/xóa node mỗi phát; _process chỉ chạy
## khi có thứ đang bay hoặc đang nổ. Lúc vào trận dựng sẵn mỗi loại một cái (ẩn)
## và khai báo material với RenderWarmup để phát bắn đầu tiên không khựng.

const SWORD_SCALE := 2.3
const SMALL_SWORD_SCALE := 1.1
const CONJURE_TIME := 0.16 # giây hóa kiếm trên vai (tối đa, kẹp theo flight)
const CONJURE_HEIGHT := 0.7 # kiếm hiện cao hơn chỗ bắn bao nhiêu mét
const SPIN_SPEED := 14.0 # rad/giây, kiếm lăn quanh trục bay
const EXPLOSION_TIME := 0.6
const SWORD_BLAST := 1.0 # bán kính kiếm khí lớn nhất, mét
const SMALL_BLAST := 0.4
const HIT_BLAST := 1.5 # vụ nổ khi trúng người
const HIT_HEIGHT := 0.9 # nổ ngang ngực
const SHARDS := 6
const HIT_PADDING := 0.3

class Shot:
	var node: Node3D
	var blade: Node3D # phần lăn quanh trục bay
	var trail: Node3D
	var kind: GameTypes.ShotKind
	var owner_id := 0
	var from := Vector3.ZERO
	var hover := Vector3.ZERO
	var to := Vector3.ZERO
	var flight := 0.1
	var conjure := 0.05
	var age := 0.0
	var targets: Array[Node] = []

class Blast:
	var node: Node3D
	var ring: Node3D
	var core: Node3D
	var shards: Array[Node3D] = []
	var kind: GameTypes.ShotKind
	var hit := false # vụ nổ trúng người (màu lửa), về pool riêng
	var size := 1.0
	var age := 0.0

var _shots: Array[Shot] = []
var _blasts: Array[Blast] = []
var _free_swords: Array[Shot] = []
var _free_small: Array[Shot] = []
var _free_blasts: Array[Blast] = []
var _free_small_blasts: Array[Blast] = []
var _free_hit_blasts: Array[Blast] = []

## Bộ mesh một loại kiếm (màu riêng), dùng chung cho mọi thanh cùng loại.
class SwordSet:
	var blade: BoxMesh
	var tip: PrismMesh
	var guard: BoxMesh
	var grip: CylinderMesh
	var pommel: SphereMesh
	var trail: BoxMesh
	var ring: TorusMesh
	var core: SphereMesh
	var shard: PrismMesh

static var _built := false
static var _demon: SwordSet # phi kiếm ma tu
static var _jade: SwordSet # phù kiếm
static var _fire: SwordSet # vụ nổ trúng người (chỉ dùng vòng, lõi, mảnh)
static var _shard_dirs: Array[Vector3] = []


func _ready() -> void:
	top_level = true
	set_process(false)
	_build_shared()
	for kind: GameTypes.ShotKind in [GameTypes.ShotKind.RIFLE, GameTypes.ShotKind.BULLET]:
		var shot := _take_shot(kind)
		shot.kind = kind
		_release_shot(shot)
		for hit: bool in [false, true]:
			var b := _new_blast(kind, hit)
			b.node.visible = false
			_blast_pool(kind, hit).append(b)


## Bắt đầu vẽ một thanh kiếm bay từ `from` tới `to` trong `flight` giây.
func fire(kind: GameTypes.ShotKind, owner_id: int, from: Vector3, to: Vector3, flight: float) -> void:
	_build_shared()
	var shot := _take_shot(kind)
	shot.kind = kind
	shot.owner_id = owner_id
	shot.from = from
	shot.to = to
	shot.flight = maxf(flight, 0.05)
	shot.conjure = minf(CONJURE_TIME, shot.flight * 0.35)
	shot.hover = from + Vector3.UP * CONJURE_HEIGHT * (1.0 if kind == GameTypes.ShotKind.RIFLE else 0.5)
	shot.age = 0.0
	shot.targets.clear()
	for n in get_tree().get_nodes_in_group(GameTypes.GROUP_ENTITIES):
		if (n as EntityBase).peer_id != owner_id:
			shot.targets.append(n)
	shot.node.visible = true
	shot.node.global_position = shot.hover
	shot.node.scale = Vector3.ONE * 0.001
	shot.trail.visible = false
	if shot.hover.distance_squared_to(to) > 0.0001:
		shot.node.look_at(to, Vector3.UP)
	_shots.append(shot)
	set_process(true)


func _process(delta: float) -> void:
	var i := _shots.size() - 1
	while i >= 0:
		var shot := _shots[i]
		shot.age += delta
		var full := SWORD_SCALE if shot.kind == GameTypes.ShotKind.RIFLE else SMALL_SWORD_SCALE
		shot.blade.rotation.z += SPIN_SPEED * delta
		var done := false
		if shot.age < shot.conjure:
			# Hóa kiếm: phồng ra từ hư không, hơi rung trên vai.
			var c := shot.age / shot.conjure
			shot.node.scale = Vector3.ONE * maxf(full * (1.0 - pow(1.0 - c, 3.0)), 0.001)
			shot.node.global_position = shot.hover + Vector3.UP * 0.05 * sin(shot.age * 50.0)
		else:
			var t := minf((shot.age - shot.conjure) / maxf(shot.flight - shot.conjure, 0.01), 1.0)
			shot.node.scale = Vector3.ONE * full
			shot.node.global_position = shot.hover.lerp(shot.to, t * t * (2.0 - t)) # phóng vút, chậm dần ở cuối
			shot.trail.visible = true
			done = t >= 1.0 or _touches_target(shot)
		if done:
			_explode(shot.kind, shot.node.global_position)
			_release_shot(shot)
			_shots.remove_at(i)
		i -= 1
	i = _blasts.size() - 1
	while i >= 0:
		var b := _blasts[i]
		b.age += delta
		if b.age >= EXPLOSION_TIME:
			b.node.visible = false
			_blast_pool(b.kind, b.hit).append(b)
			_blasts.remove_at(i)
		else:
			_animate_blast(b, b.age / EXPLOSION_TIME)
		i -= 1
	if _shots.is_empty() and _blasts.is_empty():
		set_process(false)


## Kiếm chạm người đầu tiên mà loại này trúng được (đang nhìn thấy) thì nổ luôn ở đó.
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


## Nổ lửa to ở chỗ người vừa bị trúng (`pos` là chân người đó).
func hit_burst(kind: GameTypes.ShotKind, pos: Vector3) -> void:
	_build_shared()
	_start_blast(kind, true, pos + Vector3.UP * HIT_HEIGHT, HIT_BLAST)
	set_process(true)


func _explode(kind: GameTypes.ShotKind, pos: Vector3) -> void:
	var big := kind == GameTypes.ShotKind.RIFLE
	_start_blast(kind, false, pos, SWORD_BLAST if big else SMALL_BLAST)


func _start_blast(kind: GameTypes.ShotKind, hit: bool, pos: Vector3, size: float) -> void:
	var pool := _blast_pool(kind, hit)
	var b: Blast = pool.pop_back() if not pool.is_empty() else _new_blast(kind, hit)
	b.size = size
	b.age = 0.0
	b.node.global_position = pos
	b.node.visible = true
	_animate_blast(b, 0.0)
	_blasts.append(b)


## t từ 0 tới 1: chớp sáng, vòng kiếm khí loang ra sát đất rồi mỏng dần, mảnh sáng văng ra rồi tắt.
func _animate_blast(b: Blast, t: float) -> void:
	var flash := minf(t / 0.05, 1.0) * clampf(1.0 - (t - 0.05) / 0.18, 0.0, 1.0)
	b.core.scale = Vector3.ONE * maxf(b.size * 1.6 * flash, 0.001)
	var grow := 1.0 - pow(1.0 - minf(t / 0.45, 1.0), 3.0)
	var thin := clampf(1.0 - (t - 0.35) / 0.65, 0.0, 1.0)
	b.ring.scale = Vector3(b.size * 2.4 * grow, maxf(thin, 0.001), b.size * 2.4 * grow) + Vector3.ONE * 0.001
	var fly := 1.0 - pow(1.0 - t, 2.0)
	var shard := b.size * (1.0 - t)
	for k in b.shards.size():
		var d := _shard_dirs[k]
		b.shards[k].position = (d * 1.6 * fly + Vector3.UP * 0.6 * sin(PI * t)) * b.size
		b.shards[k].scale = Vector3.ONE * maxf(shard, 0.001)


func _blast_pool(kind: GameTypes.ShotKind, hit: bool) -> Array[Blast]:
	if hit:
		return _free_hit_blasts
	return _free_blasts if kind == GameTypes.ShotKind.RIFLE else _free_small_blasts


func _take_shot(kind: GameTypes.ShotKind) -> Shot:
	var big := kind == GameTypes.ShotKind.RIFLE
	var pool := _free_swords if big else _free_small
	if not pool.is_empty():
		return pool.pop_back()
	return _new_sword(_demon if big else _jade)


func _release_shot(shot: Shot) -> void:
	shot.node.visible = false
	shot.targets.clear()
	(_free_swords if shot.kind == GameTypes.ShotKind.RIFLE else _free_small).append(shot)


## Thanh kiếm: lưỡi + mũi, chắn kiếm, chuôi, núm; mũi hướng -Z để look_at quay theo đường bay.
func _new_sword(s: SwordSet) -> Shot:
	var shot := Shot.new()
	shot.node = Node3D.new()
	add_child(shot.node)
	shot.blade = Node3D.new()
	shot.node.add_child(shot.blade)
	_part(shot.blade, s.blade, Vector3(0, 0, -0.12), Vector3.ZERO)
	_part(shot.blade, s.tip, Vector3(0, 0, -0.52), Vector3(-90, 0, 0))
	_part(shot.blade, s.guard, Vector3(0, 0, 0.24), Vector3.ZERO)
	_part(shot.blade, s.grip, Vector3(0, 0, 0.36), Vector3(90, 0, 0))
	_part(shot.blade, s.pommel, Vector3(0, 0, 0.47), Vector3.ZERO)
	shot.trail = _part(shot.node, s.trail, Vector3(0, 0, 0.9), Vector3.ZERO)
	return shot


func _new_blast(kind: GameTypes.ShotKind, hit: bool) -> Blast:
	var s := _fire if hit else (_demon if kind == GameTypes.ShotKind.RIFLE else _jade)
	var b := Blast.new()
	b.kind = kind
	b.hit = hit
	b.node = Node3D.new()
	add_child(b.node)
	for k in SHARDS:
		var sh := _part(b.node, s.shard, Vector3.ZERO, Vector3.ZERO)
		sh.look_at_from_position(Vector3.ZERO, _shard_dirs[k], Vector3.UP if absf(_shard_dirs[k].y) < 0.9 else Vector3.FORWARD)
		b.shards.append(sh)
	b.ring = _part(b.node, s.ring, Vector3(0, 0.1, 0), Vector3.ZERO)
	b.core = _part(b.node, s.core, Vector3.ZERO, Vector3.ZERO)
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
	# Ma tu: lưỡi tím đen tỏa sáng đỏ tím, chắn và chuôi đen, vệt tím.
	_demon = _sword_set(Color(0.3, 0.08, 0.4), Color(0.6, 0.08, 0.35), Color(0.12, 0.08, 0.14), Color(0.75, 0.35, 1.0, 0.45))
	# Phù kiếm: lưỡi ngọc, chắn vàng, vệt xanh ngọc.
	_jade = _sword_set(Color(0.55, 0.95, 0.85), Color(0.3, 0.9, 0.8), Color(0.85, 0.65, 0.25), Color(0.45, 1.0, 0.85, 0.45))
	# Trúng người: lửa vàng cam, lõi trắng vàng.
	_fire = _sword_set(Color(1.0, 0.6, 0.2), Color(1.0, 0.45, 0.1), Color(0.2, 0.1, 0.05), Color(1.0, 0.7, 0.3, 0.45))
	for k in SHARDS:
		var a := TAU * k / SHARDS
		_shard_dirs.append(Vector3(cos(a), 0.35 * ((k % 3) - 1), sin(a)).normalized())
	for s: SwordSet in [_demon, _jade, _fire]:
		for mesh: Mesh in [s.blade, s.guard, s.pommel, s.trail, s.ring]:
			RenderWarmup.register(mesh)


static func _sword_set(blade_color: Color, glow_color: Color, hilt_color: Color, trail_color: Color) -> SwordSet:
	var s := SwordSet.new()
	var blade := StandardMaterial3D.new()
	blade.albedo_color = blade_color
	blade.metallic = 0.3
	blade.emission_enabled = true # tự sáng như linh khí phủ lưỡi kiếm
	blade.emission = glow_color
	blade.emission_energy_multiplier = 0.6
	var hilt := _mat(hilt_color, false)
	var glow := _mat(glow_color.lightened(0.3), true)
	var trail := _mat(trail_color, true)
	trail.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.blade = BoxMesh.new()
	s.blade.size = Vector3(0.09, 0.025, 0.64)
	s.blade.material = blade
	s.tip = PrismMesh.new()
	s.tip.size = Vector3(0.09, 0.16, 0.025)
	s.tip.material = blade
	s.guard = BoxMesh.new()
	s.guard.size = Vector3(0.26, 0.05, 0.05)
	s.guard.material = hilt
	s.grip = CylinderMesh.new()
	s.grip.top_radius = 0.025
	s.grip.bottom_radius = 0.025
	s.grip.height = 0.2
	s.grip.radial_segments = 6
	s.grip.rings = 1
	s.grip.material = hilt
	s.pommel = _sphere(0.04, glow)
	s.trail = BoxMesh.new()
	s.trail.size = Vector3(0.14, 0.02, 1.1)
	s.trail.material = trail
	s.ring = TorusMesh.new()
	s.ring.inner_radius = 0.42
	s.ring.outer_radius = 0.5
	s.ring.rings = 16
	s.ring.ring_segments = 4
	s.ring.material = glow
	s.core = _sphere(0.5, glow)
	s.shard = PrismMesh.new()
	s.shard.size = Vector3(0.1, 0.35, 0.03)
	s.shard.material = glow
	return s


static func _mat(color: Color, unshaded: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if unshaded:
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
