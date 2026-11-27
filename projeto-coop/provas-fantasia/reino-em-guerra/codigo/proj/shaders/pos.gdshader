// Pós da impressão: (1) tilt-shift suave só na faixa do horizonte; (2) erro de registro: o croma (a aguada) desliza
// 1,5 px em relação à luma (a tinta), como a cor aplicada à mão fora do traço; (3) peneira de paleta com o grão da
// aquatinta: o que o motor misturou (névoa volumétrica, brilho, degradê) volta para duas cores da paleta, pontilhadas;
// (4) fibra do papel; (5) prova em negativo e reimpressão desalinhada do Golpe de Prensa.
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear;
global uniform sampler2D grao : filter_nearest, repeat_enable;
uniform float registro = 1.5;
uniform vec2 reg_dir = vec2(0.8, -0.6);
uniform float reimpressao = 0.0;
uniform float negativo = 0.0;
uniform float tilt = 1.0;
uniform float tilt_y = 0.17;
uniform float fibra = 0.035;
uniform float peneira = 1.0;
uniform float borda_lim = 0.16;
uniform vec3 pal[22];
uniform int npal = 22;
uniform float vinheta = 0.0;     // vinheta de tinta sépia-preta em grão (low key)
uniform float manchas = 0.0;     // manchas d'água no papel (anéis de maré em ocre)
uniform float clarao = 0.0;      // exposição estourada do raio (o papel estoura, a linha fica)
uniform vec2 semente_m = vec2(3.1, 7.7);
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.55 + vn(p * 2.1 + 3.7) * 0.3 + vn(p * 4.3 + 1.1) * 0.15; }

