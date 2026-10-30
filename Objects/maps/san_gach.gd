extends MapBase
## Bản đồ "Sân Gạch" 40 x 36 m dựng bằng code, đơn giản và mượt theo ảnh mẫu quan gửi: sân lát gạch vuông
## màu be ấm, khối tường xám than vát cạnh, bồn cỏ cao để nấp, cây tán tròn trong bồn đá bát giác.
## Không mô hình bản đồ, không ảnh lớn: sàn gạch vẽ bằng phép tính (shaders/san_gach.gdshader) nên sắc mịn
## ở mọi độ phóng; bóng tiếp xúc chân tường, gốc cây, bụi cỏ là một ảnh 176 x 160 dựng lúc vào trận, lọc tuyến
## tính cho mép mềm. Tường, bồn đá, viền bồn cỏ là một mesh màu theo đỉnh (một lần vẽ), mặt cỏ một mesh.
## 2 lối ra là 2 cửa phong ấn trong tường bao (bắc và đông), huyết trận ở giữa, 6 trận linh quanh sân.

const SIZE := Vector2(40, 36) # x, z
const WALL_HEIGHT := 2.0
const BEVEL := 0.12 # mét vát cạnh trên của khối tường
## Tường: Rect2(x, z, rộng theo x, sâu theo z), đơn vị mét. 4 rect đầu hở chỗ 2 lối ra là tường bao.
const WALLS: Array[Rect2] = [
	Rect2(0, 0, 10.8, 1), Rect2(13.2, 0, 26.8, 1), # bắc, hở lối ra x = 12
	Rect2(39, 1, 1, 21.8), Rect2(39, 25.2, 1, 9.8), # đông, hở lối ra z = 24
	Rect2(0, 35, 40, 1), Rect2(0, 1, 1, 34), # nam, tây
	# Khối chắn trong sân
	Rect2(11.5, 11, 1.2, 5), Rect2(27.3, 20, 1.2, 5), Rect2(14, 24, 5, 1.2), Rect2(22, 10.8, 5, 1.2),
	Rect2(1, 13.5, 4, 1.2), Rect2(35, 14.8, 4, 1.2), Rect2(25, 32, 1.2, 3),
]
## Thanh chắn trong khe cửa: cửa phong ấn đóng thì không ra ngoài sân được.
const GATE_BLOCKERS: Array[Rect2] = [Rect2(10.8, 0.4, 2.4, 0.2), Rect2(39.4, 22.8, 0.2, 2.4)]
const EXIT_GATES: Array[Vector3] = [Vector3(12, 0, 0.5), Vector3(39.5, 0, 24)]
const EXIT_GATE_YAW: Array[float] = [PI / 2, 0.0]
const PRISONS: Array[Vector3] = [Vector3(20, 0, 18)]
const SAFES: Array[Vector3] = [
	Vector3(7, 0, 7), Vector3(20, 0, 5.5), Vector3(33, 0, 7.5), Vector3(7.5, 0, 27.5),
	Vector3(33, 0, 30), Vector3(18, 0, 30.5),
]
## Bồn cỏ (Rect2) và bụi cỏ cao để nấp trong bồn: Vector3(x, z, bán kính).
const GRASS_BEDS: Array[Rect2] = [
	Rect2(13.5, 2, 3.5, 4), Rect2(2, 17, 4, 4), Rect2(33, 18, 4, 3.5), Rect2(10, 26, 3.5, 4),
	Rect2(22.5, 13.2, 4, 3), Rect2(21.5, 26, 3.5, 3),
]
const BUSHES: Array[Vector3] = [
	Vector3(15.25, 4, 1.6), Vector3(4, 19, 1.7), Vector3(35, 19.75, 1.6), Vector3(11.75, 28, 1.6),
	Vector3(24.5, 14.7, 1.5), Vector3(23.25, 27.5, 1.5),
]
## Cây trong bồn đá bát giác: Vector3(x, z, cỡ).
const TREES: Array[Vector3] = [
	Vector3(4, 3.5, 0.65), Vector3(7.6, 18.2, 0.6), Vector3(36.5, 11.5, 0.65), Vector3(31, 22.5, 0.6),
	Vector3(15, 32.5, 0.6), Vector3(36.5, 33, 0.65), Vector3(18.4, 2.8, 0.55),
]
const PLANTER_RADIUS := 0.85
const HUNTER_SPAWN := Vector3(35.5, 0.05, 3.5)
const ESCAPEE_SPAWNS: Array[Vector3] = [
	Vector3(3.2, 0.05, 31.8), Vector3(4.6, 0.05, 31.8), Vector3(3.2, 0.05, 33.2), Vector3(4.6, 0.05, 33.2),
]
## Linh thạch rải sẵn trên sàn.
const COIN_SPOTS: Array[Vector3] = [
	Vector3(3, 9, 0), Vector3(9.5, 2.5, 0), Vector3(25, 3, 0), Vector3(29, 12, 0), Vector3(37, 6, 0),
	Vector3(16, 9, 0), Vector3(9, 14, 0), Vector3(3.5, 24, 0), Vector3(15, 20, 0), Vector3(25.5, 21, 0),
	Vector3(31, 26.5, 0), Vector3(36.5, 27, 0), Vector3(21, 33, 0), Vector3(8.5, 33, 0), Vector3(29.5, 33.5, 0),
	Vector3(15.5, 15.5, 0),
]

