// A Coluna do Meio-Dia: lança de poeira dourada (cilindro aditivo). Mais densa no miolo, borda que se desfaz,
// poeira subindo devagar. No PC soma-se o FogVolume; no iPhone é só isto.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform float forca = 0.5;
uniform vec3 cor : source_color = vec3(0.9, 0.78, 0.48);
uniform float y0 = -135.0;
uniform float y1 = 280.0;
varying vec3 wp;
varying vec3 wn;
void vertex() { wp = VERTEX; wn = NORMAL; }
void fragment() {
	vec3 V = normalize(CAMERA_POSITION_WORLD - wp);
	float facing = abs(dot(normalize(wn), V));
	float core = pow(facing, 1.6);
	float dust = vnoise(vec2(wp.x * 0.05 + wp.z * 0.05, wp.y * 0.02 - vento.w * 0.03)) * 0.6 + vnoise(vec2(wp.x * 0.2, wp.y * 0.1 + vento.w * 0.05)) * 0.4;
	float h = smoothstep(y0, y0 + 30.0, wp.y) * (1.0 - smoothstep(y1 - 60.0, y1, wp.y));
	float k = core * (0.55 + 0.6 * dust) * h * forca;
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(cor * k * (1.0 - f.a * 0.6));
}
