// Mô hình bản Meshy làm cho nét: ảnh màu gốc chỉ ~20 px/m nên nhìn trong trận bị nhòe.
// - Mặt đất: ảnh lớp tách từ chính bản Meshy (R lối đất, G mảng đá vỡ) chọn cỏ / đất / đá, mỗi lớp tô
//   bằng ảnh vẽ tay lát theo mét (sắc nét), pha một phần màu gốc Meshy để giữ sắc loang của bản gốc.
// - Vách đá, lan can, cổng: màu gốc Meshy nhân chi tiết đá vẽ tay chiếu 3 phía, normal map gốc,
//   viền sáng ấm theo góc nhìn.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D meshy_albedo : source_color, filter_linear_mipmap;
uniform sampler2D meshy_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D layout_map : filter_linear, repeat_disable; // R: đất, G: đá vỡ
uniform sampler2D grass_a : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_b : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D slab : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec2 area = vec2(50.0, 45.0); // ảnh lớp phủ từ (0, 0) tới area (m)
uniform vec3 grass_dark : source_color = vec3(0.8);
uniform vec3 grass_light : source_color = vec3(1.0);
uniform vec3 dirt_tint : source_color = vec3(1.0);
uniform vec3 slab_tint : source_color = vec3(1.0);
uniform vec3 rim_tint : source_color = vec3(0.7, 0.62, 0.55); // viền tối dọc mép lối đất
uniform float saturation = 0.6;
uniform float meshy_mix = 0.3; // phần màu gốc Meshy pha vào mặt đất
uniform float rock_detail = 0.55; // độ đậm chi tiết đá vẽ tay trên vách, lan can
uniform float rim_light = 0.06;
uniform float wall_shade = 0.72; // vách, lan can tối bớt cho khỏi chói dưới nắng, nền nổi hơn
uniform vec3 rim_color : source_color = vec3(1.0, 0.92, 0.75);

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float luma(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

void fragment() {
	vec3 meshy = texture(meshy_albedo, UV).rgb;
	float ground = smoothstep(0.7, 0.9, abs(wn.y)) * (1.0 - smoothstep(0.15, 0.4, wp.y));
	vec3 c;
	if (ground > 0.0) {
		vec2 p = wp.xz;
		float n = texture(noise, p * 0.035).r * 0.65 + texture(noise, p * 0.13).r * 0.35;
		vec2 lay = texture(layout_map, p / area).rg + (texture(noise, p * 0.3).r - 0.5) * 0.1;
		vec3 g = mix(texture(grass_a, p * 0.12).rgb, texture(grass_b, vec2(p.y, -p.x) * 0.0924).rgb,
			smoothstep(0.38, 0.62, n));
		g *= mix(grass_dark, grass_light, smoothstep(0.41, 0.57, n));
		vec3 d = texture(dirt, p * 0.18).rgb * dirt_tint * mix(0.9, 1.08, n);
		vec3 s = texture(slab, p * 0.3).rgb * slab_tint;
		float wd = smoothstep(0.42, 0.5, lay.r);
		c = mix(g, d, wd);
		c *= mix(vec3(1.0), rim_tint, wd * (1.0 - smoothstep(0.5, 0.62, lay.r)));
		c = mix(c, s, smoothstep(0.42, 0.5, lay.g));
		c = mix(vec3(luma(c)), c, saturation);
		c = mix(c, meshy * (luma(c) / max(luma(meshy), 0.05)), meshy_mix); // sắc Meshy, độ sáng vẽ tay
	} else {
		c = meshy;
	}
	if (ground < 1.0) {
		vec3 w = pow(abs(wn), vec3(4.0));
		w /= w.x + w.y + w.z;
		vec3 r = texture(rock, wp.zy * 0.4).rgb * w.x + texture(rock, wp.xz * 0.4).rgb * w.y
			+ texture(rock, wp.xy * 0.4).rgb * w.z;
		float mean = luma(textureLod(rock, vec2(0.5), 12.0).rgb); // mip nhỏ nhất: độ sáng trung bình ảnh đá
		vec3 detailed = meshy * mix(1.0, luma(r) / max(mean, 0.02), rock_detail) * wall_shade;
		float f = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
		c = mix(detailed + rim_color * f * rim_light, c, ground);
		NORMAL_MAP = mix(texture(meshy_normal, UV).rgb, vec3(0.5, 0.5, 1.0), ground);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