const TILE_COLOR := Color(0.75, 0.63, 0.5)
const GROUT_COLOR := Color(0.63, 0.52, 0.41)
const OUTSIDE_COLOR := Color(0.16, 0.17, 0.2) # ngoài tường bao
const WALL_TOP := Color(0.36, 0.37, 0.41) # mặt trên khối tường
const WALL_SIDE := Color(0.27, 0.28, 0.32)
const WALL_FOOT := Color(0.18, 0.19, 0.22) # chân tường tối dần như có bóng
const STONE_LIGHT := Color(0.78, 0.75, 0.7) # bồn đá, viền bồn cỏ
const STONE_FOOT := Color(0.6, 0.57, 0.53)
const SOIL := Color(0.32, 0.22, 0.15)
const LEAF_TINT := Color(1.0, 1.08, 0.9) # tán cây sáng ấm theo ảnh mẫu
const CONTACT_PX := 4 # điểm ảnh bóng tiếp xúc trên 1 m
const CONTACT_RECT := Rect2(-2, -2, 44, 40)

const SafeScript = preload("res://Objects/safe.gd")
const ExitGateScript = preload("res://Objects/exit_gate.gd")
const PrisonScript = preload("res://Objects/prison.gd")
const CoinScript = preload("res://Objects/coin.gd")
const BushScript = preload("res://Objects/bush.gd")
const NATURE := "res://Objects/models/quaternius_nature/"

var _quality := clampi(int(ProjectSettings.get_setting("game/graphics_quality", 0)), 0, 2)
var _rng := RandomNumberGenerator.new() # cây xoay ngẫu nhiên nhưng cố định mỗi lần dựng
var _headless := DisplayServer.get_name() == "headless" # server riêng: chỉ dựng va chạm, không dựng hình


func _ready() -> void:
	_rng.seed = 20261030
	_add_collider(Rect2(-8, -8, SIZE.x + 16, SIZE.y + 16), 0.2, -0.2) # sàn
	for r: Rect2 in WALLS:
		_add_collider(r, WALL_HEIGHT)
	for r: Rect2 in GATE_BLOCKERS:
		_add_collider(r, WALL_HEIGHT)
	for t: Vector3 in TREES:
		_add_collider(Rect2(t.x - 0.6, t.y - 0.6, 1.2, 1.2), 1.0) # bồn đá quanh gốc
	for i in BUSHES.size():
		var bush: Node3D = BushScript.new()
		bush.index = i
		bush.radius = BUSHES[i].z
		bush.position = Vector3(BUSHES[i].x, 0.05, BUSHES[i].y)
		add_child(bush)
	for i in SAFES.size():
		var safe: Interactable = SafeScript.new()
		safe.interactable_id = i
		safe.position = SAFES[i]
		add_child(safe)
	for i in EXIT_GATES.size():
		var gate: Interactable = ExitGateScript.new()
		gate.interactable_id = i
		gate.position = EXIT_GATES[i]
		gate.rotation.y = EXIT_GATE_YAW[i]
		add_child(gate)
	for i in COIN_SPOTS.size():
		var coin: Interactable = CoinScript.new()
		coin.interactable_id = i
		coin.position = COIN_SPOTS[i]
		add_child(coin)
	for i in PRISONS.size():
		var prison: Prison = PrisonScript.new()
		prison.interactable_id = i
		prison.position = PRISONS[i]
		prison.exit_side = Vector3(0, 0, 1) # đệm trong tù bắn người ra phía nam
		add_child(prison)
	if not _headless:
		_add_floor()
		_add_blocks()
		_add_grass_beds()
		_add_trees()
		_add_lighting()


