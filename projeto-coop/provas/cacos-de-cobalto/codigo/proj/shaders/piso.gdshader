// Piso de azulejo estampilhado. Junta corrida a oeste, amarração (colunas desencontradas) a leste,
// soleira de corda no meio. Rejunte de verdade entre as peças; cada azulejo tem variante, erro de
// assentamento e inclinação do esmalte própria. Estados do chão por forma (não só cor):
// molhado = escurece + ondulação + brilho; untado = borda furta-cor; queimado = craquelado;
// salitre = grão fosco; choque = rejunte aceso (Condução correndo pelas juntas).
shader_type spatial;
render_mode cull_back;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D state : filter_linear, repeat_disable;     // R molhado, G óleo, B queimado, A salitre (por azulejo)
uniform sampler2D shock : filter_nearest, repeat_disable;    // R junta vertical, G junta horizontal (chegada), B trilha principal
uniform vec4 state_rect = vec4(-9.0, -6.0, 18.0, 12.0);      // x0, z0, largura, profundidade (m)
uniform vec2 shock_size = vec2(73.0, 97.0);
uniform float T = 0.25;          // lado do azulejo (m)
uniform float grout = 0.011;     // largura do rejunte (m)
uniform float bond_x = -0.75;    // a leste daqui: amarração
uniform float rope_x0 = -1.0;    // coluna da soleira de corda
uniform float time = 0.0;
uniform float shock_t = -10.0;   // tempo desde o início da Condução (s)
uniform float shock_dt = 0.01;   // s por nível do canal de chegada
uniform vec3 shadow_tint : source_color = vec3(0.47, 0.54, 0.80);
uniform vec3 rejunte : source_color = vec3(0.678, 0.647, 0.584);
uniform vec3 cal_col : source_color = vec3(0.247, 0.612, 0.502);
uniform vec3 base_col : source_color = vec3(0.937, 0.914, 0.863);   // estanho: o padrão do chão é misturado a ele
uniform float pat_mix = 0.5;      // 0,45 a 0,55: o padrão do piso fica entre 0,75 e 0,9 de valor
uniform float pat_far = 0.72;     // mistura no fundo (esmaece com a profundidade)
uniform vec3 ink : source_color = vec3(0.114, 0.153, 0.333);
uniform vec3 chalk : source_color = vec3(0.965, 0.955, 0.93);
uniform vec3 oleo_col : source_color = vec3(0.435, 0.251, 0.169);
uniform vec3 faisca : source_color = vec3(0.953, 0.776, 0.192);
uniform vec3 sky_col : source_color = vec3(0.80, 0.86, 1.0);
uniform float sheen = 0.10;
uniform float glow_str = 3.0;
uniform float far_fade = 30.0;
uniform vec3 quay = vec3(-6.4, 0.55, 0.0);   // água onde x < quay.x + quay.y * z

varying vec3 wpos;
varying float v_spec;
varying vec3 v_tiltn;
varying float v_wet;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.55 + vn(p * 2.1) * 0.3 + vn(p * 4.3) * 0.15; }
vec2 vor(vec2 p) { // distância à borda da célula de Voronoi (craquelado)
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = vec2(hash(i + g), hash(i + g + 17.0));
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return vec2(d1, d2 - d1);
}
vec3 fix_lin(vec3 c) { return c; }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// lê a chegada do choque de um segmento de junta; devolve (chegada em s, trilha principal)
vec2 shock_at(ivec2 texel, int ch) {
	if (texel.x < 0 || texel.y < 0 || texel.x >= int(shock_size.x) || texel.y >= int(shock_size.y)) return vec2(99.0, 0.0);
	vec4 s = texelFetch(shock, texel, 0);
	float v = ch == 0 ? s.r : s.g;
	if (v > 0.995) return vec2(99.0, 0.0);
	return vec2(v * 255.0 * shock_dt, ch == 0 ? s.b : s.a);
}

