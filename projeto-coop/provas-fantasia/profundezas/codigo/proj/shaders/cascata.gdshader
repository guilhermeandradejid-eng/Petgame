// A Cascata do Beiral: véu branco em faixas que correm para baixo e vira névoa antes do chão.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform float y_some = -330.0;
uniform float y_topo = 300.0;
uniform vec3 cor : source_color = vec3(0.6, 0.66, 0.72);
varying vec3 wp;
void vertex() { wp = VERTEX; }
void fragment() {
	float t = vento.w;
	float s = vnoise(vec2(UV.x * 40.0, wp.y * 0.02 + t * 1.6)) * 0.6 + vnoise(vec2(UV.x * 120.0, wp.y * 0.05 + t * 2.4)) * 0.4;
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	float fade = smoothstep(y_some, y_some + 160.0, wp.y);
	float a = (0.35 + 0.65 * smoothstep(0.35, 0.75, s)) * edge * fade * 0.9;
	vec3 c = cor * (0.75 + 0.45 * s);
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(mix(c, f.rgb, f.a * 0.75));
	ALPHA = a;
}