## Sàn gạch phủ sân, nền tối ngoài tường bao.
func _add_floor() -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://Objects/shaders/san_gach.gdshader")
	m.set_shader_parameter(&"tile_color", TILE_COLOR)
	m.set_shader_parameter(&"grout_color", GROUT_COLOR)
	m.set_shader_parameter(&"detail", float(_quality))
	m.set_shader_parameter(&"contact", ImageTexture.create_from_image(_contact_image()))
	m.set_shader_parameter(&"contact_rect", Vector4(CONTACT_RECT.position.x, CONTACT_RECT.position.y,
		1.0 / CONTACT_RECT.size.x, 1.0 / CONTACT_RECT.size.y))
	var plane := PlaneMesh.new()
	plane.size = SIZE
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = plane
	floor_mi.material_override = m
	floor_mi.position = Vector3(SIZE.x / 2, 0, SIZE.y / 2)
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mi)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = OUTSIDE_COLOR
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var outside := PlaneMesh.new()
	outside.size = Vector2(160, 160)
	var out_mi := MeshInstance3D.new()
	out_mi.mesh = outside
	out_mi.material_override = dark
	out_mi.position = Vector3(SIZE.x / 2, -0.02, SIZE.y / 2)
	out_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(out_mi)


## Ảnh bóng tiếp xúc (1 sáng, tối dần về chân vật). Chỉ tô quanh từng vật nên dựng nhanh.
func _contact_image() -> Image:
	var w := int(CONTACT_RECT.size.x) * CONTACT_PX
	var h := int(CONTACT_RECT.size.y) * CONTACT_PX
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	img.fill(Color.WHITE)
	for r: Rect2 in WALLS:
		_shade_rect(img, r, 1.1, 0.25)
	for r: Rect2 in GRASS_BEDS:
		_shade_rect(img, r, 0.35, 0.75)
	for t: Vector3 in TREES:
		_shade_disc(img, Vector2(t.x, t.y), PLANTER_RADIUS * 0.7, PLANTER_RADIUS + 1.3, 0.45)
	for s: Vector3 in SAFES:
		_shade_disc(img, Vector2(s.x, s.z), 0.9, 2.0, 0.6)
	for p: Vector3 in PRISONS:
		_shade_rect(img, Rect2(p.x - 2.4, p.z - 2.4, 4.8, 4.8), 0.7, 0.6)
	return img


## Tối dần trong `reach` mét quanh hình chữ nhật, sát mép còn `darkest`.
func _shade_rect(img: Image, r: Rect2, reach: float, darkest: float) -> void:
	var box := _pixel_box(r.grow(reach), img)
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var p := _pixel_to_world(x, y)
			var d := Vector2(maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0), maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)).length()
			_darken(img, x, y, lerpf(darkest, 1.0, smoothstep(0.0, reach, d)))


## Bóng tròn mềm: tối nhất trong bán kính `inner`, hết tối ở `outer`.
func _shade_disc(img: Image, c: Vector2, inner: float, outer: float, darkest: float) -> void:
	var box := _pixel_box(Rect2(c - Vector2(outer, outer), Vector2(outer, outer) * 2), img)
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			_darken(img, x, y, lerpf(darkest, 1.0, smoothstep(inner, outer, _pixel_to_world(x, y).distance_to(c))))


func _pixel_box(r: Rect2, img: Image) -> Rect2i:
	var a := Vector2i(((r.position - CONTACT_RECT.position) * CONTACT_PX).floor())
	var b := Vector2i(((r.end - CONTACT_RECT.position) * CONTACT_PX).ceil())
	a = a.clamp(Vector2i.ZERO, img.get_size())
	b = b.clamp(Vector2i.ZERO, img.get_size())
	return Rect2i(a, b - a)


func _pixel_to_world(x: int, y: int) -> Vector2:
	return CONTACT_RECT.position + (Vector2(x, y) + Vector2(0.5, 0.5)) / CONTACT_PX


func _darken(img: Image, x: int, y: int, v: float) -> void:
	if v < img.get_pixel(x, y).r:
		img.set_pixel(x, y, Color(v, v, v))


