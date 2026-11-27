// Núcleo da água-forte colorida à mão (A Pequena Hoste). Mesmo código no Forward+ e no Compatibility.
// - Não há sombreamento por gradiente: o escuro vira de 0 a 4 camadas de hachura (ângulos ~50°, 128°, 6°, 86°),
//   linhas de buril (finas nas pontas, grossas no meio), em coordenadas que seguem a forma (UV em metros nos bonecos,
//   mundo com dobra de altura no terreno, triplanar nas caixas). A largura da linha é o tom; o papel nunca cai abaixo
//   de ~35% (cobertura máxima de 23% por camada).
// - Densidade por oitava (como mip): o espaçamento em pixels fica sempre entre alvo_px e 2·alvo_px; a oitava fina entra
//   aos poucos, então a linha não "nada" nem some de repente quando a câmera anda.
// - Luz apaga tinta: até 16 apagadores (tochas, velas, raio, forja) vêm numa textura global, e cada herói tem uma
//   reserva de papel de 1,2 m no chão. A sombra real (PCSS no PC) entra por ATTENUATION no light().
// - Cor: o papel muda com a hora (âmbar -> cinza-azulado, em grão, nunca em degradê) e a aguada é plana, com borda de
//   pigmento acumulado e papel reservado no lugar do brilho. O erro de registro é feito no pós (croma desalinhado).
global uniform vec3 sol_dir;
global uniform vec3 foco;
global uniform float curva_k;
global uniform float curva_r0;
global uniform vec2 curva_dir;
global uniform float escuro_base;
global uniform float escuro_faixa;
global uniform float escuro_mundo;   // low key: tinta a mais só no mundo (os heróis ficam claros)
global uniform vec4 papel_frio : source_color;
global uniform vec4 papel_quente : source_color;
global uniform vec2 frente_x;
global uniform float alvo_px;
global uniform float tempo;
global uniform vec2 vento;
global uniform vec4 nevoa;          // x = início, y = fim (m da câmera), z = máximo, w = papel da névoa (0 frio..1 quente)
global uniform vec4 nevoa_alt;      // névoa de altura: x = topo (m), y = fundo (m), z = distância onde começa, w = máximo
global uniform int n_luzes;
global uniform sampler2D luzes : filter_nearest;
global uniform sampler2D grao : filter_nearest, repeat_enable;
global uniform float conv_cor;   // 1 no Compatibility: lá o uniform source_color dos shaders com luz chega sem conversão
vec3 cor_u(vec3 c) { return conv_cor > 0.5 ? mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)) : c; }

const vec3 TINTA = vec3(0.0168, 0.0116, 0.0086);       // #231C17 em linear
const vec3 PAPEL_DIA = vec3(0.815, 0.737, 0.584);      // #E9DFC9
const vec3 CERA = vec3(0.888, 0.791, 0.539);           // #F2E6C2

struct GF {
	vec3 wp; vec2 q; float px; vec4 aguada; vec3 papel; float apaga; float quente; float res; float nev; float grao; float seed; float extra;
};
varying vec3 g_wp;
varying vec2 g_q;
varying float g_px;
varying vec4 g_aguada;
varying vec3 g_papel;
varying vec4 g_luz;     // apaga, quente, reserva, névoa
varying vec3 g_misc;    // grão, semente, extra

float curva(vec3 w) {
	float d = dot(w.xz - foco.xz, curva_dir);
	float e = max(d - curva_r0, 0.0);
	return curva_k * e * e;
}

float h11(float n) { return fract(sin(n * 127.1) * 43758.5453); }

// papel: âmbar à direita, cinza-azulado à esquerda (a tempestade chega do oeste); a transição é em grão de aquatinta
vec3 papel_em(vec3 w, float gr) {
	float t = clamp((w.x - frente_x.x) / (frente_x.y - frente_x.x), 0.0, 1.0);
	return gr < t ? papel_quente.rgb : papel_frio.rgb;
}

// soma dos apagadores; devolve (apaga, quente)
vec2 apagadores(vec3 w) {
	float a = 0.0;
	float q = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= n_luzes) break;
		vec4 L = texelFetch(luzes, ivec2(i, 0), 0);
		vec4 Ex = texelFetch(luzes, ivec2(i, 1), 0);
		float d = length(w - L.xyz);
		float k = clamp(1.0 - d / max(L.w, 0.01), 0.0, 1.0);
		k = k * k * (3.0 - 2.0 * k) * Ex.x;
		a = max(a, k);
		q = max(q, k * Ex.y);
	}
	return vec2(a, q);
}

