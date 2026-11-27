// Anel de choque do macete (v2): achatado no chão, borda irregular de lasca, em duas cores de
// matéria (serragem clara e madeira). A cor dos jogadores entra só nos 2 primeiros quadros (clarão).
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 cor_a : source_color = vec3(0.95, 0.9, 0.78);
uniform vec3 cor_b : source_color = vec3(0.66, 0.43, 0.28);
uniform float raio = 0.5;
uniform float esp = 0.08;
uniform float alpha = 1.0;
uniform float sem = 0.0;
float h(float x) { return fract(sin(x * 78.233 + sem) * 43758.5453); }
float vn(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(h(i), h(i + 1.0), f); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float e = esp * (0.55 + 0.9 * vn(a * 4.0));      // espessura irregular
	float d = r - raio;
	if (abs(d) > e) discard;
	float lasca = step(0.25, vn(a * 13.0 + 5.0));       // falhas na borda de fora
	if (d > e * 0.3 && lasca < 0.5) discard;
	vec3 c = mix(cor_b, cor_a, step(0.0, d + e * 0.25));
	ALBEDO = c;
	ALPHA = alpha;
}
