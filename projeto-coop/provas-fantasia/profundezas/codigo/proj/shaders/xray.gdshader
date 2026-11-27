// Silhueta do herói atrás de obstáculo (regra 17 da pesquisa): onde o cenário opaco tampa o herói, ele aparece
// chapado na cor do jogador. Lê a profundidade da cena; onde o herói está visível, descarta.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, shadows_disabled, blend_mix;
#include "res://shaders/comum.gdshaderinc"
uniform vec3 cor : source_color = vec3(1.0);
uniform float perto = 0.0;        // profundidade (m) do ponto mais perto do herói: só tampa o que está na frente dele inteiro
uniform sampler2D prof : hint_depth_texture, filter_nearest;
void fragment() {
	float dz = texture(prof, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, dz) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, dz);
#endif
	vec4 vw = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float cena = -vw.z / vw.w;
	if (cena > perto) discard;
	float listra = step(0.5, fract((FRAGCOORD.x + FRAGCOORD.y) / 6.0));
	ALBEDO = saida(cor * mix(0.85, 1.15, listra));
	ALPHA = 0.8;
}
