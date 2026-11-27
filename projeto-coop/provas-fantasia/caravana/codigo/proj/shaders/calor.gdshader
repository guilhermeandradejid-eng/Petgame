// [PC] Distorção de calor sobre a Labareda: desloca a tela atrás da chama com ruído que sobe. Só no Forward+;
// no Compatibility (prévia web) o material fica invisível.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;
#include "res://shaders/comum.gdshaderinc"
uniform float forca = 1.0;
uniform float tempo = 0.0;
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
uniform sampler2D tela : hint_screen_texture, filter_linear;
#endif
void vertex() {
	vec3 c = NODE_POSITION_WORLD;
	vec3 tc = CAMERA_POSITION_WORLD - c; tc.y = 0.0; tc = normalize(tc);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), tc));
	vec3 up = normalize(vec3(0.0, 1.0, 0.0) - tc * 0.5);
	float sx = length(MODEL_MATRIX[0].xyz), sy = length(MODEL_MATRIX[1].xyz);
	vec3 w = c + right * VERTEX.x * sx + up * VERTEX.y * sy;
	w.y -= drop_curva(w);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	vec2 uv = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float mask = (1.0 - smoothstep(0.4, 1.0, abs(uv.x))) * smoothstep(0.0, 0.25, uv.y) * (1.0 - smoothstep(0.6, 1.0, uv.y));
	vec2 off = vec2(vnoise(vec2(uv.x * 5.0, uv.y * 4.0 - tempo * 3.0)) - 0.5, vnoise(vec2(uv.x * 4.0 + 7.0, uv.y * 5.0 - tempo * 3.7)) - 0.5);
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
	ALBEDO = texture(tela, SCREEN_UV + off * 0.012 * mask * forca).rgb;
	ALPHA = mask;
#else
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
#endif
}
