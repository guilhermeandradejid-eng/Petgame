// Água do vau: o molhado da gravura são linhas horizontais finas que refletem (escurecem embaixo do que está em cima,
// clareiam no céu de papel), quebradas pela chuva (anéis de linha). Estados por uniform: eletrificado (linhas brancas
// quebradas que mudam a cada 3 quadros), consagrado (círculo de papel limpo com borda de cera), mancha de impressão.
shader_type spatial;
render_mode world_vertex_coords, specular_disabled, cull_back;
#include "res://shaders/grav.gdshaderinc"
uniform vec4 elet = vec4(0.0, 0.0, 0.0, 0.0);     // xz centro, z raio, w força
uniform vec4 cons = vec4(0.0, 0.0, 0.0, 0.0);     // xz centro, z raio, w força
uniform float chuva = 1.0;
uniform vec3 cor_rio : source_color = vec3(0.435, 0.533, 0.580);
uniform vec2 margem = vec2(-11.0, 3.2);           // z norte, z sul (a cor volta do sul)
uniform vec4 sombras[24];                         // personagens: xz, raio, força (escurecem o reflexo)
uniform int n_sombras = 0;
varying vec3 v_w;
void vertex() {
	v_w = VERTEX;
	VERTEX.y -= curva(VERTEX);
}
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
// curva do rio (igual a mundo.gd: dobra para o norte rio acima, a leste, e para o sul a oeste)
float rio_bend(float x) {
	float e = max(x - 6.0, 0.0);
	float b = -0.012 * min(e, 14.0) * min(e, 14.0) - 0.336 * max(e - 14.0, 0.0);
	float o = max(-x - 8.0, 0.0);
	return b + 0.01 * min(o, 14.0) * min(o, 14.0) + 0.28 * max(o - 14.0, 0.0);
}
void fragment() {
	ALBEDO = vec3(1.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float tq = floor(tempo * 20.0) / 20.0;
	// linhas horizontais (ao longo de x), onduladas pela correnteza
	vec2 q = vec2(v_w.z - rio_bend(v_w.x) + 0.05 * sin(v_w.x * 1.7 + tq * 2.0) + 0.03 * sin(v_w.x * 4.3 - tq * 3.1), v_w.x * 0.25) * 0.8;
	// a cor do rio volta pela margem sul (retomada) e some no meio do vau
	float zr = v_w.z - rio_bend(v_w.x);
	float ret = smoothstep(margem.x + 4.0, margem.y, zr);
	vec4 ag = vec4(cor_u(cor_rio), smoothstep(0.35, 0.65, ret));
	// reflexo: escurece sob os personagens (manchas alongadas para baixo da tela), clareia longe
	float refl = 0.0;
	for (int i = 0; i < 24; i++) {
		if (i >= n_sombras) break;
		vec4 s = sombras[i];
		vec2 d = (v_w.xz - s.xy) / vec2(s.z * 0.5, s.z * 1.4);
		d.y -= 0.6;
		refl = max(refl, s.w * smoothstep(1.0, 0.4, length(d)));
	}
	GRAV_SET(wp, q, ag, -0.075, refl + escuro_mundo * 0.35);
	g_luz.z = reserva(wp);
	// anéis de chuva: círculos de linha que abrem e somem
	float anel = 0.0;
	if (chuva > 0.0) {
		vec2 cel = floor(v_w.xz * 1.3);
		for (int k = 0; k < 2; k++) {
			vec2 c2 = cel + vec2(float(k) * 0.5);
			float h = h21(c2);
			float ph = fract(tq * 0.9 + h);
			vec2 ctr = (c2 + vec2(h21(c2 + 3.1), h21(c2 + 7.7))) / 1.3;
			float r = ph * 0.32;
			float d = abs(length(v_w.xz - ctr) - r);
			anel = max(anel, (1.0 - smoothstep(0.0, 0.012 + 0.01 * ph, d)) * (1.0 - ph) * step(0.35, h) * chuva);
		}
	}
	g_misc.z = max(g_misc.z, anel * 1.6);
	// estados
	float de = length(v_w.xz - elet.xy);
	float dc = length(v_w.xz - cons.xy);
	vec3 e = vec3(0.0);
	if (elet.w > 0.0 && de < elet.z) {
		// eletrificado: poucos fios de faísca curtos, em zigue-zague, só dentro do raio (4 a 6 m), trocados a cada
		// 3 quadros; afinam nas pontas e somem para a borda. Nada de grade sobre o rio inteiro.
		float t3 = floor(tempo * 20.0);
		float ang = atan(v_w.z - elet.y, v_w.x - elet.x);
		float nfio = 11.0;
		float k = floor(ang / 6.2832 * nfio + 0.5);
		float sorteio = h21(vec2(k, t3));
		float a0 = (k + (sorteio - 0.5) * 0.5) / nfio * 6.2832;
		float L = elet.z * (0.35 + 0.6 * h21(vec2(k + 7.0, t3)));
		float zig = sin(de * 9.0 + sorteio * 20.0) * 0.12 + sin(de * 23.0 + t3) * 0.04;
		float off = abs(ang - a0 + zig / max(de, 0.3));
		float u = de / L;
		float w = 0.035 * (1.0 - u) * smoothstep(0.0, 0.08, u);
		float fio = (1.0 - smoothstep(w * 0.6, w, off * de)) * step(u, 1.0) * step(0.35, sorteio);
		float m = fio * smoothstep(elet.z, elet.z * 0.5, de) * elet.w;
		e = vec3(m);
	}
	EMISSION = vec3(0.0);
	g_wp = vec3(de, dc, e.x);
}
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		GF g = GRAV_GET;
		float de = g_wp.x; float dc = g_wp.y; float em = g_wp.z;
		g.wp = v_w;
		// consagrado: dentro do círculo some a hachura (papel limpo com cera) e a borda é um anel de cera
		float cin = 0.0;
		if (cons.w > 0.0) {
			cin = smoothstep(cons.z, cons.z - 0.25, dc) * cons.w;
			g.aguada = vec4(mix(g.aguada.rgb, CERA, step(0.5, cin)), mix(g.aguada.a, 0.0, cin));
		}
		// só a camada horizontal: o tom da água é a largura da linha (reflexo escuro = linha grossa)
		// faixas de reflexo do céu: linhas finas onde o céu de papel reflete, grossas na sombra das margens
		float faixa = sin(v_w.z * 1.7 + sin(v_w.x * 0.21) * 2.0) * 0.5 + 0.5;
		float D0 = 0.0;
		float D = clamp(0.35 + escuro_base * 0.3 + faixa * 0.45 + g.extra * 0.6 + smoothstep(1.0, -4.0, v_w.z - rio_bend(v_w.x)) * 0.35, 0.0, 1.9);
		D = max(D, min(g.extra - 0.6, 1.0) + 1.0 * step(1.0, g.extra));
		if (cin > 0.0) D = mix(D, 0.3, cin);   // consagrado: papel limpo com reflexo de linha fina
		vec3 c = grav_cor2(g, D, NORMAL, LIGHT, VIEW, 1.0);
		if (cons.w > 0.0) {
			float borda = smoothstep(0.18, 0.0, abs(dc - cons.z)) * cons.w;
			c = mix(c, CERA * 1.05, borda);
		}
		c = mix(c, vec3(0.906, 0.88, 0.81) * 1.25, em);
		DIFFUSE_LIGHT += c;
	}
}
