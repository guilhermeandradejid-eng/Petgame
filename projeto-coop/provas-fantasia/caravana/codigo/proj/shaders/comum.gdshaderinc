// Comum a todos os materiais do mundo da Wickwain: luzes de pavio (uniforme global, até 8), curvatura do mundo
// (a câmera alta enxerga o horizonte), ruído de pincelada triplanar e hachura de água-forte.
global uniform vec4 pavio_0; global uniform vec4 pavio_1; global uniform vec4 pavio_2; global uniform vec4 pavio_3;
global uniform vec4 pavio_4; global uniform vec4 pavio_5; global uniform vec4 pavio_6; global uniform vec4 pavio_7;
global uniform vec4 curva_piv;   // x, z do pivô; x, z da direção de frente da câmera
global uniform vec4 curva_par;   // início da dobra (m), comprimento da rampa (m), inclinação final, liga (0/1)
global uniform float ferve;      // passo de fervura das linhas (8 por segundo, semente fixa)
global uniform vec4 vento;       // dir x, dir z, força, tempo

const vec3 C_SEBO = vec3(0.887, 0.723, 0.431);
const vec3 C_AMBAR = vec3(0.807, 0.356, 0.068);
const vec3 C_VIOLETA = vec3(0.048, 0.034, 0.081);
const vec3 C_AZUL = vec3(0.024, 0.042, 0.085);
const vec3 C_NOITE = vec3(0.008, 0.011, 0.023);
const vec3 C_LINHA = vec3(0.115, 0.15, 0.23);    // linha da gravura (valor ~0,45): contraste baixo contra o fundo (~0,25)
const vec3 C_TRACO = vec3(0.223, 0.296, 0.434);   // traço claro antigo: só folha fina e sulco dos bichos
const vec3 C_FUNDO = vec3(0.034, 0.046, 0.082);   // fundo da gravura perto (valor ~0,25)

float drop_curva(vec3 w) {
	if (curva_par.w < 0.5) return 0.0;
	float d = dot(w.xz - curva_piv.xy, curva_piv.zw) - curva_par.x;
	if (d <= 0.0) return 0.0;
	float L = curva_par.y, s = curva_par.z;
	// rampa suave: inclinação cresce de 0 a s em L metros, depois fica constante
	if (d < L) return s * d * d / (2.0 * L);
	return s * (L * 0.5 + (d - L));
}

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float h31(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}
// pincelada: ruído esticado numa direção (traço de pincel), escala de 0,5 m
float pinc2(vec2 p, float ang) {
	vec2 d = vec2(cos(ang), sin(ang));
	vec2 q = vec2(dot(p, d) * 0.9, dot(p, vec2(-d.y, d.x)) * 3.2);
	return vnoise(q) * 0.65 + vnoise(q * 2.3 + 7.1) * 0.35;
}
float pincelada(vec3 w, vec3 n) {
	vec3 b = pow(abs(n), vec3(4.0)); b /= (b.x + b.y + b.z);
	vec3 p = w * 2.0;   // 0,5 m
	return pinc2(p.zy, 1.2) * b.x + pinc2(p.xz, 0.5) * b.y + pinc2(p.xy, 1.9) * b.z;
}

// máscara de luz: soma suave (log-soma-exp) das fontes de pavio, num campo em metros (E > 0 dentro da luz).
// A transição guache/gravura é uma faixa de dissolve de 0,8 m recortada por pincel em world-space (traço largo
// de 0,5 m e escova seca fina), não uma borda dura. q = calor (núcleo 1, borda 0), soma das fontes.
const float PAV_BANDA = 0.8;
float escova(vec3 w) {
	// escova seca: traços finos (12 cm) esticados, para a borda falhar como pincel com pouca tinta
	return pinc2(w.xz * 7.0 + vec2(w.y * 3.0), 0.7);
}
void pavio(vec3 w, float n, out float m, out float mol, out vec3 dl, out float q) {
	vec4 Ls[8] = vec4[8](pavio_0, pavio_1, pavio_2, pavio_3, pavio_4, pavio_5, pavio_6, pavio_7);
	float se = 0.0, aq = 0.0;
	vec3 adl = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		vec4 L = Ls[i];
		if (L.w > 0.01) {
			vec3 dv = L.xyz - w;
			float dd = length(vec2(dv.x, dv.z)) + abs(dv.y) * 0.25;
			se += exp(clamp((L.w - dd) * 2.5, -30.0, 30.0));
			float wq = clamp(1.0 - dd / max(L.w, 0.1), 0.0, 1.0);
			wq = wq * wq * (3.0 - 2.0 * wq);
			adl += normalize(dv + vec3(0.0, 0.6, 0.0)) * wq;
			aq += wq;
		}
	}
	float Ecampo = se > 0.0 ? log(se) / 2.5 : -100.0;
	float rb = Ecampo / PAV_BANDA + (n - 0.5) * 1.5 + (escova(w) - 0.5) * 0.9;
	m = smoothstep(-0.1, 0.1, rb);
	mol = m * (1.0 - smoothstep(0.0, 0.9, rb));
	q = clamp(aq, 0.0, 1.0);
	dl = length(adl) > 0.001 ? normalize(adl) : vec3(0.0, 1.0, 0.0);
}

