// Mô hình bản Meshy giữ nguyên màu gốc: ảnh màu đã vẽ sẵn sáng tối nên không tô thêm ánh sáng môi trường;
// chỗ có nắng hiện đúng màu ảnh, chỗ bóng (bóng nhân vật, cây) tối và ngả lạnh.
// Đồ họa Cao: ảnh gốc 2048 px, làm nét (unsharp 4 điểm) và thêm hạt chi tiết chỉ đổi độ sáng, không đổi màu.
shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;

uniform sampler2D meshy_albedo : source_color, filter_linear_mipmap;
uniform sampler2D detail : source_color, filter_linear_mipmap, repeat_enable; // ảnh vẽ tay xám lát theo mét
uniform vec2 texel = vec2(0.0009765625); // 1 / 1024 px
uniform float sharpen = 0.0; // 0: tắt (máy yếu)
uniform float detail_amount = 0.0; // 0: tắt
uniform vec3 shadow_tint : source_color = vec3(0.55, 0.6, 0.78);

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = texture(meshy_albedo, UV).rgb;
	if (sharpen > 0.0) {
		vec3 blur = (texture(meshy_albedo, UV + vec2(texel.x, 0.0)).rgb + texture(meshy_albedo, UV - vec2(texel.x, 0.0)).rgb
			+ texture(meshy_albedo, UV + vec2(0.0, texel.y)).rgb + texture(meshy_albedo, UV - vec2(0.0, texel.y)).rgb) * 0.25;
		c = max(c + (c - blur) * sharpen, vec3(0.0));
	}
	if (detail_amount > 0.0) {
		vec3 w = pow(abs(wn), vec3(4.0));
		w /= w.x + w.y + w.z;
		float d = dot(texture(detail, wp.zy * 0.5).rgb, vec3(0.3, 0.59, 0.11)) * w.x
			+ dot(texture(detail, wp.xz * 0.5).rgb, vec3(0.3, 0.59, 0.11)) * w.y
			+ dot(texture(detail, wp.xy * 0.5).rgb, vec3(0.3, 0.59, 0.11)) * w.z;
		float mean = dot(textureLod(detail, vec2(0.5), 12.0).rgb, vec3(0.3, 0.59, 0.11));
		c *= mix(1.0, d / max(mean, 0.02), detail_amount);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}

void light() {
	// Một đèn mặt trời: nắng giữ đúng màu ảnh, bóng đổ tối ngả lạnh. Không tính góc chiếu vì ảnh đã vẽ sẵn khối.
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), ATTENUATION);
}
