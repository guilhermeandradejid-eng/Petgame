// Pó de cal (flipbook procedural a 12 fps): nuvem branca leitosa em 3 lóbulos com contorno de
// cobalto aguado, que sobe, abre e some por limiar de ruído.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;
uniform float life = 0.0;
uniform float seed = 0.0;
uniform vec3 col : source_color = vec3(0.965, 0.955, 0.93);
uniform vec3 shade : source_color = vec3(0.80, 0.84, 0.90);
uniform vec3 edge : source_color = vec3(0.263, 0.388, 0.682);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	float lf = floor(life * 8.0) / 8.0;   // poses seguradas
	vec2 p = UV * 2.0 - 1.0;
	p.y -= -0.25 + lf * 0.35;
	float d = 9.0;
	for (int k = 0; k < 3; k++) {
		vec2 c = vec2((float(k) - 1.0) * 0.38 * (0.6 + lf * 0.6), (hash(vec2(float(k), seed)) - 0.5) * 0.3);
		float R = (0.28 + 0.12 * hash(vec2(seed, float(k)))) * (0.6 + 0.7 * lf);
		d = min(d, length(p - c) - R);
	}
	d += (vn(UV * 10.0 + seed) - 0.5) * 0.08;
	if (d > 0.05) discard;
	if (vn(UV * 14.0 + seed * 2.0) < smoothstep(0.35, 1.0, life) * 1.05) discard;
	float under = step(0.0, -p.y - 0.1);
	vec3 c = d > 0.0 ? edge : mix(col, shade, under * 0.6);
	ALBEDO = c;
}
