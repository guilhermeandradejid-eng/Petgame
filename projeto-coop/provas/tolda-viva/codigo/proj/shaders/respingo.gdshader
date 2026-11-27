// Respingo da demão de Tinta (v2): gota assimétrica esticada no sentido da pincelada, com gotas
// satélites que saem em leque. Uma forma dominante, duas cores (anilina e o azul escuro da borda).
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 cor : source_color = vec3(0.208, 0.314, 0.847);
uniform vec3 cor_esc : source_color = vec3(0.146, 0.22, 0.593);
uniform float t = 0.0;  // 0..1 da vida
uniform float sem = 0.0;
float h(float x) { return fract(sin(x * 91.7 + sem) * 43758.5453); }
float sd_drop(vec2 p, float r, float l) {
	// gota: círculo que estica para +x
	vec2 q = vec2(max(p.x, 0.0) / (1.0 + l), p.y);
	q.x = p.x < 0.0 ? p.x : q.x;
	return length(q) - r * (1.0 - 0.35 * smoothstep(0.0, r * (1.0 + l), p.x));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float grow = min(1.0, t * 5.0);
	float d = sd_drop(p + vec2(0.35, 0.0), 0.34 * grow, 1.4 * grow);
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float a = (h(fi) - 0.5) * 1.6;
		float dist = (0.35 + 0.5 * h(fi + 9.0)) * (0.4 + t * 1.2);
		vec2 c = vec2(cos(a), sin(a)) * dist - vec2(0.2, 0.0);
		float rr = (0.05 + 0.07 * h(fi + 3.0)) * (1.0 - t * 0.6);
		d = min(d, length(p - c) - rr);
	}
	// some por erosão no fim
	float er = fract(sin(dot(floor(p * 14.0), vec2(12.9, 78.2)) + sem) * 437.5);
	if (d > 0.0 || er < smoothstep(0.55, 1.0, t)) discard;
	vec3 c = mix(cor, cor_esc, step(-0.045, d));
	ALBEDO = c;
}
