// terreno_mesa: pedra esculpida e escovada a seco em 3 degraus de valor (fundo, meio, aresta), musgo de maquete,
// terra molhada. Nenhum degradê contínuo: os degraus vêm da curvatura e da oclusão assadas, com a borda quebrada
// por pincelada seca (ruído triplanar de 1 m, semente fixa). Luz real soma no máximo ±20%.
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform float real_k = 0.2;
uniform float tom = 1.0;
uniform float esc = 1.0;           // escala do pincel (1 = terraço; abismo usa menor)
uniform float curv_k = 1.0;
uniform float molhado = 0.0;
uniform float placas = 0.0;        // lajes de pedra esculpida (terraço): rachas com lavagem e arestas escovadas
global uniform float dbg;
varying vec3 wp;
varying vec3 wn;
void vertex() { wp = VERTEX; wn = NORMAL; }
vec3 voro(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 8.0, d2 = 8.0; float id = 0.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = vec2(h21(i + g), h21(i + g + 17.3)) * 0.8 + 0.1;
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; id = h21(i + g + 5.1); } else if (d < d2) { d2 = d; }
	}
	return vec3(d1, d2 - d1, id);
}
float tri(vec3 p, vec3 n, float s) {
	vec3 w = abs(n); w /= (w.x + w.y + w.z);
	return vnoise(p.yz * s) * w.x + vnoise(p.xz * s) * w.y + vnoise(p.xy * s) * w.z;
}
void fragment() {
	vec3 n = normalize(wn);
	vec3 base = vc(COLOR.rgb) * tom;
	float ao = UV2.x;
	float cv = (1.0 - UV2.y) * curv_k;
	float br = tri(wp, n, 1.6 * esc) * 0.6 + tri(wp, n, 5.0 * esc) * 0.4;      // pincelada seca
	float s = cv * 1.0 + (ao - 0.85) * 2.0 + (br - 0.5) * 0.35;
	// 3 degraus de valor
	float lvl = s < -0.25 ? 0.0 : (s < 0.3 ? 1.0 : 2.0);
	vec3 fundo = base * 0.72 * vec3(0.92, 0.96, 1.06);
	vec3 aresta = mix(vec3(luma(base)), base, 0.75) * 1.4 + 0.015;
	vec3 P = lvl < 0.5 ? fundo : (lvl < 1.5 ? base : aresta);
	if (placas > 0.0) {
		vec2 q = wp.xz * 0.62 + vec2(vnoise(wp.xz * 0.9), vnoise(wp.xz * 0.9 + 9.0)) * 0.45;
		vec3 v = voro(q);
		float crack = smoothstep(0.045, 0.012, v.y) * smoothstep(0.3, 0.5, vnoise(wp.xz * 1.6 + 3.0));
		float edge = smoothstep(0.11, 0.05, v.y) * smoothstep(0.012, 0.03, v.y) * smoothstep(0.3, 0.5, vnoise(wp.xz * 1.6 + 3.0)) * step(0.5, n.y);
		vec3 pedra = base * (0.9 + 0.2 * v.z);
		float musgo = smoothstep(0.02, 0.1, base.g - base.r);       // onde a cor de vértice é musgo
		vec3 Q = mix(pedra, base, musgo);
		Q = mix(Q, mix(vec3(luma(Q)), Q, 0.7) * 1.45 + 0.02, edge * (1.0 - musgo) * 0.8);
		Q = mix(Q, base * 0.35 * vec3(0.9, 0.95, 1.1), crack * 0.85);
		// musgo cresce nas rachas
		Q = mix(Q, vec3(0.05, 0.085, 0.05) * 1.6, crack * smoothstep(0.4, 0.7, vnoise(wp.xz * 0.7)) * 0.7);
		P = mix(P, Q * (lvl < 0.5 ? 0.7 : (lvl < 1.5 ? 1.0 : 1.12)), placas);
	}
	// luz zenital (+12% em cima) e faces de pedra viradas para baixo mais escuras
	P *= 0.9 + 0.22 * smoothstep(0.2, 0.95, n.y);
	// manchas de tinta (imperfeição com causa: pincelada de 1 m)
	P *= 0.94 + 0.12 * vnoise(wp.xz * 0.9 * esc + 7.0);
	P = pocas(P, wp, 1.0);
	P = clarao(P, wp, n);
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(P * real_k * (1.0 - f.a));
	EMISSION = saida(mix(P * (1.0 - real_k), f.rgb, f.a));
	if (dbg > 2.5) { ALBEDO = vec3(0.0); EMISSION = dbg < 3.5 ? base : (dbg < 4.5 ? vec3(ao) : vec3(cv * 0.5 + 0.5)); }
	ROUGHNESS = 1.0;
}
void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += min(LIGHT_COLOR / PI * ATTENUATION * (0.35 + 0.65 * nl), vec3(1.2));
}
