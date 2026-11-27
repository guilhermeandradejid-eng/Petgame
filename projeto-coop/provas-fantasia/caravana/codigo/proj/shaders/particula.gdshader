// Partículas no ar: chuva (riscos dourados só dentro da luz), brasa (nasce no fogo, sobe com ruído, apaga fora da
// luz), fumaça (partícula macia com erosão de alfa pela vida, fuligem fria com borda quente onde a chama ilumina,
// opacidade máx. 0,6, some perto dos heróis e da câmera; no PC, depth fade), gota de tinta da frente, mariposa e
// vaga-lume frio. Billboard e curvatura do mundo. INSTANCE_CUSTOM: x = vida 0..1, y = semente, z = brilho.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;
#include "res://shaders/comum.gdshaderinc"
uniform int tipo = 0;        // 0 chuva, 1 brasa, 2 fumaça, 3 gota de tinta, 4 mariposa, 5 vaga-lume
uniform float energia = 1.0;
uniform float tempo = 0.0;
uniform vec4 evita_0 = vec4(0.0, -99.0, 0.0, 0.0);
uniform vec4 evita_1 = vec4(0.0, -99.0, 0.0, 0.0);
uniform vec4 evita_2 = vec4(0.0, -99.0, 0.0, 0.0);
uniform vec4 evita_3 = vec4(0.0, -99.0, 0.0, 0.0);
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
uniform sampler2D prof_tela : hint_depth_texture, filter_nearest;
#endif
varying vec3 vw;
varying float vrand;
varying vec4 vcust;
varying float vz;
void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 right = normalize((INV_VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	vec3 up = tipo == 0 ? normalize(vec3(vento.x * 0.45, -1.0, vento.y * 0.45)) * -1.0 : normalize((INV_VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	if (tipo == 0) right = normalize(cross(up, (INV_VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz));
	float sx = length(MODEL_MATRIX[0].xyz);
	vec3 w = c + (right * VERTEX.x + up * VERTEX.y) * sx;
	w.y -= drop_curva(w);
	vw = w;
	vrand = h31(floor(c * 7.0));
	vcust = INSTANCE_CUSTOM;
	vec4 vp = VIEW_MATRIX * vec4(w, 1.0);
	vz = -vp.z;
	POSITION = PROJECTION_MATRIX * vp;
}
float evitar(vec3 w, vec4 e) {
	float d = length(w.xz - e.xz);
	return mix(0.2, 1.0, smoothstep(0.5, 1.3, d) + step(e.y + 2.4, w.y));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float m, mol, q; vec3 dl;
	pavio(vw, 0.5, m, mol, dl, q);
	vec3 col = vec3(1.0); float a = 1.0;
	if (tipo == 0) {
		a = (1.0 - smoothstep(0.2, 1.0, abs(p.x))) * smoothstep(1.0, 0.3, abs(p.y)) * m * 0.45;
		col = mix(C_AMBAR * 1.5, C_SEBO * 1.5, vrand);
	} else if (tipo == 1) {
		// brasa: núcleo quente, halo, brilho variável que cintila; apaga ao sair da luz
		float d = length(p * vec2(1.0, 0.7));
		float br = vcust.z * (0.75 + 0.25 * sin(tempo * 23.0 + vcust.y * 40.0));
		a = (1.0 - smoothstep(0.35, 0.95, d)) * (1.0 - smoothstep(0.75, 1.0, vcust.x)) * mix(0.25, 1.0, m);
		col = mix(vec3(1.6, 0.42, 0.08), vec3(2.6, 1.7, 0.7), 1.0 - smoothstep(0.1, 0.45, d)) * energia * br;
	} else if (tipo == 2) {
		// fumaça macia: forma por ruído, erosão de alfa ao longo da vida
		float life = vcust.x;
		float r = length(p);
		float n = vnoise(p * 2.2 + vcust.y * 10.0 + vec2(0.0, -life * 1.5)) * 0.6 + vnoise(p * 5.0 + vcust.y * 3.0 + vec2(life, 0.0)) * 0.4;
		float dens = (1.0 - r) * 1.25 - n * 0.55 - life * 0.5;
		a = smoothstep(0.0, 0.45, dens) * 0.6 * smoothstep(0.0, 0.12, life);
		vec3 fuligem = vec3(0.075, 0.075, 0.09);
		vec3 quente = vec3(0.55, 0.22, 0.07);
		float baixo = smoothstep(0.3, -0.8, p.y);          // a barriga da nuvem olha para a chama
		col = mix(fuligem, quente, q * baixo * 0.85 * (1.0 - life * 0.7));
		col = mix(col, fuligem * 1.6 + C_LINHA * 0.2, (1.0 - m) * 0.5);
		a *= evitar(vw, evita_0) * evitar(vw, evita_1) * evitar(vw, evita_2) * evitar(vw, evita_3);
		a *= smoothstep(3.0, 7.0, length(vw - CAMERA_POSITION_WORLD));
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
		float zd = texture(prof_tela, SCREEN_UV).r;
		vec4 vpos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
		float zcena = -vpos.z / vpos.w;
		a *= clamp((zcena - vz) / 0.8, 0.0, 1.0);
#endif
	} else if (tipo == 3) {
		float d = length(p * vec2(1.0, 0.75) + vec2(0.0, 0.2 * p.x * p.x));
		a = (1.0 - step(0.85, d)) * (1.0 - vcust.x);
		col = mix(vec3(0.7, 0.36, 0.14), vec3(0.95, 0.72, 0.42), step(d, 0.4));
	} else if (tipo == 4) {
		// mariposa: duas asas em gota batendo (passo de 12 fps)
		float bat = abs(sin(floor(vento.w * 14.0 + vrand * 20.0) * 1.3));
		vec2 qq = vec2(abs(p.x) / max(0.3, bat), p.y);
		float wing = 1.0 - step(0.0, (qq.y - 0.55 + qq.x * 0.9));
		wing *= step(-0.6, qq.y - qq.x * 0.3) * step(qq.x, 1.0);
		float body = step(abs(p.x), 0.08) * step(abs(p.y), 0.5);
		a = max(wing, body);
		col = mix(vec3(0.4, 0.36, 0.32), vec3(1.0, 0.85, 0.6), m) * mix(0.6, 1.0, wing);
		col = mix(col, vec3(0.1, 0.08, 0.06), body);
	} else {
		// vaga-lume frio da Treva: ponto verde-azulado que pisca devagar; some dentro da luz
		float d = length(p);
		float pisca = smoothstep(0.2, 0.9, sin(tempo * 1.7 + vcust.y * 30.0) * 0.5 + 0.5);
		a = (1.0 - smoothstep(0.15, 1.0, d)) * pisca * (1.0 - m);
		col = mix(vec3(0.25, 0.55, 0.6), vec3(0.7, 1.1, 1.0), 1.0 - smoothstep(0.0, 0.35, d)) * 1.2;
	}
	if (a < 0.01) discard;
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
	ALBEDO = saida(ALBEDO);
}
