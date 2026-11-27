// mini_pintada: miniatura de chumbo pintada em acrílica fosca. A luz está na tinta (assada no Blender):
// cor de base chapada, lavagem de 35 a 50% nos vãos (oclusão em UV2.x), luz zenital +12% nas faces de cima,
// luz de aresta +30% de valor nas convexas (curvatura em UV2.y), metal pintado como metal (degradê céu-chão,
// sem reflexo), brilho pintado (cor de vértice), sem especular. A luz real do motor soma no máximo ±20%.
// Lascas: a tinta quebra e mostra o chumbo conforme o dano; desbotar: a cor escorre e fica o primer.
shader_type spatial;
render_mode specular_disabled, diffuse_lambert, ambient_light_disabled, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform float metal = 0.0;
uniform float heroi = 0.0;
uniform float dano = 0.0;          // 0 inteiro .. 1 todo lascado
uniform float pintura = 1.0;       // 1 pintado .. 0 primer (desbotado)
uniform float real_k = 0.2;        // peso da luz real do motor
uniform vec3 tinta_quente : source_color = vec3(0.141, 0.094, 0.059);
uniform vec3 tinta_fria : source_color = vec3(0.078, 0.11, 0.169);
uniform vec3 chumbo : source_color = vec3(0.604, 0.627, 0.659);
uniform vec3 primer : source_color = vec3(0.549, 0.541, 0.525);
uniform vec3 borda_quente : source_color = vec3(1.0, 0.72, 0.4);
uniform float tom = 1.0;
uniform float piso = 0.0;          // valor mínimo (piso de 35% nos heróis)
uniform vec4 tingir = vec4(0.0);   // rgb + força: pincelada de matéria (âmbar do Visgo) ou clarão
uniform float lavagem = 0.62;
uniform float aresta = 1.0;
uniform float atmos_on = 1.0;
uniform float rim_frio = 0.0;      // inimigos: luz de aresta fria pintada (contorno claro contra o chão escuro)
uniform vec3 cor_rim : source_color = vec3(0.5, 0.68, 0.78);
global uniform float dbg;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = VERTEX;
	wn = NORMAL;
}
vec3 sat(vec3 c, float s) { return mix(vec3(luma(c)), c, s); }
void fragment() {
	vec3 base = vc(COLOR.rgb) * tom;
	base = mix(vec3(luma(base)), base, 1.12);   // acrílica: cor chapada um pouco mais saturada
	float ao = UV2.x;
	float cv = 1.0 - UV2.y;          // o glTF inverte o V
	float hgt = 1.0 - UV.y;
	vec3 n = normalize(wn);
	// 1) lavagem nos vãos, na tinta da zona (sépia nos quentes, azul-negro nos frios)
	float quente = step(base.b, base.r);
	vec3 ink = mix(tinta_fria, tinta_quente, quente);
	float w = 1.0 - smoothstep(0.72, 0.99, ao);
	vec3 P = mix(base, ink * 0.7 + base * 0.2, w * lavagem * 1.1);
	// 2) luz zenital: a luz vem de cima, sempre
	float up = smoothstep(0.25, 0.85, n.y);
	float dn = smoothstep(-0.15, -0.75, n.y);
	// camadas do pintor: sombra (-25% embaixo, fria), base, luz de cima (+12%)
	P *= 0.8 + 0.34 * smoothstep(-0.6, 0.85, n.y);
	P = mix(P, P * vec3(0.82, 0.86, 1.0), dn * 0.6);
	// pincelada: variação fosca da tinta, presa ao modelo
	P *= 0.95 + 0.1 * UV.x;
	// 3) metal pintado como metal (metal não metálico): degradê de céu e chão pelo reflexo, em faixas
	if (metal > 0.5) {
		vec3 V = normalize(CAMERA_POSITION_WORLD - wp);
		vec3 r = reflect(-V, n);
		float t = r.y;
		float b = t > 0.55 ? 1.55 : (t > 0.15 ? 1.05 : (t > -0.25 ? 0.42 : 0.75));
		P = sat(base, 0.8) * b;
		P = mix(P, vec3(0.95, 0.93, 0.88), smoothstep(0.86, 0.93, t) * 0.8);
		P = mix(P, ink * 0.5, w * 0.6);
	}
	// 4) luz de aresta: linha clara (+30% de valor, -20% de saturação) nas convexas, mais forte nas de cima
	float ed = smoothstep(0.55, 1.1, cv) * (0.55 + 0.45 * clamp(n.y + 0.4, 0.0, 1.0)) * aresta;
	P = mix(P, sat(P, 0.8) * 1.38 + 0.03, ed);
	// leve degradê de altura da miniatura (os pés mais escuros, como na pintura)
	P *= mix(0.9, 1.04, clamp(hgt * 1.3, 0.0, 1.0));
	// 5) lascas: a tinta quebra (borda escura) e mostra o chumbo pintado
	if (dano > 0.0) {
		float ch = UV.x;
		float th = 1.0 - dano * 0.75;
		float m = smoothstep(th - 0.015, th + 0.015, ch);
		float rim = smoothstep(th - 0.07, th - 0.02, ch) * (1.0 - m);
		vec3 lead = chumbo * (0.75 + 0.35 * up + 0.3 * ed);
		P = mix(P, P * 0.45, rim * 0.8);
		P = mix(P, lead, m);
	}
	// 6) desbotar: a cor escorre de cima para baixo em pinceladas e sobra o primer
	if (pintura < 1.0) {
		float stroke = vnoise(vec2(wp.x * 9.0 + wp.z * 7.0, 0.5) * 2.0) * 0.18;
		float m = step(1.0 - hgt - stroke, pintura * 1.2 - 0.1);
		vec3 pr = primer * (0.8 + 0.15 * up + 0.25 * ed) * mix(0.75, 1.0, 1.0 - w);
		P = mix(pr, P, m);
	}
	// 7) pincelada de matéria por cima (resina, cal): cobre com brilho pintado
	P = mix(P, tingir.rgb * (0.9 + 0.3 * up), tingir.a * (0.35 + 0.65 * smoothstep(0.3, 0.7, vnoise(wp.xz * 18.0 + wp.y * 9.0))));
	// piso de valor: o herói nunca afunda no escuro
	P = max(P, P / max(luma(P), 0.001) * piso * step(0.0005, luma(P)));
	P = clarao(P, wp, n);
	// borda quente sem sombra (heróis): luz própria
	vec3 V = normalize(CAMERA_POSITION_WORLD - wp);
	float fr = pow(1.0 - clamp(dot(n, V), 0.0, 1.0), 3.0);
	P += borda_quente * fr * 0.07 * heroi;
	// aresta fria dos inimigos: faixa recortada (sem degradê), mais forte nas faces de cima
	float rimf = smoothstep(0.6, 0.66, 1.0 - clamp(dot(n, V), 0.0, 1.0)) * (0.55 + 0.45 * clamp(n.y + 0.5, 0.0, 1.0));
	P = mix(P, cor_rim * (0.75 + 0.25 * up), rimf * rim_frio * 0.55);
	vec4 f = atmos_on > 0.5 ? atmos_k(wp, CAMERA_POSITION_WORLD) : vec4(0.0);
	ALBEDO = saida(P * real_k * (1.0 - f.a));
	EMISSION = saida(mix(P * (1.0 - real_k), f.rgb, f.a));
	if (dbg > 0.5) { ALBEDO = vec3(0.0); EMISSION = dbg < 1.5 ? vec3(ao) : vec3(max(cv,0.0), max(-cv,0.0), hgt); }
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += min(LIGHT_COLOR / PI * ATTENUATION * (0.35 + 0.65 * nl), vec3(1.0));
}
