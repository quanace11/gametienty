// Vòng phù văn phát sáng nằm trên nền: cộng sáng (không cần sắp xếp), quay chậm và nhấp nháy nhẹ, không cần đèn.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D rune : filter_linear_mipmap;
uniform vec3 color : source_color = vec3(0.4, 0.75, 1.0);
uniform float energy = 1.4;
uniform float spin = 0.08; // vòng mỗi giây (rad/s)

void fragment() {
	float a = TIME * spin;
	vec2 p = UV - 0.5;
	p = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * p + 0.5;
	float m = texture(rune, p).a;
	float pulse = 0.8 + 0.2 * sin(TIME * 1.7);
	ALBEDO = color * m * energy * pulse;
}
