// Mô hình bản Meshy giữ nguyên màu gốc: ảnh màu đã vẽ sẵn sáng tối nên không tô thêm ánh sáng môi trường;
// chỗ có nắng hiện đúng màu ảnh, chỗ bóng (bóng nhân vật, cây) tối và ngả lạnh.
// Mặt sân (chỗ phẳng, sát đất) vẽ lại cho sắc nét ở mọi độ phóng (tools/ban_do_meshy/nen_sac.py):
// mép cỏ / đất / đá lấy từ ảnh khoảng cách (nen_lop, kiểu chữ SDF) nên luôn sắc, có viền tối kiểu nét cọ;
// màu cỏ, đất theo từng chỗ lấy từ ảnh sắc màu nhỏ (giữ tông màu bản Meshy); vân vẽ tay lát theo mét chỉ đổi
// độ sáng (cỏ, đất, lối gạch cuội, phiến đá nứt); bóng đổ dưới cây, đá, bụi vẽ sẵn.
// Vách đá, lan can, cổng vòng vẫn dùng ảnh Meshy theo UV.
shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;

uniform sampler2D meshy_albedo : source_color, filter_linear_mipmap;
uniform bool use_flat = false; // chỉ mặt sân; pháp trận truyền tống dùng ảnh Meshy riêng
uniform vec2 field_size = vec2(50.0, 45.0); // mét (x, z) mà các ảnh nền phủ
uniform sampler2D layers : filter_linear_mipmap, repeat_disable; // R mép cỏ, G mép đá, B bóng vẽ sẵn, A nhiễu
uniform sampler2D grass_tint : source_color, filter_linear, repeat_disable;
uniform sampler2D dirt_tint : source_color, filter_linear, repeat_disable;
uniform sampler2D stone_albedo : source_color, filter_linear_mipmap, repeat_disable; // đá lát, phù văn, phiến đá; A lối gạch
uniform sampler2D stone_detail : filter_linear_mipmap, repeat_enable; // G phiến đá nứt, B gạch cuội
uniform float stone_tile = 0.3; // số lần lặp vân gạch cuội / phiến đá trên 1 m
uniform sampler2D detail : filter_linear_mipmap, repeat_enable; // R vân cỏ, G vân đất, B lá cỏ ở mép
uniform float detail_tile = 0.35; // số lần lặp ảnh vân trên 1 m
uniform float detail_amount = 0.4; // độ đậm vân (0: tắt)
uniform bool detail_two_layers = true; // trộn 2 lớp vân xoay lệch cho không lộ ô lặp (máy yếu: 1 lớp)
uniform float edge_wobble = 0.14; // mép cỏ lởm chởm theo lá cỏ (mét)
uniform float rim_dark = 0.32; // viền tối phía đất sát mép cỏ
uniform vec3 shadow_tint : source_color = vec3(0.55, 0.6, 0.78);

varying vec3 wp;
varying float up;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y); // lưới gốc lật mặt lung tung
}

// Mép sắc theo khoảng cách: rộng đúng một điểm ảnh màn hình dù ảnh gốc bị phóng to.
float edge(float d) {
	float px = max(fwidth(d), 0.002);
	return smoothstep(0.5 - px, 0.5 + px, d);
}

vec3 ground(vec2 f) {
	vec4 lay = texture(layers, f);
	vec2 t = wp.xz * detail_tile;
	vec3 d = texture(detail, t).rgb;
	if (detail_two_layers) {
		d = mix(d, texture(detail, vec2(t.y, -t.x) * 0.61 + 0.37).rgb, smoothstep(0.35, 0.75, lay.a));
	}
	float g = lay.r + (d.b - 0.5) * edge_wobble;
	float grass = edge(g);
	vec3 gc = texture(grass_tint, f).rgb * (1.0 + (d.r - 0.5) * 2.0 * detail_amount);
	gc *= 1.0 + 0.1 * (1.0 - smoothstep(0.5, 0.62, g)); // mép cỏ sáng hơn chút như nét cọ
	vec3 dc = texture(dirt_tint, f).rgb * (1.0 + (d.g - 0.5) * 2.0 * detail_amount);
	dc *= 1.0 - rim_dark * smoothstep(0.32, 0.5, g); // bóng cỏ phủ xuống mép đất
	vec3 c = mix(dc, gc, grass);
	float stone = edge(lay.g);
	vec4 so = texture(stone_albedo, f);
	float cobble = smoothstep(0.45, 0.65, so.a);
	float grey = 1.0 - smoothstep(0.1, 0.25, max(so.r, max(so.g, so.b)) - min(so.r, min(so.g, so.b))); // phù văn tím xanh giữ nguyên
	vec2 sv = texture(stone_detail, wp.xz * stone_tile).gb;
	float sd = mix(sv.x, sv.y, cobble);
	vec3 sc = so.rgb * (1.0 + (sd - 0.5) * 2.0 * mix(0.45 * grey, 0.65, cobble));
	sc *= 1.0 - 0.25 * (1.0 - smoothstep(0.5, 0.58, lay.g)); // viền tối mép đá
	c = mix(c * (1.0 - 0.25 * smoothstep(0.38, 0.5, lay.g)), sc, stone);
	return c * lay.b;
}

void fragment() {
	vec2 f = wp.xz / field_size;
	vec2 e = min(f, 1.0 - f) * field_size; // mét tới mép sân
	float w = !use_flat ? 0.0 : smoothstep(0.7, 0.85, up) * (1.0 - smoothstep(0.12, 0.3, wp.y)) * smoothstep(0.2, 0.6, min(e.x, e.y));
	vec3 c = use_flat ? ground(f) : vec3(0.0); // rẽ nhánh theo uniform: đạo hàm (fwidth, mipmap) vẫn đúng
	if (w < 1.0) {
		c = mix(texture(meshy_albedo, UV).rgb, c, w);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}

void light() {
	// Một đèn mặt trời: nắng giữ đúng màu ảnh, bóng đổ tối ngả lạnh. Không tính góc chiếu vì ảnh đã vẽ sẵn khối.
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), ATTENUATION);
}
