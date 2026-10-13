extends MapBase
## Bản đồ thử 32 x 20 m, dựng bằng khối hộp. Sau này thay bằng scene dựng
## trong editor (GridMap / model), giữ nguyên các hàm của MapBase.

const SIZE := Vector2(32, 20) # x, z
const WALL_HEIGHT := 2.5
## Tường trên mặt sàn: Rect2(x, z, rộng theo x, sâu theo z), đơn vị mét.
const WALLS := [
	# Viền
	Rect2(0, 0, 32, 0.4), Rect2(0, 19.6, 32, 0.4),
	Rect2(0, 0, 0.4, 20), Rect2(31.6, 0, 0.4, 20),
	# Chướng ngại
	Rect2(6, 3, 0.8, 6), Rect2(6, 12, 0.8, 5),
	Rect2(12, 6, 8, 0.8), Rect2(12, 13.2, 8, 0.8),
	Rect2(24, 2, 0.8, 7), Rect2(24, 11, 0.8, 7),
]
const SAFES := [Vector3(9, 0, 2.6), Vector3(16, 0, 10), Vector3(22, 0, 17.4)]
const EXIT_GATE := Vector3(31.2, 0, 10)
const HUNTER_SPAWN := Vector3(28, 0.05, 10)
const ESCAPEE_SPAWNS: Array[Vector3] = [
	Vector3(2.4, 0.05, 4), Vector3(2.4, 0.05, 8), Vector3(2.4, 0.05, 12), Vector3(2.4, 0.05, 16),
]

const SafeScript = preload("res://Objects/safe.gd")
const ExitGateScript = preload("res://Objects/exit_gate.gd")


func _ready() -> void:
	_add_box(Vector3(SIZE.x / 2, -0.1, SIZE.y / 2), Vector3(SIZE.x, 0.2, SIZE.y), Color(0.22, 0.25, 0.22))
	for r: Rect2 in WALLS:
		var center := r.get_center()
		_add_box(Vector3(center.x, WALL_HEIGHT / 2, center.y), Vector3(r.size.x, WALL_HEIGHT, r.size.y), Color(0.5, 0.47, 0.42))
	for i in SAFES.size():
		var safe: Interactable = SafeScript.new()
		safe.interactable_id = i
		safe.position = SAFES[i]
		add_child(safe)
	var gate: Interactable = ExitGateScript.new()
	gate.position = EXIT_GATE
	add_child(gate)
	_add_lighting()


func _add_box(center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)


func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.11, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func get_hunter_spawn() -> Vector3:
	return HUNTER_SPAWN


func get_escapee_spawns() -> Array[Vector3]:
	return ESCAPEE_SPAWNS


func get_safe_count() -> int:
	return SAFES.size()
