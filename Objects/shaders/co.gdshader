// Cỏ kiểu tranh vẽ: gốc đậm, ngọn sáng theo độ cao đỉnh (mét, tính trong mesh), nhân với ảnh lá.
// Bản trong mờ (bụi mình đang đứng trong) tạo trong bush.gd bằng cách thay dòng đánh dấu MO.
shader_type spatial;
render_mode cull_disabled; //MO_RENDER

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 root_color : source_color = vec3(0.13, 0.32, 0.12);
uniform vec3 tip_color : source_color = vec3(0.6, 0.86, 0.32);
uniform float height = 1.0;
uniform float fade = 1.0;

varying float h;

void vertex() {
	h = clamp(VERTEX.y / height, 0.0, 1.0);
}

void fragment() {
	vec3 t = texture(tex, UV).rgb;
	ALBEDO = mix(root_color, tip_color, h * h * (3.0 - 2.0 * h)) * t;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	//MO_ALPHA
}
