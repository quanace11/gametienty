// Mặt cỏ trong bồn: xanh nõn chuối loang theo nhiễu, lấm tấm vệt đất, không cần ảnh.
shader_type spatial;
render_mode specular_disabled;

uniform vec3 grass_color : source_color = vec3(0.56, 0.74, 0.24);
uniform vec3 dark_color : source_color = vec3(0.4, 0.58, 0.16);
uniform vec3 soil_color : source_color = vec3(0.45, 0.33, 0.2);
uniform float detail = 1.0; // 0: một màu (đồ họa Thấp)

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

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 col = grass_color;
	if (detail > 0.0) {
		col = mix(dark_color, grass_color, smoothstep(0.25, 0.75, noise(wp * 0.9)));
		col *= 1.0 + (noise(wp * 9.0) - 0.5) * 0.12;
		float soil = smoothstep(0.8, 0.86, noise(wp * 6.0 + 17.0)) * smoothstep(0.55, 0.7, noise(wp * 0.7 + 3.0));
		col = mix(col, soil_color, soil * 0.6); // lấm tấm vệt đất nhỏ
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
