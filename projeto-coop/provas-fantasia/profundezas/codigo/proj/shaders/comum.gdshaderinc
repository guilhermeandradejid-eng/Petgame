// Comum a todos os materiais de Plumbdeep. A atmosfera é feita no material (igual no Compatibility e no Forward+):
// perspectiva atmosférica por passos de 250 m (valor 30% mais perto da névoa, saturação -40%) e névoa de altura
// que só existe abaixo do plano de jogo. O Forward+ soma névoa volumétrica por cima.
global uniform vec4 nevoa_cor;      // rgb: cor da névoa fria; a: força geral
global uniform vec4 nevoa_par;      // x: início (m), y: passo (m), z: valor por passo, w: saturação por passo
global uniform vec4 nevoa_alt;      // x: topo da névoa de altura (y), y: densidade por metro, z: brilho extra, w: altura de fade
global uniform vec4 nevoa_alt_cor;  // rgb: cor da névoa de altura
global uniform vec4 vento;          // xy: direção, z: força, w: tempo
global uniform vec4 resp;           // x: respiração (-1 inspira, 0 prende, 1 expira), y: raio da frente (m), zw: origem xz da frente
global uniform vec4 flash;          // xyz: posição do clarão da reação, w: força (luz pintada barata)
global uniform vec4 flash_cor;
// v2: poças de luz quente PINTADAS (vela, geodo, isca, postes, guincho): xyz posição, w raio. Iguais nos dois
// renderers e baratas no iPhone; no PC as OmniLight somam por cima.
global uniform vec4 lq0; global uniform vec4 lq1; global uniform vec4 lq2; global uniform vec4 lq3; global uniform vec4 lq4;
global uniform vec4 lq5; global uniform vec4 lq6; global uniform vec4 lq7; global uniform vec4 lq8; global uniform vec4 lq9;

float h31(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float h21(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float vnoise3(vec3 p) {
	vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h31(i), h31(i + vec3(1,0,0)), f.x), mix(h31(i + vec3(0,1,0)), h31(i + vec3(1,1,0)), f.x), f.y);
	float b = mix(mix(h31(i + vec3(0,0,1)), h31(i + vec3(1,0,1)), f.x), mix(h31(i + vec3(0,1,1)), h31(i + vec3(1,1,1)), f.x), f.y);
	return mix(a, b, f.z);
}
// O Compatibility (WebGL2) escreve a cor final sem a conversão linear -> sRGB que o Forward+ faz no fim; 'saida'
// aplica essa conversão só no Compatibility, para os dois renderers darem os mesmos pixels. 'vc' fica como
// ponto único de leitura da cor de vértice (linear nos dois).
vec3 vc(vec3 c) { return c; }
vec3 saida(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
#else
	return c;
#endif
}
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// quanto da névoa cobre este ponto (0..1) e a cor dela
vec4 atmos_k(vec3 wp, vec3 cam) {
	float d = max(length(wp - cam) - nevoa_par.x, 0.0);
	float n = d / nevoa_par.y;
	float kv = 1.0 - pow(1.0 - nevoa_par.z, n);
	// névoa de altura: comprimento do raio dentro da camada abaixo do topo
	float top = nevoa_alt.x;
	float L = length(wp - cam);
	float inside = 0.0;
	if (wp.y < top) {
		float dy = max(cam.y - wp.y, 0.01);
		inside = L * clamp((top - wp.y) / dy, 0.0, 1.0);
	}
	float kh = 1.0 - exp(-inside * nevoa_alt.y);
	kh *= smoothstep(0.0, nevoa_alt.w, top - wp.y);
	vec3 col = mix(nevoa_cor.rgb, nevoa_alt_cor.rgb, clamp(kh / max(kv + kh, 0.001), 0.0, 1.0));
	float k = 1.0 - (1.0 - kv) * (1.0 - kh);
	return vec4(col, clamp(k * nevoa_cor.a, 0.0, 0.985));
}
vec3 atmos(vec3 c, vec3 wp, vec3 cam) {
	float d = max(length(wp - cam) - nevoa_par.x, 0.0);
	float ks = 1.0 - pow(1.0 - nevoa_par.w, d / nevoa_par.y);
	c = mix(c, vec3(luma(c)), ks * nevoa_cor.a);
	vec4 f = atmos_k(wp, cam);
	return mix(c, f.rgb, f.a);
}
// clarão barato de reação (luz pintada que o iPhone também tem): soma no máximo +20%
vec3 clarao(vec3 c, vec3 wp, vec3 n) {
	if (flash.w <= 0.0) return c;
	vec3 d = flash.xyz - wp;
	float r = length(d);
	float k = flash.w * clamp(1.0 - r / 7.0, 0.0, 1.0);
	k *= k * (0.5 + 0.5 * clamp(dot(n, d / max(r, 0.001)), 0.0, 1.0));
	return c + c * flash_cor.rgb * k * 0.35 + flash_cor.rgb * k * 0.06;
}

// poça de luz em 3 degraus de pincel (sem degradê contínuo): borda larga fraca, miolo mais forte
float poca_k(vec4 L, vec3 wp) {
	if (L.w <= 0.0) return 0.0;
	float d = length((wp - L.xyz) * vec3(1.0, 1.6, 1.0)) / L.w;
	return smoothstep(1.0, 0.92, d) * 0.45 + smoothstep(0.62, 0.55, d) * 0.35 + smoothstep(0.3, 0.24, d) * 0.2;
}
vec3 pocas(vec3 c, vec3 wp, float k) {
	float s = poca_k(lq0, wp) + poca_k(lq1, wp) + poca_k(lq2, wp) + poca_k(lq3, wp) + poca_k(lq4, wp)
		+ poca_k(lq5, wp) + poca_k(lq6, wp) + poca_k(lq7, wp) + poca_k(lq8, wp) + poca_k(lq9, wp);
	s = min(s, 1.2) * k;
	vec3 q = vec3(1.0, 0.64, 0.3);
	return c * (1.0 + q * s * 1.1) + q * s * 0.02;
}
