// Água de resina com verniz: a única superfície brilhante. Preta, espelhada; reflexo barato (céu pintado da caverna,
// a Coluna, as luzes de herói e o clarão da reação), anéis de chuva e a Corrente correndo em linhas.
shader_type spatial;
render_mode unshaded, shadows_disabled, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform float tempo = 0.0;
uniform float corrente = 0.0;      // 0..1: força da Corrente na poça
uniform float corrente_t = 0.0;    // quadros desde o início (as linhas correm em 6 quadros)
uniform vec3 centro = vec3(0.0);
uniform vec2 raio = vec2(4.4, 3.0);
uniform vec3 eletrico : source_color = vec3(0.55, 0.95, 1.0);
uniform vec4 luz0 = vec4(0.0);     // xyz posição de uma luz quente (vela/geodo), w força
uniform vec4 luz1 = vec4(0.0);
uniform vec3 sol_dir = vec3(0.1, 1.0, 0.25);
global uniform float dbg;
varying vec3 wp;
void vertex() { wp = VERTEX; }
float anel(vec2 p, float t, float seed) {
	vec2 cell = floor(p * 2.6);
	vec2 f = fract(p * 2.6) - 0.5;
	float h = h21(cell + seed);
	float ph = fract(t * 0.9 + h);
	vec2 o = (vec2(h21(cell + 3.1), h21(cell + 7.7)) - 0.5) * 0.5;
	float r = length(f - o);
	float ring = smoothstep(0.022, 0.0, abs(r - ph * 0.32)) * (1.0 - ph) * step(0.72, h);
	return ring;
}
void fragment() {
	vec2 q = (wp.xz - centro.xz) / raio;
	float rr = length(q);
	float borda = smoothstep(1.0, 0.82, rr + (vnoise(wp.xz * 1.5) - 0.5) * 0.25);
	if (borda < 0.5) discard;
	vec3 V = normalize(CAMERA_POSITION_WORLD - wp);
	// anéis de chuva perturbam a normal
	float rg = anel(wp.xz, tempo, 0.0) + anel(wp.xz + 0.37, tempo * 1.1 + 0.3, 5.0);
	vec3 n = normalize(vec3(dFdx(rg) * -3.0, 1.0, dFdy(rg) * -3.0));
	vec3 r = reflect(-V, n);
	// "céu" refletido: o teto escuro da caverna com um rasgo dourado (a Coluna) e o brilho ciano dos fungos
	vec3 col = vec3(0.006, 0.008, 0.013);
	col += vec3(0.012, 0.022, 0.026) * smoothstep(0.2, 0.9, r.y);
	float sol = pow(clamp(dot(r, normalize(sol_dir)), 0.0, 1.0), 40.0);
	col += vec3(0.95, 0.78, 0.45) * sol * 0.9;
	// luzes quentes dos heróis refletidas (estrias verticais de verniz)
	for (int i = 0; i < 2; i++) {
		vec4 L = i == 0 ? luz0 : luz1;
		if (L.w > 0.0) {
			vec3 m = vec3(L.x, 2.0 * wp.y - L.y, L.z);
			vec3 d = normalize(m - CAMERA_POSITION_WORLD);
			vec3 rd = reflect(-V, n);
			vec3 toL = normalize(m - wp);
			float ang = 1.0 - dot(normalize(vec3(rd.x, 0.0, rd.z)), normalize(vec3(toL.x, 0.0, toL.z)));
			float k = pow(clamp(dot(rd, toL), 0.0, 1.0), 300.0) + smoothstep(0.004, 0.0, ang) * smoothstep(0.7, 0.98, dot(rd, toL)) * 0.5;
			col += vec3(1.0, 0.7, 0.35) * k * L.w * 0.6;
		}
	}
	// verniz: fresnel e anéis claros
	float fr = pow(1.0 - clamp(dot(vec3(0, 1, 0), V), 0.0, 1.0), 3.0);
	col += vec3(0.04, 0.05, 0.06) * fr + vec3(0.12, 0.13, 0.15) * rg * 0.5;
	// Corrente: linhas elétricas que correm do centro para fora em 6 quadros e ficam piscando
	if (corrente > 0.0) {
		float reach = clamp(corrente_t / 6.0, 0.0, 1.0) * 1.15;
		float a = atan(q.y, q.x);
		float lines = 0.0;
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float w = vnoise(vec2(a * 4.0 + fk * 5.0 + floor(rr * 9.0) * 0.21, rr * 3.0 - floor(corrente_t / 2.0) * 1.7 + fk));
			lines += step(abs(w - 0.5), 0.022);
		}

		float m = step(rr, reach) * corrente;
		col = mix(col, col + eletrico * 0.5, m * 0.6);
		col += eletrico * clamp(lines, 0.0, 1.0) * m * 0.35;
		col += eletrico * smoothstep(reach - 0.12, reach, rr) * step(rr, reach) * corrente * 1.2;   // a borda da onda elétrica
	}
	col = clarao(col, wp, vec3(0, 1, 0));
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(mix(col, f.rgb, f.a));
	if (dbg > 5.5) ALBEDO = dbg < 6.5 ? vec3(f.a) : (dbg < 7.5 ? vec3(rg) : vec3(sol));
}
