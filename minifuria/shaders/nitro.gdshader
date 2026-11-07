shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Chama de nitro: cone com ruído correndo, núcleo branco, borda azul/roxa e "diamantes de choque".
uniform float power = 1.0;
uniform vec3 core_col : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 mid_col : source_color = vec3(0.25, 0.75, 1.0);
uniform vec3 edge_col : source_color = vec3(0.45, 0.2, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// UV.y: 0 na base (escapamento) -> 1 na ponta; UV.x dá a volta no cone
	float along = 1.0 - UV.y;
	float n = noise(vec2(UV.x * 6.0, along * 5.0 - TIME * 14.0)) * 0.6 + noise(vec2(UV.x * 13.0, along * 11.0 - TIME * 23.0)) * 0.4;
	float fade = smoothstep(1.0, 0.25 + n * 0.35, along);
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	float core = (1.0 - rim) * smoothstep(0.55, 0.0, along);
	// diamantes de choque
	float dia = pow(max(0.0, sin(along * 28.0 - TIME * 2.0)), 8.0) * smoothstep(0.7, 0.1, along);
	vec3 c = mix(edge_col, mid_col, smoothstep(0.9, 0.2, along));
	c = mix(c, core_col, clamp(core * 1.4 + dia * 0.8, 0.0, 1.0));
	float a = fade * (0.55 + n * 0.6) * (0.4 + (1.0 - rim) * 0.8) * power;
	ALBEDO = c * (2.2 + dia * 3.0);
	ALPHA = clamp(a, 0.0, 1.0);
}
