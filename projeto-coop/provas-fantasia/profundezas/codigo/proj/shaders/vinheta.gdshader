// Vinheta pintada (quad preso à câmera): escurece e esfria as bordas do mapa, nunca o centro.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, shadows_disabled, cull_disabled;
#include "res://shaders/comum.gdshaderinc"
uniform float forca = 0.55;
void vertex() { POSITION = vec4(VERTEX.xy, 0.0, 1.0); }
void fragment() {
	vec2 p = SCREEN_UV * 2.0 - 1.0;
	p.x *= 0.82;
	float d = length(p * vec2(1.0, 1.08));
	float k = smoothstep(0.62, 1.45, d) * forca;
	ALBEDO = saida(vec3(0.012, 0.016, 0.03));
	ALPHA = k;
}
