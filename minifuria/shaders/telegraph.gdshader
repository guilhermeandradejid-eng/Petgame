shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Avisos no chão dos ataques de chefe (arm 0 -> 1 = tempo até o golpe).
//   mode 0  círculo de impacto. sub 0 = TREMOR (o chão racha do centro para fora), 1 = METEORO (mira com
//           colchetes girando), 2 = PULSO EMP (grade hexagonal elétrica), 3 = genérico
//   mode 1  chão em chamas (MURO DE FOGO)
//   mode 2  faixa de perigo (BOTE, BOLAS DE NEVE, BLOQUEIO, PORTÃO LASER): listras correndo + setas
//   mode 3  poça de lama borbulhando (CROCODILO)
//   mode 4  gelo liso com cristais (AVALANCHE)
// Tudo com uma sombra escura por baixo do desenho, para ler bem em neve, areia ou asfalto.
uniform vec4 col : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform float arm = 0.0;
uniform float tt = 0.0;
uniform float mode = 0.0;
uniform float sub = 3.0;
uniform vec2 size = vec2(4.0, 4.0);   // meia-largura e meio-comprimento em metros (listras sem esticar)
uniform float seed = 0.0;
uniform float life = 1.0;              // some depois do golpe

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453); }
vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))) + seed * 13.0) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}
// voronoi: x = distância ao centro da célula, y = distância à borda, z = id da célula
vec3 voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 mg;
	vec2 mr;
	float md = 8.0;
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 o = hash2(n + g);
		vec2 r = g + o - f;
		float d = dot(r, r);
		if (d < md) { md = d; mr = r; mg = g; }
	}
	float me = 8.0;
	for (int j = -2; j <= 2; j++)
	for (int i = -2; i <= 2; i++) {
		vec2 g = mg + vec2(float(i), float(j));
		vec2 o = hash2(n + g);
		vec2 r = g + o - f;
		if (dot(mr - r, mr - r) > 0.00001)
			me = min(me, dot(0.5 * (mr + r), normalize(r - mr)));
	}
	return vec3(sqrt(md), me, hash(n + mg));
}
float band(float x, float c, float w, float aa) { return smoothstep(w + aa, w, abs(x - c)); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 m = p * size;   // em metros
	float r = length(p);
	float ang = atan(p.y, p.x);
	float charging = step(arm, 0.999);
	float blink = 0.72 + 0.28 * sin(tt * (9.0 + arm * 26.0));
	vec3 c = vec3(0.0);
	float a = 0.0;
	if (mode > 3.5) {
		// ---- GELO: cristais (células com borda branca), brilho correndo e cintilado
		float edge_n = fbm(m * 0.35 + 3.0) * 0.18;
		float inside = smoothstep(1.0, 0.9, max(abs(p.x), abs(p.y)) + edge_n);
		vec3 v = voronoi(m * 0.55);
		float cracks = smoothstep(0.06, 0.0, v.y);
		float cell = 0.75 + 0.25 * v.z;
		float shine = smoothstep(0.12, 0.0, abs(fract((m.x + m.y) * 0.06 - tt * 0.35) - 0.5));
		float twinkle = step(0.985, hash(floor(m * 3.0))) * (0.5 + 0.5 * sin(tt * 9.0 + hash(floor(m * 3.0)) * 40.0));
		c = mix(vec3(0.42, 0.72, 0.95), vec3(0.85, 0.96, 1.0), cell * 0.6) + vec3(1.0) * (cracks * 0.7 + shine * 0.35 + twinkle);
		a = inside * (charging > 0.5 ? (0.25 + 0.35 * arm) * blink : 0.72);
	} else if (mode > 2.5) {
		// ---- LAMA: poça de borda irregular, marrom brilhante com bolhas que crescem e estouram
		float rr = length(m) / max(size.x, 0.001) + (fbm(m * 0.6 + 7.0) - 0.5) * 0.35;
		float inside = smoothstep(1.0, 0.86, rr);
		float rim = band(rr, 0.93, 0.05, 0.05);
		float f = fbm(m * 0.9 + vec2(tt * 0.15, -tt * 0.1));
		vec3 v = voronoi(m * 1.1 + vec2(0.0, tt * 0.05));
		float ph = fract(tt * (0.35 + v.z * 0.5) + v.z * 7.0);
		float bub = smoothstep(0.04, 0.0, abs(v.x - ph * 0.42)) * step(0.55, v.z) * (1.0 - ph);
		float gloss = smoothstep(0.55, 0.9, fbm(m * 0.5 - vec2(tt * 0.05, 0.0)));
		c = mix(vec3(0.16, 0.09, 0.03), vec3(0.42, 0.27, 0.1), f) + vec3(0.55, 0.45, 0.3) * (bub * 0.8 + gloss * 0.35) + vec3(0.3, 0.2, 0.08) * rim;
		a = inside * (charging > 0.5 ? 0.35 + 0.45 * arm : 0.92);
	} else if (mode > 1.5) {
		// ---- FAIXA DE PERIGO: listras diagonais correndo, borda viva e setas pulsando ao longo da faixa
		float ex = smoothstep(1.0, 0.94, abs(p.x));
		float ez = smoothstep(1.0, 0.9, abs(p.y));
		float inside = ex * ez;
		float border = max(band(abs(p.x), 0.97, 0.03, 0.02), band(abs(p.y), 0.95, 0.05, 0.03));
		float st = step(0.5, fract((m.x + m.y) * 0.45 - tt * 1.6));
		float chev = 0.0;
		float lz = fract(m.x * 0.18 + tt * 1.2);
		chev = smoothstep(0.08, 0.0, abs(lz - 0.5 - abs(p.y) * 0.35)) * step(abs(p.y), 0.55);
		vec3 hot = col.rgb;
		c = mix(vec3(0.06, 0.05, 0.08), hot, st * 0.85) + hot * (border * 1.3 + chev * 0.8);
		a = inside * (charging > 0.5 ? (0.45 + 0.4 * arm) * blink : 0.38);
	} else if (mode > 0.5) {
		// ---- FOGO: chamas em fbm subindo pela faixa, borda rasgada, núcleo amarelo
		float n1 = fbm(vec2(m.x * 0.8, m.y * 0.8 - tt * 2.6));
		float n2 = fbm(vec2(m.x * 1.7 + 4.0, m.y * 1.4 - tt * 4.0));
		float e = max(abs(p.x), abs(p.y)) + (n1 - 0.5) * 0.45;
		float inside = smoothstep(1.0, 0.7, e);
		float heat = clamp(n1 * 0.7 + n2 * 0.6 - e * 0.35, 0.0, 1.0);
		c = mix(vec3(0.35, 0.03, 0.0), vec3(1.0, 0.35, 0.03), smoothstep(0.25, 0.6, heat));
		c = mix(c, vec3(1.0, 0.9, 0.45), smoothstep(0.62, 0.85, heat));
		c *= 1.6;
		a = inside * clamp(heat * 1.6, 0.0, 1.0) * arm;
	} else {
		// ---- CÍRCULO DE IMPACTO
		float inside = step(r, 1.0);
		// borda dupla: faixa tracejada girando e um aro fino por dentro
		float dash = step(0.38, fract(ang / 6.2831853 * 20.0 + tt * (0.5 + arm)));
		float outer = band(r, 0.94, 0.04, 0.015) * dash;
		float thin = band(r, 0.86, 0.008, 0.01);
		// anel que fecha do aro até o centro: quando chega no meio, é o golpe
		float closing = band(r, 1.0 - arm * 0.92, 0.025, 0.02) * charging;
		// varredura de relógio: a área já "carregada" fica mais acesa
		float sweep_a = fract((ang + 1.5707963) / 6.2831853);
		float sweep = step(sweep_a, arm) * 0.22 * step(r, 0.86);
		float lead = smoothstep(0.02, 0.0, abs(sweep_a - arm)) * step(r, 0.86) * 0.6 * charging;
		// setas apontando para fora (saia daí!)
		float k8 = fract(ang / 6.2831853 * 8.0) - 0.5;
		float rr = fract(r * 2.2 - tt * 1.4);
		float arrows = smoothstep(0.05, 0.0, abs(rr - 0.5 + abs(k8) * 0.9)) * step(0.25, r) * step(r, 0.82) * 0.55;
		float detail = 0.0;
		if (sub < 0.5) {
			// TREMOR: rachaduras que se espalham do centro e brilham mais perto do golpe
			// células tortas (ruído desloca o voronoi) e rachaduras radiais saindo do centro
			vec2 wq = m * 0.42 + vec2(fbm(m * 0.7), fbm(m * 0.7 + 5.3)) * 1.6;
			vec3 v = voronoi(wq);
			float radial = smoothstep(0.035, 0.0, abs(fract(ang / 6.2831853 * 7.0 + (fbm(m * 0.45) - 0.5) * 0.5) - 0.5) * r * 2.0) * step(0.12, r);
			float crack = max(smoothstep(0.045, 0.0, v.y) * step(0.35, hash(floor(wq) + 3.0)), radial) * smoothstep(arm * 1.05 + 0.05, arm * 1.05 - 0.1, r);
			detail = crack * (0.6 + arm * 1.2);
			arrows *= 0.7;
		} else if (sub < 1.5) {
			// METEORO: mira com quatro colchetes girando e cruz no centro
			float rot = ang + tt * 1.6;
			float br = band(r, 0.7, 0.025, 0.015) * step(0.62, abs(fract(rot / 6.2831853 * 4.0) - 0.5) * 2.0);
			float cross_ = (band(p.x, 0.0, 0.012, 0.01) + band(p.y, 0.0, 0.012, 0.01)) * step(r, 0.42) * step(0.08, r);
			float dot_ = smoothstep(0.07, 0.04, r);
			detail = br * 1.2 + cross_ + dot_;
			arrows = 0.0;
		} else if (sub < 2.5) {
			// EMP: grade hexagonal com uma onda elétrica correndo para fora
			vec2 q = m * 0.7;
			vec2 h = vec2(q.x * 1.1547, q.y + q.x * 0.57735);
			vec2 fh = fract(h) - 0.5;
			float hexd = max(abs(fh.x), max(abs(fh.y), abs(fh.x + fh.y)));
			float grid = smoothstep(0.03, 0.0, abs(hexd - 0.48));
			float wave = band(fract(r * 1.5 - tt * 1.8), 0.5, 0.12, 0.08);
			detail = grid * (0.25 + wave * 0.9);
			arrows *= 0.6;
		}
		vec3 hot = col.rgb;
		c = hot * (outer * 1.4 + thin + closing * 1.6 + sweep + lead + arrows + detail) + vec3(1.0) * (closing * 0.35 + lead * 0.3);
		float lum = clamp(outer + thin * 0.8 + closing + sweep * 1.4 + lead + arrows + detail, 0.0, 1.0);
		a = inside * (charging > 0.5 ? lum * blink : lum * 0.35);
		// sombra: escurece o chão dentro do círculo para o desenho saltar
		float shade = inside * (charging > 0.5 ? 0.22 + 0.18 * arm : 0.12);
		c = mix(vec3(0.0), c, clamp(a / max(a + shade, 0.001), 0.0, 1.0)) ;
		a = clamp(a + shade, 0.0, 0.95);
	}
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0) * life;
}