// gravura por tonal art map: a linha é CLARA sobre fundo escuro, então quanto mais claro o tom (albedo e lado
// iluminado pelo Sol Velho), mais camadas entram e mais grossa fica a linha. Direção pelo fluxo da superfície: no chão, curva de nível (perpendicular à descida) e, no plano,
// uma diagonal fixa com leve ondulação; nas laterais, contorno horizontal. Ferve a 8 fps.
float linha(float c, float larg) {
	float fw = max(fwidth(c), 1e-4);
	float d = abs(fract(c + 0.5) - 0.5);
	float l = 1.0 - smoothstep(larg * 0.5 - fw * 0.75, larg * 0.5 + fw * 0.75, d);
	// longe demais: vira tom médio, sem moiré
	return mix(l, larg, smoothstep(0.35, 0.7, fw));
}
float hachura(vec3 w, vec3 n, float tom, float fq_) {
	vec3 b = pow(abs(n), vec3(3.0)); b /= (b.x + b.y + b.z);
	float sd = floor(ferve);
	float wob = (vnoise(w.xz * 0.9 + vec2(sd * 3.1, sd * 1.7)) - 0.5) * 0.3 + (vnoise(vec2(w.y * 2.3, sd)) - 0.5) * 0.2;
	// fluxo: no chão inclinado, a linha segue a curva de nível; no plano, diagonal fixa
	vec2 hn = n.xz;
	float incl = smoothstep(0.35, 0.7, length(hn));   // só barranco íngreme segue o fluxo; o resto fica em traço deitado
	vec2 dfix = normalize(vec2(0.15, 1.0) + vec2(vnoise(w.xz * 0.07) - 0.5, 0.0) * 0.6);
	vec2 dniv = length(hn) > 1e-3 ? normalize(hn) : dfix;
	vec2 dch = normalize(mix(dfix, dniv, incl));
	float cs = w.y * fq_ + wob;
	float ct = dot(w.xz, dch) * fq_ + wob;
	// traço quebrado (buril): falhas ao longo da linha
	float dashs = step(0.32, vnoise(vec2(dot(w.xz, vec2(0.7, 0.7)) * 2.0 + floor(cs) * 7.3, floor(cs) * 1.9 + sd * 0.5)));
	float dasht = step(0.4, vnoise(vec2(dot(w.xz, vec2(-dch.y, dch.x)) * 2.6 + floor(ct) * 7.3, floor(ct) * 1.9 + sd * 0.5)));
	// camada 1: entra a partir de tom 0,12; espessura cresce com o tom
	float t1 = clamp((tom - 0.08) * 1.0, 0.0, 0.36);
	float l1 = (linha(cs, t1) * dashs * (b.x + b.z) + linha(ct, t1) * dasht * b.y) * step(0.12, tom);
	// camada 2 (cruzada, meia densidade): só nos tons altos
	float t2 = clamp((tom - 0.45) * 1.2, 0.0, 1.0);
	float l2 = 0.0;
	if (t2 > 0.01) {
		float cs2 = dot(vec2(w.x + w.z, w.y), vec2(0.6, 0.8)) * fq_ * 0.5 + wob;
		float ct2 = dot(w.xz, vec2(-dch.y, dch.x)) * fq_ * 0.5 + wob;
		l2 = linha(cs2, t2 * 0.4) * (b.x + b.z) + linha(ct2, t2 * 0.4) * b.y;
	}
	return clamp(max(l1, l2), 0.0, 1.0);
}

// Saída dos materiais unshaded: no Compatibility (Godot 4.7, prévia web) o ALBEDO de um material unshaded sai sem a
// conversão linear -> sRGB que o Forward+ faz (0,05 vira 13 em vez de 63). Converter aqui deixa os dois iguais.
vec3 saida(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
#else
	return c;
#endif
}
// Entrada de cores 'source_color' nos materiais unshaded: no Compatibility elas chegam em sRGB (sem conversão),
// então são linearizadas aqui antes de passar por saida(). No Forward+ já chegam lineares.
vec3 entrada(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
#else
	return c;
#endif
}
