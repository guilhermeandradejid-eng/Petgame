// Labareda: chama em billboard alinhado ao eixo Y (inclinado um pouco para a câmera alta), com ruído que corre
// para cima por vértice e por pixel, erosão de alfa pela altura e pela vida, e gradiente emissivo branco, amarelo,
// laranja e vermelho do núcleo à ponta. Quantizado em 5 faixas macias (guache), HDR para o glow do PC.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;
#include "res://shaders/comum.gdshaderinc"
uniform float fase = 0.0;
uniform float energia = 1.6;
uniform float vida = 1.0;      // 0..1: tamanho/força (nasce, ruge, morre)
uniform float tempo = 0.0;
uniform float largura = 0.42;
varying float vh;
void vertex() {
	vec3 c = NODE_POSITION_WORLD;
	vec3 tc = CAMERA_POSITION_WORLD - c; tc.y = 0.0;
	tc = length(tc) > 1e-3 ? normalize(tc) : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), tc));
	vec3 up = normalize(vec3(0.0, 1.0, 0.0) - tc * 0.5);
	float sx = length(MODEL_MATRIX[0].xyz), sy = length(MODEL_MATRIX[1].xyz);
	float h = clamp(VERTEX.y, 0.0, 1.0);
	vh = h;
	// lambida: ruído que sobe pela chama e o vento deita a ponta
	float sw = (vnoise(vec2(fase * 17.0, h * 2.0 - tempo * 2.6)) - 0.5) * 0.5 + sin(tempo * 7.0 + fase * 30.0 + h * 3.0) * 0.08;
	vec3 w = c + right * (VERTEX.x * sx * largura * 2.0 + sw * h * h * sy * 0.45) + up * VERTEX.y * sy;
	w.xz += vento.xy * vento.z * 0.35 * h * h * sy;
	w.y -= drop_curva(w);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	vec2 uv = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);   // x -1..1, y 0 (base) .. 1 (ponta)
	float y = uv.y;
	float n1 = vnoise(vec2(uv.x * 2.4 + fase * 13.0, y * 2.6 - tempo * 3.4 + fase * 7.0));
	float n2 = vnoise(vec2(uv.x * 6.0 + fase * 5.0, y * 6.5 - tempo * 6.5));
	float nn = n1 * 0.62 + n2 * 0.38;
	// perfil de gota: largo embaixo, ponta fina; o ruído entorta mais no alto
	// perfil por chama: largura e curva variam com a fase; borda recortada por ruído de duas escalas
	float prof = (0.75 + 0.25 * fase) * pow(clamp(1.0 - y, 0.0, 1.0), 0.6 + 0.5 * fase) * smoothstep(-0.05, 0.2, y);
	prof *= 0.8 + 0.4 * vnoise(vec2(y * 5.0 - tempo * 4.0, fase * 9.0));
	float dx = abs(uv.x + (nn - 0.5) * 0.9 * y + sin(y * 4.0 + fase * 6.0) * 0.12 * y);
	float corpo = prof - dx;
	// erosão de alfa: o limiar sobe com a altura e quando a chama morre
	float er = y * 0.5 + (1.0 - vida) * 0.7;
	float dens = corpo * 1.8 + (nn - 0.5) * 0.7 - er * 0.6 + 0.12;
	float a = smoothstep(0.0, 0.07, dens);
	if (a < 0.02) discard;
	// calor: núcleo branco embaixo, vermelho na ponta e na borda
	float heat = clamp(dens * 1.25 + (0.2 - y) * 1.0, 0.0, 1.0);
	float hq = floor(heat * 5.0) / 4.0;
	heat = mix(hq, heat, 0.3);
	vec3 col = mix(vec3(0.5, 0.06, 0.02), vec3(1.0, 0.3, 0.04), smoothstep(0.0, 0.35, heat));
	col = mix(col, vec3(1.0, 0.68, 0.16), smoothstep(0.35, 0.65, heat));
	col = mix(col, vec3(1.0, 0.95, 0.78), smoothstep(0.7, 1.0, heat));
	ALBEDO = col * energia * mix(0.7, 1.15, heat);
	ALPHA = a * mix(0.75, 1.0, smoothstep(0.0, 0.3, heat));
	ALBEDO = saida(ALBEDO);
}