## Tường, bồn đá quanh gốc cây, viền bồn cỏ: một mesh màu theo đỉnh.
func _add_blocks() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r: Rect2 in WALLS:
		_block(st, r, WALL_HEIGHT, BEVEL, WALL_TOP, WALL_SIDE, WALL_FOOT)
	for r: Rect2 in GRASS_BEDS: # viền đá thấp quanh bồn cỏ
		_block(st, Rect2(r.position.x - 0.15, r.position.y - 0.15, r.size.x + 0.3, 0.15), 0.14, 0.03, STONE_LIGHT, STONE_LIGHT, STONE_FOOT)
		_block(st, Rect2(r.position.x - 0.15, r.end.y, r.size.x + 0.3, 0.15), 0.14, 0.03, STONE_LIGHT, STONE_LIGHT, STONE_FOOT)
		_block(st, Rect2(r.position.x - 0.15, r.position.y, 0.15, r.size.y), 0.14, 0.03, STONE_LIGHT, STONE_LIGHT, STONE_FOOT)
		_block(st, Rect2(r.end.x, r.position.y, 0.15, r.size.y), 0.14, 0.03, STONE_LIGHT, STONE_LIGHT, STONE_FOOT)
	for t: Vector3 in TREES:
		_planter(st, Vector3(t.x, 0, t.y))
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true # màu khai báo ở trên là màu sRGB như ảnh
	m.roughness = 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)


## Khối hộp vát cạnh trên: mặt trên màu `top`, thành bên tối dần từ `side` xuống `foot` ở chân.
func _block(st: SurfaceTool, r: Rect2, height: float, bevel: float, top: Color, side: Color, foot: Color) -> void:
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var hb := height - bevel
	_quad(st, [Vector3(x0 + bevel, height, z0 + bevel), Vector3(x1 - bevel, height, z0 + bevel),
		Vector3(x1 - bevel, height, z1 - bevel), Vector3(x0 + bevel, height, z1 - bevel)], Vector3.UP, [top, top, top, top])
	var outs: Array[Vector3] = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
	var lo: Array[Vector3] = [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]
	var inset: Array[Vector3] = [Vector3(bevel, 0, bevel), Vector3(-bevel, 0, bevel), Vector3(-bevel, 0, -bevel), Vector3(bevel, 0, -bevel)]
	var rim := top.lerp(Color.WHITE, 0.12) # cạnh vát bắt nắng sáng hơn
	for k in 4:
		var a := lo[k]
		var b := lo[(k + 1) % 4]
		var n := outs[k]
		_quad(st, [a, b, b + Vector3(0, hb, 0), a + Vector3(0, hb, 0)], n, [foot, foot, side, side])
		var ta := a + inset[k] + Vector3(0, height, 0)
		var tb := b + inset[(k + 1) % 4] + Vector3(0, height, 0)
		_quad(st, [a + Vector3(0, hb, 0), b + Vector3(0, hb, 0), tb, ta], (n + Vector3.UP).normalized(), [rim, rim, rim, rim])


## Bồn đá bát giác quanh gốc cây, lòng bồn đất.
func _planter(st: SurfaceTool, c: Vector3) -> void:
	const SIDES := 8
	const HEIGHT := 0.28
	var ro := PLANTER_RADIUS
	var ri := PLANTER_RADIUS - 0.16
	var soil_y := 0.2
	for k in SIDES:
		var a0 := TAU * (k + 0.5) / SIDES
		var a1 := TAU * (k + 1.5) / SIDES
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n := (d0 + d1).normalized()
		var up := Vector3(0, HEIGHT, 0)
		_quad(st, [c + d0 * ro, c + d1 * ro, c + d1 * ro + up, c + d0 * ro + up], n, [STONE_FOOT, STONE_FOOT, STONE_LIGHT, STONE_LIGHT])
		_quad(st, [c + d0 * ro + up, c + d1 * ro + up, c + d1 * ri + up, c + d0 * ri + up], Vector3.UP,
			[STONE_LIGHT, STONE_LIGHT, STONE_LIGHT, STONE_LIGHT])
		_quad(st, [c + d0 * ri + up, c + d1 * ri + up, c + d1 * ri + Vector3(0, soil_y, 0), c + d0 * ri + Vector3(0, soil_y, 0)], -n,
			[STONE_FOOT, STONE_FOOT, STONE_FOOT, STONE_FOOT])
		_tri(st, [c + Vector3(0, soil_y, 0), c + d0 * ri + Vector3(0, soil_y, 0), c + d1 * ri + Vector3(0, soil_y, 0)], Vector3.UP, SOIL)


