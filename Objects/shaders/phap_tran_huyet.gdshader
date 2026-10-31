// Pháp trận Meshy (cùng mô hình với pháp trận truyền tống) nhuộm thành huyết trận: chỗ phù văn sáng xanh
// đổi sang đỏ máu, đá ngả tối đỏ. Chiếu sáng như ban_do_meshy.gdshader: nắng giữ màu ảnh, bóng ngả lạnh.
shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;

uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform vec3 stone_tint : source_color = vec3(0.66, 0.54, 0.54);
uniform vec3 glow_color : source_color = vec3(1.0, 0.16, 0.12);
uniform vec3 shadow_tint : source_color = vec3(0.55, 0.6, 0.78);

void fragment() {
	vec3 c = texture(albedo, UV).rgb;
	float glow = smoothstep(0.06, 0.22, c.b - c.r) * smoothstep(0.35, 0.6, c.b); // phù văn xanh sáng
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 stone = vec3(lum) * stone_tint * 1.1; // rêu, đá thành xám đỏ
	ALBEDO = mix(stone, glow_color * (0.6 + lum), glow);
	EMISSION = glow_color * glow * 0.6;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), ATTENUATION);
}
