class_name RenderWarmup
extends CanvasLayer
## Làm nóng lúc vào trận, sau màn "Đang vào trận...". Renderer Compatibility
## (OpenGL) dịch shader ngay lần đầu vẽ một loại material, mỗi loại vài trăm ms
## trên điện thoại; chữ cũng vẽ từng ký tự vào ảnh font lần đầu gặp. Không làm
## nóng thì trận khựng mỗi khi thứ mới lọt vào khung hình (rương, cổng, nhân vật
## khác, phi kiếm, vụ nổ, thông báo...).
## Cách làm: gom mọi material trong trận (kể cả node đang ẩn) cộng material các
## module khai báo trước bằng register() (đổi màu sau này, hiệu ứng dựng lúc cần),
## vẽ mỗi cái lên một khối nhỏ ngay trước camera; mỗi kiểu chữ đang dùng (font, cỡ,
## viền) vẽ một dòng đủ chữ tiếng Việt. Tất cả nằm dưới màn che trong WARM_FRAMES
## khung hình rồi bỏ. Khung hình đầu chỉ vẽ màn che (trận ẩn) để màn che hiện ngay.
## Shader đã dịch Godot lưu ở user://shader_cache nên lần mở game sau nhanh hơn.
## Chỉ chạy trên máy có màn hình; server riêng không tạo node này.

## Đã dịch xong shader, máy này sẵn sàng vào trận (Match báo server).
signal warmed

const WARM_FRAMES := 2 # khung hình vẽ mẫu (lần đầu dịch, lần sau dịch nốt biến thể đèn / bóng)
const FADE_TIME := 0.25
const MAX_SAMPLES := 160
const GRID := 12 # khối mỗi hàng
const SPACING := 0.1 # mét giữa hai khối, đủ nhỏ để cả lưới nằm trong khung hình
const DISTANCE := 2.0 # mét trước camera
const CHARSET := "aàáảãạăằắẳẵặâầấẩẫậbcdđeèéẻẽẹêềếểễệghiìíỉĩịklmnoòóỏõọôồốổỗộơờớởỡợpqrstuùúủũụưừứửữựvwxyỳýỷỹỵz" \
	+ "AÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬBCDĐEÈÉẺẼẸÊỀẾỂỄỆGHIÌÍỈĨỊKLMNOÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢPQRSTUÙÚỦŨỤƯỪỨỬỮỰVWXYỲÝỶỸỴZ" \
	+ "0123456789 .,:;!?%/()+-●✦▼"

static var _registered: Array[Material] = [] # giữ suốt game (đều là tài nguyên dùng chung)
static var _overlays: Array[Material] = [] # phủ lên mô hình có xương (chớp đỏ khi trúng...)
static var _text_styles: Array[Array] = [] # [font, cỡ, viền] vẽ bằng draw_string (không có Label để gom)
static var _box: BoxMesh

var _world: Node3D # cả trận, ẩn ở khung hình đầu
var _samples: Node3D
var _texts: Array[Node] = [] # dòng chữ mẫu 2D (dưới màn che)
var _skeletons := {} # mesh đầu tiên -> Skeleton3D: một mô hình có xương mỗi loại
var _styles := {} # "font:cỡ:viền:3d" -> [font, cỡ, viền, 3d]
var _cover: ColorRect
var _start_frame := 0
var _fade := 0.0


## Module khai báo trước material (hoặc mesh: lấy material từng mặt) sẽ dùng sau
## (đổi màu khi mở, hiệu ứng lúc bắn...) để được dịch sẵn. Gọi lúc dựng tài
## nguyên dùng chung, gọi nhiều lần không sao.
static func register(res: Resource) -> void:
	if res is Mesh:
		for s in (res as Mesh).get_surface_count():
			_add_unique(_registered, (res as Mesh).surface_get_material(s))
		var prim := res as PrimitiveMesh
		if prim:
			_add_unique(_registered, prim.material)
	else:
		_add_unique(_registered, res as Material)


## Material phủ (material_overlay) sẽ đặt lên mô hình có xương: phủ lên mô hình
## có xương là shader riêng, nên được vẽ sẵn trên từng mô hình có xương trong trận.
static func register_overlay(mat: Material) -> void:
	_add_unique(_overlays, mat)


## Kiểu chữ module vẽ tay bằng draw_string / draw_string_outline (cỡ, viền) để
## vẽ sẵn các ký tự. Gọi trong _ready của node đó.
static func register_text(font: Font, size: int, outline := 0) -> void:
	for s: Array in _text_styles:
		if s[0] == font and s[1] == size and s[2] == outline:
			return
	_text_styles.append([font, size, outline])


func _init(world: Node3D) -> void:
	_world = world
	layer = 100
	_cover = ColorRect.new()
	_cover.color = Color(0.07, 0.06, 0.1)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cover)
	var label := Label.new()
	label.text = "Đang vào trận..."
	label.add_theme_font_size_override("font_size", 28)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cover.add_child(label)


func _ready() -> void:
	_world.visible = false
	_start_frame = Engine.get_process_frames()


