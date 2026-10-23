// Mô hình bản Meshy giữ nguyên màu gốc: ảnh màu đã vẽ sẵn sáng tối nên không tô thêm ánh sáng môi trường;
// chỗ có nắng hiện đúng màu ảnh, chỗ bóng (bóng nhân vật, cây) tối và ngả lạnh.
// Mặt sân (chỗ phẳng, sát đất) lấy màu từ ảnh nền liền một tấm đã làm mịn (nen_min.jpg, chiếu theo x, z):
// không lộ đường nối giữa các mảnh ảnh Meshy, không lem màu khi thu nhỏ, không hạt nhiễu. Vách đá, lan can,
// cổng vòng vẫn dùng ảnh Meshy theo UV.
shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;

uniform sampler2D meshy_albedo : source_color, filter_linear_mipmap;
uniform sampler2D flat_albedo : source_color, filter_linear_mipmap, repeat_disable; // ảnh nền phủ đúng sân
uniform bool use_flat = false; // chỉ mặt sân; pháp trận truyền tống dùng ảnh Meshy riêng
uniform vec2 field_size = vec2(50.0, 45.0); // mét (x, z) mà flat_albedo phủ
uniform vec3 shadow_tint : source_color = vec3(0.55, 0.6, 0.78);

varying vec3 wp;
varying float up;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y); // lưới gốc lật mặt lung tung
}

void fragment() {
	vec2 f = wp.xz / field_size;
	vec2 edge = min(f, 1.0 - f) * field_size; // mét tới mép sân
	float w = !use_flat ? 0.0 : smoothstep(0.7, 0.85, up) * (1.0 - smoothstep(0.12, 0.3, wp.y)) * smoothstep(0.2, 0.6, min(edge.x, edge.y));
	vec3 c = w > 0.0 ? texture(flat_albedo, f).rgb : vec3(0.0);
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
