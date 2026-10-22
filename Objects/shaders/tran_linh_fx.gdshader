// Hiệu ứng trận linh (cộng sáng): luồng linh khí, vòng sóng, chớp sáng, tia lửa, hào quang linh thạch.
// Màu và độ sáng đặt theo từng node (instance uniform tint), nên mọi trận linh dùng chung 3 material.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform int shape = 0; // 0 đặc, 1 vòng sóng (mặt phẳng, theo UV), 2 mềm mép (mờ dần ra rìa theo góc nhìn)
instance uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	float a = tint.a * COLOR.a;
	if (shape == 1) {
		float d = length(UV - 0.5) * 2.0;
		a *= smoothstep(0.55, 0.9, d) * (1.0 - smoothstep(0.9, 1.0, d));
	} else if (shape == 2) {
		a *= pow(abs(dot(NORMAL, VIEW)), 1.5);
	}
	ALBEDO = tint.rgb * COLOR.rgb * a;
}
