// Sombra de contato recortada em papel: elipse com borda rasgada, multiplicada por tinta (regra 6).
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mul, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 shadow_tint : source_color = vec3(0.62, 0.50, 0.64);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float e = 0.92 + 0.08 * (vn(vec2(a * 6.0, NODE_POSITION_WORLD.x * 3.0)) - 0.5);
	float m = step(length(p), e);
	ALBEDO = mix(vec3(1.0), shadow_tint, m);
}
