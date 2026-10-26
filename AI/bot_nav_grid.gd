class_name BotNavGrid
extends RefCounted
## Lưới tìm đường cho bot (A*), dựng một lần mỗi bản đồ từ chính khối va chạm
## layer 1 (tường, đá, cây, rương, nhà tù...), nên bản đồ nào cũng dùng được mà
## không cần NavMesh. Mọi bot của một trận dùng chung một lưới.
## Ô 0,5 m; ô nào quả cầu cỡ người (PROBE_RADIUS) chạm vật cản thì là ô đặc.
## Vật đặt giữa trận (hộp gỗ) không có trong lưới: bot kẹt thì tự rẽ.

const CELL := 0.5 # mét
const PROBE_RADIUS := 0.38 # hơi to hơn người trốn (0,32) để không đi sát mép tường
const PROBE_Y := 0.75 # tâm quả cầu dò: trên mặt sàn, thấp hơn đá (cao 1 m)
const MARGIN := 6.0 # mét quanh khung bản đồ (pháp trận truyền tống nằm ngoài bờ tây)
const NEAR_FREE := 4 # ô: điểm nằm trong ô đặc thì tìm ô trống gần nhất trong bán kính này

static var _cache := {} # instance id của bản đồ -> BotNavGrid

var build_ms := 0 ## thời gian dựng (đo để ghi log)
var logged := false ## bot đầu tiên đã ghi log thời gian dựng
var _astar := AStarGrid2D.new()
var _origin := Vector2.ZERO
var _size := Vector2i.ZERO
var _zone := PackedInt32Array() # ô -> số vùng liền nhau (-1 = ô đặc); khác vùng thì không tìm đường


## Lưới của bản đồ `map`, dựng lần đầu được hỏi.
static func for_map(map: Node3D) -> BotNavGrid:
	var key := map.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	for k: int in _cache.keys(): # bản đồ trận cũ đã bị xóa
		if not is_instance_id_valid(k):
			_cache.erase(k)
	var grid := BotNavGrid.new()
	grid._build(map)
	_cache[key] = grid
	return grid


func _build(map: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var bounds: Rect2 = map.get_bounds() if map.has_method(&"get_bounds") else Rect2()
	bounds = bounds.grow(MARGIN)
	_origin = bounds.position
	_size = Vector2i(ceili(bounds.size.x / CELL), ceili(bounds.size.y / CELL))
	_astar.region = Rect2i(Vector2i.ZERO, _size)
	_astar.cell_size = Vector2(CELL, CELL)
	_astar.offset = _origin + Vector2(CELL, CELL) / 2.0
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	var space := map.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = PROBE_RADIUS
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.collision_mask = 1
	var xf := Transform3D.IDENTITY
	for y in _size.y:
		for x in _size.x:
			var p := _astar.offset + Vector2(x, y) * CELL
			xf.origin = Vector3(p.x, PROBE_Y, p.y)
			q.transform = xf
			if not space.intersect_shape(q, 1).is_empty():
				_astar.set_point_solid(Vector2i(x, y))
	_label_zones()
	build_ms = Time.get_ticks_msec() - t0


## Đánh số vùng liền nhau (loang 4 hướng), để biết trước hai điểm không nối
## với nhau (trong / ngoài nhà tù) mà khỏi để A* duyệt hết bản đồ.
func _label_zones() -> void:
	_zone.resize(_size.x * _size.y)
	_zone.fill(-2)
	var stack := PackedInt32Array()
	var zone := 0
	for i in _zone.size():
		if _zone[i] != -2:
			continue
		if _astar.is_point_solid(Vector2i(i % _size.x, i / _size.x)):
			_zone[i] = -1
			continue
		_zone[i] = zone
		stack.append(i)
		while not stack.is_empty():
			var c := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var cx := c % _size.x
			var cy := c / _size.x
			for n: Vector2i in [Vector2i(cx + 1, cy), Vector2i(cx - 1, cy), Vector2i(cx, cy + 1), Vector2i(cx, cy - 1)]:
				if n.x < 0 or n.y < 0 or n.x >= _size.x or n.y >= _size.y:
					continue
				var j := n.y * _size.x + n.x
				if _zone[j] != -2:
					continue
				if _astar.is_point_solid(n):
					_zone[j] = -1
				else:
					_zone[j] = zone
					stack.append(j)
		zone += 1


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - _origin.x) / CELL), floori((p.y - _origin.y) / CELL))


func is_free(p: Vector2) -> bool:
	var c := to_cell(p)
	return _astar.is_in_boundsv(c) and not _astar.is_point_solid(c)


## Đường đi trên mặt sàn từ `from` tới `to`. Đích nằm trong vật cản (giữa rương)
## thì tới ô trống sát đó. Rỗng nếu không tới được (đích bên kia tường nhà tù):
## bot đi thẳng như cũ.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _nearest_free(to_cell(from))
	var b := _nearest_free(to_cell(to))
	if a.x < 0 or b.x < 0 or _zone[a.y * _size.x + a.x] != _zone[b.y * _size.x + b.x]:
		return PackedVector2Array()
	return _astar.get_point_path(a, b)


## Đi thẳng từ `a` tới `b` không vướng ô đặc. Bỏ qua đoạn `skip_start` đầu (mình
## đang đứng sát tường) và `skip_end` cuối (đích là giữa rương).
func clear_line(a: Vector2, b: Vector2, skip_start := 0.6, skip_end := 0.0) -> bool:
	var length := a.distance_to(b)
	var stop := length - skip_end
	var d := skip_start
	while d < stop:
		if not is_free(a.lerp(b, d / length)):
			return false
		d += CELL * 0.75
	return true


func _clamp(c: Vector2i) -> Vector2i:
	return Vector2i(clampi(c.x, 0, _size.x - 1), clampi(c.y, 0, _size.y - 1))


## Ô trống gần `c` nhất (chính nó nếu trống), (-1, -1) nếu quanh đó toàn ô đặc.
func _nearest_free(c: Vector2i) -> Vector2i:
	c = _clamp(c)
	if not _astar.is_point_solid(c):
		return c
	for r in range(1, NEAR_FREE + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if _astar.is_in_boundsv(n) and not _astar.is_point_solid(n):
					return n
	return Vector2i(-1, -1)
