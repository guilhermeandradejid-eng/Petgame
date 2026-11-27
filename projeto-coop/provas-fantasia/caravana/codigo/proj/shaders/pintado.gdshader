// pintado_pela_luz: o único shader-base de personagens e cenário. Na luz das lanternas (pavio) é guache fosco em
// 3 faixas com borda de pincelada; fora dela é gravura em água-forte. A fronteira é a frente de pincel (guache molhado).
// O Sol Velho (a única luz direcional) só decide as faixas e projeta a sombra; quem decide pintado ou gravado é o pavio.
shader_type spatial;
render_mode world_vertex_coords, cull_back, specular_disabled;
#include "res://shaders/comum.gdshaderinc"

uniform float heroi = 0.0;          // 1: sempre pintado (luz de borda própria da lanterna do cinto)
uniform float fuligem_h = 0.0;      // altura (m) até onde as pernas do herói já viram hachura
uniform float metal = 0.0;          // ponto de luz pintado
uniform float borda = 0.0;          // luz de borda quente (heróis)
uniform vec3 cor_jogador : source_color = vec3(1.0);
uniform float susto = 0.0;          // clarão de susto (pintado agora)
uniform float freq = 11.0;          // linhas por metro
uniform float forca_pavio = 1.0;    // 0: o objeto ignora as lanternas (fundo distante)
uniform float valor_min = 0.16;
uniform float tom_k = 1.0;
uniform float vento_k = 0.0;        // balanço de vento (juncos, estandartes): peso pela cor de vértice alfa
uniform vec4 forcar = vec4(0.0);
uniform float tom_linha = 1.0;
uniform float massa = 0.0;         // bicho da Treva: massa escura (tinta-noite) com poucas linhas, lê contra o chão gravado
uniform float fino = 0.0;          // folha fina (junco, capim): na Treva vira o próprio traço claro
uniform float molhado = 0.0;       // lodo molhado: listras douradas refletidas das lanternas
uniform float chao = 0.0;          // terreno: albedo procedural (ocre, grama, seixos) por cima da cor de vértice
uniform float desat = 0.18;        // guache dessaturado (dark fantasy)
uniform float fade_lin = 1.0;      // as linhas da gravura somem com a distância (névoa)

varying vec3 vw;
varying vec3 vn;
varying float vm;
varying float vmol;
varying vec3 vdl;
varying float vq;
varying float vnz;
varying float vh;
varying vec3 vbase;
varying float vref;
varying float vpinc;
varying float vdist;
varying float vhl0;
varying float vhl1;

void vertex() {
	if (vento_k > 0.0) {
		float h = max(VERTEX.y - NODE_POSITION_WORLD.y, 0.0);
		float ph = dot(VERTEX.xz, vec2(0.37, 0.21));
		float g = sin(vento.w * 2.1 + ph) * 0.6 + sin(vento.w * 3.7 + ph * 1.7) * 0.4;
		VERTEX.xz += vento.xy * (vento.z * 0.35 + g * 0.18) * h * h * vento_k;
	}
	VERTEX.y -= drop_curva(VERTEX);
	vw = VERTEX;
	vh = VERTEX.y - NODE_POSITION_WORLD.y;
}

