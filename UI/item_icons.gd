extends RefCounted
## Biểu tượng thẻ phù bảo vẽ bằng code (không cần ảnh): mỗi loại một hình dễ
## nhận ra (chữ thập hồi phục, tia sét thần hành, kiếm, mũi tên lò xo...) và một
## màu riêng. Vẽ trong `_draw()` của Control bất kỳ: ItemIcons.draw_icon(self, ...).

const INK := Color(0.12, 0.1, 0.16)
const T := GameTypes.ItemType
const COLORS := {
	T.MEDKIT: Color(0.35, 0.85, 0.45),
	T.STUN_GRENADE: Color(1.0, 0.85, 0.3),
	T.TRAP: Color(0.95, 0.45, 0.3),
	T.JUMP_PAD: Color(0.45, 0.85, 1.0),
	T.CRATE: Color(0.8, 0.62, 0.4),
	T.SPEED_BOOST: Color(0.55, 0.95, 0.95),
	T.PISTOL: Color(0.75, 0.85, 1.0),
	T.DISGUISE: Color(0.9, 0.7, 1.0),
	T.TELEPORT: Color(0.95, 0.3, 0.45),
	T.RADAR: Color(0.8, 0.55, 1.0),
}

static var _pts := PackedVector2Array() # dùng lại, không tạo mảng mới mỗi lần vẽ


## Màu nhận diện của loại thẻ.
static func color_of(type: int) -> Color:
	return COLORS.get(type, Color.WHITE)


## Vẽ biểu tượng loại `type` vào ô vuông cạnh `size` quanh `c`. `dim` = thẻ chưa dùng được.
static func draw_icon(ci: CanvasItem, type: int, c: Vector2, size: float, dim := false) -> void:
	var col := color_of(type)
	if dim:
		col = col.lerp(Color(0.55, 0.55, 0.6), 0.65)
	var r := size * 0.5
	var w := maxf(2.0, size * 0.09) # nét vẽ
	match type:
		T.MEDKIT: # chữ thập trên tròn
			ci.draw_circle(c, r, INK)
			ci.draw_circle(c, r - w * 0.6, col)
			ci.draw_rect(Rect2(c - Vector2(r * 0.18, r * 0.6), Vector2(r * 0.36, r * 1.2)), Color.WHITE)
			ci.draw_rect(Rect2(c - Vector2(r * 0.6, r * 0.18), Vector2(r * 1.2, r * 0.36)), Color.WHITE)
		T.STUN_GRENADE: # lá bùa có ngôi sao choáng
			_rect(ci, Rect2(c - Vector2(r * 0.55, r * 0.9), Vector2(r * 1.1, r * 1.8)), col, w)
			_star(ci, c, r * 0.45, INK)
		T.TRAP: # vòng răng cưa
			ci.draw_arc(c, r * 0.75, 0, TAU, 24, INK, w * 2.2)
			ci.draw_arc(c, r * 0.75, 0, TAU, 24, col, w)
			for k in 8:
				var a := TAU * k / 8.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c + d * r * 0.4, c + d * r * 0.95, col, w)
		T.JUMP_PAD: # lò xo + mũi tên lên
			_arrow_up(ci, c + Vector2(0, -r * 0.2), r * 0.7, col, w)
			for k in 3:
				var y := c.y + r * (0.35 + k * 0.2)
				ci.draw_line(Vector2(c.x - r * 0.6, y), Vector2(c.x + r * 0.6, y), col, w)
		T.CRATE: # khối đá
			_rect(ci, Rect2(c - Vector2(r * 0.8, r * 0.8), Vector2(r * 1.6, r * 1.6)), col, w)
			ci.draw_line(c + Vector2(-r * 0.8, 0), c + Vector2(r * 0.8, 0), INK, w)
			ci.draw_line(c + Vector2(0, -r * 0.8), c + Vector2(0, 0), INK, w)
			ci.draw_line(c + Vector2(-r * 0.4, 0), c + Vector2(-r * 0.4, r * 0.8), INK, w)
			ci.draw_line(c + Vector2(r * 0.4, 0), c + Vector2(r * 0.4, r * 0.8), INK, w)
		T.SPEED_BOOST: # tia sét
			_poly(ci, [Vector2(0.15, -1), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.2, 1),
				Vector2(0.55, -0.15), Vector2(0.05, -0.15)], c, r, col)
		T.PISTOL: # kiếm bay chéo
			var tip := c + Vector2(r * 0.85, -r * 0.85)
			var hilt := c + Vector2(-r * 0.45, r * 0.45)
			ci.draw_line(hilt, tip, INK, w * 3.0)
			ci.draw_line(hilt, tip, col, w * 1.6)
			ci.draw_line(hilt + Vector2(-r * 0.3, -r * 0.3), hilt + Vector2(r * 0.3, r * 0.3), INK, w * 1.8)
			ci.draw_line(hilt, hilt + Vector2(-r * 0.4, r * 0.4), INK, w * 1.8)
		T.DISGUISE: # mặt nạ
			ci.draw_circle(c, r * 0.85, INK)
			ci.draw_circle(c, r * 0.85 - w * 0.6, col)
			ci.draw_circle(c + Vector2(-r * 0.32, -r * 0.1), r * 0.16, INK)
			ci.draw_circle(c + Vector2(r * 0.32, -r * 0.1), r * 0.16, INK)
		T.TELEPORT: # xoáy huyết độn
			for k in 3:
				ci.draw_arc(c, r * (0.3 + k * 0.25), k * 1.6, k * 1.6 + PI * 1.3, 16, col, w * 1.2)
			ci.draw_circle(c, r * 0.15, col)
		T.RADAR: # con mắt thần thức
			ci.draw_arc(c + Vector2(0, r * 0.55), r * 0.95, -PI * 0.82, -PI * 0.18, 16, col, w * 1.3)
			ci.draw_arc(c - Vector2(0, r * 0.55), r * 0.95, PI * 0.18, PI * 0.82, 16, col, w * 1.3)
			ci.draw_circle(c, r * 0.3, col)
			ci.draw_circle(c, r * 0.13, INK)
		_:
			ci.draw_circle(c, r * 0.6, col)


static func _rect(ci: CanvasItem, rect: Rect2, col: Color, w: float) -> void:
	ci.draw_rect(rect.grow(w * 0.6), INK)
	ci.draw_rect(rect, col)


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	_pts.resize(10)
	for k in 10:
		var a := -PI / 2 + TAU * k / 10.0
		_pts[k] = c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45)
	ci.draw_colored_polygon(_pts, col)


static func _arrow_up(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_line(c + Vector2(0, r * 0.6), c + Vector2(0, -r * 0.4), col, w * 1.4)
	_pts.resize(3)
	_pts[0] = c + Vector2(0, -r)
	_pts[1] = c + Vector2(-r * 0.55, -r * 0.3)
	_pts[2] = c + Vector2(r * 0.55, -r * 0.3)
	ci.draw_colored_polygon(_pts, col)


## Đa giác theo tọa độ chuẩn -1..1, có viền đen.
static func _poly(ci: CanvasItem, unit: Array, c: Vector2, r: float, col: Color) -> void:
	_pts.resize(unit.size())
	for k in unit.size():
		_pts[k] = c + (unit[k] as Vector2) * r
	ci.draw_polyline(_pts + PackedVector2Array([_pts[0]]), INK, r * 0.2, true)
	ci.draw_colored_polygon(_pts, col)
