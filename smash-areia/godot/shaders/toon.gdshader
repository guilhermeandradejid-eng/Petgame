// Toon pintado no estilo de aventura fofa (chibi): luz e sombra com transição
// macia, sombra colorida, luz de céu e rebote da areia, contorno de luz claro,
// vento opcional e névoa azul de distância.
// Unshaded: fica igual em qualquer celular e custa pouco.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
#include "res://shaders/lighting.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.55, 0.45, 0.75, 1.0);
uniform float rim_amount = 0.35;
uniform float spec_amount = 0.0;
uniform float halftone = 1.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float wind = 0.0;
uniform float fog = 1.0;
uniform float bg = 0.0;     // cenário: menos contraste e um véu lilás (o foco fica na quadra)

const vec3 KEY = vec3(-0.45, 0.72, 0.53);      // luz principal (frente-esquerda)
const vec3 SUN_BACK = vec3(-0.55, 0.35, -0.76); // sol baixo atrás da quadra (contraluz)
const vec3 HAZE = vec3(1.0, 0.84, 0.72);

void vertex() {
	if (wind > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float h = max(VERTEX.y - 2.0, 0.0);
		VERTEX.x += sin(TIME * 1.6 + wp.x * 0.3 + wp.z * 0.2) * wind * h * 0.06;
		VERTEX.z += cos(TIME * 1.3 + wp.x * 0.2) * wind * h * 0.04;
	}
}

void fragment() {
	vec3 base = albedo.rgb * COLOR.rgb;
	vec3 L = normalize((VIEW_MATRIX * vec4(normalize(KEY), 0.0)).xyz);
	vec3 UPV = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float ndl = dot(NORMAL, L);
	// estilo "aventura fofa" (toon pintado): duas faixas com transição macia,
	// sombra colorida e quente, luz do céu por cima e rebote da areia por baixo.
	// Nada de retícula nem de brilho de plástico.
	float aa = max(fwidth(ndl), 0.002);
	float lit = smoothstep(-0.07 - aa, 0.07 + aa, ndl - 0.0);
	float hi = smoothstep(0.5, 0.78, ndl);
	vec3 shadow_col = base * mix(shadow_tint.rgb, vec3(0.78, 0.66, 0.86), 0.35);
	vec3 col = mix(shadow_col, base * (1.0 + 0.06 * hi), lit);
	// céu (azul claro) nas faces de cima e rebote quente da areia nas de baixo
	float up = dot(NORMAL, UPV);
	col += base * vec3(0.05, 0.08, 0.14) * clamp(up, 0.0, 1.0) * (1.0 - bg * 0.5);
	col += base * vec3(0.16, 0.1, 0.03) * clamp(-up, 0.0, 1.0) * (1.0 - lit * 0.6) * (1.0 - bg);
	// "halftone" agora vira só uma sombra de oclusão macia (sem pontinhos)
	col *= 1.0 - clamp(-ndl - 0.35, 0.0, 1.0) * 0.18 * halftone;

	// contorno de luz (rim) macio e claro: destaca a silhueta sem traço preto
	vec3 S = normalize((VIEW_MATRIX * vec4(normalize(SUN_BACK), 0.0)).xyz);
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.5, 0.82, fres) * (0.45 + 0.55 * smoothstep(-0.3, 0.5, dot(NORMAL, S)));
	col = mix(col, col * 0.55 + vec3(1.0, 0.93, 0.78) * 0.5, rim * rim_amount);

	vec3 H = normalize(L + VIEW);
	// brilho pintado (cabelo, olhos): mancha recortada, só onde for pedido
	float sh = dot(NORMAL, H);
	col = mix(col, col + vec3(0.4), smoothstep(0.978 - aa * 4.0, 0.978 + aa * 4.0, sh) * spec_amount * lit * 0.8);

	col = mix(col, flash_color.rgb, flash);
	col = mix(col, vec3(0.84, 0.92, 1.0) * (0.8 + 0.2 * lit), bg * 0.12);   // véu azul leve: profundidade de ar
	float dist = length(VERTEX);
	col = mix(col, night_haze(HAZE), smoothstep(45.0, 380.0, dist) * 0.85 * fog);
	ALBEDO = night_grade(col, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