func _process(delta: float) -> void:
	var frame := Engine.get_process_frames() - _start_frame # 0 = khung hình dựng trận: chỉ vẽ màn che
	if frame == 0:
		return
	if frame == 1:
		_world.visible = true
		_build_samples()
	if _samples and frame <= WARM_FRAMES:
		_place_samples()
		return
	if _samples:
		_samples.queue_free()
		_samples = null
		for t in _texts:
			t.queue_free()
		_texts.clear()
		warmed.emit()
	_fade += delta / FADE_TIME
	_cover.modulate.a = 1.0 - _fade
	if _fade >= 1.0:
		queue_free()


func _build_samples() -> void:
	var materials: Array[Material] = []
	_collect(_world, materials)
	for m in _registered:
		_add_unique(materials, m)
	for s: Array in _text_styles:
		_add_style(s[0], s[1], s[2], false)
	if _box == null:
		_box = BoxMesh.new()
		_box.size = Vector3.ONE * 0.07
	_samples = Node3D.new()
	_samples.top_level = true
	_world.add_child(_samples)
	var count := mini(materials.size(), MAX_SAMPLES)
	@warning_ignore("integer_division")
	var rows := (count + GRID - 1) / GRID
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = _box
		mi.material_override = materials[i]
		@warning_ignore("integer_division")
		mi.position = Vector3((i % GRID - GRID / 2.0) * SPACING, (i / GRID - rows / 2.0) * SPACING, -DISTANCE)
		_samples.add_child(mi)
	# Mô hình có xương vẽ bằng shader riêng: chép nguyên khung xương + thân (cả khi
	# phủ material), thu nhỏ đặt cạnh lưới khối.
	var k := 0
	var copies := _skeletons.size() * (_overlays.size() + 1)
	for skel: Skeleton3D in _skeletons.values():
		for overlay: Material in [null] + _overlays:
			var copy := skel.duplicate(0) as Skeleton3D
			var holder := Node3D.new()
			holder.position = Vector3((k - copies / 2.0) * SPACING * 2.0, -0.3, -DISTANCE)
			holder.scale = Vector3.ONE * 0.08
			holder.add_child(copy)
			copy.transform = Transform3D.IDENTITY
			for mi in copy.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = overlay
			_samples.add_child(holder)
			k += 1
	for style: Array in _styles.values():
		if style[3]:
			var l3 := Label3D.new()
			l3.font = style[0]
			l3.font_size = style[1]
			l3.outline_size = style[2]
			l3.pixel_size = 0.0002 # cả dòng chỉ vài cm, vẫn trong khung hình
			l3.text = CHARSET
			l3.position.z = -DISTANCE
			_samples.add_child(l3)
		else:
			var l := Label.new()
			l.add_theme_font_override(&"font", style[0])
			l.add_theme_font_size_override(&"font_size", style[1])
			l.add_theme_constant_override(&"outline_size", style[2])
			l.text = CHARSET
			add_child(l)
			_texts.append(l)
	move_child(_cover, -1) # chữ mẫu vẽ trước, màn che đè lên
	print("[%d] Làm nóng %d material, %d kiểu chữ" % [multiplayer.get_unique_id(), materials.size(), _styles.size()])


## Đặt lưới khối ngay trước camera đang dùng (camera bám nhân vật có thể vừa dời).
func _place_samples() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		_samples.global_transform = cam.global_transform


func _collect(node: Node, out: Array[Material]) -> void:
	var gi := node as GeometryInstance3D
	if gi:
		_add_unique(out, gi.material_override)
		_add_unique(out, gi.material_overlay)
		var mi := node as MeshInstance3D
		if mi and mi.mesh:
			var skel := mi.get_parent() as Skeleton3D
			if skel and not _skeletons.has(mi.mesh):
				_skeletons[mi.mesh] = skel
			for s in mi.mesh.get_surface_count():
				_add_unique(out, mi.get_surface_override_material(s))
				_add_unique(out, mi.mesh.surface_get_material(s))
		var l3 := node as Label3D
		if l3:
			_add_style(l3.font if l3.font else ThemeDB.fallback_font, l3.font_size, l3.outline_size, true)
	var label := node as Label
	if label:
		if label.label_settings:
			var ls := label.label_settings
			_add_style(ls.font if ls.font else label.get_theme_font(&"font"), ls.font_size, ls.outline_size, false)
		else:
			_add_style(label.get_theme_font(&"font"), label.get_theme_font_size(&"font_size"), label.get_theme_constant(&"outline_size"), false)
	for child in node.get_children():
		_collect(child, out)


func _add_style(font: Font, size: int, outline: int, in_3d: bool) -> void:
	if font == null:
		return
	var key := "%d:%d:%d:%s" % [font.get_instance_id(), size, outline, in_3d]
	if not _styles.has(key):
		_styles[key] = [font, size, outline, in_3d]


static func _add_unique(out: Array[Material], m: Material) -> void:
	if m != null and not out.has(m):
		out.append(m)
