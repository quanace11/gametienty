// Mặt đất vẽ tay: 2 ảnh màu nước lát theo tọa độ thế giới, trộn theo nhiễu cho không lộ ô lặp,
// nhân thêm sắc loang (dark -> light) để giữ tông màu chung của bản đồ.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_a : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_b : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec3 dark : source_color = vec3(0.8);
uniform vec3 light : source_color = vec3(1.0);
uniform float tile = 0.12; // số lần lặp ảnh trên 1 m (0.12: một ô ảnh rộng 8 m)
uniform float scale = 0.035; // cỡ vệt loang

varying vec2 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float n = texture(noise, wp * scale).r * 0.65 + texture(noise, wp * scale * 3.7).r * 0.35;
	vec3 a = texture(albedo_a, wp * tile).rgb;
	vec3 b = texture(albedo_b, vec2(wp.y, -wp.x) * tile * 0.77).rgb; // xoay và lệch cỡ để 2 lớp không trùng ô
	vec3 base = mix(a, b, smoothstep(0.38, 0.62, n));
	ALBEDO = base * mix(dark, light, smoothstep(0.41, 0.57, n));
	ROUGHNESS = 1.0;
}
