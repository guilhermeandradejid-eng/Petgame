// Papel de seda: pedaço rasgado (borda por ruído angular), translúcido, com fibras e vinco.
// Sobreposição deixa ver o pedaço de baixo, como seda de verdade. Sem textura.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(1.0, 0.24, 0.55);
uniform float opacity = 0.78;
uniform int shape = 0; // 0 = retalho, 1 = estrela de impacto, 2 = fita
uniform float seed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float sd = seed + dot(NODE_POSITION_WORLD, vec3(3.1, 7.7, 1.3));
	float a = atan(p.y, p.x);
	float r = length(p);
	float edge;
	if (shape == 1) {
		edge = mix(0.38, 0.98, pow(abs(cos(a * 4.0 + sd)), 6.0));
	} else if (shape == 2) {
		edge = 2.0; r = abs(p.y) * 3.0 + 0.0 * a;
	} else {
		edge = max(abs(p.x), abs(p.y)) > 0.0 ? 0.86 : 0.86; r = max(abs(p.x) * 1.0, abs(p.y) * 1.15);
	}
	edge += 0.07 * (vn(vec2(a * 5.0, sd)) - 0.5) + 0.05 * (vn(vec2(a * 23.0, sd + 9.0)) - 0.5);
	if (r > edge) discard;
	float fib = vn(p * vec2(40.0, 4.0) + sd) * 0.6 + vn(p * vec2(6.0, 60.0) - sd) * 0.4;
	float crease = 1.0 - 0.22 * smoothstep(0.035, 0.0, abs(dot(p, normalize(vec2(0.6, 0.8 + 0.3 * sin(sd)))) - 0.12));
	float rim = smoothstep(edge - 0.06, edge, r);
	ALBEDO = tint * (0.9 + 0.12 * fib) * crease;
	ALPHA = opacity * (1.0 - 0.35 * rim);
}
