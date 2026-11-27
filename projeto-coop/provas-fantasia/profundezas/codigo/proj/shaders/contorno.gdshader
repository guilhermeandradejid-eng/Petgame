// Casca invertida de 1,5 px (em 1080p) na cor da lavagem do personagem: só separa a miniatura do fundo.
// Nenhum traço de tinta preta. Alfa da cor de vértice = peso da casca.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform float px = 1.5;
uniform float px_ref = 1080.0;
uniform vec4 cor = vec4(0.0);     // a > 0 troca a cor (máscara, silhueta do jogador)
varying vec3 wp;
void vertex() {
	wp = VERTEX;
	vec4 vp = VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 nv = normalize((VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
	float span = abs(ortho ? 2.0 / PROJECTION_MATRIX[1][1] : (-vp.z) * 2.0 / PROJECTION_MATRIX[1][1]);
	vp.xyz += nv * (px / px_ref * span * COLOR.a);
	POSITION = PROJECTION_MATRIX * vp;
}
void fragment() {
	vec3 c = mix(vc(COLOR.rgb) * 0.8, cor.rgb, cor.a);
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(mix(c, f.rgb, f.a));
}