float reserva(vec3 w) {
	float r = 9.0;
	for (int i = 0; i < 4; i++) {
		vec4 H = texelFetch(luzes, ivec2(i, 2), 0);
		if (H.w <= 0.0) continue;
		float d = length(w.xz - H.xz);
		r = min(r, mix(0.12, 9.0, smoothstep(H.w * 0.55, H.w, d)));
	}
	return r;
}

// cobertura de UMA família de linhas, numa oitava: posição s (em espaçamentos), t ao longo da linha, px = espaçamentos/pixel
float buril(float s, float t, float meia, float px, float sd) {
	float n = floor(s);
	float h = fract(sin(n * 91.7 + sd * 311.3) * 43758.5453);
	float L = mix(16.0, 34.0, h);                   // comprimento do traço em espaçamentos
	float u = fract(t / L + h * 7.13);
	float lag = smoothstep(0.0, 0.07, u) * smoothstep(1.0, 0.82, u) * (0.7 + 0.3 * sin(3.14159 * u)); // lágrima do buril
	float w = meia * lag / px;                      // meia largura em pixels
	float d = abs(fract(s) - 0.5) / px;             // distância ao centro da linha em pixels
	float cov = clamp(min(d + 0.5, w) - max(d - 0.5, -w), 0.0, 1.0);
	// abaixo de ~2,2 px por espaçamento, troca a linha pelo tom médio (sem moiré)
	float media = 2.0 * meia * 0.7;
	return mix(cov, media, smoothstep(0.42, 0.6, px));
}

const vec4 ANG = vec4(0.105, 0.873, 2.234, 1.501);     // 6° (em volta da forma), 50°, 128°, 86°: cruzamentos fora de 90°

float hachura_e(vec2 q, float D, float px_m, float sd, float esp_fixo) {
	// px_m: metros por pixel; escolhe a oitava pelo espaçamento em pixels (esp_fixo > 0: espaçamento fixo em metros,
	// sem oitavas, para o chão: ao longe a linha vira tom médio, que é a perspectiva atmosférica da gravura)
	float esp0 = 0.06;
	float L = log2(max(esp0 / px_m, 1e-3) / alvo_px);
	float lv = floor(L);
	float f = L - lv;
	float espA = esp0 / exp2(lv);
	if (esp_fixo > 0.0) { espA = esp_fixo; f = 0.0; }
	float tinta = 1.0;
	for (int i = 0; i < 4; i++) {
		float band = clamp(D - float(i), 0.0, 1.0);
		if (band <= 0.0) break;
		float meia = 0.115 * pow(band, 0.7);
		float a = ANG[i];
		vec2 dir = vec2(cos(a), sin(a));
		vec2 per = vec2(-dir.y, dir.x);
		float sA = dot(q, dir) / espA;
		float tA = dot(q, per) / espA;
		float pxA = px_m / espA;
		float cA = buril(sA + 0.37 * float(i), tA, meia, pxA, sd + float(i) * 3.1);
		float c = cA;
		if (f > 0.0) {
			float cB = buril(sA * 2.0 + 0.37 * float(i), tA * 2.0, meia, pxA * 2.0, sd + float(i) * 3.1 + 17.0);
			c = mix(cA, cB, f);
		}
		tinta *= 1.0 - c;
	}
	return 1.0 - tinta;
}
float hachura(vec2 q, float D, float px_m, float sd) { return hachura_e(q, D, px_m, sd, 0.0); }

// prepara no fragment(): GRAV_SET(wp, q, aguada, semente, extra) atribui os varyings (macro, porque função não pode)
GF grav_prep(vec3 wp, vec2 q, vec4 aguada, float sd, vec2 fragc, vec3 campos, float extra, float pxm) {
	GF g;
	g.wp = wp; g.q = q; g.aguada = aguada; g.seed = sd; g.extra = extra;
	g.px = max(pxm, 1e-5);
	vec4 G = texture(grao, fragc / 256.0);
	g.grao = G.r * 0.996 + 0.002;
	g.papel = papel_em(wp, fract(G.r + 0.37));
	vec2 ap = apagadores(wp);
	g.apaga = ap.x; g.quente = ap.y;
	g.res = 9.0;
	float dcam = length(wp - campos);
	g.nev = smoothstep(nevoa.x, nevoa.y, dcam) * nevoa.z;
	// névoa de altura: deita no vale e no rio; como o mundo cai com a curvatura, ela engrossa com a distância
	float hf = smoothstep(nevoa_alt.x, nevoa_alt.y, wp.y) * smoothstep(nevoa_alt.z, nevoa_alt.z + 14.0, dcam) * nevoa_alt.w;
	g.nev = clamp(max(g.nev, hf) + g.nev * hf * 0.5, 0.0, 0.97);
	return g;
}
#define GRAV_SET(WP, Q, AG, SD, EX) { GF gg_ = grav_prep(WP, Q, AG, SD, FRAGCOORD.xy, CAMERA_POSITION_WORLD, EX, length(vec2(length(dFdx(WP)), length(dFdy(WP)))) * 0.7071); g_wp = gg_.wp; g_q = gg_.q; g_px = gg_.px; g_aguada = gg_.aguada; g_papel = gg_.papel; g_luz = vec4(gg_.apaga, gg_.quente, gg_.res, gg_.nev); g_misc = vec3(gg_.grao, gg_.seed, gg_.extra); }
#define GRAV_GET GF(g_wp, g_q, g_px, g_aguada, g_papel, g_luz.x, g_luz.y, g_luz.z, g_luz.w, g_misc.x, g_misc.y, g_misc.z)