## Tứ giác phẳng 4 đỉnh theo vòng, tự đảo thứ tự cho mặt trước quay về `n`.
func _quad(st: SurfaceTool, p: Array[Vector3], n: Vector3, c: Array[Color]) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(n) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i: int in order:
		st.set_normal(n)
		st.set_color(c[i])
		st.add_vertex(p[i])


func _tri(st: SurfaceTool, p: Array[Vector3], n: Vector3, color: Color) -> void:
	var order := [0, 1, 2]
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(n) > 0.0:
		order = [0, 2, 1]
	for i: int in order:
		st.set_normal(n)
		st.set_color(color)
		st.add_vertex(p[i])


## Mặt cỏ trong các bồn cỏ (bụi cỏ cao do bush.gd vẽ): một mesh.
func _add_grass_beds() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white: Array[Color] = [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
	for r: Rect2 in GRASS_BEDS:
		_quad(st, [Vector3(r.position.x, 0.04, r.position.y), Vector3(r.end.x, 0.04, r.position.y),
			Vector3(r.end.x, 0.04, r.end.y), Vector3(r.position.x, 0.04, r.end.y)], Vector3.UP, white)
	var m := ShaderMaterial.new()
	m.shader = load("res://Objects/shaders/bon_co.gdshader")
	m.set_shader_parameter(&"detail", 0.0 if _quality == 0 else 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Cây tán tròn Quaternius (CC0): thân và lá mỗi loại gộp một mesh.
func _add_trees() -> void:
	var trunk := StandardMaterial3D.new()
	trunk.albedo_texture = BushScript.mip_texture(NATURE + "vo_cay.png")
	trunk.roughness = 1.0
	var leaf := ShaderMaterial.new()
	leaf.shader = load("res://Objects/shaders/la.gdshader")
	leaf.set_shader_parameter(&"tex", BushScript.mip_texture(NATURE + "la_cay.png"))
	leaf.set_shader_parameter(&"tint", LEAF_TINT)
	leaf.set_shader_parameter(&"shadow_tint", Color(0.62, 0.62, 0.7))
	var trunks := SurfaceTool.new()
	trunks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t: Vector3 in TREES:
		var model := "CommonTree_3" if _rng.randf() < 0.5 else "CommonTree_5"
		var s := t.z * (0.8 if model == "CommonTree_3" else 1.15) # khuôn cao 6,6 m / 4,4 m
		var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * s), Vector3(t.x, 0.2, t.y))
		trunks.append_from(load(NATURE + model + "_vo.obj"), 0, xf)
		leaves.append_from(load(NATURE + model + "_la.obj"), 0, xf)
	for pair: Array in [[trunks, trunk], [leaves, leaf]]:
		var mi := MeshInstance3D.new()
		mi.mesh = (pair[0] as SurfaceTool).commit()
		mi.material_override = pair[1]
		add_child(mi)


## Va chạm hình hộp, không hình.
func _add_collider(r: Rect2, height: float, bottom := 0.0) -> void:
	var body := StaticBody3D.new()
	var c := r.get_center()
	body.position = Vector3(c.x, bottom + height / 2, c.y)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(r.size.x, height, r.size.y)
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 35, 0)
	sun.shadow_enabled = _quality > 0 # đồ họa Thấp: chỉ bóng tiếp xúc vẽ sẵn
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL # camera nhìn từ trên: 1 lượt vẽ bóng
	sun.directional_shadow_max_distance = 32.0
	sun.shadow_opacity = 0.55 # bóng nhạt như ảnh mẫu
	sun.light_energy = 0.5
	sun.light_color = Color(1.0, 0.96, 0.9)
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = OUTSIDE_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.92, 0.88)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func get_hunter_spawn() -> Vector3:
	return HUNTER_SPAWN


func get_escapee_spawns() -> Array[Vector3]:
	return ESCAPEE_SPAWNS


func get_safe_count() -> int:
	return SAFES.size()


func get_coin_spots() -> Array[Vector3]:
	return COIN_SPOTS


func get_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, SIZE)


func get_bushes() -> Array[Vector3]:
	return BUSHES.duplicate() # bản sao: hằng là mảng chỉ đọc, GameState xóa / gán lại mỗi trận


func get_walls() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.assign(WALLS + GATE_BLOCKERS)
	return out
