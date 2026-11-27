// Marcas no chão: mancha de óleo (gota de graxa brilhante com contorno na cor de quem untou), anel de jogador com
// símbolo de forma, telegrafia inimiga (verde-ácido, forma que se fecha) e anel de tinta da Frente de Pincel.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;
#include "res://shaders/comum.gdshaderinc"
uniform int tipo = 0;            // 0 mancha de óleo, 1 anel de jogador, 2 telegrafia, 3 frente de pincel, 4 chão queimando
uniform vec3 cor : source_color = vec3(0.88, 0.31, 0.24);
uniform float fecha = 0.5;       // telegrafia: 0 aberta .. 1 fechada
uniform int simbolo = 0;         // 0 círculo, 1 triângulo, 2 quadrado, 3 losango
uniform float semente = 0.0;
uniform float raio = 1.0;
uniform float queima = 0.0;
uniform float quebra = 0.0;      // telegrafia interrompida: o anel se parte
uniform float tempo = 0.0;
varying vec3 vw;
void vertex() { VERTEX.y -= drop_curva(VERTEX); vw = VERTEX; }
float sdpoly(vec2 p, int s) {
	if (s == 1) { p.y = -p.y; vec2 q = vec2(abs(p.x), p.y); return max(q.x * 0.866 + q.y * 0.5, -q.y) - 0.5; }
	if (s == 2) { vec2 q = abs(p); return max(q.x, q.y) - 0.42; }
	if (s == 3) { vec2 q = abs(p); return (q.x + q.y) * 0.75 - 0.42; }
	return length(p) - 0.48;
}
void fragment() {
	vec3 cor_l = entrada(cor);
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	vec3 c = vec3(0.0); float a = 0.0;
	float n = vnoise(p * 3.0 + semente) ;
	if (tipo == 0) {
		// óleo: película escura e brilhante, borda orgânica macia, filete fino na cor_l de quem untou
		float edge = 0.72 + 0.08 * sin(ang * 3.0 + semente) + 0.05 * sin(ang * 5.0 + semente * 2.1) + 0.025 * sin(ang * 11.0 + semente * 3.7);
		float body = 1.0 - smoothstep(edge - 0.08, edge, r);
		float rim = (1.0 - smoothstep(0.0, 0.035, abs(r - edge + 0.01)));
		vec3 g = vec3(0.035, 0.028, 0.03);
		float brilho = smoothstep(0.7, 0.85, pinc2(p * vec2(1.5, 3.0) + semente, 0.3)) * step(r, edge - 0.15);
		c = mix(g, vec3(0.36, 0.3, 0.22), brilho * 0.7);
		c = mix(c, cor_l * 0.9, rim);
		a = max(body * 0.62, rim * 0.55);
		// queimando: o óleo carboniza e as rachaduras viram brasa
		float rach = 1.0 - smoothstep(0.02, 0.07, abs(vnoise(p * 5.0 + semente) - 0.5));
		float pulso = 0.7 + 0.3 * sin(tempo * 9.0 + r * 8.0 + semente);
		vec3 queimado = mix(vec3(0.03, 0.022, 0.018), vec3(1.6, 0.5, 0.1) * pulso, rach * step(r, edge - 0.05));
		c = mix(c, queimado, queima * body);
		a = mix(a, max(body * mix(0.4, 0.95, rach), rim * 0.2), queima);
	} else if (tipo == 1) {
		// anel de jogador: um só anel fino projetado no chão, na cor_l do jogador, alfa 45%; símbolo pequeno na frente
		float ring = 1.0 - smoothstep(0.018, 0.04, abs(r - 0.86));
		vec2 sp = p - vec2(0.0, 0.86);
		float sym = 1.0 - smoothstep(-0.02, 0.02, sdpoly(sp * 6.0, simbolo));
		c = cor_l * 1.1;
		a = max(ring * 0.45, sym * 0.7);
	} else if (tipo == 2) {
		// telegrafia: anel fino que se fecha para dentro (verde-ácido com filete escuro), limite externo tracejado
		// e quatro setas pequenas; sem disco de preenchimento
		float rr = mix(0.95, 0.15, fecha);
		float ring = 1.0 - smoothstep(0.01, 0.024, abs(r - rr));
		float ink = 1.0 - smoothstep(0.024, 0.045, abs(r - rr));
		float edge = (1.0 - smoothstep(0.006, 0.016, abs(r - 0.95))) * step(0.5, fract(ang * 3.8197));
		float seta = 0.0;
		for (int i = 0; i < 4; i++) {
			float aa = float(i) * 1.5708 + 0.785;
			vec2 d = vec2(cos(aa), sin(aa));
			vec2 q = vec2(dot(p, d) - rr - 0.06, dot(p, vec2(-d.y, d.x)));
			seta = max(seta, step(abs(q.y), 0.06 - q.x * 0.9) * step(0.0, q.x) * step(q.x, 0.07));
		}
		float br = 1.0;
		if (quebra > 0.0) br = step(quebra * 0.9, fract(ang * 1.2732 + n * 0.3));
		c = mix(vec3(0.03, 0.04, 0.01), vec3(0.72, 0.9, 0.2), max(ring, seta));
		a = max(max(ring * 0.65, ink * 0.35), max(edge * 0.2, seta * 0.6)) * br;
	} else if (tipo == 3) {
		// anel de tinta da frente de pincel: borda molhada recortada com gotas
		float e = 0.9 + (vnoise(vec2(ang * 6.0 + semente, 1.0)) - 0.5) * 0.12;
		float band = smoothstep(e - 0.12, e - 0.02, r) * (1.0 - smoothstep(e, e + 0.03, r));
		float gotas = step(0.82, vnoise(vec2(ang * 22.0, r * 30.0 + semente))) * step(e, r) * step(r, e + 0.08);
		c = mix(vec3(0.86, 0.5, 0.2), vec3(0.95, 0.8, 0.5), step(0.5, n));
		a = max(band * 0.85, gotas);
		c = mix(vec3(0.3, 0.12, 0.05), c, step(r, e - 0.02) + gotas);
	} else if (tipo == 5) {
		// Badalada Funda: três ondas de bronze-sebo que se abrem (a ajuda cresce), traço quebrado
		float ph = fract(tempo * 0.8);
		a = 0.0;
		for (int k = 0; k < 3; k++) {
			float rr = fract(ph + float(k) / 3.0) * 0.95;
			float w = 0.025 + 0.02 * (1.0 - rr);
			float ring = (1.0 - smoothstep(w * 0.6, w, abs(r - rr))) * step(0.3, vnoise(vec2(ang * 9.0, float(k) + semente)));
			a = max(a, ring * (1.0 - rr));
		}
		c = mix(vec3(0.85, 0.6, 0.3), cor_l * 1.2, 0.5);
	} else if (tipo == 6) {
		// chão consagrado: cristais de sal em pinceladas curtas
		float cr = step(0.62, vnoise(p * 14.0 + semente)) * step(r, 0.9 + (n - 0.5) * 0.2);
		float borda_s = (1.0 - smoothstep(0.02, 0.05, abs(r - 0.88 - (n - 0.5) * 0.15)));
		c = cor_l * 1.1;
		a = max(cr * 0.85, borda_s * 0.7);
	} else if (tipo == 7) {
		// Pederneira na poça: raios curtos em zigue-zague na cor_l de quem lançou, núcleo sebo
		float st = floor(tempo * 12.0);
		a = 0.0;
		for (int k = 0; k < 6; k++) {
			float aa = (float(k) + vnoise(vec2(st, float(k)))) * 1.047;
			vec2 d = vec2(cos(aa), sin(aa));
			float along = dot(p, d);
			float lat = dot(p, vec2(-d.y, d.x)) - (vnoise(vec2(along * 9.0 + st, float(k))) - 0.5) * 0.2;
			a = max(a, (1.0 - smoothstep(0.012, 0.03, abs(lat))) * step(0.0, along) * step(along, 0.85));
		}
		c = mix(cor_l * 1.4, vec3(1.6, 1.5, 1.3), step(r, 0.25));
	} else if (tipo == 8) {
		c = vec3(0.03, 0.025, 0.05);
		a = (1.0 - smoothstep(0.35, 0.95, r)) * 0.62;
	} else {
		float edge = 0.85 + (vnoise(vec2(ang * 3.0 + semente, 2.0)) - 0.5) * 0.3;
		float body = 1.0 - smoothstep(edge - 0.1, edge, r);
		c = mix(vec3(0.05, 0.03, 0.02), vec3(1.6, 0.55, 0.12), step(0.62, n) * queima);
		a = body * 0.85;
	}
	if (a < 0.01) discard;
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0);
	ALBEDO = saida(ALBEDO);
}
