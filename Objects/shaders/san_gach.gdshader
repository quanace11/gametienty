// Sàn gạch vuông màu be ấm vẽ hoàn toàn bằng phép tính (không ảnh màu): mạch vữa khử răng cưa bằng fwidth
// nên sắc mịn ở mọi độ phóng, mỗi viên lệch sáng tối một chút, mép viên hơi tối như gạch vát, vài viên có
// vết nứt mảnh. Bóng tiếp xúc (chân tường, gốc cây, bụi cỏ) đọc từ một ảnh nhỏ dựng lúc vào trận, lọc
// tuyến tính nên mép bóng mềm. Chỉ 1 ảnh và vài số: không vượt giới hạn uniform của máy yếu / máy ảo.
shader_type spatial;
render_mode specular_disabled;

uniform vec3 tile_color : source_color = vec3(0.86, 0.75, 0.61);
uniform vec3 grout_color : source_color = vec3(0.66, 0.55, 0.43);
uniform float tile_size = 1.25; // mét
uniform float grout = 0.025; // nửa bề rộng mạch vữa (mét)
uniform float variation = 0.07; // độ lệch sáng tối giữa các viên
uniform float detail = 1.0; // mức đồ họa: 0 một màu mỗi viên, 1 thêm vân loang và vết nứt, 2 thêm hạt mịn
uniform sampler2D contact : filter_linear, repeat_disable; // R: 1 sáng, 0 bóng tiếp xúc
uniform vec4 contact_rect = vec4(0.0, 0.0, 0.025, 0.0277); // gốc x, z và 1 / cỡ (mét) của ảnh bóng

varying vec2 wp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = wp / tile_size;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash(cell);
	vec2 d2 = min(f, 1.0 - f) * tile_size; // mét tới mép viên
	float e = min(d2.x, d2.y);
	float aa = max(fwidth(e), 0.001);
	float g = 1.0 - smoothstep(grout - aa, grout + aa, e);

	vec3 col = tile_color * (1.0 + (h - 0.5) * variation);
	col *= mix(0.94, 1.0, smoothstep(grout, grout + 0.12, e)); // mép viên vát tối dần
	if (detail > 0.0) {
		col *= 1.0 + (noise(wp * 1.3 + h * 7.0) - 0.5) * 0.08;
		if (detail > 1.5) {
			col *= 1.0 + (noise(wp * 7.0) - 0.5) * 0.035;
		}
		if (h > 0.93) { // vết nứt mảnh lượn qua viên
			float y = f.y - 0.5 - (noise(vec2(f.x * 3.0, h * 50.0)) - 0.5) * 0.7;
			float w = max(fwidth(y), 0.0005);
			float crack = 1.0 - smoothstep(0.0, w * 1.5, abs(y));
			crack *= smoothstep(0.05, 0.2, f.x) * smoothstep(0.95, 0.75, f.x);
			col = mix(col, grout_color * 0.95, crack * 0.45);
		}
	}
	col = mix(col, grout_color, g);
	float c = texture(contact, (wp - contact_rect.xy) * contact_rect.zw).r;
	ALBEDO = col * mix(0.62, 1.0, c);
	ROUGHNESS = 0.95;
}
