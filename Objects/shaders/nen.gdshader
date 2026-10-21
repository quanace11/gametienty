// Mặt đất kiểu tranh vẽ: 2 lớp nhiễu theo tọa độ thế giới trộn 2 màu, không lặp ô.
shader_type spatial;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec3 dark : source_color = vec3(0.3, 0.5, 0.2);
uniform vec3 light : source_color = vec3(0.47, 0.66, 0.27);
uniform float scale = 0.035;

varying vec2 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float n = texture(noise, wp * scale).r * 0.65 + texture(noise, wp * scale * 3.7).r * 0.35;
	ALBEDO = mix(dark, light, smoothstep(0.41, 0.57, n));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