vec3 at(vec2 uv) { return texture(tela, uv).rgb; }
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	// (1) tilt-shift: desfoca só os 17% de cima (céu e horizonte)
	float bl = tilt * smoothstep(tilt_y, 0.0, uv.y) * 2.2;
	vec3 c = at(uv);
	if (bl > 0.05) {
		vec3 s = vec3(0.0);
		float tw = 0.0;
		for (int i = -2; i <= 2; i++) {
			for (int j = -2; j <= 2; j++) {
				float w = exp(-float(i * i + j * j) / 4.0);
				s += at(uv + vec2(float(i), float(j)) * px * bl) * w;
				tw += w;
			}
		}
		c = s / tw;
	}
	// (2) registro: luma daqui, croma de 1,5 px ao lado (mais 4 px na reimpressão)
	vec2 o = reg_dir * px * (registro + reimpressao * 4.0);
	vec3 c2 = at(uv - o);
	vec3 cr = c2 - vec3(lum(c2));
	vec3 base = vec3(lum(c)) + cr;
	// só aplica onde há croma de verdade (aguada), para não sujar a tinta e o papel
	// só a aguada dos heróis (cores de jogador, saturação HSV > 0,6) sai do registro; o mundo fica no lugar
	float s1 = (max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b))) / max(max(c.r, max(c.g, c.b)), 1e-3);
	float s2 = (max(c2.r, max(c2.g, c2.b)) - min(c2.r, min(c2.g, c2.b))) / max(max(c2.r, max(c2.g, c2.b)), 1e-3);
	c = mix(c, base, smoothstep(0.58, 0.64, max(s1, s2)) * step(0.0, 1.0));
	// (3) peneira de paleta em grão (só em área lisa; borda de linha fica como está)
	vec4 G = texture(grao, FRAGCOORD.xy / 256.0);
	G.r = G.r * 0.996 + 0.002;
	// o verde-mordente (olhos acesos, halo, brilho) volta exato para a paleta antes da peneira
	if (c.g > 0.55 && c.g > c.r * 1.12 && c.g > c.b * 2.2) c = pal[18];
	if (peneira > 0.5) {
		float l0 = lum(at(uv));
		float e = max(max(abs(lum(at(uv + vec2(px.x, 0.0))) - l0), abs(lum(at(uv - vec2(px.x, 0.0))) - l0)),
		              max(abs(lum(at(uv + vec2(0.0, px.y))) - l0), abs(lum(at(uv - vec2(0.0, px.y))) - l0)));
		// mistura de tinta com uma cor da paleta (borda de linha) já é "da paleta": fica como está
		vec3 INK = pal[0];
		float rmin = 99.0;
		for (int k = 1; k < 22; k++) {
			if (k >= npal) break;
			vec3 dpi = pal[k] - INK;
			float a = clamp(dot(c - INK, dpi) / max(dot(dpi, dpi), 1e-5), 0.0, 1.0);
			vec3 rr = c - (INK + dpi * a);
			rmin = min(rmin, dot(rr, rr));
		}
		float misto = 1.0 - smoothstep(0.0004, 0.0016, rmin);
		float d1 = 99.0; float d2 = 99.0; vec3 p1 = c; vec3 p2 = c;
		for (int k = 0; k < 22; k++) {
			if (k >= npal) break;
			if (k == 11 || k == 12 || (k >= 14 && k <= 18) || k == 21) continue;   // raio, jogadores, mordente e perigo não entram na peneira
			vec3 d = (c - pal[k]) * vec3(0.9, 1.2, 0.7);
			float dd = dot(d, d);
			if (dd < d1) { d2 = d1; p2 = p1; d1 = dd; p1 = pal[k]; }
			else if (dd < d2) { d2 = dd; p2 = pal[k]; }
		}
		vec3 seg = p2 - p1;
		float t = clamp(dot(c - p1, seg) / max(dot(seg, seg), 1e-5), 0.0, 1.0);
		vec3 q = G.r < t ? p2 : p1;
		c = mix(q, c, misto);   // toda cor que não é tinta sobre a paleta volta para duas cores da paleta, em grão
	}
	// (4) fibra do papel
	c *= 1.0 + (G.g - 0.5) * fibra;
	// (4b) manchas d'água no papel: a área manchada escurece o papel claro para âmbar e tem borda de maré ocre
	if (manchas > 0.0) {
		vec2 mp = (uv * vec2(1.78, 1.0)) * 2.4 + semente_m;
		float n = fbm(mp) + 0.12 * vn(mp * 9.0);
		float limiar = 0.71;
		float dentro = step(limiar, n) * manchas;
		float mare = (1.0 - smoothstep(0.0, 0.006, abs(n - limiar))) * manchas;
		float lc = lum(c);
		if (dentro > 0.5 && lc > 0.55 && fract(G.r * 7.31) < 0.45) c = vec3(0.890, 0.788, 0.604);
		if (mare > 0.5 && lc > 0.6 && fract(G.r * 3.7) < 0.6) c = vec3(0.890, 0.788, 0.604);
	}
	// (4c) vinheta de tinta em grão, irregular como borda de chapa mal entintada
	if (vinheta > 0.0) {
		vec2 d = (uv - 0.5) * vec2(1.0, 1.25);
		float r = length(d) * 1.55 + (vn(uv * 6.0 + semente_m) - 0.5) * 0.18;
		float v = smoothstep(0.8, 1.25, r) * vinheta;
		// vinheta de buril: linhas a 50° que engrossam para os cantos (a largura é o tom), não grão
		vec2 fp = FRAGCOORD.xy / max(registro / 1.5, 0.5) * (1.0 / 1.0);
		float esp = 5.0 * max(registro / 1.5, 0.67);
		float s = abs(fract(dot(FRAGCOORD.xy, vec2(0.643, 0.766)) / esp) - 0.5) * 2.0;
		float s2 = abs(fract(dot(FRAGCOORD.xy, vec2(-0.906, 0.423)) / esp) - 0.5) * 2.0;
		if (s < v * 1.1 || s2 < (v - 0.5) * 1.2) c = pal[0];
	}
	// (4d) clarão do raio: o papel estoura em branco-papel, a linha de tinta fica
	if (clarao > 0.0) {
		float lc = lum(c);
		c = lc < 0.22 ? c : mix(c, vec3(0.957, 0.945, 0.910), step(G.r, clarao));
	}
	// (5) prova em negativo, dentro da paleta: o claro vira tinta, o escuro vira papel (2 tons)
	vec3 neg = mix(vec3(0.914, 0.875, 0.788), pal[0], smoothstep(0.22, 0.58, lum(c)));
	c = mix(c, neg, negativo);
	COLOR = vec4(c, 1.0);
}
