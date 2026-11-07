shader_type spatial;
render_mode cull_disabled;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 q = wpos.xz;
	float n = noise(q * 0.06) * 0.5 + noise(q * 0.4) * 0.3 + hash(floor(q * 3.0)) * 0.2;
	vec3 a = vec3(0.20, 0.50, 0.12);
	vec3 b = vec3(0.34, 0.64, 0.16);
	ALBEDO = mix(a, b, n);
	ROUGHNESS = 1.0;
}
