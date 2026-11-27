// Água rasa do brejo: na luz, guache escuro com listras douradas refletidas das lanternas e anéis de chuva;
// na Treva, gravura de linhas horizontais. Mesmo pavio e mesma curvatura do mundo.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled;
#include "res://shaders/comum.gdshaderinc"
uniform vec3 c_agua : source_color = vec3(0.16, 0.19, 0.2);
uniform float chuva = 1.0;
uniform float tempo = 0.0;
uniform float freq = 4.5;
varying vec3 vw;
void vertex() { VERTEX.y -= drop_curva(VERTEX); vw = VERTEX; }
float listra(vec4 L, vec3 w, vec3 cam, vec3 right) {
	if (L.w <= 0.01) return 0.0;
	// reflexo: faixa vertical na tela entre a luz e a câmera, alongada na direção da câmera
	vec3 d = w - L.xyz;
	vec3 fw = normalize(vec3(w.x - cam.x, 0.0, w.z - cam.z));
	float wob = (vnoise(vec2(w.x * 3.0, w.z * 9.0 + tempo * 2.0)) - 0.5) * 0.5;
	float lat = abs(dot(d, right)) + wob;
	float ao = dot(vec3(d.x, 0.0, d.z), fw);
	float alc = min(L.w, 5.0);
	return exp(-lat * lat / 0.25) * smoothstep(-alc * 1.3, -0.2, ao) * (1.0 - smoothstep(-0.2, 0.5, ao));
}
void fragment() {
	vec3 nw = vec3(0.0, 1.0, 0.0);
	float n = pincelada(vw, nw);
	float m, mol, q; vec3 dl;
	pavio(vw, n, m, mol, dl, q);
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 right = normalize((INV_VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	float ref = listra(pavio_0, vw, cam, right) + listra(pavio_1, vw, cam, right) + listra(pavio_2, vw, cam, right) + listra(pavio_3, vw, cam, right)
		+ listra(pavio_4, vw, cam, right) + listra(pavio_5, vw, cam, right) + listra(pavio_6, vw, cam, right) + listra(pavio_7, vw, cam, right);
	ref = clamp(ref, 0.0, 1.0);
	// pinceladas horizontais de água
	float st = step(0.55, pinc2(vw.xz * vec2(1.0, 3.0), 0.0));
	// poça na luz: espelho do céu do crepúsculo (malva) escurecido, mais quente perto do fogo, nunca buraco preto
	float rq = smoothstep(0.0, 1.0, q);
	vec3 ceu_ref = mix(vec3(0.05, 0.045, 0.07), vec3(0.16, 0.09, 0.07), rq);
	vec3 pint = ceu_ref * (0.85 + 0.3 * st) + vec3(0.04, 0.022, 0.012) * st * rq;
	pint = mix(pint, C_SEBO * 1.1, step(0.5, ref + (n - 0.5) * 0.4) * 0.85);
	pint = mix(pint, C_AMBAR * 0.9, step(0.15, ref) * step(ref + (n - 0.5) * 0.4, 0.5) * 0.6);
	// anéis de chuva (só se veem na luz)
	vec2 cell = floor(vw.xz * 1.6);
	float ph = fract(tempo * 1.3 + h21(cell));
	vec2 cc = (cell + vec2(h21(cell + 3.1), h21(cell + 7.7))) / 1.6;
	float rr = length(vw.xz - cc);
	float anel = (1.0 - smoothstep(0.012, 0.03, abs(rr - ph * 0.28))) * (1.0 - ph) * chuva;
	pint = mix(pint, C_SEBO * 0.8, anel * 0.7);
	// gravura: linhas horizontais (em relação à câmera) que fervem
	float sd = floor(ferve);
	float c = dot(vw.xz, vec2(0.0, 1.0)) * freq + (vnoise(vw.xz * vec2(0.6, 2.0) + sd * 3.3) - 0.5) * 0.8;
	float tom = 0.28 + 0.3 * step(0.6, pinc2(vw.xz * 0.5 + sd * 0.1, 0.1));
	float hl = linha(c, tom);
	vec3 dist = mix(C_FUNDO * 1.1, C_NOITE * 1.6, smoothstep(18.0, 60.0, length(vw - cam)));
	vec3 grav = mix(dist, C_LINHA * 0.9, hl * (1.0 - smoothstep(20.0, 48.0, length(vw - cam))));
	grav = mix(grav, C_LINHA * 0.6, step(0.45, ref) * 0.0);
	ALBEDO = mix(grav, pint, m);
	ALBEDO = saida(ALBEDO);
}
