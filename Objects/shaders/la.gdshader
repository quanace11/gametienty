// Lá cây, hoa cắt viền theo alpha, chiếu sáng giống sàn Meshy (ban_do_meshy.gdshader): chỗ nắng hiện đúng màu ảnh,
// nên lá tô màu rêu sàn (tools/la_reu) ra đúng màu rêu sàn; bóng tán tự đổ lên mình chỉ tối nhẹ để còn khối.
shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 shadow_tint : source_color = vec3(0.55, 0.6, 0.78);
uniform float shadow_depth = 0.8; // 1: bóng tối như trên sàn

void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * tint;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.3;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), 1.0 - (1.0 - ATTENUATION) * shadow_depth);
}
