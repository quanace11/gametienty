extends RefCounted
## Theme chung kiểu game chibi: bảng bo tròn, nút màu có viền đậm và bóng đổ,
## chữ trắng viền đen. Dựng bằng code (StyleBoxFlat), không cần ảnh. Dựng một
## lần rồi dùng chung (static), gán vào Control gốc của từng màn hình.

const INK := Color(0.12, 0.1, 0.16) # viền, bóng
const PANEL := Color(0.16, 0.2, 0.32, 0.92)
const PANEL_LIGHT := Color(0.98, 0.95, 0.88)
const BLUE := Color(0.25, 0.6, 0.98)
const RED := Color(0.94, 0.33, 0.3)
const GREEN := Color(0.33, 0.78, 0.4)
const GOLD := Color(1.0, 0.8, 0.25)
const MUTED := Color(0.55, 0.58, 0.66)

static var _theme: Theme


## Lề an toàn (tai thỏ, lỗ camera, góc bo của điện thoại) theo đơn vị của canvas:
## x = trái, y = trên, z = phải, w = dưới. Máy tính trả 0. Thêm sẵn ít nhất
## `extra` px để nút không sát mép màn hình.
static func safe_insets(viewport: Viewport, extra := 0.0) -> Vector4:
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0.0 or win.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0 or not OS.has_feature("mobile"):
		return Vector4(extra, extra, extra, extra)
	var k := viewport.get_visible_rect().size / win
	return Vector4(maxf(extra, safe.position.x * k.x), maxf(extra, safe.position.y * k.y),
		maxf(extra, (win.x - safe.end.x) * k.x), maxf(extra, (win.y - safe.end.y) * k.y))


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color(&"font_color", &"Label", Color.WHITE)
	t.set_color(&"font_outline_color", &"Label", INK)
	t.set_constant(&"outline_size", &"Label", 6)
	t.set_stylebox(&"panel", &"PanelContainer", panel(PANEL))
	t.set_stylebox(&"panel", &"Panel", panel(PANEL))
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		t.set_stylebox(state, &"Button", button_box(BLUE, state))
	t.set_color(&"font_color", &"Button", Color.WHITE)
	t.set_color(&"font_hover_color", &"Button", Color.WHITE)
	t.set_color(&"font_pressed_color", &"Button", Color.WHITE)
	t.set_color(&"font_focus_color", &"Button", Color.WHITE)
	t.set_color(&"font_disabled_color", &"Button", Color(1, 1, 1, 0.5))
	t.set_color(&"font_outline_color", &"Button", INK)
	t.set_constant(&"outline_size", &"Button", 5)
	t.set_font_size(&"font_size", &"Button", 22)
	var edit := StyleBoxFlat.new()
	edit.bg_color = Color(1, 1, 1, 0.95)
	edit.set_corner_radius_all(12)
	edit.set_border_width_all(3)
	edit.border_color = INK
	edit.set_content_margin_all(10)
	t.set_stylebox(&"normal", &"LineEdit", edit)
	t.set_stylebox(&"focus", &"LineEdit", edit)
	t.set_stylebox(&"read_only", &"LineEdit", edit)
	t.set_color(&"font_color", &"LineEdit", INK)
	t.set_color(&"font_placeholder_color", &"LineEdit", Color(INK, 0.45))
	t.set_color(&"caret_color", &"LineEdit", INK)
	t.set_color(&"font_color", &"CheckBox", Color.WHITE)
	t.set_color(&"font_outline_color", &"CheckBox", INK)
	t.set_constant(&"outline_size", &"CheckBox", 5)
	_theme = t
	return t


## Bảng bo tròn có viền đậm.
static func panel(color: Color, radius := 18, border := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = INK
	s.set_content_margin_all(14)
	return s


## Nút màu: viền đậm, bóng đổ phía dưới (nhấn thì bóng mất, nút như bị lún).
static func button_box(color: Color, state: StringName = &"normal") -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(16)
	s.set_border_width_all(3)
	s.border_color = INK
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	match state:
		&"hover", &"focus":
			s.bg_color = color.lightened(0.12)
			s.shadow_color = INK
			s.shadow_offset = Vector2(0, 5)
		&"pressed":
			s.bg_color = color.darkened(0.12)
			s.content_margin_top = 13
			s.content_margin_bottom = 9
		&"disabled":
			s.bg_color = MUTED
		_:
			s.bg_color = color
			s.shadow_color = INK
			s.shadow_offset = Vector2(0, 5)
	return s


## Đổi màu một nút (giữ viền, bóng, hiệu ứng nhấn).
static func color_button(b: Button, color: Color) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		b.add_theme_stylebox_override(state, button_box(color, state))
