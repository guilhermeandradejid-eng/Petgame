// Telegrafia de perigo: vermelhão de perigo (#B5301F), a única cor de ameaça (o verde-mordente fica só nos mortos).
// Faixa em forma de lança (larga no pé, ponta fina), com contorno em traço de pena (largura que varia, pontas que
// passam do canto) e preenchimento que sobe do pé à ponta mostrando o tempo até o golpe; o resto é hachura animada.
// Círculo (modo 1): contorno de pena e preenchimento em setor de relógio.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;
global uniform vec3 foco;
global uniform float curva_k;
global uniform float curva_r0;
global uniform vec2 curva_dir;
global uniform float tempo;
global uniform sampler2D grao : filter_nearest, repeat_enable;
uniform vec3 verde : source_color = vec3(0.710, 0.188, 0.122);   // (nome antigo) cor do perigo
uniform vec3 tinta : source_color = vec3(0.137, 0.110, 0.090);
uniform float progresso = 1.0;
uniform float aceso = 1.0;
uniform int modo = 0;      // 0 lança (UV.y = 0 no pé, 1 na ponta), 1 círculo (UV centrado)
uniform float semente = 0.0;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(h21(vec2(i, semente)), h21(vec2(i + 1.0, semente)), f); }
void vertex() {
	float d = dot(VERTEX.xz - foco.xz, curva_dir);
	float e = max(d - curva_r0, 0.0);
	VERTEX.y -= curva_k * e * e;
}
void fragment() {
	if (aceso <= 0.0) discard;
	vec2 uv = UV;
	float tq = floor(tempo * 20.0) / 20.0;
	float cheio = 0.0; float hach = 0.0; float pena = 0.0;
	if (modo == 0) {
		float y = uv.y;                // 0 no pé (no morto), 1 na ponta
		float meia = mix(0.42, 0.05, pow(y, 1.2));
		float x = abs(uv.x - 0.5);
		float dentro = step(x, meia) * step(y, 0.985);
		float wp = 0.025 + 0.02 * vn(y * 9.0);               // largura do traço de pena
		float borda = abs(x - meia);
		pena = (1.0 - smoothstep(wp * 0.6, wp, borda)) * step(0.02, y) * step(y, 1.0);
		pena = max(pena, (1.0 - smoothstep(0.012, 0.022, abs(y - 0.01))) * step(x, 0.48 + 0.04 * vn(x * 30.0)));
		cheio = dentro * step(y, progresso);
		hach = dentro * step(0.55, fract((uv.x * 0.6 + y * 2.2) * 5.0 - tq * 1.2)) * (1.0 - cheio);
		// a frente do preenchimento é uma linha de tinta (quanto falta)
		pena = max(pena, dentro * (1.0 - smoothstep(0.008, 0.02, abs(y - progresso))) * step(0.02, progresso) * step(progresso, 0.99));
	} else {
		vec2 c = uv * 2.0 - 1.0;
		float r = length(c);
		float a = atan(c.x, -c.y) / 6.2832 + 0.5;
		float R = 0.9 + 0.025 * (vn(a * 14.0) - 0.5);
		float wp = 0.02 + 0.018 * vn(a * 23.0 + 3.0);
		pena = 1.0 - smoothstep(wp * 0.6, wp, abs(r - R));
		float dentro = step(r, R);
		// o setor já cumprido do relógio recebe hachura fina (35%); o resto do círculo fica limpo
		cheio = 0.0;
		hach = dentro * step(a, progresso) * step(0.68, fract((c.x + c.y) * 9.0 - tq * 1.2)) * smoothstep(0.15, 0.5, r);
		pena = max(pena, dentro * (1.0 - smoothstep(0.01, 0.025, abs(fract(a - progresso + 0.5) - 0.5) * r * 6.2832)) * step(0.01, progresso));
	}
	float g = texture(grao, FRAGCOORD.xy / 256.0).r;
	if (pena > 0.5) { ALBEDO = tinta; }
	else if (cheio > 0.5) { ALBEDO = verde; }
	else if (hach > 0.5 && g < 0.8) { ALBEDO = verde; }
	else { discard; }
}