void fragment() {
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vn = nw;
	float n = pincelada(vw, nw);
	vnz = n;
	vpinc = step(0.5, pinc2(vw.xz * 4.0 + vw.y * 2.0, 0.4 + n)) * 0.6 + pinc2(vw.xz * 9.0 + vec2(vw.y * 5.0), 1.1) * 0.4;
	float m, mol, q; vec3 dl;
	pavio(vw, n, m, mol, dl, q);
	m *= forca_pavio; mol *= forca_pavio; q *= forca_pavio;
	if (heroi > 0.5) {
		float perna = 1.0 - smoothstep(-0.04, 0.04, fuligem_h - vh + (n - 0.5) * 0.08);
		m = max(m, perna);
		q = max(q, 0.62 * perna);   // a lanterna do cinto: o herói fica sempre na faixa clara da rampa
		dl = normalize(mix(dl, normalize(vec3(-0.3, 0.8, 0.5)), 0.5));
	}
	m = clamp(m + forcar.x - forcar.y, 0.0, 1.0);
	vm = m; vmol = mol * m; vq = q;
	vdl = (VIEW_MATRIX * vec4(dl, 0.0)).xyz;
	vbase = COLOR.rgb * tom_k;
	if (chao > 0.5) {
		// albedo real do chão: manchas de ocre, grama rala e seixos sobre o lodo da cor de vértice
		float lv = dot(COLOR.rgb, vec3(0.3, 0.55, 0.15));
		float seco = clamp(lv / 0.06, 0.4, 1.3);                  // o lodo molhado (escuro) continua escuro
		float oc = smoothstep(0.42, 0.68, vnoise(vw.xz * 0.32 + 4.0) * 0.7 + vnoise(vw.xz * 1.3) * 0.3);
		float gr = smoothstep(0.5, 0.72, vnoise(vw.xz * 0.45 + 17.0) * 0.75 + vnoise(vw.xz * 2.1 + 3.0) * 0.25);
		vec2 cel = floor(vw.xz * 5.0);
		vec2 cc = (cel + vec2(h21(cel), h21(cel + 5.3)) * 0.7 + 0.15) / 5.0;
		float pb = step(0.95, h21(cel + 11.0)) * (1.0 - smoothstep(0.025, 0.045, length(vw.xz - cc * vec2(1.0, 1.0) + vec2(0.01, 0.0))));
		vec3 ocre = vec3(0.26, 0.15, 0.055) * seco;
		vec3 grama = vec3(0.12, 0.14, 0.045) * seco;
		vec3 seixo = vec3(0.16, 0.15, 0.13);
		vbase = mix(vbase, ocre, oc * 0.75);
		vbase = mix(vbase, grama, gr * 0.7);
		vbase = mix(vbase, seixo, pb);
	}
	vdist = length(vw - CAMERA_POSITION_WORLD);
	vref = 0.0;
	if (molhado > 0.0) {
		vec4 Ls[8] = vec4[8](pavio_0, pavio_1, pavio_2, pavio_3, pavio_4, pavio_5, pavio_6, pavio_7);
		vec3 rgt = normalize((INV_VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
		vec3 fw = normalize(vec3(vw.x - CAMERA_POSITION_WORLD.x, 0.0, vw.z - CAMERA_POSITION_WORLD.z));
		for (int i = 0; i < 8; i++) {
			if (Ls[i].w > 0.3) {
				vec3 d = vw - Ls[i].xyz;
				float lat = abs(dot(d, rgt)) + (vnoise(vec2(vw.x * 4.0, vw.z * 14.0)) - 0.5) * 0.5;
				float ao = dot(vec3(d.x, 0.0, d.z), fw);
				float alc = min(Ls[i].w, 4.0);
				vref = max(vref, exp(-lat * lat / 0.18) * smoothstep(-alc * 1.1, -0.2, ao) * (1.0 - smoothstep(-0.2, 0.4, ao)));
			}
		}
		vref *= step(0.45, pinc2(vw.xz * vec2(1.0, 3.5), 0.0)) * molhado;
	}
	float lumb = dot(vbase, vec3(0.3, 0.55, 0.15));
	// tom do TAM: luminância do albedo e curvatura (bordas e quinas ganham linha)
	float curv = clamp(length(fwidth(nw)) * 6.0, 0.0, 0.3);
	float t0 = clamp(0.04 + 0.22 * sqrt(lumb) + curv, 0.0, 0.9) * tom_linha;
	float t1 = clamp(0.1 + 0.42 * sqrt(lumb) + curv, 0.0, 0.9) * tom_linha;
	float lfade = mix(1.0, 1.0 - smoothstep(20.0, 48.0, vdist), fade_lin);
	vhl0 = hachura(vw, nw, t0, freq) * lfade;
	vhl1 = hachura(vw, nw, t1, freq) * lfade;
	ALBEDO = vec3(1.0);
	ROUGHNESS = 1.0;
}

vec3 guache(vec3 base, float s, float lt, float n, float q, float mol, vec3 N, vec3 V, vec3 L) {
	// 3 faixas sem degradê, borda recortada pela pincelada
	float t = max(s * 0.9, lt) + (n - 0.5) * 0.34;
	// rampa de valor da luz: núcleo quente e claro, borda fria e escura (a luz cai, não é um decalque chapado)
	float rq = smoothstep(0.0, 1.0, q);
	vec3 rampa = mix(vec3(0.42, 0.45, 0.56), vec3(1.38, 1.12, 0.8), rq);
	vec3 luz = base * rampa;
	vec3 meia = base * vec3(0.74, 0.62, 0.72) * mix(vec3(0.55, 0.57, 0.68), vec3(1.2, 1.0, 0.8), rq);
	vec3 sombra = base * mix(vec3(0.46, 0.38, 0.62), vec3(0.62, 0.54, 0.76), heroi);
	luz *= 1.0 + 0.12 * heroi;
	vec3 c = t > 0.62 ? luz : (t > 0.36 ? meia : sombra);
	c *= 0.9 + 0.2 * vpinc;
	if (metal > 0.5) {
		vec3 Hh = normalize(L + V);
		float sp = dot(N, Hh) + (n - 0.5) * 0.08;
		c = mix(c, base * 0.6 + C_SEBO * 0.9, step(0.93, sp) * step(0.36, t));
	}
	// frente de pincel: guache molhado, mais saturado e com a borda da tinta acumulada
	float lum = dot(c, vec3(0.3, 0.55, 0.15));
	vec3 sat = max(mix(vec3(lum), c, 1.45), 0.0);
	c = mix(c, sat * vec3(1.06, 0.98, 0.92), mol * 0.6);
	float lum2 = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(vec3(lum2), c, 1.0 - desat);
	return c;
}

void light() {
	if (!LIGHT_IS_DIRECTIONAL) {
		// [PC] lanternas do motor: só o reforço quente com sombra própria (sombras longas das lanternas)
		float nd = max(dot(NORMAL, LIGHT), 0.0);
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * nd * 0.06 * vbase * vm / PI;
	} else {
		vec3 N = NORMAL;
		float s = clamp(dot(N, LIGHT) * 0.5 + 0.5, 0.0, 1.0) * mix(0.25, 1.0, ATTENUATION);
		vec3 lv = normalize(vdl);
		float lt = (clamp(dot(N, lv) * 0.5 + 0.5, 0.0, 1.0)) * smoothstep(0.0, 0.5, vq) * 1.05;
		vec3 base = vbase;
		vec3 pint = guache(base, s, lt, vnz, vq, vmol, N, VIEW, LIGHT);
		float fr = 1.0 - clamp(dot(N, VIEW), 0.0, 1.0);
		// luz de borda na cor do jogador (heróis): destaca a silhueta do fundo escuro
		pint += cor_jogador * smoothstep(0.66, 0.86, fr) * borda * 0.45;
		pint *= mix(1.0, 0.55, massa);
		pint += vec3(0.9, 0.8, 0.6) * susto;
		pint = mix(pint, C_SEBO * 0.9 + C_AMBAR * 0.4, vref * 0.75);
		// gravura: fundo azul-noite (mais escuro longe), linhas claras pela forma
		vec3 fundo = mix(C_FUNDO, C_NOITE * 1.6, smoothstep(18.0, 70.0, vdist));
		fundo = max(fundo, vec3(valor_min * valor_min * 0.9, valor_min * valor_min * 0.95, valor_min * valor_min * 1.4));
		float hl = mix(vhl0, vhl1, smoothstep(0.4, 0.7, s + (vnz - 0.5) * 0.2)) * (1.0 - 0.75 * massa);
		fundo = mix(fundo, C_NOITE * 0.75, massa);
		vec3 grav = mix(fundo, C_LINHA, hl);
		// sulco claro no contorno de dentro
		grav = mix(grav, mix(C_LINHA * 1.2, C_TRACO * 1.1, massa), smoothstep(0.72, 0.9, fr) * mix(0.6, 0.22, massa));
		grav = mix(grav, C_TRACO * (0.4 + 0.3 * s) * mix(0.35, 1.0, 1.0 - smoothstep(25.0, 60.0, vdist)), fino);
		DIFFUSE_LIGHT += mix(grav, pint, vm);
	}
}