void fragment() {
	vec2 p = wpos.xz;
	if (p.x < quay.x + quay.y * p.y) discard;
	// ---------------- coordenadas do azulejo (assentamento)
	float ci = floor(p.x / T);
	bool east = p.x >= bond_x;
	bool rope = p.x >= rope_x0 && p.x < bond_x;
	float zoff = (east && mod(ci, 2.0) > 0.5) ? 0.5 * T : 0.0;
	float cj = floor((p.y - zoff) / T);
	vec2 tid = vec2(ci, cj);
	vec2 uv = vec2(p.x / T - ci, (p.y - zoff) / T - cj);
	// erro de assentamento: ±1 mm e ±0,8°
	float h1 = hash(tid), h2 = hash(tid + 7.3), h3 = hash(tid + 3.1);
	vec2 c = uv - 0.5;
	float ang = (h1 - 0.5) * 0.028;
	c = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * c + (vec2(h2, h3) - 0.5) * (0.002 / T);
	uv = c + 0.5;
	// rejunte
	float gw = grout / T * 0.5;
	vec2 dd = min(uv, 1.0 - uv);
	float dg = min(dd.x, dd.y);
	float gm = 1.0 - smoothstep(gw * 0.75, gw * 1.35, dg + (fbm(p * 90.0) - 0.5) * gw * 0.5);
	// ---------------- cor do azulejo
	float var = floor(h1 * 6.0);
	vec2 cell = vec2(mod(var, 4.0), floor(var / 4.0));
	vec2 tuv = clamp(uv, 0.004, 0.996);
	if (rope) { cell = vec2(2.0 + mod(cj, 2.0), 1.0); tuv = vec2(tuv.y, 1.0 - tuv.x); }
	vec3 tile = texture(atlas, (cell + tuv) / vec2(4.0, 2.0)).rgb;
	tile *= 0.97 + 0.05 * h2;      // espessura do esmalte varia por peça
	// o chão é palco: padrão misturado ao estanho (valor alto, pouco contraste) e mais ainda ao fundo
	vec3 camw = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float depthf = smoothstep(9.0, 20.0, length(wpos - camw));
	tile = mix(tile, base_col, mix(pat_mix, pat_far, depthf));
	vec3 col = mix(tile, mix(rejunte, base_col, 0.25) * (0.92 + 0.12 * vn(p * 40.0)), gm);
	float spec = (1.0 - gm) * 1.0;
	// ---------------- estados
	vec2 suv = (p - state_rect.xy) / state_rect.zw;
	vec4 st = texture(state, suv);
	float nwet = fbm(p * 2.3) * 0.5 + fbm(p * 9.0) * 0.25;
	float wet = smoothstep(0.42, 0.47, st.r + (nwet - 0.4) * 0.35 + gm * 0.12);   // a água corre antes pelo rejunte
	float wet_edge = smoothstep(0.36, 0.42, st.r + (nwet - 0.4) * 0.35 + gm * 0.12) - wet;
	// queimado: fuligem + craquelado
	float burn = smoothstep(0.35, 0.6, st.b + (fbm(p * 3.0) - 0.5) * 0.4);
	if (burn > 0.0) {
		vec2 v = vor(p * 26.0 + vec2(h1, h2));
		float crack = 1.0 - smoothstep(0.02, 0.06, v.y);
		vec3 soot = mix(col * 0.62, vec3(0.20, 0.15, 0.13), 0.35 * smoothstep(0.4, 0.9, fbm(p * 5.0)));
		soot = mix(soot, vec3(0.16, 0.11, 0.10), crack * 0.85);
		col = mix(col, soot, burn);
		spec *= 1.0 - burn * 0.8;
	}
	// salitre: crosta granulada e fosca
	float salt = smoothstep(0.4, 0.55, st.a + (fbm(p * 4.0) - 0.5) * 0.5);
	if (salt > 0.0) {
		float g1 = vn(p * 160.0), g2 = vn(p * 55.0);
		float grain = step(0.5, g1 * 0.6 + g2 * 0.4);
		vec3 sc = mix(vec3(0.824, 0.820, 0.784), vec3(0.62, 0.61, 0.57), grain * 0.6);
		col = mix(col, sc, salt * (0.75 + 0.25 * step(0.35, g2)));
		spec *= 1.0 - salt;
	}
	// óleo: mancha castanha com borda furta-cor
	float oil = smoothstep(0.45, 0.5, st.g + (fbm(p * 3.5) - 0.5) * 0.3);
	float oil_e = smoothstep(0.38, 0.45, st.g + (fbm(p * 3.5) - 0.5) * 0.3) - oil;
	if (oil + oil_e > 0.0) {
		col = mix(col, mix(col * 0.55, oleo_col, 0.55), oil);
		float hh = fract(fbm(p * 6.0) * 2.0 + p.x * 0.7);
		vec3 ir = 0.55 + 0.45 * cos(6.2831 * (hh + vec3(0.0, 0.33, 0.67)));
		col = mix(col, ir * 0.9, oil_e * 0.85);
	}
	// molhado (cal): sem camada colorida. O próprio esmalte escurece 15% e fica espelhado (roughness
	// 0,1 e SSR no Forward+); a borda é uma linha de tinta ondulada com franja de cal branca por fora.
	float wv = st.r + (nwet - 0.4) * 0.35 + gm * 0.12;
	float edge_ink = smoothstep(0.405, 0.42, wv) - smoothstep(0.43, 0.445, wv);
	float fringe = (smoothstep(0.33, 0.37, wv) - smoothstep(0.405, 0.42, wv)) * step(0.42, vn(p * 70.0) * 0.6 + vn(p * 22.0) * 0.6);
	wet = smoothstep(0.43, 0.445, wv);
	if (wet + edge_ink + fringe > 0.0) {
		vec3 wc = mix(col * 0.80, vec3(0.663, 0.733, 0.867) * 0.8, 0.12);   // escurece ~20% e puxa para o céu (cobalto aguado), nunca verde
		float rip = sin(length(p - vec2(-1.2, -2.2)) * 26.0 - time * 3.0 + fbm(p * 3.0) * 6.0);
		float ripl = smoothstep(0.95, 0.99, rip) * (0.5 + 0.5 * fbm(p * 1.5 + time * 0.1));
		wc = mix(wc, chalk, ripl * 0.35);
		col = mix(col, wc, wet);
		col = mix(col, chalk, fringe * 0.95);
		col = mix(col, ink, edge_ink * 0.85);
		spec = max(spec, wet * 1.6);
	}
	v_wet = wet;
	// ---------------- choque pelo rejunte
	vec3 glow = vec3(0.0);
	if (shock_t > -1.0) {
		// junta vertical mais próxima
		float xv = floor(p.x / T + 0.5);
		float dxv = abs(p.x - xv * T);
		float kv = floor(p.y / (T * 0.5));
		vec2 sv = shock_at(ivec2(int(xv) + 36, int(kv) + 48), 0);
		// junta horizontal mais próxima (na coluna deste azulejo)
		float zh = (floor((p.y - zoff) / T + 0.5)) * T + zoff;
		float dzh = abs(p.y - zh);
		float kh = floor(zh / (T * 0.5) + 0.5);
		vec2 shv = shock_at(ivec2(int(ci) + 36, int(kh) + 48), 1);
		float best = 0.0;
		for (int k = 0; k < 2; k++) {
			vec2 sa = k == 0 ? sv : shv;
			float d = k == 0 ? dxv : dzh;
			float along = k == 0 ? p.y : p.x;
			float age = shock_t - sa.x;
			if (age < 0.0 || sa.x > 50.0) continue;
			float main = sa.y;
			// o raio serpenteia dentro e em volta da junta (quadros de raio a 30 por segundo)
			float tq = floor(time * 30.0);
			float wig = (vn(vec2(along * 38.0, tq * 1.7)) - 0.5) * 0.022 * (0.5 + main);
			float dl = abs(d - wig);
			float life = exp(-age * mix(9.0, 4.0, main));
			float head = smoothstep(0.08, 0.0, age);
			float core = 1.0 - smoothstep(0.003 + 0.003 * main, 0.007 + 0.004 * main, dl);
			float halo = 1.0 - smoothstep(0.006, 0.035 + 0.035 * main, dl);
			float lit = core * (0.3 + 0.7 * main) * max(life, head) + halo * 0.45 * life * (0.12 + 0.88 * main) + head * halo * 0.5 * (0.3 + 0.7 * main);
			best = max(best, lit);
		}
		glow = mix(faisca, vec3(1.0, 0.97, 0.85), smoothstep(0.7, 1.2, best)) * best;
		// a área molhada inteira ganha brilho enquanto a corrente passa
		col = mix(col, col + faisca * 0.10, wet * smoothstep(-0.05, 0.1, shock_t) * exp(-max(shock_t, 0.0) * 1.5));
	}
	ALBEDO = col;
	EMISSION = glow * glow_str;
	v_spec = spec;
	// inclinação do esmalte por peça (até 1,5°)
	v_tiltn = normalize(vec3((h2 - 0.5) * 0.05, 1.0, (h3 - 0.5) * 0.05));
	NORMAL = normalize((VIEW_MATRIX * vec4(v_tiltn, 0.0)).xyz);
	// reflexo do céu no esmalte, por peça: o mosaico de brilhos (some com a distância)
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float dist = length(wpos - (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	float fade = 1.0 - smoothstep(far_fade * 0.6, far_fade, dist);
	EMISSION += sky_col * (sheen * (0.4 + 1.2 * hash(tid + 1.7)) * (0.3 + fres) * spec * fade + v_wet * 0.07 * (0.3 + fres * 2.0));
	ROUGHNESS = mix(1.0, 0.06, v_wet);   // o reflexo dos personagens vem da película reflexo.gdshader
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float sh = smoothstep(0.35, 0.65, ATTENUATION);
	float lit = smoothstep(-0.02, 0.02, ndl) * sh;
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), lit) * LIGHT_COLOR / PI;
	vec3 H = normalize(VIEW + LIGHT);
	float s = smoothstep(0.9965, 0.998, dot(NORMAL, H)) * lit * v_spec;
	SPECULAR_LIGHT += s * 0.8 * LIGHT_COLOR / PI;
}
