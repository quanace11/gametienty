// Mặt đất theo bố cục bản Meshy: ảnh lớp (R đất, G đá vỡ) phủ cả sân 50 x 45 m quyết định chỗ nào là
// cỏ, lối đất, nền đá; mỗi lớp tô bằng ảnh vẽ tay lát theo tọa độ thế giới nên nhìn gần vẫn nét.
// Mép lối đất có viền tối kiểu vẽ tay; mép lớp lượn theo nhiễu cho khỏi lộ ô ảnh lớp.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D layout_map : filter_linear, repeat_disable; // R: đất, G: đá vỡ
uniform sampler2D grass_a : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_b : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D slab : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec2 area = vec2(50.0, 45.0); // ảnh lớp phủ từ (0, 0) tới area (m)
uniform vec3 grass_dark : source_color = vec3(0.8);
uniform vec3 grass_light : source_color = vec3(1.0);
uniform vec3 dirt_tint : source_color = vec3(1.0);
uniform vec3 slab_tint : source_color = vec3(1.0);
uniform vec3 rim_tint : source_color = vec3(0.7, 0.62, 0.55); // viền tối dọc mép lối đất
uniform float grass_tile = 0.12;
uniform float dirt_tile = 0.18;
uniform float slab_tile = 0.3;
uniform float saturation = 0.6;

varying vec2 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float n = texture(noise, wp * 0.035).r * 0.65 + texture(noise, wp * 0.13).r * 0.35;
	float fine = texture(noise, wp * 0.3).r - 0.5;
	vec2 lay = texture(layout_map, wp / area).rg + fine * 0.1;
	vec3 g = mix(texture(grass_a, wp * grass_tile).rgb, texture(grass_b, vec2(wp.y, -wp.x) * grass_tile * 0.77).rgb,
		smoothstep(0.38, 0.62, n));
	g *= mix(grass_dark, grass_light, smoothstep(0.41, 0.57, n));
	vec3 d = texture(dirt, wp * dirt_tile).rgb * dirt_tint * mix(0.9, 1.08, n);
	vec3 s = texture(slab, wp * slab_tile).rgb * slab_tint;
	float wd = smoothstep(0.42, 0.5, lay.r);
	float ws = smoothstep(0.42, 0.5, lay.g);
	vec3 c = mix(g, d, wd);
	float rim = wd * (1.0 - smoothstep(0.5, 0.62, lay.r)); // dải hẹp phía trong mép đất: viền tối kiểu vẽ tay
	c *= mix(vec3(1.0), rim_tint, rim);
	c = mix(c, s, ws);
	c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, saturation);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
