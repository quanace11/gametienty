// Mặt sân động phủ vẽ bằng phép tính, giữ tông màu bản Meshy mà sắc mịn ở mọi độ phóng: cỏ xanh rêu loang,
// lối đất, mảng đá vỡ, lối gạch cuội. Hình lối đất / đá vỡ lấy từ ảnh lớp 512 px (lop_nen.png: R đất, G đá
// vỡ), mép cắt bằng fwidth nên luôn sắc, lượn theo nhiễu như nét cọ. Ảnh thứ hai dựng lúc vào trận: R bóng
// tiếp xúc (chân vách, đá, gốc cây, bụi), G lối gạch cuội. Chỉ 2 ảnh và vài số: không vượt giới hạn uniform.
// Chiếu sáng như các vật khác của bản đồ: nắng hiện đúng màu, bóng tối ngả lạnh.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform vec2 field_size = vec2(50.0, 45.0); // mét (x, z) mà 2 ảnh phủ
uniform sampler2D layout_map : filter_linear, repeat_disable; // R lối đất, G mảng đá vỡ
uniform sampler2D baked : filter_linear, repeat_disable; // R bóng tiếp xúc (1 sáng), G lối gạch cuội
uniform vec3 grass_dark : source_color = vec3(0.32, 0.46, 0.19);
uniform vec3 grass_light : source_color = vec3(0.54, 0.65, 0.29);
uniform vec3 dirt_color : source_color = vec3(0.7, 0.57, 0.39);
uniform vec3 stone_color : source_color = vec3(0.62, 0.64, 0.62);
uniform vec3 cobble_color : source_color = vec3(0.56, 0.56, 0.58);
uniform float detail = 1.0; // mức đồ họa: 0 ít vân, 1 vân loang, 2 thêm hạt mịn
uniform vec3 shadow_tint : source_color = vec3(0.55, 0.6, 0.78);

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

// Mép sắc rộng đúng một điểm ảnh màn hình.
float edge(float d) {
	float px = max(fwidth(d), 0.002);
	return smoothstep(0.5 - px, 0.5 + px, d);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 f = wp / field_size;
	vec2 lay = texture(layout_map, f).rg;
	vec2 bk = texture(baked, f).rg;
	float big = noise(wp * 0.35);
	float wob = noise(wp * 2.2) - 0.5;

	// Cỏ: 2 tông loang theo nhiễu lớn, lấm tấm ngọn cỏ sáng.
	vec3 c = mix(grass_dark, grass_light, smoothstep(0.2, 0.8, big));
	if (detail > 0.0) {
		c *= 1.0 + (noise(wp * 1.7) - 0.5) * 0.14;
		if (detail > 1.5) {
			c *= 1.0 + (noise(wp * 11.0) - 0.5) * 0.1;
		}
	}

	// Lối đất: mép lượn theo nhiễu, viền tối phía đất, viền sáng phía cỏ như nét cọ.
	float dm = lay.r + wob * 0.18;
	float dirt = edge(dm);
	vec3 dc = dirt_color * (1.0 + (noise(wp * 1.3 + 9.0) - 0.5) * 0.16);
	if (detail > 0.0) {
		dc = mix(dc, dirt_color * 0.78, smoothstep(0.78, 0.84, noise(wp * 5.0)) * 0.6); // sỏi nhỏ
	}
	dc *= 1.0 - 0.22 * (1.0 - smoothstep(0.5, 0.62, dm));
	c *= 1.0 + 0.12 * smoothstep(0.32, 0.5, dm) * (1.0 - dirt);
	c = mix(c, dc, dirt);

	// Mảng đá vỡ: phiến xám phẳng, viền tối.
	float sm = lay.g + wob * 0.1;
	float stone = edge(sm);
	vec3 sc = stone_color * (1.0 + (noise(wp * 0.9 + 3.0) - 0.5) * 0.14);
	sc *= 1.0 - 0.3 * (1.0 - smoothstep(0.5, 0.6, sm));
	c = mix(c * (1.0 - 0.2 * smoothstep(0.35, 0.5, sm)), sc, stone);

	// Lối gạch cuội: viên tròn cạnh xếp so le, mạch tối.
	float pm = bk.g;
	float path = edge(pm);
	if (pm > 0.3) {
		vec2 q = wp * 2.6;
		q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
		vec2 cell = floor(q);
		vec2 g = abs(fract(q) - 0.5);
		float r = max(g.x, g.y) + 0.12 * min(g.x, g.y); // viên vuông bo góc
		float aa = max(fwidth(r), 0.01);
		float gap = smoothstep(0.43 - aa, 0.43 + aa, r);
		vec3 cc = cobble_color * (0.86 + 0.24 * hash(cell)) * (1.0 - 0.12 * smoothstep(0.2, 0.42, r));
		cc = mix(cc, cobble_color * 0.45, gap);
		cc *= 1.0 - 0.3 * (1.0 - smoothstep(0.5, 0.62, pm)); // viền tối mép lối
		c = mix(c * (1.0 - 0.25 * smoothstep(0.3, 0.5, pm)), cc, path);
	}

	ALBEDO = c * mix(0.6, 1.0, bk.r);
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), ATTENUATION);
}
