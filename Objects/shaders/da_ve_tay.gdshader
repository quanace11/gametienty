// Đá vẽ tay kiểu Stylized Fantasy: ảnh vẽ tay chiếu 3 phía theo tọa độ thế giới (không cần UV của mô hình),
// mặt hướng lên phủ rêu, mép quay ra phía camera sáng viền ấm để khối đá rõ khi nhìn từ trên.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 moss_tint : source_color = vec3(1.0);
uniform float tile = 0.35; // số lần lặp ảnh trên 1 m
uniform float moss_amount = 0.0; // 0: không rêu, 1: phủ hết mặt trên
uniform float rim = 0.25; // độ sáng viền
uniform vec3 rim_color : source_color = vec3(1.0, 0.92, 0.75);

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(wn), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 c = texture(albedo, wp.zy * tile).rgb * w.x
		+ texture(albedo, wp.xz * tile).rgb * w.y
		+ texture(albedo, wp.xy * tile).rgb * w.z;
	c *= tint;
	if (moss_amount > 0.0) {
		float top = smoothstep(1.0 - moss_amount, 1.0 - moss_amount + 0.25, wn.y);
		float m = dot(texture(moss, wp.xz * 0.25).rgb, vec3(0.3, 0.59, 0.11)) * 3.0; // chỉ lấy vân sáng tối của ảnh rêu
		c = mix(c, moss_tint * m, top);
	}
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = c + rim_color * f * rim;
	ROUGHNESS = 1.0;
}
