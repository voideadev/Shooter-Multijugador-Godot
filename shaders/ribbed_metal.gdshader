shader_type spatial;
uniform vec3 col_a : source_color = vec3(0.45, 0.5, 0.52);
uniform vec3 col_b : source_color = vec3(0.36, 0.4, 0.42);
uniform float freq = 6.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float k = fract((wpos.x + wpos.z) * freq);
	float s = smoothstep(0.0, 0.5, k) * (1.0 - smoothstep(0.5, 1.0, k));
	ALBEDO = mix(col_b, col_a, s);
	ROUGHNESS = 0.6;
	METALLIC = 0.35;
}
