shader_type spatial;
uniform vec3 col_a : source_color = vec3(0.78, 0.67, 0.48);
uniform vec3 col_b : source_color = vec3(0.64, 0.52, 0.35);
uniform float scale = 0.5;
varying vec3 wpos;
float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float n = vnoise(wpos * scale) * 0.55 + vnoise(wpos * scale * 4.0) * 0.3 + vnoise(wpos * scale * 17.0) * 0.15;
	ALBEDO = mix(col_b, col_a, n);
	ROUGHNESS = 0.95;
}
