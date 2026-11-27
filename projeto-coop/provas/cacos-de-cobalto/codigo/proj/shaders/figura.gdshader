// Figura de faiança: atlas pintado, toon de 2 degraus por light(), sombra = multiplicar por cobalto,
// brilho do esmalte como decalque de janela (4 vidraças, limiar duro, segue a normal), rim de cor
// única na cor do jogador só no lado oposto à luz, peça de vidrado na cor do jogador (região do
// atlas trocada aqui), rosto de 3 traços desenhado aqui, untado = esmalte molhado (janela maior e
// filete âmbar duro), negativo amarelo da Condução, lampejo de golpe e borda vermelho-lacre da
// telegrafia (só no miolo de terracota dos inimigos).
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 shadow_tint : source_color = vec3(0.47, 0.54, 0.80);
uniform float band = 0.0;
uniform float soft = 0.012;
uniform float spec_w = 0.12;      // meia largura da janela de brilho (unidades de normal)
uniform float spec_str = 0.85;
uniform float rim_str = 0.0;       // heróis: 1 (rim na cor do jogador); inimigos: 0
// jogador: cor numa peça grande de vidrado (até 2 regiões do atlas) e no rim
uniform vec3 player_col : source_color = vec3(1.0);
uniform vec4 player_rect0 = vec4(-1.0);
uniform vec4 player_rect1 = vec4(-1.0);
uniform vec2 player_mode = vec2(0.0);   // 0: branco vira a cor (traço escurece); 1: azul-noite vira a cor
uniform vec3 oil_col : source_color = vec3(0.86, 0.58, 0.22);
// rosto
uniform vec4 face_rect = vec4(-1.0);   // u0, v0, u1, v1 da região da cabeça no atlas
uniform vec2 face_size = vec2(1.0, 0.35); // circunferência e altura da cabeça (m)
uniform float t_eyes = 0.45;
uniform float t_mouth = 0.70;
uniform float eye_gap = 0.075;
uniform float eye_w = 0.024;
uniform float eye_h = 0.034;
uniform float eye_open = 1.0;
uniform float eye_tilt = 0.0;
uniform float brow = 0.0;
uniform float mouth_w = 0.05;
uniform float mouth_curve = 0.4;
uniform float mouth_open = 0.0;
uniform vec2 look = vec2(0.0);
uniform vec3 face_ink : source_color = vec3(0.114, 0.153, 0.333);
// estados
uniform float oil = 0.0;
uniform float invert = 0.0;
uniform float flash = 0.0;
uniform float lacre = 0.0;
uniform float lacre_mat = 0.25;   // material que acende (0,25 biscoito; 0,5 salitre)
uniform vec3 lacre_col : source_color = vec3(0.769, 0.125, 0.212);
uniform vec3 neg_col : source_color = vec3(0.953, 0.776, 0.192);
uniform float emit_str = 1.6;
uniform float time = 0.0;

varying float v_spec;
varying float v_lit_boost;
varying float v_oil;

vec3 fix_vc(vec3 vc) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return mix(vc * 12.92, 1.055 * pow(vc, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), vc));
#else
	return vc;
#endif
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// cobertura (0..1) dos 3 traços em coordenadas métricas do rosto
float face_ink_amt(vec2 p) {
	float n = (vn(p * 900.0) - 0.5) * 0.0025;
	float ink = 0.0;
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		vec2 q = p - vec2(sx * eye_gap, 0.0);
		float a = -sx * eye_tilt * 0.5;
		q = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * q;
		if (eye_open > 0.22) {
			vec2 e = q / vec2(eye_w, eye_h * eye_open);
			float d = length(e) - 1.0;
			float body = 1.0 - smoothstep(-0.05, 0.08, d + n * 30.0);
			// brilho de reserva (pupila clara) desloca com o olhar
			vec2 hl = (q - vec2(eye_w * 0.25 + look.x * eye_w * 0.4, -eye_h * eye_open * 0.35 + look.y * eye_h * 0.3)) / (eye_w * 0.36);
			body *= smoothstep(0.85, 1.15, length(hl));
			ink = max(ink, body);
		} else {
			// olho fechado: arco (alegria/esforço) de pincel
			float y = q.y + (q.x * q.x) / eye_w * 0.9 * (eye_open < 0.1 ? 1.0 : -1.0) - eye_h * 0.1;
			float th = eye_h * 0.28 * (1.0 - smoothstep(0.6, 1.25, abs(q.x) / eye_w));
			ink = max(ink, (1.0 - smoothstep(th * 0.7, th * 1.2, abs(y) + n * 10.0)) * step(abs(q.x), eye_w * 1.3));
		}
		// sobrancelha: traço curto acima do olho
		if (abs(brow) > 0.01) {
			vec2 b = q - vec2(0.0, -eye_h * 1.55);
			float yb = b.y + sx * brow * b.x * 0.7;
			float thb = eye_h * 0.2 * (1.0 - smoothstep(0.5, 1.0, abs(b.x) / (eye_w * 1.3)));
			ink = max(ink, (1.0 - smoothstep(thb * 0.6, thb * 1.2, abs(yb))) * step(abs(b.x), eye_w * 1.35));
		}
	}
	// boca: arco com curva e abertura
	vec2 m = p - vec2(0.0, (t_mouth - t_eyes) * face_size.y);
	float u = m.x / mouth_w;
	if (abs(u) < 1.15) {
		float yc = -mouth_curve * (1.0 - u * u) * mouth_w * 0.35;
		float th = mouth_w * 0.10 * (1.0 - smoothstep(0.7, 1.15, abs(u)));
		float line = 1.0 - smoothstep(th * 0.6, th * 1.2, abs(m.y - yc) + n * 8.0);
		float openf = 0.0;
		if (mouth_open > 0.01) {
			float lo = yc + mouth_open * mouth_w * 0.9 * max(0.0, 1.0 - u * u);
			openf = step(yc, m.y) * step(m.y, lo) * step(abs(u), 1.0);
		}
		ink = max(ink, max(line, openf));
	}
	return clamp(ink, 0.0, 1.0);
}

