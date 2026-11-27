// Telegrafia do raio do clima, em papel branco (não é perigo de inimigo): as linhas de hachura do céu dobram e
// convergem para a ponta de ferro do mastro, apertando conforme o raio chega.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never, depth_test_disabled;
uniform float k = 0.0;
uniform float t = 0.0;
uniform vec3 tinta : source_color = vec3(0.137, 0.110, 0.090);
uniform vec3 papel : source_color = vec3(0.957, 0.945, 0.910);
float h11(float n) { return fract(sin(n * 127.1) * 43758.5453); }
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	float n = 44.0;
	float id = floor((a / 6.2832 + 0.5) * n);
	float fa = fract((a / 6.2832 + 0.5) * n) - 0.5;
	float tq = floor(t * 20.0) / 20.0;
	// traço que corre para dentro: só um pedaço de cada raio aparece, andando em direção ao centro
	float ph = fract(h11(id) + tq * (0.9 + h11(id + 3.0)));
	float seg = smoothstep(0.0, 0.08, r - (1.0 - ph) * 0.9) * smoothstep(0.35, 0.2, r - (1.0 - ph) * 0.9);
	float w = 0.022 * (0.4 + r);
	float lin = 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.08, abs(fa));
	float m = lin * seg * step(0.12, r) * step(r, 0.98) * step(0.35, h11(id + 7.0));
	if (m * k < 0.5) discard;
	ALBEDO = mix(tinta, papel * 1.6, step(0.5, h11(id + 11.0)));
}
