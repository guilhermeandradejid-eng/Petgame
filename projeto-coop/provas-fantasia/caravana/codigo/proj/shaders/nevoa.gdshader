// Névoa pintada: lâmina transparente em forma de pincelada, de frente para a câmera. Na luz, pega o âmbar;
// fora dela, vira linhas de hachura horizontais. Anda com o vento.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;
#include "res://shaders/comum.gdshaderinc"
uniform vec3 cor_luz : source_color = vec3(0.95, 0.66, 0.34);
uniform vec3 cor_treva : source_color = vec3(0.42, 0.5, 0.64);
uniform float alfa = 0.55;
uniform float vel = 0.5;
uniform float semente = 0.0;
uniform float freq_linhas = 40.0;
uniform float aceso = 0.0;    // força do âmbar (a camada perto do fogo)
uniform float curva = 1.0;
uniform float luz_alfa = 1.0;   // alfa dentro da luz (a névoa de maré some no halo)
varying vec3 vw;
void vertex() { if (curva > 0.5) VERTEX.y -= drop_curva(VERTEX); vw = VERTEX; }
void fragment() {
	vec3 cor_luz_l = entrada(cor_luz);
	vec3 cor_treva_l = entrada(cor_treva);
	vec2 uv = UV;
	float t = vento.w * vel * 0.05;
	// forma de pincelada: faixas horizontais com borda recortada
	float n = pinc2(vec2(uv.x * 3.0 - t * 3.0 + semente, uv.y * 1.2 + semente * 0.3), 0.0);
	float n2 = vnoise(vec2(uv.x * 9.0 - t * 6.0 + semente * 2.0, uv.y * 3.0));
	float shape = smoothstep(0.0, 0.35, uv.y) * smoothstep(1.0, 0.55, uv.y) * smoothstep(0.0, 0.3, uv.x) * smoothstep(1.0, 0.7, uv.x);
	float a = step(0.55, n * 0.8 + n2 * 0.35 + shape * 0.3 - 0.15) * shape;
	float m, mol, q; vec3 dl;
	pavio(vw, n, m, mol, dl, q);
	m = max(m, aceso);
	// fora da luz: linhas horizontais
	float sd = floor(ferve);
	float c = uv.y * freq_linhas + (vnoise(vec2(uv.x * 4.0 + sd, sd)) - 0.5) * 0.6;
	float l = 1.0 - smoothstep(0.12, 0.3, abs(fract(c) - 0.5) * 2.0 - 0.6);
	l = linha(c, 0.35);
	vec3 col = mix(cor_treva_l, cor_luz_l * (0.8 + 0.4 * n2), m);
	float aa = a * alfa * mix(l * 0.9, 0.8 * luz_alfa, m);
	ALBEDO = col;
	ALPHA = aa;
	ALBEDO = saida(ALBEDO);
}