void fragment() {
	vec4 vc = vec4(fix_vc(COLOR.rgb), COLOR.a);
	vec3 c = texture(atlas, UV).rgb;
	// rosto
	if (face_rect.x >= 0.0 && UV.x > face_rect.x && UV.x < face_rect.z && UV.y > face_rect.y && UV.y < face_rect.w) {
		vec2 st = (UV - face_rect.xy) / (face_rect.zw - face_rect.xy);
		vec2 p = vec2((st.x - 0.5) * face_size.x, (st.y - t_eyes) * face_size.y);
		c = mix(c, face_ink, face_ink_amt(p));
	}
	// peça de vidrado na cor do jogador
	for (int k = 0; k < 2; k++) {
		vec4 r = k == 0 ? player_rect0 : player_rect1;
		if (r.x >= 0.0 && UV.x > r.x && UV.x < r.z && UV.y > r.y && UV.y < r.w) {
			float l = dot(c, vec3(0.299, 0.587, 0.114));
			float md = k == 0 ? player_mode.x : player_mode.y;
			vec3 dark = player_col * 0.38;
			vec3 lite = mix(player_col, vec3(1.0), 0.6);
			c = md < 0.5 ? mix(dark, player_col, smoothstep(0.15, 0.7, l)) : mix(player_col, lite, smoothstep(0.35, 0.8, l));
		}
	}
	float mat = vc.g;
	// borda vermelho-lacre (telegrafia) só no biscoito
	float is_bisque = smoothstep(0.08, 0.04, abs(mat - lacre_mat));
	c = mix(c, lacre_col, lacre * is_bisque);
	EMISSION = lacre_col * lacre * is_bisque * 0.6;
	// negativo amarelo (Condução): o escuro vira antimônio, o claro vira azul-noite
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 neg = mix(neg_col * 1.05, vec3(0.10, 0.12, 0.30), smoothstep(0.25, 0.75, lum));
	c = mix(c, neg, invert);
	c = mix(c, vec3(0.93, 0.90, 0.84), flash);
	ALBEDO = c;
	EMISSION += c * vc.b * emit_str + neg_col * invert * 0.35;
	v_spec = vc.r * (1.0 - invert);
	v_lit_boost = invert + flash;
	v_oil = oil;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float sh = smoothstep(0.35, 0.65, ATTENUATION);
	float lit = smoothstep(band - soft, band + soft, ndl) * sh;
	lit = max(lit, v_lit_boost);
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), lit) * LIGHT_COLOR / PI;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// rim de cor única, corte duro, só do lado oposto à luz
	float away = 1.0 - smoothstep(-0.05, 0.05, ndl);
	float rim = smoothstep(0.685, 0.71, fres) * away;
	SPECULAR_LIGHT += rim * player_col * rim_str * 0.85 * LIGHT_COLOR;
	// brilho do esmalte: decalque de janela de 4 vidraças que segue a normal (limiar duro)
	vec3 H = normalize(VIEW + LIGHT);
	vec3 d = NORMAL - H;
	float ww = spec_w * (1.0 + 0.6 * clamp(v_oil, 0.0, 1.0));
	vec2 q = d.xy / vec2(ww, ww * 1.35);
	float win = step(max(abs(q.x), abs(q.y)), 1.0) * step(0.16, abs(q.x)) * step(0.16, abs(q.y)) * step(0.0, dot(NORMAL, H));
	float sp = max(v_spec, clamp(v_oil, 0.0, 1.0));
	SPECULAR_LIGHT += win * lit * sp * spec_str * (1.0 + 0.6 * clamp(v_oil, 0.0, 1.0)) * LIGHT_COLOR / PI;
	// untado: filete âmbar duro na borda iluminada (o óleo escorrendo no esmalte)
	float oilrim = smoothstep(0.66, 0.69, fres) * (1.0 - away) * clamp(v_oil, 0.0, 2.0);
	SPECULAR_LIGHT += oilrim * oil_col * 0.9 * LIGHT_COLOR;
}