vec3 grav_cor2(GF g, float D, vec3 N, vec3 Ldir, vec3 V, float lit) {
	D *= 1.0 - g.apaga;
	D = min(D, g.res);
	// aquatinta de sombra funda (só no mundo escurecido): passa de 4 camadas, o grão de resina fecha em tinta
	float aq = clamp((D - 3.1) * 0.32, 0.0, 0.5) * step(1.0, g.extra);
	D = clamp(D, 0.0, 4.0);
	vec3 papel = mix(g.papel, papel_quente.rgb, step(g.grao, max(g.quente, step(g.res, 0.6))));   // a reserva do herói é papel quente
	papel = mix(papel, PAPEL_DIA, step(g.grao, g.quente * g.quente * 0.8));
	vec3 base = papel;
	if (g.aguada.a > 0.01 && g.res > 0.6) {   // reserva do herói: papel limpo, sem aguada
		vec3 w = g.aguada.rgb;
		float fr = 1.0 - clamp(dot(N, V), 0.0, 1.0);
		w *= mix(1.0, 0.8, smoothstep(0.62, 0.72, fr));               // borda de pigmento acumulado
		base = g.grao < g.aguada.a * 1.02 ? w : papel;      // aguada sem degradê: ou tem pigmento, ou é papel
		float spec = dot(reflect(-Ldir, N), V);
		base = mix(base, PAPEL_DIA, step(0.985, spec) * step(0.7, lit)); // papel reservado no brilho
	}
	float cob = g.seed < 0.0 ? hachura_e(g.q, D, g.px, 1.0, -g.seed) : hachura(g.q, D, g.px, g.seed);
	vec3 c = mix(base, TINTA, cob);
	c = fract(g.grao * 3.17 + 0.29) < aq ? TINTA : c;
	// névoa de aquatinta: as linhas clareiam para o papel e o grão de resina escurece em pontos
	vec3 pn = mix(papel_frio.rgb, papel_quente.rgb, nevoa.w);
	c = fract(g.grao * 7.31) < g.nev * 0.85 ? pn : c;
	c = mix(c, TINTA, step(g.grao, g.nev * 0.12));
	return c;
}

vec3 grav_cor(vec3 N, vec3 Ldir, vec3 V, float atten, GF g) {
	float ndl = dot(N, Ldir);
	float lit = clamp(ndl * 0.85 + 0.3, 0.0, 1.0) * mix(0.25, 1.0, atten);
	float D = escuro_base + (1.0 - lit) * escuro_faixa + g.extra;
	return grav_cor2(g, D, N, Ldir, V, lit);
}

// Gravura em negativo (os mortos da Procissão): a figura é tinta cheia e a luz é cavada em linhas de papel, como na
// matriz entalhada. O lado iluminado ganha 2 a 3 famílias de linha branca; a sombra fica preta; a borda tem um fio de
// papel (rim) que separa a figura do fundo escuro.
vec3 grav_neg(vec3 N, vec3 Ldir, vec3 V, float atten, GF g, float rim) {
	float ndl = dot(N, Ldir);
	float lit = clamp(ndl * 0.85 + 0.3, 0.0, 1.0) * mix(0.25, 1.0, atten);
	float W = clamp(lit * 2.3 - 0.85 + g.apaga * 2.0, 0.0, 3.0);
	float cob = hachura(g.q, W, g.px, g.seed + 5.0);
	vec3 linha = mix(g.papel, PAPEL_DIA, 0.5);
	vec3 c = mix(TINTA, linha, cob);
	float fr = 1.0 - clamp(dot(N, V), 0.0, 1.0);
	c = mix(c, PAPEL_DIA, step(0.78, fr) * rim);
	vec3 pn = mix(papel_frio.rgb, papel_quente.rgb, nevoa.w);
	c = fract(g.grao * 7.31) < g.nev * 0.85 ? pn : c;
	return c;
}
