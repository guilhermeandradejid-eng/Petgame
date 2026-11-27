// Rastro de Tinta (v2): pincelada larga deixada no ar pela broxa. UV.x = ao longo (0 = ponta nova),
// UV.y = largura. Largura afunila em ease-in até zero na cauda; o fim some por erosão de alfa com
// ruído de pincelada (manchas, não fios de 1 px); borda no mesmo azul 30% mais escuro.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 cor : source_color = vec3(0.208, 0.314, 0.847);
uniform vec3 borda : source_color = vec3(0.146, 0.22, 0.593);
uniform float vida = 1.0;
uniform float semente = 0.0;
uniform float opac = 1.0;
float h1(float x) { return fract(sin(x * 91.7 + semente) * 43758.5453); }
float vn1(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(h1(i), h1(i + 1.0), f); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + semente) * 43758.5453); }
float vn2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	float u = UV.x; float v = UV.y * 2.0 - 1.0;
	float taper = 1.0 - u * u;                       // ease-in: 1 na cabeça, 0 na cauda
	float w = taper * (0.86 + 0.14 * vn1(u * 6.0)) * smoothstep(0.0, 0.05, u + 0.02);
	if (abs(v) > w) discard;
	// erosão por manchas de cerda: limiar sobe para a cauda e com o fim da vida
	float er = vn2(vec2(u * 9.0, v * 2.5)) * 0.6 + vn2(vec2(u * 23.0, v * 6.0)) * 0.4;
	float lim = smoothstep(0.3, 0.92, u) * 1.02 + (1.0 - vida) * 1.1;
	if (er < lim) discard;
	float bristle = vn1(v * 19.0 + 3.0) * 0.65 + vn1(v * 53.0) * 0.35;
	vec3 c = cor * (0.82 + 0.3 * bristle);
	c = mix(c, borda, step(w - 0.14 * taper - 0.02, abs(v)));
	ALBEDO = c;
	ALPHA = opac;
}
