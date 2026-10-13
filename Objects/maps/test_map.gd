extends MapBase
## Bản đồ thử 1600x1000. Sau này thay bằng scene vẽ trong editor (TileMap).

const SIZE := Vector2(1600, 1000)
const WALLS := [
	# Viền
	Rect2(0, 0, 1600, 20), Rect2(0, 980, 1600, 20),
	Rect2(0, 0, 20, 1000), Rect2(1580, 0, 20, 1000),
	# Chướng ngại
	Rect2(300, 150, 40, 300), Rect2(300, 600, 40, 250),
	Rect2(600, 300, 400, 40), Rect2(600, 660, 400, 40),
	Rect2(1200, 100, 40, 350), Rect2(1200, 550, 40, 350),
]
const SAFES := [Vector2(450, 120), Vector2(800, 500), Vector2(1100, 880)]
const EXIT_GATE := Vector2(1560, 500)
const HUNTER_SPAWN := Vector2(1400, 500)
const ESCAPEE_SPAWNS: Array[Vector2] = [Vector2(120, 200), Vector2(120, 400), Vector2(120, 600), Vector2(120, 800)]

const SafeScript = preload("res://Objects/safe.gd")
const ExitGateScript = preload("res://Objects/exit_gate.gd")


func _ready() -> void:
	for r: Rect2 in WALLS:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		body.position = r.get_center()
		body.add_child(shape)
		add_child(body)
	for i in SAFES.size():
		var safe: Interactable = SafeScript.new()
		safe.interactable_id = i
		safe.position = SAFES[i]
		add_child(safe)
	var gate: Interactable = ExitGateScript.new()
	gate.position = EXIT_GATE
	add_child(gate)


func get_hunter_spawn() -> Vector2:
	return HUNTER_SPAWN


func get_escapee_spawns() -> Array[Vector2]:
	return ESCAPEE_SPAWNS


func get_safe_count() -> int:
	return SAFES.size()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.13, 0.15, 0.13))
	for r: Rect2 in WALLS:
		draw_rect(r, Color(0.35, 0.33, 0.3))
