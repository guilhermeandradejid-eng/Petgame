// Névoa, fumaça e feixe em grão de aquatinta: nada de transparência suave; cada pixel é papel/cor ou nada, sorteado pelo
// grão de resina (textura de ruído azul em tela). A densidade vem de faixas de ruído que andam com o vento.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;
global uniform vec3 foco;
global uniform float curva_k;
global uniform float curva_r0;
global uniform vec2 curva_dir;
global uniform float tempo;
global uniform vec2 vento;
global uniform sampler2D grao : filter_nearest, repeat_enable;
uniform vec3 cor : source_color = vec3(0.914, 0.875, 0.788);
uniform vec3 cor2 : source_color = vec3(0.914, 0.875, 0.788);
uniform float dens = 0.5;
uniform float escala = 0.15;
uniform vec2 deriva = vec2(0.3, 0.0);
uniform int modo = 0;          // 0 camada de névoa (plano), 1 coluna de fumaça (UV), 2 feixe (UV)
uniform float distante = 0.0;
uniform float fase = 0.0;
uniform float borda = 1.0;     // esmaece nas bordas do cartão
uniform float curvar = 1.0;
uniform float grao_esc = 1.0;
varying vec3 v_w;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.55 + vn(p * 2.1 + 3.7) * 0.3 + vn(p * 4.3 + 1.1) * 0.15; }
void vertex() {
	v_w = VERTEX;
	if (curvar > 0.5) {
		float d = dot(VERTEX.xz - foco.xz, curva_dir);   // tronco que rola: o chão cai para o norte, o horizonte fica reto
		float e = max(d - curva_r0, 0.0);
		VERTEX.y -= curva_k * e * e;
	}
}
void fragment() {
	float tq = floor(tempo * 20.0) / 20.0 + fase;
	float a = 0.0;
	if (modo == 0) {
		vec2 p = v_w.xz * escala * vec2(0.22, 2.6) + deriva * tq * escala;
		a = fbm(p) * 1.25 - 0.32;
		a = smoothstep(0.0, 0.7, a);
		float e = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		a *= smoothstep(0.0, 0.25, e * borda + (1.0 - borda) * 0.3);
	} else if (modo == 1) {
		// coluna de fumaça: sobe e inclina com o vento, alarga para cima
		vec2 uv = UV;
		float w = 0.18 + 0.5 * (1.0 - uv.y);
		float x = (uv.x - 0.5 - (1.0 - uv.y) * (1.0 - uv.y) * 0.35) / w;
		float n = fbm(vec2(x * 1.5, uv.y * 4.0 + tq * 0.5));
		a = smoothstep(1.0, 0.25, abs(x) + n * 0.5) * smoothstep(0.0, 0.08, 1.0 - uv.y) * smoothstep(0.0, 0.25, uv.y);
	} else if (modo == 4) {
		// marca de queimado do raio: estrela de rachaduras de tinta em volta de um miolo cheio
		vec2 c = UV * 2.0 - 1.0;
		float r = length(c);
		float ang = atan(c.y, c.x);
		float raios = pow(abs(sin(ang * 4.5 + fbm(vec2(ang * 3.0, 1.0)) * 3.0)), 6.0) * smoothstep(1.0, 0.2, r);
		a = max(smoothstep(0.45, 0.15, r + (fbm(c * 4.0) - 0.5) * 0.3), raios * 0.9);
	} else if (modo == 3) {
		// sombra de contato em disco (aquatinta mais densa no centro)
		float r = length(UV * 2.0 - 1.0);
		a = smoothstep(1.0, 0.35, r);
	} else {
		// feixe de luz: lâmina que esmaece nas pontas, com fiapos
		vec2 uv = UV;
		float n = fbm(vec2(uv.x * 6.0, uv.y * 2.0 - tq * 0.2));
		a = smoothstep(0.0, 0.35, uv.x) * smoothstep(1.0, 0.65, uv.x) * smoothstep(0.0, 0.3, uv.y) * smoothstep(1.0, 0.7, uv.y) * (0.6 + 0.6 * n);
	}
	a *= dens;
	vec4 G = texture(grao, FRAGCOORD.xy / (256.0 * grao_esc));
	float g = G.r * 0.996 + 0.002;
	if (g > a) discard;
	ALBEDO = mix(cor, cor2, step(g, a * 0.35));
}
